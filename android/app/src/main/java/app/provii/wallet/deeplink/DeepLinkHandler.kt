// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.deeplink

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Base64
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.navigation.NavController
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import app.provii.wallet.BuildConfig
import app.provii.wallet.R
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.logging.redactId
import app.provii.wallet.navigation.NavigationPayloadStore
import app.provii.wallet.navigation.Screen
import timber.log.Timber
import org.json.JSONObject
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Handles deep links for the Provii Wallet verification and attestation flows
 *
 * Security features (MASVS-PLATFORM-3):
 * - Strict URL validation with trusted domain allowlist
 * - Nonce tracking to prevent replay attacks
 * - Rate limiting to prevent abuse (max 10 deep links per minute)
 * - HTTPS App Links preferred over legacy custom URL scheme
 *
 * Supported URL schemes:
 * Legacy custom scheme (backward compatibility - deprecated):
 * - provii://verify?d={base64url_encoded_json} - Verification challenge from QR/deeplink
 * - provii://attest?d={base64url_data} - Blind attestation with base64 encoded data
 *
 * Secure HTTPS links (App Links / Universal Links - RECOMMENDED):
 * - https://provii.app/verify?d={base64url_encoded_json}
 * - https://provii.app/attest?d={base64url_data}
 *
 * @see <a href="https://developer.android.com/training/app-links">Android App Links</a>
 */
@Singleton
class DeepLinkHandler
    @Inject
    constructor(
        private val context: Context,
        private val auditLogger: app.provii.wallet.security.AuditLogger,
        private val navigationPayloadStore: NavigationPayloadStore,
    ) {
        // ========== SANDBOX DEEP-LINK PROMPT (/ ) ==========

        /**
         * Which signal raised the sandbox confirmation prompt. The dialog copy
         * differs between the two paths so the user understands what was picked
         * up.
         *
         * - [URL]: query-parameter advisory (`?env=sandbox`) seen before
         *   the challenge payload is decoded.
         * - [CHALLENGE]: required `environment` field inside the decoded
         *   challenge payload. The verifier has committed to sandbox in a signed
         *   payload.
         */
        enum class SandboxPromptSource { URL, CHALLENGE }

        /**
         * Payload for the sandbox-mode confirmation prompt. Surfaced when a deep
         * link advertises sandbox while the wallet is in production. Stores the
         * original URI so the handler can resume processing if the user accepts,
         * and the [source] so MainActivity can pick the correct copy.
         */
        data class PendingSandboxPrompt(
            val uri: Uri,
            val source: SandboxPromptSource,
        )

        private val _pendingSandboxPrompt = MutableStateFlow<PendingSandboxPrompt?>(null)

        /**
         * Observed by the UI layer (MainActivity) which presents a Material 3
         * AlertDialog when this flow emits a non-null value. Primary action
         * calls [confirmSandboxPrompt]; secondary action calls
         * [dismissSandboxPrompt].
         */
        val pendingSandboxPrompt: StateFlow<PendingSandboxPrompt?> =
            _pendingSandboxPrompt.asStateFlow()

        // ========== NONCE TRACKING FOR REPLAY PREVENTION ==========

        /**
         * In-memory cache of processed nonces for fast lookup.
         * Backed by EncryptedSharedPreferences so nonces survive process death.
         * Key: nonce/challenge_id, Value: timestamp when processed
         */
        private val processedNonces = ConcurrentHashMap<String, Long>()

        /**
         * Maximum age for nonce entries before cleanup (5 minutes)
         * This window should be longer than the challenge expiration to ensure
         * replayed challenges are caught even after original expiration
         */
        private val nonceMaxAgeMs = 5 * 60 * 1000L

        /**
         * Maximum number of nonces to track before forced cleanup
         */
        private val maxNonceEntries = 1000

        /**
         * EncryptedSharedPreferences for persisting nonces across process death.
         * Uses AES256-GCM encryption to protect nonce data at rest.
         * NEVER use plain SharedPreferences for security-relevant data (MASVS-STORAGE).
         *
         * The underlying file name is environment-scoped
         * (`provii_deeplink_nonces` for production, `provii_deeplink_nonces_sandbox`
         * for sandbox) so that a replay in one environment cannot block a link
         * in the other. Because the wallet can toggle sandbox at runtime, the
         * SharedPreferences instance is opened via a function rather than a
         * lazy delegate. Each call resolves the currently-active bucket.
         */
        private fun noncePrefs(): SharedPreferences {
            val masterKey =
                MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
            return EncryptedSharedPreferences.create(
                context,
                currentNoncePrefsName(),
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }

        /**
         * Track the env in effect the last time we touched the nonce store. If
         * it changes between calls (because the user toggled sandbox), we drop
         * the in-memory cache so entries bound to the previous environment's
         * prefs file do not leak across.
         */
        @Volatile
        private var lastObservedEnv: String = EnvironmentManager.getCurrentEnvironment()

        init {
            // Load persisted nonces into the in-memory cache on startup
            loadPersistedNonces()
        }

        /**
         * Reconcile the in-memory cache with the currently-active environment.
         * Called from every nonce read/write path. If the environment changed
         * since we last looked, clear the cache and reload from the new bucket.
         */
        private fun ensureEnvSyncedWithNonceStore() {
            val current = EnvironmentManager.getCurrentEnvironment()
            if (current != lastObservedEnv) {
                Timber.d("Environment changed ($lastObservedEnv -> $current); refreshing nonce store")
                processedNonces.clear()
                lastObservedEnv = current
                loadPersistedNonces()
            }
        }

        /**
         * Load nonces from EncryptedSharedPreferences into the in-memory cache.
         * Discards any entries older than nonceMaxAgeMs.
         */
        private fun loadPersistedNonces() {
            try {
                val now = System.currentTimeMillis()
                val cutoff = now - nonceMaxAgeMs
                val all = noncePrefs().all
                var loaded = 0
                for ((key, value) in all) {
                    val timestamp = (value as? Long) ?: continue
                    if (timestamp >= cutoff) {
                        processedNonces[key] = timestamp
                        loaded++
                    }
                }
                if (loaded > 0) {
                    Timber.d("Loaded $loaded persisted nonces from encrypted storage")
                }
            } catch (e: Exception) {
                Timber.w(e, "Failed to load persisted nonces, starting with empty cache")
            }
        }

        /**
         * Persist a nonce to EncryptedSharedPreferences after adding it to the in-memory cache.
         */
        private fun persistNonce(
            nonce: String,
            timestamp: Long,
        ) {
            try {
                noncePrefs().edit().putLong(nonce, timestamp).apply()
            } catch (e: Exception) {
                Timber.w(e, "Failed to persist nonce to encrypted storage")
            }
        }

        /**
         * Remove expired nonces from EncryptedSharedPreferences.
         */
        private fun prunePersistedNonces(keysToRemove: Collection<String>) {
            try {
                val editor = noncePrefs().edit()
                for (key in keysToRemove) {
                    editor.remove(key)
                }
                editor.apply()
            } catch (e: Exception) {
                Timber.w(e, "Failed to prune persisted nonces")
            }
        }

        // ========== RATE LIMITING ==========

        /**
         * Rate limiting: max deep links per time window
         */
        private val rateLimitWindowMs = 60 * 1000L // 1 minute window
        private val maxDeepLinksPerWindow = 10 // Max 10 deep links per minute

        /**
         * Tracks deep link processing for rate limiting
         */
        private val rateLimitCounter = AtomicInteger(0)
        private val rateLimitWindowStart = AtomicLong(System.currentTimeMillis())

        companion object {
            const val SCHEME_PROVIIWALLET = "provii"
            const val SCHEME_HTTPS = "https"
            const val HOST_PROVIIWALLET_APP = "provii.app"
            const val HOST_VERIFY = "verify"
            const val HOST_ATTEST = "attest"
            const val PATH_VERIFY = "/verify"
            const val PATH_ATTEST = "/attest"
            const val PARAM_DATA = "d"
            const val PARAM_TOKEN = "token"
            const val PARAM_KEY = "key"

            /**
             * EncryptedSharedPreferences file name for nonce persistence across
             * process death, production bucket.
             */
            private const val NONCE_PREFS_NAME_PRODUCTION = "provii_deeplink_nonces"

            /**
             * EncryptedSharedPreferences file name for nonce persistence across
             * process death, sandbox bucket (). Kept separate from
             * production so a replay observed in sandbox cannot block a
             * legitimate production link, and vice versa.
             */
            private const val NONCE_PREFS_NAME_SANDBOX = "provii_deeplink_nonces_sandbox"

            /**
             * Returns the SharedPreferences file name for the currently-active
             * environment. Resolved at call time so runtime sandbox toggles
             * route subsequent reads and writes to the correct bucket.
             */
            internal fun currentNoncePrefsName(): String {
                return if (EnvironmentManager.isSandboxEnabled()) {
                    NONCE_PREFS_NAME_SANDBOX
                } else {
                    NONCE_PREFS_NAME_PRODUCTION
                }
            }

            // Get default verify URL from EnvironmentManager
            private val defaultVerifyUrl: String
                get() = EnvironmentManager.getVerifierVerifyUrl()

            // Trusted verifier domains for validation - dynamically determined by environment.
            // SECURITY (INV-WM-014): This allowlist MUST match the iOS DeepLinkHandler
            // trustedVerifierDomains exactly. Only .app domains are legitimate; the .au and
            // .com.au domains were added in error and have been removed.
            private val trustedVerifierDomains: Set<String>
                get() {
                    val baseSet =
                        mutableSetOf(
                            "verify.provii.app",
                            "invokeprovii.com", // Demo domain
                        )

                    // Add sandbox domains if in sandbox mode
                    if (EnvironmentManager.isSandboxEnabled()) {
                        baseSet.add("sandbox-verify.provii.app")
                        baseSet.add("sandbox.invokeprovii.com")
                    }

                    // Add staging/dev domains based on environment
                    when (EnvironmentManager.getCurrentEnvironment()) {
                        "staging" -> {
                            baseSet.add("staging-verify.provii.app")
                        }
                        "development" -> {
                            baseSet.add("dev-verify.provii.app")
                        }
                    }

                    return baseSet
                }
        }

        // ========== RATE LIMITING METHODS ==========

        /**
         * Check if deep link processing is rate limited.
         * Returns true if the request should be blocked due to rate limiting.
         *
         * @return true if rate limited, false if request can proceed
         */
        private fun isRateLimited(): Boolean {
            val now = System.currentTimeMillis()
            val windowStart = rateLimitWindowStart.get()

            // Check if we need to reset the window
            if (now - windowStart > rateLimitWindowMs) {
                // Atomically reset the window
                if (rateLimitWindowStart.compareAndSet(windowStart, now)) {
                    rateLimitCounter.set(1)
                    return false
                }
            }

            // Increment and check counter
            val count = rateLimitCounter.incrementAndGet()
            if (count > maxDeepLinksPerWindow) {
                Timber.w("Deep link rate limited: $count requests in window")
                auditLogger.logDeepLink(
                    scheme = "rate_limit",
                    action = "blocked",
                    details =
                        mapOf(
                            "count" to count,
                            "max" to maxDeepLinksPerWindow,
                            "window_ms" to rateLimitWindowMs,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return true
            }

            return false
        }

        // ========== NONCE TRACKING METHODS ==========

        /**
         * Check if a nonce/challenge_id has already been processed (replay attack detection).
         * Also records the nonce if not previously seen.
         *
         * @param nonce The unique identifier to check (challenge_id, attestation data, etc.)
         * @return true if this is a replay (nonce already seen), false if new
         */
        private fun isReplayAttack(nonce: String): Boolean {
            // Rebuild the in-memory cache if the environment changed
            // since the last nonce check. Entries from the previous environment's
            // EncryptedSharedPreferences file must not influence this decision.
            ensureEnvSyncedWithNonceStore()

            cleanupExpiredNonces()

            val now = System.currentTimeMillis()
            val previousTimestamp = processedNonces.putIfAbsent(nonce, now)

            if (previousTimestamp != null) {
                // Nonce was already processed
                val ageMs = now - previousTimestamp
                Timber.w("Replay attack detected: nonce was processed ${ageMs}ms ago")
                auditLogger.logDeepLink(
                    scheme = "security",
                    action = "replay_attack_blocked",
                    details =
                        mapOf(
                            "nonce" to nonce.take(16) + "...", // Truncate for log safety
                            "age_ms" to ageMs,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return true
            }

            // Persist to EncryptedSharedPreferences so nonce survives process death
            persistNonce(nonce, now)
            return false
        }

        /**
         * Clean up expired nonce entries to prevent memory growth.
         * Called automatically before each nonce check.
         */
        private fun cleanupExpiredNonces() {
            val now = System.currentTimeMillis()
            val cutoff = now - nonceMaxAgeMs

            // Remove entries older than the max age from in-memory cache
            val expiredKeys = mutableListOf<String>()
            processedNonces.entries.removeIf { (key, timestamp) ->
                val expired = timestamp < cutoff
                if (expired) expiredKeys.add(key)
                expired
            }

            // If still too many entries, force cleanup of oldest half
            if (processedNonces.size > maxNonceEntries) {
                val sorted = processedNonces.entries.sortedBy { it.value }
                val toRemove = sorted.take(sorted.size / 2)
                toRemove.forEach { entry ->
                    processedNonces.remove(entry.key)
                    expiredKeys.add(entry.key)
                }
                Timber.d("Forced nonce cleanup: removed ${toRemove.size} entries")
            }

            // Prune expired nonces from persistent storage
            if (expiredKeys.isNotEmpty()) {
                prunePersistedNonces(expiredKeys)
            }
        }

        // ========== SANDBOX PROMPT CALLBACKS () ==========

        /**
         * Confirm the sandbox prompt: enable sandbox mode and re-dispatch the
         * original deep-link URI so the handler can route it. Returns the
         * navigation route produced by handleUri, or null if the re-dispatch
         * fails for any reason.
         *
         * SECURITY: Enabling sandbox switches all API endpoints to the sandbox
         * environment. The user's explicit confirmation is the consent gate.
         */
        fun confirmSandboxPrompt(): String? {
            val prompt = _pendingSandboxPrompt.value ?: return null
            _pendingSandboxPrompt.value = null

            auditLogger.logDeepLink(
                scheme = prompt.uri.scheme ?: "unknown",
                action = "sandbox_prompt_confirmed",
                details =
                    mapOf(
                        "environment" to EnvironmentManager.getCurrentEnvironment(),
                    ),
            )

            EnvironmentManager.enableSandbox(true)
            // drop in-memory nonces bound to the previous environment's
            // prefs file so they cannot poison the sandbox bucket. The new
            // environment's persisted nonces (if any) are re-loaded on the next
            // isReplayAttack call via ensureEnvSyncedWithNonceStore.
            processedNonces.clear()
            lastObservedEnv = EnvironmentManager.getCurrentEnvironment()
            return handleUri(prompt.uri)
        }

        /**
         * Dismiss the sandbox prompt and drop the pending deep-link silently.
         * Called by the UI layer when the user taps the secondary action on the
         * sandbox confirmation dialog.
         */
        fun dismissSandboxPrompt() {
            val prompt = _pendingSandboxPrompt.value ?: return
            _pendingSandboxPrompt.value = null

            auditLogger.logDeepLink(
                scheme = prompt.uri.scheme ?: "unknown",
                action = "sandbox_prompt_cancelled",
                details =
                    mapOf(
                        "environment" to EnvironmentManager.getCurrentEnvironment(),
                    ),
            )
        }

        /**
         * Clear nonce tracking (for testing purposes only)
         */
        fun clearNonceTracking() {
            processedNonces.clear()
            try {
                noncePrefs().edit().clear().apply()
            } catch (e: Exception) {
                Timber.w(e, "Failed to clear persisted nonce storage")
            }
            Timber.d("Nonce tracking cleared (memory and persistent storage)")
        }

        /**
         * Get statistics for monitoring (testing/debugging)
         */
        fun getSecurityStats(): Map<String, Any> {
            return mapOf(
                "tracked_nonces" to processedNonces.size,
                "rate_limit_count" to rateLimitCounter.get(),
                "rate_limit_window_remaining_ms" to maxOf(0L, rateLimitWindowMs - (System.currentTimeMillis() - rateLimitWindowStart.get())),
            )
        }

        // ========== URL VALIDATION ==========

        /**
         * Validate URL structure and characters to prevent injection attacks.
         *
         * ADV-WM-002: Iteratively percent-decodes the URL before pattern matching to
         * defeat double/triple encoding bypasses. Patterns are checked against the
         * fully decoded form so that %3Cscript, %253Cscript, etc. are all caught.
         *
         * @param url The URL string to validate
         * @return true if the URL is safe and well-formed
         */
        private fun isValidUrlStructure(url: String): Boolean {
            // Reject empty or excessively long URLs
            if (url.isEmpty() || url.length > 2048) {
                Timber.w("URL validation failed: invalid length ${url.length}")
                return false
            }

            // Iteratively percent-decode to defeat double/triple encoding.
            val decoded = iterativePercentDecode(url, maxIterations = 5)
            val decodedLower = decoded.lowercase()

            // Reject URLs with suspicious patterns (checked against decoded form)
            val suspiciousPatterns =
                listOf(
                    "javascript:", // XSS attempt
                    "data:", // Data URL injection
                    "vbscript:", // VBScript injection
                    "<script", // Script tag injection
                    "\n", // Newline injection
                    "\r", // Carriage return injection
                    "\u0000", // Null byte injection
                    "../", // Path traversal
                    "..\\", // Path traversal (backslash)
                    "\${", // Expression/JNDI injection
                )

            for (pattern in suspiciousPatterns) {
                if (decodedLower.contains(pattern)) {
                    Timber.w("URL validation failed: suspicious pattern detected")
                    auditLogger.logDeepLink(
                        scheme = "security",
                        action = "url_injection_blocked",
                        details =
                            mapOf(
                                "pattern" to pattern,
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    return false
                }
            }

            return true
        }

        /**
         * Iteratively percent-decode a string until it stabilises or the iteration
         * limit is reached. Defeats double-encoding, triple-encoding, etc.
         */
        private fun iterativePercentDecode(
            value: String,
            maxIterations: Int,
        ): String {
            var current = value
            for (i in 0 until maxIterations) {
                val next =
                    try {
                        java.net.URLDecoder.decode(current, "UTF-8")
                    } catch (_: Exception) {
                        break
                    }
                if (next == current) break
                current = next
            }
            return current
        }

        /**
         * Validate and sanitize a domain name.
         *
         * @param domain The domain to validate
         * @return true if the domain is valid
         */
        private fun isValidDomain(domain: String?): Boolean {
            if (domain.isNullOrEmpty()) return false

            // Domain length check
            if (domain.length > 253) return false

            // Valid domain character pattern (alphanumeric, hyphens, dots)
            val domainPattern = Regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
            if (!domain.matches(domainPattern)) {
                Timber.w("Invalid domain format: $domain")
                return false
            }

            return true
        }

        // ========== BIOMETRIC GATE FOR VERIFICATION DEEP LINKS ==========

        /**
         * SECURITY (MASVS-AUTH-1): Require biometric authentication before processing
         * verification deep links. This prevents an attacker with physical device access
         * from triggering proof generation without the legitimate user's consent.
         *
         * Must be called from a FragmentActivity context (BiometricPrompt requirement).
         * Returns true if authentication succeeded, false if it failed or was cancelled.
         *
         * If biometric hardware is not available or no biometrics are enrolled, returns
         * true (the user has no biometric protection configured and we cannot force
         * enrolment from a deep link handler).
         */
        suspend fun requireBiometricForVerification(activity: FragmentActivity): Boolean {
            val biometricManager = BiometricManager.from(activity)
            val canAuthenticateBiometric =
                biometricManager.canAuthenticate(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG,
                )

            // Determine which authenticator to use. When strong biometrics are
            // available, prefer them. When no biometrics are enrolled, fall back to device
            // credential (PIN/pattern/password) instead of skipping authentication entirely.
            // Only skip when NO authentication mechanism is available at all (no hardware).
            val authenticators: Int
            when (canAuthenticateBiometric) {
                BiometricManager.BIOMETRIC_SUCCESS -> {
                    authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG
                }
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
                    // No biometrics enrolled. Fall back to device credential (PIN/pattern/password).
                    val canAuthenticateDevice =
                        biometricManager.canAuthenticate(
                            BiometricManager.Authenticators.DEVICE_CREDENTIAL,
                        )
                    if (canAuthenticateDevice == BiometricManager.BIOMETRIC_SUCCESS) {
                        Timber.d("Biometric gate: no biometrics enrolled, falling back to device credential")
                        authenticators = BiometricManager.Authenticators.DEVICE_CREDENTIAL
                    } else {
                        // No biometrics AND no device credential (no lock screen). Block the operation.
                        Timber.w("Biometric gate: no biometrics enrolled and no device credential configured")
                        auditLogger.logDeepLink(
                            scheme = "security",
                            action = "biometric_gate_no_auth_available",
                            details =
                                mapOf(
                                    "biometric_status" to canAuthenticateBiometric,
                                    "device_credential_status" to canAuthenticateDevice,
                                    "environment" to EnvironmentManager.getCurrentEnvironment(),
                                ),
                        )
                        return false
                    }
                }
                BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> {
                    // No biometric hardware. Fall back to device credential if available.
                    val canAuthenticateDevice =
                        biometricManager.canAuthenticate(
                            BiometricManager.Authenticators.DEVICE_CREDENTIAL,
                        )
                    if (canAuthenticateDevice == BiometricManager.BIOMETRIC_SUCCESS) {
                        Timber.d("Biometric gate: no biometric hardware, falling back to device credential")
                        authenticators = BiometricManager.Authenticators.DEVICE_CREDENTIAL
                    } else {
                        Timber.w("Biometric gate: no biometric hardware and no device credential configured")
                        auditLogger.logDeepLink(
                            scheme = "security",
                            action = "biometric_gate_no_auth_available",
                            details =
                                mapOf(
                                    "biometric_status" to canAuthenticateBiometric,
                                    "device_credential_status" to canAuthenticateDevice,
                                    "environment" to EnvironmentManager.getCurrentEnvironment(),
                                ),
                        )
                        return false
                    }
                }
                else -> {
                    // Hardware present but unavailable (BIOMETRIC_ERROR_HW_UNAVAILABLE,
                    // BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED, etc.). Block the operation.
                    Timber.w("Biometric gate: biometric hardware unavailable ($canAuthenticateBiometric)")
                    auditLogger.logDeepLink(
                        scheme = "security",
                        action = "biometric_gate_hw_unavailable",
                        details =
                            mapOf(
                                "biometric_status" to canAuthenticateBiometric,
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    return false
                }
            }

            val useDeviceCredentialOnly = authenticators == BiometricManager.Authenticators.DEVICE_CREDENTIAL

            return suspendCoroutine { continuation ->
                val executor = ContextCompat.getMainExecutor(activity)
                val prompt =
                    BiometricPrompt(
                        activity,
                        executor,
                        object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                                super.onAuthenticationSucceeded(result)
                                Timber.d("Deep link biometric gate: authentication succeeded")
                                auditLogger.logDeepLink(
                                    scheme = "security",
                                    action = "biometric_gate_passed",
                                    details =
                                        mapOf(
                                            "authenticator" to if (useDeviceCredentialOnly) "device_credential" else "biometric_strong",
                                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                                        ),
                                )
                                continuation.resume(true)
                            }

                            override fun onAuthenticationError(
                                errorCode: Int,
                                errString: CharSequence,
                            ) {
                                super.onAuthenticationError(errorCode, errString)
                                Timber.w("Deep link biometric gate: error $errorCode - $errString")
                                auditLogger.logDeepLink(
                                    scheme = "security",
                                    action = "biometric_gate_failed",
                                    details =
                                        mapOf(
                                            "error_code" to errorCode,
                                            "authenticator" to if (useDeviceCredentialOnly) "device_credential" else "biometric_strong",
                                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                                        ),
                                )
                                continuation.resume(false)
                            }

                            override fun onAuthenticationFailed() {
                                super.onAuthenticationFailed()
                                Timber.w("Deep link biometric gate: bad biometric (user can retry)")
                                // Do NOT resume here; the system will let the user retry.
                                // Only onAuthenticationError or onAuthenticationSucceeded are terminal.
                            }
                        },
                    )

                val promptInfo =
                    if (useDeviceCredentialOnly) {
                        // Device credential prompts must NOT set negative button text
                        BiometricPrompt.PromptInfo.Builder()
                            .setTitle(activity.getString(R.string.keystore_biometric_prompt_title))
                            .setSubtitle(activity.getString(R.string.keystore_biometric_prompt_subtitle_create_proof))
                            .setAllowedAuthenticators(BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                            .build()
                    } else {
                        BiometricPrompt.PromptInfo.Builder()
                            .setTitle(activity.getString(R.string.keystore_biometric_prompt_title))
                            .setSubtitle(activity.getString(R.string.keystore_biometric_prompt_subtitle_create_proof))
                            .setNegativeButtonText(activity.getString(R.string.keystore_biometric_prompt_cancel))
                            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                            .build()
                    }

                prompt.authenticate(promptInfo)
            }
        }

        /**
         * Check whether the given URI targets a verification deep link.
         * Callers should gate verification URIs behind biometric authentication
         * before calling handleUri.
         */
        fun isVerificationDeepLink(uri: Uri): Boolean {
            val scheme = uri.scheme?.lowercase() ?: return false
            val host = uri.host?.lowercase()
            val path = uri.path?.lowercase()

            return when {
                scheme == SCHEME_PROVIIWALLET && host == HOST_VERIFY -> true
                scheme == SCHEME_HTTPS && host == HOST_PROVIIWALLET_APP && path?.startsWith(PATH_VERIFY) == true -> true
                else -> false
            }
        }

        /**
         * Handle URI and return navigation route string, or null if invalid
         * This method performs all security validation and returns the route for navigation
         * Supports both legacy custom scheme (provii://) and secure HTTPS links
         *
         * Security checks performed:
         * 1. Rate limiting (max 10 requests/minute)
         * 2. URL structure validation (length, suspicious patterns)
         * 3. Scheme and host validation
         * 4. Nonce/challenge replay detection (in specific handlers)
         *
         * IMPORTANT: For verification deep links, callers MUST call
         * requireBiometricForVerification() before calling this method.
         * Use isVerificationDeepLink() to determine if the URI requires biometric gating.
         */
        fun handleUri(uri: Uri): String? {
            // SECURITY: Rate limiting check
            if (isRateLimited()) {
                Timber.w("Deep link rejected: rate limit exceeded")
                return null
            }

            // SECURITY: Validate URL structure
            val uriString = uri.toString()
            if (!isValidUrlStructure(uriString)) {
                Timber.w("Deep link rejected: invalid URL structure")
                auditLogger.logDeepLink(
                    scheme = uri.scheme ?: "unknown",
                    action = "url_validation_failed",
                    details =
                        mapOf(
                            "uri_length" to uriString.length,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            val scheme = uri.scheme?.lowercase() ?: return null
            val host = uri.host?.lowercase()
            val path = uri.path?.lowercase()

            // Advisory `env` query parameter. If the deep-link carries
            // `?env=sandbox` and the wallet is currently in production, prompt
            // the user before continuing. The allowlist checks below are deferred
            // until the user accepts the prompt, at which point handleUri runs
            // again from the top via confirmSandboxPrompt().
            val envValue = uri.getQueryParameter("env")?.lowercase()
            if (envValue == "sandbox" && !EnvironmentManager.isSandboxEnabled()) {
                Timber.i("Deep link carries env=sandbox but wallet is production; prompting user")
                auditLogger.logDeepLink(
                    scheme = scheme,
                    action = "sandbox_prompt_presented",
                    details =
                        mapOf(
                            "host" to (host ?: "null"),
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                _pendingSandboxPrompt.value = PendingSandboxPrompt(uri, SandboxPromptSource.URL)
                return null
            }

            // SECURITY: Log legacy scheme usage for migration tracking
            if (scheme == SCHEME_PROVIIWALLET) {
                Timber.i("Legacy URL scheme used. Consider migrating to App Links (https://).")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "legacy_scheme_used",
                    details =
                        mapOf(
                            "host" to (host ?: "null"),
                            "recommendation" to "migrate_to_app_links",
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
            }

            return when {
                // Legacy custom scheme: provii://verify, provii://attest
                scheme == SCHEME_PROVIIWALLET -> {
                    when (host) {
                        HOST_VERIFY -> handleVerifyUri(uri)
                        HOST_ATTEST -> handleAttestUri(uri)
                        else -> {
                            Timber.w("Unknown deep link host: $host")
                            auditLogger.logDeepLink(
                                scheme = SCHEME_PROVIIWALLET,
                                action = "unknown_host_rejected",
                                details =
                                    mapOf(
                                        "host" to (host ?: "null"),
                                        "environment" to EnvironmentManager.getCurrentEnvironment(),
                                    ),
                            )
                            null
                        }
                    }
                }
                // HTTPS App Links: https://provii.app/verify, /attest (PREFERRED)
                scheme == SCHEME_HTTPS && host == HOST_PROVIIWALLET_APP -> {
                    when {
                        path?.startsWith(PATH_VERIFY) == true -> handleVerifyUri(uri)
                        path?.startsWith(PATH_ATTEST) == true -> handleAttestUri(uri)
                        else -> {
                            Timber.w("Unknown App Link path: $path")
                            auditLogger.logDeepLink(
                                scheme = SCHEME_HTTPS,
                                action = "unknown_path_rejected",
                                details =
                                    mapOf(
                                        "path" to (path ?: "null"),
                                        "environment" to EnvironmentManager.getCurrentEnvironment(),
                                    ),
                            )
                            null
                        }
                    }
                }
                else -> {
                    Timber.w("Unsupported scheme or host: $scheme://$host")
                    auditLogger.logDeepLink(
                        scheme = scheme,
                        action = "unsupported_scheme_rejected",
                        details =
                            mapOf(
                                "host" to (host ?: "null"),
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    null
                }
            }
        }

        /**
         * Handle deep links from both onCreate and onNewIntent
         * Returns true if the deep link was handled successfully
         * Supports both legacy custom scheme and secure HTTPS App Links
         *
         * Note: This method delegates to handleUri for the main security checks.
         * It's kept for backward compatibility with NavController-based navigation.
         */
        fun handleIntent(
            intent: Intent?,
            navController: NavController?,
        ): Boolean {
            if (intent == null) return false
            if (intent.action != Intent.ACTION_VIEW) return false

            val data: Uri = intent.data ?: return false

            // Need a NavController to navigate
            if (navController == null) {
                Timber.w("DeepLinkHandler: NavController is null, cannot handle deep link")
                return false
            }

            // Delegate to handleUri which includes all security checks
            val route = handleUri(data)
            if (route != null) {
                navController.navigate(route) {
                    launchSingleTop = true
                    popUpTo(Screen.CredentialList.route) { inclusive = false }
                }
                return true
            }
            return false
        }

        /**
         * Handle verification URI and return navigation route, or null if invalid
         *
         * Security: Includes replay attack prevention using challenge_id as nonce
         */
        private fun handleVerifyUri(uri: Uri): String? {
            val encodedData = uri.getQueryParameter(PARAM_DATA)
            if (encodedData.isNullOrBlank()) {
                Timber.e("Verify deep link missing 'd' parameter")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "verify_invalid",
                    details =
                        mapOf(
                            "reason" to "missing_d_parameter",
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            return try {
                // Decode base64url to JSON string (with size validation)
                val json = decodeBase64Url(encodedData) ?: return null
                Timber.d("Deep link (verify) received, payload size: ${json.length} bytes")

                // Parse and validate the challenge payload
                val challengePayload = parseAndValidateChallengePayload(json)
                if (challengePayload == null) {
                    Timber.e("Failed to parse or validate challenge payload")
                    return null
                }

                // sandbox-marked challenge received while the wallet
                // is running in production. Raise the challenge-specific sandbox
                // prompt and defer routing. If the user accepts, the caller
                // re-dispatches the URI via confirmSandboxPrompt() and the
                // second pass finds `isSandboxEnabled == true`, skipping this
                // branch.
                //
                // This check runs BEFORE the replay check so the challenge_id
                // does not get consumed by a rejected attempt.
                val challengeEnv = challengePayload.optString("environment")
                if (challengeEnv == "sandbox" && !EnvironmentManager.isSandboxEnabled()) {
                    Timber.i("Challenge payload is sandbox-marked but wallet is production; prompting user")
                    auditLogger.logDeepLink(
                        scheme = SCHEME_PROVIIWALLET,
                        action = "challenge_sandbox_prompt_presented",
                        details =
                            mapOf(
                                "challenge_id" to challengePayload.getString("challenge_id"),
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    _pendingSandboxPrompt.value = PendingSandboxPrompt(uri, SandboxPromptSource.CHALLENGE)
                    return null
                }

                // SECURITY: Check for replay attack using challenge_id as nonce
                val challengeId = challengePayload.getString("challenge_id")
                if (isReplayAttack(challengeId)) {
                    Timber.e("Verification replay attack detected for challenge: ${redactId(challengeId)}")
                    auditLogger.logDeepLink(
                        scheme = SCHEME_PROVIIWALLET,
                        action = "verify_replay_blocked",
                        details =
                            mapOf(
                                "challenge_id" to challengeId,
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    return null
                }

                // `wallet_env` reports which env the wallet processed
                // THIS challenge under. Named distinctly from `environment`
                // (which is the wallet's currently-selected env) so upstream
                // consumers can differentiate wallet state from per-challenge
                // processing env. `challenge_env` mirrors the value the verifier
                // signed into the payload.
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "verify",
                    details =
                        mapOf(
                            "challenge_id" to challengeId,
                            "verifier" to Uri.parse(challengePayload.optString("verify_url", defaultVerifyUrl)).host,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                            "wallet_env" to EnvironmentManager.getCurrentEnvironment(),
                            "challenge_env" to challengePayload.optString("environment"),
                        ),
                )

                // Store challenge JSON and return a UUID-keyed route so sensitive
                // data never appears in the navigation back-stack string.
                val payloadKey = navigationPayloadStore.put(json)
                "deeplink_verification/$payloadKey"
            } catch (e: Exception) {
                Timber.e(e, "Failed to handle verification deep link")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "verify_failed",
                    details =
                        mapOf(
                            "error" to e.message,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                null
            }
        }

        /**
         * Handle verification challenge deep link
         * provii://verify?d=<base64url_encoded_json>
         */
        private fun handleVerifyDeepLink(
            uri: Uri,
            navController: NavController,
        ): Boolean {
            val route = handleVerifyUri(uri)
            if (route != null) {
                navController.navigate(route) {
                    launchSingleTop = true
                    // Keep credential list in back stack in case user needs to go back
                    popUpTo(Screen.CredentialList.route) { inclusive = false }
                }
                return true
            }
            return false
        }

        /**
         * Handle attestation URI and return navigation route, or null if invalid
         * provii://attest?d=<base64url_encoded_attestation>
         *
         * This enables blind issuance flow where officers create attestations that users
         * scan to obtain credentials. The wallet generates r_bits locally for privacy.
         *
         * Security: Includes replay attack prevention using attestation hash as nonce
         */
        private fun handleAttestUri(uri: Uri): String? {
            val attestationData = uri.getQueryParameter(PARAM_DATA)

            if (attestationData.isNullOrEmpty()) {
                Timber.w("Attest deep link missing 'd' parameter")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "attest_invalid",
                    details =
                        mapOf(
                            "reason" to "missing_d_parameter",
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            // Validate size (attestation should be small, ~500 chars max)
            if (attestationData.length > 1000) {
                Timber.w("Attest deep link data too large: ${attestationData.length} chars")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "attest_invalid",
                    details =
                        mapOf(
                            "reason" to "data_too_large",
                            "data_length" to attestationData.length,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            // Validate base64url format
            if (!isValidBase64Url(attestationData)) {
                Timber.w("Attest deep link data is not valid base64url")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "attest_invalid",
                    details =
                        mapOf(
                            "reason" to "invalid_base64url",
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            // SECURITY: Check for replay attack using SHA-256 of attestation data as nonce.
            // hashCode() is only 32 bits and has trivial collision rate; SHA-256 is collision-resistant.
            val attestDigest =
                MessageDigest.getInstance("SHA-256")
                    .digest(attestationData.toByteArray(Charsets.UTF_8))
            val nonceKey = "attest:${Base64.encodeToString(attestDigest, Base64.NO_WRAP or Base64.URL_SAFE)}"
            if (isReplayAttack(nonceKey)) {
                Timber.w("Attestation replay attack detected")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "attest_replay_blocked",
                    details =
                        mapOf(
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            Timber.i("Attest deep link accepted, data size: ${attestationData.length} chars")

            auditLogger.logDeepLink(
                scheme = SCHEME_PROVIIWALLET,
                action = "attest",
                details =
                    mapOf(
                        "data_length" to attestationData.length,
                        "environment" to EnvironmentManager.getCurrentEnvironment(),
                    ),
            )

            // Store attestation data and return a UUID-keyed route so the raw
            // attestation never appears in the navigation back-stack string.
            val payloadKey = navigationPayloadStore.put(attestationData)
            return "deeplink_attest/$payloadKey"
        }

        /**
         * Parse and validate challenge payload from JSON
         */
        private fun parseAndValidateChallengePayload(json: String): JSONObject? {
            return try {
                val payload = JSONObject(json)

                // Check required fields
                if (!payload.has("challenge_id") || payload.getString("challenge_id").isBlank()) {
                    Timber.e("Invalid challenge_id in payload")
                    return null
                }

                if (!payload.has("rp_challenge") || payload.getString("rp_challenge").length != 43) {
                    Timber.e("Invalid rp_challenge length")
                    return null
                }

                if (!payload.has("submit_secret") || payload.getString("submit_secret").length != 43) {
                    Timber.e("Invalid submit_secret length")
                    return null
                }

                if (!payload.has("cutoff_days") || !payload.has("verifying_key_id")) {
                    Timber.e("Missing required numeric fields")
                    return null
                }

                // `environment` is a required field. Missing or
                // unrecognised values indicate a malformed payload from an
                // upstream that is not speaking the current challenge contract.
                // The gateway always emits this field
                // so absence is a protocol violation rather than
                // something to paper over with a default.
                if (!payload.has("environment")) {
                    Timber.e("Missing required environment field in challenge payload")
                    auditLogger.logDeepLink(
                        scheme = SCHEME_PROVIIWALLET,
                        action = "verify_invalid",
                        details =
                            mapOf(
                                "reason" to "missing_environment_field",
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    return null
                }
                val environmentValue = payload.getString("environment").lowercase()
                if (environmentValue != "sandbox" && environmentValue != "production") {
                    Timber.e("Invalid environment value in challenge payload: $environmentValue")
                    auditLogger.logDeepLink(
                        scheme = SCHEME_PROVIIWALLET,
                        action = "verify_invalid",
                        details =
                            mapOf(
                                "reason" to "invalid_environment_value",
                                "environment" to EnvironmentManager.getCurrentEnvironment(),
                            ),
                    )
                    return null
                }
                // Normalise to lowercase so downstream comparisons do not need
                // to repeat the case-folding.
                payload.put("environment", environmentValue)

                // Validate verify_url if provided
                val verifyUrl = payload.optString("verify_url")
                if (verifyUrl.isNotEmpty() && !isValidVerifyUrl(verifyUrl)) {
                    Timber.e("Untrusted verify URL: $verifyUrl")
                    return null
                }

                // Check expiration if provided
                val expiresAt = payload.optLong("expires_at", 0)
                if (expiresAt > 0) {
                    val now = System.currentTimeMillis() / 1000
                    if (expiresAt < now) {
                        Timber.e("Challenge has expired")
                        return null
                    }
                }

                payload
            } catch (e: Exception) {
                Timber.e(e, "Failed to parse challenge payload")
                null
            }
        }

        /**
         * Decode base64url string to UTF-8 string with size validation
         * Returns null if the payload is too large or decoding fails
         */
        private fun decodeBase64Url(encoded: String): String? {
            // Validate size: max 10000 chars encoded (~7.5KB decoded max)
            if (encoded.length > 10000) {
                Timber.e("Deep link payload too large: ${encoded.length} chars")
                auditLogger.logDeepLink(
                    scheme = SCHEME_PROVIIWALLET,
                    action = "payload_size_exceeded",
                    details =
                        mapOf(
                            "encoded_length" to encoded.length,
                            "max_allowed" to 10000,
                            "environment" to EnvironmentManager.getCurrentEnvironment(),
                        ),
                )
                return null
            }

            return try {
                // Convert base64url to base64
                var base64 =
                    encoded
                        .replace('-', '+')
                        .replace('_', '/')

                // Add padding if necessary
                when (base64.length % 4) {
                    2 -> base64 += "=="
                    3 -> base64 += "="
                }

                val bytes = Base64.decode(base64, Base64.NO_WRAP)
                String(bytes, Charsets.UTF_8)
            } catch (e: Exception) {
                Timber.e(e, "Failed to decode base64url payload")
                null
            }
        }

        /**
         * Validate that the verify URL is from a trusted domain
         */
        private fun isValidVerifyUrl(url: String): Boolean {
            return try {
                val uri = Uri.parse(url)

                // Must be HTTPS (allow HTTP for localhost in debug builds only)
                val isLocalhostHttp = BuildConfig.DEBUG && uri.scheme == "http" && uri.host == "localhost"
                if (uri.scheme != "https" && !isLocalhostHttp) {
                    Timber.w("Verify URL not HTTPS: $url")
                    return false
                }

                // Check if host is in trusted list
                val host = uri.host?.lowercase() ?: return false

                // Allow localhost for testing (debug builds only)
                if (BuildConfig.DEBUG && (host == "localhost" || host == "127.0.0.1" || host == "10.0.2.2")) {
                    return true
                }

                val isValid =
                    trustedVerifierDomains.any { trustedDomain ->
                        host == trustedDomain || host.endsWith(".$trustedDomain")
                    }

                if (!isValid) {
                    Timber.w("Verify URL host not trusted: $host (environment: ${EnvironmentManager.getCurrentEnvironment()})")
                }

                isValid
            } catch (e: Exception) {
                Timber.e(e, "Error validating verify URL")
                false
            }
        }

        /**
         * Validate that a string is valid base64url encoding
         * Base64url uses: A-Z, a-z, 0-9, -, _ (no padding)
         */
        private fun isValidBase64Url(encoded: String): Boolean {
            // Base64url character set: A-Z, a-z, 0-9, -, _
            val base64UrlRegex = Regex("^[A-Za-z0-9_-]+$")

            // Should not be empty
            if (encoded.isEmpty()) {
                return false
            }

            // Should only contain valid base64url characters
            if (!encoded.matches(base64UrlRegex)) {
                Timber.w("HMAC contains invalid base64url characters")
                return false
            }

            // Should not have padding (base64url doesn't use padding)
            if (encoded.contains('=')) {
                Timber.w("HMAC contains padding, not valid base64url")
                return false
            }

            // HMAC-SHA256 produces 32 bytes = 43 base64url chars (without padding)
            // Allow some flexibility for different hash algorithms but warn if unusual
            if (encoded.length < 20 || encoded.length > 100) {
                Timber.w("HMAC length unusual: ${encoded.length} chars (expected ~43 for SHA256)")
            }

            return true
        }

        /**
         * Create a verification deep link (for testing/sharing)
         */
        fun createVerificationDeepLink(
            challengeId: String,
            rpChallenge: String,
            cutoffDays: Int,
            verifyingKeyId: Int,
            submitSecret: String,
            verifyUrl: String? = null,
            expiresAt: Long? = null,
            environment: String? = null,
        ): String {
            val payload =
                JSONObject().apply {
                    put("challenge_id", challengeId)
                    put("rp_challenge", rpChallenge)
                    put("cutoff_days", cutoffDays)
                    put("verifying_key_id", verifyingKeyId)
                    put("submit_secret", submitSecret)
                    // `environment` is a required field. Default to the
                    // wallet's currently-active environment when the caller does
                    // not specify.
                    put("environment", environment ?: EnvironmentManager.getCurrentEnvironment())
                    // Use environment-specific URL if not provided
                    put("verify_url", verifyUrl ?: defaultVerifyUrl)
                    expiresAt?.let { put("expires_at", it) }
                }

            val json = payload.toString()
            val encoded = Base64.encodeToString(json.toByteArray(Charsets.UTF_8), Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

            return "provii://verify?d=$encoded"
        }
    }
