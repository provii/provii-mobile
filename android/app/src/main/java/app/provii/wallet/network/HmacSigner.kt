// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.network

import timber.log.Timber
import java.nio.charset.StandardCharsets
import java.util.Arrays
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Constructs and signs HMAC-SHA256 authenticated requests for the issuer API. Builds
 * canonical JSON payloads with deterministic field ordering for the issuance start,
 * sign-commitment, and attestation creation endpoints. Each request includes a 256-bit
 * nonce for replay prevention and a hex-encoded HMAC tag computed over the canonical
 * message format "{timestamp}:{METHOD}:{PATH}:{json}:{nonce}".
 */
object HmacSigner {
    private val secureRandom = java.security.SecureRandom()

    /**
     * Convert bytes to hex string
     */
    private fun hex(bytes: ByteArray): String =
        bytes.joinToString("") { "%02x".format(it) }

    /**
     * Generate HMAC-SHA256 and return as hex string.
     * Copies the secret into a local array that is zeroised after use.
     */
    fun hmacSha256Hex(
        secret: ByteArray,
        data: String,
    ): String {
        val keyBytes = secret.copyOf()
        try {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(keyBytes, "HmacSHA256"))
            return hex(mac.doFinal(data.toByteArray(StandardCharsets.UTF_8)))
        } finally {
            Arrays.fill(keyBytes, 0.toByte())
        }
    }

    // Canonical HMAC format: {ts}:{METHOD}:{path}:{json}:{nonce}
    // Source of truth: provii-issuer/src/session.rs::create_canonical_message_for_attestation
    // All implementations (Rust, Swift, Kotlin) must produce byte-identical output.

    /**
     * Build canonical message for HMAC signing
     * Format: "{timestamp}:{METHOD}:{PATH}:{jsonWithoutHmac}:{nonce}"
     */
    fun canonicalMessage(
        ts: Long,
        method: String,
        path: String,
        jsonWithoutHmac: String,
        nonce: String,
    ): String {
        val msg = "$ts:${method.uppercase()}:$path:$jsonWithoutHmac:$nonce"
        Timber.d("Canonical message length: %d, path: %s", msg.length, path)
        return msg
    }

    /**
     * Build canonical JSON for /v1/issuance/start
     * CRITICAL: Must use exact field order and "key_id" (snake_case)
     */
    fun canonicalStartJson(
        actor: String,
        format: String,
        keyId: String,
        ts: Long,
        schema: String?,
        validityDays: Int?,
        kid: String?,
    ): String {
        // Helper to escape and quote strings
        fun jstr(s: String) = "\"" + jsonEscape(s) + "\""

        fun joptStr(v: String?) = if (v == null) "null" else jstr(v)

        fun joptNum(v: Int?) = v?.toString() ?: "null"

        // IMPORTANT: "key_id" not "keyId" in the canonical form
        val json = """{"actor":${jstr(actor)},"authorizer":{"format":${jstr(format)},"key_id":${jstr(keyId)},"timestamp":$ts},"schema":${joptStr(schema)},"validity_days":${joptNum(validityDays)},"kid":${joptStr(kid)}}"""

        Timber.d("Canonical start JSON length: %d", json.length)
        return json
    }

    /**
     * Build canonical JSON for /v1/issuance/sign-commitment
     * CRITICAL: Must use exact field order and "key_id" (snake_case)
     */
    fun canonicalSignJson(
        sessionId: String,
        commitmentB64: String,
        format: String,
        keyId: String,
        ts: Long,
    ): String {
        fun jstr(s: String) = "\"" + jsonEscape(s) + "\""

        // IMPORTANT: "key_id" not "keyId" in the canonical form
        val json = """{"session_id":${jstr(sessionId)},"commitment":${jstr(commitmentB64)},"authorizer":{"format":${jstr(format)},"key_id":${jstr(keyId)},"timestamp":$ts}}"""

        Timber.d("Canonical sign JSON length: %d", json.length)
        return json
    }

    /**
     * Generate a 64 hex character nonce (256 bits) for replay prevention
     */
    fun generateNonce(): String {
        val bytes = ByteArray(32)
        secureRandom.nextBytes(bytes)
        return hex(bytes)
    }

    /**
     * RFC 8259 compliant JSON string escaping.
     * Escapes backslash, double quote, named control characters (BS, HT, LF, FF, CR),
     * and remaining U+0000-U+001F as \u00xx (lowercase hex).
     * Forward slash is NOT escaped.
     */
    private fun jsonEscape(s: String): String {
        val sb = StringBuilder(s.length)
        for (ch in s) {
            when (ch) {
                '\\' -> sb.append("\\\\")
                '"' -> sb.append("\\\"")
                '\b' -> sb.append("\\b")
                '\t' -> sb.append("\\t")
                '\n' -> sb.append("\\n")
                '\u000C' -> sb.append("\\f")
                '\r' -> sb.append("\\r")
                else -> {
                    if (ch.code in 0x00..0x1F) {
                        sb.append("\\u%04x".format(ch.code))
                    } else {
                        sb.append(ch)
                    }
                }
            }
        }
        return sb.toString()
    }

    /**
     * Build the actual authoriser JSON object for the request.
     * This uses "keyId" (camelCase) for the actual API request.
     *
     * SECURITY (INV-WM-012): All string parameters are escaped via jsonEscape() to
     * prevent JSON injection through crafted format, keyId, hmac, or nonce values.
     */
    fun buildAuthorizerJson(
        format: String,
        keyId: String,
        timestamp: Long,
        hmac: String,
        nonce: String,
    ): String {
        // The actual request uses camelCase "keyId" (not snake_case)
        return """{"format":"${jsonEscape(format)}","keyId":"${jsonEscape(keyId)}","timestamp":$timestamp,"hmac":"${jsonEscape(hmac)}","nonce":"${jsonEscape(nonce)}"}"""
    }

    /**
     * Create the authoriser payload for /v1/issuance/start.
     */
    fun createStartAuthorizer(
        secret: ByteArray,
        actor: String,
        format: String,
        keyId: String,
        schema: String? = null,
        validityDays: Int? = null,
        kid: String? = null,
    ): Pair<String, Long> {
        val timestamp = System.currentTimeMillis() / 1000L
        val nonce = generateNonce()
        val canonicalJson =
            canonicalStartJson(
                actor = actor,
                format = format,
                keyId = keyId,
                ts = timestamp,
                schema = schema,
                validityDays = validityDays,
                kid = kid,
            )
        val canonicalMsg =
            canonicalMessage(
                ts = timestamp,
                method = "POST",
                path = "/v1/issuance/start",
                jsonWithoutHmac = canonicalJson,
                nonce = nonce,
            )
        val hmac = hmacSha256Hex(secret, canonicalMsg)
        val authorizer =
            buildAuthorizerJson(
                format = format,
                keyId = keyId,
                timestamp = timestamp,
                hmac = hmac,
                nonce = nonce,
            )
        return authorizer to timestamp
    }

    /**
     * Create the authoriser payload for /v1/issuance/sign-commitment.
     */
    fun createSignAuthorizer(
        secret: ByteArray,
        sessionId: String,
        commitmentB64: String,
        format: String,
        keyId: String,
    ): Pair<String, Long> {
        val timestamp = System.currentTimeMillis() / 1000L
        val nonce = generateNonce()
        val canonicalJson =
            canonicalSignJson(
                sessionId = sessionId,
                commitmentB64 = commitmentB64,
                format = format,
                keyId = keyId,
                ts = timestamp,
            )
        val canonicalMsg =
            canonicalMessage(
                ts = timestamp,
                method = "POST",
                path = "/v1/issuance/blind",
                jsonWithoutHmac = canonicalJson,
                nonce = nonce,
            )
        val hmac = hmacSha256Hex(secret, canonicalMsg)
        val authorizer =
            buildAuthorizerJson(
                format = format,
                keyId = keyId,
                timestamp = timestamp,
                hmac = hmac,
                nonce = nonce,
            )
        return authorizer to timestamp
    }

    /**
     * Build canonical JSON for /v1/attestation/create
     * CRITICAL: Must use exact field order and "key_id" (snake_case)
     */
    fun canonicalAttestationJson(
        dobDays: Int,
        format: String,
        keyId: String,
        ts: Long,
    ): String {
        fun jstr(s: String) = "\"" + jsonEscape(s) + "\""

        // IMPORTANT: "key_id" not "keyId" in the canonical form
        val json = """{"dob_days":$dobDays,"authorizer":{"format":${jstr(format)},"key_id":${jstr(keyId)},"timestamp":$ts}}"""

        Timber.d("Canonical attestation JSON length: %d", json.length)
        return json
    }

    /**
     * Create the authoriser payload for /v1/attestation/create.
     */
    fun createAttestationAuthorizer(
        secret: ByteArray,
        dobDays: Int,
        format: String,
        keyId: String,
    ): Pair<String, Long> {
        val timestamp = System.currentTimeMillis() / 1000L
        val nonce = generateNonce()
        val canonicalJson =
            canonicalAttestationJson(
                dobDays = dobDays,
                format = format,
                keyId = keyId,
                ts = timestamp,
            )
        val canonicalMsg =
            canonicalMessage(
                ts = timestamp,
                method = "POST",
                path = "/v1/attestation/create",
                jsonWithoutHmac = canonicalJson,
                nonce = nonce,
            )
        val hmac = hmacSha256Hex(secret, canonicalMsg)
        val authorizer =
            buildAuthorizerJson(
                format = format,
                keyId = keyId,
                timestamp = timestamp,
                hmac = hmac,
                nonce = nonce,
            )
        return authorizer to timestamp
    }
}
