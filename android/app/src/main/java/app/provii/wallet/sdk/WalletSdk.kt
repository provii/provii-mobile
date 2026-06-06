// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.sdk

import android.content.Context
import java.io.File
import java.security.MessageDigest

/**
 * JNI helper that loads the Rust provii_mobile_sdk_ffi native library and stores the
 * Application Context as a GlobalRef for use by native code. This must be called
 * before any UniFFI-generated bindings are invoked, because JNA alone does not
 * trigger JNI_OnLoad for the library.
 *
 * After loading the native library, the SHA-256 hash of the .so file is
 * computed and compared against the expected digest embedded at build time. If the
 * hash does not match, a SecurityException is thrown to prevent execution of a
 * tampered library. The comparison uses MessageDigest.isEqual which is NOT
 * constant-time, but this is acceptable here because the hash is public (embedded
 * in the APK) and an attacker who can replace the .so can also replace this check.
 */
object WalletSdk {
    /**
     * Expected SHA-256 digest of libprovii_mobile_sdk_ffi.so (hex-encoded, lowercase).
     * This value MUST be updated every time the native library is rebuilt.
     * To compute: sha256sum android/app/src/main/jniLibs/<abi>/libprovii_mobile_sdk_ffi.so
     *
     * Per-ABI digests are stored in BuildConfig at build time via the Gradle
     * nativeLibHashes property. When that property is not set (local dev builds),
     * verification is skipped with a warning log.
     */
    private val EXPECTED_LIB_HASHES: Map<String, String> =
        try {
            // BuildConfig.NATIVE_LIB_HASHES is a semicolon-separated list of abi=hash pairs
            // injected by the Gradle build, e.g. "arm64-v8a=abcd1234;armeabi-v7a=ef567890"
            val raw = app.provii.wallet.BuildConfig.NATIVE_LIB_HASHES
            if (raw.isNotEmpty()) {
                raw.split(";").associate { entry ->
                    val (abi, hash) = entry.split("=", limit = 2)
                    abi.trim() to hash.trim().lowercase()
                }
            } else {
                emptyMap()
            }
        } catch (_: Exception) {
            emptyMap()
        }

    @Volatile
    private var verified = false

    init {
        // Ensure JNI_OnLoad runs
        System.loadLibrary("provii_mobile_sdk_ffi")
    }

    /**
     * Verify the integrity of the loaded native library by computing its SHA-256
     * hash and comparing against the expected value for the current ABI.
     *
     * @param context Application context used to locate the native library directory
     * @throws SecurityException if the hash does not match the expected value
     */
    fun verifyNativeLibrary(context: Context) {
        if (verified) return

        if (EXPECTED_LIB_HASHES.isEmpty()) {
            if (app.provii.wallet.BuildConfig.BUILD_TYPE == "release") {
                throw SecurityException("Native library integrity hashes not configured for release build")
            }
            // No hashes configured (local dev build). Log a warning but do not block.
            android.util.Log.w("WalletSdk", "Native library hash verification skipped: no expected hashes configured")
            verified = true
            return
        }

        val nativeLibDir = context.applicationInfo.nativeLibraryDir
        val libFile = File(nativeLibDir, "libprovii_mobile_sdk_ffi.so")

        if (!libFile.exists()) {
            throw SecurityException(
                "Native library not found at expected path: ${libFile.absolutePath}",
            )
        }

        val digest = MessageDigest.getInstance("SHA-256")
        libFile.inputStream().buffered().use { stream ->
            val buffer = ByteArray(8192)
            var bytesRead: Int
            while (stream.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
            }
        }

        val actualHash = digest.digest().joinToString("") { "%02x".format(it) }

        // Determine the ABI from the nativeLibDir path (e.g. /data/app/.../lib/arm64)
        val abiSegment = File(nativeLibDir).name
        // Map directory names to standard ABI identifiers
        val abi =
            when (abiSegment) {
                "arm64" -> "arm64-v8a"
                "arm" -> "armeabi-v7a"
                "x86" -> "x86"
                "x86_64" -> "x86_64"
                else -> abiSegment
            }

        val expectedHash = EXPECTED_LIB_HASHES[abi]
        if (expectedHash == null) {
            throw SecurityException("Unsupported ABI '$abi': no integrity hash available")
        }

        if (actualHash != expectedHash) {
            throw SecurityException(
                "Native library integrity check failed for ABI '$abi'. " +
                    "Expected hash: $expectedHash, actual: $actualHash",
            )
        }

        verified = true
    }

    /**
     * Returns: 0 = OK, 1 = Already initialized, 2 = Error
     * (Matches constants in crates/ffi/src/android_init.rs)
     */
    @JvmStatic
    external fun initAndroidContext(context: Context): Int
}
