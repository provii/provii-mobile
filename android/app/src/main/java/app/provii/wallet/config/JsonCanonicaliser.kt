// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.config

/**
 * RFC 8785 JSON Canonicalisation Scheme.
 *
 * Sarah's gateway computes HMAC over the byte-exact canonical form defined
 * by RFC 8785, so the Kotlin client must emit identical output. Key rules:
 *
 *  - Object keys sorted by UTF-16 code-unit order.
 *  - No insignificant whitespace.
 *  - String escapes limited to the seven short forms from RFC 8785 section
 *    3.2.2.2 (plus `\uXXXX` lowercase hex for control points under 0x20).
 *    Forward slash is NOT escaped.
 *  - Integers render without a decimal point.
 *  - Booleans and null render as their literal tokens.
 *
 * Only the Kotlin/Java types used on the client side (`Number`, `Boolean`,
 * `String`, `null`, `List`, `Map<String, Any?>`) are handled. Unknown types
 * throw `JsonCanonicaliserException`.
 */
object JsonCanonicaliser {
    class JsonCanonicaliserException(message: String) : RuntimeException(message)

    fun canonicalise(value: Any?): String {
        val builder = StringBuilder()
        appendValue(value, builder)
        return builder.toString()
    }

    private fun appendValue(
        value: Any?,
        out: StringBuilder,
    ) {
        when (value) {
            null -> out.append("null")
            is Boolean -> out.append(if (value) "true" else "false")
            is Long, is Int, is Short, is Byte -> out.append(value.toString())
            is Double -> appendDouble(value, out)
            is Float -> appendDouble(value.toDouble(), out)
            is Number -> appendDouble(value.toDouble(), out)
            is String -> appendString(value, out)
            is Map<*, *> -> appendObject(value, out)
            is Iterable<*> -> appendArray(value, out)
            is Array<*> -> appendArray(value.toList(), out)
            else -> throw JsonCanonicaliserException("Unsupported type: ${value::class.java.name}")
        }
    }

    private fun appendObject(
        value: Map<*, *>,
        out: StringBuilder,
    ) {
        val entries =
            value.entries.map { (k, v) ->
                val key = k?.toString() ?: throw JsonCanonicaliserException("Null object key")
                key to v
            }.sortedWith(Utf16KeyComparator)
        out.append('{')
        for ((index, pair) in entries.withIndex()) {
            if (index > 0) out.append(',')
            appendString(pair.first, out)
            out.append(':')
            appendValue(pair.second, out)
        }
        out.append('}')
    }

    private fun appendArray(
        value: Iterable<*>,
        out: StringBuilder,
    ) {
        out.append('[')
        var first = true
        for (element in value) {
            if (!first) out.append(',')
            first = false
            appendValue(element, out)
        }
        out.append(']')
    }

    private fun appendDouble(
        value: Double,
        out: StringBuilder,
    ) {
        if (value.isNaN() || value.isInfinite()) {
            throw JsonCanonicaliserException("Non-finite number: $value")
        }
        if (value == 0.0) {
            out.append('0')
            return
        }
        if (value % 1.0 == 0.0 && Math.abs(value) < 1e16) {
            out.append(value.toLong().toString())
            return
        }
        out.append(value.toString())
    }

    private fun appendString(
        value: String,
        out: StringBuilder,
    ) {
        out.append('"')
        var i = 0
        while (i < value.length) {
            val c = value[i]
            when (c) {
                '\\' -> out.append("\\\\")
                '"' -> out.append("\\\"")
                '\b' -> out.append("\\b")
                '\t' -> out.append("\\t")
                '\n' -> out.append("\\n")
                '\u000C' -> out.append("\\f")
                '\r' -> out.append("\\r")
                else -> {
                    if (c.code < 0x20) {
                        out.append("\\u%04x".format(c.code))
                    } else {
                        out.append(c)
                    }
                }
            }
            i++
        }
        out.append('"')
    }

    /**
     * UTF-16 code-unit lexicographic comparator per RFC 8785 section 3.2.3.
     * Kotlin `String.compareTo` uses UTF-16 code units already, so this is a
     * thin wrapper. The explicit comparator keeps the ordering contract
     * visible in code and guards against future refactors.
     */
    internal object Utf16KeyComparator : Comparator<Pair<String, Any?>> {
        override fun compare(
            a: Pair<String, Any?>,
            b: Pair<String, Any?>,
        ): Int {
            val ak = a.first
            val bk = b.first
            val min = minOf(ak.length, bk.length)
            for (i in 0 until min) {
                val diff = ak[i].code - bk[i].code
                if (diff != 0) return diff
            }
            return ak.length - bk.length
        }
    }
}
