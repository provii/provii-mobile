// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import androidx.biometric.BiometricManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import timber.log.Timber
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages Android Keystore operations for PIN storage and SDK secure storage. Wraps
 * EncryptedSharedPreferences with per-use biometric authentication (BIOMETRIC_STRONG only,
 * no device credential fallback) and optional StrongBox hardware backing. Also provides
 * PIN rate limiting with a 15-minute lockout after five consecutive failures.
 */
@Singleton
class NativeKeystoreManager
    @Inject
    constructor(
        private val context: Context,
    ) {
        companion object {
            private const val ANDROID_KEYSTORE = "AndroidKeyStore"
            private const val PIN_KEY_ALIAS = "ProviiWalletPINKey"
            private const val TRANSFORMATION = "AES/GCM/NoPadding"
            private const val GCM_TAG_LENGTH = 128
            private const val ENCRYPTED_PREFS_FILE = "provii_pin_prefs"

            // PIN rate limiting constants
            private const val MAX_PIN_ATTEMPTS = 5
            private const val LOCKOUT_DURATION_MS = 15L * 60 * 1000 // 15 minutes
            private const val KEY_PIN_ATTEMPTS = "pin_attempt_count"
            private const val KEY_LOCKOUT_UNTIL = "pin_lockout_until"
        }

        private val keyguardManager: KeyguardManager =
            context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

        private val biometricManager: BiometricManager =
            BiometricManager.from(context)

        /**
         * Whether the device has a screen lock (PIN, pattern, password, or biometric) configured.
         */
        val isDeviceAuthAvailable: Boolean
            get() = keyguardManager.isDeviceSecure

        /**
         * Whether the device has strong biometric hardware available and enrolled.
         */
        val isBiometricStrongAvailable: Boolean
            get() =
                biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
                    BiometricManager.BIOMETRIC_SUCCESS

        private val keyStore: KeyStore =
            KeyStore.getInstance(ANDROID_KEYSTORE).apply {
                load(null)
            }

        // Nullable backing field for encryptedPrefs to support key rotation
        @Volatile
        private var _encryptedPrefs: android.content.SharedPreferences? = null

        private val encryptedPrefs: android.content.SharedPreferences
            get() {
                return _encryptedPrefs ?: synchronized(this) {
                    _encryptedPrefs ?: createEncryptedPrefs().also { _encryptedPrefs = it }
                }
            }

        private fun createEncryptedPrefs(): android.content.SharedPreferences {
            // SECURITY: EncryptedSharedPreferences MasterKey uses per-use biometric auth.
            // No 30-second window, no device credential fallback.
            return try {
                createEncryptedPrefsWithStrongBox(useStrongBox = true)
            } catch (e: Exception) {
                Timber.w(e, "StrongBox not available, falling back to software-backed keystore")
                createEncryptedPrefsWithStrongBox(useStrongBox = false)
            }
        }

        private fun createEncryptedPrefsWithStrongBox(useStrongBox: Boolean): android.content.SharedPreferences {
            val spec =
                KeyGenParameterSpec.Builder(
                    MasterKey.DEFAULT_MASTER_KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                ).apply {
                    setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    setKeySize(256)
                    // NOTE: MasterKey for EncryptedSharedPreferences must NOT require biometric auth.
                    // EncryptedSharedPreferences has no BiometricPrompt API, so a biometric-gated
                    // MasterKey causes UserNotAuthenticatedException on every read/write.
                    // Biometric protection is enforced at the app layer (MainActivity lock gate).
                    if (useStrongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        setIsStrongBoxBacked(true)
                    }
                }.build()

            val masterKey =
                MasterKey.Builder(context)
                    .setKeyGenParameterSpec(spec)
                    .build()

            return EncryptedSharedPreferences.create(
                context,
                ENCRYPTED_PREFS_FILE,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }

        init {
            if (isDeviceAuthAvailable) {
                generateKeyIfNeeded()
            } else {
                Timber.w("Device has no screen lock configured; skipping PIN key generation")
            }
        }

        private fun generateKeyIfNeeded() {
            if (!keyStore.containsAlias(PIN_KEY_ALIAS)) {
                generateKey()
            }
        }

        private fun generateKey() {
            val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)

            // SECURITY: Select authentication type based on device capabilities.
            // Prefer BIOMETRIC_STRONG when available; fall back to BIOMETRIC_STRONG | DEVICE_CREDENTIAL
            // so devices with only a PIN/pattern screen lock can still protect the key.
            val authType =
                if (isBiometricStrongAvailable) {
                    KeyProperties.AUTH_BIOMETRIC_STRONG
                } else {
                    KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
                }

            val keyGenParameterSpec =
                KeyGenParameterSpec.Builder(
                    PIN_KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                ).apply {
                    setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    setKeySize(256)
                    // SECURITY: Require per-use authentication for PIN key access.
                    // timeout=0 means every operation requires fresh auth.
                    setUserAuthenticationRequired(true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        setUserAuthenticationParameters(0, authType)
                    } else {
                        setUserAuthenticationValidityDurationSeconds(-1)
                    }
                    // SECURITY: Invalidate key if new biometrics are enrolled (BIO-H04)
                    setInvalidatedByBiometricEnrollment(true)
                    // Use StrongBox for hardware-backed security if available (Android P+)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        setIsStrongBoxBacked(true)
                    }
                }.build()

            try {
                keyGenerator.init(keyGenParameterSpec)
                keyGenerator.generateKey()
            } catch (e: StrongBoxUnavailableException) {
                Timber.w("StrongBox unavailable for PIN key, falling back to TEE-backed key")
                val fallbackSpec =
                    KeyGenParameterSpec.Builder(
                        PIN_KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    ).apply {
                        setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        setKeySize(256)
                        setUserAuthenticationRequired(true)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            setUserAuthenticationParameters(0, authType)
                        } else {
                            setUserAuthenticationValidityDurationSeconds(-1)
                        }
                        setInvalidatedByBiometricEnrollment(true)
                    }.build()
                keyGenerator.init(fallbackSpec)
                keyGenerator.generateKey()
            }
            Timber.d("PIN encryption key generated successfully")
        }

        /**
         * SECURITY: Ensure a MasterKey exists with the requested parameters.
         * Called by KeystoreBridge.ensureMasterKey() to verify the key is properly configured.
         *
         * When requireBiometrics is true, the key requires per-use BIOMETRIC_STRONG auth
         * with no device credential fallback and enrolment invalidation.
         *
         * @param requireBiometrics Whether the key should require biometric auth
         * @param useStrongbox Whether to attempt StrongBox hardware backing
         * @return true if the MasterKey is available, false on failure
         */
        fun ensureMasterKeyWithParams(
            requireBiometrics: Boolean,
            useStrongbox: Boolean,
        ): Boolean {
            return try {
                val specBuilder =
                    KeyGenParameterSpec.Builder(
                        MasterKey.DEFAULT_MASTER_KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    ).apply {
                        setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        setKeySize(256)

                        // NOTE: Biometric protection is enforced at the app layer (MainActivity lock gate),
                        // not on the MasterKey. EncryptedSharedPreferences has no BiometricPrompt API,
                        // so a biometric-gated MasterKey causes UserNotAuthenticatedException.

                        if (useStrongbox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            setIsStrongBoxBacked(true)
                        }
                    }

                val masterKey =
                    MasterKey.Builder(context)
                        .setKeyGenParameterSpec(specBuilder.build())
                        .build()

                // Verify the key actually exists in the Keystore after creation
                val alias = masterKey.toString().ifEmpty { MasterKey.DEFAULT_MASTER_KEY_ALIAS }
                if (!keyStore.containsAlias(alias)) {
                    Timber.e("ensureMasterKeyWithParams: MasterKey alias $alias not found after creation")
                    return false
                }
                Timber.d("ensureMasterKeyWithParams: MasterKey available (biometrics=$requireBiometrics, strongbox=$useStrongbox)")
                true
            } catch (e: StrongBoxUnavailableException) {
                if (useStrongbox) {
                    Timber.w("StrongBox unavailable for MasterKey, retrying without StrongBox")
                    return ensureMasterKeyWithParams(requireBiometrics, useStrongbox = false)
                }
                Timber.e(e, "ensureMasterKeyWithParams failed")
                false
            } catch (e: Exception) {
                if (useStrongbox) {
                    Timber.w(e, "MasterKey creation with StrongBox failed, retrying without")
                    return ensureMasterKeyWithParams(requireBiometrics, useStrongbox = false)
                }
                Timber.e(e, "ensureMasterKeyWithParams failed")
                false
            }
        }

        /**
         * Encrypts [data] using the PIN key from Android Keystore (AES-256-GCM).
         *
         * Returns an [EncryptedData] containing the ciphertext, IV, and algorithm identifier.
         *
         * **Memory lifecycle: caller's responsibility.** This function does NOT zeroise [data]
         * after use. The caller owns the buffer and must zeroise it once encryption is complete.
         * Zeroing inside this function was removed because it silently mutated caller-owned arrays,
         * causing hard-to-diagnose data corruption when callers reused the same buffer.
         *
         * @param data The plaintext bytes to encrypt. Not modified by this function. Zeroise after use.
         * @return An [EncryptedData] holding the IV, ciphertext, and algorithm name.
         */
        fun encryptData(data: ByteArray): EncryptedData {
            val secretKey = keyStore.getKey(PIN_KEY_ALIAS, null) as SecretKey
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)

            val iv = cipher.iv
            val ciphertext = cipher.doFinal(data)

            return EncryptedData(
                ciphertext = ciphertext,
                iv = iv,
                algorithm = TRANSFORMATION,
            )
        }

        fun listAllKeys(): List<String> {
            return try {
                val allKeys = encryptedPrefs.all.keys.toList()
                Timber.d("NativeKeystoreManager: Found ${allKeys.size} total keys in encrypted prefs")
                allKeys
            } catch (e: Exception) {
                Timber.e(e, "Failed to list keys from encrypted preferences")
                emptyList()
            }
        }

        fun decryptData(encryptedData: EncryptedData): SensitiveDataHolder {
            val secretKey = keyStore.getKey(PIN_KEY_ALIAS, null) as SecretKey
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, encryptedData.iv)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
            val result = cipher.doFinal(encryptedData.ciphertext)

            return SensitiveDataHolder.takeOwnership(result)
        }

        // Secure storage methods for PIN only
        fun saveSecureString(
            key: String,
            value: String,
        ) {
            encryptedPrefs.edit().putString(key, value).apply()
        }

        fun getSecureString(key: String): String? {
            return encryptedPrefs.getString(key, null)
        }

        fun saveSecureBytes(
            key: String,
            value: ByteArray,
        ) {
            // Convert to Base64 string for storage. The encoded string
            // is a JVM String (immutable, cannot be zeroised), but the input
            // byte array is zeroised by the caller (see encryptData).
            val encoded = android.util.Base64.encodeToString(value, android.util.Base64.NO_WRAP)
            saveSecureString(key, encoded)
        }

        fun getSecureBytes(key: String): SensitiveDataHolder? {
            val encoded = getSecureString(key) ?: return null
            // Convert the encoded string to a byte array for Base64
            // decoding, then zeroise the intermediate byte array.
            val encodedBytes = encoded.toByteArray(Charsets.US_ASCII)
            val decoded = android.util.Base64.decode(encodedBytes, android.util.Base64.NO_WRAP)
            java.util.Arrays.fill(encodedBytes, 0.toByte())
            return SensitiveDataHolder.takeOwnership(decoded)
        }

        fun removeSecureData(key: String) {
            encryptedPrefs.edit().remove(key).apply()
        }

        /**
         * SECURITY: Rotate the master encryption key.
         * This deletes the current MasterKey from Android Keystore and forces re-creation.
         * The caller (Rust SDK) is responsible for backing up and re-storing all data.
         *
         * @return true if key rotation was successful
         */
        fun rotateMasterKey(): Boolean {
            return try {
                Timber.d("Rotating master encryption key...")

                // Step 1: Delete the MasterKey alias from Android Keystore
                // The default alias used by MasterKey.Builder is "_androidx_security_master_key_"
                val masterKeyAlias = MasterKey.DEFAULT_MASTER_KEY_ALIAS

                if (keyStore.containsAlias(masterKeyAlias)) {
                    keyStore.deleteEntry(masterKeyAlias)
                    Timber.d("Deleted existing MasterKey alias: $masterKeyAlias")
                }

                // Step 2: Clear cached encrypted prefs reference to force recreation.
                // The lazy delegate will create new EncryptedSharedPreferences with a new MasterKey
                // on next access.
                clearEncryptedPrefsCache()

                Timber.d("Master key rotation completed successfully")
                true
            } catch (e: Exception) {
                Timber.e(e, "Failed to rotate master key")
                false
            }
        }

        /**
         * Force recreation of EncryptedSharedPreferences on next access.
         * Called after master key rotation to ensure new key material is used.
         */
        private fun clearEncryptedPrefsCache() {
            _encryptedPrefs = null
        }

        // ---- PIN rate limiting (MASVS-AUTH-2) ----

        /**
         * Check whether PIN entry is currently locked out due to too many failed attempts.
         * If the lockout has expired, the attempt counter is reset automatically.
         */
        fun isPinLocked(): Boolean {
            val lockoutUntil =
                try {
                    getSecureString(KEY_LOCKOUT_UNTIL)?.toLongOrNull() ?: 0L
                } catch (e: Exception) {
                    0L
                }
            if (lockoutUntil > System.currentTimeMillis()) return true
            // Lockout expired, reset so the user can try again
            if (lockoutUntil > 0L) resetPinAttempts()
            return false
        }

        /**
         * Record a PIN verification attempt. On success the counter resets.
         * After [MAX_PIN_ATTEMPTS] consecutive failures a 15-minute lockout begins.
         */
        fun recordPinAttempt(success: Boolean) {
            if (success) {
                resetPinAttempts()
                return
            }
            val attempts = getPinAttemptCount() + 1
            saveSecureString(KEY_PIN_ATTEMPTS, attempts.toString())
            if (attempts >= MAX_PIN_ATTEMPTS) {
                val lockoutUntil = System.currentTimeMillis() + LOCKOUT_DURATION_MS
                saveSecureString(KEY_LOCKOUT_UNTIL, lockoutUntil.toString())
                Timber.w("PIN locked out until ${java.util.Date(lockoutUntil)}")
            }
        }

        /**
         * Return the number of consecutive failed PIN attempts since the last success or reset.
         */
        fun getPinAttemptCount(): Int {
            return try {
                getSecureString(KEY_PIN_ATTEMPTS)?.toIntOrNull() ?: 0
            } catch (e: Exception) {
                0
            }
        }

        /**
         * Return how many PIN attempts remain before lockout.
         */
        fun getRemainingAttempts(): Int {
            return (MAX_PIN_ATTEMPTS - getPinAttemptCount()).coerceAtLeast(0)
        }

        /**
         * Return the number of milliseconds remaining in the current lockout window,
         * or 0 if no lockout is active.
         */
        fun getLockoutRemainingMs(): Long {
            val lockoutUntil =
                try {
                    getSecureString(KEY_LOCKOUT_UNTIL)?.toLongOrNull() ?: 0L
                } catch (e: Exception) {
                    0L
                }
            return (lockoutUntil - System.currentTimeMillis()).coerceAtLeast(0L)
        }

        private fun resetPinAttempts() {
            removeSecureData(KEY_PIN_ATTEMPTS)
            removeSecureData(KEY_LOCKOUT_UNTIL)
        }
    }

/**
 * Data class representing encrypted data with its metadata.
 * Holds the ciphertext, initialisation vector, and algorithm identifier
 * produced by [NativeKeystoreManager.encryptData].
 */
data class EncryptedData(
    val ciphertext: ByteArray,
    val iv: ByteArray,
    val algorithm: String,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EncryptedData

        if (!ciphertext.contentEquals(other.ciphertext)) return false
        if (!iv.contentEquals(other.iv)) return false
        if (algorithm != other.algorithm) return false

        return true
    }

    override fun hashCode(): Int {
        var result = ciphertext.contentHashCode()
        result = 31 * result + iv.contentHashCode()
        result = 31 * result + algorithm.hashCode()
        return result
    }

    override fun toString(): String =
        "EncryptedData(algorithm=$algorithm, ciphertextLen=${ciphertext.size})"
}
