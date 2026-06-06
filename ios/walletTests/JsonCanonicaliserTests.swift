// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class JsonCanonicaliserTests: XCTestCase {

    // MARK: - Primitives

    func testCanonicaliseString() throws {
        let result = try JsonCanonicaliser.canonicalise("hello")
        XCTAssertEqual(result, "\"hello\"")
    }

    func testCanonicaliseStringWithEscapes() throws {
        let result = try JsonCanonicaliser.canonicalise("line\nnew\ttab\\back\"quote")
        XCTAssertEqual(result, "\"line\\nnew\\ttab\\\\back\\\"quote\"")
    }

    func testCanonicaliseControlCharacters() throws {
        // Control char U+0001 should be 
        let result = try JsonCanonicaliser.canonicalise("\u{01}")
        XCTAssertEqual(result, "\"\\u0001\"")
    }

    func testCanonicaliseInteger() throws {
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(42), "42")
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(0), "0")
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(-1), "-1")
    }

    func testCanonicaliseInt64() throws {
        let large: Int64 = 1_717_000_000
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(large), "1717000000")
    }

    func testCanonicaliseBool() throws {
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(true), "true")
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(false), "false")
    }

    func testCanonicaliseNull() throws {
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(NSNull()), "null")
    }

    // MARK: - Double edge cases

    func testCanonicaliseDoubleZero() throws {
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(0.0), "0")
    }

    func testCanonicaliseNegativeZero() throws {
        // RFC 8785: -0 renders as 0
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(-0.0), "0")
    }

    func testCanonicaliseNaNThrows() {
        XCTAssertThrowsError(try JsonCanonicaliser.canonicalise(Double.nan))
    }

    func testCanonicaliseInfinityThrows() {
        XCTAssertThrowsError(try JsonCanonicaliser.canonicalise(Double.infinity))
    }

    func testCanonicaliseIntegerDouble() throws {
        // 42.0 should render as "42" (no decimal point)
        XCTAssertEqual(try JsonCanonicaliser.canonicalise(42.0), "42")
    }

    // MARK: - Arrays

    func testCanonicaliseEmptyArray() throws {
        let result = try JsonCanonicaliser.canonicalise([] as [Any])
        XCTAssertEqual(result, "[]")
    }

    func testCanonicaliseArray() throws {
        let result = try JsonCanonicaliser.canonicalise([1, "two", true] as [Any])
        XCTAssertEqual(result, "[1,\"two\",true]")
    }

    // MARK: - Dictionaries (key sorting)

    func testCanonicaliseDictionaryKeySorting() throws {
        let dict: [String: Any] = ["b": 2, "a": 1, "c": 3]
        let result = try JsonCanonicaliser.canonicalise(dict)
        // Keys must be sorted by UTF-16 code unit order
        XCTAssertEqual(result, "{\"a\":1,\"b\":2,\"c\":3}")
    }

    func testCanonicaliseNestedDictionary() throws {
        let dict: [String: Any] = [
            "outer": ["inner": "value"] as [String: Any]
        ]
        let result = try JsonCanonicaliser.canonicalise(dict)
        XCTAssertEqual(result, "{\"outer\":{\"inner\":\"value\"}}")
    }

    func testCanonicaliseEmptyDictionary() throws {
        let result = try JsonCanonicaliser.canonicalise([:] as [String: Any])
        XCTAssertEqual(result, "{}")
    }

    // MARK: - No insignificant whitespace

    func testNoWhitespace() throws {
        let dict: [String: Any] = ["key": "value"]
        let result = try JsonCanonicaliser.canonicalise(dict)
        XCTAssertFalse(result.contains(" "), "Canonical JSON must have no insignificant whitespace")
        XCTAssertFalse(result.contains("\n"), "Canonical JSON must have no newlines")
    }
}
