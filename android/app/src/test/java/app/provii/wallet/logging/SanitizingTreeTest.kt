// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.logging

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Method

/**
 * Tests for [SanitizingTree]. Invokes the private `redact` method via reflection
 * to verify JWT, credential field, and credential ID redaction patterns without
 * requiring Timber to be planted.
 */
class SanitizingTreeTest {
    private val tree = SanitizingTree()
    private val redactMethod: Method =
        SanitizingTree::class.java.getDeclaredMethod("redact", String::class.java).apply {
            isAccessible = true
        }

    private fun redact(input: String): String = redactMethod.invoke(tree, input) as String

    @Test
    fun `redact replaces JWT tokens`() {
        val jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.bSxCCvYpgdI9tCZCBZ5kZE-p"
        val result = redact("Token: $jwt end")
        assertTrue(result.contains("[JWT-REDACTED]"))
        assertFalse(result.contains("eyJ"))
    }

    @Test
    fun `redact replaces base64 credential fields`() {
        val msg = """Found "r_bits": "QWxsIHlvdXIgYmFzZSBhcmUgYmVsb25nIHRvIHVz" in response"""
        val result = redact(msg)
        assertTrue(result.contains("[CREDENTIAL-REDACTED]"))
        assertFalse(result.contains("QWxs"))
    }

    @Test
    fun `redact replaces credential_id values`() {
        val msg = """Processing "credential_id": "abc123-def456-ghi789-jkl012" ..."""
        val result = redact(msg)
        assertTrue(result.contains("[ID-REDACTED]"))
    }

    @Test
    fun `redact leaves safe messages unchanged`() {
        val msg = "Wallet initialised in 200ms"
        val result = redact(msg)
        assertTrue(result == msg)
    }
}
