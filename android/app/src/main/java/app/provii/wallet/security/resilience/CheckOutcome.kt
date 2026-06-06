// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security.resilience

import timber.log.Timber

/**
 * Tracks the outcome of individual security checks so that mass exception events
 * (indicative of seccomp filtering, blanket hooking, or similar attack techniques)
 * can be detected at the orchestrator level.
 *
 * Each check invocation records whether it completed successfully or threw an exception.
 * After all checks finish, [ExceptionTally.exceedsThreshold] reveals whether the
 * proportion of exceptions exceeds a configured limit.
 */
data class ExceptionTally(
    val totalChecks: Int,
    val exceptionCount: Int,
    val threshold: Float,
) {
    /**
     * True when the ratio of exceptions to total checks exceeds the configured threshold.
     * Returns false when totalChecks is zero (no checks ran) to avoid division by zero.
     */
    val exceedsThreshold: Boolean
        get() = totalChecks > 0 && (exceptionCount.toFloat() / totalChecks.toFloat()) > threshold
}

/**
 * Mutable builder for accumulating check outcomes during a detection run.
 * Not thread-safe; intended for single-threaded use within a single [performChecks] call.
 */
class ExceptionTallyBuilder(private val threshold: Float) {
    private var total = 0
    private var exceptions = 0

    /**
     * Run a single check lambda, returning its boolean result. If the lambda throws,
     * the exception is counted and [defaultOnException] is returned instead.
     *
     * @param tag Logging tag for the parent checker
     * @param checkName Human-readable name used in log messages
     * @param defaultOnException Value returned when the check throws
     * @param check The detection logic to execute
     * @return The check result, or [defaultOnException] on exception
     */
    fun runCheck(
        tag: String,
        checkName: String,
        defaultOnException: Boolean = false,
        check: () -> Boolean,
    ): Boolean {
        total++
        return try {
            check()
        } catch (t: Throwable) {
            exceptions++
            Timber.tag(tag).e(t, "Exception in check: %s", checkName)
            defaultOnException
        }
    }

    /**
     * Merge another tally's counts into this builder. Used when an aggregator method
     * (e.g. checkFridaIndicators) delegates to sub-checks via its own builder and then
     * folds the sub-tally back into the parent.
     */
    fun merge(child: ExceptionTally) {
        total += child.totalChecks
        exceptions += child.exceptionCount
    }

    fun build(): ExceptionTally =
        ExceptionTally(
            totalChecks = total,
            exceptionCount = exceptions,
            threshold = threshold,
        )
}
