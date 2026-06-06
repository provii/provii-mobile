// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.config

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.provii.wallet.BuildConfig
import app.provii.wallet.security.integrity.RootDetector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import timber.log.Timber
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.SecureRandom
import java.security.spec.ECGenParameterSpec
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Per-install sandbox credential returned by the gateway.
 *
 * `clientId` (prefix `mwallet-sbx-`) doubles as the issuer api key.
 * `hmacSecret` is the base64url HMAC secret used to sign refresh + revoke.
 * `expiresAt` carries the sliding TTL from Sarah's mobile sandbox contract.
 */
data class SandboxCredential(
    val clientId: String,
    val hmacSecret: String,
    val expiresAt: Instant,
) {
    fun isExpired(now: Instant = Instant.now()): Boolean = !now.isBefore(expiresAt)

    fun needsRefresh(now: Instant = Instant.now()): Boolean =
        !now.isBefore(expiresAt.minus(Duration.ofHours(24)))

    override fun toString(): String =
        "SandboxCredential(clientId=$clientId, hmacSecret=[REDACTED], expiresAt=$expiresAt)"
}

class SandboxGatewayException(val statusCode: Int, val responseBody: String) :
    RuntimeException("Sandbox gateway returned HTTP $statusCode: $responseBody")

class SandboxLifetimeExhaustedException :
    RuntimeException("Credential absolute lifetime exhausted; must re-register")

class SandboxEmulatorUnsupportedException :
    RuntimeException("Key attestation requires a physical device with hardware-backed Keystore")

/**
 * sandbox credential lifecycle, using Android Key Attestation in
 * place of Play Integrity (Tim decision 2026-04-16, no Play Console
 * dependency). At first sandbox enable the fetcher:
 *   1. GETs /api/mobile/sandbox/challenge for a gateway-minted nonce.
 *   2. Generates a fresh EC P-256 key pair in AndroidKeyStore with the nonce
 *      as attestation challenge. Tries StrongBox first; falls back to
 *      hardware-backed TEE if StrongBox is absent.
 *   3. Reads the attestation certificate chain off the KeyStore and encodes
 *      it as base64url of the concatenated DER certs.
 *   4. POSTs /api/mobile/sandbox/register with install_uuid, platform,
 *      app_version, attestation_nonce, timestamp_ms, key_attestation_chain.
 *      Gateway returns {client_id, hmac_secret, expires_at}.
 *
 * Refresh + revoke sign `timestamp:POST:path:JCS(body)` with the returned
 * `hmac_secret` via `javax.crypto.Mac` (`HmacSHA256`), the platform
 * primitive for constant-time HMAC comparison. WorkManager reruns
 * /refresh 24 hours before `expiresAt`.
 *
 * Devices without hardware-backed attestation (pre-2018 or rooted) fail on
 * step 2 with a clear error; the gateway also rejects SOFTWARE attestation
 * anyway.
 */
object SandboxCredentialFetcher {
    private val secureRandom = SecureRandom()
    private const val PREFS_NAME = "wallet_sandbox_bootstrap"
    private const val KEY_INSTALL_ID = "provii.install_id"
    private const val KEY_CREDENTIAL = "provii.sandbox.credential"

    // / Android Keystore alias for the per-install attestation key.
    private const val ATTESTATION_KEY_ALIAS = "provii.sandbox.attestation_key"

    internal const val REFRESH_WORK_NAME = "provii.sandbox.refresh"

    // / 16 KiB request-body ceiling per Sarah's contract.
    private const val MAX_BODY_BYTES = 16 * 1024

    // / Canonical HMAC envelope version matching the gateway.
    private const val HMAC_ENVELOPE_VERSION = "mwallet-sbx/v1"

    // / LOW: Client-side challenge TTL safety margin (seconds). Gateway nonces
    // / expire after 60s; we re-fetch if more than 45s elapsed.
    private const val CHALLENGE_TTL_SAFETY_MARGIN_MS = 45_000L

    private val mutex = Mutex()
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    @Volatile
    private var appContext: Context? = null

    @Volatile
    private var prefsOverride: SharedPreferences? = null

    @Volatile
    private var httpClientOverride: OkHttpClient? = null

    @Volatile
    private var baseUrlOverride: String? = null

    @Volatile
    private var attestationProviderOverride: AttestationProvider? = null

    private val defaultHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build()
    }

    /**
     * Must be called once from `Application.onCreate` before any other method.
     */
    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    /**
     * Test hook. Injects SharedPreferences, OkHttp client, base URL, and an
     * attestation provider so tests can run on plain JVM without Android
     * Keystore access.
     */
    internal fun initializeForTesting(
        prefs: SharedPreferences,
        httpClient: OkHttpClient? = null,
        baseUrl: String? = null,
        attestationProvider: AttestationProvider? = null,
    ) {
        prefsOverride = prefs
        httpClientOverride = httpClient
        baseUrlOverride = baseUrl
        attestationProviderOverride = attestationProvider
    }

    private fun prefs(): SharedPreferences {
        prefsOverride?.let { return it }
        val ctx = requireNotNull(appContext) { "SandboxCredentialFetcher.initialize(context) not called" }
        val masterKey =
            androidx.security.crypto.MasterKey.Builder(ctx)
                .setKeyScheme(androidx.security.crypto.MasterKey.KeyScheme.AES256_GCM)
                .build()
        return androidx.security.crypto.EncryptedSharedPreferences.create(
            ctx,
            PREFS_NAME,
            masterKey,
            androidx.security.crypto.EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            androidx.security.crypto.EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    private fun httpClient(): OkHttpClient = httpClientOverride ?: defaultHttpClient

    private fun baseUrl(): String = baseUrlOverride ?: EnvironmentManager.getConfigApi()

    private fun attestationProvider(): AttestationProvider =
        attestationProviderOverride ?: KeyStoreAttestationProvider

    // region install id

    /**
     * Lazy-creates and persists a UUID v4 install id. Gateway spec requires
     * UUID v7 for lexical-time ordering; this implementation emits v7 via
     * [generateUuidV7] since `UUID.randomUUID()` on its own would violate the
     * contract.
     */
    fun installId(): String {
        val store = prefs()
        val existing = store.getString(KEY_INSTALL_ID, null)
        if (!existing.isNullOrBlank()) return existing
        val minted = generateUuidV7()
        store.edit().putString(KEY_INSTALL_ID, minted).apply()
        return minted
    }

    // endregion

    // region lifecycle

    suspend fun register(
        platform: String = "android",
        appVersion: String = defaultAppVersion(),
    ): Result<SandboxCredential> =
        withContext(Dispatchers.IO) {
            mutex.withLock {
                runCatching {
                    // MED-14: Emulator guard. RootDetector.performChecks() detects
                    // emulator environments. Key attestation requires a physical
                    // device with hardware-backed Keystore; the gateway also
                    // rejects SOFTWARE attestation.
                    val ctx = appContext
                    if (ctx != null) {
                        val detection = RootDetector.performChecks(ctx)
                        if (detection.isEmulator) {
                            throw SandboxEmulatorUnsupportedException()
                        }
                    }

                    val challengeStart = System.currentTimeMillis()
                    val nonce = fetchChallenge()
                    val installUuid = installId()
                    val timestampMs = System.currentTimeMillis()

                    // LOW: Client-side challenge TTL check. Re-fetch if stale.
                    if (timestampMs - challengeStart > CHALLENGE_TTL_SAFETY_MARGIN_MS) {
                        throw IllegalStateException("Challenge nonce expired before registration completed")
                    }

                    // BLOCKER-5: attestationChain is now List<String>, each cert
                    // base64url-encoded separately.
                    val attestationChain =
                        attestationProvider().generateAttestationChain(
                            alias = ATTESTATION_KEY_ALIAS,
                            challenge = nonce.toByteArray(Charsets.UTF_8),
                        )
                    val body =
                        sortedMapOf<String, Any>(
                            "app_version" to appVersion,
                            "attestation_nonce" to nonce,
                            "install_uuid" to installUuid,
                            "key_attestation_chain" to attestationChain,
                            "platform" to platform,
                            "timestamp_ms" to timestampMs,
                        )
                    val credential = postForCredential("/api/mobile/sandbox/register", body, signingSecret = null)
                    cache(credential)
                    scheduleRefresh(credential.expiresAt)
                    credential
                }
            }
        }

    suspend fun refresh(): Result<SandboxCredential> =
        withContext(Dispatchers.IO) {
            mutex.withLock {
                runCatching {
                    val current =
                        cachedCredential()
                            ?: throw IllegalStateException("Cannot refresh: no credential cached")
                    // MobileLifecycleRequestSchema only accepts client_id; install_uuid
                    // is stripped by the gateway schema.
                    val body =
                        sortedMapOf<String, Any>(
                            "client_id" to current.clientId,
                        )
                    val credential =
                        postForCredential(
                            "/api/mobile/sandbox/refresh",
                            body,
                            signingSecret = current.hmacSecret,
                            clientId = current.clientId,
                        )
                    cache(credential)
                    scheduleRefresh(credential.expiresAt)
                    credential
                }
            }
        }

    suspend fun revoke(): Result<Unit> =
        withContext(Dispatchers.IO) {
            mutex.withLock {
                runCatching {
                    val current = cachedCredential()
                    if (current == null) {
                        clearCache()
                        cancelScheduledRefresh()
                        return@runCatching
                    }
                    // MobileLifecycleRequestSchema only accepts client_id.
                    val body =
                        sortedMapOf<String, Any>(
                            "client_id" to current.clientId,
                        )
                    postRaw("/api/mobile/sandbox/revoke", body, signingSecret = current.hmacSecret, clientId = current.clientId)
                    clearCache()
                    cancelScheduledRefresh()
                }
            }
        }

    suspend fun currentCredential(): Result<SandboxCredential> =
        withContext(Dispatchers.IO) {
            val cached = cachedCredential()
            if (cached != null) {
                // Fresh and not in the refresh window: return immediately.
                if (!cached.isExpired() && !cached.needsRefresh()) {
                    return@withContext Result.success(cached)
                }
                // BLOCKER-1: Fully expired credentials must never be returned as
                // a fallback. Try refresh first; on failure fall through to register().
                if (cached.isExpired()) {
                    val refreshResult = refresh()
                    if (refreshResult.isSuccess) {
                        return@withContext refreshResult
                    }
                    // Fall through to register().
                } else if (cached.needsRefresh()) {
                    // Within 24h window but not yet expired: best-effort slide.
                    // MED-15: Log refresh failures before falling back.
                    return@withContext refresh().recover { error ->
                        Timber.e(error, "Sandbox credential refresh failed (still valid), using cached")
                        cached
                    }
                }
            }
            register()
        }

    fun clearCache() {
        prefs().edit().remove(KEY_CREDENTIAL).apply()
    }

    // endregion

    // region persistence

    private fun cache(credential: SandboxCredential) {
        val json =
            JSONObject()
                .put("client_id", credential.clientId)
                .put("hmac_secret", credential.hmacSecret)
                .put("expires_at", DateTimeFormatter.ISO_INSTANT.format(credential.expiresAt))
                .toString()
        prefs().edit().putString(KEY_CREDENTIAL, json).apply()
    }

    private fun cachedCredential(): SandboxCredential? {
        val raw = prefs().getString(KEY_CREDENTIAL, null) ?: return null
        return try {
            val obj = JSONObject(raw)
            SandboxCredential(
                clientId = obj.getString("client_id"),
                hmacSecret = obj.getString("hmac_secret"),
                expiresAt = Instant.parse(obj.getString("expires_at")),
            )
        } catch (e: Exception) {
            Timber.w(e, "Failed to decode cached sandbox credential")
            null
        }
    }

    // endregion

    // region HTTP

    private fun fetchChallenge(): String {
        val url = baseUrl().trimEnd('/') + "/api/mobile/sandbox/challenge"
        val request = Request.Builder().url(url).get().build()
        httpClient().newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw SandboxGatewayException(response.code, body)
            val nonce = JSONObject(body).optString("nonce")
            if (nonce.isNullOrBlank()) throw IllegalStateException("Challenge response missing nonce")
            return nonce
        }
    }

    private fun postForCredential(
        path: String,
        body: Map<String, Any>,
        signingSecret: String?,
        clientId: String? = null,
    ): SandboxCredential {
        val responseBody = postRaw(path, body, signingSecret, clientId)
        val obj = JSONObject(responseBody)
        return SandboxCredential(
            clientId = obj.getString("client_id"),
            hmacSecret = obj.getString("hmac_secret"),
            expiresAt = Instant.parse(obj.getString("expires_at")),
        )
    }

    private fun postRaw(
        path: String,
        body: Map<String, Any>,
        signingSecret: String?,
        clientId: String? = null,
    ): String {
        val canonical = JsonCanonicaliser.canonicalise(body)
        val canonicalBytes = canonical.toByteArray(Charsets.UTF_8)
        require(canonicalBytes.size <= MAX_BODY_BYTES) {
            "Request body exceeds 16 KiB ceiling (${canonicalBytes.size} bytes)"
        }

        val builder =
            Request.Builder()
                .url(baseUrl().trimEnd('/') + path)
                .post(canonical.toRequestBody(jsonMedia))
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")

        // BLOCKER-3: Use the mwallet-sbx/v1 HMAC envelope matching the gateway.
        // Format: "mwallet-sbx/v1\n{method}\n{path}\n{timestamp}\n{nonce}\n{JCS body bytes}"
        // Headers: X-Mwallet-Auth (structured), X-Mwallet-Sig (hex HMAC tag).
        if (signingSecret != null && clientId != null) {
            val timestampSeconds = System.currentTimeMillis() / 1000
            val nonceHex = generateNonceHex()
            val header = "$HMAC_ENVELOPE_VERSION\nPOST\n$path\n$timestampSeconds\n$nonceHex\n"
            val signingBytes = header.toByteArray(Charsets.UTF_8) + canonicalBytes

            // MED-13: Zeroise the key copy after use via SensitiveDataHolder pattern.
            val keyBytes = signingSecret.toByteArray(Charsets.UTF_8)
            val signature: String
            try {
                val mac = Mac.getInstance("HmacSHA256")
                mac.init(SecretKeySpec(keyBytes, "HmacSHA256"))
                signature = mac.doFinal(signingBytes).joinToString("") { "%02x".format(it) }
            } finally {
                java.util.Arrays.fill(keyBytes, 0.toByte())
            }

            val authValue = "Mwallet-Sandbox client_id=$clientId,ts=$timestampSeconds,nonce=$nonceHex"
            builder.header("X-Mwallet-Auth", authValue)
            builder.header("X-Mwallet-Sig", signature)
        }

        httpClient().newCall(builder.build()).execute().use { response ->
            val respBody = response.body?.string().orEmpty()
            // HIGH-8: 409 or 403 may indicate absolute lifetime exhaustion.
            if (response.code == 409 || response.code == 403) {
                if ("lifetime" in respBody || "exhausted" in respBody) {
                    throw SandboxLifetimeExhaustedException()
                }
            }
            if (!response.isSuccessful) {
                throw SandboxGatewayException(response.code, respBody)
            }
            return respBody
        }
    }

    // endregion

    // region HMAC

    /**
     * HMAC-SHA256 hex via `javax.crypto.Mac` -- the platform primitive
     * for constant-time HMAC comparison on Android.
     * MED-13: Zeroises the key copy after use.
     */
    internal fun hmacSha256Hex(
        key: ByteArray,
        data: ByteArray,
    ): String {
        val keyBytes = key.copyOf()
        try {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(keyBytes, "HmacSHA256"))
            val signature = mac.doFinal(data)
            return signature.joinToString("") { "%02x".format(it) }
        } finally {
            java.util.Arrays.fill(keyBytes, 0.toByte())
        }
    }

    /**
     * Generate a 32-byte hex nonce (64 hex chars) for HMAC envelope replay
     * prevention. Uses SecureRandom.
     */
    internal fun generateNonceHex(): String {
        val bytes = ByteArray(32)
        secureRandom.nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    // endregion

    // region background refresh

    private fun scheduleRefresh(expiresAt: Instant) {
        val ctx = appContext ?: return
        val now = Instant.now()
        val delay = Duration.between(now, expiresAt.minus(Duration.ofHours(24)))
        val clamped = if (delay.isNegative) Duration.ZERO else delay
        val constraints =
            Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
        val request =
            OneTimeWorkRequestBuilder<SandboxRefreshWorker>()
                .setInitialDelay(clamped.toMillis(), TimeUnit.MILLISECONDS)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()
        WorkManager.getInstance(ctx)
            .enqueueUniqueWork(REFRESH_WORK_NAME, ExistingWorkPolicy.REPLACE, request)
    }

    private fun cancelScheduledRefresh() {
        val ctx = appContext ?: return
        WorkManager.getInstance(ctx).cancelUniqueWork(REFRESH_WORK_NAME)
    }

    // endregion

    // region UUID v7

    /**
     * Generates a UUID v7 per RFC 9562 draft: 48-bit unix-ms timestamp,
     * version 7 nibble, variant 10, 74 random bits.
     */
    internal fun generateUuidV7(random: SecureRandom = secureRandom): String {
        val bytes = ByteArray(16)
        random.nextBytes(bytes)
        val unixMs = System.currentTimeMillis()
        bytes[0] = ((unixMs ushr 40) and 0xff).toByte()
        bytes[1] = ((unixMs ushr 32) and 0xff).toByte()
        bytes[2] = ((unixMs ushr 24) and 0xff).toByte()
        bytes[3] = ((unixMs ushr 16) and 0xff).toByte()
        bytes[4] = ((unixMs ushr 8) and 0xff).toByte()
        bytes[5] = (unixMs and 0xff).toByte()
        bytes[6] = ((bytes[6].toInt() and 0x0f) or 0x70).toByte()
        bytes[8] = ((bytes[8].toInt() and 0x3f) or 0x80).toByte()
        val hex = bytes.joinToString("") { "%02x".format(it) }
        return buildString(36) {
            append(hex, 0, 8)
            append('-')
            append(hex, 8, 12)
            append('-')
            append(hex, 12, 16)
            append('-')
            append(hex, 16, 20)
            append('-')
            append(hex, 20, 32)
        }
    }

    // endregion

    private fun defaultAppVersion(): String =
        try {
            BuildConfig.VERSION_NAME
        } catch (_: Throwable) {
            "unknown"
        }

    // region base64url

    internal fun base64UrlEncode(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

    // endregion
}

/**
 * Abstraction over the Android Keystore attestation pathway so unit tests
 * can inject a deterministic fake chain without hitting a real TEE or
 * StrongBox.
 */
interface AttestationProvider {
    /**
     * Generates a fresh EC P-256 key pair under [alias] with the gateway
     * [challenge] as attestation challenge and returns each DER certificate
     * as a separate base64url-encoded string. BLOCKER-5: The gateway Zod
     * schema expects `z.array(z.string().min(16)).min(2)` and maps each
     * element individually.
     */
    fun generateAttestationChain(
        alias: String,
        challenge: ByteArray,
    ): List<String>
}

/**
 * Production [AttestationProvider] that drives AndroidKeyStore. Tries
 * StrongBox first, then retries without StrongBox on
 * `StrongBoxUnavailableException`. The fallback is still hardware-backed via
 * the TEE; the server rejects SOFTWARE attestation outright so a pure
 * software emulator will fail-loud at the gateway.
 */
object KeyStoreAttestationProvider : AttestationProvider {
    override fun generateAttestationChain(
        alias: String,
        challenge: ByteArray,
    ): List<String> {
        // Regenerate on every register so the attestation challenge always
        // carries the fresh nonce Sarah's verifier requires.
        runCatching {
            val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            if (ks.containsAlias(alias)) ks.deleteEntry(alias)
        }

        val generator =
            KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                "AndroidKeyStore",
            )

        fun baseBuilder(): KeyGenParameterSpec.Builder =
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setAttestationChallenge(challenge)

        try {
            generator.initialize(baseBuilder().setIsStrongBoxBacked(true).build())
            generator.generateKeyPair()
        } catch (_: StrongBoxUnavailableException) {
            // Fallback path: hardware-backed TEE without StrongBox. The
            // gateway still accepts TEE attestation; it only rejects
            // software-backed keys.
            Timber.w("StrongBox unavailable, falling back to TEE-only attestation")
            generator.initialize(baseBuilder().build())
            generator.generateKeyPair()
        }

        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val chain =
            ks.getCertificateChain(alias)
                ?: throw IllegalStateException("Attestation chain missing after key generation")
        // BLOCKER-5: Return each DER cert as a separate base64url string.
        // Gateway Zod expects z.array(z.string().min(16)).min(2) and later
        // does .map(b64 => base64ToBytes(b64)).
        return chain.map { cert -> SandboxCredentialFetcher.base64UrlEncode(cert.encoded) }
    }
}

/**
 * WorkManager worker that refreshes the sandbox credential 24 hours before
 * expiry. Scheduled by [SandboxCredentialFetcher.scheduleRefresh].
 */
class SandboxRefreshWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        SandboxCredentialFetcher.initialize(applicationContext)
        val outcome = SandboxCredentialFetcher.refresh()
        return if (outcome.isSuccess) Result.success() else Result.retry()
    }
}
