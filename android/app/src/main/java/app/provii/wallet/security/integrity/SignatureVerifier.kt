// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security.integrity

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import timber.log.Timber
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.zip.ZipFile

/**
 * MASVS-RESILIENCE-2: Runtime application integrity verification performed entirely on-device
 * without network or Google API calls. Validates the APK signature against an expected hash,
 * computes a SHA-256 digest of classes.dex to detect code modification, confirms the
 * AndroidManifest.xml is present and non-empty, verifies the package name, and checks the
 * installer source.
 */
object SignatureVerifier {
    private const val TAG = "SignatureVerifier"

    /**
     * SHA-256 hash of the release signing certificate.
     *
     * TODO: Replace this placeholder with the actual release signing certificate hash
     * before any release build. Generate it during CI with:
     *   keytool -list -v -keystore release.keystore | grep SHA256
     * or at runtime with SignatureVerifier.logIntegrityHashes(context).
     */
    private const val EXPECTED_SIGNING_CERT_HASH = "PLACEHOLDER_REPLACE_BEFORE_RELEASE"

    /**
     * Validate that the signing certificate hash has been configured.
     * Throws in release builds if the placeholder is still present.
     * Call this from Application.onCreate() to fail fast.
     */
    fun validateConfiguration(context: android.content.Context) {
        val isDebug =
            context.applicationInfo.flags and
                android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!isDebug && EXPECTED_SIGNING_CERT_HASH == "PLACEHOLDER_REPLACE_BEFORE_RELEASE") {
            throw SecurityException(
                "Signing certificate hash not configured for release build. " +
                    "Set EXPECTED_SIGNING_CERT_HASH before publishing.",
            )
        }
    }

    /**
     * Result of integrity verification.
     */
    data class IntegrityResult(
        val signatureValid: Boolean,
        val expectedSignatureHash: String?,
        val actualSignatureHash: String?,
        val dexHashValid: Boolean,
        val expectedDexHash: String?,
        val actualDexHash: String?,
        val manifestValid: Boolean,
        val packageNameValid: Boolean,
        val installerValid: Boolean,
        val installerPackage: String?,
        val issues: List<String>,
    ) {
        val isIntact: Boolean
            get() = signatureValid && dexHashValid && manifestValid && packageNameValid

        val isTampered: Boolean
            get() = !isIntact

        val integrityLevel: IntegrityLevel
            get() =
                when {
                    !signatureValid -> IntegrityLevel.COMPROMISED
                    !dexHashValid -> IntegrityLevel.COMPROMISED
                    !manifestValid -> IntegrityLevel.SUSPICIOUS
                    !packageNameValid -> IntegrityLevel.COMPROMISED
                    // Sideloaded (null installer) or unknown installer
                    !installerValid -> IntegrityLevel.SUSPICIOUS
                    else -> IntegrityLevel.VERIFIED
                }
    }

    enum class IntegrityLevel {
        VERIFIED,
        UNKNOWN_SOURCE,
        SUSPICIOUS,
        COMPROMISED,
    }

    /**
     * Configuration for integrity verification.
     */
    data class VerificationConfig(
        val expectedSignatureHash: String? = EXPECTED_SIGNING_CERT_HASH,
        val expectedDexHash: String? = null,
        val expectedPackageName: String = "app.provii.wallet",
        val allowedInstallers: List<String> =
            listOf(
                "com.android.vending", // Google Play Store
                "com.amazon.venezia", // Amazon App Store
                "org.fdroid.fdroid", // F-Droid
                "org.fdroid.basic", // F-Droid Basic
                "com.aurora.store", // Aurora Store (F-Droid compatible)
                "com.sec.android.app.samsungapps", // Samsung Galaxy Store
                "com.huawei.appmarket", // Huawei AppGallery
            ),
    )

    /**
     * Performs integrity verification against the provided config.
     *
     * @param context Application context
     * @param config Verification configuration with expected values
     * @return IntegrityResult with detailed verification information
     */
    fun performVerification(
        context: Context,
        config: VerificationConfig = VerificationConfig(),
    ): IntegrityResult {
        val issues = mutableListOf<String>()

        // Get signature hash
        val actualSignatureHash = getSignatureHash(context)
        val signatureValid =
            if (config.expectedSignatureHash != null) {
                if (!MessageDigest.isEqual(
                        actualSignatureHash?.toByteArray(Charsets.UTF_8),
                        config.expectedSignatureHash.toByteArray(Charsets.UTF_8),
                    )
                ) {
                    issues.add("Signature hash mismatch")
                    false
                } else {
                    true
                }
            } else {
                // If no expected hash provided, just ensure we can get the signature
                if (actualSignatureHash == null) {
                    issues.add("Unable to retrieve signature")
                    false
                } else {
                    true
                }
            }

        // Get DEX hash. Fail CLOSED: if an expected hash is configured and the
        // actual hash cannot be computed or does not match, treat as COMPROMISED.
        // If no expected hash is configured, inability to compute the hash is also
        // treated as a failure (the DEX file should always be readable).
        val actualDexHash = getDexHash(context)
        val dexHashValid =
            if (config.expectedDexHash != null) {
                if (actualDexHash == null) {
                    issues.add("DEX hash could not be computed (expected hash was configured)")
                    false
                } else if (!MessageDigest.isEqual(
                        actualDexHash.toByteArray(Charsets.UTF_8),
                        config.expectedDexHash.toByteArray(Charsets.UTF_8),
                    )
                ) {
                    issues.add("DEX hash mismatch")
                    false
                } else {
                    true
                }
            } else {
                // No expected hash configured. Still fail if we cannot read the DEX.
                if (actualDexHash == null) {
                    issues.add("Unable to compute DEX hash")
                    false
                } else {
                    true
                }
            }

        // Verify manifest integrity
        val manifestValid = verifyManifestIntegrity(context)
        if (!manifestValid) {
            issues.add("Manifest integrity check failed")
        }

        // Verify package name
        val packageNameValid = verifyPackageName(context, config.expectedPackageName)
        if (!packageNameValid) {
            issues.add("Package name mismatch")
        }

        // Check installer. Sideloaded APKs (null installer) are flagged as suspicious.
        // Only explicitly allowed installers pass this check.
        val installerPackage = getInstallerPackage(context)
        val installerValid =
            config.allowedInstallers.isEmpty() ||
                installerPackage in config.allowedInstallers

        if (installerPackage == null) {
            issues.add("Sideloaded APK (no installer package)")
        } else if (!installerValid) {
            issues.add("Unknown installer: $installerPackage")
        }

        val result =
            IntegrityResult(
                signatureValid = signatureValid,
                expectedSignatureHash = config.expectedSignatureHash,
                actualSignatureHash = actualSignatureHash,
                dexHashValid = dexHashValid,
                expectedDexHash = config.expectedDexHash,
                actualDexHash = actualDexHash,
                manifestValid = manifestValid,
                packageNameValid = packageNameValid,
                installerValid = installerValid,
                installerPackage = installerPackage,
                issues = issues,
            )

        if (result.isTampered) {
            Timber.tag(TAG).w("Integrity issues detected: ${issues.joinToString(", ")}")
        }

        return result
    }

    /**
     * Get SHA-256 hash of the APK signature.
     */
    @Suppress("DEPRECATION")
    fun getSignatureHash(context: Context): String? {
        return try {
            val packageInfo: PackageInfo =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    context.packageManager.getPackageInfo(
                        context.packageName,
                        PackageManager.GET_SIGNING_CERTIFICATES,
                    )
                } else {
                    context.packageManager.getPackageInfo(
                        context.packageName,
                        PackageManager.GET_SIGNATURES,
                    )
                }

            val signatures: Array<Signature>? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    packageInfo.signingInfo?.apkContentsSigners
                } else {
                    @Suppress("DEPRECATION")
                    packageInfo.signatures
                }

            signatures?.firstOrNull()?.let { signature ->
                val md = MessageDigest.getInstance("SHA-256")
                val digest = md.digest(signature.toByteArray())
                bytesToHex(digest)
            }
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error getting signature hash")
            null
        }
    }

    /**
     * Get SHA-256 hash of classes.dex file.
     */
    fun getDexHash(context: Context): String? {
        return try {
            val apkPath = context.applicationInfo.sourceDir
            ZipFile(apkPath).use { zipFile ->
                val dexEntry = zipFile.getEntry("classes.dex")
                if (dexEntry != null) {
                    val inputStream = zipFile.getInputStream(dexEntry)
                    val md = MessageDigest.getInstance("SHA-256")
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        md.update(buffer, 0, bytesRead)
                    }
                    inputStream.close()
                    bytesToHex(md.digest())
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error computing DEX hash")
            null
        }
    }

    /**
     * Verify the AndroidManifest integrity by checking if it can be properly parsed.
     */
    private fun verifyManifestIntegrity(context: Context): Boolean {
        return try {
            val apkPath = context.applicationInfo.sourceDir
            ZipFile(apkPath).use { zipFile ->
                val manifestEntry = zipFile.getEntry("AndroidManifest.xml")
                if (manifestEntry != null) {
                    // Verify manifest exists and has content
                    val inputStream = zipFile.getInputStream(manifestEntry)
                    val size = inputStream.available()
                    inputStream.close()
                    size > 0
                } else {
                    false
                }
            }
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error verifying manifest")
            false
        }
    }

    /**
     * Verify the package name matches expected value.
     */
    private fun verifyPackageName(
        context: Context,
        expectedPackageName: String,
    ): Boolean {
        return context.packageName == expectedPackageName
    }

    /**
     * Get the installer package name.
     */
    private fun getInstallerPackage(context: Context): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.packageManager.getInstallSourceInfo(context.packageName)
                    .installingPackageName
            } else {
                context.packageManager.getInstallerPackageName(context.packageName)
            }
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error getting installer package")
            null
        }
    }

    /**
     * Convert bytes to hex string.
     */
    private fun bytesToHex(bytes: ByteArray): String {
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Compute hash of entire APK file.
     */
    fun getApkHash(context: Context): String? {
        return try {
            val apkPath = context.applicationInfo.sourceDir
            val file = File(apkPath)
            FileInputStream(file).use { fis ->
                val md = MessageDigest.getInstance("SHA-256")
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (fis.read(buffer).also { bytesRead = it } != -1) {
                    md.update(buffer, 0, bytesRead)
                }
                bytesToHex(md.digest())
            }
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error computing APK hash")
            null
        }
    }

    /**
     * Quick signature check for frequent verification.
     *
     * @param context Application context
     * @param expectedHash Expected signature hash (null to skip validation)
     * @return true if signature is valid
     */
    fun quickCheck(
        context: Context,
        expectedHash: String? = null,
    ): Boolean {
        val actualHash = getSignatureHash(context)
        return if (expectedHash != null) {
            actualHash != null &&
                MessageDigest.isEqual(
                    actualHash.toByteArray(Charsets.UTF_8),
                    expectedHash.toByteArray(Charsets.UTF_8),
                )
        } else {
            actualHash != null
        }
    }

    /**
     * Generate verification config from current app state.
     * Useful for establishing a baseline during development.
     */
    fun generateConfig(context: Context): VerificationConfig {
        return VerificationConfig(
            expectedSignatureHash = getSignatureHash(context),
            expectedDexHash = getDexHash(context),
            expectedPackageName = context.packageName,
        )
    }

    /**
     * Log current integrity hashes for debugging/setup purposes.
     *
     * Guarded behind BuildConfig.DEBUG to prevent integrity hashes
     * from being logged in release builds. Leaking these values in production
     * logs would let an attacker know exactly which hashes to forge.
     */
    fun logIntegrityHashes(context: Context) {
        if (!app.provii.wallet.BuildConfig.DEBUG) {
            Timber.tag(TAG).w("logIntegrityHashes() called in non-debug build; suppressing output")
            return
        }
        Timber.tag(TAG).d("Current Integrity Hashes:")
        Timber.tag(TAG).d("  Package: ${context.packageName}")
        Timber.tag(TAG).d("  Signature Hash: ${getSignatureHash(context)}")
        Timber.tag(TAG).d("  DEX Hash: ${getDexHash(context)}")
        Timber.tag(TAG).d("  APK Hash: ${getApkHash(context)}")
        Timber.tag(TAG).d("  Installer: ${getInstallerPackage(context)}")
    }
}
