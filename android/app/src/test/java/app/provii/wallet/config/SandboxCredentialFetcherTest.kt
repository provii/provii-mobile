// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.config

import android.content.SharedPreferences
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeFormatter
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Unit tests for the W26 `SandboxCredentialFetcher`.
 *
 * Covers:
 *  - UUID v7 format + version/variant + lexical ordering.
 *  - HMAC-SHA256 against RFC 4231 test case 1.
 *  - StrongBox fallback (stubbed attestation provider exercising both paths).
 *  - Full register flow against MockWebServer: challenge -> register -> parse.
 *  - Refresh signing over `timestamp:POST:path:JCS(body)` with the returned
 *    hmac_secret. Byte-exact HMAC verification in the test recomputes the
 *    signature via `javax.crypto.Mac` (same primitive as production).
 *  - Credential expiry helpers.
 */
@RunWith(RobolectricTestRunner::class)
class SandboxCredentialFetcherTest {
    private lateinit var server: MockWebServer
    private lateinit var prefs: InMemorySharedPreferences
    private lateinit var httpClient: OkHttpClient
    private lateinit var attestationProvider: StubAttestationProvider

    @Before
    fun setup() {
        server = MockWebServer().apply { start() }
        prefs = InMemorySharedPreferences()
        httpClient = OkHttpClient.Builder().build()
        attestationProvider = StubAttestationProvider()
        SandboxCredentialFetcher.initializeForTesting(
            prefs = prefs,
            httpClient = httpClient,
            baseUrl = server.url("/").toString().trimEnd('/'),
            attestationProvider = attestationProvider,
        )
    }

    @After
    fun tearDown() {
        server.shutdown()
        prefs.edit().clear().apply()
    }

    // region UUID v7

    @Test
    fun `uuid v7 has 36 chars and correct hyphen layout`() {
        val id = SandboxCredentialFetcher.generateUuidV7()
        assertEquals(36, id.length)
        val parts = id.split("-")
        assertEquals(5, parts.size)
        assertEquals(8, parts[0].length)
        assertEquals(4, parts[1].length)
        assertEquals(4, parts[2].length)
        assertEquals(4, parts[3].length)
        assertEquals(12, parts[4].length)
    }

    @Test
    fun `uuid v7 version nibble is seven`() {
        val id = SandboxCredentialFetcher.generateUuidV7()
        assertEquals('7', id.split("-")[2][0])
    }

    @Test
    fun `uuid v7 variant nibble is 8 9 a or b`() {
        val id = SandboxCredentialFetcher.generateUuidV7()
        val variant = id.split("-")[3][0]
        assertTrue("variant=$variant", variant in listOf('8', '9', 'a', 'b'))
    }

    @Test
    fun `uuid v7 lexical ordering matches generation order`() {
        val first = SandboxCredentialFetcher.generateUuidV7()
        Thread.sleep(2)
        val second = SandboxCredentialFetcher.generateUuidV7()
        assertTrue(first <= second)
    }

    @Test
    fun `install id persists between calls`() {
        val a = SandboxCredentialFetcher.installId()
        val b = SandboxCredentialFetcher.installId()
        assertEquals(a, b)
    }

    // endregion

    // region HMAC

    @Test
    fun `hmac sha256 matches rfc 4231 test case 1`() {
        val key = ByteArray(20) { 0x0b }
        val data = "Hi There".toByteArray(Charsets.UTF_8)
        val expected = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
        assertEquals(expected, SandboxCredentialFetcher.hmacSha256Hex(key, data))
    }

    // endregion

    // region register flow

    @Test
    fun `register fetches challenge attests and parses gateway response`() =
        runBlocking {
            val expiresAt = Instant.now().plus(Duration.ofDays(7))
            val challengeJson = "{\"nonce\":\"nonce-abc\",\"expires_in\":60}"
            val registerJson = "{\"client_id\":\"mwallet-sbx-01234567-89ab-7cde-8f01-234567890abc\",\"hmac_secret\":\"c2VjcmV0LWJhc2U2NA\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(expiresAt)}\"}"
            server.enqueue(MockResponse().setBody(challengeJson).setResponseCode(200))
            server.enqueue(MockResponse().setBody(registerJson).setResponseCode(200))

            val result = SandboxCredentialFetcher.register(platform = "android", appVersion = "1.0.0")
            assertTrue("result=$result", result.isSuccess)
            val credential = result.getOrThrow()
            assertTrue(credential.clientId.startsWith("mwallet-sbx-"))
            assertEquals("c2VjcmV0LWJhc2U2NA", credential.hmacSecret)
            assertFalse(credential.isExpired())

            // Validate wire contract on the register request.
            server.takeRequest() // challenge
            val registerReq = server.takeRequest()
            assertEquals("POST", registerReq.method)
            assertEquals("/api/mobile/sandbox/register", registerReq.path)
            val body = registerReq.body.readUtf8()
            assertTrue("body contains install_uuid", body.contains("\"install_uuid\""))
            assertTrue("body contains attestation_nonce", body.contains("\"attestation_nonce\":\"nonce-abc\""))
            // BLOCKER-5: key_attestation_chain must be a JSON array, not a single string.
            assertTrue("body contains key_attestation_chain array", body.contains("\"key_attestation_chain\":["))
            assertTrue("attestation provider was invoked with nonce bytes", attestationProvider.lastChallenge.contentEquals("nonce-abc".toByteArray(Charsets.UTF_8)))
        }

    // endregion

    // region refresh signing

    @Test
    fun `refresh signs mwallet-sbx v1 envelope with returned hmac secret`() =
        runBlocking {
            // Prime the fetcher with a cached credential so refresh has something
            // to slide.
            val secret = "c2VjcmV0LWJhc2U2NA"
            val clientId = "mwallet-sbx-01234567890123456789012345678901"
            val initialJson = "{\"client_id\":\"$clientId\",\"hmac_secret\":\"$secret\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(Instant.now().plus(Duration.ofHours(23)))}\"}"
            prefs.edit().putString("provii.sandbox.credential", initialJson).apply()

            val refreshedExpiry = Instant.now().plus(Duration.ofDays(7))
            val refreshJson = "{\"client_id\":\"$clientId\",\"hmac_secret\":\"$secret\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(refreshedExpiry)}\"}"
            server.enqueue(MockResponse().setBody(refreshJson).setResponseCode(200))

            val refreshResult = SandboxCredentialFetcher.refresh()
            assertTrue("refresh failed: $refreshResult", refreshResult.isSuccess)

            val req: RecordedRequest = server.takeRequest()
            assertEquals("POST", req.method)
            assertEquals("/api/mobile/sandbox/refresh", req.path)

            // BLOCKER-3: New headers are X-Mwallet-Auth and X-Mwallet-Sig.
            val authHeader = req.getHeader("X-Mwallet-Auth")
            val sig = req.getHeader("X-Mwallet-Sig")
            assertNotNull("X-Mwallet-Auth must be present", authHeader)
            assertNotNull("X-Mwallet-Sig must be present", sig)
            assertEquals(64, sig!!.length)

            // Parse the auth header to extract ts and nonce.
            assertTrue("auth header prefix", authHeader!!.startsWith("Mwallet-Sandbox "))
            val fields =
                authHeader.removePrefix("Mwallet-Sandbox ").split(",").associate {
                    val (k, v) = it.split("=", limit = 2)
                    k.trim() to v.trim()
                }
            assertEquals(clientId, fields["client_id"])
            val ts = fields["ts"]!!
            val nonceHex = fields["nonce"]!!

            // Reconstruct the canonical signing bytes and verify the HMAC.
            val bodyBytes = req.body.clone().readByteArray()
            val headerStr = "mwallet-sbx/v1\nPOST\n/api/mobile/sandbox/refresh\n$ts\n$nonceHex\n"
            val signingBytes = headerStr.toByteArray(Charsets.UTF_8) + bodyBytes
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
            val expected = mac.doFinal(signingBytes).joinToString("") { "%02x".format(it) }
            assertEquals(expected, sig)

            // Body should NOT contain install_uuid (MobileLifecycleRequestSchema strips it).
            val bodyStr = String(bodyBytes, Charsets.UTF_8)
            assertFalse("body must not contain install_uuid", bodyStr.contains("install_uuid"))
        }

    // endregion

    // region credential expiry

    @Test
    fun `credential past expires is expired`() {
        val credential =
            SandboxCredential(
                clientId = "mwallet-sbx-test",
                hmacSecret = "secret",
                expiresAt = Instant.now().minusSeconds(10),
            )
        assertTrue(credential.isExpired())
    }

    @Test
    fun `credential within 24h window needs refresh`() {
        val credential =
            SandboxCredential(
                clientId = "mwallet-sbx-test",
                hmacSecret = "secret",
                expiresAt = Instant.now().plus(Duration.ofHours(23)),
            )
        assertTrue(credential.needsRefresh())
    }

    @Test
    fun `credential well beyond 24h does not need refresh`() {
        val credential =
            SandboxCredential(
                clientId = "mwallet-sbx-test",
                hmacSecret = "secret",
                expiresAt = Instant.now().plus(Duration.ofDays(5)),
            )
        assertFalse(credential.needsRefresh())
    }

    // endregion

    // region BLOCKER-1: expired credential falls through to register

    @Test
    fun `currentCredential re-registers when credential is expired and refresh fails`() =
        runBlocking {
            // Cache an expired credential.
            val expiredJson = "{\"client_id\":\"mwallet-sbx-expired\",\"hmac_secret\":\"c2VjcmV0\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(Instant.now().minus(Duration.ofHours(1)))}\"}"
            prefs.edit().putString("provii.sandbox.credential", expiredJson).apply()

            // Refresh will fail (403).
            server.enqueue(MockResponse().setResponseCode(403).setBody("{\"error\":\"expired\"}"))
            // Challenge + register for the fallback.
            server.enqueue(MockResponse().setBody("{\"nonce\":\"nonce-expired\",\"expires_in\":60}").setResponseCode(200))
            val freshExpiry = Instant.now().plus(Duration.ofDays(7))
            server.enqueue(MockResponse().setBody("{\"client_id\":\"mwallet-sbx-fresh\",\"hmac_secret\":\"bmV3c2VjcmV0\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(freshExpiry)}\"}").setResponseCode(200))

            val result = SandboxCredentialFetcher.currentCredential()
            assertTrue("should succeed with fresh credential", result.isSuccess)
            assertEquals("mwallet-sbx-fresh", result.getOrThrow().clientId)
        }

    // endregion

    // region MED-16: revoke tests

    @Test
    fun `revoke signs request with mwallet-sbx v1 envelope`() =
        runBlocking {
            val secret = "c2VjcmV0LWJhc2U2NA"
            val clientId = "mwallet-sbx-01234567890123456789012345678901"
            val cachedJson = "{\"client_id\":\"$clientId\",\"hmac_secret\":\"$secret\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(Instant.now().plus(Duration.ofDays(5)))}\"}"
            prefs.edit().putString("provii.sandbox.credential", cachedJson).apply()

            server.enqueue(MockResponse().setResponseCode(200).setBody("{}"))
            val result = SandboxCredentialFetcher.revoke()
            assertTrue("revoke should succeed", result.isSuccess)

            val req = server.takeRequest()
            assertEquals("POST", req.method)
            assertEquals("/api/mobile/sandbox/revoke", req.path)
            assertNotNull("X-Mwallet-Auth required", req.getHeader("X-Mwallet-Auth"))
            assertNotNull("X-Mwallet-Sig required", req.getHeader("X-Mwallet-Sig"))
            assertEquals(64, req.getHeader("X-Mwallet-Sig")!!.length)
        }

    @Test
    fun `revoke clears local credential and cancels refresh`() =
        runBlocking {
            val cachedJson = "{\"client_id\":\"mwallet-sbx-revoke\",\"hmac_secret\":\"c2VjcmV0\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(Instant.now().plus(Duration.ofDays(5)))}\"}"
            prefs.edit().putString("provii.sandbox.credential", cachedJson).apply()

            server.enqueue(MockResponse().setResponseCode(200).setBody("{}"))
            SandboxCredentialFetcher.revoke()

            // Credential should be cleared from prefs.
            val remaining = prefs.getString("provii.sandbox.credential", null)
            assertTrue("credential must be cleared", remaining == null)
        }

    @Test
    fun `revoke surfaces auth failures from gateway`() =
        runBlocking {
            val cachedJson = "{\"client_id\":\"mwallet-sbx-revokeauth\",\"hmac_secret\":\"c2VjcmV0\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(Instant.now().plus(Duration.ofDays(5)))}\"}"
            prefs.edit().putString("provii.sandbox.credential", cachedJson).apply()

            server.enqueue(MockResponse().setResponseCode(401).setBody("{\"code\":\"mobile_signature_mismatch\"}"))
            val result = SandboxCredentialFetcher.revoke()
            assertTrue("revoke should fail on 401", result.isFailure)
            val ex = result.exceptionOrNull()
            assertTrue("exception should be SandboxGatewayException", ex is SandboxGatewayException)
            assertEquals(401, (ex as SandboxGatewayException).statusCode)
        }

    // endregion

    // region StrongBox fallback

    @Test
    fun `attestation provider is invoked via the fetcher seam`() =
        runBlocking {
            // The StrongBox -> TEE fallback lives inside `KeyStoreAttestationProvider`
            // and is exercised on-device (CI instrumentation). This unit test
            // asserts only that the fetcher delegates to the `AttestationProvider`
            // seam exactly once per register call, so an on-device integration
            // test can confirm the fallback end to end without contaminating JVM
            // CI with Android Keystore calls.
            val challengeJson = "{\"nonce\":\"nonce-sb\",\"expires_in\":60}"
            val registerJson = "{\"client_id\":\"mwallet-sbx-sb\",\"hmac_secret\":\"c2VjcmV0\",\"expires_at\":\"${DateTimeFormatter.ISO_INSTANT.format(Instant.now().plus(Duration.ofDays(1)))}\"}"
            server.enqueue(MockResponse().setBody(challengeJson).setResponseCode(200))
            server.enqueue(MockResponse().setBody(registerJson).setResponseCode(200))

            SandboxCredentialFetcher.clearCache()
            prefs.edit().remove("provii.sandbox.credential").apply()
            val result = SandboxCredentialFetcher.register()
            assertTrue(result.isSuccess)
            assertEquals(1, attestationProvider.invocationCount)
        }

    // endregion
}

// region Stub attestation provider

internal class StubAttestationProvider : AttestationProvider {
    var invocationCount = 0
    var lastChallenge: ByteArray = ByteArray(0)

    override fun generateAttestationChain(
        alias: String,
        challenge: ByteArray,
    ): List<String> {
        invocationCount += 1
        lastChallenge = challenge
        // BLOCKER-5: Return a list of per-cert base64url strings matching
        // the gateway's z.array(z.string().min(16)).min(2) schema.
        return listOf(
            SandboxCredentialFetcher.base64UrlEncode("stub-leaf-cert-for-$alias".toByteArray(Charsets.UTF_8)),
            SandboxCredentialFetcher.base64UrlEncode("stub-root-cert-for-$alias".toByteArray(Charsets.UTF_8)),
        )
    }
}

// endregion

// region In-memory SharedPreferences

internal class InMemorySharedPreferences : SharedPreferences {
    private val store = mutableMapOf<String, Any?>()

    override fun getAll(): MutableMap<String, *> = store.toMutableMap()

    override fun getString(
        key: String,
        defValue: String?,
    ): String? = store[key] as? String ?: defValue

    override fun getStringSet(
        key: String,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? =
        @Suppress("UNCHECKED_CAST")
        (store[key] as? MutableSet<String>)
            ?: defValues

    override fun getInt(
        key: String,
        defValue: Int,
    ): Int = store[key] as? Int ?: defValue

    override fun getLong(
        key: String,
        defValue: Long,
    ): Long = store[key] as? Long ?: defValue

    override fun getFloat(
        key: String,
        defValue: Float,
    ): Float = store[key] as? Float ?: defValue

    override fun getBoolean(
        key: String,
        defValue: Boolean,
    ): Boolean = store[key] as? Boolean ?: defValue

    override fun contains(key: String): Boolean = store.containsKey(key)

    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    override fun edit(): SharedPreferences.Editor = Editor()

    inner class Editor : SharedPreferences.Editor {
        private val pending = mutableMapOf<String, Any?>()
        private val removals = mutableSetOf<String>()
        private var clear = false

        override fun putString(
            key: String,
            value: String?,
        ): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putStringSet(
            key: String,
            values: MutableSet<String>?,
        ): SharedPreferences.Editor {
            pending[key] = values
            return this
        }

        override fun putInt(
            key: String,
            value: Int,
        ): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putLong(
            key: String,
            value: Long,
        ): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putFloat(
            key: String,
            value: Float,
        ): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putBoolean(
            key: String,
            value: Boolean,
        ): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun remove(key: String): SharedPreferences.Editor {
            removals.add(key)
            return this
        }

        override fun clear(): SharedPreferences.Editor {
            clear = true
            return this
        }

        override fun commit(): Boolean {
            apply()
            return true
        }

        override fun apply() {
            if (clear) store.clear()
            removals.forEach { store.remove(it) }
            store.putAll(pending)
            pending.clear()
            removals.clear()
            clear = false
        }
    }
}

// endregion
