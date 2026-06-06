// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import app.provii.wallet.security.NativeKeystoreManager
import app.provii.wallet.security.SensitiveDataHolder
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.inject.Inject
import javax.inject.Singleton
import timber.log.Timber
import java.security.KeyStore
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * Bridge class expected by the Rust SDK's android_storage.rs.
 *
 * SECURITY: All biometric-protected operations fail CLOSED. If biometric
 * authentication cannot be performed (no Activity, hardware unavailable,
 * user cancellation), the operation returns false / null.
 */
@Singleton
class KeystoreBridge
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        private val keystoreManager: NativeKeystoreManager,
    ) {
        companion object {
            private const val KEY_PREFIX = "provii_sdk_"
            private const val BIOMETRIC_KEY_ALIAS = "provii_biometric_auth_key"
            private const val STORAGE_BIOMETRIC_KEY_PREFIX = "provii_bio_storage_"
            private const val ANDROID_KEYSTORE = "AndroidKeyStore"
            private const val TRANSFORMATION = "AES/GCM/NoPadding"
            private const val GCM_TAG_LENGTH = 128
            private const val BIOMETRIC_PROMPT_TIMEOUT_MS = 60_000L

            @Volatile
            private var instance: KeystoreBridge? = null

            @JvmStatic
            fun getInstance(context: Context): KeystoreBridge {
                return instance ?: synchronized(this) {
                    instance ?: run {
                        val appCtx = context.applicationContext
                        val nkm = app.provii.wallet.security.NativeKeystoreManager(appCtx)
                        KeystoreBridge(appCtx, nkm).also { created ->
                            instance = created
                            Timber.d("KeystoreBridge lazily constructed (no DI)")
                        }
                    }
                }
            }

            internal fun setInstance(bridge: KeystoreBridge) {
                instance = bridge
                Timber.d("KeystoreBridge instance registered")
            }
        }

        private val keyStore: KeyStore =
            KeyStore.getInstance(ANDROID_KEYSTORE).apply {
                load(null)
            }

        init {
            setInstance(this)
            ensureBiometricKeyExists()
        }

        /**
         * SECURITY: Ensure the biometric authentication key exists.
         * This key is used to bind biometric authentication to a cryptographic operation
         * per MASVS-AUTH-1 and MASVS-AUTH-3 requirements.
         */
        private fun ensureBiometricKeyExists() {
            if (!keyStore.containsAlias(BIOMETRIC_KEY_ALIAS)) {
                generateBiometricKey()
            }
        }

        /**
         * SECURITY: Generate a key that requires biometric authentication for every use.
         * The key is bound to biometric auth and cannot be used without successful authentication.
         * Uses setUserAuthenticationParameters(0, AUTH_TYPE_BIOMETRIC) for per-use auth
         * (timeout 0 means every operation requires fresh biometric authentication).
         */
        private fun generateBiometricKey() {
            val keyGenerator =
                KeyGenerator.getInstance(
                    KeyProperties.KEY_ALGORITHM_AES,
                    ANDROID_KEYSTORE,
                )

            try {
                val spec = buildBiometricKeySpec(BIOMETRIC_KEY_ALIAS, useStrongbox = true)
                keyGenerator.init(spec)
                keyGenerator.generateKey()
                Timber.d("Biometric authentication key generated with StrongBox")
            } catch (e: Exception) {
                Timber.w(e, "StrongBox unavailable for biometric key, falling back to TEE")
                try {
                    val spec = buildBiometricKeySpec(BIOMETRIC_KEY_ALIAS, useStrongbox = false)
                    keyGenerator.init(spec)
                    keyGenerator.generateKey()
                    Timber.d("Biometric authentication key generated (TEE-backed)")
                } catch (e2: Exception) {
                    Timber.e(e2, "Failed to generate biometric key entirely")
                }
            }
        }

        /**
         * SECURITY: Build a KeyGenParameterSpec for biometric-protected keys.
         * All biometric keys share these properties:
         *   - AES-256-GCM
         *   - Per-use biometric authentication (timeout = 0, type = BIOMETRIC only)
         *   - Invalidated on biometric enrollment change
         *   - Optional StrongBox backing
         */
        private fun buildBiometricKeySpec(
            alias: String,
            useStrongbox: Boolean,
        ): KeyGenParameterSpec {
            return KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            ).apply {
                setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                setKeySize(256)
                // SECURITY: Require biometric authentication for every key use
                setUserAuthenticationRequired(true)
                // SECURITY: timeout=0 means every-use auth; AUTH_BIOMETRIC_STRONG only,
                // no device credential (PIN/pattern) fallback
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                } else {
                    // Pre-API 30: timeout of -1 means every-use authentication
                    setUserAuthenticationValidityDurationSeconds(-1)
                }
                // SECURITY: Invalidate key if new biometrics are enrolled
                setInvalidatedByBiometricEnrollment(true)
                if (useStrongbox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    setIsStrongBoxBacked(true)
                }
            }.build()
        }

        /**
         * SECURITY: Get a cipher initialised for encryption with the biometric-bound key.
         * This cipher can only be used after successful biometric authentication.
         * @return Cipher ready for use in BiometricPrompt.CryptoObject
         */
        private fun getCipherForBiometricAuth(): Cipher {
            val secretKey = keyStore.getKey(BIOMETRIC_KEY_ALIAS, null) as SecretKey
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            return cipher
        }

        /**
         * SECURITY: Ensure the master encryption key exists with the requested parameters.
         * Delegates to NativeKeystoreManager to create an appropriately configured MasterKey.
         *
         * @param useStrongbox Whether to attempt StrongBox hardware backing
         * @param requireBiometrics Whether the key should require biometric auth
         * @return true if the master key is available, false if creation failed
         */
        fun ensureMasterKey(
            useStrongbox: Boolean,
            requireBiometrics: Boolean,
        ): Boolean {
            Timber.d("ensureMasterKey called: strongbox=$useStrongbox, biometrics=$requireBiometrics")
            return try {
                keystoreManager.ensureMasterKeyWithParams(
                    requireBiometrics = requireBiometrics,
                    useStrongbox = useStrongbox,
                )
            } catch (e: Exception) {
                Timber.e(e, "ensureMasterKey failed")
                false
            }
        }

        fun initialise(
            requireBiometrics: Boolean,
            useStrongbox: Boolean,
        ) {
            Timber.d("initialise called: biometrics=$requireBiometrics, strongbox=$useStrongbox")
            keystoreManager.saveSecureString("${KEY_PREFIX}config_biometrics", requireBiometrics.toString())
            keystoreManager.saveSecureString("${KEY_PREFIX}config_strongbox", useStrongbox.toString())
        }

        /**
         * SECURITY: Store data securely, honouring both requireBiometrics and useStrongbox flags.
         *
         * When requireBiometrics is true, data is encrypted with a per-use biometric-protected
         * Keystore key. The biometric prompt MUST have already been completed via
         * requireBiometricAuth() before calling this method, or this method will fail closed.
         *
         * When useStrongbox is true, the encryption key is backed by StrongBox hardware
         * (with TEE fallback if StrongBox is unavailable).
         */
        fun storeSecure(
            key: String,
            data: ByteArray,
            useStrongbox: Boolean,
            requireBiometrics: Boolean,
        ): Boolean {
            return try {
                Timber.d("storeSecure called: dataSize=${data.size} bytes, useStrongbox=$useStrongbox, requireBiometrics=$requireBiometrics")

                if (requireBiometrics) {
                    // SECURITY: For biometric-protected storage, we use a dedicated biometric key
                    // per storage item. The caller MUST complete biometric auth via the Activity
                    // path before this data can be retrieved.
                    val storageKeyAlias = "$STORAGE_BIOMETRIC_KEY_PREFIX$key"
                    ensureBiometricStorageKey(storageKeyAlias, useStrongbox)
                }

                keystoreManager.saveSecureBytes("$KEY_PREFIX$key", data)

                // Verify it was actually saved
                val verifyData: SensitiveDataHolder? = keystoreManager.getSecureBytes("$KEY_PREFIX$key")
                if (verifyData != null) {
                    Timber.d("  - Verification: Data was saved and retrieved successfully (${verifyData.size} bytes)")
                    verifyData.close()
                } else {
                    Timber.e("  - Verification FAILED: Could not retrieve data immediately after saving")
                    return false
                }

                true
            } catch (e: Exception) {
                Timber.e(e, "storeSecure failed")
                false
            }
        }

        /**
         * SECURITY: Ensure a biometric-protected Keystore key exists for a storage item.
         * This key requires per-use biometric auth (timeout=0, AUTH_BIOMETRIC_STRONG only).
         */
        private fun ensureBiometricStorageKey(
            alias: String,
            useStrongbox: Boolean,
        ) {
            if (keyStore.containsAlias(alias)) return

            val keyGenerator =
                KeyGenerator.getInstance(
                    KeyProperties.KEY_ALGORITHM_AES,
                    ANDROID_KEYSTORE,
                )

            try {
                val spec = buildBiometricKeySpec(alias, useStrongbox)
                keyGenerator.init(spec)
                keyGenerator.generateKey()
                Timber.d("Biometric storage key created: $alias (StrongBox=$useStrongbox)")
            } catch (e: StrongBoxUnavailableException) {
                Timber.w("StrongBox unavailable for storage key $alias, falling back to TEE")
                val spec = buildBiometricKeySpec(alias, useStrongbox = false)
                keyGenerator.init(spec)
                keyGenerator.generateKey()
                Timber.d("Biometric storage key created: $alias (TEE-backed)")
            } catch (e: Exception) {
                // If key creation fails with StrongBox, retry without
                if (useStrongbox) {
                    Timber.w(e, "Key creation with StrongBox failed for $alias, retrying without")
                    val spec = buildBiometricKeySpec(alias, useStrongbox = false)
                    keyGenerator.init(spec)
                    keyGenerator.generateKey()
                    Timber.d("Biometric storage key created: $alias (TEE-backed, after StrongBox failure)")
                } else {
                    throw e
                }
            }
        }

        /**
         * SECURITY: Retrieve secure data with optional biometric authentication.
         *
         * When requireBiometrics is true, this method FAILS CLOSED (returns null) because
         * biometric authentication requires an Activity context that is not available from
         * the Rust FFI path. Callers must use the Activity-based path instead:
         *   1. Call requireBiometricAuth(activity, reason) to authenticate the user
         *   2. On success, call retrieveSecure() with requireBiometrics=false
         *
         * This ensures biometric auth is never silently bypassed.
         */
        fun retrieveSecure(
            key: String,
            requireBiometrics: Boolean,
        ): SensitiveDataHolder? {
            return try {
                Timber.d("retrieveSecure called: requireBiometrics=$requireBiometrics")

                if (requireBiometrics) {
                    // SECURITY: Fail CLOSED. Biometric authentication requires a FragmentActivity
                    // to show the BiometricPrompt. This non-Activity path cannot authenticate,
                    // so it must refuse the operation entirely.
                    Timber.e(
                        "retrieveSecure: biometric auth required but no Activity context available. " +
                            "Caller must use requireBiometricAuth(activity) before retrieving data.",
                    )
                    return null
                }

                val data = keystoreManager.getSecureBytes("$KEY_PREFIX$key")

                if (data != null) {
                    Timber.d("  - Retrieved ${data.size} bytes successfully")
                } else {
                    Timber.d("  - No data found")
                }

                data
            } catch (e: Exception) {
                Timber.e(e, "retrieveSecure failed")
                null
            }
        }

        fun deleteSecure(key: String): Boolean {
            return try {
                Timber.d("deleteSecure called")
                keystoreManager.removeSecureData("$KEY_PREFIX$key")
                // Also clean up any biometric storage key for this item
                val storageKeyAlias = "$STORAGE_BIOMETRIC_KEY_PREFIX$key"
                if (keyStore.containsAlias(storageKeyAlias)) {
                    keyStore.deleteEntry(storageKeyAlias)
                    Timber.d("  - Deleted biometric storage key: $storageKeyAlias")
                }
                true
            } catch (e: Exception) {
                Timber.e(e, "deleteSecure failed")
                false
            }
        }

        /**
         * List SDK key aliases in the Android Keystore.
         *
         * Returns all Keystore aliases that carry the SDK prefix ([KEY_PREFIX]),
         * with the prefix stripped. Aliases for other apps or unrelated system keys
         * are excluded by the prefix filter.
         */
        fun listKeys(): Array<String> {
            return try {
                val allKeys = keystoreManager.listAllKeys()

                val sdkKeys =
                    allKeys
                        .filter { it.startsWith(KEY_PREFIX) }
                        .map { it.removePrefix(KEY_PREFIX) }

                Timber.d("listKeys: found ${sdkKeys.size} SDK keys")

                sdkKeys.toTypedArray()
            } catch (e: Exception) {
                Timber.e(e, "Failed to list keys")
                emptyArray()
            }
        }

        /**
         * SECURITY: Check biometric availability only. Does NOT authenticate the user.
         *
         * This method is called from the Rust FFI path which lacks an Activity context.
         * It returns false (fail closed) with an error indicating the caller must use
         * the Activity-based authentication path instead.
         *
         * For actual biometric authentication, use:
         *   - requireBiometricAuth(activity, reason) for blocking auth from any thread
         *   - authenticateBiometricFromActivity(activity, reason, timeout) for suspend/coroutine auth
         */
        fun authenticateBiometric(
            reason: String,
            timeoutMs: Int,
        ): Boolean {
            Timber.d("authenticateBiometric: reason=$reason, timeout=$timeoutMs")

            // SECURITY: Fail CLOSED. This non-Activity path cannot show a BiometricPrompt,
            // so it must never return true. Returning true without actually authenticating
            // would silently bypass biometric protection (BIO-C01).
            val biometricManager = BiometricManager.from(context)
            val canAuthenticate =
                biometricManager.canAuthenticate(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG,
                )

            when (canAuthenticate) {
                BiometricManager.BIOMETRIC_SUCCESS -> {
                    Timber.e(
                        "authenticateBiometric: biometric hardware is available, but this method " +
                            "cannot show a prompt without an Activity. Use requireBiometricAuth(activity) instead.",
                    )
                    return false
                }
                BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> {
                    Timber.e("No biometric hardware available")
                    return false
                }
                BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> {
                    Timber.e("Biometric hardware unavailable")
                    return false
                }
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
                    Timber.e("No biometric credentials enrolled")
                    return false
                }
                else -> {
                    Timber.e("Biometric authentication not available: $canAuthenticate")
                    return false
                }
            }
        }

        /**
         * SECURITY: Check whether biometric authentication hardware is available
         * without attempting authentication. Safe to call from any context.
         *
         * @return true if BIOMETRIC_STRONG hardware is available and enrolled
         */
        fun isBiometricAvailable(): Boolean {
            val biometricManager = BiometricManager.from(context)
            return biometricManager.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG,
            ) == BiometricManager.BIOMETRIC_SUCCESS
        }

        /**
         * SECURITY: Perform biometric authentication with crypto-binding from an Activity context.
         * This is the BLOCKING (non-suspend) variant for use from non-coroutine callers.
         *
         * Uses a CompletableFuture internally so it can be called from any thread.
         * The BiometricPrompt is posted to the Activity's main executor.
         *
         * MASVS-AUTH-1, MASVS-AUTH-3: Authentication is bound to a CryptoObject.
         * Only BIOMETRIC_STRONG is accepted; no PIN/pattern/device credential fallback.
         *
         * @param activity The FragmentActivity to host the BiometricPrompt
         * @param reason User-visible subtitle explaining why authentication is needed
         * @return true only if biometric auth succeeded with a valid CryptoObject
         */
        fun requireBiometricAuth(
            activity: FragmentActivity,
            reason: String,
        ): Boolean {
            Timber.d("requireBiometricAuth: reason=$reason")

            val future = CompletableFuture<Boolean>()

            // SECURITY: Get cipher bound to biometric-authenticated key.
            // This cipher can only be used after successful biometric authentication.
            val cipher: Cipher
            try {
                cipher = getCipherForBiometricAuth()
            } catch (e: Exception) {
                Timber.e(e, "Failed to get cipher for biometric auth, regenerating key")
                try {
                    generateBiometricKey()
                } catch (e2: Exception) {
                    Timber.e(e2, "Failed to regenerate biometric key")
                }
                return false
            }

            val cryptoObject = BiometricPrompt.CryptoObject(cipher)

            // BiometricPrompt must be created and shown on the main thread
            val executor = ContextCompat.getMainExecutor(activity)
            executor.execute {
                try {
                    val biometricPrompt =
                        BiometricPrompt(
                            activity,
                            executor,
                            object : BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                                    super.onAuthenticationSucceeded(result)
                                    val authenticatedCipher = result.cryptoObject?.cipher
                                    if (authenticatedCipher != null) {
                                        Timber.d("requireBiometricAuth: succeeded with crypto binding")
                                        future.complete(true)
                                    } else {
                                        Timber.e("requireBiometricAuth: succeeded but CryptoObject missing")
                                        future.complete(false)
                                    }
                                }

                                override fun onAuthenticationError(
                                    errorCode: Int,
                                    errString: CharSequence,
                                ) {
                                    super.onAuthenticationError(errorCode, errString)
                                    Timber.e("requireBiometricAuth error: $errorCode - $errString")
                                    future.complete(false)
                                }

                                override fun onAuthenticationFailed() {
                                    super.onAuthenticationFailed()
                                    Timber.w("requireBiometricAuth: attempt failed (user can retry)")
                                    // Don't complete the future; the user can retry
                                }
                            },
                        )

                    // SECURITY: BIOMETRIC_STRONG only. No DEVICE_CREDENTIAL fallback.
                    // Device credential cannot be bound to a CryptoObject.
                    val promptInfo =
                        BiometricPrompt.PromptInfo.Builder()
                            .setTitle(context.getString(R.string.keystore_biometric_prompt_title))
                            .setSubtitle(reason)
                            .setNegativeButtonText(context.getString(R.string.keystore_biometric_prompt_cancel))
                            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                            .build()

                    biometricPrompt.authenticate(promptInfo, cryptoObject)
                } catch (e: Exception) {
                    Timber.e(e, "requireBiometricAuth: failed to show prompt")
                    future.complete(false)
                }
            }

            return try {
                future.get(BIOMETRIC_PROMPT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            } catch (e: TimeoutException) {
                Timber.e("requireBiometricAuth: timed out after ${BIOMETRIC_PROMPT_TIMEOUT_MS}ms")
                false
            } catch (e: Exception) {
                Timber.e(e, "requireBiometricAuth: unexpected error waiting for result")
                false
            }
        }

        /**
         * SECURITY: Authenticate with biometric from Activity context (suspend/coroutine variant).
         * This implementation binds biometric authentication to a cryptographic operation
         * per MASVS-AUTH-1 and MASVS-AUTH-3 requirements to prevent biometric bypass attacks.
         *
         * Only BIOMETRIC_STRONG is accepted; no PIN/pattern/device credential fallback.
         * The authentication is bound to a CryptoObject containing a cipher that can only
         * be used after successful biometric verification.
         */
        suspend fun authenticateBiometricFromActivity(
            activity: FragmentActivity,
            reason: String,
            timeoutMs: Int,
        ): Boolean =
            suspendCoroutine { continuation ->
                Timber.d("authenticateBiometricFromActivity: reason=$reason")

                // SECURITY: Get cipher bound to biometric-authenticated key
                val cipher: Cipher
                try {
                    cipher = getCipherForBiometricAuth()
                } catch (e: Exception) {
                    Timber.e(e, "Failed to get cipher for biometric auth")
                    // Key may have been invalidated by biometric enrollment change
                    try {
                        generateBiometricKey()
                        continuation.resume(false)
                        return@suspendCoroutine
                    } catch (e2: Exception) {
                        Timber.e(e2, "Failed to regenerate biometric key")
                        continuation.resume(false)
                        return@suspendCoroutine
                    }
                }

                val cryptoObject = BiometricPrompt.CryptoObject(cipher)

                val executor = ContextCompat.getMainExecutor(activity)
                val biometricPrompt =
                    BiometricPrompt(
                        activity,
                        executor,
                        object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                                super.onAuthenticationSucceeded(result)
                                val authenticatedCipher = result.cryptoObject?.cipher
                                if (authenticatedCipher != null) {
                                    Timber.d("Biometric authentication succeeded with crypto binding")
                                    continuation.resume(true)
                                } else {
                                    Timber.e("Biometric authentication succeeded but CryptoObject was not used")
                                    continuation.resume(false)
                                }
                            }

                            override fun onAuthenticationError(
                                errorCode: Int,
                                errString: CharSequence,
                            ) {
                                super.onAuthenticationError(errorCode, errString)
                                Timber.e("Biometric authentication error: $errorCode - $errString")
                                continuation.resume(false)
                            }

                            override fun onAuthenticationFailed() {
                                super.onAuthenticationFailed()
                                Timber.w("Biometric authentication failed")
                                // Don't resume here; user can retry
                            }
                        },
                    )

                // SECURITY: BIOMETRIC_STRONG only. No DEVICE_CREDENTIAL fallback.
                val promptInfo =
                    BiometricPrompt.PromptInfo.Builder()
                        .setTitle(context.getString(R.string.keystore_biometric_prompt_title))
                        .setSubtitle(reason)
                        .setNegativeButtonText(context.getString(R.string.keystore_biometric_prompt_cancel))
                        .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                        .build()

                biometricPrompt.authenticate(promptInfo, cryptoObject)
            }

        /**
         * SECURITY: Rotate the master encryption key.
         * Called by Rust SDK's store-android rotate_master_key() implementation.
         * The Rust SDK handles backing up and re-storing all data before/after this call.
         *
         * @return true if key rotation was successful
         */
        fun rotateMasterKey(): Boolean {
            Timber.d("rotateMasterKey called")
            return try {
                val result = keystoreManager.rotateMasterKey()
                Timber.d("rotateMasterKey result: $result")
                result
            } catch (e: Exception) {
                Timber.e(e, "rotateMasterKey failed")
                false
            }
        }
    }
