// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.config

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Extended tests for [JsonCanonicaliser] covering RFC 8785 edge cases.
 */
class JsonCanonicaliserTest2 {
    @Test
    fun canonicaliseNull() {
        assertEquals("null", JsonCanonicaliser.canonicalise(null))
    }

    @Test
    fun canonicaliseBooleans() {
        assertEquals("true", JsonCanonicaliser.canonicalise(true))
        assertEquals("false", JsonCanonicaliser.canonicalise(false))
    }

    @Test
    fun canonicaliseIntegers() {
        assertEquals("0", JsonCanonicaliser.canonicalise(0))
        assertEquals("42", JsonCanonicaliser.canonicalise(42))
        assertEquals("-1", JsonCanonicaliser.canonicalise(-1))
        assertEquals("2147483647", JsonCanonicaliser.canonicalise(Int.MAX_VALUE))
    }

    @Test
    fun canonicaliseLong() {
        assertEquals("9999999999", JsonCanonicaliser.canonicalise(9999999999L))
    }

    @Test
    fun canonicaliseDoubleWholeNumberRendersWithoutDecimal() {
        assertEquals("1", JsonCanonicaliser.canonicalise(1.0))
        assertEquals("100", JsonCanonicaliser.canonicalise(100.0))
        assertEquals("-5", JsonCanonicaliser.canonicalise(-5.0))
    }

    @Test
    fun canonicaliseDoubleZeroRendersAsZero() {
        assertEquals("0", JsonCanonicaliser.canonicalise(0.0))
        assertEquals("0", JsonCanonicaliser.canonicalise(-0.0))
    }

    @Test
    fun canonicaliseDoubleWithFraction() {
        assertEquals("1.5", JsonCanonicaliser.canonicalise(1.5))
    }

    @Test(expected = JsonCanonicaliser.JsonCanonicaliserException::class)
    fun canonicaliseNaNThrows() {
        JsonCanonicaliser.canonicalise(Double.NaN)
    }

    @Test(expected = JsonCanonicaliser.JsonCanonicaliserException::class)
    fun canonicaliseInfinityThrows() {
        JsonCanonicaliser.canonicalise(Double.POSITIVE_INFINITY)
    }

    @Test
    fun canonicaliseString() {
        assertEquals("\"hello\"", JsonCanonicaliser.canonicalise("hello"))
    }

    @Test
    fun canonicaliseStringEscapesControlCharacters() {
        assertEquals("\"\\n\"", JsonCanonicaliser.canonicalise("\n"))
        assertEquals("\"\\r\"", JsonCanonicaliser.canonicalise("\r"))
        assertEquals("\"\\t\"", JsonCanonicaliser.canonicalise("\t"))
        assertEquals("\"\\b\"", JsonCanonicaliser.canonicalise("\b"))
        assertEquals("\"\\f\"", JsonCanonicaliser.canonicalise(""))
    }

    @Test
    fun canonicaliseStringEscapesBackslashAndQuote() {
        assertEquals("\"a\\\\b\"", JsonCanonicaliser.canonicalise("a\\b"))
        assertEquals("\"a\\\"b\"", JsonCanonicaliser.canonicalise("a\"b"))
    }

    @Test
    fun canonicaliseStringLowControlPoint() {
        // U+0001 -> 
        assertEquals("\"\\u0001\"", JsonCanonicaliser.canonicalise(""))
    }

    @Test
    fun canonicaliseStringForwardSlashNotEscaped() {
        assertEquals("\"/path/to\"", JsonCanonicaliser.canonicalise("/path/to"))
    }

    @Test
    fun canonicaliseEmptyList() {
        assertEquals("[]", JsonCanonicaliser.canonicalise(emptyList<Any>()))
    }

    @Test
    fun canonicaliseList() {
        assertEquals("[1,2,3]", JsonCanonicaliser.canonicalise(listOf(1, 2, 3)))
    }

    @Test
    fun canonicaliseNestedList() {
        assertEquals("[[1],2]", JsonCanonicaliser.canonicalise(listOf(listOf(1), 2)))
    }

    @Test
    fun canonicaliseEmptyMap() {
        assertEquals("{}", JsonCanonicaliser.canonicalise(emptyMap<String, Any>()))
    }

    @Test
    fun canonicaliseMapSortsByUtf16Keys() {
        val map = mapOf("b" to 2, "a" to 1)
        assertEquals("""{"a":1,"b":2}""", JsonCanonicaliser.canonicalise(map))
    }

    @Test
    fun canonicaliseMapWithMixedTypes() {
        val map = mapOf("str" to "hello", "num" to 42, "bool" to true, "nil" to null)
        val result = JsonCanonicaliser.canonicalise(map)
        assertEquals("""{"bool":true,"nil":null,"num":42,"str":"hello"}""", result)
    }

    @Test
    fun canonicaliseArray() {
        assertEquals("[1,2]", JsonCanonicaliser.canonicalise(arrayOf(1, 2)))
    }

    @Test
    fun canonicaliseFloatRenderedAsDouble() {
        assertEquals("1", JsonCanonicaliser.canonicalise(1.0f))
    }

    @Test
    fun canonicaliseShort() {
        assertEquals("42", JsonCanonicaliser.canonicalise(42.toShort()))
    }

    @Test
    fun canonicaliseByte() {
        assertEquals("7", JsonCanonicaliser.canonicalise(7.toByte()))
    }

    @Test(expected = JsonCanonicaliser.JsonCanonicaliserException::class)
    fun canonicaliseUnsupportedTypeThrows() {
        JsonCanonicaliser.canonicalise(Object())
    }

    @Test(expected = JsonCanonicaliser.JsonCanonicaliserException::class)
    fun canonicaliseNullKeyThrows() {
        val map = HashMap<String?, Any>()
        map[null] = "value"
        @Suppress("UNCHECKED_CAST")
        JsonCanonicaliser.canonicalise(map as Map<*, *>)
    }

    @Test
    fun utf16KeyComparatorSortsByCodeUnit() {
        val comparator = JsonCanonicaliser.Utf16KeyComparator
        val pairs = listOf("b" to 2, "a" to 1, "c" to 3).map { it.first to it.second as Any? }
        val sorted = pairs.sortedWith(comparator)
        assertEquals("a", sorted[0].first)
        assertEquals("b", sorted[1].first)
        assertEquals("c", sorted[2].first)
    }

    @Test
    fun utf16KeyComparatorHandlesPrefixOrdering() {
        val comparator = JsonCanonicaliser.Utf16KeyComparator
        val pairs = listOf("ab" to null, "a" to null)
        val sorted = pairs.sortedWith(comparator)
        assertEquals("a", sorted[0].first)
        assertEquals("ab", sorted[1].first)
    }
}
