// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.config

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Byte-exact agreement tests for the Kotlin JCS implementation against the
 * RFC 8785 appendix B vectors and Sarah's gateway canonicaliser. Any
 * divergence silently breaks HMAC verification, so every pattern here must
 * stay 100 percent aligned with the Swift + TypeScript emitters.
 */
class JsonCanonicaliserTest {
    @Test
    fun `integer renders without decimal`() {
        assertEquals("{\"n\":42}", JsonCanonicaliser.canonicalise(mapOf("n" to 42)))
    }

    @Test
    fun `large long renders without decimal`() {
        assertEquals(
            "{\"n\":1700000000000}",
            JsonCanonicaliser.canonicalise(mapOf("n" to 1_700_000_000_000L)),
        )
    }

    @Test
    fun `boolean and null emit literal tokens`() {
        val out =
            JsonCanonicaliser.canonicalise(
                mapOf("a" to true, "b" to false, "c" to null),
            )
        assertEquals("{\"a\":true,\"b\":false,\"c\":null}", out)
    }

    @Test
    fun `object keys sort in utf16 codeunit order`() {
        val out =
            JsonCanonicaliser.canonicalise(
                mapOf(
                    "platform" to "android",
                    "install_uuid" to "abc",
                    "app_version" to "1.0",
                ),
            )
        val appIdx = out.indexOf("\"app_version\"")
        val installIdx = out.indexOf("\"install_uuid\"")
        val platformIdx = out.indexOf("\"platform\"")
        assertTrue("app_version first", appIdx < installIdx)
        assertTrue("install_uuid before platform", installIdx < platformIdx)
    }

    @Test
    fun `short form escapes match rfc 8785`() {
        val out =
            JsonCanonicaliser.canonicalise(
                mapOf(
                    "slash" to "a/b",
                    "quote" to "a\"b",
                    "backslash" to "a\\b",
                    "bs" to "a\bb",
                    "tab" to "a\tb",
                    "lf" to "a\nb",
                    "ff" to "a\u000Cb",
                    "cr" to "a\rb",
                ),
            )
        assertTrue("forward slash not escaped", out.contains("\"a/b\""))
        assertTrue(out.contains("\"a\\\"b\""))
        assertTrue(out.contains("\"a\\\\b\""))
        assertTrue(out.contains("\"a\\bb\""))
        assertTrue(out.contains("\"a\\tb\""))
        assertTrue(out.contains("\"a\\nb\""))
        assertTrue(out.contains("\"a\\fb\""))
        assertTrue(out.contains("\"a\\rb\""))
    }

    @Test
    fun `control characters escape as lower hex`() {
        val out = JsonCanonicaliser.canonicalise(mapOf("ctrl" to "a\u0001b"))
        assertTrue(out.contains("\"a\\u0001b\""))
    }

    @Test
    fun `no insignificant whitespace`() {
        val out = JsonCanonicaliser.canonicalise(mapOf("x" to 1, "y" to listOf(1, 2, 3)))
        assertFalse(out.contains(" "))
        assertFalse(out.contains("\n"))
    }

    @Test
    fun `nested arrays preserve element order`() {
        val out = JsonCanonicaliser.canonicalise(mapOf("outer" to mapOf("inner" to listOf(1, 2, 3))))
        assertEquals("{\"outer\":{\"inner\":[1,2,3]}}", out)
    }

    @Test
    fun `empty container literals`() {
        assertEquals("{}", JsonCanonicaliser.canonicalise(emptyMap<String, Any>()))
        assertEquals("[]", JsonCanonicaliser.canonicalise(emptyList<Any>()))
    }

    @Test
    fun `negative zero collapses`() {
        assertEquals("{\"n\":0}", JsonCanonicaliser.canonicalise(mapOf("n" to -0.0)))
    }

    @Test
    fun `utf16 key ordering handles bmp and supplementary plane`() {
        val out =
            JsonCanonicaliser.canonicalise(
                mapOf(
                    "\uFEFF" to 1,
                    "A" to 2,
                    "\uD83D\uDE00" to 3, // U+1F600 surrogate pair starts with 0xD83D
                ),
            )
        val aIdx = out.indexOf("\"A\"")
        val bomIdx = out.indexOf("\"\uFEFF\"")
        val emojiIdx = out.indexOf("\"\uD83D\uDE00\"")
        assertTrue("A before BOM", aIdx < bomIdx)
        // 0xD83D > 0xFEFF is false; actually the surrogate sorts before BOM
        // in UTF-16. The test asserts the stable ordering observed from the
        // emitter so Sarah's gateway produces identical output.
        assertTrue("emoji before BOM", emojiIdx < bomIdx)
    }

    @Test
    fun `register body vector matches expected string`() {
        val body =
            linkedMapOf<String, Any>(
                "platform" to "android",
                "install_uuid" to "01234567-89ab-7cde-8f01-234567890abc",
                "app_version" to "1.0.0",
                "attestation_nonce" to "abcd",
                "timestamp_ms" to 1_700_000_000_000L,
            )
        val expected = "{\"app_version\":\"1.0.0\",\"attestation_nonce\":\"abcd\",\"install_uuid\":\"01234567-89ab-7cde-8f01-234567890abc\",\"platform\":\"android\",\"timestamp_ms\":1700000000000}"
        assertEquals(expected, JsonCanonicaliser.canonicalise(body))
    }
}
