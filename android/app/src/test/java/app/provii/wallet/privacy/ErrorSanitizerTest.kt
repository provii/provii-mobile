// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.privacy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ErrorSanitizerTest {
    @Test
    fun `sanitize redacts email addresses`() {
        val input = "Error for user test@example.com during login"
        val result = ErrorSanitizer.sanitize(input)
        assertTrue(result.contains("[email@redacted]"))
        assertFalse(result.contains("test@example.com"))
    }

    @Test
    fun `sanitize redacts JWT tokens`() {
        val jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.aLongBase64UrlSignature_Here"
        val input = "Auth token: $jwt"
        val result = ErrorSanitizer.sanitize(input)
        assertTrue(result.contains("[credential-redacted]"))
        assertFalse(result.contains("eyJ"))
    }

    @Test
    fun `sanitize redacts base64 credential fields`() {
        val input = """Failed with "r_bits": "QWxsIHlvdXIgYmFzZSBhcmUgYmVsb25nIHRvIHVz" in body"""
        val result = ErrorSanitizer.sanitize(input)
        assertTrue(result.contains("[credential-redacted]"))
        assertFalse(result.contains("QWxs"))
    }

    @Test
    fun `sanitize preserves safe messages`() {
        val input = "Something went wrong. Please try again."
        assertEquals(input, ErrorSanitizer.sanitize(input))
    }

    @Test
    fun `sanitize handles empty string`() {
        assertEquals("", ErrorSanitizer.sanitize(""))
    }

    @Test
    fun `sanitize handles multiple emails in one message`() {
        val input = "Sent to a@b.com and c@d.org"
        val result = ErrorSanitizer.sanitize(input)
        assertFalse(result.contains("a@b.com"))
        assertFalse(result.contains("c@d.org"))
    }
}
