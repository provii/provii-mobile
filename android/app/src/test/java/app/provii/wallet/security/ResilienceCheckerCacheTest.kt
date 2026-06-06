package app.provii.wallet.security

import android.content.Context
import app.provii.wallet.security.resilience.ResilienceChecker
import app.provii.wallet.security.resilience.ResilienceChecker.ResilienceConfig
import app.provii.wallet.security.resilience.ResilienceChecker.SecurityLevel
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Unit tests for ResilienceChecker cache state management:
 * isDeviceCompromised, shouldPerformFullCheck timing, and getLastResult.
 */
class ResilienceCheckerCacheTest {
    private lateinit var checker: ResilienceChecker

    @Before
    fun setUp() {
        // Reset the singleton so each test gets a fresh instance
        val instanceField = ResilienceChecker::class.java.getDeclaredField("instance")
        instanceField.isAccessible = true
        instanceField.set(null, null)

        val context = mock(Context::class.java)
        `when`(context.applicationContext).thenReturn(context)
        checker =
            ResilienceChecker.getInstance(
                context,
                ResilienceConfig(checkIntervalMs = 1000L),
            )
    }

    @Test
    fun `isDeviceCompromised reflects injected compromised state`() {
        // Initially false
        assertFalse(checker.isDeviceCompromised())

        // Set compromised via reflection
        val field = ResilienceChecker::class.java.getDeclaredField("isCompromised")
        field.isAccessible = true
        val atomicBool = field.get(checker) as AtomicBoolean
        atomicBool.set(true)

        assertTrue(checker.isDeviceCompromised())
    }

    @Test
    fun `shouldPerformFullCheck returns true when interval elapsed`() {
        // With a fresh instance, lastCheckTime is 0, so elapsed > checkIntervalMs
        assertTrue(
            "Should perform full check when no check has ever been run",
            checker.shouldPerformFullCheck(),
        )

        // Simulate a recent check by setting lastCheckTime to now
        val field = ResilienceChecker::class.java.getDeclaredField("lastCheckTime")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val ref = field.get(checker) as AtomicReference<Long>
        ref.set(System.currentTimeMillis())

        assertFalse(
            "Should not perform full check immediately after a check",
            checker.shouldPerformFullCheck(),
        )
    }

    @Test
    fun `getLastResult returns null before any check and non-null after injection`() {
        assertNull("Should be null before any check", checker.getLastResult())

        // Inject a result
        val result =
            ResilienceChecker.ResilienceResult(
                antiDebugResult = null,
                integrityResult = null,
                rootResult = null,
                overallSecure = true,
                securityLevel = SecurityLevel.SECURE,
                allThreats = emptyList(),
                recommendations = emptyList(),
            )
        val field = ResilienceChecker::class.java.getDeclaredField("lastResult")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val ref = field.get(checker) as AtomicReference<ResilienceChecker.ResilienceResult?>
        ref.set(result)

        val retrieved = checker.getLastResult()
        assertNotNull("Should return cached result after injection", retrieved)
        assertEquals(SecurityLevel.SECURE, retrieved!!.securityLevel)
        assertTrue(retrieved.overallSecure)
    }
}
