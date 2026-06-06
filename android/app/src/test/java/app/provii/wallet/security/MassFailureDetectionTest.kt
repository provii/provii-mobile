package app.provii.wallet.security

import android.content.Context
import app.provii.wallet.security.antiDebug.AntiDebugChecker
import app.provii.wallet.security.integrity.RootDetector
import app.provii.wallet.security.resilience.ExceptionTally
import app.provii.wallet.security.resilience.ResilienceChecker
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

/**
 * Tests for the mass-failure detection mechanism added by .
 *
 * An attacker using seccomp filtering or blanket hooking can cause all (or most) security
 * checks to throw exceptions, making the device appear clean. The mass-failure threshold
 * detects this by flagging when the exception ratio exceeds a configurable limit.
 *
 * These tests cover the specific scenarios required by the adversarial conditions:
 * 7/12 AntiDebug (below threshold), 8/12 (above), 6/11 Root (below), 7/11 (above),
 * all-exception, and clean device.
 */
class MassFailureDetectionTest {
    private lateinit var checker: ResilienceChecker

    @Before
    fun setUp() {
        val instanceField = ResilienceChecker::class.java.getDeclaredField("instance")
        instanceField.isAccessible = true
        instanceField.set(null, null)

        val context = mock(Context::class.java)
        `when`(context.applicationContext).thenReturn(context)
        checker = ResilienceChecker.getInstance(context, ResilienceChecker.ResilienceConfig())
    }

    // --- Helper factories ---

    private fun cleanAntiDebug(
        exceptionCount: Int = 0,
        totalChecks: Int = 12,
    ) =
        AntiDebugChecker.AntiDebugResult(
            isDebuggerAttached = false,
            isDebuggable = false,
            hasFridaIndicators = false,
            hasXposedIndicators = false,
            hasTracerPid = false,
            detectedThreats = emptyList(),
            exceptionTally =
                ExceptionTally(
                    totalChecks = totalChecks,
                    exceptionCount = exceptionCount,
                    threshold = 0.6f,
                ),
        )

    private fun cleanRoot(
        exceptionCount: Int = 0,
        totalChecks: Int = 11,
    ) =
        RootDetector.RootDetectionResult(
            hasSuBinary = false,
            hasRootManagementApps = false,
            hasTestKeys = false,
            hasDangerousProps = false,
            hasBusyBox = false,
            hasRwSystem = false,
            hasMagiskIndicators = false,
            hasMagiskHideIndicators = false,
            hasNativeLayerIndicators = false,
            seLinuxEnforcing = true,
            isEmulator = false,
            detectedIndicators = emptyList(),
            exceptionTally =
                ExceptionTally(
                    totalChecks = totalChecks,
                    exceptionCount = exceptionCount,
                    threshold = 0.6f,
                ),
        )

    // --- AntiDebug threshold boundary ---

    @Test
    fun `antiDebug 7 of 12 exceptions is below threshold and returns SECURE`() {
        // 7/12 = 58.3% which is <= 60%
        val level = checker.calculateSecurityLevel(cleanAntiDebug(exceptionCount = 7), null, null)
        assertEquals(ResilienceChecker.SecurityLevel.SECURE, level)
    }

    @Test
    fun `antiDebug 8 of 12 exceptions is above threshold and returns CRITICAL`() {
        // 8/12 = 66.7% which is > 60%
        val level = checker.calculateSecurityLevel(cleanAntiDebug(exceptionCount = 8), null, null)
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    // --- Root threshold boundary ---

    @Test
    fun `root 6 of 11 exceptions is below threshold and returns SECURE`() {
        // 6/11 = 54.5% which is <= 60%
        val level = checker.calculateSecurityLevel(null, null, cleanRoot(exceptionCount = 6))
        assertEquals(ResilienceChecker.SecurityLevel.SECURE, level)
    }

    @Test
    fun `root 7 of 11 exceptions is above threshold and returns CRITICAL`() {
        // 7/11 = 63.6% which is > 60%
        val level = checker.calculateSecurityLevel(null, null, cleanRoot(exceptionCount = 7))
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    // --- All-exception scenario ---

    @Test
    fun `all antiDebug checks throwing returns CRITICAL`() {
        val level = checker.calculateSecurityLevel(cleanAntiDebug(exceptionCount = 12), null, null)
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    @Test
    fun `all root checks throwing returns CRITICAL`() {
        val level = checker.calculateSecurityLevel(null, null, cleanRoot(exceptionCount = 11))
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    @Test
    fun `both checkers all-exception returns CRITICAL`() {
        val level =
            checker.calculateSecurityLevel(
                cleanAntiDebug(exceptionCount = 12),
                null,
                cleanRoot(exceptionCount = 11),
            )
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    // --- Clean device ---

    @Test
    fun `zero exceptions on both checkers returns SECURE`() {
        val level =
            checker.calculateSecurityLevel(
                cleanAntiDebug(exceptionCount = 0),
                null,
                cleanRoot(exceptionCount = 0),
            )
        assertEquals(ResilienceChecker.SecurityLevel.SECURE, level)
    }

    // --- Edge: antiDebug above threshold but root below, still CRITICAL ---

    @Test
    fun `antiDebug above threshold triggers CRITICAL even when root is clean`() {
        val level =
            checker.calculateSecurityLevel(
                cleanAntiDebug(exceptionCount = 9),
                null,
                cleanRoot(exceptionCount = 0),
            )
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    @Test
    fun `root above threshold triggers CRITICAL even when antiDebug is clean`() {
        val level =
            checker.calculateSecurityLevel(
                cleanAntiDebug(exceptionCount = 0),
                null,
                cleanRoot(exceptionCount = 8),
            )
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    // --- ExceptionTally on data classes ---

    @Test
    fun `AntiDebugResult carries exceptionTally through`() {
        val tally = ExceptionTally(totalChecks = 12, exceptionCount = 5, threshold = 0.6f)
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
                exceptionTally = tally,
            )
        assertEquals(12, result.exceptionTally.totalChecks)
        assertEquals(5, result.exceptionTally.exceptionCount)
        assertFalse(result.exceptionTally.exceedsThreshold)
    }

    @Test
    fun `RootDetectionResult carries exceptionTally through`() {
        val tally = ExceptionTally(totalChecks = 11, exceptionCount = 8, threshold = 0.6f)
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = false,
                hasTestKeys = false,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = emptyList(),
                exceptionTally = tally,
            )
        assertEquals(11, result.exceptionTally.totalChecks)
        assertEquals(8, result.exceptionTally.exceptionCount)
        assertTrue(result.exceptionTally.exceedsThreshold)
    }
}
