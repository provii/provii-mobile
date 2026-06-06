package app.provii.wallet.security

import app.provii.wallet.security.resilience.ExceptionTally
import app.provii.wallet.security.resilience.ExceptionTallyBuilder
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for [ExceptionTally] and [ExceptionTallyBuilder].
 *
 * Validates threshold calculations, merge behaviour, and the runCheck
 * wrapper for both passing and throwing lambdas.
 */
class CheckOutcomeTest {
    // --- ExceptionTally ---

    @Test
    fun `ExceptionTally exceedsThreshold is true when ratio exceeds threshold`() {
        // 8/12 = 0.667 > 0.6
        val tally = ExceptionTally(totalChecks = 12, exceptionCount = 8, threshold = 0.6f)
        assertTrue("8/12 should exceed 60% threshold", tally.exceedsThreshold)
    }

    @Test
    fun `ExceptionTally exceedsThreshold is false when ratio is below threshold`() {
        // 7/12 = 0.583 < 0.6
        val tally = ExceptionTally(totalChecks = 12, exceptionCount = 7, threshold = 0.6f)
        assertFalse("7/12 should not exceed 60% threshold", tally.exceedsThreshold)
    }

    @Test
    fun `ExceptionTally exceedsThreshold is false when totalChecks is zero`() {
        val tally = ExceptionTally(totalChecks = 0, exceptionCount = 0, threshold = 0.6f)
        assertFalse("Zero total checks should not exceed threshold", tally.exceedsThreshold)
    }

    @Test
    fun `ExceptionTally exceedsThreshold is true when all checks threw`() {
        val tally = ExceptionTally(totalChecks = 11, exceptionCount = 11, threshold = 0.6f)
        assertTrue("11/11 should exceed 60% threshold", tally.exceedsThreshold)
    }

    @Test
    fun `ExceptionTally exceedsThreshold is false when no checks threw`() {
        val tally = ExceptionTally(totalChecks = 12, exceptionCount = 0, threshold = 0.6f)
        assertFalse("0/12 should not exceed 60% threshold", tally.exceedsThreshold)
    }

    // --- ExceptionTallyBuilder.runCheck ---

    @Test
    fun `runCheck returns lambda result on success`() {
        val builder = ExceptionTallyBuilder(threshold = 0.6f)
        val result = builder.runCheck("TestTag", "successCheck") { true }
        assertTrue("Should return true from successful check", result)
        val tally = builder.build()
        assertEquals(1, tally.totalChecks)
        assertEquals(0, tally.exceptionCount)
    }

    @Test
    fun `runCheck returns defaultOnException on throw`() {
        val builder = ExceptionTallyBuilder(threshold = 0.6f)
        val result =
            builder.runCheck("TestTag", "failingCheck") {
                throw RuntimeException("simulated failure")
            }
        assertFalse("Should return false (default) on exception", result)
        val tally = builder.build()
        assertEquals(1, tally.totalChecks)
        assertEquals(1, tally.exceptionCount)
    }

    @Test
    fun `runCheck returns custom defaultOnException value`() {
        val builder = ExceptionTallyBuilder(threshold = 0.6f)
        val result =
            builder.runCheck("TestTag", "failingCheck", defaultOnException = true) {
                throw RuntimeException("simulated failure")
            }
        assertTrue("Should return true (custom default) on exception", result)
    }

    @Test
    fun `runCheck catches Throwable not just Exception`() {
        val builder = ExceptionTallyBuilder(threshold = 0.6f)
        val result =
            builder.runCheck("TestTag", "errorCheck") {
                throw OutOfMemoryError("simulated OOM")
            }
        assertFalse("Should catch Throwable", result)
        val tally = builder.build()
        assertEquals(1, tally.exceptionCount)
    }

    @Test
    fun `builder accumulates multiple checks correctly`() {
        val builder = ExceptionTallyBuilder(threshold = 0.6f)
        builder.runCheck("T", "c1") { true }
        builder.runCheck("T", "c2") { false }
        builder.runCheck("T", "c3") { throw RuntimeException("fail") }
        builder.runCheck("T", "c4") { true }
        builder.runCheck("T", "c5") { throw IllegalStateException("fail") }

        val tally = builder.build()
        assertEquals(5, tally.totalChecks)
        assertEquals(2, tally.exceptionCount)
        assertFalse("2/5 = 40% should not exceed 60% threshold", tally.exceedsThreshold)
    }

    // --- ExceptionTallyBuilder.merge ---

    @Test
    fun `merge combines child tally counts into parent`() {
        val parent = ExceptionTallyBuilder(threshold = 0.6f)
        parent.runCheck("T", "p1") { true }
        parent.runCheck("T", "p2") { throw RuntimeException("fail") }

        val child = ExceptionTallyBuilder(threshold = 0.6f)
        child.runCheck("T", "c1") { true }
        child.runCheck("T", "c2") { throw RuntimeException("fail") }
        child.runCheck("T", "c3") { throw RuntimeException("fail") }

        parent.merge(child.build())
        val tally = parent.build()

        // Parent: 2 total, 1 exception. Child: 3 total, 2 exceptions. Merged: 5 total, 3 exceptions.
        assertEquals(5, tally.totalChecks)
        assertEquals(3, tally.exceptionCount)
    }

    @Test
    fun `merge with empty child does not change parent counts`() {
        val parent = ExceptionTallyBuilder(threshold = 0.6f)
        parent.runCheck("T", "p1") { true }

        val emptyChild = ExceptionTally(totalChecks = 0, exceptionCount = 0, threshold = 0.6f)
        parent.merge(emptyChild)

        val tally = parent.build()
        assertEquals(1, tally.totalChecks)
        assertEquals(0, tally.exceptionCount)
    }

    // --- Boundary cases for threshold ---

    @Test
    fun `exceedsThreshold is false at exactly 60 percent`() {
        // 6/10 = 0.6 which is not strictly greater than 0.6
        val tally = ExceptionTally(totalChecks = 10, exceptionCount = 6, threshold = 0.6f)
        assertFalse("Exactly 60% should not exceed threshold (strict >)", tally.exceedsThreshold)
    }

    @Test
    fun `exceedsThreshold is true just above 60 percent`() {
        // 7/11 = 0.636 > 0.6
        val tally = ExceptionTally(totalChecks = 11, exceptionCount = 7, threshold = 0.6f)
        assertTrue("7/11 = 63.6% should exceed 60% threshold", tally.exceedsThreshold)
    }
}
