// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager as AndroidClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages clipboard operations with automatic expiration for security. Matches the iOS
 * ClipboardManager.swift behaviour with a 60-second auto-clear. On API 33+ the clip is
 * marked with EXTRA_IS_SENSITIVE so the system hides the preview and auto-clears; a
 * Handler-based fallback runs on all API levels as defence in depth.
 *
 * MASVS-STORAGE-2: Sensitive data copied to the clipboard is automatically removed after
 * a short timeout to reduce the window for exfiltration via other apps reading clipboard
 * contents. Android 10+ restricts background clipboard access, but foreground apps can
 * still read it, so the auto-clear mitigates that risk.
 */
@Singleton
class ClipboardManager
    @Inject
    constructor(
        private val context: Context,
    ) {
        companion object {
            private const val DEFAULT_EXPIRY_MS = 60_000L // 60 seconds
        }

        private val handler = Handler(Looper.getMainLooper())
        private var clearRunnable: Runnable? = null
        private val systemClipboard: AndroidClipboardManager
            get() = context.getSystemService(Context.CLIPBOARD_SERVICE) as AndroidClipboardManager

        /**
         * Copy text to clipboard with automatic expiration.
         *
         * On API 33+ the clip is marked as sensitive via EXTRA_IS_SENSITIVE so the
         * system hides the content in clipboard preview UI and auto-clears it. On
         * older API levels we rely solely on the Handler-based scheduled clear.
         *
         * @param text      The text to copy.
         * @param label     A non-sensitive label for the clip data.
         * @param sensitive Whether the content is sensitive (default true). When true,
         *                  the system hides the preview on API 33+ and we always
         *                  schedule an auto-clear.
         * @param expiryMs  Custom expiry in milliseconds (defaults to 60 seconds).
         */
        fun copy(
            text: String,
            label: String = "Provii",
            sensitive: Boolean = true,
            expiryMs: Long = DEFAULT_EXPIRY_MS,
        ) {
            // Cancel any pending clear from a previous copy
            clearRunnable?.let { handler.removeCallbacks(it) }

            // Build clip data
            val clip = ClipData.newPlainText(label, text)

            // API 33+: Mark as sensitive so the system hides preview and auto-clears
            if (sensitive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                clip.description.extras =
                    PersistableBundle().apply {
                        putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                    }
            }

            systemClipboard.setPrimaryClip(clip)

            // Defence in depth: always schedule our own clear regardless of API level.
            // On API 33+ this is a fallback in case the system auto-clear is delayed.
            val runnable = Runnable { clear() }
            clearRunnable = runnable
            handler.postDelayed(runnable, expiryMs)

            Timber.d("Clipboard set with ${expiryMs / 1000}s expiration (sensitive=$sensitive, api=${Build.VERSION.SDK_INT})")
        }

        /**
         * Immediately clear the clipboard. Safe to call multiple times.
         *
         * LIMITATION (INV-WM-010): On pre-API 28 (Android P) devices, `clearPrimaryClip()`
         * is unavailable. The fallback overwrites the clip with an empty string, which
         * clears the visible content but does not remove the clip entry from the system
         * clipboard history. This is an accepted platform limitation; API 27 and below
         * represent < 5% of the install base and there is no reliable alternative.
         */
        fun clear() {
            clearRunnable?.let { handler.removeCallbacks(it) }
            clearRunnable = null

            try {
                // Android P (28+) added clearPrimaryClip()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    systemClipboard.clearPrimaryClip()
                } else {
                    // Pre-P fallback: overwrite with empty clip (see LIMITATION above)
                    systemClipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                }
                Timber.d("Clipboard cleared")
            } catch (e: Exception) {
                Timber.e(e, "Failed to clear clipboard")
            }
        }
    }
