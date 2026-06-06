// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

/// Unit tests for HmacSigner's individual methods. The full golden-vector
/// cross-platform parity tests live in ProviiWalletTests/HmacSignerTests.swift;
/// these tests exercise every public method signature with inline known-answer
/// values to drive coverage without requiring the shared vector file.
final class HmacSignerUnitTests: XCTestCase {

    private let testSecret = Data([
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20
    ])

    // MARK: - hmacSha256Hex

    func testHmacSha256HexProducesLowercaseHex() throws {
        let result = try HmacSigner.hmacSha256Hex(secret: testSecret, data: "test")
        XCTAssertEqual(result.count, 64, "HMAC-SHA256 hex must be 64 characters")
        let hexPattern = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        XCTAssertNotNil(hexPattern.firstMatch(in: result, range: range), "Must be lowercase hex")
    }

    func testHmacSha256HexDeterministic() throws {
        let a = try HmacSigner.hmacSha256Hex(secret: testSecret, data: "hello")
        let b = try HmacSigner.hmacSha256Hex(secret: testSecret, data: "hello")
        XCTAssertEqual(a, b, "Same secret and data must produce identical HMAC")
    }

    func testHmacSha256HexDifferentDataProducesDifferentOutput() throws {
        let a = try HmacSigner.hmacSha256Hex(secret: testSecret, data: "data1")
        let b = try HmacSigner.hmacSha256Hex(secret: testSecret, data: "data2")
        XCTAssertNotEqual(a, b, "Different data must produce different HMAC")
    }

    // MARK: - canonicalMessage

    func testCanonicalMessageFormat() {
        let result = HmacSigner.canonicalMessage(
            ts: 1717000000,
            method: "post",
            path: "/v1/test",
            jsonWithoutHmac: "{\"key\":\"value\"}",
            nonce: "abc123"
        )
        // Method is uppercased
        XCTAssertEqual(result, "1717000000:POST:/v1/test:{\"key\":\"value\"}:abc123")
    }

    func testCanonicalMessageUppercasesMethod() {
        let result = HmacSigner.canonicalMessage(
            ts: 0, method: "get", path: "/", jsonWithoutHmac: "{}", nonce: "n"
        )
        XCTAssertTrue(result.contains(":GET:"), "Method must be uppercased")
    }

    // MARK: - canonicalStartJson

    func testCanonicalStartJsonFieldOrder() {
        let result = HmacSigner.canonicalStartJson(params: HmacSigner.StartJsonParams(
            actor: "officer-1",
            format: "hmac-sha256",
            keyId: "key-1",
            ts: 1717000000,
            schema: "age_v1",
            validityDays: 365,
            kid: "kid-1"
        ))
        // Must use "key_id" (snake_case), not "keyId"
        XCTAssertTrue(result.contains("\"key_id\""), "Must use snake_case key_id")
        XCTAssertFalse(result.contains("\"keyId\""), "Must not use camelCase keyId")
        // Must start with actor
        XCTAssertTrue(result.hasPrefix("{\"actor\":"), "Must start with actor field")
    }

    func testCanonicalStartJsonNullOptionals() {
        let result = HmacSigner.canonicalStartJson(params: HmacSigner.StartJsonParams(
            actor: "a",
            format: "f",
            keyId: "k",
            ts: 0,
            schema: nil,
            validityDays: nil,
            kid: nil
        ))
        XCTAssertTrue(result.contains("\"schema\":null"), "nil schema must render as null")
        XCTAssertTrue(result.contains("\"validity_days\":null"), "nil validityDays must render as null")
        XCTAssertTrue(result.contains("\"kid\":null"), "nil kid must render as null")
    }

    // MARK: - canonicalSignJson

    func testCanonicalSignJsonFieldOrder() {
        let result = HmacSigner.canonicalSignJson(
            sessionId: "sess-1",
            commitmentB64: "Y29tbWl0bWVudA",
            format: "hmac-sha256",
            keyId: "key-1",
            ts: 1717000000
        )
        XCTAssertTrue(result.hasPrefix("{\"session_id\":"), "Must start with session_id")
        XCTAssertTrue(result.contains("\"key_id\""), "Must use snake_case key_id")
    }

    // MARK: - canonicalAttestationJson

    func testCanonicalAttestationJsonFieldOrder() {
        let result = HmacSigner.canonicalAttestationJson(
            dobDays: 12345,
            format: "hmac-sha256",
            keyId: "key-1",
            ts: 1717000000
        )
        XCTAssertTrue(result.hasPrefix("{\"dob_days\":12345"), "Must start with dob_days")
        XCTAssertTrue(result.contains("\"key_id\""), "Must use snake_case key_id")
    }

    // MARK: - buildAuthorizerJson

    func testBuildAuthorizerJsonUseCamelCase() {
        let result = HmacSigner.buildAuthorizerJson(
            format: "hmac-sha256",
            keyId: "key-1",
            timestamp: 1717000000,
            hmac: "abcdef",
            nonce: "nonce-1"
        )
        // API request uses camelCase "keyId"
        XCTAssertTrue(result.contains("\"keyId\":"), "Must use camelCase keyId for API")
        XCTAssertFalse(result.contains("\"key_id\":"), "Must not use snake_case for API")
    }

    func testBuildAuthorizerJsonWithChallengeId() {
        let result = HmacSigner.buildAuthorizerJson(
            format: "f",
            keyId: "k",
            timestamp: 0,
            hmac: "h",
            nonce: "n",
            challengeId: "ch-1"
        )
        XCTAssertTrue(result.contains("\"challengeId\":\"ch-1\""), "Must include challengeId when provided")
    }

    func testBuildAuthorizerJsonWithoutChallengeId() {
        let result = HmacSigner.buildAuthorizerJson(
            format: "f",
            keyId: "k",
            timestamp: 0,
            hmac: "h",
            nonce: "n"
        )
        XCTAssertFalse(result.contains("challengeId"), "Must not include challengeId when nil")
    }

    // MARK: - generateNonce

    func testGenerateNonce64HexChars() throws {
        let nonce = try HmacSigner.generateNonce()
        XCTAssertEqual(nonce.count, 64)
    }

    func testGenerateNonceUnique() throws {
        let a = try HmacSigner.generateNonce()
        let b = try HmacSigner.generateNonce()
        XCTAssertNotEqual(a, b)
    }

    // MARK: - JSON escape (exercised via canonicalStartJson)

    func testJsonEscapeSpecialCharacters() {
        // Inject special chars into the actor field to exercise jsonEscape
        let result = HmacSigner.canonicalStartJson(params: HmacSigner.StartJsonParams(
            actor: "line\nnew\ttab\\back\"quote\r\u{08}\u{0C}",
            format: "f",
            keyId: "k",
            ts: 0,
            schema: nil,
            validityDays: nil,
            kid: nil
        ))
        XCTAssertTrue(result.contains("\\n"), "Newline must be escaped")
        XCTAssertTrue(result.contains("\\t"), "Tab must be escaped")
        XCTAssertTrue(result.contains("\\\\"), "Backslash must be escaped")
        XCTAssertTrue(result.contains("\\\""), "Quote must be escaped")
        XCTAssertTrue(result.contains("\\r"), "CR must be escaped")
        XCTAssertTrue(result.contains("\\b"), "BS must be escaped")
        XCTAssertTrue(result.contains("\\f"), "FF must be escaped")
    }

    // MARK: - createStartAuthorizer

    func testCreateStartAuthorizerReturnsValidJSON() throws {
        let (authorizer, timestamp) = try HmacSigner.createStartAuthorizer(
            secret: testSecret,
            actor: "officer-1",
            format: "hmac-sha256",
            keyId: "key-1",
            schema: "age_v1",
            validityDays: 365,
            kid: "kid-1"
        )
        XCTAssertFalse(authorizer.isEmpty, "Authorizer JSON must not be empty")
        XCTAssertTrue(authorizer.contains("\"hmac\":"), "Must contain HMAC field")
        XCTAssertTrue(authorizer.contains("\"nonce\":"), "Must contain nonce field")
        XCTAssertTrue(authorizer.contains("\"keyId\":"), "Must use camelCase keyId")
        XCTAssertGreaterThan(timestamp, 0, "Timestamp must be positive")
    }

    func testCreateStartAuthorizerWithNilOptionals() throws {
        let (authorizer, _) = try HmacSigner.createStartAuthorizer(
            secret: testSecret,
            actor: "a",
            format: "f",
            keyId: "k"
        )
        XCTAssertFalse(authorizer.isEmpty)
    }

    // MARK: - createAttestationAuthorizer

    func testCreateAttestationAuthorizerReturnsValidJSON() throws {
        let (authorizer, timestamp) = try HmacSigner.createAttestationAuthorizer(
            secret: testSecret,
            dobDays: 12345,
            format: "hmac-sha256",
            keyId: "key-1"
        )
        XCTAssertFalse(authorizer.isEmpty)
        XCTAssertTrue(authorizer.contains("\"hmac\":"))
        XCTAssertTrue(authorizer.contains("\"nonce\":"))
        XCTAssertGreaterThan(timestamp, 0)
    }

    // MARK: - hex helper (via hmacSha256Hex)

    func testHmacSha256HexEmptyData() throws {
        let result = try HmacSigner.hmacSha256Hex(secret: testSecret, data: "")
        XCTAssertEqual(result.count, 64)
    }

    // MARK: - jsonEscape edge cases

    func testJsonEscapeControlChars() {
        // U+0001 should be escaped as 
        let result = HmacSigner.canonicalStartJson(params: HmacSigner.StartJsonParams(
            actor: "\u{01}",
            format: "f",
            keyId: "k",
            ts: 0,
            schema: nil,
            validityDays: nil,
            kid: nil
        ))
        XCTAssertTrue(result.contains("\\u0001"), "Control char U+0001 must be \\u0001")
    }
}
