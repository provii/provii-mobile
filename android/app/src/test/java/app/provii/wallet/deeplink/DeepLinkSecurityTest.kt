package app.provii.wallet.deeplink

import android.content.SharedPreferences
import android.net.Uri
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.navigation.NavigationPayloadStore
import app.provii.wallet.security.AuditLogger
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.any
import org.mockito.kotlin.times
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for DeepLinkHandler security features (MASVS-PLATFORM-3)
 *
 * Tests cover:
 * 1. Rate limiting
 * 2. Nonce/replay attack prevention
 * 3. URL validation
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class DeepLinkSecurityTest {
    private lateinit var auditLogger: AuditLogger
    private lateinit var deepLinkHandler: DeepLinkHandler

    companion object {
        @JvmStatic
        @BeforeClass
        fun setUpClass() {
            // Initialize EnvironmentManager for testing if not already initialized
            if (!EnvironmentManager.isInitialized()) {
                val mockPrefs =
                    mock<SharedPreferences> {
                        on { getBoolean(any(), any()) }.thenReturn(false)
                        on { getString(any(), any()) }.thenReturn("production")
                    }
                EnvironmentManager.initializeForTesting(mockPrefs)
            }
        }
    }

    @Before
    fun setUp() {
        auditLogger = mock()
        val mockContext: android.content.Context = mock()
        deepLinkHandler = DeepLinkHandler(mockContext, auditLogger, NavigationPayloadStore())
        // Clear any nonces from previous tests
        deepLinkHandler.clearNonceTracking()
    }

    // ==================== RATE LIMITING TESTS ====================

    @Test
    fun `rate limiting allows first 10 requests`() {
        // Create 10 valid verify URIs with unique challenge IDs
        repeat(10) { index ->
            val challengePayload = createChallengePayload("challenge-$index")
            val uri = createVerifyUri(challengePayload)
            val result = deepLinkHandler.handleUri(uri)
            assertNotNull("Request $index should be allowed", result)
        }
    }

    @Test
    fun `rate limiting blocks requests after limit exceeded`() {
        // Create 11 unique verify URIs to trigger rate limiting
        repeat(10) { index ->
            // Clear nonce tracking to avoid replay detection affecting this test
            deepLinkHandler.clearNonceTracking()
            val challengePayload = createChallengePayload("challenge-limit-$index")
            val uri = createVerifyUri(challengePayload)
            deepLinkHandler.handleUri(uri)
        }

        // 11th request should be blocked by rate limiting
        val challengePayload = createChallengePayload("challenge-limit-11")
        val uri = createVerifyUri(challengePayload)
        val result = deepLinkHandler.handleUri(uri)
        assertNull("Request 11 should be blocked by rate limiting", result)
    }

    @Test
    fun `security stats reports rate limit count`() {
        // Make a few requests
        repeat(3) { index ->
            deepLinkHandler.clearNonceTracking()
            val challengePayload = createChallengePayload("stats-challenge-$index")
            val uri = createVerifyUri(challengePayload)
            deepLinkHandler.handleUri(uri)
        }

        val stats = deepLinkHandler.getSecurityStats()
        assertTrue("Rate limit count should be at least 3", (stats["rate_limit_count"] as Int) >= 3)
    }

    // ==================== REPLAY ATTACK PREVENTION TESTS ====================

    @Test
    fun `verify deep link replay is blocked`() {
        val challengePayload = createChallengePayload("test-challenge-123")
        val uri = createVerifyUri(challengePayload)

        // First request should succeed
        val firstResult = deepLinkHandler.handleUri(uri)
        assertNotNull("First verify request should succeed", firstResult)

        // Second request with same challenge_id should be blocked
        val secondResult = deepLinkHandler.handleUri(uri)
        assertNull("Replay of verify request should be blocked", secondResult)
    }

    @Test
    fun `different nonces are not blocked`() {
        val challengePayload1 = createChallengePayload("unique-challenge-1")
        val challengePayload2 = createChallengePayload("unique-challenge-2")

        val uri1 = createVerifyUri(challengePayload1)
        val uri2 = createVerifyUri(challengePayload2)

        // Both should succeed as they have different challenge IDs
        val result1 = deepLinkHandler.handleUri(uri1)
        val result2 = deepLinkHandler.handleUri(uri2)

        assertNotNull("First challenge should be allowed", result1)
        assertNotNull("Second (different) challenge should also be allowed", result2)
    }

    @Test
    fun `clear nonce tracking resets replay detection`() {
        val challengePayload = createChallengePayload("reset-challenge")
        val uri = createVerifyUri(challengePayload)

        // First request
        deepLinkHandler.handleUri(uri)

        // Clear nonce tracking
        deepLinkHandler.clearNonceTracking()

        // Same request should now succeed
        val result = deepLinkHandler.handleUri(uri)
        assertNotNull("Request should succeed after clearing nonce tracking", result)
    }

    @Test
    fun `security stats reports tracked nonces count`() {
        val challenges = listOf("nonce-track-1", "nonce-track-2", "nonce-track-3")

        challenges.forEach { challengeId ->
            val challengePayload = createChallengePayload(challengeId)
            val uri = createVerifyUri(challengePayload)
            deepLinkHandler.handleUri(uri)
        }

        val stats = deepLinkHandler.getSecurityStats()
        assertTrue("Should have tracked nonces", (stats["tracked_nonces"] as Int) >= challenges.size)
    }

    // ==================== URL VALIDATION TESTS ====================

    @Test
    fun `rejects URLs with javascript scheme injection`() {
        // This tests that malicious URLs are rejected
        // Note: Uri.parse may normalize these, so we test the validation logic
        val maliciousUrl = "provii://verify?d=javascript:alert(1)"
        val uri = Uri.parse(maliciousUrl)

        // Should be rejected during URL validation
        val result = deepLinkHandler.handleUri(uri)
        assertNull("JavaScript injection should be blocked", result)
    }

    @Test
    fun `rejects URLs that are too long`() {
        // Create a URL with a very long parameter
        val longData = "a".repeat(10001)
        val longUrl = "provii://verify?d=$longData"
        val uri = Uri.parse(longUrl)

        val result = deepLinkHandler.handleUri(uri)
        assertNull("Excessively long URL should be blocked", result)
    }

    @Test
    fun `accepts valid App Links URL`() {
        val challengePayload = createChallengePayload("unique-challenge-for-applinks")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("https://provii.app/verify?d=$encoded")

        val result = deepLinkHandler.handleUri(uri)
        assertNotNull("Valid App Links URL should be accepted", result)
    }

    @Test
    fun `rejects unknown hosts`() {
        val uri = Uri.parse("provii://unknown_action?param=value")
        val result = deepLinkHandler.handleUri(uri)
        assertNull("Unknown host should be rejected", result)
    }

    @Test
    fun `rejects unsupported schemes`() {
        val uri = Uri.parse("http://provii.app/verify?d=test")
        val result = deepLinkHandler.handleUri(uri)
        assertNull("HTTP scheme should be rejected (only HTTPS allowed)", result)
    }

    // ==================== EXPIRED CHALLENGE ====================

    @Test
    fun `rejects expired verification challenge`() {
        val rpChallenge = "a".repeat(43)
        val submitSecret = "b".repeat(43)
        // expires_at is 1 hour in the PAST
        val expiresAt = (System.currentTimeMillis() / 1000) - 3600

        val expiredPayload =
            """
            {
                "challenge_id": "expired-challenge-001",
                "rp_challenge": "$rpChallenge",
                "submit_secret": "$submitSecret",
                "cutoff_days": 30,
                "verifying_key_id": 1,
                "environment": "production",
                "verify_url": "https://verify.provii.app/v1/verify",
                "expires_at": $expiresAt
            }
            """.trimIndent()

        val uri = createVerifyUri(expiredPayload)
        val result = deepLinkHandler.handleUri(uri)
        assertNull("Expired challenge should be rejected", result)
    }

    @Test
    fun `accepts challenge with future expiry`() {
        val rpChallenge = "c".repeat(43)
        val submitSecret = "d".repeat(43)
        // expires_at is 1 hour in the future
        val expiresAt = (System.currentTimeMillis() / 1000) + 3600

        val validPayload =
            """
            {
                "challenge_id": "future-expiry-001",
                "rp_challenge": "$rpChallenge",
                "submit_secret": "$submitSecret",
                "cutoff_days": 30,
                "verifying_key_id": 1,
                "environment": "production",
                "verify_url": "https://verify.provii.app/v1/verify",
                "expires_at": $expiresAt
            }
            """.trimIndent()

        val uri = createVerifyUri(validPayload)
        val result = deepLinkHandler.handleUri(uri)
        assertNotNull("Challenge with future expiry should be accepted", result)
    }

    // ==================== HELPER METHODS ====================

    private fun createVerifyUri(jsonPayload: String): Uri {
        val encoded = base64UrlEncode(jsonPayload)
        return Uri.parse("provii://verify?d=$encoded")
    }

    private fun createChallengePayload(challengeId: String): String {
        val rpChallenge = "a".repeat(43) // 43 char base64url for 256-bit nonce
        val submitSecret = "b".repeat(43)
        val expiresAt = (System.currentTimeMillis() / 1000) + 3600 // 1 hour from now

        // `environment` is a required field on every challenge
        // payload. Test fixtures default to `production` so the security
        // tests here (rate limiting, replay detection, nonce tracking) are
        // not entangled with the sandbox-on-production rejection
        // path, which has its own dedicated coverage in
        // `DeepLinkSandboxEnvTest`.
        return """
            {
                "challenge_id": "$challengeId",
                "rp_challenge": "$rpChallenge",
                "submit_secret": "$submitSecret",
                "cutoff_days": 30,
                "verifying_key_id": 1,
                "environment": "production",
                "verify_url": "https://verify.provii.app/v1/verify",
                "expires_at": $expiresAt
            }
            """.trimIndent()
    }

    private fun base64UrlEncode(data: String): String {
        return android.util.Base64.encodeToString(
            data.toByteArray(Charsets.UTF_8),
            android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING,
        )
    }
}
