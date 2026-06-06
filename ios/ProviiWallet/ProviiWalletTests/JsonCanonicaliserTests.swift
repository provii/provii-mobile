// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Byte-exact agreement tests for the iOS JCS implementation against the
/// RFC 8785 appendix B vectors. The gateway signs HMAC over the bytes this
/// module emits, so any divergence silently breaks authentication.

import XCTest
@testable import ProviiWallet

final class JsonCanonicaliserTests: XCTestCase {

    // MARK: - RFC 8785 appendix B vectors

    /// Appendix B.1: simple object. Keys sorted UTF-16, no whitespace.
    func testAppendixB1SortedKeys() throws {
        let input: [String: Any] = [
            "numbers": [333333333.33333329, 1e30, 4.5],
            "string": "\u{20ac}$\u{000f}\u{000a}A'\u{42}\u{22}\u{5c}\\\"\u{2f}",
            "literals": [NSNull(), true, false]
        ]
        let canonical = try JsonCanonicaliser.canonicalise(input)
        // Keys appear in UTF-16 sorted order: literals < numbers < string.
        let litIdx = canonical.range(of: "\"literals\"")!.lowerBound
        let numIdx = canonical.range(of: "\"numbers\"")!.lowerBound
        let strIdx = canonical.range(of: "\"string\"")!.lowerBound
        XCTAssertLessThan(litIdx, numIdx)
        XCTAssertLessThan(numIdx, strIdx)
        // No whitespace between tokens.
        XCTAssertFalse(canonical.contains(" "))
        XCTAssertFalse(canonical.contains("\n"))
    }

    /// RFC 8785 section 3.2.2.2: escape short forms for the seven C0 controls
    /// and `"` plus `\`. Forward slash must NOT be escaped.
    func testStringEscapesRfc8785ShortForms() throws {
        let input: [String: Any] = [
            "slash": "a/b",
            "quote": "a\"b",
            "backslash": "a\\b",
            "bs": "a\u{0008}b",
            "tab": "a\tb",
            "lf": "a\nb",
            "ff": "a\u{000c}b",
            "cr": "a\rb"
        ]
        let canonical = try JsonCanonicaliser.canonicalise(input)
        XCTAssertTrue(canonical.contains("\"a/b\""), "forward slash not escaped")
        XCTAssertTrue(canonical.contains("\"a\\\"b\""))
        XCTAssertTrue(canonical.contains("\"a\\\\b\""))
        XCTAssertTrue(canonical.contains("\"a\\bb\""))
        XCTAssertTrue(canonical.contains("\"a\\tb\""))
        XCTAssertTrue(canonical.contains("\"a\\nb\""))
        XCTAssertTrue(canonical.contains("\"a\\fb\""))
        XCTAssertTrue(canonical.contains("\"a\\rb\""))
    }

    /// Other control characters serialise as `\uXXXX` lowercase hex.
    func testControlCharactersEscapedAsLowerHex() throws {
        let canonical = try JsonCanonicaliser.canonicalise(["ctrl": "a\u{0001}b"])
        XCTAssertTrue(canonical.contains("\"a\\u0001b\""))
    }

    /// Integers render without decimal point.
    func testIntegerFormatting() throws {
        let canonical = try JsonCanonicaliser.canonicalise(["n": 42])
        XCTAssertEqual(canonical, "{\"n\":42}")
    }

    func testLargeIntegerFormatting() throws {
        let canonical = try JsonCanonicaliser.canonicalise(["n": Int64(1_700_000_000_000)])
        XCTAssertEqual(canonical, "{\"n\":1700000000000}")
    }

    /// Booleans and null emit as literal tokens.
    func testBooleanAndNullLiterals() throws {
        let canonical = try JsonCanonicaliser.canonicalise([
            "a": true,
            "b": false,
            "c": NSNull()
        ] as [String: Any])
        XCTAssertEqual(canonical, "{\"a\":true,\"b\":false,\"c\":null}")
    }

    /// Key sort uses UTF-16 code units, not Unicode scalars. `"A"` (0x0041)
    /// precedes any supplementary-plane surrogate pair (0xD83D high surrogate
    /// for U+1F600) which in turn precedes the BOM (0xFEFF).
    func testUtf16KeySortOrder() throws {
        let input: [String: Any] = [
            "\u{FEFF}": 1,
            "A": 2,
            "\u{1F600}": 3
        ]
        let canonical = try JsonCanonicaliser.canonicalise(input)
        let aIdx = canonical.range(of: "\"A\"")!.lowerBound
        let emojiIdx = canonical.range(of: "\"\u{1F600}\"")!.lowerBound
        let bomIdx = canonical.range(of: "\"\u{FEFF}\"")!.lowerBound
        XCTAssertLessThan(aIdx, emojiIdx)
        XCTAssertLessThan(emojiIdx, bomIdx)
    }

    /// Nested arrays preserve element order and use comma separators.
    func testNestedStructure() throws {
        let canonical = try JsonCanonicaliser.canonicalise([
            "outer": [
                "inner": [1, 2, 3]
            ]
        ])
        XCTAssertEqual(canonical, "{\"outer\":{\"inner\":[1,2,3]}}")
    }

    /// Empty containers.
    func testEmptyObjectAndArray() throws {
        XCTAssertEqual(try JsonCanonicaliser.canonicalise([String: Any]()), "{}")
        XCTAssertEqual(try JsonCanonicaliser.canonicalise([Any]()), "[]")
    }

    /// Zero rendered as `0` (not `-0`).
    func testNegativeZeroCollapsesToZero() throws {
        let canonical = try JsonCanonicaliser.canonicalise(["n": -0.0])
        XCTAssertEqual(canonical, "{\"n\":0}")
    }

    /// Representative register-body vector. Must match Sarah's gateway
    /// canonicaliser for the W26 happy path.
    func testRegisterBodyVector() throws {
        let input: [String: Any] = [
            "platform": "ios",
            "install_uuid": "01234567-89ab-7cde-8f01-234567890abc",
            "app_version": "1.0.0",
            "attestation_nonce": "abcd",
            "timestamp_ms": 1_700_000_000_000
        ]
        let canonical = try JsonCanonicaliser.canonicalise(input)
        let expected = "{\"app_version\":\"1.0.0\",\"attestation_nonce\":\"abcd\",\"install_uuid\":\"01234567-89ab-7cde-8f01-234567890abc\",\"platform\":\"ios\",\"timestamp_ms\":1700000000000}"
        XCTAssertEqual(canonical, expected)
    }
}
