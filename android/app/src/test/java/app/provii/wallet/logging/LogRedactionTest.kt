// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.logging

import org.junit.Assert.assertEquals
import org.junit.Test

class LogRedactionTest {
    @Test
    fun `redactId returns empty marker for blank input`() {
        assertEquals("[empty]", redactId(""))
        assertEquals("[empty]", redactId("   "))
    }

    @Test
    fun `redactId replaces short strings entirely`() {
        assertEquals("***", redactId("a"))
        assertEquals("***", redactId("ab"))
        assertEquals("***", redactId("abc"))
        assertEquals("***", redactId("abcd"))
    }

    @Test
    fun `redactId shows first four chars for longer strings`() {
        assertEquals("abcd***", redactId("abcde"))
        assertEquals("abcd***", redactId("abcdef"))
        assertEquals("1234***", redactId("1234567890"))
    }
}
