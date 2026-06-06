// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.deeplink

import android.content.SharedPreferences
import android.net.Uri
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.config.SandboxCredentialFetcher
import app.provii.wallet.navigation.NavigationPayloadStore
import app.provii.wallet.security.AuditLogger
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for the `?env=sandbox` advisory query parameter ().
 *
 * The validator does not reject a deep-link based on its env value: the
 * allowlist checks treat env purely as advisory, and the sheet UX in
 * MainActivity is the consent gate. These tests pin that contract so a
 * future change cannot silently start rejecting env values.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class DeepLinkSandboxEnvTest {
    private lateinit var auditLogger: AuditLogger
    private lateinit var deepLinkHandler: DeepLinkHandler

    companion object {
        /** Backing store for the stateful mock so putBoolean/getBoolean round-trips. */
        private val prefsStore = java.util.concurrent.ConcurrentHashMap<String, Any>()

        @JvmStatic
        @BeforeClass
        fun setUpClass() {
            prefsStore.clear()
            val mockEditor =
                mock<SharedPreferences.Editor> {
                    on { putBoolean(any(), any()) }.thenAnswer { invocation ->
                        val key = invocation.getArgument<String>(0)
                        val value = invocation.getArgument<Boolean>(1)
                        prefsStore[key] = value
                        mock
                    }
                    on { putString(any(), any()) }.thenAnswer { invocation ->
                        val key = invocation.getArgument<String>(0)
                        val value = invocation.getArgument<String>(1)
                        prefsStore[key] = value
                        mock
                    }
                    on { remove(any()) }.thenReturn(mock)
                    on { apply() }.then { /* no-op */ }
                    on { commit() }.thenReturn(true)
                }
            val mockPrefs =
                mock<SharedPreferences> {
                    on { getBoolean(any(), any()) }.thenAnswer { invocation ->
                        val key = invocation.getArgument<String>(0)
                        val default = invocation.getArgument<Boolean>(1)
                        prefsStore[key] as? Boolean ?: default
                    }
                    on { getString(any(), any()) }.thenAnswer { invocation ->
                        val key = invocation.getArgument<String>(0)
                        val default = invocation.getArgument<String>(1)
                        prefsStore[key] as? String ?: default
                    }
                    on { edit() }.thenReturn(mockEditor)
                }
            // Force re-initialisation so this test class always gets
            // the stateful mock, regardless of class ordering.
            EnvironmentManager.initializeForTesting(mockPrefs)
            SandboxCredentialFetcher.initializeForTesting(mockPrefs)
        }
    }

    @Before
    fun setUp() {
        auditLogger = mock()
        val mockContext: android.content.Context = mock()
        deepLinkHandler = DeepLinkHandler(mockContext, auditLogger, NavigationPayloadStore())
        deepLinkHandler.clearNonceTracking()

        // Start every test in production so `?env=sandbox` trips the prompt
        // path rather than being absorbed by an already-sandbox wallet.
        if (EnvironmentManager.isSandboxEnabled()) {
            EnvironmentManager.enableSandbox(false)
        }
    }

    @After
    fun tearDown() {
        // Leave the global EnvironmentManager in production so sibling test
        // classes observe a clean slate.
        if (EnvironmentManager.isSandboxEnabled()) {
            EnvironmentManager.enableSandbox(false)
        }
        deepLinkHandler.dismissSandboxPrompt()
    }

    // ==================== ENV PARAMETER BEHAVIOUR ====================

    @Test
    fun `env=sandbox triggers prompt instead of immediate routing`() {
        val challengePayload = createChallengePayload("env-sandbox-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=sandbox&d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull("Sandbox env must defer routing behind the prompt", route)
        assertNotNull(
            "Sandbox env must raise the prompt state for the UI to observe",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `env=production is tolerated and routes normally`() {
        val challengePayload = createChallengePayload("env-production-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=production&d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNotNull("env=production must route without prompting", route)
        assertNull(
            "env=production must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `missing env is tolerated and routes normally`() {
        val challengePayload = createChallengePayload("env-missing-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNotNull("Missing env must route without prompting", route)
        assertNull(
            "Missing env must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `garbage env value is ignored and routes normally`() {
        // Pinned behaviour: any env value other than "sandbox" is advisory-only
        // and routes normally. The validator never rejects based on env.
        val challengePayload = createChallengePayload("env-garbage-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=%24%7Bjndi%7D&d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull(
            "Garbage env containing JNDI-style metachars must still be rejected " +
                "by the upstream injection filter",
            route,
        )
        assertNull(
            "Garbage env must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `plain garbage env value routes normally`() {
        val challengePayload = createChallengePayload("env-garbage-2")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=banana&d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNotNull(
            "Non-sandbox env values are advisory-only and must route normally",
            route,
        )
        assertNull(
            "Non-sandbox env must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `env=SANDBOX is matched case-insensitively`() {
        val challengePayload = createChallengePayload("env-sandbox-case-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=SANDBOX&d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull("env=SANDBOX must be treated like env=sandbox", route)
        assertNotNull(
            "Uppercase env=SANDBOX must raise the prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `env=sandbox on already-sandbox wallet does not prompt`() {
        EnvironmentManager.enableSandbox(true)
        try {
            val challengePayload = createChallengePayload("env-sandbox-already-1")
            val encoded = base64UrlEncode(challengePayload)
            val uri = Uri.parse("provii://verify?env=sandbox&d=$encoded")

            val route = deepLinkHandler.handleUri(uri)

            assertNotNull(
                "env=sandbox while already in sandbox must route normally",
                route,
            )
            assertNull(
                "env=sandbox while already in sandbox must not raise the prompt",
                deepLinkHandler.pendingSandboxPrompt.value,
            )
        } finally {
            EnvironmentManager.enableSandbox(false)
        }
    }

    @Test
    fun `dismissSandboxPrompt drops the pending state`() {
        val challengePayload = createChallengePayload("env-dismiss-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=sandbox&d=$encoded")

        deepLinkHandler.handleUri(uri)
        assertNotNull(deepLinkHandler.pendingSandboxPrompt.value)

        deepLinkHandler.dismissSandboxPrompt()

        assertNull(
            "dismissSandboxPrompt must clear the prompt state",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    // ==================== CHALLENGE PAYLOAD ENVIRONMENT FIELD (/ ) ====================

    @Test
    fun `challenge payload missing environment is rejected`() {
        // `environment` is a required field. The gateway always
        // emits it, so absence is a protocol violation rather than something
        // to paper over with a defensive default.
        val challengePayload = createChallengePayloadWithoutEnv("env-field-missing-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull("Challenge payload missing environment must be rejected", route)
        assertNull(
            "Missing environment must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `challenge payload with invalid environment is rejected`() {
        // only `sandbox` and `production` are valid. Any other
        // value is a malformed payload. No defensive mapping.
        val challengePayload = createChallengePayloadWithEnv("env-field-bad-1", env = "staging")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull("Challenge payload with invalid environment must be rejected", route)
        assertNull(
            "Invalid environment must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `challenge payload environment=production routes normally`() {
        val challengePayload = createChallengePayloadWithEnv("env-field-prod-1", env = "production")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNotNull("Production-marked challenge on production wallet must route", route)
        assertNull(
            "Production-marked challenge must not raise the sandbox prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    @Test
    fun `challenge payload environment=sandbox on production wallet raises challenge prompt`() {
        // sandbox-marked challenge on a production-toggled wallet
        // must raise the challenge-specific prompt (distinct from the W13
        // URL-level prompt) and defer routing without consuming the nonce.
        val challengePayload = createChallengePayloadWithEnv("env-field-sandbox-1", env = "sandbox")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull("Sandbox-marked challenge on production must defer routing", route)
        val prompt = deepLinkHandler.pendingSandboxPrompt.value
        assertNotNull("Sandbox-marked challenge must raise the prompt", prompt)
        assertEquals(
            "Sandbox-marked challenge must raise the challenge-specific prompt",
            DeepLinkHandler.SandboxPromptSource.CHALLENGE,
            prompt!!.source,
        )
    }

    @Test
    fun `challenge payload environment=SANDBOX is matched case-insensitively`() {
        // The parser lowercases the environment value before the rejection
        // check, so an uppercase "SANDBOX" is treated identically to
        // "sandbox".
        val challengePayload = createChallengePayloadWithEnv("env-field-case-1", env = "SANDBOX")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?d=$encoded")

        val route = deepLinkHandler.handleUri(uri)

        assertNull("Uppercase SANDBOX must be treated like sandbox", route)
        assertNotNull(
            "Uppercase SANDBOX must raise the prompt",
            deepLinkHandler.pendingSandboxPrompt.value,
        )
    }

    // NOTE: The companion's stateful mock SharedPreferences now supports
    // putBoolean/getBoolean round-trips, so `EnvironmentManager.enableSandbox(true)`
    // correctly flips `isSandboxEnabled()`. The W13 sibling test
    // `env=sandbox on already-sandbox wallet does not prompt` validates
    // the sandbox-on-sandbox routing path.

    @Test
    fun `url-level prompt carries URL source`() {
        // Pin that a W13 URL-level trigger surfaces as URL source (so the
        // UI picks the deeplink_sandbox_prompt_* strings, not the
        // challenge_sandbox_prompt_* ones).
        val challengePayload = createChallengePayload("env-source-url-1")
        val encoded = base64UrlEncode(challengePayload)
        val uri = Uri.parse("provii://verify?env=sandbox&d=$encoded")

        deepLinkHandler.handleUri(uri)

        val prompt = deepLinkHandler.pendingSandboxPrompt.value
        assertNotNull("URL-level env=sandbox must raise the prompt", prompt)
        assertEquals(
            "URL-level trigger must carry URL source",
            DeepLinkHandler.SandboxPromptSource.URL,
            prompt!!.source,
        )
    }

    // ==================== ENV-NAMESPACED NONCE BUCKETS ====================

    @Test
    fun `nonce prefs file name reflects active environment`() {
        EnvironmentManager.enableSandbox(false)
        assertEquals(
            "provii_deeplink_nonces",
            DeepLinkHandler.currentNoncePrefsName(),
        )

        EnvironmentManager.enableSandbox(true)
        try {
            assertEquals(
                "provii_deeplink_nonces_sandbox",
                DeepLinkHandler.currentNoncePrefsName(),
            )
        } finally {
            EnvironmentManager.enableSandbox(false)
        }
    }

    // ==================== HELPER METHODS ====================

    /**
     * Production-environment challenge payload. required
     * `environment` field is present; use [createChallengePayloadWithEnv] or
     * [createChallengePayloadWithoutEnv] to cover the other branches.
     */
    private fun createChallengePayload(challengeId: String): String {
        return createChallengePayloadWithEnv(challengeId, env = "production")
    }

    /**
     * Challenge payload with a caller-specified `environment` value. Useful
     * for pinning the sandbox-on-production rejection path and the
     * environment-field validation rules.
     */
    private fun createChallengePayloadWithEnv(
        challengeId: String,
        env: String,
    ): String {
        val rpChallenge = "a".repeat(43)
        val submitSecret = "b".repeat(43)
        val expiresAt = (System.currentTimeMillis() / 1000) + 3600

        return """
            {
                "challenge_id": "$challengeId",
                "rp_challenge": "$rpChallenge",
                "submit_secret": "$submitSecret",
                "cutoff_days": 30,
                "verifying_key_id": 1,
                "environment": "$env",
                "verify_url": "https://verify.provii.app/v1/verify",
                "expires_at": $expiresAt
            }
            """.trimIndent()
    }

    /**
     * Challenge payload missing the required `environment` field.
     * treats this as a protocol violation and the parser returns null.
     */
    private fun createChallengePayloadWithoutEnv(challengeId: String): String {
        val rpChallenge = "a".repeat(43)
        val submitSecret = "b".repeat(43)
        val expiresAt = (System.currentTimeMillis() / 1000) + 3600

        return """
            {
                "challenge_id": "$challengeId",
                "rp_challenge": "$rpChallenge",
                "submit_secret": "$submitSecret",
                "cutoff_days": 30,
                "verifying_key_id": 1,
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
