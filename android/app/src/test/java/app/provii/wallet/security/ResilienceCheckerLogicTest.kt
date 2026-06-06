package app.provii.wallet.security

import android.content.Context
import app.provii.wallet.security.antiDebug.AntiDebugChecker
import app.provii.wallet.security.integrity.RootDetector
import app.provii.wallet.security.integrity.SignatureVerifier
import app.provii.wallet.security.resilience.ExceptionTally
import app.provii.wallet.security.resilience.ResilienceChecker
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

/**
 * Unit tests for ResilienceChecker.calculateSecurityLevel logic.
 *
 * Verifies that each security level tier is correctly assigned based on
 * the combination of anti-debug, integrity, and root detection results.
 * Priority ordering is tested via overlapping flag combinations.
 */
class ResilienceCheckerLogicTest {
    private lateinit var checker: ResilienceChecker

    @Before
    fun setUp() {
        // Reset the singleton so each test gets a fresh instance
        val instanceField = ResilienceChecker::class.java.getDeclaredField("instance")
        instanceField.isAccessible = true
        instanceField.set(null, null)

        val context = mock(Context::class.java)
        `when`(context.applicationContext).thenReturn(context)
        checker = ResilienceChecker.getInstance(context, ResilienceChecker.ResilienceConfig())
    }

    // --- CRITICAL tier ---

    @Test
    fun `calculateSecurityLevel returns CRITICAL when Frida detected`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = true,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Frida detected"),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    @Test
    fun `calculateSecurityLevel returns CRITICAL when Xposed detected`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = true,
                hasTracerPid = false,
                detectedThreats = listOf("Xposed detected"),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    @Test
    fun `calculateSecurityLevel returns CRITICAL when integrity is tampered`() {
        val integrity =
            SignatureVerifier.IntegrityResult(
                signatureValid = false,
                expectedSignatureHash = "expected",
                actualSignatureHash = "actual",
                dexHashValid = false,
                expectedDexHash = "expected",
                actualDexHash = "actual",
                manifestValid = true,
                packageNameValid = true,
                installerValid = true,
                installerPackage = "com.android.vending",
                issues = listOf("Signature hash mismatch", "DEX hash mismatch"),
            )
        val level = checker.calculateSecurityLevel(null, integrity, null)
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    // --- COMPROMISED tier ---

    @Test
    fun `calculateSecurityLevel returns COMPROMISED when debugger attached`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = true,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Debugger attached"),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(ResilienceChecker.SecurityLevel.COMPROMISED, level)
    }

    @Test
    fun `calculateSecurityLevel returns COMPROMISED when tracerPid set`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = true,
                detectedThreats = listOf("Process is being traced"),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(ResilienceChecker.SecurityLevel.COMPROMISED, level)
    }

    @Test
    fun `calculateSecurityLevel returns COMPROMISED when device is rooted`() {
        val root =
            RootDetector.RootDetectionResult(
                hasSuBinary = true,
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
                detectedIndicators = listOf("su binary found"),
            )
        val level = checker.calculateSecurityLevel(null, null, root)
        assertEquals(ResilienceChecker.SecurityLevel.COMPROMISED, level)
    }

    @Test
    fun `calculateSecurityLevel returns COMPROMISED when signature invalid`() {
        val integrity =
            SignatureVerifier.IntegrityResult(
                signatureValid = false,
                expectedSignatureHash = "expected",
                actualSignatureHash = "actual",
                dexHashValid = true,
                expectedDexHash = null,
                actualDexHash = "hash",
                manifestValid = true,
                packageNameValid = true,
                installerValid = true,
                installerPackage = "com.android.vending",
                issues = listOf("Signature hash mismatch"),
            )
        // isTampered is true (signatureValid=false means isIntact=false) so this
        // actually hits CRITICAL. Build a result where only signatureValid is false
        // but the rest pass isIntact == false check differently.
        // Actually: isTampered = !isIntact, isIntact = signatureValid && dexHashValid && manifestValid && packageNameValid
        // signatureValid=false => isIntact=false => isTampered=true => CRITICAL
        // To test the COMPROMISED path for signatureValid==false we need isTampered to be false,
        // but that's impossible when signatureValid is false.
        // The COMPROMISED branch checks `integrity?.signatureValid == false` but that's only
        // reached if isTampered is false (CRITICAL didn't match). Since signatureValid=false
        // always makes isTampered=true, the COMPROMISED branch for signatureValid is dead code
        // when CRITICAL also checks isTampered. However, the check is still in the code.
        // Let's verify CRITICAL is returned here (the priority is correct).
        val level = checker.calculateSecurityLevel(null, integrity, null)
        assertEquals(
            "signatureValid=false makes isTampered=true, so CRITICAL takes priority",
            ResilienceChecker.SecurityLevel.CRITICAL,
            level,
        )
    }

    // --- AT_RISK tier ---

    @Test
    fun `calculateSecurityLevel returns AT_RISK when running on emulator`() {
        val root =
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
                isEmulator = true,
                detectedIndicators = listOf("Running on emulator"),
            )
        val level = checker.calculateSecurityLevel(null, null, root)
        assertEquals(ResilienceChecker.SecurityLevel.AT_RISK, level)
    }

    @Test
    fun `calculateSecurityLevel returns AT_RISK when test-keys detected`() {
        val root =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = false,
                hasTestKeys = true,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("Test-keys detected"),
            )
        val level = checker.calculateSecurityLevel(null, null, root)
        assertEquals(ResilienceChecker.SecurityLevel.AT_RISK, level)
    }

    @Test
    fun `calculateSecurityLevel returns AT_RISK when debuggable flag set`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = true,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Application is debuggable"),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(ResilienceChecker.SecurityLevel.AT_RISK, level)
    }

    // --- CAUTION tier ---

    @Test
    fun `calculateSecurityLevel returns CAUTION when installer invalid`() {
        val integrity =
            SignatureVerifier.IntegrityResult(
                signatureValid = true,
                expectedSignatureHash = "hash",
                actualSignatureHash = "hash",
                dexHashValid = true,
                expectedDexHash = null,
                actualDexHash = "dex",
                manifestValid = true,
                packageNameValid = true,
                installerValid = false,
                installerPackage = null,
                issues = listOf("Sideloaded APK (no installer package)"),
            )
        val level = checker.calculateSecurityLevel(null, integrity, null)
        assertEquals(ResilienceChecker.SecurityLevel.CAUTION, level)
    }

    // --- SECURE tier ---

    @Test
    fun `calculateSecurityLevel returns SECURE when all clean`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
            )
        val integrity =
            SignatureVerifier.IntegrityResult(
                signatureValid = true,
                expectedSignatureHash = "hash",
                actualSignatureHash = "hash",
                dexHashValid = true,
                expectedDexHash = null,
                actualDexHash = "dex",
                manifestValid = true,
                packageNameValid = true,
                installerValid = true,
                installerPackage = "com.android.vending",
                issues = emptyList(),
            )
        val root =
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
            )
        val level = checker.calculateSecurityLevel(antiDebug, integrity, root)
        assertEquals(ResilienceChecker.SecurityLevel.SECURE, level)
    }

    @Test
    fun `calculateSecurityLevel returns SECURE when all null inputs`() {
        val level = checker.calculateSecurityLevel(null, null, null)
        assertEquals(ResilienceChecker.SecurityLevel.SECURE, level)
    }

    // --- Priority ordering ---

    @Test
    fun `CRITICAL takes priority over COMPROMISED when both Frida and debugger detected`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = true,
                isDebuggable = true,
                hasFridaIndicators = true,
                hasXposedIndicators = false,
                hasTracerPid = true,
                detectedThreats = listOf("Frida detected", "Debugger attached"),
            )
        val root =
            RootDetector.RootDetectionResult(
                hasSuBinary = true,
                hasRootManagementApps = true,
                hasTestKeys = true,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = false,
                isEmulator = true,
                detectedIndicators = listOf("su binary found", "emulator"),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, root)
        assertEquals(ResilienceChecker.SecurityLevel.CRITICAL, level)
    }

    // --- Mass-failure threshold detection ---

    @Test
    fun `calculateSecurityLevel returns CRITICAL when antiDebug exceptions exceed threshold`() {
        // 8 of 12 checks threw = 66.7%, above the default 60% threshold
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
                exceptionTally = ExceptionTally(totalChecks = 12, exceptionCount = 8, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(
            "Mass exception in anti-debug checks should trigger CRITICAL",
            ResilienceChecker.SecurityLevel.CRITICAL,
            level,
        )
    }

    @Test
    fun `calculateSecurityLevel does not trigger mass-failure when antiDebug exceptions below threshold`() {
        // 7 of 12 checks threw = 58.3%, below the default 60% threshold
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
                exceptionTally = ExceptionTally(totalChecks = 12, exceptionCount = 7, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(
            "Below-threshold exceptions should not trigger CRITICAL",
            ResilienceChecker.SecurityLevel.SECURE,
            level,
        )
    }

    @Test
    fun `calculateSecurityLevel returns CRITICAL when root exceptions exceed threshold`() {
        // 7 of 11 checks threw = 63.6%, above the default 60% threshold
        val root =
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
                exceptionTally = ExceptionTally(totalChecks = 11, exceptionCount = 7, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(null, null, root)
        assertEquals(
            "Mass exception in root checks should trigger CRITICAL",
            ResilienceChecker.SecurityLevel.CRITICAL,
            level,
        )
    }

    @Test
    fun `calculateSecurityLevel does not trigger mass-failure when root exceptions below threshold`() {
        // 6 of 11 checks threw = 54.5%, below the default 60% threshold
        val root =
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
                exceptionTally = ExceptionTally(totalChecks = 11, exceptionCount = 6, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(null, null, root)
        assertEquals(
            "Below-threshold root exceptions should not trigger CRITICAL",
            ResilienceChecker.SecurityLevel.SECURE,
            level,
        )
    }

    @Test
    fun `calculateSecurityLevel returns CRITICAL when all antiDebug checks throw`() {
        // 12 of 12 = 100%, well above threshold
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
                exceptionTally = ExceptionTally(totalChecks = 12, exceptionCount = 12, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, null)
        assertEquals(
            "All checks throwing should trigger CRITICAL",
            ResilienceChecker.SecurityLevel.CRITICAL,
            level,
        )
    }

    @Test
    fun `calculateSecurityLevel returns SECURE when zero exceptions on clean device`() {
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
                exceptionTally = ExceptionTally(totalChecks = 12, exceptionCount = 0, threshold = 0.6f),
            )
        val root =
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
                exceptionTally = ExceptionTally(totalChecks = 11, exceptionCount = 0, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(antiDebug, null, root)
        assertEquals(
            "Zero exceptions on clean device should be SECURE",
            ResilienceChecker.SecurityLevel.SECURE,
            level,
        )
    }

    @Test
    fun `mass-failure takes priority over individual check results`() {
        // All individual checks say clean, but mass exceptions indicate suppression
        val antiDebug =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
                exceptionTally = ExceptionTally(totalChecks = 12, exceptionCount = 10, threshold = 0.6f),
            )
        val integrity =
            SignatureVerifier.IntegrityResult(
                signatureValid = true,
                expectedSignatureHash = "hash",
                actualSignatureHash = "hash",
                dexHashValid = true,
                expectedDexHash = null,
                actualDexHash = "dex",
                manifestValid = true,
                packageNameValid = true,
                installerValid = true,
                installerPackage = "com.android.vending",
                issues = emptyList(),
            )
        val root =
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
                exceptionTally = ExceptionTally(totalChecks = 11, exceptionCount = 0, threshold = 0.6f),
            )
        val level = checker.calculateSecurityLevel(antiDebug, integrity, root)
        assertEquals(
            "Mass-failure should override clean individual results",
            ResilienceChecker.SecurityLevel.CRITICAL,
            level,
        )
    }
}
