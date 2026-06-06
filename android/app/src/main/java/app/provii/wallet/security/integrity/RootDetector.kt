// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security.integrity

import android.content.Context
import android.os.Build
import app.provii.wallet.security.resilience.ExceptionTally
import app.provii.wallet.security.resilience.ExceptionTallyBuilder
import timber.log.Timber
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * MASVS-RESILIENCE-3: Local-only root and emulator detection. Scans for su binaries, root
 * management apps (Magisk, SuperSU, KingRoot), Magisk Hide/Zygisk/Shamiko root-hiding
 * mechanisms, dangerous system properties, BusyBox, SELinux state, and emulator indicators.
 * No Google APIs or network calls are made, so this works on F-Droid builds and devices
 * without Google services.
 *
 * Exception tallying: each of the 11 top-level checks is wrapped via
 * [ExceptionTallyBuilder.runCheck] so that the resilience orchestrator can detect
 * mass exception events indicative of seccomp filtering or blanket hooking.
 */
object RootDetector {
    private const val TAG = "RootDetector"

    /**
     * Runs a shell command with a bounded wait. Returns the first line of stdout on success,
     * or null if the process does not finish within [timeoutSeconds] seconds or produces no
     * output. The correct ordering is:
     *   1. start process
     *   2. waitFor(timeout): if it times out, destroyForcibly and return null
     *   3. only then read stdout (pipe buffer is sufficient for single-line commands)
     *
     * This ordering is important: readLine() on the input stream blocks until the process
     * writes output or closes the pipe. Calling readLine() before waitFor() means a hung
     * process blocks the read forever, making the timeout unreachable.
     *
     * Requires API 26+ (Process.waitFor(long, TimeUnit) and destroyForcibly()).
     * Project minSdk = 29, so both are safe to call unconditionally.
     */
    private fun execWithTimeout(
        command: Array<String>,
        timeoutSeconds: Long = 5L,
    ): String? {
        val process = Runtime.getRuntime().exec(command)
        val completed = process.waitFor(timeoutSeconds, TimeUnit.SECONDS)
        if (!completed) {
            process.destroyForcibly()
            Timber.tag(TAG).w("execWithTimeout: timed out after ${timeoutSeconds}s for ${command.joinToString(" ")}")
            return null
        }
        return BufferedReader(InputStreamReader(process.inputStream)).use { it.readLine() }
    }

    /**
     * Minimum weighted score required to classify a device as an emulator.
     * Genuine emulators score 20-40+. Budget OEM devices with a single weak
     * signal (e.g. manufacturer="unknown") score well below this threshold.
     */
    private const val EMULATOR_SCORE_THRESHOLD = 8

    /**
     * Result of root detection with per-check detail and an overall confidence level.
     */
    data class RootDetectionResult(
        val hasSuBinary: Boolean,
        val hasRootManagementApps: Boolean,
        val hasTestKeys: Boolean,
        val hasDangerousProps: Boolean,
        val hasBusyBox: Boolean,
        val hasRwSystem: Boolean,
        val hasMagiskIndicators: Boolean,
        val hasMagiskHideIndicators: Boolean,
        val hasNativeLayerIndicators: Boolean,
        val seLinuxEnforcing: Boolean,
        val isEmulator: Boolean,
        val detectedIndicators: List<String>,
        val exceptionTally: ExceptionTally = ExceptionTally(totalChecks = 0, exceptionCount = 0, threshold = 0.6f),
    ) {
        val isRooted: Boolean
            get() =
                hasSuBinary || hasRootManagementApps || hasMagiskIndicators ||
                    hasMagiskHideIndicators || hasNativeLayerIndicators ||
                    hasDangerousProps || (hasTestKeys && hasRwSystem)

        val isCompromisedEnvironment: Boolean
            get() = isRooted || isEmulator

        val confidenceLevel: ConfidenceLevel
            get() =
                when {
                    hasSuBinary && hasRootManagementApps -> ConfidenceLevel.DEFINITE
                    hasSuBinary || hasMagiskIndicators || hasMagiskHideIndicators -> ConfidenceLevel.HIGH
                    hasRootManagementApps || hasDangerousProps || hasNativeLayerIndicators -> ConfidenceLevel.MEDIUM
                    hasTestKeys || hasBusyBox -> ConfidenceLevel.LOW
                    else -> ConfidenceLevel.NONE
                }
    }

    enum class ConfidenceLevel {
        NONE,
        LOW,
        MEDIUM,
        HIGH,
        DEFINITE,
    }

    /**
     * Common paths where su binary might be found.
     */
    private val SU_BINARY_PATHS =
        listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su",
            "/cache/su",
            "/data/su",
            "/dev/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/su/bin/su",
            "/data/adb/su/bin/su",
            "/apex/com.android.runtime/bin/su",
            "/apex/com.android.art/bin/su",
        )

    /**
     * Root management app packages.
     */
    private val ROOT_MANAGEMENT_PACKAGES =
        listOf(
            // Magisk
            "com.topjohnwu.magisk",
            "io.github.vvb2060.magisk",
            "io.github.huskydg.magisk",
            // SuperSU
            "eu.chainfire.supersu",
            "com.noshufou.android.su",
            "com.noshufou.android.su.elite",
            // KingRoot
            "com.kingroot.kinguser",
            "com.kingo.root",
            "com.kingouser.com",
            // Other root managers
            "com.koushikdutta.superuser",
            "com.thirdparty.superuser",
            "com.yellowes.su",
            "com.devadvance.rootcloak",
            "com.devadvance.rootcloakplus",
            "com.ramdroid.appquarantine",
            "com.amphoras.hidemyroot",
            "com.amphoras.hidemyrootadfree",
            "com.formyhm.hideroot",
            "com.formyhm.hiderootPremium",
            "com.zachspong.temprootremovejb",
            "com.saurik.substrate",
            // Root hiding
            "de.robv.android.xposed.installer",
            "com.github.nicholasadamou.hooked",
        )

    /**
     * Magisk-specific indicators (includes Magisk, Zygisk, Shamiko, KernelSU).
     */
    private val MAGISK_PATHS =
        listOf(
            "/sbin/.magisk",
            "/sbin/.core",
            "/data/adb/magisk",
            "/data/adb/magisk/",
            "/data/adb/magisk.img",
            "/data/adb/magisk.db",
            "/data/adb/magisk_simple",
            "/data/magisk",
            "/cache/magisk.log",
            "/data/adb/ksu",
            "/data/adb/ksud",
            "/data/adb/modules",
            // Zygisk module marker
            "/data/adb/modules/.zygisk",
            // Shamiko (Magisk module that hides root from detection)
            "/data/adb/modules/shamiko/",
            "/data/adb/shamiko/",
            "/data/adb/modules/zygisk_lsposed/",
            "/data/adb/modules/riru_lsposed/",
        )

    /**
     * Known repackaged Magisk Manager package names.
     * Magisk Manager can be hidden by renaming to a random package.
     */
    private val MAGISK_MANAGER_PACKAGES =
        listOf(
            "com.topjohnwu.magisk",
            "io.github.vvb2060.magisk",
            "io.github.huskydg.magisk",
            // KernelSU manager
            "me.weishu.kernelsu",
        )

    /**
     * Dangerous system property values.
     */
    private val DANGEROUS_PROPERTIES =
        mapOf(
            "ro.debuggable" to "1",
            "ro.secure" to "0",
            "service.adb.root" to "1",
            "ro.build.selinux" to "0",
        )

    /**
     * Performs all root detection checks.
     *
     * Each of the 11 checks is wrapped via [ExceptionTallyBuilder.runCheck] so that
     * the aggregated exception ratio is available in [RootDetectionResult.exceptionTally].
     *
     * @param context Application context
     * @return RootDetectionResult with detailed information
     */
    fun performChecks(context: Context): RootDetectionResult {
        val tally = ExceptionTallyBuilder(threshold = 0.6f)
        val indicators = mutableListOf<String>()

        val hasSu = tally.runCheck(TAG, "checkSuBinary") { checkSuBinary() }
        if (hasSu) indicators.add("su binary found")

        val hasRootApps = tally.runCheck(TAG, "checkRootManagementApps") { checkRootManagementApps(context) }
        if (hasRootApps) indicators.add("Root management app installed")

        val hasTestKeys = tally.runCheck(TAG, "checkTestKeys") { checkTestKeys() }
        if (hasTestKeys) indicators.add("Test-keys detected in build")

        val hasDangerousProps = tally.runCheck(TAG, "checkDangerousProperties") { checkDangerousProperties() }
        if (hasDangerousProps) indicators.add("Dangerous system properties")

        val hasBusyBox = tally.runCheck(TAG, "checkBusyBox") { checkBusyBox() }
        if (hasBusyBox) indicators.add("BusyBox installed")

        val hasRwSystem = tally.runCheck(TAG, "checkRwSystem") { checkRwSystem() }
        if (hasRwSystem) indicators.add("System partition is writable")

        val hasMagisk = tally.runCheck(TAG, "checkMagiskIndicators") { checkMagiskIndicators() }
        if (hasMagisk) indicators.add("Magisk indicators detected")

        val hasMagiskHide = tally.runCheck(TAG, "checkMagiskHideIndicators") { checkMagiskHideIndicators(context) }
        if (hasMagiskHide) indicators.add("Magisk Hide/Zygisk/Shamiko indicators detected")

        val hasNativeLayer = tally.runCheck(TAG, "checkNativeLayerRootIndicators") { checkNativeLayerRootIndicators() }
        if (hasNativeLayer) indicators.add("Native-layer root indicators detected")

        // checkSeLinuxEnforcing: on exception, default to false (not detected as enforcing).
        // This is the safe default because a genuine device returns "enforcing" and we want
        // to flag non-enforcing, but an exception should not raise a false positive for root.
        // The exception still counts in the tally.
        val seLinuxEnforcing =
            tally.runCheck(TAG, "checkSeLinuxEnforcing", defaultOnException = true) {
                checkSeLinuxEnforcing()
            }
        if (!seLinuxEnforcing) indicators.add("SELinux not enforcing")

        val isEmulator = tally.runCheck(TAG, "checkEmulator") { checkEmulator() }
        if (isEmulator) indicators.add("Running on emulator")

        val exceptionTally = tally.build()

        val result =
            RootDetectionResult(
                hasSuBinary = hasSu,
                hasRootManagementApps = hasRootApps,
                hasTestKeys = hasTestKeys,
                hasDangerousProps = hasDangerousProps,
                hasBusyBox = hasBusyBox,
                hasRwSystem = hasRwSystem,
                hasMagiskIndicators = hasMagisk,
                hasMagiskHideIndicators = hasMagiskHide,
                hasNativeLayerIndicators = hasNativeLayer,
                seLinuxEnforcing = seLinuxEnforcing,
                isEmulator = isEmulator,
                detectedIndicators = indicators,
                exceptionTally = exceptionTally,
            )

        if (result.isRooted) {
            Timber.tag(TAG).w("Root detected: ${indicators.joinToString(", ")}")
        }
        if (result.isEmulator) {
            Timber.tag(TAG).w("Emulator detected")
        }

        return result
    }

    /**
     * Check for su binary in common paths.
     */
    private fun checkSuBinary(): Boolean {
        // Check file existence
        val pathCheck =
            SU_BINARY_PATHS.any { path ->
                try {
                    File(path).exists()
                } catch (_: Exception) {
                    false
                }
            }
        if (pathCheck) return true

        // Check via which command
        val result = execWithTimeout(arrayOf("/system/bin/which", "su"))
        return !result.isNullOrEmpty()
    }

    /**
     * Check for root management applications.
     *
     * Inner per-package catches (NameNotFoundException) are preserved because
     * a missing package is the normal, expected case.
     */
    private fun checkRootManagementApps(context: Context): Boolean {
        val pm = context.packageManager
        return ROOT_MANAGEMENT_PACKAGES.any { pkg ->
            try {
                pm.getPackageInfo(pkg, 0)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Check if build was signed with test-keys.
     */
    private fun checkTestKeys(): Boolean {
        val buildTags = Build.TAGS
        val fingerprint = Build.FINGERPRINT

        return buildTags?.contains("test-keys") == true ||
            fingerprint.contains("test-keys") ||
            fingerprint.contains("/dev-keys") ||
            fingerprint.contains("/debug-keys")
    }

    /**
     * Check for dangerous system properties.
     */
    private fun checkDangerousProperties(): Boolean {
        return DANGEROUS_PROPERTIES.any { (prop, dangerousValue) ->
            try {
                val value = execWithTimeout(arrayOf("getprop", prop))?.trim()
                value == dangerousValue
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Check for BusyBox installation (common with rooted devices).
     */
    private fun checkBusyBox(): Boolean {
        val busyBoxPaths =
            listOf(
                "/system/xbin/busybox",
                "/system/bin/busybox",
                "/sbin/busybox",
                "/data/local/busybox",
                "/data/local/xbin/busybox",
            )

        return busyBoxPaths.any { path ->
            try {
                File(path).exists()
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Check if system partition is mounted as read-write.
     */
    private fun checkRwSystem(): Boolean {
        val mounts = File("/proc/mounts").readText()
        // Look for /system mounted with rw
        return mounts.lines().any { line ->
            line.contains("/system") && line.contains(" rw")
        }
    }

    /**
     * Check for Magisk-specific indicators.
     */
    private fun checkMagiskIndicators(): Boolean {
        // Check Magisk paths
        val pathCheck =
            MAGISK_PATHS.any { path ->
                try {
                    File(path).exists()
                } catch (_: Exception) {
                    false
                }
            }
        if (pathCheck) return true

        // Check for Magisk Manager hidden package name pattern.
        // Magisk Manager can be renamed to random package names.
        val mapsFile = File("/proc/self/maps")
        if (mapsFile.exists()) {
            val content = mapsFile.readText().lowercase()
            return content.contains("magisk") || content.contains("/sbin/.magisk")
        }
        return false
    }

    /**
     * Check if SELinux is in enforcing mode.
     * Rooted devices often have SELinux permissive or disabled.
     */
    private fun checkSeLinuxEnforcing(): Boolean {
        // Check getenforce command
        val result = execWithTimeout(arrayOf("getenforce"))?.trim()?.lowercase()
        return result == "enforcing"
    }

    /**
     * Check if running on an emulator.
     */
    private fun checkEmulator(): Boolean {
        return checkEmulatorBuildProperties() ||
            checkEmulatorHardware() ||
            checkEmulatorFiles()
    }

    /**
     * Check build properties for emulator indicators using weighted scoring.
     * Delegates to [scoreEmulatorBuildProperties] with values read from [Build].
     */
    private fun checkEmulatorBuildProperties(): Boolean {
        val score =
            scoreEmulatorBuildProperties(
                fingerprint = Build.FINGERPRINT,
                model = Build.MODEL,
                manufacturer = Build.MANUFACTURER,
                brand = Build.BRAND,
                device = Build.DEVICE,
                product = Build.PRODUCT,
                hardware = Build.HARDWARE,
                board = Build.BOARD,
            )
        Timber.tag(TAG).d("Emulator build-property score: %d (threshold %d)", score, EMULATOR_SCORE_THRESHOLD)
        return score >= EMULATOR_SCORE_THRESHOLD
    }

    /**
     * Compute an emulator likelihood score from raw build property strings.
     *
     * Exposed as `internal` so unit tests can exercise the scoring logic directly
     * without mocking Android framework classes.
     *
     * Scoring bands:
     *   - Definitive markers (goldfish, ranchu, vbox, sdk model names, genymotion,
     *     sdk in fingerprint/product): 10 pts each. Sets [hasDefinitiveSignal].
     *   - Moderate signals (test-keys in fingerprint, chromium manufacturer): 6 pts each.
     *   - Generic signals (fingerprint/device/brand contains "generic" or "unknown"): 4-5 pts,
     *     capped at 5 pts total when no definitive signal has fired.
     *   - Weak signals (manufacturer empty or "unknown", board empty or "unknown"): 2 pts each.
     *
     * Genuine emulators score 20-40+. A budget OEM with only manufacturer="unknown" scores
     * 2 pts. A GSI build with all three "generic" checks hit but no definitive signal scores
     * at most 5 pts. Neither crosses the [EMULATOR_SCORE_THRESHOLD] of 8.
     *
     * @return computed score (>= [EMULATOR_SCORE_THRESHOLD] means emulator)
     */
    internal fun scoreEmulatorBuildProperties(
        fingerprint: String,
        model: String,
        manufacturer: String,
        brand: String,
        device: String,
        product: String,
        hardware: String,
        board: String,
    ): Int {
        val fp = fingerprint.lowercase()
        val mdl = model.lowercase()
        val mfr = manufacturer.lowercase()
        val br = brand.lowercase()
        val dev = device.lowercase()
        val prd = product.lowercase()
        val hw = hardware.lowercase()
        val brd = board.lowercase()

        var score = 0
        var hasDefinitiveSignal = false
        var genericScore = 0

        // --- Definitive markers (10 pts each) ---

        // Goldfish: the kernel used by the Android emulator
        if (hw.contains("goldfish") || brd.contains("goldfish") ||
            dev.contains("goldfish") || fp.contains("goldfish")
        ) {
            score += 10
            hasDefinitiveSignal = true
        }

        // Ranchu: successor QEMU kernel for the Android emulator
        if (hw.contains("ranchu")) {
            score += 10
            hasDefinitiveSignal = true
        }

        // VirtualBox (Genymotion, x86 emulators)
        if (hw.contains("vbox86") || dev.contains("vbox86p") ||
            mdl == "vbox86p" || prd.contains("vbox86p") ||
            fp.contains("vbox")
        ) {
            score += 10
            hasDefinitiveSignal = true
        }

        // SDK model names: exact matches and well-known substrings
        if (mdl == "sdk" || mdl == "sdk_x86" || mdl == "sdk_google" ||
            mdl.contains("google_sdk") || mdl.contains("android sdk built for") ||
            mdl.contains("sdk_gphone") || mdl.contains("sdk_gphone64") ||
            mdl.contains("droid4x") || mdl.contains("emulator")
        ) {
            score += 10
            hasDefinitiveSignal = true
        }

        // Genymotion manufacturer
        if (mfr.contains("genymotion")) {
            score += 10
            hasDefinitiveSignal = true
        }

        // SDK/google_sdk in fingerprint or product (distinct from "generic", handled separately)
        if (fp.contains("sdk") || fp.contains("google_sdk") ||
            prd.contains("sdk") || prd.contains("google_sdk") ||
            prd.contains("sdk_x86") || prd.contains("sdk_gphone") ||
            prd.contains("emulator") || prd.contains("simulator")
        ) {
            score += 10
            hasDefinitiveSignal = true
        }

        // --- Moderate signals (6 pts each) ---

        // test-keys in fingerprint: developer or rooted build; meaningful alongside other signals
        if (fp.contains("test-keys")) {
            score += 6
        }

        // Chromium as manufacturer: ChromeOS-based Android containers
        if (mfr.contains("chromium")) {
            score += 6
        }

        // --- Generic signals (tracked separately for cap) ---

        // "generic" or "unknown" in fingerprint (4 pts)
        if (fp.contains("generic") || fp.contains("unknown")) {
            genericScore += 4
        }

        // "generic" in device (4 pts)
        if (dev.contains("generic")) {
            genericScore += 4
        }

        // "generic" in brand (5 pts, brand is more field-specific than a fingerprint substring)
        if (br.contains("generic") || br.contains("generic_x86")) {
            genericScore += 5
        }

        // --- Weak signals (2 pts each) ---

        // Empty or "unknown" manufacturer: common on unbranded budget OEM devices
        if (mfr.isEmpty() || mfr == "unknown") {
            score += 2
        }

        // Empty or "unknown" board: some budget devices omit this field
        if (brd.isEmpty() || brd == "unknown") {
            score += 2
        }

        // Apply generic-signal cap when no definitive marker has fired.
        // A GSI build can legitimately hit all three generic checks (4+4+5 = 13 pts)
        // without being an emulator. Cap at 5 pts in that case.
        val effectiveGenericScore = if (hasDefinitiveSignal) genericScore else minOf(genericScore, 5)
        score += effectiveGenericScore

        return score
    }

    /**
     * Check hardware characteristics for emulator indicators.
     */
    private fun checkEmulatorHardware(): Boolean {
        // Check for QEMU driver
        val qemuDrivers =
            listOf(
                "/dev/socket/qemud",
                "/dev/qemu_pipe",
                "/dev/goldfish_pipe",
            )

        return qemuDrivers.any { path ->
            try {
                File(path).exists()
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Check for emulator-specific files.
     */
    private fun checkEmulatorFiles(): Boolean {
        val emulatorFiles =
            listOf(
                "/system/lib/libc_malloc_debug_qemu.so",
                "/sys/qemu_trace",
                "/system/bin/qemu-props",
                "/dev/socket/genyd",
                "/dev/socket/baseband_genyd",
                "/init.goldfish.rc",
                "/init.ranchu.rc",
                "/fstab.goldfish",
                "/fstab.ranchu",
                "/ueventd.goldfish.rc",
                "/ueventd.ranchu.rc",
                "/x86.prop",
                "/data/data/com.android.emulator.smoketests",
            )

        return emulatorFiles.any { path ->
            try {
                File(path).exists()
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Detect Magisk Hide, Zygisk and Shamiko root-hiding mechanisms.
     *
     * Magisk Hide (legacy) and its successors Zygisk + Shamiko work by
     * unmounting or hiding root artefacts from targeted apps. We detect
     * them through suspicious mount namespaces, repackaged Magisk Manager
     * packages, Zygisk and Shamiko module markers on disk, and system
     * properties set by Magisk/KernelSU.
     */
    private fun checkMagiskHideIndicators(context: Context): Boolean {
        // 1. Check /proc/self/mountinfo for suspicious mount namespaces.
        // MagiskHide creates bind mounts to hide su; Shamiko uses mount
        // namespace isolation. Look for tmpfs on /system or suspicious binds.
        val mountinfo = File("/proc/self/mountinfo")
        if (mountinfo.exists()) {
            val content = mountinfo.readText().lowercase()
            // Magisk mounts a tmpfs over /sbin to hide .magisk
            if (content.contains("tmpfs /sbin") ||
                content.contains("magisk") ||
                content.contains("/adb/modules")
            ) {
                return true
            }
        }

        // 2. Check for repackaged Magisk Manager (uses random package names)
        val pm = context.packageManager
        // Direct known package check
        if (MAGISK_MANAGER_PACKAGES.any { pkg ->
                try {
                    pm.getPackageInfo(pkg, 0)
                    true
                } catch (_: Exception) {
                    false
                }
            }
        ) {
            return true
        }

        // 3. Check Zygisk-specific properties
        val zygiskProps =
            listOf(
                "ro.zygisk.enabled",
                "persist.sys.zygisk",
            )
        for (prop in zygiskProps) {
            val value = execWithTimeout(arrayOf("getprop", prop))?.trim()?.lowercase()
            if (value == "1" || value == "true") {
                return true
            }
        }

        return false
    }

    /**
     * Native-layer root detection.
     *
     * Checks that operate at the native/proc level rather than just
     * looking for files or packages: /proc/self/maps for suspicious
     * libraries (su wrappers, inject libs) and /proc/mounts for
     * overlay/bind mounts hiding su binaries.
     */
    private fun checkNativeLayerRootIndicators(): Boolean {
        // 1. Check /proc/self/maps for suspicious native libraries
        val suspiciousLibs =
            listOf(
                "libsu.so",
                "libsupol.so",
                "libmagisk",
                "libzygisk",
                "libriru",
                "liblspd.so",
            )

        val mapsFile = File("/proc/self/maps")
        if (mapsFile.exists()) {
            mapsFile.bufferedReader().use { reader ->
                reader.lineSequence().forEach { line ->
                    val lower = line.lowercase()
                    if (suspiciousLibs.any { lower.contains(it) }) {
                        return true
                    }
                }
            }
        }

        // 2. Check /proc/mounts for overlay/bind mounts hiding su binaries.
        // Overlay mounts on /system/bin or /system/xbin are suspicious.
        val mounts = File("/proc/mounts")
        if (mounts.exists()) {
            mounts.bufferedReader().use { reader ->
                reader.lineSequence().forEach { line ->
                    val lower = line.lowercase()
                    // overlayfs on system paths is suspicious
                    if (lower.contains("overlay") &&
                        (lower.contains("/system/bin") || lower.contains("/system/xbin"))
                    ) {
                        return true
                    }
                    // bind mount hiding su
                    if (lower.contains("/su") && lower.contains("bind")) {
                        return true
                    }
                }
            }
        }

        return false
    }

    /**
     * Quick check for most common root indicators.
     * Use for frequent polling. Does not participate in exception tallying.
     *
     * @return true if root is likely present
     */
    fun quickCheck(): Boolean {
        // Quick su check
        return listOf("/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su")
            .any { path ->
                try {
                    File(path).exists()
                } catch (_: Exception) {
                    false
                }
            }
    }
}
