// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.error

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for [ErrorHandler.ErrorInfo] and [ErrorHandler.ErrorType] data classes.
 * The actual handleError method requires Android Context for string resources,
 * so it is tested via Robolectric in the existing test suite. These tests
 * validate the data model behaviour.
 */
class ErrorHandlerTest {
    @Test
    fun errorInfoPreservesAllFields() {
        val info = ErrorHandler.ErrorInfo(
            userMessage = "test message",
            errorType = ErrorHandler.ErrorType.NETWORK,
            isRetryable = true,
            actionLabel = "Retry",
        )
        assertEquals("test message", info.userMessage)
        assertEquals(ErrorHandler.ErrorType.NETWORK, info.errorType)
        assertTrue(info.isRetryable)
        assertEquals("Retry", info.actionLabel)
    }

    @Test
    fun errorInfoDefaultActionLabelIsNull() {
        val info = ErrorHandler.ErrorInfo(
            userMessage = "msg",
            errorType = ErrorHandler.ErrorType.UNKNOWN,
            isRetryable = false,
        )
        assertEquals(null, info.actionLabel)
    }

    @Test
    fun errorTypeEnumHasAllExpectedValues() {
        val types = ErrorHandler.ErrorType.entries
        assertTrue(types.contains(ErrorHandler.ErrorType.NETWORK))
        assertTrue(types.contains(ErrorHandler.ErrorType.SECURITY))
        assertTrue(types.contains(ErrorHandler.ErrorType.VALIDATION))
        assertTrue(types.contains(ErrorHandler.ErrorType.STATE))
        assertTrue(types.contains(ErrorHandler.ErrorType.STORAGE))
        assertTrue(types.contains(ErrorHandler.ErrorType.PROOF))
        assertTrue(types.contains(ErrorHandler.ErrorType.UNKNOWN))
        assertEquals(7, types.size)
    }
}
