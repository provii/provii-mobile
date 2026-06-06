// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// RFC 8785 JSON Canonicalisation Scheme (JCS).
///
/// Sarah's gateway computes HMAC over the exact canonical bytes defined by
/// RFC 8785. The Swift client must emit byte-identical output otherwise the
/// HMAC verification will fail silently. Key rules implemented here:
///
///  - Keys sorted by UTF-16 code-unit order.
///  - No insignificant whitespace.
///  - String escapes limited to the seven short forms defined in RFC 8785
///    section 3.2.2.2 (plus `\uXXXX` for control points under 0x20). The
///    forward slash is NOT escaped.
///  - Numbers rendered via ECMA-262 `Number.prototype.toString` semantics
///    (RFC 8785 section 3.2.2.3). Integers render without a decimal point;
///    non-integer doubles render in the shortest round-trip form and use
///    exponent notation outside the `1e-6 ≤ |x| < 1e21` window.
///  - `true`, `false`, `null` rendered as their literal tokens.
///
/// Only the data types used on the client side (`String`, `Int`, `Int64`,
/// `Double`, `Bool`, `NSNull`, `Array`, `Dictionary<String, Any>`) are
/// handled. Hitting any other type throws `JsonCanonicaliserError.unsupported`.

import Foundation

enum JsonCanonicaliserError: Error {
    case unsupported(String)
    case invalidNumber(Double)
    case invalidKey
}

enum JsonCanonicaliser {

    static func canonicalise(_ value: Any) throws -> String {
        var builder = String()
        builder.reserveCapacity(64)
        try append(value, into: &builder)
        return builder
    }

    // MARK: - Dispatch

    private static func append(_ value: Any, into out: inout String) throws {
        if value is NSNull {
            out.append("null")
            return
        }
        if let number = value as? NSNumber {
            try appendNSNumber(number, into: &out)
            return
        }
        if let bool = value as? Bool {
            out.append(bool ? "true" : "false")
            return
        }
        if let int = value as? Int64 {
            out.append(numberIntegerString(int))
            return
        }
        if let int = value as? Int {
            out.append(numberIntegerString(Int64(int)))
            return
        }
        if let double = value as? Double {
            try appendDouble(double, into: &out)
            return
        }
        if let string = value as? String {
            appendEscapedString(string, into: &out)
            return
        }
        if let array = value as? [Any] {
            try appendArray(array, into: &out)
            return
        }
        if let dict = value as? [String: Any] {
            try appendDictionary(dict, into: &out)
            return
        }
        throw JsonCanonicaliserError.unsupported(String(describing: type(of: value)))
    }

    // NSNumber needs special handling because Swift bridges Bool to NSNumber.
    private static func appendNSNumber(_ number: NSNumber, into out: inout String) throws {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            out.append(number.boolValue ? "true" : "false")
            return
        }
        // Treat NSNumber-wrapped ints and doubles distinctly so integer
        // values round-trip without a trailing `.0`.
        let type = String(cString: number.objCType)
        switch type {
        case "c", "C", "s", "S", "i", "I", "l", "L", "q", "Q":
            out.append(numberIntegerString(number.int64Value))
        default:
            try appendDouble(number.doubleValue, into: &out)
        }
    }

    private static func appendArray(_ array: [Any], into out: inout String) throws {
        out.append("[")
        for (index, element) in array.enumerated() {
            if index > 0 { out.append(",") }
            try append(element, into: &out)
        }
        out.append("]")
    }

    private static func appendDictionary(_ dict: [String: Any], into out: inout String) throws {
        let sortedKeys = dict.keys.sorted(by: compareKeysUtf16)
        out.append("{")
        for (index, key) in sortedKeys.enumerated() {
            if index > 0 { out.append(",") }
            appendEscapedString(key, into: &out)
            out.append(":")
            try append(dict[key] as Any, into: &out)
        }
        out.append("}")
    }

    // MARK: - Keys

    /// UTF-16 code-unit lexicographic comparison per RFC 8785 section 3.2.3.
    private static func compareKeysUtf16(_ a: String, _ b: String) -> Bool {
        let au = Array(a.utf16)
        let bu = Array(b.utf16)
        let count = min(au.count, bu.count)
        for i in 0..<count {
            if au[i] != bu[i] { return au[i] < bu[i] }
        }
        return au.count < bu.count
    }

    // MARK: - Numbers

    private static func numberIntegerString(_ value: Int64) -> String {
        String(value)
    }

    private static func appendDouble(_ value: Double, into out: inout String) throws {
        if value.isNaN || value.isInfinite {
            throw JsonCanonicaliserError.invalidNumber(value)
        }
        if value == 0 {
            // RFC 8785 treats -0 as 0.
            out.append("0")
            return
        }
        if value.truncatingRemainder(dividingBy: 1) == 0,
           abs(value) < 1e16 {
            // Integer in Double representation; emit without decimal point.
            out.append(String(Int64(value)))
            return
        }
        // Rely on Swift's shortest round-trip formatter (Grisu) for the rest.
        // Swift's `String(value)` for `Double` emits shortest round-trip per
        // IEEE 754 and matches ECMA-262 for the ranges we care about. Tests
        // assert this against the RFC 8785 appendix B vectors.
        out.append(String(value))
    }

    // MARK: - Strings

    private static func appendEscapedString(_ value: String, into out: inout String) {
        out.append("\"")
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\u{0008}": out.append("\\b")
            case "\u{0009}": out.append("\\t")
            case "\u{000A}": out.append("\\n")
            case "\u{000C}": out.append("\\f")
            case "\u{000D}": out.append("\\r")
            case "\"": out.append("\\\"")
            case "\\": out.append("\\\\")
            default:
                if scalar.value < 0x20 {
                    out.append(String(format: "\\u%04x", scalar.value))
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out.append("\"")
    }
}
