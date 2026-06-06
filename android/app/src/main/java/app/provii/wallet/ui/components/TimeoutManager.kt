// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.accessibility.TimeoutBehavior
import kotlinx.coroutines.delay
import timber.log.Timber
import kotlin.math.max

/**
 * Timeout management facilities for time-limited flows such as verification sessions.
 * Provides both a composable [rememberTimeoutState] hook and a class-based [TimeoutManager]
 * for non-Compose contexts. Respects WCAG 2.2 AAA criterion 2.2.3 (No Timing) by
 * honouring the user's [TimeoutBehavior] preference from [WalletAccessibilityManager].
 */

/**
 * State holder for timeout management.
 *
 * Tracks remaining time and provides callbacks for timeout events.
 * Respects accessibility timeout behaviour settings.
 *
 * @property totalSeconds Total timeout duration in seconds
 * @property remainingSeconds Current remaining seconds before timeout
 * @property isActive Whether the timeout is currently running
 * @property hasExpired Whether the timeout has expired
 */
data class TimeoutState(
    val totalSeconds: Int,
    val remainingSeconds: Int,
    val isActive: Boolean,
    val hasExpired: Boolean,
) {
    /**
     * Returns the warning threshold (20% of total time or 60 seconds, whichever is smaller)
     */
    val warningThreshold: Int
        get() = max(10, (totalSeconds * 0.2).toInt()).coerceAtMost(60)

    /**
     * Returns true if we should show a warning
     */
    val shouldShowWarning: Boolean
        get() = isActive && remainingSeconds <= warningThreshold && remainingSeconds > 0
}

/**
 * Composable function that manages timeout state and lifecycle.
 *
 * Features:
 * - Automatic countdown with 1-second intervals
 * - Respects accessibility timeout behaviour (NONE = no timeout)
 * - Warning threshold calculation (20% of total time or 60s max)
 * - Callback when timeout expires
 * - Support for extending timeout
 *
 * WCAG 2.2 AAA: 2.2.3 No Timing compliance
 *
 * @param standardDuration Standard timeout duration in milliseconds
 * @param onTimeout Callback when timeout expires
 * @param enabled Whether timeout tracking is enabled
 * @return TimeoutState current state of the timeout
 */
@Composable
fun rememberTimeoutState(
    standardDuration: Long = 30_000L,
    onTimeout: () -> Unit = {},
    enabled: Boolean = true,
): TimeoutState {
    val accessibilityManager = LocalAccessibilityManager.current
    val settings by accessibilityManager.settings.collectAsState()

    // Get the timeout duration based on accessibility settings
    val timeoutDuration = accessibilityManager.getTimeoutDuration(standard = standardDuration)

    // If timeout is disabled (NONE behaviour) or not enabled, return inactive state
    val isActive = enabled && timeoutDuration != null
    val totalSeconds = timeoutDuration?.takeIf { enabled }?.let { (it / 1000).toInt() } ?: 0

    var remainingSeconds by remember { mutableIntStateOf(totalSeconds) }
    var hasExpired by remember { mutableStateOf(false) }

    // Reset timer when settings or duration changes
    LaunchedEffect(timeoutDuration, enabled) {
        if (isActive) {
            remainingSeconds = totalSeconds
            hasExpired = false
            Timber.d("TimeoutManager: Started with $totalSeconds seconds (behavior: ${settings.timeoutBehavior})")
        }
    }

    // Countdown effect
    LaunchedEffect(isActive, remainingSeconds) {
        if (isActive && remainingSeconds > 0) {
            delay(1000)
            remainingSeconds -= 1

            // Log at key intervals for debugging
            when (remainingSeconds) {
                60, 30, 15, 10, 5 -> Timber.d("TimeoutManager: $remainingSeconds seconds remaining")
            }
        } else if (isActive && remainingSeconds == 0 && !hasExpired) {
            Timber.w("TimeoutManager: Timeout expired!")
            hasExpired = true
            onTimeout()
        }
    }

    return TimeoutState(
        totalSeconds = totalSeconds,
        remainingSeconds = remainingSeconds,
        isActive = isActive,
        hasExpired = hasExpired,
    )
}

/**
 * Extension function to extend the timeout by resetting it to the original duration.
 *
 * Note: This is a simple reset approach. More sophisticated implementations
 * could add additional time or use different extension strategies.
 */
fun TimeoutState.extend(): TimeoutState {
    Timber.d("TimeoutManager: Timeout extended, resetting to $totalSeconds seconds")
    return copy(
        remainingSeconds = totalSeconds,
        hasExpired = false,
    )
}

/**
 * Alternative implementation using a class-based approach for more complex scenarios.
 * This provides more control over the timeout lifecycle.
 */
class TimeoutManager(
    private val standardDuration: Long = 30_000L,
    private val onTimeout: () -> Unit = {},
    private val onWarning: (Int) -> Unit = {},
) {
    private var totalSeconds: Int = 0
    private var remainingSeconds: Int = 0
    private var isRunning: Boolean = false
    private var hasExpired: Boolean = false

    val warningThreshold: Int
        get() = max(10, (totalSeconds * 0.2).toInt()).coerceAtMost(60)

    fun start(duration: Long) {
        totalSeconds = (duration / 1000).toInt()
        remainingSeconds = totalSeconds
        isRunning = true
        hasExpired = false
        Timber.d("TimeoutManager: Started with $totalSeconds seconds")
    }

    fun stop() {
        isRunning = false
        Timber.d("TimeoutManager: Stopped")
    }

    fun extend() {
        remainingSeconds = totalSeconds
        hasExpired = false
        Timber.d("TimeoutManager: Extended to $totalSeconds seconds")
    }

    fun tick() {
        if (!isRunning || remainingSeconds <= 0) return

        remainingSeconds -= 1

        when {
            remainingSeconds == 0 -> {
                hasExpired = true
                isRunning = false
                Timber.w("TimeoutManager: Timeout expired!")
                onTimeout()
            }
            remainingSeconds <= warningThreshold && remainingSeconds % 10 == 0 -> {
                Timber.d("TimeoutManager: Warning - $remainingSeconds seconds remaining")
                onWarning(remainingSeconds)
            }
        }
    }

    fun getRemainingSeconds(): Int = remainingSeconds

    fun isActive(): Boolean = isRunning && !hasExpired

    fun shouldShowWarning(): Boolean = isRunning && remainingSeconds <= warningThreshold && remainingSeconds > 0
}
