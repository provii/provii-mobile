// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for [HmacSigner] canonical JSON construction and HMAC signing.
 */
class HmacSignerCanonicalTest {
    @Test
    fun `canonicalMessage produces correct format`() {
        val msg = HmacSigner.canonicalMessage(
            ts = 1700000000L,
            method = "POST",
            path = "/v1/issuance/start",
            jsonWithoutHmac = """{"key":"value"}""",
            nonce = "abc123",
        )
        assertEquals("""1700000000:POST:/v1/issuance/start:{"key":"value"}:abc123""", msg)
    }

    @Test
    fun `canonicalMessage uppercases method`() {
        val msg = HmacSigner.canonicalMessage(
            ts = 1L,
            method = "post",
            path = "/test",
            jsonWithoutHmac = "{}",
            nonce = "n",
        )
        assertTrue(msg.startsWith("1:POST:"))
    }

    @Test
    fun `canonicalStartJson preserves field order with snake_case key_id`() {
        val json = HmacSigner.canonicalStartJson(
            actor = "holder",
            format = "client",
            keyId = "pk_test123",
            ts = 1700000000L,
            schema = "provii.age/1",
            validityDays = 365,
            kid = "kid-1",
        )
        assertTrue(json.contains(""""actor":"holder""""))
        assertTrue(json.contains(""""key_id":"pk_test123""""))
        assertTrue(json.contains(""""schema":"provii.age/1""""))
        assertTrue(json.contains(""""validity_days":365"""))
        assertTrue(json.contains(""""kid":"kid-1""""))
    }

    @Test
    fun `canonicalStartJson renders null for optional fields`() {
        val json = HmacSigner.canonicalStartJson(
            actor = "holder",
            format = "client",
            keyId = "pk_test",
            ts = 1L,
            schema = null,
            validityDays = null,
            kid = null,
        )
        assertTrue(json.contains(""""schema":null"""))
        assertTrue(json.contains(""""validity_days":null"""))
        assertTrue(json.contains(""""kid":null"""))
    }

    @Test
    fun `canonicalSignJson preserves field order`() {
        val json = HmacSigner.canonicalSignJson(
            sessionId = "sess-1",
            commitmentB64 = "Y29tbWl0bWVudA",
            format = "client",
            keyId = "pk_test",
            ts = 1700000000L,
        )
        assertTrue(json.contains(""""session_id":"sess-1""""))
        assertTrue(json.contains(""""commitment":"Y29tbWl0bWVudA""""))
        assertTrue(json.contains(""""key_id":"pk_test""""))
    }

    @Test
    fun `canonicalAttestationJson produces correct output`() {
        val json = HmacSigner.canonicalAttestationJson(
            dobDays = 7300,
            format = "client",
            keyId = "pk_abc",
            ts = 1700000000L,
        )
        assertTrue(json.contains(""""dob_days":7300"""))
        assertTrue(json.contains(""""key_id":"pk_abc""""))
    }

    @Test
    fun `generateNonce returns 64 hex characters`() {
        val nonce = HmacSigner.generateNonce()
        assertEquals(64, nonce.length)
        assertTrue(nonce.matches(Regex("^[0-9a-f]{64}$")))
    }

    @Test
    fun `generateNonce produces unique values`() {
        val nonces = (1..10).map { HmacSigner.generateNonce() }.toSet()
        assertEquals(10, nonces.size)
    }

    @Test
    fun `hmacSha256Hex produces deterministic output`() {
        val secret = "test-secret".toByteArray()
        val data = "test-data"
        val h1 = HmacSigner.hmacSha256Hex(secret, data)
        val h2 = HmacSigner.hmacSha256Hex(secret, data)
        assertEquals(h1, h2)
        assertEquals(64, h1.length) // SHA-256 = 32 bytes = 64 hex chars
    }

    @Test
    fun `hmacSha256Hex produces different output for different data`() {
        val secret = "test-secret".toByteArray()
        val h1 = HmacSigner.hmacSha256Hex(secret, "data-a")
        val h2 = HmacSigner.hmacSha256Hex(secret, "data-b")
        assertNotEquals(h1, h2)
    }

    @Test
    fun `buildAuthorizerJson escapes special characters`() {
        val json = HmacSigner.buildAuthorizerJson(
            format = "client",
            keyId = "pk_test",
            timestamp = 1700000000L,
            hmac = "abc123",
            nonce = "def456",
        )
        assertTrue(json.contains(""""format":"client""""))
        assertTrue(json.contains(""""keyId":"pk_test""""))
        assertTrue(json.contains(""""timestamp":1700000000"""))
        assertTrue(json.contains(""""hmac":"abc123""""))
        assertTrue(json.contains(""""nonce":"def456""""))
    }

    @Test
    fun `createAttestationAuthorizer returns valid authorizer and timestamp`() {
        val secret = "test-secret-32bytes-padding12345".toByteArray()
        val (authorizer, ts) = HmacSigner.createAttestationAuthorizer(
            secret = secret,
            dobDays = 7300,
            format = "client",
            keyId = "pk_abc",
        )
        assertTrue(ts > 0)
        assertTrue(authorizer.contains(""""format":"client""""))
        assertTrue(authorizer.contains(""""keyId":"pk_abc""""))
        assertTrue(authorizer.contains("hmac"))
        assertTrue(authorizer.contains("nonce"))
    }

    @Test
    fun `createStartAuthorizer returns valid authorizer and timestamp`() {
        val secret = "test-secret-32bytes-padding12345".toByteArray()
        val (authorizer, ts) = HmacSigner.createStartAuthorizer(
            secret = secret,
            actor = "holder",
            format = "client",
            keyId = "pk_test",
            schema = "provii.age/1",
            validityDays = 365,
            kid = null,
        )
        assertTrue(ts > 0)
        assertTrue(authorizer.contains("hmac"))
        assertTrue(authorizer.contains("nonce"))
    }

    @Test
    fun `createSignAuthorizer returns valid authorizer and timestamp`() {
        val secret = "test-secret-32bytes-padding12345".toByteArray()
        val (authorizer, ts) = HmacSigner.createSignAuthorizer(
            secret = secret,
            sessionId = "sess-1",
            commitmentB64 = "Y29tbWl0bWVudA",
            format = "client",
            keyId = "pk_test",
        )
        assertTrue(ts > 0)
        assertTrue(authorizer.contains("hmac"))
    }
}
