// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.settings

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import app.provii.wallet.R
import app.provii.wallet.config.EnvironmentManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Hidden sandbox environment toggle activated by tapping the version label seven times
 * within a short window. Mirrors the Android developer options pattern. Shows toast
 * countdown feedback during activation and triggers an environment switch between
 * production and sandbox via [EnvironmentManager].
 *
 * When disabling sandbox, [onSettingsTap] awaits revocation via
 * [EnvironmentManager.disableSandboxAndRevoke] with a 10-second timeout before killing
 * the process. This prevents the race where [android.os.Process.killProcess] fires before
 * the gateway revoke HTTP call can complete (OkHttp default timeout is 15 s, former kill
 * delay was 1.5 s).
 */
class SandboxToggleHandler {
    private var tapCount = 0
    private val handler = Handler(Looper.getMainLooper())
    private val resetRunnable = Runnable { tapCount = 0 }
    private var lastToast: Toast? = null
    private var toggled = false

    companion object {
        private const val REQUIRED_TAPS = 5
        private const val RESET_DELAY_MS = 2000L // Reset after 2 seconds of no taps

        /** Maximum time to wait for gateway revocation before killing the process anyway. */
        private const val REVOKE_TIMEOUT_MS = 10_000L
    }

    /**
     * Handle a tap on the settings version label.
     *
     * @param context Android context for toasts and process restart.
     * @param scope Coroutine scope used to await revocation on the disable path.
     *   Must remain active until the process is killed. Pass [rememberCoroutineScope]
     *   from the composable that owns this handler.
     * @param onSandboxDisabled Optional suspend callback invoked after revocation completes
     *   (or times out) and before the process is killed. Use this to run any additional
     *   cleanup such as clearing local credential records.
     * @return `true` if sandbox was enabled, `null` otherwise (disable path is async).
     */
    fun onSettingsTap(
        context: Context,
        scope: CoroutineScope,
        onSandboxDisabled: (suspend () -> Unit)? = null,
    ): Boolean? {
        // Ignore taps after toggle has fired (app is restarting)
        if (toggled) return null

        // Cancel any existing toast to show new one immediately
        lastToast?.cancel()

        // Remove any pending reset
        handler.removeCallbacks(resetRunnable)

        // Increment tap count
        tapCount++
        var toggleResult: Boolean? = null

        when (tapCount) {
            REQUIRED_TAPS -> {
                // Show developer message
                lastToast =
                    Toast.makeText(
                        context,
                        context.getString(R.string.sandbox_toast_developer_mode),
                        Toast.LENGTH_SHORT,
                    ).apply { show() }

                // Schedule reset
                handler.postDelayed(resetRunnable, RESET_DELAY_MS)
            }

            REQUIRED_TAPS + 1 -> {
                // Toggle sandbox mode
                toggled = true
                val isSandboxEnabled = EnvironmentManager.isSandboxEnabled()
                val newState = !isSandboxEnabled

                // Reset counter
                tapCount = 0

                if (newState) {
                    // Enabling sandbox: fire-and-forget bootstrap (same as before).
                    EnvironmentManager.enableSandbox(true)
                    toggleResult = true

                    lastToast =
                        Toast.makeText(
                            context,
                            context.getString(R.string.sandbox_toast_enabled),
                            Toast.LENGTH_LONG,
                        ).apply { show() }

                    // Restart app after a short delay
                    handler.postDelayed({
                        restartApp(context)
                    }, 1500)
                } else {
                    // Disabling sandbox: show "Switching..." immediately, then await
                    // gateway revocation before killing the process.
                    lastToast =
                        Toast.makeText(
                            context,
                            context.getString(R.string.sandbox_toast_switching),
                            Toast.LENGTH_LONG,
                        ).apply { show() }

                    scope.launch {
                        // Persist preference + current environment synchronously inside
                        // disableSandboxAndRevoke, then await the HTTP revoke call.
                        // withTimeoutOrNull ensures the process is killed even if the
                        // gateway is unreachable; revocation is best-effort.
                        withTimeoutOrNull(REVOKE_TIMEOUT_MS) {
                            EnvironmentManager.disableSandboxAndRevoke()
                            onSandboxDisabled?.invoke()
                        }
                        // Kill on the main thread via Handler so any pending UI work
                        // can complete before the process exits.
                        handler.post {
                            restartApp(context)
                        }
                    }

                    // Return null: caller must not assume synchronous completion.
                    toggleResult = null
                }
            }

            in 3..4 -> {
                // Show countdown
                val remaining = REQUIRED_TAPS - tapCount
                val message =
                    if (remaining == 1) {
                        context.getString(R.string.sandbox_toast_one_step_away)
                    } else {
                        context.getString(R.string.sandbox_toast_steps_away, remaining)
                    }
                lastToast = Toast.makeText(context, message, Toast.LENGTH_SHORT).apply { show() }

                // Schedule reset
                handler.postDelayed(resetRunnable, RESET_DELAY_MS)
            }

            else -> {
                // Early taps (1-2) - no message shown
                handler.postDelayed(resetRunnable, RESET_DELAY_MS)
            }
        }

        return toggleResult
    }

    private fun restartApp(context: Context) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
        intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK)
        context.startActivity(intent)

        // Force kill the current process
        android.os.Process.killProcess(android.os.Process.myPid())
    }
}
