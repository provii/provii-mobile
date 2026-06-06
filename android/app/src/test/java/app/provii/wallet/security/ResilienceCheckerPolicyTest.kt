package app.provii.wallet.security

import android.content.Context
import app.provii.wallet.security.resilience.ResilienceChecker
import app.provii.wallet.security.resilience.ResilienceChecker.ResilienceConfig
import app.provii.wallet.security.resilience.ResilienceChecker.SecurityLevel
import app.provii.wallet.security.resilience.ResilienceChecker.ThreatResponsePolicy
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import java.util.concurrent.atomic.AtomicReference

/**
 * Unit tests for ResilienceChecker.shouldRestrictCredentials boundary logic.
 *
 * Verifies that credential restriction is only applied when both:
 *  - the security level is COMPROMISED or CRITICAL, AND
 *  - the threat response policy is RESTRICT_FEATURES or TERMINATE
 */
class ResilienceCheckerPolicyTest {
    @Before
    fun setUp() {
        // Reset the singleton so each test gets a fresh instance with its own config
        val instanceField = ResilienceChecker::class.java.getDeclaredField("instance")
        instanceField.isAccessible = true
        instanceField.set(null, null)
    }

    private fun buildChecker(policy: ThreatResponsePolicy): ResilienceChecker {
        val context = mock(Context::class.java)
        `when`(context.applicationContext).thenReturn(context)
        val config = ResilienceConfig(threatResponsePolicy = policy)
        return ResilienceChecker.getInstance(context, config)
    }

    private fun buildResult(securityLevel: SecurityLevel): ResilienceChecker.ResilienceResult {
        return ResilienceChecker.ResilienceResult(
            antiDebugResult = null,
            integrityResult = null,
            rootResult = null,
            overallSecure = securityLevel == SecurityLevel.SECURE,
            securityLevel = securityLevel,
            allThreats = if (securityLevel == SecurityLevel.SECURE) emptyList() else listOf("test threat"),
            recommendations = emptyList(),
        )
    }

    private fun injectCachedResult(
        checker: ResilienceChecker,
        result: ResilienceChecker.ResilienceResult,
    ) {
        val field = ResilienceChecker::class.java.getDeclaredField("lastResult")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val ref = field.get(checker) as AtomicReference<ResilienceChecker.ResilienceResult?>
        ref.set(result)
    }

    // --- RESTRICT_FEATURES policy ---

    @Test
    fun `shouldRestrictCredentials returns true for RESTRICT_FEATURES with CRITICAL level`() {
        val checker = buildChecker(ThreatResponsePolicy.RESTRICT_FEATURES)
        injectCachedResult(checker, buildResult(SecurityLevel.CRITICAL))
        assertTrue(checker.shouldRestrictCredentials())
    }

    @Test
    fun `shouldRestrictCredentials returns true for RESTRICT_FEATURES with COMPROMISED level`() {
        val checker = buildChecker(ThreatResponsePolicy.RESTRICT_FEATURES)
        injectCachedResult(checker, buildResult(SecurityLevel.COMPROMISED))
        assertTrue(checker.shouldRestrictCredentials())
    }

    @Test
    fun `shouldRestrictCredentials returns false for RESTRICT_FEATURES with AT_RISK level`() {
        val checker = buildChecker(ThreatResponsePolicy.RESTRICT_FEATURES)
        injectCachedResult(checker, buildResult(SecurityLevel.AT_RISK))
        assertFalse(checker.shouldRestrictCredentials())
    }

    @Test
    fun `shouldRestrictCredentials returns false for RESTRICT_FEATURES with SECURE level`() {
        val checker = buildChecker(ThreatResponsePolicy.RESTRICT_FEATURES)
        injectCachedResult(checker, buildResult(SecurityLevel.SECURE))
        assertFalse(checker.shouldRestrictCredentials())
    }

    // --- TERMINATE policy ---

    @Test
    fun `shouldRestrictCredentials returns true for TERMINATE with CRITICAL level`() {
        val checker = buildChecker(ThreatResponsePolicy.TERMINATE)
        injectCachedResult(checker, buildResult(SecurityLevel.CRITICAL))
        assertTrue(checker.shouldRestrictCredentials())
    }

    @Test
    fun `shouldRestrictCredentials returns true for TERMINATE with COMPROMISED level`() {
        val checker = buildChecker(ThreatResponsePolicy.TERMINATE)
        injectCachedResult(checker, buildResult(SecurityLevel.COMPROMISED))
        assertTrue(checker.shouldRestrictCredentials())
    }

    // --- LOG_ONLY policy ---

    @Test
    fun `shouldRestrictCredentials returns false for LOG_ONLY even with CRITICAL level`() {
        val checker = buildChecker(ThreatResponsePolicy.LOG_ONLY)
        injectCachedResult(checker, buildResult(SecurityLevel.CRITICAL))
        assertFalse(checker.shouldRestrictCredentials())
    }

    // --- LOG_AND_WARN policy ---

    @Test
    fun `shouldRestrictCredentials returns false for LOG_AND_WARN even with CRITICAL level`() {
        val checker = buildChecker(ThreatResponsePolicy.LOG_AND_WARN)
        injectCachedResult(checker, buildResult(SecurityLevel.CRITICAL))
        assertFalse(checker.shouldRestrictCredentials())
    }

    // --- No cached result ---

    @Test
    fun `shouldRestrictCredentials returns false when no result cached`() {
        val checker = buildChecker(ThreatResponsePolicy.RESTRICT_FEATURES)
        assertFalse(checker.shouldRestrictCredentials())
    }
}
