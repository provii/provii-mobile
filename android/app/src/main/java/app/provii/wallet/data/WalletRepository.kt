// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import android.content.Context
import android.os.StatFs
import app.provii.wallet.R
import android.util.Base64
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.config.SandboxCredentialFetcher
import app.provii.wallet.sdk.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton
import java.io.File
import app.provii.wallet.logging.redactId
import app.provii.wallet.network.HmacSigner
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlin.math.max
import kotlin.math.min
import kotlin.ExperimentalUnsignedTypes
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import android.content.SharedPreferences
import androidx.annotation.VisibleForTesting
import androidx.fragment.app.FragmentActivity
import app.provii.wallet.KeystoreBridge
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * Exception thrown when user authentication is required but not completed.
 */
class AuthenticationRequiredException(message: String = "User authentication required") : Exception(message)

/**
 * Central repository coordinating wallet lifecycle, credential storage, proof generation, and
 * sandbox issuance flows. Wraps the Rust SDK's [ProviiWallet] instance behind a thread-safe
 * initialisation mutex and exposes reactive [StateFlow] properties for credential and setup
 * state. Proof generation requires biometric authentication via [KeystoreBridge] before the
 * SDK's prover is invoked. Environment-aware: verifier URLs and sandbox credentials are
 * synchronised with [EnvironmentManager] before every network operation.
 */
@Singleton
class WalletRepository
    @Inject
    constructor(
        private val appContext: Context,
        private val auditLogger: app.provii.wallet.security.AuditLogger,
        private val keystoreBridge: KeystoreBridge,
        private val httpClient: OkHttpClient,
    ) {
        companion object {
            private const val TAG = "WalletRepository"
            private const val VK_ID = 2031517468
            private const val PROVING_KEY_FILENAME = "age_pk.$VK_ID.bin"

            /**
             * Creates a WalletRepository with a pre-injected [ProviiWalletInterface] for
             * unit testing. Bypasses Hilt DI. Not for production use.
             */
            @VisibleForTesting
            internal fun createForTesting(
                appContext: Context,
                walletInterface: ProviiWalletInterface,
                auditLogger: app.provii.wallet.security.AuditLogger,
                keystoreBridge: KeystoreBridge,
                httpClient: OkHttpClient = OkHttpClient(),
            ): WalletRepository {
                val repo = WalletRepository(appContext, auditLogger, keystoreBridge, httpClient)
                repo.wallet = walletInterface
                repo.proverInitialized.set(true)
                return repo
            }
        }

        // Sandbox configuration constants (non-credential values)
        private object SandboxConstants {
            const val SCHEMA = "provii.age/1"
            const val LABEL = "sandbox"
            const val MAX_VALIDITY_DAYS = 36500
            const val DEFAULT_VALIDITY_DAYS = 36500
        }

        // Get issuer base URL from EnvironmentManager
        private val issuerBaseUrl: String
            get() = EnvironmentManager.getIssuerApi()

        private var wallet: ProviiWalletInterface? = null
        private val proverInitialized = AtomicBoolean(false)
        private val lastProverInitTime = AtomicLong(0L)

        // Add mutex for thread-safe initialisation
        private val initializationMutex = Mutex()
        private var isInitializing = false

        // Single credential state - no list
        private val _credentialState = MutableStateFlow<CredentialState>(CredentialState.None)
        val credentialState: StateFlow<CredentialState> = _credentialState.asStateFlow()

        private val _isProcessing = MutableStateFlow(false)
        val isProcessing: StateFlow<Boolean> = _isProcessing.asStateFlow()

        // Wallet readiness: true only after initializeWallet() succeeds in the
        // current process lifetime. Not persisted across process death.
        private val _isReady = MutableStateFlow(false)
        val isReady: StateFlow<Boolean> = _isReady.asStateFlow()

        // Setup state for proving key
        private val _setupState = MutableStateFlow<SetupState>(SetupState.NotStarted)
        val setupState: StateFlow<SetupState> = _setupState.asStateFlow()

        sealed class CredentialState {
            object None : CredentialState()

            data class HasCredentials(
                val primary: StoredCredentialInfo? = null,
                val managed: List<StoredCredentialInfo> = emptyList(),
            ) : CredentialState()
        }

        /** Lightweight credential info for state tracking */
        data class StoredCredentialInfo(
            val id: String,
            val credentialType: String,
            val nickname: String?,
            val canProve: Boolean,
            val isExpired: Boolean,
        ) {
            /** Nullable display name. UI layer resolves fallback via stringResource. */
            val displayName: String? get() = nickname
            val isManaged: Boolean get() = credentialType == "managed"

            override fun toString() = "StoredCredentialInfo(id=${id.take(8)}..., credentialType=$credentialType, isExpired=$isExpired)"
        }

        sealed class SetupState {
            object NotStarted : SetupState()

            object Checking : SetupState()

            data class Downloading(val progress: Float, val downloadedMB: Float, val totalMB: Float) : SetupState()

            object Initialising : SetupState()

            object Ready : SetupState()

            data class Error(
                val message: String,
                val canRetry: Boolean = true,
                val requiresAction: SetupAction? = null,
            ) : SetupState()
        }

        enum class SetupAction {
            FREE_STORAGE,
            CHECK_NETWORK,
            CONTACT_SUPPORT,
        }

        sealed class QrAction {
            data class VerificationChallenge(val challengeJson: String) : QrAction()

            data class Attestation(val attestationData: String) : QrAction()

            object Unknown : QrAction()

            data class Error(val message: String) : QrAction()
        }

        // === Debug Helpers ===

        private fun logMemoryStatus(context: String) {
            val runtime = Runtime.getRuntime()
            val usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1048576L
            val maxMemory = runtime.maxMemory() / 1048576L
            val availableMemory = maxMemory - usedMemory
            Timber.d("[$context] Memory: ${usedMemory}MB used, ${availableMemory}MB available of ${maxMemory}MB max")
        }

        private suspend fun logProverState(context: String) {
            try {
                wallet?.let { w ->
                    val diagnostics = w.getDiagnosticInfo()
                    Timber.d("===== PROVER STATE CHECK: $context =====")
                    Timber.d("  Environment: ${EnvironmentManager.getCurrentEnvironment()}")
                    Timber.d("  Wallet instance: ${w.hashCode()}")
                    Timber.d("  Prover initialised (SDK): ${diagnostics.proverInitialized}")
                    Timber.d("  Prover initialised (local): ${proverInitialized.get()}")
                    Timber.d("  Last init time: ${if (lastProverInitTime.get() > 0) "${(System.currentTimeMillis() - lastProverInitTime.get()) / 1000}s ago" else "never"}")
                    Timber.d("  SDK version: ${diagnostics.sdkVersion}")
                    Timber.d("  Credential count: ${diagnostics.credentialCount}")
                    Timber.d("=========================================")
                } ?: Timber.d("[$context] Wallet is null!")
            } catch (e: Exception) {
                Timber.e("[$context] Error checking prover state: ${e.message}")
            }
        }

        // === Prover Management ===

        private suspend fun ensureProverInitialized(): Result<Unit> =
            withContext(Dispatchers.IO) {
                Timber.d("ensureProverInitialized() called (${EnvironmentManager.getCurrentEnvironment()} environment)")
                logMemoryStatus("Before prover init")

                val w = wallet
                if (w == null) {
                    Timber.e("ensureProverInitialized: Wallet is null!")
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_not_initialized)))
                }

                // First check SDK's view of prover state
                try {
                    val diagnostics = w.getDiagnosticInfo()
                    Timber.d("Current prover state from SDK: ${diagnostics.proverInitialized}")
                    Timber.d("Wallet instance being used: ${w.hashCode()}")

                    if (diagnostics.proverInitialized == true && proverInitialized.get()) {
                        val timeSinceInit = (System.currentTimeMillis() - lastProverInitTime.get()) / 1000
                        Timber.d("Prover already initialised ${timeSinceInit}s ago, skipping init")
                        return@withContext Result.success(Unit)
                    }

                    if (diagnostics.proverInitialized == true && !proverInitialized.get()) {
                        Timber.w("SDK says prover is initialised but local flag is false - updating flag")
                        proverInitialized.set(true)
                        lastProverInitTime.set(System.currentTimeMillis())
                        return@withContext Result.success(Unit)
                    }
                } catch (e: Exception) {
                    Timber.e("Error checking diagnostics: ${e.message}")
                }

                // Need to initialise prover
                Timber.d("Prover needs initialisation")

                val filesDir = appContext.filesDir.absolutePath
                val pkFile = File(filesDir, PROVING_KEY_FILENAME)

                Timber.d("Proving key file: ${pkFile.absolutePath}")
                Timber.d("  Exists: ${pkFile.exists()}")
                Timber.d("  Readable: ${pkFile.canRead()}")
                Timber.d("  Size: ${pkFile.length() / 1048576}MB")

                if (!pkFile.exists()) {
                    Timber.e("Proving key file does not exist!")
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_proving_key_not_found)))
                }

                if (!pkFile.canRead()) {
                    Timber.e("Proving key file exists but is not readable!")
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_proving_key_not_readable)))
                }

                try {
                    Timber.d("Loading proving key into memory...")
                    val pkBytes = pkFile.readBytes()
                    Timber.d("Loaded ${pkBytes.size} bytes (${pkBytes.size / 1048576}MB)")

                    logMemoryStatus("After loading PK bytes")

                    // Try wallet method first
                    Timber.d("Attempting wallet.initialiseProver()...")
                    try {
                        w.initializeProver(pkBytes)
                        Timber.d("wallet.initialiseProver() completed without exception")
                    } catch (e: FfiException.Prover) {
                        Timber.e("wallet.initialiseProver() failed with Prover error: ${e.msg}")
                        Timber.d("Attempting global sdkInitProver() as fallback...")

                        try {
                            sdkInitProver(pkBytes)
                            Timber.d("sdkInitProver() completed without exception")
                        } catch (e2: Exception) {
                            Timber.e("sdkInitProver() also failed: ${e2.message}")
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_prover_error, e.msg)))
                        }
                    }

                    // Verify initialisation worked
                    Timber.d("Verifying prover initialisation...")
                    val postInitDiagnostics = w.getDiagnosticInfo()

                    if (postInitDiagnostics.proverInitialized == true) {
                        proverInitialized.set(true)
                        lastProverInitTime.set(System.currentTimeMillis())
                        Timber.d("✔ PROVER INITIALIZED SUCCESSFULLY")
                        Timber.d("  Verification: SDK reports prover is initialised")
                        logMemoryStatus("After successful prover init")
                        return@withContext Result.success(Unit)
                    } else {
                        Timber.e("PROVER INITIALISATION FAILED")
                        Timber.e("  Initialisation appeared to succeed but SDK still reports prover not initialised")
                        proverInitialized.set(false)
                        return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_prover_verification_failed)))
                    }
                } catch (e: OutOfMemoryError) {
                    Timber.e(e, "OUT OF MEMORY loading proving key")
                    logMemoryStatus("After OOM")
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_out_of_memory)))
                } catch (e: FfiException.Prover) {
                    Timber.e("FFI Prover error: ${e.msg}")
                    proverInitialized.set(false)
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_prover_error, e.msg)))
                } catch (e: FfiException) {
                    Timber.e("FFI error: ${e.message}")
                    proverInitialized.set(false)
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_ffi_error, e.message ?: "Unknown")))
                } catch (e: Exception) {
                    Timber.e(e, "Unexpected error initialising prover")
                    proverInitialized.set(false)
                    return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_prover_init_failed, e.message ?: "Unknown")))
                }
            }

        // === URL Synchronization ===

        /**
         * Ensures the wallet's verifier URL matches the current environment setting.
         * This MUST be called before any operation that might make network requests.
         */
        private suspend fun ensureCorrectVerifierUrl() {
            wallet?.let { w ->
                val expectedUrl = EnvironmentManager.getVerifierApi()
                val currentUrl = w.getVerifierBaseUrl()

                if (currentUrl != expectedUrl) {
                    Timber.w("Wallet verifier URL mismatch! Current: $currentUrl, Expected: $expectedUrl")
                    Timber.w("Updating to correct URL for ${EnvironmentManager.getCurrentEnvironment()} environment")
                    w.setVerifierBaseUrl(expectedUrl)

                    // Verify the change took effect
                    val updatedUrl = w.getVerifierBaseUrl()
                    Timber.d("Verifier URL updated. Now set to: $updatedUrl")

                    if (updatedUrl != expectedUrl) {
                        Timber.e("Verifier URL update verification failed: expected=$expectedUrl, got=$updatedUrl")
                    }
                } else {
                    Timber.d("Verifier URL already correct: $currentUrl (${EnvironmentManager.getCurrentEnvironment()} environment)")
                }
            }
        }

        /**
         * Configure wallet with verifier API key in sandbox mode
         * This allows the SDK to authenticate with the verifier API
         */
        private suspend fun configureWalletForSandbox() {
            wallet?.let { w ->
                if (EnvironmentManager.isSandboxEnabled()) {
                    Timber.d("Sandbox mode enabled, fetching per-install credential via gateway...")

                    val credentialResult = SandboxCredentialFetcher.currentCredential()
                    if (credentialResult.isSuccess) {
                        val credential = credentialResult.getOrThrow()
                        val currentConfig = w.getConfig()
                        val updatedConfig =
                            WalletConfig(
                                autoSelect = currentConfig.autoSelect,
                                networkTimeout = currentConfig.networkTimeout,
                                cacheProvingKeys = currentConfig.cacheProvingKeys,
                                issuerApiUrl = currentConfig.issuerApiUrl,
                                verifierApiUrl = currentConfig.verifierApiUrl,
                                verifierApiKey = credential.clientId,
                                verifierOrigin = currentConfig.verifierOrigin,
                                environment = currentConfig.environment,
                                enableParallelProver = currentConfig.enableParallelProver,
                                maxProverThreads = currentConfig.maxProverThreads,
                            )
                        w.updateConfig(updatedConfig)
                        Timber.d("Wallet configured with per-install sandbox credential")
                    } else {
                        val error = credentialResult.exceptionOrNull()
                        Timber.e("Failed to fetch sandbox credential: ${error?.message}")
                        // Don't fail initialisation, just log the error
                    }
                } else {
                    Timber.d("Not in sandbox mode, skipping sandbox credential configuration")
                }
            }
        }

        // === Verification Flow ===

        suspend fun processVerificationChallenge(qrContent: String): Result<String> =
            withContext(Dispatchers.IO) {
                Timber.d("processVerificationChallenge called (${EnvironmentManager.getCurrentEnvironment()} environment)")
                logProverState("Before processVerificationChallenge")

                try {
                    if (wallet == null) {
                        Timber.d("Wallet is null, attempting to initialise...")
                        val initResult = initializeWallet()
                        if (initResult.isFailure) {
                            Timber.e("Failed to initialise wallet: ${initResult.exceptionOrNull()?.message}")
                            return@withContext Result.failure(
                                initResult.exceptionOrNull() ?: Exception("Wallet initialisation failed"),
                            )
                        }
                    }

                    // CRITICAL: Ensure verifier URL matches current environment BEFORE processing challenge
                    ensureCorrectVerifierUrl()

                    val w = wallet ?: return@withContext Result.failure(IllegalStateException(appContext.getString(R.string.wallet_error_wallet_still_null)))

                    Timber.d("Processing QR challenge with wallet instance: ${w.hashCode()}")
                    Timber.d("Verifier URL being used: ${w.getVerifierBaseUrl()}")
                    val challengeId = w.processQrChallenge(qrContent)
                    Timber.d("Challenge processed successfully, ID: ${redactId(challengeId)}")

                    Result.success(challengeId)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to process verification challenge")
                    Result.failure(e)
                }
            }

        /**
         * Process manual entry input, detecting whether it's a 12-digit short code or UUID
         * and fetching the appropriate challenge details.
         */
        suspend fun processManualEntry(input: String): Result<String> =
            withContext(Dispatchers.IO) {
                Timber.d("processManualEntry called (${EnvironmentManager.getCurrentEnvironment()} environment)")
                Timber.d("Input length: ${input.length}")

                try {
                    if (wallet == null) {
                        Timber.d("Wallet is null, attempting to initialise...")
                        val initResult = initializeWallet()
                        if (initResult.isFailure) {
                            Timber.e("Failed to initialise wallet: ${initResult.exceptionOrNull()?.message}")
                            return@withContext Result.failure(
                                initResult.exceptionOrNull() ?: Exception("Wallet initialisation failed"),
                            )
                        }
                    }

                    // CRITICAL: Ensure verifier URL matches current environment BEFORE processing
                    ensureCorrectVerifierUrl()

                    val w = wallet ?: return@withContext Result.failure(IllegalStateException("Wallet still null after init"))

                    Timber.d("Processing manual entry with wallet instance: ${w.hashCode()}")
                    Timber.d("Verifier URL being used: ${w.getVerifierBaseUrl()}")

                    // The SDK's processManualEntry method will detect if it's a short code or UUID
                    val challengeId = w.processManualEntry(input)
                    Timber.d("Manual entry processed successfully, challenge ID: ${redactId(challengeId)}")

                    Result.success(challengeId)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to process manual entry")
                    Result.failure(e)
                }
            }

        /**
         * Create an age proof for a verification challenge.
         * SECURITY: Requires biometric/device credential authentication before accessing credentials.
         *
         * @param credentialId The ID of the credential to use
         * @param challengeId The ID of the verification challenge
         * @param activity The FragmentActivity required for showing BiometricPrompt
         * @return Result containing the proof JSON or an error
         */
        suspend fun createAgeProof(
            credentialId: String,
            challengeId: String,
            activity: FragmentActivity,
        ): Result<String> {
            Timber.d("========== createAgeProof START ==========")
            Timber.d("Environment: ${EnvironmentManager.getCurrentEnvironment()}")
            Timber.d("Credential ID: ${redactId(credentialId)}")
            Timber.d("Challenge ID: ${redactId(challengeId)}")

            try {
                // SECURITY: Authenticate user before accessing credentials
                // BiometricPrompt MUST be created and shown on Main thread (FragmentManager requirement)
                Timber.d("Authenticating user before credential access...")
                val authenticated =
                    withContext(Dispatchers.Main) {
                        keystoreBridge.authenticateBiometricFromActivity(
                            activity = activity,
                            reason = appContext.getString(R.string.keystore_biometric_prompt_subtitle_create_proof),
                            timeoutMs = 30000,
                        )
                    }
                if (!authenticated) {
                    Timber.e("User authentication failed or cancelled")
                    auditLogger.logVerificationAttempt(
                        credentialId = credentialId,
                        challengeId = challengeId,
                        verifyUrl = "N/A",
                        result = "auth_failed",
                    )
                    return Result.failure(AuthenticationRequiredException())
                }
                Timber.d("User authenticated successfully")

                // Proof generation runs on IO thread for heavy cryptographic work
                return withContext(Dispatchers.IO) {
                    // Check wallet
                    val w = wallet
                    if (w == null) {
                        Timber.e("Wallet is null in createAgeProof")
                        return@withContext Result.failure(Exception("Wallet not initialised"))
                    }
                    Timber.d("Using wallet instance: ${w.hashCode()}")

                    // Log current state
                    logProverState("Before proof generation")

                    // Ensure prover is initialised
                    Timber.d("Ensuring prover is initialised...")
                    val proverResult = ensureProverInitialized()
                    if (proverResult.isFailure) {
                        val error = proverResult.exceptionOrNull()
                        Timber.e("Prover initialisation failed: ${error?.message}")
                        return@withContext Result.failure(
                            error ?: Exception("Prover initialisation failed"),
                        )
                    }

                    // Verify credential exists and is valid
                    try {
                        Timber.d("Verifying credential...")
                        val credJson = w.getCredential(credentialId)
                        if (credJson == null) {
                            Timber.e("Credential not found: ${redactId(credentialId)}")
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_credential_not_found)))
                        }
                        Timber.d("Credential found, length: ${credJson.length} chars")
                    } catch (e: Exception) {
                        Timber.e("Error retrieving credential: ${e.message}")
                        return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_credential_access_failed, e.message ?: "Unknown")))
                    }

                    // Final state check before proof generation
                    logProverState("Immediately before createAgeProof call")
                    logMemoryStatus("Before proof generation")

                    // Generate proof
                    Timber.d("Calling wallet.createAgeProof()...")
                    val startTime = System.currentTimeMillis()

                    val proofJson =
                        try {
                            w.createAgeProof(credentialId, challengeId)
                        } catch (e: FfiException.Prover) {
                            Timber.e("PROVER ERROR: ${e.msg}")

                            // Run full diagnostics when proof fails
                            Timber.e("=== RUNNING PROOF FAILURE DIAGNOSTICS ===")
                            Timber.e("Environment: ${EnvironmentManager.getCurrentEnvironment()}")
                            try {
                                // First try the diagnoseProofFailure function if it exists
                                val diagnostics = w.diagnoseProofFailure(credentialId, challengeId)
                                diagnostics.split("\n").forEach { line ->
                                    Timber.e("DIAG: $line")
                                }
                            } catch (diagError: Exception) {
                                Timber.e("diagnoseProofFailure not available or failed: ${diagError.message}")

                                // Fallback: Manual diagnostics
                                try {
                                    // Check if credential has secrets
                                    val hasSecrets = w.hasCredentialSecrets(credentialId)
                                    Timber.e("DIAG: Credential has secrets: $hasSecrets")

                                    // Get challenge diagnostics
                                    val challengeDiag = w.getChallengeDiagnostics(challengeId)
                                    Timber.e("DIAG: Challenge info: $challengeDiag")

                                    // Try debug preflight
                                    val preflight = w.debugPreflight(credentialId, challengeId)
                                    Timber.e("DIAG: Preflight report: $preflight")
                                } catch (fallbackError: Exception) {
                                    Timber.e("DIAG: Fallback diagnostics failed: ${fallbackError.message}")
                                }
                            }

                            // Additional debug info
                            Timber.e("DIAG: Prover initialised (before): ${proverInitialized.get()}")
                            Timber.e("DIAG: SDK prover state: ${w.getDiagnosticInfo().proverInitialized}")

                            // Check the actual error message for clues
                            when {
                                e.msg.contains("commitment", ignoreCase = true) -> {
                                    Timber.e("DIAG: Likely commitment mismatch - credential may have been issued with wrong parameters")
                                }
                                e.msg.contains("constraint", ignoreCase = true) -> {
                                    Timber.e("DIAG: Circuit constraint violation - check r_bits length and format")
                                }
                                e.msg.contains("memory", ignoreCase = true) -> {
                                    Timber.e("DIAG: Possible memory issue during proof generation")
                                    logMemoryStatus("After proof failure")
                                }
                                e.msg.contains("failed", ignoreCase = true) -> {
                                    Timber.e("DIAG: Generic proof generation failure - check proving key compatibility")
                                }
                            }

                            Timber.e("=== END DIAGNOSTICS ===")

                            proverInitialized.set(false) // Mark as not initialised for next attempt
                            return@withContext Result.failure(Exception("Prover error: ${e.msg}"))
                        } catch (e: FfiException.InvalidFormat) {
                            Timber.e("✗ INVALID FORMAT: ${e.msg}")
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_invalid_format, e.msg)))
                        } catch (e: FfiException.NotInitialized) {
                            Timber.e("NOT INITIALISED: Prover reports not initialised")
                            proverInitialized.set(false)
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_not_initialized_short)))
                        } catch (e: FfiException) {
                            Timber.e("✗ FFI ERROR: ${e.javaClass.simpleName}: ${e.message}")
                            return@withContext Result.failure(Exception("FFI error: ${e.message}"))
                        } catch (e: Exception) {
                            Timber.e(e, "Unexpected error during proof creation: ${e.javaClass.simpleName}")
                            return@withContext Result.failure(e)
                        }

                    val duration = System.currentTimeMillis() - startTime
                    Timber.d("✔ PROOF CREATED SUCCESSFULLY in ${duration}ms (${EnvironmentManager.getCurrentEnvironment()})")
                    Timber.d("Proof JSON length: ${proofJson.length} chars")

                    logMemoryStatus("After proof generation")
                    Timber.d("========== createAgeProof END ==========")

                    Result.success(proofJson)
                }
            } catch (e: Exception) {
                Timber.e("========== createAgeProof FAILED ==========")
                Timber.e("Environment: ${EnvironmentManager.getCurrentEnvironment()}")
                Timber.e("Exception type: ${e.javaClass.simpleName}")
                Timber.e("Message: ${e.message}")
                Timber.e("Stack trace:", e)
                return Result.failure(e)
            }
        }

        suspend fun submitProof(proofJson: String): Result<Boolean> =
            withContext(Dispatchers.IO) {
                Timber.d("submitProof called (${EnvironmentManager.getCurrentEnvironment()} environment)")
                try {
                    // Ensure correct verifier URL before submitting
                    ensureCorrectVerifierUrl()

                    val w = wallet ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))
                    Timber.d("Submitting proof to: ${w.getVerifierBaseUrl()}")

                    val success = w.submitProof(proofJson)
                    Timber.d("Proof submission result: $success")

                    // Extract challengeId and credentialId from proofJson for audit logging
                    try {
                        val proofObj = JSONObject(proofJson)
                        val challengeId = proofObj.optString("challenge_id", "unknown")
                        val credentialId = proofObj.optString("credential_id", "unknown")

                        auditLogger.logVerificationAttempt(
                            credentialId = credentialId,
                            challengeId = challengeId,
                            verifyUrl = w.getVerifierBaseUrl(),
                            result = if (success) "success" else "failure",
                        )
                    } catch (e: Exception) {
                        Timber.w("Could not parse proof for audit logging: ${e.message}")
                    }

                    Result.success(success)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to submit proof")

                    // Log failed verification attempt
                    try {
                        val credentialId =
                            try {
                                JSONObject(proofJson).optString("credential_id", "unknown")
                            } catch (_: Exception) {
                                "unknown"
                            }
                        auditLogger.logVerificationAttempt(
                            credentialId = credentialId,
                            challengeId = "unknown",
                            verifyUrl = wallet?.getVerifierBaseUrl() ?: "unknown",
                            result = "error: ${e.message}",
                        )
                    } catch (logError: Exception) {
                        Timber.w("Could not log verification failure: ${logError.message}")
                    }

                    Result.failure(e)
                }
            }

        // === Blind Attestation Flow ===

        /**
         * Process blind attestation issuance.
         * This is the privacy preserving flow where:
         * - Officer creates an attestation containing dob_days (never sees r_bits or commitment)
         * - User's device generates r_bits locally via SDK
         * - User sends attestation + commitment to issuer
         * - Issuer verifies attestation and signs the commitment
         *
         * @param attestationData Base64-encoded attestation from officer's QR code
         * @return Result with Unit on success, or failure with error message
         */
        suspend fun processBlindIssuance(
            attestationData: String,
            credentialType: String = "primary",
            nickname: String? = null,
        ): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    _isProcessing.value = true

                    // Ensure wallet is initialised
                    if (wallet == null) {
                        Timber.d("Wallet not initialised, initialising now...")
                        val initResult = initializeWallet()
                        if (initResult.isFailure) {
                            return@withContext Result.failure(
                                Exception(appContext.getString(R.string.attestation_error_unexpected)),
                            )
                        }
                    }

                    Timber.d("Processing blind attestation...")

                    // Step 1: Decode and validate attestation

                    // Size cap: reject oversized payloads before decoding (QR path allows up to 10,000 chars)
                    if (attestationData.length > 4096) {
                        Timber.e("Attestation string exceeds 4096 character limit (length=${attestationData.length})")
                        return@withContext Result.failure(
                            Exception(appContext.getString(R.string.attestation_error_invalid_data)),
                        )
                    }

                    val attestationBytes =
                        try {
                            Base64.decode(attestationData, Base64.URL_SAFE or Base64.NO_WRAP)
                        } catch (e: Exception) {
                            Timber.e(e, "Failed to decode attestation base64")
                            return@withContext Result.failure(
                                Exception(appContext.getString(R.string.attestation_error_invalid_data)),
                            )
                        }

                    // Parse attestation JSON to extract dob_days
                    val attestationJson =
                        try {
                            String(attestationBytes, Charsets.UTF_8)
                        } catch (e: Exception) {
                            Timber.e(e, "Failed to parse attestation as UTF-8")
                            return@withContext Result.failure(
                                Exception(appContext.getString(R.string.attestation_error_invalid_data)),
                            )
                        }

                    val attestationObj =
                        try {
                            JSONObject(attestationJson)
                        } catch (e: Exception) {
                            Timber.e(e, "Failed to parse attestation as JSON")
                            return@withContext Result.failure(
                                Exception(appContext.getString(R.string.attestation_error_invalid_data)),
                            )
                        }

                    // Required field presence check
                    val requiredFields = listOf("dob_days", "issuer_id", "timestamp", "nonce")
                    val missingFields = requiredFields.filter { !attestationObj.has(it) }
                    if (missingFields.isNotEmpty()) {
                        Timber.e("Attestation missing required fields: $missingFields")
                        return@withContext Result.failure(
                            Exception(appContext.getString(R.string.attestation_error_invalid_data)),
                        )
                    }

                    // Unknown field warning (log only, hard rejection breaks forward compatibility)
                    val knownFields = setOf("dob_days", "issuer_id", "timestamp", "nonce", "expires_at", "signature")
                    val keys = attestationObj.keys().asSequence().toSet()
                    val unknownFields = keys - knownFields
                    if (unknownFields.isNotEmpty()) {
                        Timber.w("Attestation contains unknown fields (ignored for forward compatibility): $unknownFields")
                    }

                    // Check expiry if present
                    if (attestationObj.has("expires_at")) {
                        val expiresAt = attestationObj.getLong("expires_at")
                        val now = System.currentTimeMillis() / 1000
                        if (now > expiresAt) {
                            Timber.w("Attestation expired at $expiresAt, current time: $now")
                            return@withContext Result.failure(
                                Exception(appContext.getString(R.string.attestation_error_expired)),
                            )
                        }
                    }

                    val dobDays = attestationObj.getInt("dob_days")

                    // dob_days range validation (matches server create_attestation bounds exactly)
                    if (dobDays < -25000 || dobDays > 36500) {
                        Timber.e("Attestation dob_days=$dobDays is outside valid range [-25000, 36500]")
                        return@withContext Result.failure(
                            Exception(appContext.getString(R.string.attestation_error_invalid_data)),
                        )
                    }

                    Timber.d("Attestation DOB days received")

                    // Step 2: Generate r_bits and commitment locally using SDK
                    // The SDK generates secure randomness and computes Pedersen commitment
                    Timber.d("Computing commitment with SDK...")
                    val commitmentJson = sdkIssueComputeCommitment(dobDays.toString())
                    val commitmentObj = JSONObject(commitmentJson)
                    val rBitsB64 = commitmentObj.getString("r_bits")

                    Timber.d("Commitment computed locally")

                    // Step 3: Call blind issuance endpoint
                    Timber.d("Calling blind issuance endpoint...")
                    val blindRequestJson =
                        JSONObject().apply {
                            put("attestation", attestationData)
                            put("r_bits", rBitsB64)
                        }.toString()

                    val requestBody = blindRequestJson.toRequestBody("application/json".toMediaType())
                    val request =
                        Request.Builder()
                            .url("$issuerBaseUrl/v1/issuance/blind")
                            .post(requestBody)
                            .addHeader("Content-Type", "application/json")
                            .build()

                    val response = httpClient.newCall(request).execute()
                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: "Unknown error"
                        Timber.e("Blind issuance failed: ${response.code} - $errorBody")
                        return@withContext Result.failure(Exception("Blind issuance failed: ${response.code}"))
                    }

                    val headerJson =
                        response.body?.string()
                            ?: return@withContext Result.failure(Exception("Empty response from blind issuance"))

                    Timber.d("Blind issuance response received")

                    // Step 4: Finalise and store the credential
                    Timber.d("Storing credential (type=$credentialType)...")
                    val credentialId =
                        wallet?.finalizeAndStoreCredential(
                            headerJson = headerJson,
                            dobDays = dobDays,
                            rBitsB64 = rBitsB64,
                            label = null, // Use primary namespace
                            credentialType = credentialType,
                            nickname = nickname,
                        ) ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))

                    Timber.d("Credential stored with ID: ${redactId(credentialId)}")
                    refreshCredentialState()

                    Timber.d("Blind attestation issuance completed successfully")
                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Blind attestation failed: ${e.message}")
                    val errorMsg =
                        when {
                            e.message?.contains("network", ignoreCase = true) == true ||
                                e.message?.contains("connection", ignoreCase = true) == true ->
                                appContext.getString(R.string.attestation_error_network)
                            else ->
                                appContext.getString(R.string.attestation_error_unexpected)
                        }
                    Result.failure(Exception(errorMsg))
                } finally {
                    _isProcessing.value = false
                }
            }

        suspend fun storeSandboxCredential(credentialJson: String): Result<String> =
            withContext(Dispatchers.IO) {
                try {
                    if (wallet == null) {
                        val initResult = initializeWallet()
                        if (initResult.isFailure) {
                            val error = initResult.exceptionOrNull() ?: Exception("Wallet initialisation failed")
                            return@withContext Result.failure(error)
                        }
                    }
                    val walletInstance = wallet ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))
                    val credentialId =
                        walletInstance.storeCredentialWithLabel(
                            credentialJson,
                            SandboxConstants.LABEL,
                            "primary",
                            null,
                        )
                    Timber.d("Sandbox credential stored with ID: ${redactId(credentialId)}")
                    checkCredential()
                    Result.success(credentialId)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to store sandbox credential")
                    Result.failure(e)
                }
            }

        suspend fun deleteSandboxCredentials(): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    wallet?.let {
                        Timber.d("Clearing sandbox credentials...")
                        it.deleteSandboxCredentials()
                        checkCredential()
                    }
                    // also revoke on the gateway so the per-install
                    // record is retired server-side. Failure is non-fatal; the
                    // sliding TTL reaps any orphaned credential regardless.
                    SandboxCredentialFetcher.revoke().onFailure { err ->
                        Timber.w(err, "Gateway revoke failed on sandbox mode off-flip")
                    }
                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to delete sandbox credentials")
                    Result.failure(e)
                }
            }

        @OptIn(ExperimentalUnsignedTypes::class)
        suspend fun generateSandboxCredential(
            ageYears: Int,
            dateOfBirth: LocalDate? = null,
            validityDays: Int = SandboxConstants.DEFAULT_VALIDITY_DAYS,
            credentialType: String = "primary",
            nickname: String? = null,
        ): Result<String> =
            withContext(Dispatchers.IO) {
                try {
                    if (!EnvironmentManager.isSandboxEnabled()) {
                        return@withContext Result.failure(IllegalStateException(appContext.getString(R.string.wallet_error_sandbox_disabled)))
                    }

                    // fetch the per-install credential from the mobile
                    // sandbox gateway. `clientId` is the issuer api key; `hmacSecret`
                    // is the HMAC secret returned by `/register`.
                    val credentialResult = SandboxCredentialFetcher.currentCredential()
                    if (credentialResult.isFailure) {
                        val error = credentialResult.exceptionOrNull() ?: Exception("Failed to fetch sandbox credentials")
                        Timber.e(error, "[WalletRepository] Cannot generate test credential: ${error.message}")
                        return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_fetch_sandbox_credentials), error))
                    }
                    val credential = credentialResult.getOrThrow()
                    val sandboxIssuerBaseUrl = EnvironmentManager.getIssuerApi()

                    val normalizedAge = max(ageYears, 0)
                    val clampedValidity = min(max(validityDays, 1), SandboxConstants.MAX_VALIDITY_DAYS)

                    if (wallet == null) {
                        val initResult = initializeWallet()
                        if (initResult.isFailure) {
                            val error = initResult.exceptionOrNull() ?: Exception("Wallet initialisation failed")
                            return@withContext Result.failure(error)
                        }
                    }
                    val walletInstance = wallet ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))

                    // Compute DOB days and r_bits from the date of birth
                    val dobIso = dateOfBirth?.let { computeDateOfBirthIso(it) } ?: computeDateOfBirthIso(normalizedAge)
                    val commitmentJson = sdkIssueComputeCommitment(dobIso)
                    val commitmentObject = JSONObject(commitmentJson)
                    val dobDays = commitmentObject.getInt("dob_days")
                    val rBits = commitmentObject.getString("r_bits")

                    // Create attestation via provii-issuer using HMAC-SHA256 authentication
                    val hmacSecretBytes =
                        Base64.decode(
                            credential.hmacSecret,
                            Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP,
                        )
                    val authorizerJson: String
                    try {
                        val (authorizer, _) =
                            HmacSigner.createAttestationAuthorizer(
                                secret = hmacSecretBytes,
                                dobDays = dobDays,
                                format = "client",
                                keyId = credential.clientId,
                            )
                        authorizerJson = authorizer
                    } finally {
                        java.util.Arrays.fill(hmacSecretBytes, 0.toByte())
                    }
                    val attestationResponseJson =
                        sdkCreateAttestation(
                            baseUrl = sandboxIssuerBaseUrl,
                            dobDays = dobDays,
                            authorizerJson = authorizerJson,
                        )
                    val attestationResponse = JSONObject(attestationResponseJson)
                    val attestationB64 = attestationResponse.getString("attestation")

                    // Submit attestation + r_bits to provii-issuer for blind issuance
                    val headerJson =
                        sdkIssueBlind(
                            baseUrl = sandboxIssuerBaseUrl,
                            attestationB64 = attestationB64,
                            rBitsB64 = rBits,
                        )

                    // Finalise and store the credential directly with sandbox label
                    // This bypasses JSON serialisation to ensure secrets (dob_days, r_bits) are preserved
                    val credentialId =
                        walletInstance.finalizeAndStoreCredential(
                            headerJson = headerJson,
                            dobDays = dobDays,
                            rBitsB64 = rBits,
                            label = SandboxConstants.LABEL,
                            credentialType = credentialType,
                            nickname = nickname,
                        )
                    Timber.d("Sandbox credential stored with ID: ${redactId(credentialId)}")
                    checkCredential()
                    Result.success(credentialId)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to generate sandbox credential")
                    Result.failure(e)
                }
            }

        suspend fun processQrCode(qrContent: String): QrAction =
            withContext(Dispatchers.IO) {
                try {
                    if (wallet == null) {
                        initializeWallet()
                    }

                    val action =
                        wallet?.processScannedQr(qrContent)
                            ?: return@withContext QrAction.Error("Wallet not initialised")

                    when (action) {
                        is app.provii.wallet.sdk.QrAction.VerificationChallenge ->
                            QrAction.VerificationChallenge(action.challengeJson)
                        is app.provii.wallet.sdk.QrAction.Attestation ->
                            QrAction.Attestation(action.attestationData)
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Failed to process QR code")
                    QrAction.Error(e.message ?: "Unknown error")
                }
            }

        // === Storage Helper ===

        private fun getAvailableStorageBytes(path: String): Long {
            return try {
                val stat = StatFs(path)
                stat.availableBlocksLong * stat.blockSizeLong
            } catch (e: Exception) {
                Timber.e(e, "Failed to get storage stats")
                0L
            }
        }

        // === Proving Key Management ===

        suspend fun checkProvingKeyStatus(): Boolean =
            withContext(Dispatchers.IO) {
                try {
                    val filesDir = appContext.filesDir.absolutePath
                    val available = provingKeyIsAvailable(filesDir)
                    Timber.d("Proving key available: $available (${EnvironmentManager.getCurrentEnvironment()})")
                    available
                } catch (e: Exception) {
                    Timber.e(e, "Failed to check proving key status")
                    false
                }
            }

        suspend fun downloadProvingKey(): Result<Unit> {
            return try {
                withContext(Dispatchers.IO) {
                    _setupState.value = SetupState.Checking

                    val filesDir = appContext.filesDir.absolutePath

                    if (provingKeyIsAvailable(filesDir)) {
                        _setupState.value = SetupState.Ready
                        return@withContext Result.success(Unit)
                    }

                    val availableBytes = getAvailableStorageBytes(filesDir)
                    val storageCheck = provingKeyCheckStorageWithBytes(filesDir, availableBytes.toULong())

                    when (storageCheck) {
                        is StorageCheckResult.Ready -> {
                            Timber.d("Storage check passed")
                        }
                        is StorageCheckResult.InsufficientSpace -> {
                            _setupState.value =
                                SetupState.Error(
                                    message = storageCheck.message,
                                    canRetry = false,
                                    requiresAction = SetupAction.FREE_STORAGE,
                                )
                            return@withContext Result.failure(Exception(storageCheck.message))
                        }
                        is StorageCheckResult.Error -> {
                            _setupState.value =
                                SetupState.Error(
                                    message = storageCheck.message,
                                    canRetry = true,
                                )
                            return@withContext Result.failure(Exception(storageCheck.message))
                        }
                    }

                    _setupState.value = SetupState.Downloading(0f, 0f, 0f)

                    val progressListener =
                        object : ProvingKeyProgressListener {
                            override fun onProgress(
                                bytesDownloaded: ULong,
                                totalBytes: ULong,
                                percentage: UByte,
                            ) {
                                val downloadedMB = bytesDownloaded.toFloat() / (1024f * 1024f)
                                val totalMB = totalBytes.toFloat() / (1024f * 1024f)
                                val progress = percentage.toFloat() / 100f

                                _setupState.value =
                                    SetupState.Downloading(
                                        progress = progress,
                                        downloadedMB = downloadedMB,
                                        totalMB = totalMB,
                                    )
                            }
                        }

                    // Download from environment-specific CDN
                    Timber.d("Downloading proving key from ${EnvironmentManager.getCDNProvingKey()}")
                    provingKeyDownload(filesDir, progressListener)

                    _setupState.value = SetupState.Initialising
                    provingKeyInit(filesDir)

                    _setupState.value = SetupState.Ready
                    Result.success(Unit)
                }
            } catch (e: Exception) {
                _setupState.value =
                    SetupState.Error(
                        message = "Error: ${e.message ?: "Unknown error"}",
                        canRetry = true,
                    )
                Result.failure(e)
            }
        }

        suspend fun retryProvingKeyDownload() {
            Timber.d("Retrying proving key download...")
            _setupState.value = SetupState.NotStarted
            delay(100)
            downloadProvingKey()
        }

        suspend fun clearProvingKey(): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    val filesDir = appContext.filesDir.absolutePath
                    provingKeyDelete(filesDir)
                    _setupState.value = SetupState.NotStarted
                    proverInitialized.set(false)
                    lastProverInitTime.set(0L)
                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to clear proving key")
                    Result.failure(e)
                }
            }

        // === Wallet Initialisation ===

        suspend fun initializeWallet(): Result<Unit> =
            withContext(Dispatchers.IO) {
                // Use mutex to prevent concurrent initialisation
                initializationMutex.withLock {
                    Timber.d("========================================")
                    Timber.d("initializeWallet() START (thread: ${Thread.currentThread().name})")
                    Timber.d("Environment: ${EnvironmentManager.getCurrentEnvironment()}")
                    Timber.d("========================================")

                    try {
                        // Check if wallet already exists AND is valid
                        wallet?.let { existingWallet ->
                            Timber.d("Wallet already exists (instance: ${existingWallet.hashCode()})")

                            // Verify the wallet is still valid
                            try {
                                val diagnostics = existingWallet.getDiagnosticInfo()
                                Timber.d("Existing wallet is valid, prover initialised: ${diagnostics.proverInitialized}")

                                // CRITICAL: Always update verifier URL in case environment changed
                                val expectedUrl = EnvironmentManager.getVerifierApi()
                                val currentUrl = existingWallet.getVerifierBaseUrl()

                                if (currentUrl != expectedUrl) {
                                    Timber.w("Wallet URL mismatch on reuse! Current: $currentUrl, Expected: $expectedUrl")
                                    existingWallet.setVerifierBaseUrl(expectedUrl)

                                    // Verify it worked
                                    val verifiedUrl = existingWallet.getVerifierBaseUrl()
                                    if (verifiedUrl == expectedUrl) {
                                        Timber.d("✓ Updated verifier URL to: $expectedUrl (${EnvironmentManager.getCurrentEnvironment()})")
                                    } else {
                                        return@withContext Result.failure(IllegalStateException("Failed to update verifier URL! Expected $expectedUrl but got $verifiedUrl"))
                                    }
                                } else {
                                    Timber.d("✓ Verifier URL already correct: $currentUrl (${EnvironmentManager.getCurrentEnvironment()})")
                                }

                                if (diagnostics.proverInitialized == true) {
                                    Timber.d("Wallet and prover already initialised - reusing existing instance")

                                    // Ensure wallet is configured for sandbox mode if needed
                                    configureWalletForSandbox()

                                    checkCredential()
                                    _isReady.value = true
                                    return@withContext Result.success(Unit)
                                } else {
                                    Timber.w("Wallet exists but prover not initialised - will reinitialise prover")

                                    // Ensure wallet is configured for sandbox mode if needed
                                    configureWalletForSandbox()

                                    val proverResult = ensureProverInitialized()
                                    if (proverResult.isSuccess) {
                                        checkCredential()
                                        _isReady.value = true
                                        return@withContext Result.success(Unit)
                                    } else {
                                        Timber.e("Failed to reinitialise prover, creating new wallet")
                                        // Fall through to create new wallet
                                    }
                                }
                            } catch (e: Exception) {
                                Timber.e("Existing wallet appears invalid: ${e.message}, creating new wallet")
                                // Destroy the invalid wallet
                                try {
                                    (existingWallet as? Disposable)?.destroy()
                                } catch (destroyError: Exception) {
                                    Timber.e("Error destroying invalid wallet: ${destroyError.message}")
                                }
                                wallet = null
                                proverInitialized.set(false)
                            }
                        }

                        val filesDir = appContext.filesDir.absolutePath

                        // Check proving key
                        val provingKeyAvailable = provingKeyIsAvailable(filesDir)
                        if (!provingKeyAvailable) {
                            Timber.e("Proving key not available")
                            return@withContext Result.failure(
                                Exception(appContext.getString(R.string.wallet_error_proving_key_unavailable)),
                            )
                        }

                        val versionName =
                            try {
                                appContext.packageManager.getPackageInfo(appContext.packageName, 0).versionName ?: "unknown"
                            } catch (_: Exception) {
                                "unknown"
                            }
                        val buildNumber =
                            try {
                                appContext.packageManager.getPackageInfo(appContext.packageName, 0).longVersionCode.toString()
                            } catch (_: Exception) {
                                "unknown"
                            }
                        val appInfo =
                            AppInfo(
                                version = versionName,
                                buildNumber = buildNumber,
                                platform = "Android",
                                deviceModel = android.os.Build.MODEL,
                                osVersion = android.os.Build.VERSION.RELEASE,
                            )

                        // Create wallet
                        val newWallet = ProviiWallet(appInfo)
                        Timber.d("New wallet instance created: ${newWallet.hashCode()}")

                        // Set storage handle
                        val secureStore = createDefaultSecureStore()
                        newWallet.setStorageHandle(secureStore)
                        Timber.d("Storage handle set")

                        // Set verifier URL based on environment
                        val verifierUrl = EnvironmentManager.getVerifierApi()
                        newWallet.setVerifierBaseUrl(verifierUrl)
                        Timber.d("Verifier base URL set to: $verifierUrl (${EnvironmentManager.getCurrentEnvironment()})")

                        // Store the wallet BEFORE initialising prover
                        wallet = newWallet

                        // Configure wallet for sandbox (fetch and set verifier API key)
                        configureWalletForSandbox()

                        // Initialise prover immediately
                        Timber.d("Initialising prover as part of wallet setup...")
                        val proverResult = ensureProverInitialized()
                        if (proverResult.isFailure) {
                            Timber.e("Failed to initialise prover during wallet setup: ${proverResult.exceptionOrNull()?.message}")
                            (wallet as? Disposable)?.destroy()
                            wallet = null
                            proverInitialized.set(false)
                            return@withContext proverResult
                        }

                        // Verify storage is working
                        try {
                            val credentials = wallet?.listCredentials() ?: emptyList()
                            Timber.d("Storage verified, found ${credentials.size} credentials")
                            credentials.forEach { cred ->
                                Timber.d("  Credential: ${redactId(cred.id)}, status: ${cred.status}")
                            }
                        } catch (e: Exception) {
                            Timber.e(e, "Storage verification failed")
                            (wallet as? Disposable)?.destroy()
                            wallet = null
                            proverInitialized.set(false)
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_storage_init_failed)))
                        }

                        checkCredential()

                        Timber.d("========================================")
                        Timber.d("initializeWallet() COMPLETE")
                        Timber.d("Environment: ${EnvironmentManager.getCurrentEnvironment()}")
                        Timber.d("========================================")

                        _isReady.value = true
                        Result.success(Unit)
                    } catch (e: Exception) {
                        Timber.e(e, "Failed to initialise wallet")
                        (wallet as? Disposable)?.destroy()
                        wallet = null
                        proverInitialized.set(false)
                        _isReady.value = false
                        Result.failure(e)
                    }
                }
            }

        private suspend fun checkCredential() {
            refreshCredentialState()
        }

        /** Reload credential state from SDK storage */
        suspend fun refreshCredentialState() {
            wallet?.let { w ->
                try {
                    val credentials = w.listCredentials()
                    if (credentials.isNotEmpty()) {
                        var primary: StoredCredentialInfo? = null
                        val managed = mutableListOf<StoredCredentialInfo>()

                        for (info in credentials) {
                            val credInfo =
                                StoredCredentialInfo(
                                    id = info.id,
                                    credentialType = info.credentialType,
                                    nickname = info.nickname,
                                    canProve = info.status == CredentialStatus.VALID,
                                    isExpired = info.status == CredentialStatus.EXPIRED,
                                )
                            if (info.credentialType == "managed") {
                                managed.add(credInfo)
                            } else {
                                primary = credInfo
                            }
                        }
                        _credentialState.value =
                            CredentialState.HasCredentials(
                                primary = primary,
                                managed = managed,
                            )
                        Timber.d("Credential state updated: primary=${primary != null}, managed=${managed.size}")
                    } else {
                        _credentialState.value = CredentialState.None
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Failed to check credentials")
                    _credentialState.value = CredentialState.None
                }
            }
        }

        // === Credential Management ===

        suspend fun deleteCredential(credentialId: String): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    wallet?.deleteCredential(credentialId)
                    refreshCredentialState()
                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to delete credential")
                    Result.failure(e)
                }
            }

        /** Delete all stored credentials */
        suspend fun deleteAllCredentials(): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    val credentials = wallet?.listCredentials() ?: emptyList()
                    for (cred in credentials) {
                        wallet?.deleteCredential(cred.id)
                    }
                    _credentialState.value = CredentialState.None
                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to delete all credentials")
                    Result.failure(e)
                }
            }

        /** Get all credentials that can generate proofs */
        suspend fun getProvableCredentials(): List<StoredCredentialInfo> =
            withContext(Dispatchers.IO) {
                val state = _credentialState.value as? CredentialState.HasCredentials ?: return@withContext emptyList()
                val result = mutableListOf<StoredCredentialInfo>()
                state.primary?.let { if (it.canProve) result.add(it) }
                result.addAll(state.managed.filter { it.canProve })
                result
            }

        /** Update the nickname of a credential */
        suspend fun updateCredentialNickname(
            credentialId: String,
            nickname: String?,
        ): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    wallet?.updateCredentialNickname(credentialId, nickname)
                        ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))
                    refreshCredentialState()
                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to update credential nickname")
                    Result.failure(e)
                }
            }

        /** Get provable credentials with suitability info for a specific challenge */
        suspend fun getProvableCredentialsForChallenge(challengeId: String): Result<List<CredentialSuitabilityInfo>> =
            withContext(Dispatchers.IO) {
                try {
                    val w = wallet ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))
                    val suitabilities = w.getProvableCredentialsForChallenge(challengeId)
                    Result.success(
                        suitabilities.map { s ->
                            CredentialSuitabilityInfo(
                                id = s.id,
                                nickname = s.nickname,
                                credentialType = s.credentialType,
                                canSatisfy = s.canSatisfy,
                                failureReason = s.failureReason,
                            )
                        },
                    )
                } catch (e: Exception) {
                    Timber.e(e, "Failed to get credential suitability")
                    Result.failure(e)
                }
            }

        /** Get available credential slot count in the current namespace */
        suspend fun getAvailableSlotCount(): Result<Int> =
            withContext(Dispatchers.IO) {
                try {
                    val w = wallet ?: return@withContext Result.failure(IllegalStateException("Wallet not initialised"))
                    Result.success(w.getAvailableSlotCount().toInt())
                } catch (e: Exception) {
                    Timber.e(e, "Failed to get available slot count")
                    Result.failure(e)
                }
            }

        /** Credential suitability for a specific challenge */
        data class CredentialSuitabilityInfo(
            val id: String,
            val nickname: String?,
            val credentialType: String,
            val canSatisfy: Boolean,
            val failureReason: String?,
        ) {
            /** Nullable display name. UI layer resolves fallback via stringResource. */
            val displayName: String? get() = nickname
            val isManaged: Boolean get() = credentialType == "managed"
        }

        /** Simple credential info for the picker UI (no suitability/dob exposure) */
        data class CredentialPickerItem(
            val id: String,
            val nickname: String?,
            val credentialType: String,
            val isExpired: Boolean,
        ) {
            /** Nullable display name. UI layer resolves fallback via stringResource. */
            val displayName: String? get() = nickname
            val isManaged: Boolean get() = credentialType == "managed"

            override fun toString() = "CredentialPickerItem(id=${id.take(8)}..., credentialType=$credentialType, isExpired=$isExpired)"
        }

        /** Get provable credentials for picker (no suitability pre-filtering) */
        fun getPickerCredentials(): List<CredentialPickerItem> {
            val state = _credentialState.value
            if (state !is CredentialState.HasCredentials) return emptyList()
            val items = mutableListOf<CredentialPickerItem>()
            state.primary?.let { cred ->
                if (cred.canProve) {
                    items.add(CredentialPickerItem(cred.id, cred.nickname, cred.credentialType, cred.isExpired))
                }
            }
            state.managed.filter { it.canProve }.forEach { cred ->
                items.add(CredentialPickerItem(cred.id, cred.nickname, cred.credentialType, cred.isExpired))
            }
            return items
        }

        // === Settings ===

        private val _biometricEnabled = MutableStateFlow(false)
        val biometricEnabled: StateFlow<Boolean> = _biometricEnabled.asStateFlow()

        private fun getEncryptedPrefs(): SharedPreferences {
            // SECURITY: Require device authentication for master key access
            val masterKey =
                MasterKey.Builder(appContext)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .setUserAuthenticationRequired(true, 30)
                    .build()
            return EncryptedSharedPreferences.create(
                appContext,
                "wallet_prefs_encrypted",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }

        suspend fun setBiometricEnabled(enabled: Boolean): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    if (enabled) {
                        val isAvailable = wallet?.isBiometricAvailable() ?: false
                        if (!isAvailable) {
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_biometric_unavailable)))
                        }

                        val config =
                            BiometricConfig(
                                timeoutSeconds = 30u,
                                title = "Enable Biometric",
                                subtitle = "Authenticate to enable biometric protection",
                                description = null,
                            )

                        val result = BiometricAuthenticator(config).authenticate()
                        val authenticated = result == BiometricResult.SUCCESS
                        if (!authenticated) {
                            return@withContext Result.failure(Exception(appContext.getString(R.string.wallet_error_auth_failed)))
                        }
                    }

                    _biometricEnabled.value = enabled

                    getEncryptedPrefs()
                        .edit()
                        .putBoolean("biometric_enabled", enabled)
                        .apply()

                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to set biometric enabled state")
                    Result.failure(e)
                }
            }

        suspend fun clearAllData(): Result<Unit> =
            withContext(Dispatchers.IO) {
                try {
                    wallet?.listCredentials()?.forEach { credInfo ->
                        wallet?.deleteCredential(credInfo.id)
                    }

                    val filesDir = appContext.filesDir.absolutePath
                    try {
                        provingKeyDelete(filesDir)
                    } catch (e: Exception) {
                        Timber.w("Failed to delete proving key: ${e.message}")
                    }

                    getEncryptedPrefs()
                        .edit()
                        .clear()
                        .apply()

                    _credentialState.value = CredentialState.None
                    _setupState.value = SetupState.NotStarted
                    _biometricEnabled.value = false
                    _isReady.value = false
                    proverInitialized.set(false)
                    lastProverInitTime.set(0L)

                    (wallet as? Disposable)?.destroy()
                    wallet = null

                    Result.success(Unit)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to clear all data")
                    Result.failure(e)
                }
            }

        fun markProverStale() {
            Timber.d("Marking prover as potentially stale")
            // Don't actually set to false, just log that we should check
            // The ensureProverInitialised method will handle verification
        }

        fun cleanup() {
            Timber.d("WalletRepository cleanup() called")
            (wallet as? Disposable)?.destroy()
            wallet = null
            _isReady.value = false
            proverInitialized.set(false)
            lastProverInitTime.set(0L)
        }

        private fun computeDateOfBirthIso(ageYears: Int): String {
            val safeAge = max(ageYears, 0)
            val today = LocalDate.now(ZoneOffset.UTC)
            val dob = today.minusYears(safeAge.toLong())
            return computeDateOfBirthIso(dob)
        }

        private fun computeDateOfBirthIso(date: LocalDate): String {
            val today = LocalDate.now(ZoneOffset.UTC)
            val clamped = if (date.isAfter(today)) today else date
            return clamped.format(DateTimeFormatter.ISO_DATE)
        }

        // === Debug Functions ===

        suspend fun getDebugInfo(): String =
            withContext(Dispatchers.IO) {
                buildString {
                    appendLine("=== WALLET DEBUG INFO ===")
                    appendLine("Timestamp: ${System.currentTimeMillis()}")
                    appendLine("Environment: ${EnvironmentManager.getCurrentEnvironment()}")
                    appendLine("Sandbox Mode: ${EnvironmentManager.isSandboxEnabled()}")

                    wallet?.let { w ->
                        appendLine("\nWallet:")
                        appendLine("  Instance: ${w.hashCode()}")

                        try {
                            val diagnostics = w.getDiagnosticInfo()
                            appendLine("  SDK Version: ${diagnostics.sdkVersion}")
                            appendLine("  Prover Initialized: ${diagnostics.proverInitialized}")
                            appendLine("  Credential Count: ${diagnostics.credentialCount}")
                            appendLine("  Storage Available: ${diagnostics.storageAvailable}")
                        } catch (e: Exception) {
                            appendLine("  Error getting diagnostics: ${e.message}")
                        }
                    } ?: appendLine("\nWallet: NULL")

                    appendLine("\nProver:")
                    appendLine("  Local flag: ${proverInitialized.get()}")
                    appendLine("  Last init: ${if (lastProverInitTime.get() > 0) "${(System.currentTimeMillis() - lastProverInitTime.get()) / 1000}s ago" else "never"}")

                    val filesDir = appContext.filesDir.absolutePath
                    val pkFile = File(filesDir, PROVING_KEY_FILENAME)
                    appendLine("\nProving Key:")
                    appendLine("  Path: ${pkFile.absolutePath}")
                    appendLine("  Exists: ${pkFile.exists()}")
                    appendLine("  Size: ${if (pkFile.exists()) "${pkFile.length() / 1048576}MB" else "N/A"}")

                    val runtime = Runtime.getRuntime()
                    val usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1048576L
                    val maxMemory = runtime.maxMemory() / 1048576L
                    appendLine("\nMemory:")
                    appendLine("  Used: ${usedMemory}MB")
                    appendLine("  Max: ${maxMemory}MB")
                    appendLine("  Available: ${maxMemory - usedMemory}MB")

                    appendLine("\nURLs:")
                    appendLine("  Issuer API: $issuerBaseUrl")
                    appendLine("  Verifier API: ${EnvironmentManager.getVerifierApi()}")
                    appendLine("  Registry: ${EnvironmentManager.getIssuersRegistry()}")
                    appendLine("  CDN: ${EnvironmentManager.getCDNProvingKey()}")

                    appendLine("\nCredential State: ${_credentialState.value}")
                    appendLine("Setup State: ${_setupState.value}")
                }
            }
    }
