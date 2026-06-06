// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.deeplink

import android.content.SharedPreferences
import android.net.Uri
import android.util.Base64
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.navigation.NavigationPayloadStore
import app.provii.wallet.security.AuditLogger
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class DeepLinkHandlerTest {
    private lateinit var auditLogger: AuditLogger
    private lateinit var handler: DeepLinkHandler
    private lateinit var payloadStore: NavigationPayloadStore

    companion object {
        @JvmStatic
        @BeforeClass
        fun setUpClass() {
            if (!EnvironmentManager.isInitialized()) {
                val mockPrefs = mock<SharedPreferences> {
                    on { getBoolean(any(), any()) }.thenReturn(false)
                }
                EnvironmentManager.initializeForTesting(mockPrefs)
            }
        }
    }

    @Before
    fun setUp() {
        auditLogger = mock()
        payloadStore = NavigationPayloadStore()
        handler = DeepLinkHandler(
            RuntimeEnvironment.getApplication(),
            auditLogger,
            payloadStore,
        )
        handler.clearNonceTracking()
    }

    private fun makeVerifyPayload(
        challengeId: String = "test-challenge-id",
        environment: String = "production",
    ): String {
        val payload = JSONObject().apply {
            put("challenge_id", challengeId)
            put("rp_challenge", "abcdefghijklmnopqrstuvwxyz01234567890ABCDEF")
            put("cutoff_days", 6570)
            put("verifying_key_id", 2031517468)
            put("submit_secret", "ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdef")
            put("environment", environment)
            put("verify_url", "https://verify.provii.app/v1/verify")
        }
        val json = payload.toString()
        return Base64.encodeToString(
            json.toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
    }

    @Test
    fun handleUriRejectsEmptyScheme() {
        val uri = Uri.parse("")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleUriRejectsUnknownScheme() {
        val uri = Uri.parse("ftp://provii.app/verify?d=abc")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleUriRejectsUnknownLegacyHost() {
        val uri = Uri.parse("provii://unknown?d=abc")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleUriRejectsUnknownHttpsPath() {
        val uri = Uri.parse("https://provii.app/unknown?d=abc")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleUriRejectsOverlongUrl() {
        val longData = "a".repeat(2100)
        val uri = Uri.parse("provii://verify?d=$longData")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleUriRejectsRateLimitedRequests() {
        // Exhaust the rate limit (10 per minute)
        for (i in 0..10) {
            handler.handleUri(Uri.parse("provii://verify?d=invalid"))
        }
        // The 12th should be rate limited
        val result = handler.handleUri(Uri.parse("provii://verify?d=invalid"))
        assertNull(result)
    }

    @Test
    fun isVerificationDeepLinkReturnsTrueForLegacyVerify() {
        val uri = Uri.parse("provii://verify?d=abc")
        assertTrue(handler.isVerificationDeepLink(uri))
    }

    @Test
    fun isVerificationDeepLinkReturnsTrueForHttpsVerify() {
        val uri = Uri.parse("https://provii.app/verify?d=abc")
        assertTrue(handler.isVerificationDeepLink(uri))
    }

    @Test
    fun isVerificationDeepLinkReturnsFalseForAttest() {
        val uri = Uri.parse("provii://attest?d=abc")
        assertFalse(handler.isVerificationDeepLink(uri))
    }

    @Test
    fun isVerificationDeepLinkReturnsFalseForRandom() {
        val uri = Uri.parse("https://example.com/verify?d=abc")
        assertFalse(handler.isVerificationDeepLink(uri))
    }

    @Test
    fun handleVerifyUriWithValidPayloadReturnsRoute() {
        val encoded = makeVerifyPayload()
        val uri = Uri.parse("provii://verify?d=$encoded")
        val route = handler.handleUri(uri)
        assertNotNull(route)
        assertTrue(route!!.startsWith("deeplink_verification/"))
    }

    @Test
    fun handleVerifyUriBlocksReplay() {
        val encoded = makeVerifyPayload(challengeId = "replay-test-id")
        val uri = Uri.parse("provii://verify?d=$encoded")
        val route1 = handler.handleUri(uri)
        assertNotNull(route1)
        val route2 = handler.handleUri(uri)
        assertNull(route2) // Replay blocked
    }

    @Test
    fun handleVerifyUriRejectsMissingData() {
        val uri = Uri.parse("provii://verify")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleAttestUriWithValidDataReturnsRoute() {
        // Valid base64url data
        val data = Base64.encodeToString(
            """{"dob_days":7300,"issuer_id":"iss-1","timestamp":1700000000,"nonce":"abc"}""".toByteArray(),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        val uri = Uri.parse("provii://attest?d=$data")
        val route = handler.handleUri(uri)
        assertNotNull(route)
        assertTrue(route!!.startsWith("deeplink_attest/"))
    }

    @Test
    fun handleAttestUriRejectsMissingData() {
        val uri = Uri.parse("provii://attest")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleAttestUriRejectsOversizedData() {
        val longData = "A".repeat(1001)
        val uri = Uri.parse("provii://attest?d=$longData")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleAttestUriBlocksReplay() {
        val data = "SGVsbG8gV29ybGQ"
        val uri = Uri.parse("provii://attest?d=$data")
        handler.handleUri(uri)
        val route2 = handler.handleUri(uri)
        assertNull(route2)
    }

    @Test
    fun getSecurityStatsReturnsExpectedKeys() {
        val stats = handler.getSecurityStats()
        assertTrue(stats.containsKey("tracked_nonces"))
        assertTrue(stats.containsKey("rate_limit_count"))
        assertTrue(stats.containsKey("rate_limit_window_remaining_ms"))
    }

    @Test
    fun createVerificationDeepLinkProducesValidUri() {
        val link = handler.createVerificationDeepLink(
            challengeId = "cid-1",
            rpChallenge = "abcdefghijklmnopqrstuvwxyz01234567890ABCDEF",
            cutoffDays = 6570,
            verifyingKeyId = 1234,
            submitSecret = "ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdef",
            environment = "production",
        )
        assertTrue(link.startsWith("provii://verify?d="))
    }

    @Test
    fun currentNoncePrefsNameReturnsProductionByDefault() {
        val name = DeepLinkHandler.currentNoncePrefsName()
        assertEquals("provii_deeplink_nonces", name)
    }

    @Test
    fun handleHttpsVerifyRoute() {
        val encoded = makeVerifyPayload(challengeId = "https-test-id")
        val uri = Uri.parse("https://provii.app/verify?d=$encoded")
        val route = handler.handleUri(uri)
        assertNotNull(route)
        assertTrue(route!!.startsWith("deeplink_verification/"))
    }

    @Test
    fun handleHttpsAttestRoute() {
        val data = "SGVsbG8gUHJvdmlp"
        val uri = Uri.parse("https://provii.app/attest?d=$data")
        val route = handler.handleUri(uri)
        assertNotNull(route)
        assertTrue(route!!.startsWith("deeplink_attest/"))
    }

    @Test
    fun dismissSandboxPromptClearsState() {
        assertNull(handler.pendingSandboxPrompt.value)
        handler.dismissSandboxPrompt() // Should not throw
    }

    @Test
    fun confirmSandboxPromptReturnsNullWhenNoPending() {
        assertNull(handler.confirmSandboxPrompt())
    }

    @Test
    fun handleVerifyRejectsMissingEnvironment() {
        val payload = JSONObject().apply {
            put("challenge_id", "no-env-test")
            put("rp_challenge", "abcdefghijklmnopqrstuvwxyz01234567890ABCDEF")
            put("cutoff_days", 6570)
            put("verifying_key_id", 2031517468)
            put("submit_secret", "ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdef")
            // No environment field
        }
        val encoded = Base64.encodeToString(
            payload.toString().toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        val uri = Uri.parse("provii://verify?d=$encoded")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleVerifyRejectsInvalidEnvironmentValue() {
        val payload = JSONObject().apply {
            put("challenge_id", "invalid-env-test")
            put("rp_challenge", "abcdefghijklmnopqrstuvwxyz01234567890ABCDEF")
            put("cutoff_days", 6570)
            put("verifying_key_id", 2031517468)
            put("submit_secret", "ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdef")
            put("environment", "staging") // Not production or sandbox
        }
        val encoded = Base64.encodeToString(
            payload.toString().toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        val uri = Uri.parse("provii://verify?d=$encoded")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun handleUriRejectsSuspiciousPatterns() {
        val uri = Uri.parse("provii://verify?d=abc%3Cscript%3E")
        assertNull(handler.handleUri(uri))
    }

    @Test
    fun sandboxEnvParamPrompts() {
        val encoded = makeVerifyPayload(challengeId = "sandbox-env-test")
        val uri = Uri.parse("provii://verify?d=$encoded&env=sandbox")
        val route = handler.handleUri(uri)
        assertNull(route) // Should prompt, not route
        assertNotNull(handler.pendingSandboxPrompt.value)
    }
}
