// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security.resilience

import android.content.Context
import androidx.annotation.VisibleForTesting
import app.provii.wallet.security.antiDebug.AntiDebugChecker
import app.provii.wallet.security.integrity.RootDetector
import app.provii.wallet.security.integrity.SignatureVerifier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Orchestrates all device-level resilience checks into a single security assessment. Combines
 * anti-debugging protection (MASVS-RESILIENCE-1), anti-tampering verification (MASVS-RESILIENCE-2),
 * and root/emulator detection (MASVS-RESILIENCE-3). All checks run locally without Google APIs
 * or network calls, remaining compatible with F-Droid builds and devices without Google services.
 * Results are cached and exposed via [isDeviceCompromised] for gate checks in the UI layer.
 */
class ResilienceChecker private constructor(
    private val context: Context,
    private val config: ResilienceConfig,
) {
    companion object {
        private const val TAG = "ResilienceChecker"

        @Volatile
        private var instance: ResilienceChecker? = null

        /**
         * Get singleton instance of ResilienceChecker.
         */
        fun getInstance(
            context: Context,
            config: ResilienceConfig = ResilienceConfig(),
        ): ResilienceChecker {
            return instance ?: synchronized(this) {
                instance ?: ResilienceChecker(context.applicationContext, config).also {
                    instance = it
                }
            }
        }
    }

    /**
     * Configuration for resilience checks.
     */
    data class ResilienceConfig(
        val enableAntiDebug: Boolean = true,
        val enableTamperDetection: Boolean = true,
        val enableRootDetection: Boolean = true,
        val enableEmulatorDetection: Boolean = true,
        val signatureConfig: SignatureVerifier.VerificationConfig = SignatureVerifier.VerificationConfig(),
        val threatResponsePolicy: ThreatResponsePolicy = ThreatResponsePolicy.RESTRICT_FEATURES,
        val checkIntervalMs: Long = 30_000L, // 30 seconds for periodic checks
        val massFailureThreshold: Float = 0.6f,
    ) {
        companion object {
            /** Minimum allowed polling interval (1 second). Prevents tight
             *  loops from zero or negative values draining battery. */
            const val MIN_CHECK_INTERVAL_MS = 1000L
        }

        /** Check interval clamped to at least [MIN_CHECK_INTERVAL_MS]. */
        val safeCheckIntervalMs: Long get() = maxOf(checkIntervalMs, MIN_CHECK_INTERVAL_MS)
    }

    /**
     * Policy for how to respond to detected threats.
     */
    enum class ThreatResponsePolicy {
        LOG_ONLY, // Just log the threat
        LOG_AND_WARN, // Log and warn but allow app to continue
        RESTRICT_FEATURES, // Disable sensitive features
        TERMINATE, // Terminate the application
    }

    /**
     * Combined result of all resilience checks.
     */
    data class ResilienceResult(
        val antiDebugResult: AntiDebugChecker.AntiDebugResult?,
        val integrityResult: SignatureVerifier.IntegrityResult?,
        val rootResult: RootDetector.RootDetectionResult?,
        val overallSecure: Boolean,
        val securityLevel: SecurityLevel,
        val allThreats: List<String>,
        val recommendations: List<String>,
    )

    /**
     * Overall security level based on all checks.
     */
    enum class SecurityLevel {
        SECURE, // No threats detected
        CAUTION, // Minor issues detected (e.g., unknown installer)
        AT_RISK, // Moderate threats (e.g., test-keys, emulator)
        COMPROMISED, // Serious threats (e.g., root, debugger)
        CRITICAL, // Critical threats (e.g., Frida, Xposed, tampering)
    }

    // Cached results for quick access
    private val lastResult = AtomicReference<ResilienceResult?>(null)
    private val isCompromised = AtomicBoolean(false)
    private val lastCheckTime = AtomicReference<Long>(0L)

    /**
     * Perform all resilience checks asynchronously.
     *
     * @return ResilienceResult with a full security assessment
     */
    suspend fun performAllChecks(): ResilienceResult =
        withContext(Dispatchers.Default) {
            try {
                performAllChecksInternal()
            } catch (t: Throwable) {
                // An unhandled Error (OutOfMemoryError, StackOverflowError, etc.) or
                // unexpected exception escaped all inner checks. Treat the device as
                // compromised because we cannot make any security guarantees.
                Timber.tag(TAG).e(t, "Unhandled throwable during security checks; marking compromised")
                isCompromised.set(true)

                val fallback =
                    ResilienceResult(
                        antiDebugResult = null,
                        integrityResult = null,
                        rootResult = null,
                        overallSecure = false,
                        securityLevel = SecurityLevel.CRITICAL,
                        allThreats = listOf("Security check infrastructure failure"),
                        recommendations = listOf("Device security could not be verified"),
                    )
                lastResult.set(fallback)
                lastCheckTime.set(System.currentTimeMillis())
                fallback
            }
        }

    /**
     * Core implementation of [performAllChecks], separated so that the outer method
     * can wrap it in a catch(Throwable) guard.
     */
    private suspend fun performAllChecksInternal(): ResilienceResult {
        val threats = mutableListOf<String>()
        val recommendations = mutableListOf<String>()

        // Anti-debugging checks
        val antiDebugResult =
            if (config.enableAntiDebug) {
                AntiDebugChecker.performChecks(context).also { result ->
                    threats.addAll(result.detectedThreats)
                    if (result.isDebuggerAttached) {
                        recommendations.add("Debugger detected - disconnect debugger for secure operation")
                    }
                    if (result.hasFridaIndicators) {
                        recommendations.add("Frida detected - remove instrumentation framework")
                    }
                    if (result.hasXposedIndicators) {
                        recommendations.add("Xposed detected - disable Xposed modules")
                    }
                }
            } else {
                null
            }

        // Integrity verification
        val integrityResult =
            if (config.enableTamperDetection) {
                SignatureVerifier.performVerification(context, config.signatureConfig).also { result ->
                    threats.addAll(result.issues)
                    if (!result.signatureValid) {
                        recommendations.add("App signature verification failed - reinstall from trusted source")
                    }
                    if (!result.dexHashValid) {
                        recommendations.add("Code integrity compromised - reinstall the application")
                    }
                    if (!result.installerValid) {
                        recommendations.add("App installed from unknown source - consider reinstalling from official store")
                    }
                }
            } else {
                null
            }

        // Root and emulator detection
        val rootResult =
            if (config.enableRootDetection || config.enableEmulatorDetection) {
                RootDetector.performChecks(context).also { result ->
                    if (config.enableRootDetection) {
                        threats.addAll(result.detectedIndicators.filter { !it.contains("emulator") })
                        if (result.isRooted) {
                            recommendations.add("Device is rooted - sensitive operations may be at risk")
                        }
                    }
                    if (config.enableEmulatorDetection && result.isEmulator) {
                        threats.add("Running on emulator")
                        recommendations.add("Running on emulator - not recommended for production use")
                    }
                }
            } else {
                null
            }

        // Calculate overall security level
        val securityLevel = calculateSecurityLevel(antiDebugResult, integrityResult, rootResult)
        val overallSecure = securityLevel == SecurityLevel.SECURE

        val result =
            ResilienceResult(
                antiDebugResult = antiDebugResult,
                integrityResult = integrityResult,
                rootResult = rootResult,
                overallSecure = overallSecure,
                securityLevel = securityLevel,
                allThreats = threats.distinct(),
                recommendations = recommendations.distinct(),
            )

        // Cache results
        lastResult.set(result)
        lastCheckTime.set(System.currentTimeMillis())
        isCompromised.set(!overallSecure)

        // Log results
        logSecurityAssessment(result)

        // Handle threats based on policy
        handleThreats(result)

        return result
    }

    /**
     * Perform quick checks suitable for frequent polling.
     * Only checks the most critical security indicators.
     *
     * @return true if critical threats detected
     */
    fun performQuickCheck(): Boolean {
        val hasDebugger = if (config.enableAntiDebug) AntiDebugChecker.quickCheck() else false
        val hasRoot = if (config.enableRootDetection) RootDetector.quickCheck() else false

        val isCritical = hasDebugger || hasRoot
        isCompromised.set(isCritical)

        return isCritical
    }

    /**
     * Get the last cached result without performing new checks.
     */
    fun getLastResult(): ResilienceResult? = lastResult.get()

    /**
     * Check if the device is currently considered compromised.
     */
    fun isDeviceCompromised(): Boolean = isCompromised.get()

    /**
     * Check if enough time has passed to warrant a new full check.
     */
    fun shouldPerformFullCheck(): Boolean {
        val elapsed = System.currentTimeMillis() - lastCheckTime.get()
        return elapsed > config.safeCheckIntervalMs
    }

    /**
     * Determine whether credential access should be restricted based on the
     * last check result and the configured threat response policy.
     *
     * Returns true if the security level is COMPROMISED or CRITICAL and the
     * policy is RESTRICT_FEATURES or TERMINATE. MainActivity uses this to
     * gate access to credential screens.
     */
    fun shouldRestrictCredentials(): Boolean {
        val result = lastResult.get() ?: return false
        if (config.threatResponsePolicy == ThreatResponsePolicy.LOG_ONLY ||
            config.threatResponsePolicy == ThreatResponsePolicy.LOG_AND_WARN
        ) {
            return false
        }
        return result.securityLevel == SecurityLevel.COMPROMISED ||
            result.securityLevel == SecurityLevel.CRITICAL
    }

    // Handle to the periodic check coroutine so it can be cancelled
    private var periodicCheckJob: Job? = null

    /**
     * Start periodic security checks on the given coroutine scope.
     * Runs a full check immediately, then repeats at the configured interval.
     * Calls [onThreatDetected] on the Default dispatcher whenever the security
     * level is COMPROMISED or CRITICAL.
     */
    fun startPeriodicChecks(
        scope: CoroutineScope,
        onThreatDetected: (ResilienceResult) -> Unit = {},
    ) {
        periodicCheckJob?.cancel()
        periodicCheckJob =
            scope.launch(Dispatchers.Default) {
                while (isActive) {
                    val result = performAllChecks()
                    if (result.securityLevel == SecurityLevel.COMPROMISED ||
                        result.securityLevel == SecurityLevel.CRITICAL
                    ) {
                        withContext(Dispatchers.Main) {
                            onThreatDetected(result)
                        }
                    }
                    delay(config.safeCheckIntervalMs)
                }
            }
    }

    /**
     * Stop periodic security checks.
     */
    fun stopPeriodicChecks() {
        periodicCheckJob?.cancel()
        periodicCheckJob = null
    }

    /**
     * Calculate overall security level from individual check results.
     */
    @VisibleForTesting
    internal fun calculateSecurityLevel(
        antiDebug: AntiDebugChecker.AntiDebugResult?,
        integrity: SignatureVerifier.IntegrityResult?,
        root: RootDetector.RootDetectionResult?,
    ): SecurityLevel {
        // Mass-failure detection: if more than massFailureThreshold of checks on either
        // checker threw exceptions, an attacker may be using seccomp filtering or blanket
        // hooking to suppress all detection. Return CRITICAL immediately.
        val antiDebugTally = antiDebug?.exceptionTally
        val rootTally = root?.exceptionTally
        if (antiDebugTally != null && antiDebugTally.totalChecks > 0 &&
            (antiDebugTally.exceptionCount.toFloat() / antiDebugTally.totalChecks.toFloat()) > config.massFailureThreshold
        ) {
            Timber.tag(TAG).e(
                "Mass exception in anti-debug checks: %d/%d exceeded %.0f%% threshold",
                antiDebugTally.exceptionCount,
                antiDebugTally.totalChecks,
                config.massFailureThreshold * 100,
            )
            return SecurityLevel.CRITICAL
        }
        if (rootTally != null && rootTally.totalChecks > 0 &&
            (rootTally.exceptionCount.toFloat() / rootTally.totalChecks.toFloat()) > config.massFailureThreshold
        ) {
            Timber.tag(TAG).e(
                "Mass exception in root detection checks: %d/%d exceeded %.0f%% threshold",
                rootTally.exceptionCount,
                rootTally.totalChecks,
                config.massFailureThreshold * 100,
            )
            return SecurityLevel.CRITICAL
        }

        // Critical: Frida, Xposed, or tampering
        if (antiDebug?.hasFridaIndicators == true ||
            antiDebug?.hasXposedIndicators == true ||
            integrity?.isTampered == true
        ) {
            return SecurityLevel.CRITICAL
        }

        // Compromised: Debugger attached, rooted, or code modified
        if (antiDebug?.isDebuggerAttached == true ||
            antiDebug?.hasTracerPid == true ||
            root?.isRooted == true ||
            integrity?.signatureValid == false
        ) {
            return SecurityLevel.COMPROMISED
        }

        // At Risk: Emulator, test-keys, or dangerous props
        if (root?.isEmulator == true ||
            root?.hasTestKeys == true ||
            root?.hasDangerousProps == true ||
            antiDebug?.isDebuggable == true
        ) {
            return SecurityLevel.AT_RISK
        }

        // Caution: Unknown installer
        if (integrity?.installerValid == false) {
            return SecurityLevel.CAUTION
        }

        return SecurityLevel.SECURE
    }

    /**
     * Log security assessment results.
     */
    private fun logSecurityAssessment(result: ResilienceResult) {
        when (result.securityLevel) {
            SecurityLevel.SECURE -> {
                Timber.tag(TAG).d("Security assessment: SECURE")
            }
            SecurityLevel.CAUTION -> {
                Timber.tag(TAG).i("Security assessment: CAUTION - ${result.allThreats.size} minor issues")
            }
            SecurityLevel.AT_RISK -> {
                Timber.tag(TAG).w("Security assessment: AT_RISK - ${result.allThreats}")
            }
            SecurityLevel.COMPROMISED -> {
                Timber.tag(TAG).e("Security assessment: COMPROMISED - ${result.allThreats}")
            }
            SecurityLevel.CRITICAL -> {
                Timber.tag(TAG).e("Security assessment: CRITICAL - ${result.allThreats}")
            }
        }
    }

    /**
     * Handle detected threats based on configured policy.
     *
     * For RESTRICT_FEATURES and TERMINATE policies, the isCompromised flag is
     * set to true when the security level is HIGH or above, so that callers
     * such as MainActivity can gate credential access without re-running checks.
     */
    private fun handleThreats(result: ResilienceResult) {
        if (result.overallSecure) return

        when (config.threatResponsePolicy) {
            ThreatResponsePolicy.LOG_ONLY -> {
                // Already logged in logSecurityAssessment
            }
            ThreatResponsePolicy.LOG_AND_WARN -> {
                // Application should display warning to user
                Timber.tag(TAG).w("Security threats detected. Recommendations: ${result.recommendations}")
            }
            ThreatResponsePolicy.RESTRICT_FEATURES -> {
                // Application should disable sensitive features when COMPROMISED or CRITICAL
                if (result.securityLevel == SecurityLevel.COMPROMISED ||
                    result.securityLevel == SecurityLevel.CRITICAL
                ) {
                    isCompromised.set(true)
                    Timber.tag(TAG).w(
                        "RESTRICT_FEATURES: credential access restricted (level=${result.securityLevel})",
                    )
                } else {
                    Timber.tag(TAG).w("Security threats detected but below restriction threshold")
                }
            }
            ThreatResponsePolicy.TERMINATE -> {
                if (result.securityLevel == SecurityLevel.CRITICAL) {
                    isCompromised.set(true)
                    Timber.tag(TAG).e("Critical security threat detected. Terminating application.")
                    // Match iOS behaviour and actually terminate the process
                    // when the TERMINATE policy is configured and a CRITICAL threat is
                    // detected. Without this, the policy name is misleading and callers
                    // relying on TERMINATE semantics get silent degradation instead.
                    android.os.Process.killProcess(android.os.Process.myPid())
                    kotlin.system.exitProcess(1)
                }
            }
        }
    }

    /**
     * Builder for creating ResilienceChecker with custom configuration.
     */
    class Builder(private val context: Context) {
        private var enableAntiDebug = true
        private var enableTamperDetection = true
        private var enableRootDetection = true
        private var enableEmulatorDetection = true
        private var signatureConfig = SignatureVerifier.VerificationConfig()
        private var threatResponsePolicy = ThreatResponsePolicy.RESTRICT_FEATURES
        private var checkIntervalMs = 30_000L
        private var massFailureThreshold = 0.6f

        fun setAntiDebugEnabled(enabled: Boolean) = apply { enableAntiDebug = enabled }

        fun setTamperDetectionEnabled(enabled: Boolean) = apply { enableTamperDetection = enabled }

        fun setRootDetectionEnabled(enabled: Boolean) = apply { enableRootDetection = enabled }

        fun setEmulatorDetectionEnabled(enabled: Boolean) = apply { enableEmulatorDetection = enabled }

        fun setSignatureConfig(config: SignatureVerifier.VerificationConfig) = apply { signatureConfig = config }

        fun setThreatResponsePolicy(policy: ThreatResponsePolicy) = apply { threatResponsePolicy = policy }

        fun setCheckInterval(intervalMs: Long) =
            apply {
                checkIntervalMs = maxOf(intervalMs, ResilienceConfig.MIN_CHECK_INTERVAL_MS)
            }

        fun setMassFailureThreshold(threshold: Float) = apply { massFailureThreshold = threshold }

        fun build(): ResilienceChecker {
            val config =
                ResilienceConfig(
                    enableAntiDebug = enableAntiDebug,
                    enableTamperDetection = enableTamperDetection,
                    enableRootDetection = enableRootDetection,
                    enableEmulatorDetection = enableEmulatorDetection,
                    signatureConfig = signatureConfig,
                    threatResponsePolicy = threatResponsePolicy,
                    checkIntervalMs = checkIntervalMs,
                    massFailureThreshold = massFailureThreshold,
                )
            return getInstance(context, config)
        }
    }
}
