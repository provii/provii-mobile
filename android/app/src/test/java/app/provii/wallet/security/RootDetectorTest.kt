package app.provii.wallet.security

import app.provii.wallet.security.integrity.RootDetector
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for RootDetector
 *
 * Note: These tests validate the logic and data structures.
 * Full integration testing requires an Android device/emulator.
 */
class RootDetectorTest {
    @Test
    fun `RootDetectionResult isRooted returns true when su binary found`() {
        val result =
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

        assertTrue("Should be rooted when su binary is found", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isRooted returns true when root management app installed`() {
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = true,
                hasTestKeys = false,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("Root management app installed"),
            )

        assertTrue("Should be rooted when root management app is installed", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isRooted returns true when Magisk detected`() {
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = false,
                hasTestKeys = false,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = true,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("Magisk indicators detected"),
            )

        assertTrue("Should be rooted when Magisk is detected", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isRooted returns true when dangerous props found`() {
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = false,
                hasTestKeys = false,
                hasDangerousProps = true,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("Dangerous system properties"),
            )

        assertTrue("Should be rooted when dangerous props are found", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isRooted returns true when test-keys and rw system`() {
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = false,
                hasTestKeys = true,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = true,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("Test-keys detected", "System partition writable"),
            )

        assertTrue("Should be rooted when test-keys and rw system", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isRooted returns false when only test-keys`() {
        // Test-keys alone (without rw system) is not definitive root indicator
        val result =
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

        assertFalse("Should not be rooted with only test-keys", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isRooted returns false when no indicators`() {
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
            )

        assertFalse("Should not be rooted when no indicators", result.isRooted)
    }

    @Test
    fun `RootDetectionResult isCompromisedEnvironment includes emulator`() {
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
                isEmulator = true,
                detectedIndicators = listOf("Running on emulator"),
            )

        assertFalse("Should not be rooted on emulator alone", result.isRooted)
        assertTrue("Should be compromised environment on emulator", result.isCompromisedEnvironment)
    }

    @Test
    fun `ConfidenceLevel is DEFINITE when su and root app found`() {
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = true,
                hasRootManagementApps = true,
                hasTestKeys = false,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("su binary found", "Root app installed"),
            )

        assertEquals(
            "Should have DEFINITE confidence when su and root app found",
            RootDetector.ConfidenceLevel.DEFINITE,
            result.confidenceLevel,
        )
    }

    @Test
    fun `ConfidenceLevel is HIGH when su found alone`() {
        val result =
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

        assertEquals(
            "Should have HIGH confidence when su found alone",
            RootDetector.ConfidenceLevel.HIGH,
            result.confidenceLevel,
        )
    }

    @Test
    fun `ConfidenceLevel is MEDIUM when root app found alone`() {
        val result =
            RootDetector.RootDetectionResult(
                hasSuBinary = false,
                hasRootManagementApps = true,
                hasTestKeys = false,
                hasDangerousProps = false,
                hasBusyBox = false,
                hasRwSystem = false,
                hasMagiskIndicators = false,
                hasMagiskHideIndicators = false,
                hasNativeLayerIndicators = false,
                seLinuxEnforcing = true,
                isEmulator = false,
                detectedIndicators = listOf("Root app installed"),
            )

        assertEquals(
            "Should have MEDIUM confidence when root app found alone",
            RootDetector.ConfidenceLevel.MEDIUM,
            result.confidenceLevel,
        )
    }

    @Test
    fun `ConfidenceLevel is LOW when only test-keys`() {
        val result =
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

        assertEquals(
            "Should have LOW confidence when only test-keys",
            RootDetector.ConfidenceLevel.LOW,
            result.confidenceLevel,
        )
    }

    @Test
    fun `ConfidenceLevel is NONE when no indicators`() {
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
            )

        assertEquals(
            "Should have NONE confidence when no indicators",
            RootDetector.ConfidenceLevel.NONE,
            result.confidenceLevel,
        )
    }

    @Test
    fun `ConfidenceLevel enum values are correctly ordered`() {
        val levels = RootDetector.ConfidenceLevel.values()

        assertEquals("NONE should be first", RootDetector.ConfidenceLevel.NONE, levels[0])
        assertEquals("LOW should be second", RootDetector.ConfidenceLevel.LOW, levels[1])
        assertEquals("MEDIUM should be third", RootDetector.ConfidenceLevel.MEDIUM, levels[2])
        assertEquals("HIGH should be fourth", RootDetector.ConfidenceLevel.HIGH, levels[3])
        assertEquals("DEFINITE should be fifth", RootDetector.ConfidenceLevel.DEFINITE, levels[4])
    }

    // -------------------------------------------------------------------------
    // Emulator weighted-scoring tests
    // These tests exercise RootDetector.scoreEmulatorBuildProperties() directly
    // so that no Android framework mocking is required.
    // -------------------------------------------------------------------------

    private fun score(
        fingerprint: String = "samsung/dreamlte/dreamlte:9/PPR1.180610.011/G950FXXS5DSE1:user/release-keys",
        model: String = "SM-G950F",
        manufacturer: String = "samsung",
        brand: String = "samsung",
        device: String = "dreamlte",
        product: String = "dreamltexx",
        hardware: String = "samsungexynos8895",
        board: String = "universal8895",
    ): Int =
        RootDetector.scoreEmulatorBuildProperties(
            fingerprint = fingerprint,
            model = model,
            manufacturer = manufacturer,
            brand = brand,
            device = device,
            product = product,
            hardware = hardware,
            board = board,
        )

    @Test
    fun `score for standard Android emulator (goldfish hardware) is at least 8`() {
        // Typical AVD: hardware=goldfish, model=sdk_gphone64_x86_64, product=sdk_gphone64_x86_64
        val result =
            score(
                fingerprint = "google/sdk_gphone64_x86_64/generic_x86_64:14/UPB5.230623.003/10808477:userdebug/test-keys",
                model = "sdk_gphone64_x86_64",
                manufacturer = "Google",
                brand = "google",
                device = "generic_x86_64",
                product = "sdk_gphone64_x86_64",
                hardware = "goldfish",
                board = "goldfish_x86_64",
            )
        assertTrue("Standard AVD should score >= 8, got $result", result >= 8)
    }

    @Test
    fun `score for Genymotion emulator is at least 8`() {
        val result =
            score(
                fingerprint = "generic/vbox86p/vbox86p:6.0/MRA58K/494667:userdebug/test-keys",
                model = "vbox86p",
                manufacturer = "Genymotion",
                brand = "generic",
                device = "vbox86p",
                product = "vbox86p",
                hardware = "vbox86",
                board = "unknown",
            )
        assertTrue("Genymotion emulator should score >= 8, got $result", result >= 8)
    }

    @Test
    fun `score for budget OEM device with only unknown manufacturer is below threshold`() {
        // A device where only manufacturer="unknown" fires. Just 2 pts, not an emulator
        val result =
            score(
                fingerprint = "Walton/WF4U_PRO/WF4U_PRO:10/QP1A.190711.020/1590456000:user/release-keys",
                model = "WF4U PRO",
                manufacturer = "unknown",
                brand = "Walton",
                device = "WF4U_PRO",
                product = "WF4U_PRO",
                hardware = "mt6765",
                board = "mt6765",
            )
        assertEquals("Budget device with only manufacturer=unknown should score 2", 2, result)
        assertTrue("Budget device with only manufacturer=unknown should NOT be flagged", result < 8)
    }

    @Test
    fun `score for GSI build with all three generic signals is capped and below threshold`() {
        // AOSP reference image flashed to a Pixel: fingerprint contains "generic", device="generic",
        // brand="generic". No goldfish, ranchu, vbox, or SDK model marker fires.
        // genericScore = 4 + 4 + 5 = 13 pts, capped to 5 because hasDefinitiveSignal is false.
        val pureGsi =
            score(
                fingerprint = "generic/aosp_taimen/generic:10/QP1A.191005.007.A3/5972272:user/release-keys",
                model = "Pixel 2 XL",
                manufacturer = "Google",
                brand = "generic",
                device = "generic",
                product = "aosp_taimen",
                hardware = "walleye",
                board = "walleye",
            )
        assertEquals("GSI with all three generic signals should score 5 (capped)", 5, pureGsi)
        assertTrue("GSI build should NOT be flagged as emulator", pureGsi < 8)
    }

    @Test
    fun `score for clean real device is zero`() {
        // No emulator indicators at all, should score 0
        val result = score()
        assertEquals("Clean real device should score 0", 0, result)
    }

    @Test
    fun `score for Amazon Fire tablet is below threshold`() {
        // Fire tablets report brand="Amazon", hardware varies but no goldfish/ranchu/sdk markers
        val result =
            score(
                fingerprint = "Amazon/mustang/mustang:9/PS7233/71215120112:user/release-keys",
                model = "KFMAWI",
                manufacturer = "Amazon",
                brand = "Amazon",
                device = "mustang",
                product = "mustang",
                hardware = "mt8163",
                board = "mt8163",
            )
        assertTrue("Amazon Fire tablet should NOT be flagged as emulator, score=$result", result < 8)
    }
}
