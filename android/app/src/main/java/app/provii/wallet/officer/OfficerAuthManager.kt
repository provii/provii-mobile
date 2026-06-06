// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.officer

import android.content.Context
import app.provii.wallet.R
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.logging.redactId
import dagger.hilt.android.qualifiers.ApplicationContext
import app.provii.wallet.data.YubikeyManager
import app.provii.wallet.security.NativeKeystoreManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton
import java.security.SecureRandom
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Manages officer authentication and blind attestation creation. Officers authenticate
 * via a YubiKey HMAC-SHA1 challenge-response against provii-issuer, then create attestations
 * that users scan to obtain credentials. The officer never sees the user's commitment
 * or randomness bits, preserving privacy during issuance.
 */
@Singleton
class OfficerAuthManager
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
        private val yubikeyManager: YubikeyManager,
        private val keystoreManager: NativeKeystoreManager,
        private val dataPreservationManager: app.provii.wallet.ui.accessibility.DataPreservationManager,
        private val auditLogger: app.provii.wallet.security.AuditLogger,
        private val httpClient: OkHttpClient,
    ) {
        companion object {
            private const val OFFICER_KEY_ID = "officer_key_id"
        }

        /**
         * Store the officer ID for later use in attestation creation.
         * Called from OfficerEntryScreen when officer enters their ID.
         */
        suspend fun setOfficerId(officerId: String) {
            keystoreManager.saveSecureString(OFFICER_KEY_ID, officerId)
            updateSessionCache(officerId)
        }

        /**
         * Get the stored officer ID.
         * Returns null if not set.
         */
        suspend fun getOfficerId(): String? {
            return keystoreManager.getSecureString(OFFICER_KEY_ID)
        }

        /**
         * Validate officer ID and store it.
         * This replaces the old authenticateOfficer function.
         */
        suspend fun authenticateOfficer(officerId: String): Result<Unit> {
            return try {
                // Validate officer ID format
                if (!officerId.matches(Regex("^[a-zA-Z0-9@._+-]+$"))) {
                    return Result.failure(IllegalArgumentException("Invalid officer ID format"))
                }
                // Store the officer ID for later use
                setOfficerId(officerId)
                Result.success(Unit)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

        // SECURITY: SecureRandom instance for cryptographic token generation
        private val secureRandom = SecureRandom()

        // Get issuer base URL from EnvironmentManager
        private val issuerBaseUrl: String
            get() = EnvironmentManager.getIssuerApi()

        private val json =
            Json {
                ignoreUnknownKeys = true
                encodeDefaults = true
            }

        private val managerScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

        // State flows for UI
        private val _issuanceState = MutableStateFlow<IssuanceState>(IssuanceState.Idle)
        val issuanceState: StateFlow<IssuanceState> = _issuanceState.asStateFlow()

        // Session expiry state flows (for UI compatibility)
        private val _sessionExpiryWarning = MutableStateFlow(false)
        val sessionExpiryWarning: StateFlow<Boolean> = _sessionExpiryWarning.asStateFlow()

        private val _timeUntilExpiry = MutableStateFlow<Long?>(null)
        val timeUntilExpiry: StateFlow<Long?> = _timeUntilExpiry.asStateFlow()

        /**
         * Session info for UI display.
         */
        data class SessionInfo(
            val officerId: String,
            val stationId: String = "",
            val issuedToday: Int = 0,
        )

        // Cache session info for synchronous access
        private var _cachedSessionInfo: SessionInfo? = null

        /**
         * Get session info for UI display (synchronous version for Compose).
         * Returns non-null if officer is authenticated, null otherwise.
         */
        fun getSessionInfo(): SessionInfo? {
            return _cachedSessionInfo
        }

        /**
         * Update cached session info when officer ID changes.
         */
        private fun updateSessionCache(officerId: String?) {
            _cachedSessionInfo = officerId?.let { SessionInfo(officerId = it) }
        }

        // Private hex function for converting bytes to hex string
        private fun hex(bytes: ByteArray): String =
            bytes.joinToString("") { "%02x".format(it) }

        sealed class IssuanceState {
            object Idle : IssuanceState()

            object ValidatingInput : IssuanceState()

            data class WaitingForYubikeyTouch(
                val message: String,
            ) : IssuanceState()

            object CreatingAttestation : IssuanceState()

            data class Complete(val attestationB64: String, val deeplink: String) : IssuanceState()

            data class Error(val message: String, val canRetry: Boolean = true) : IssuanceState()
        }

        @Serializable
        data class ChallengeResponse(
            val challenge_id: String,
            val challenge: String, // hex
            val expires_at: Long,
        )

        @Serializable
        data class AttestationRequest(
            val dob_days: Int,
            val authorizer: AttestationAuthorizer,
        )

        @Serializable
        data class AttestationAuthorizer(
            val format: String,
            val keyId: String,
            val challengeId: String,
            val timestamp: Long,
            val hmac: String,
            val nonce: String,
        ) {
            override fun toString(): String =
                "AttestationAuthorizer(format=$format, keyId=$keyId, challengeId=$challengeId, timestamp=$timestamp, hmac=[REDACTED], nonce=[REDACTED])"
        }

        @Serializable
        data class AttestationResponse(
            val attestation: String, // base64-encoded attestation blob
            val expires_at: Long,
        )

        @Serializable
        data class PreservedIssuanceData(
            val dobDays: Int? = null,
            val documentVerified: Boolean = false,
            val dobMatches: Boolean = false,
            val timestamp: Long = System.currentTimeMillis(),
        )

        /**
         * Fetch server challenge for YubiKey authentication
         */
        private suspend fun fetchServerChallenge(officerId: String): Result<Pair<String, ByteArray>> =
            withContext(Dispatchers.IO) {
                try {
                    // Send officer_id in a JSON POST body instead of URL
                    // query string or headers. POST body is not logged by default in
                    // most reverse proxies and CDNs.
                    val url = "$issuerBaseUrl/v1/challenge"
                    val requestJson =
                        json.encodeToString(
                            kotlinx.serialization.json.buildJsonObject {
                                put("officer_id", kotlinx.serialization.json.JsonPrimitive(officerId))
                            },
                        )
                    val requestBody = requestJson.toRequestBody("application/json".toMediaType())

                    val request =
                        Request.Builder()
                            .url(url)
                            .post(requestBody)
                            .addHeader("Content-Type", "application/json")
                            .build()

                    val result =
                        httpClient.newCall(request).execute().use { response ->
                            if (!response.isSuccessful) {
                                return@use Result.failure(Exception("Challenge request failed: ${response.code}"))
                            }

                            val body =
                                response.body?.string()
                                    ?: return@use Result.failure(Exception("Empty response"))
                            val challenge = json.decodeFromString(ChallengeResponse.serializer(), body)

                            if (challenge.challenge.length != 64) {
                                return@use Result.failure(
                                    IllegalStateException("Invalid challenge length: expected 64 hex chars, got ${challenge.challenge.length}"),
                                )
                            }

                            val challengeBytes =
                                challenge.challenge.chunked(2)
                                    .map { it.toInt(16).toByte() }
                                    .toByteArray()

                            if (challengeBytes.size != 32) {
                                return@use Result.failure(
                                    IllegalStateException("Invalid challenge byte length: expected 32, got ${challengeBytes.size}"),
                                )
                            }

                            Result.success(challenge.challenge_id to challengeBytes)
                        }
                    result
                } catch (e: Exception) {
                    Timber.e(e, "Failed to fetch server challenge")
                    Result.failure(e)
                }
            }

        /**
         * Preserve current issuance data.
         * Returns true on success, false if the underlying storage write failed.
         */
        suspend fun preserveIssuanceData(
            dobDays: Int? = null,
            documentVerified: Boolean = false,
            dobMatches: Boolean = false,
        ): Boolean {
            val preservedData =
                PreservedIssuanceData(
                    dobDays = dobDays,
                    documentVerified = documentVerified,
                    dobMatches = dobMatches,
                    timestamp = System.currentTimeMillis(),
                )

            val success = dataPreservationManager.preserve("officer_issuance", preservedData)
            if (success) {
                Timber.d("OfficerAuthManager: issuance data preserved")
            } else {
                Timber.e("OfficerAuthManager: preservation failed for officer_issuance; user data may be lost on session expiry")
            }
            return success
        }

        /**
         * Restore preserved issuance data
         */
        suspend fun restoreIssuanceData(): PreservedIssuanceData? {
            val restored = dataPreservationManager.restore<PreservedIssuanceData>("officer_issuance")
            if (restored != null) {
                Timber.d("Issuance data restored")
            }
            return restored
        }

        /**
         * Clear preserved issuance data
         */
        suspend fun clearPreservedData() {
            dataPreservationManager.clear("officer_issuance")
            Timber.d("Preserved issuance data cleared")
        }

        /**
         * Convert ISO date string to days since Unix epoch
         */
        private fun dobIsoToDays(dobIso: String): Int {
            val dobDate = LocalDate.parse(dobIso, DateTimeFormatter.ISO_LOCAL_DATE)
            val epoch = LocalDate.of(1970, 1, 1)
            return ChronoUnit.DAYS.between(epoch, dobDate).toInt()
        }

        /**
         * Create attestation for a given DOB using YubiKey authentication.
         * This is a single-step flow that requires one YubiKey touch.
         *
         * NEW BLIND ATTESTATION FLOW:
         * - Officer enters DOB and touches YubiKey
         * - Server creates attestation (signed DOB) without any commitment
         * - User scans attestation QR, generates r_bits locally, and calls blind issuance
         * - PRIVACY: Officer never sees commitment C or r_bits
         *
         * @param dobIso DOB in ISO format (YYYY-MM-DD)
         * @param documentVerified Whether the officer verified the physical document
         * @param dobMatches Whether the DOB matches the document
         * @return Result containing the base64-encoded attestation string on success
         */
        suspend fun createAttestation(
            dobIso: String,
            documentVerified: Boolean,
            dobMatches: Boolean,
        ): Result<String> =
            withContext(Dispatchers.IO) {
                try {
                    Timber.d("Creating attestation for DOB (using ${EnvironmentManager.getCurrentEnvironment()} environment)")

                    _issuanceState.value = IssuanceState.ValidatingInput

                    // Get officer ID from storage (set during authenticateOfficer)
                    val officerId = getOfficerId()
                    if (officerId == null) {
                        val errorMsg = context.getString(R.string.officer_auth_error_not_authenticated)
                        _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                        return@withContext Result.failure(IllegalStateException(errorMsg))
                    }

                    // Validate officer ID format (accepts email addresses)
                    if (!officerId.matches(Regex("^[a-zA-Z0-9@._+-]+$"))) {
                        val errorMsg = context.getString(R.string.officer_auth_error_invalid_format)
                        _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                        return@withContext Result.failure(IllegalArgumentException(errorMsg))
                    }

                    // Validate inputs
                    if (!documentVerified || !dobMatches) {
                        val errorMsg = context.getString(R.string.officer_auth_error_verify_document_dob)
                        _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = false)
                        return@withContext Result.failure(Exception(errorMsg))
                    }

                    // Validate DOB format and age
                    val dobDate =
                        try {
                            LocalDate.parse(dobIso, DateTimeFormatter.ISO_LOCAL_DATE)
                        } catch (e: Exception) {
                            val errorMsg = context.getString(R.string.officer_auth_error_invalid_date_format)
                            _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                            return@withContext Result.failure(Exception(errorMsg))
                        }

                    val age = Period.between(dobDate, LocalDate.now()).years
                    Timber.d("Attestation for age: $age years")

                    // Step 0: Refresh YubiKey connection before challenge fetch
                    yubikeyManager.refreshConnection()
                    kotlinx.coroutines.delay(500)

                    // Step 1: Get server challenge
                    val (challengeId, challengeBytes) =
                        fetchServerChallenge(officerId).getOrElse {
                            val errorMsg = context.getString(R.string.officer_auth_error_challenge_failed, it.message ?: "")
                            _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                            return@withContext Result.failure(it)
                        }

                    Timber.d("Got server challenge ID: ${redactId(challengeId)}, size: ${challengeBytes.size} bytes")

                    // Step 2: Wait for YubiKey touch and compute HMAC-SHA1(challenge)
                    _issuanceState.value = IssuanceState.CreatingAttestation

                    val hmacResult = yubikeyManager.performHmacChallenge(challengeBytes)

                    if (hmacResult?.isFailure != false) {
                        val errorMsg = context.getString(R.string.officer_auth_error_touch_timeout)
                        _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                        return@withContext Result.failure(Exception(errorMsg))
                    }

                    val hmacBytes = hmacResult.getOrThrow()
                    val hmacHex = hex(hmacBytes)
                    java.util.Arrays.fill(hmacBytes, 0.toByte())
                    Timber.d("HMAC obtained for attestation")

                    // Step 3: Create attestation via POST /v1/attestation/create
                    _issuanceState.value = IssuanceState.CreatingAttestation

                    val ts = System.currentTimeMillis() / 1000
                    val dobDays = dobIsoToDays(dobIso)

                    // Generate 64 hex char nonce (256 bits) for replay prevention
                    val nonceBytes = ByteArray(32)
                    secureRandom.nextBytes(nonceBytes)
                    val nonce = nonceBytes.joinToString("") { "%02x".format(it) }
                    java.util.Arrays.fill(nonceBytes, 0.toByte())

                    val attestationRequest =
                        AttestationRequest(
                            dob_days = dobDays,
                            authorizer =
                                AttestationAuthorizer(
                                    format = "yubikey",
                                    keyId = officerId,
                                    challengeId = challengeId,
                                    timestamp = ts,
                                    hmac = hmacHex,
                                    nonce = nonce,
                                ),
                        )

                    val requestBody =
                        json.encodeToString(attestationRequest)
                            .toRequestBody("application/json".toMediaType())

                    val request =
                        Request.Builder()
                            .url("$issuerBaseUrl/v1/attestation/create")
                            .post(requestBody)
                            .addHeader("Content-Type", "application/json")
                            .build()

                    val attestationResult =
                        httpClient.newCall(request).execute().use { response ->
                            if (!response.isSuccessful) {
                                val errorBody = response.body?.string() ?: "Unknown error"
                                val errorMsg = "Attestation failed: ${response.code}"
                                Timber.w("Attestation failed: $errorMsg - $errorBody")
                                _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                                return@use Result.failure(Exception(errorMsg))
                            }

                            val responseBody = response.body?.string()
                            if (responseBody == null) {
                                val errorMsg = "Empty response from attestation server"
                                _issuanceState.value = IssuanceState.Error(errorMsg, canRetry = true)
                                return@use Result.failure(Exception(errorMsg))
                            }
                            Result.success(json.decodeFromString(AttestationResponse.serializer(), responseBody))
                        }
                    if (attestationResult.isFailure) {
                        return@withContext Result.failure(attestationResult.exceptionOrNull() ?: Exception("Attestation failed"))
                    }
                    val attestationResponse = attestationResult.getOrThrow()

                    // Build deeplink: provii://attest?d=<base64-attestation>
                    val deeplink = "provii://attest?d=${attestationResponse.attestation}"

                    // Store officer ID for logging
                    keystoreManager.saveSecureString(OFFICER_KEY_ID, officerId)

                    // Log successful WebAuthn authentication
                    auditLogger.logWebAuthnAuthentication(
                        officerId = officerId,
                        credentialId = officerId,
                        success = true,
                    )

                    // Log successful attestation creation
                    auditLogger.logCredentialIssuance(
                        officerId = officerId,
                        requestId = attestationResponse.attestation.take(20) + "...", // Truncated for logging
                        issuerKid = officerId,
                        success = true,
                    )

                    _issuanceState.value = IssuanceState.Complete(attestationResponse.attestation, deeplink)

                    Timber.d("Attestation created successfully")
                    Result.success(attestationResponse.attestation)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to create attestation")

                    // Log failed attestation - use empty string if officerId not available
                    val failedOfficerId =
                        try {
                            getOfficerId() ?: ""
                        } catch (_: Exception) {
                            ""
                        }
                    auditLogger.logWebAuthnAuthentication(
                        officerId = failedOfficerId,
                        credentialId = "",
                        success = false,
                    )

                    if (_issuanceState.value !is IssuanceState.Error) {
                        _issuanceState.value =
                            IssuanceState.Error(
                                message = e.message ?: context.getString(R.string.officer_auth_error_issue_failed),
                                canRetry = true,
                            )
                    }
                    Result.failure(e)
                }
            }

        fun resetIssuance() {
            _issuanceState.value = IssuanceState.Idle
        }

        fun endSession() {
            _issuanceState.value = IssuanceState.Idle

            // Clear session cache first
            updateSessionCache(null)

            // SECURITY: Clear stored officer ID
            try {
                keystoreManager.removeSecureData(OFFICER_KEY_ID)
                Timber.d("Officer credentials cleared securely")
            } catch (e: Exception) {
                Timber.w("Failed to clear officer credentials: ${e.message}")
            }

            // Clear preserved data on normal logout
            managerScope.launch {
                clearPreservedData()
            }
        }

        fun cleanup() {
            managerScope.cancel()
        }
    }
