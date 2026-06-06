// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.network

import com.google.gson.Gson
import com.google.gson.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Golden vector tests for HmacSigner. Each test loads expected output from
 * shared/test-vectors/hmac_signer_vectors.json and asserts byte-exact
 * agreement. Any divergence from these vectors means the HMAC will not
 * match the provii-issuer and authentication will fail.
 *
 * The same vectors are consumed by the iOS HmacSignerTests, guaranteeing
 * cross-platform parity.
 */
class HmacSignerTest {
    private val vectors: JsonObject by lazy {
        val stream =
            javaClass.classLoader!!.getResourceAsStream("hmac_signer_vectors.json")
                ?: throw IllegalStateException("hmac_signer_vectors.json not found on classpath")
        Gson().fromJson(stream.bufferedReader(), JsonObject::class.java)
    }

    private val secret: ByteArray by lazy {
        val hex = vectors.get("secret_hex").asString
        hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }

    // =========================================================================
    // hmacSha256Hex
    // =========================================================================

    @Test
    fun `hmacSha256Hex matches golden vectors`() {
        val cases = vectors.getAsJsonArray("hmac_sha256_hex")
        for (element in cases) {
            val obj = element.asJsonObject
            val id = obj.get("id").asString
            val data = obj.get("data").asString
            val expected = obj.get("expected").asString

            val actual = HmacSigner.hmacSha256Hex(secret, data)
            assertEquals("hmacSha256Hex vector '$id' mismatch", expected, actual)
        }
    }

    // =========================================================================
    // canonicalStartJson
    // =========================================================================

    @Test
    fun `canonicalStartJson matches golden vectors`() {
        val cases = vectors.getAsJsonArray("canonicalStartJson")
        for (element in cases) {
            val obj = element.asJsonObject
            val id = obj.get("id").asString
            val actor = obj.get("actor").asString
            val format = obj.get("format").asString
            val keyId = obj.get("keyId").asString
            val ts = obj.get("ts").asLong
            val schema = if (obj.get("schema").isJsonNull) null else obj.get("schema").asString
            val validityDays = if (obj.get("validityDays").isJsonNull) null else obj.get("validityDays").asInt
            val kid = if (obj.get("kid").isJsonNull) null else obj.get("kid").asString
            val expected = obj.get("expected").asString

            val actual =
                HmacSigner.canonicalStartJson(
                    actor = actor,
                    format = format,
                    keyId = keyId,
                    ts = ts,
                    schema = schema,
                    validityDays = validityDays,
                    kid = kid,
                )
            assertEquals("canonicalStartJson vector '$id' mismatch", expected, actual)
        }
    }

    // =========================================================================
    // canonicalSignJson
    // =========================================================================

    @Test
    fun `canonicalSignJson matches golden vectors`() {
        val cases = vectors.getAsJsonArray("canonicalSignJson")
        for (element in cases) {
            val obj = element.asJsonObject
            val id = obj.get("id").asString
            val sessionId = obj.get("sessionId").asString
            val commitmentB64 = obj.get("commitmentB64").asString
            val format = obj.get("format").asString
            val keyId = obj.get("keyId").asString
            val ts = obj.get("ts").asLong
            val expected = obj.get("expected").asString

            val actual =
                HmacSigner.canonicalSignJson(
                    sessionId = sessionId,
                    commitmentB64 = commitmentB64,
                    format = format,
                    keyId = keyId,
                    ts = ts,
                )
            assertEquals("canonicalSignJson vector '$id' mismatch", expected, actual)
        }
    }

    // =========================================================================
    // canonicalAttestationJson
    // =========================================================================

    @Test
    fun `canonicalAttestationJson matches golden vectors`() {
        val cases = vectors.getAsJsonArray("canonicalAttestationJson")
        for (element in cases) {
            val obj = element.asJsonObject
            val id = obj.get("id").asString
            val dobDays = obj.get("dobDays").asInt
            val format = obj.get("format").asString
            val keyId = obj.get("keyId").asString
            val ts = obj.get("ts").asLong
            val expected = obj.get("expected").asString

            val actual =
                HmacSigner.canonicalAttestationJson(
                    dobDays = dobDays,
                    format = format,
                    keyId = keyId,
                    ts = ts,
                )
            assertEquals("canonicalAttestationJson vector '$id' mismatch", expected, actual)
        }
    }

    // =========================================================================
    // canonicalMessage
    // =========================================================================

    @Test
    fun `canonicalMessage matches golden vectors`() {
        val cases = vectors.getAsJsonArray("canonicalMessage")
        for (element in cases) {
            val obj = element.asJsonObject
            val id = obj.get("id").asString
            val ts = obj.get("ts").asLong
            val method = obj.get("method").asString
            val path = obj.get("path").asString
            val jsonWithoutHmac = obj.get("jsonWithoutHmac").asString
            val nonce = obj.get("nonce").asString
            val expected = obj.get("expected").asString

            val actual =
                HmacSigner.canonicalMessage(
                    ts = ts,
                    method = method,
                    path = path,
                    jsonWithoutHmac = jsonWithoutHmac,
                    nonce = nonce,
                )
            assertEquals("canonicalMessage vector '$id' mismatch", expected, actual)
        }
    }

    // =========================================================================
    // buildAuthorizerJson
    // =========================================================================

    @Test
    fun `buildAuthorizerJson matches golden vectors`() {
        val cases = vectors.getAsJsonArray("buildAuthorizerJson")
        for (element in cases) {
            val obj = element.asJsonObject
            val id = obj.get("id").asString
            val format = obj.get("format").asString
            val keyId = obj.get("keyId").asString
            val timestamp = obj.get("timestamp").asLong
            val hmac = obj.get("hmac").asString
            val nonce = obj.get("nonce").asString
            val expected = obj.get("expected").asString

            val actual =
                HmacSigner.buildAuthorizerJson(
                    format = format,
                    keyId = keyId,
                    timestamp = timestamp,
                    hmac = hmac,
                    nonce = nonce,
                )
            assertEquals("buildAuthorizerJson vector '$id' mismatch", expected, actual)
        }
    }

    // =========================================================================
    // End-to-end (full flow)
    // =========================================================================

    @Test
    fun `end to end attestation flow matches golden vector`() {
        val e2e = vectors.getAsJsonArray("endToEnd")
        val attest = e2e.first { it.asJsonObject.get("id").asString == "attestation_full_flow" }.asJsonObject
        val params = attest.getAsJsonObject("params")

        val canonJson =
            HmacSigner.canonicalAttestationJson(
                dobDays = params.get("dobDays").asInt,
                format = params.get("format").asString,
                keyId = params.get("keyId").asString,
                ts = attest.get("ts").asLong,
            )
        assertEquals(attest.get("expectedCanonicalJson").asString, canonJson)

        val canonMsg =
            HmacSigner.canonicalMessage(
                ts = attest.get("ts").asLong,
                method = attest.get("method").asString,
                path = attest.get("endpoint").asString,
                jsonWithoutHmac = canonJson,
                nonce = attest.get("nonce").asString,
            )
        assertEquals(attest.get("expectedCanonicalMessage").asString, canonMsg)

        val hmac = HmacSigner.hmacSha256Hex(secret, canonMsg)
        assertEquals(attest.get("expectedHmac").asString, hmac)

        val authJson =
            HmacSigner.buildAuthorizerJson(
                format = params.get("format").asString,
                keyId = params.get("keyId").asString,
                timestamp = attest.get("ts").asLong,
                hmac = hmac,
                nonce = attest.get("nonce").asString,
            )
        assertEquals(attest.get("expectedAuthorizerJson").asString, authJson)
    }

    @Test
    fun `end to end issuance start flow matches golden vector`() {
        val e2e = vectors.getAsJsonArray("endToEnd")
        val start = e2e.first { it.asJsonObject.get("id").asString == "issuance_start_full_flow" }.asJsonObject
        val params = start.getAsJsonObject("params")

        val canonJson =
            HmacSigner.canonicalStartJson(
                actor = params.get("actor").asString,
                format = params.get("format").asString,
                keyId = params.get("keyId").asString,
                ts = start.get("ts").asLong,
                schema = if (params.has("schema") && !params.get("schema").isJsonNull) params.get("schema").asString else null,
                validityDays = if (params.has("validityDays") && !params.get("validityDays").isJsonNull) params.get("validityDays").asInt else null,
                kid = if (params.has("kid") && !params.get("kid").isJsonNull) params.get("kid").asString else null,
            )
        assertEquals(start.get("expectedCanonicalJson").asString, canonJson)

        val canonMsg =
            HmacSigner.canonicalMessage(
                ts = start.get("ts").asLong,
                method = start.get("method").asString,
                path = start.get("endpoint").asString,
                jsonWithoutHmac = canonJson,
                nonce = start.get("nonce").asString,
            )
        assertEquals(start.get("expectedCanonicalMessage").asString, canonMsg)

        val hmac = HmacSigner.hmacSha256Hex(secret, canonMsg)
        assertEquals(start.get("expectedHmac").asString, hmac)

        val authJson =
            HmacSigner.buildAuthorizerJson(
                format = params.get("format").asString,
                keyId = params.get("keyId").asString,
                timestamp = start.get("ts").asLong,
                hmac = hmac,
                nonce = start.get("nonce").asString,
            )
        assertEquals(start.get("expectedAuthorizerJson").asString, authJson)
    }

    // =========================================================================
    // Nonce generation sanity checks
    // =========================================================================

    @Test
    fun `generateNonce returns 64 hex chars`() {
        val nonce = HmacSigner.generateNonce()
        assertEquals("Nonce must be 64 hex characters", 64, nonce.length)
        assertTrue("Nonce must be lowercase hex", nonce.matches(Regex("[0-9a-f]{64}")))
    }

    @Test
    fun `generateNonce returns unique values`() {
        val nonces = (1..100).map { HmacSigner.generateNonce() }.toSet()
        assertEquals("100 nonces should all be unique", 100, nonces.size)
    }
}
