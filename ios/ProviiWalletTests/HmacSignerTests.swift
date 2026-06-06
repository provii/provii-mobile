// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

/// Golden vector tests for HmacSigner. Each test loads expected output from
/// shared/test-vectors/hmac_signer_vectors.json and asserts byte-exact
/// agreement. Any divergence from these vectors means the HMAC will not
/// match the provii-issuer and authentication will fail.
///
/// The same vectors are consumed by the Android HmacSignerTest, guaranteeing
/// cross-platform parity.
final class HmacSignerTests: XCTestCase {

    // MARK: - Test Vector Loading

    private struct Vectors: Decodable {
        let secret_hex: String
        let hmac_sha256_hex: [HmacVector]
        let canonicalStartJson: [StartVector]
        let canonicalSignJson: [SignVector]
        let canonicalAttestationJson: [AttestationVector]
        let canonicalMessage: [MessageVector]
        let buildAuthorizerJson: [AuthorizerVector]
        let endToEnd: [EndToEndVector]
    }

    private struct HmacVector: Decodable {
        let id: String
        let data: String
        let expected: String
    }

    private struct StartVector: Decodable {
        let id: String
        let actor: String
        let format: String
        let keyId: String
        let ts: Int64
        let schema: String?
        let validityDays: Int?
        let kid: String?
        let expected: String
    }

    private struct SignVector: Decodable {
        let id: String
        let sessionId: String
        let commitmentB64: String
        let format: String
        let keyId: String
        let ts: Int64
        let expected: String
    }

    private struct AttestationVector: Decodable {
        let id: String
        let dobDays: Int32
        let format: String
        let keyId: String
        let ts: Int64
        let expected: String
    }

    private struct MessageVector: Decodable {
        let id: String
        let ts: Int64
        let method: String
        let path: String
        let jsonWithoutHmac: String
        let nonce: String
        let expected: String
    }

    private struct AuthorizerVector: Decodable {
        let id: String
        let format: String
        let keyId: String
        let timestamp: Int64
        let hmac: String
        let nonce: String
        let expected: String
    }

    private struct EndToEndVector: Decodable {
        let id: String
        let endpoint: String
        let method: String
        let ts: Int64
        let nonce: String
        let params: EndToEndParams
        let expectedCanonicalJson: String
        let expectedCanonicalMessage: String
        let expectedHmac: String
        let expectedAuthorizerJson: String
    }

    private struct EndToEndParams: Decodable {
        let actor: String?
        let dobDays: Int32?
        let format: String
        let keyId: String
        let schema: String?
        let validityDays: Int?
        let kid: String?
    }

    private lazy var vectors: Vectors = {
        // Walk up from the test bundle to find shared/test-vectors/
        // The vectors file is at the repo root under shared/test-vectors/
        let repoRoot = findRepoRoot()
        let url = repoRoot.appendingPathComponent("shared/test-vectors/hmac_signer_vectors.json")
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load hmac_signer_vectors.json from \(url.path)")
        }
        guard let decoded = try? JSONDecoder().decode(Vectors.self, from: data) else {
            fatalError("Could not decode hmac_signer_vectors.json")
        }
        return decoded
    }()

    private lazy var secret: Data = {
        hexToData(vectors.secret_hex)
    }()

    /// Walk up from the current file to find the repo root (directory containing ios/ and shared/).
    private func findRepoRoot() -> URL {
        // Try common locations for the repo root
        let fileManager = FileManager.default

        // Option 1: relative to the source file location via #filePath
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("shared/test-vectors/hmac_signer_vectors.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }

        // Option 2: check if the test bundle has a reference to the file
        if let bundlePath = Bundle(for: type(of: self)).path(forResource: "hmac_signer_vectors", ofType: "json") {
            return URL(fileURLWithPath: bundlePath).deletingLastPathComponent()
        }

        fatalError("Could not find repo root containing shared/test-vectors/hmac_signer_vectors.json")
    }

    private func hexToData(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                fatalError("Invalid hex character in '\(byteString)'")
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    // MARK: - hmacSha256Hex Tests

    func testHmacSha256HexMatchesGoldenVectors() {
        for vector in vectors.hmac_sha256_hex {
            let actual = HmacSigner.hmacSha256Hex(secret: secret, data: vector.data)
            XCTAssertEqual(actual, vector.expected, "hmacSha256Hex vector '\(vector.id)' mismatch")
        }
    }

    // MARK: - canonicalStartJson Tests

    func testCanonicalStartJsonMatchesGoldenVectors() {
        for vector in vectors.canonicalStartJson {
            let actual = HmacSigner.canonicalStartJson(params: HmacSigner.StartJsonParams(
                actor: vector.actor,
                format: vector.format,
                keyId: vector.keyId,
                ts: vector.ts,
                schema: vector.schema,
                validityDays: vector.validityDays,
                kid: vector.kid
            ))
            XCTAssertEqual(actual, vector.expected, "canonicalStartJson vector '\(vector.id)' mismatch")
        }
    }

    // MARK: - canonicalSignJson Tests

    func testCanonicalSignJsonMatchesGoldenVectors() {
        for vector in vectors.canonicalSignJson {
            let actual = HmacSigner.canonicalSignJson(
                sessionId: vector.sessionId,
                commitmentB64: vector.commitmentB64,
                format: vector.format,
                keyId: vector.keyId,
                ts: vector.ts
            )
            XCTAssertEqual(actual, vector.expected, "canonicalSignJson vector '\(vector.id)' mismatch")
        }
    }

    // MARK: - canonicalAttestationJson Tests

    func testCanonicalAttestationJsonMatchesGoldenVectors() {
        for vector in vectors.canonicalAttestationJson {
            let actual = HmacSigner.canonicalAttestationJson(
                dobDays: vector.dobDays,
                format: vector.format,
                keyId: vector.keyId,
                ts: vector.ts
            )
            XCTAssertEqual(actual, vector.expected, "canonicalAttestationJson vector '\(vector.id)' mismatch")
        }
    }

    // MARK: - canonicalMessage Tests

    func testCanonicalMessageMatchesGoldenVectors() {
        for vector in vectors.canonicalMessage {
            let actual = HmacSigner.canonicalMessage(
                ts: vector.ts,
                method: vector.method,
                path: vector.path,
                jsonWithoutHmac: vector.jsonWithoutHmac,
                nonce: vector.nonce
            )
            XCTAssertEqual(actual, vector.expected, "canonicalMessage vector '\(vector.id)' mismatch")
        }
    }

    // MARK: - buildAuthorizerJson Tests

    func testBuildAuthorizerJsonMatchesGoldenVectors() {
        for vector in vectors.buildAuthorizerJson {
            let actual = HmacSigner.buildAuthorizerJson(
                format: vector.format,
                keyId: vector.keyId,
                timestamp: vector.timestamp,
                hmac: vector.hmac,
                nonce: vector.nonce
            )
            XCTAssertEqual(actual, vector.expected, "buildAuthorizerJson vector '\(vector.id)' mismatch")
        }
    }

    // MARK: - End-to-End Tests

    func testEndToEndAttestationFlowMatchesGoldenVector() {
        guard let vector = vectors.endToEnd.first(where: { $0.id == "attestation_full_flow" }) else {
            XCTFail("attestation_full_flow vector not found")
            return
        }

        let canonJson = HmacSigner.canonicalAttestationJson(
            dobDays: vector.params.dobDays!,
            format: vector.params.format,
            keyId: vector.params.keyId,
            ts: vector.ts
        )
        XCTAssertEqual(canonJson, vector.expectedCanonicalJson, "E2E attestation: canonical JSON mismatch")

        let canonMsg = HmacSigner.canonicalMessage(
            ts: vector.ts,
            method: vector.method,
            path: vector.endpoint,
            jsonWithoutHmac: canonJson,
            nonce: vector.nonce
        )
        XCTAssertEqual(canonMsg, vector.expectedCanonicalMessage, "E2E attestation: canonical message mismatch")

        let hmac = HmacSigner.hmacSha256Hex(secret: secret, data: canonMsg)
        XCTAssertEqual(hmac, vector.expectedHmac, "E2E attestation: HMAC mismatch")

        let authJson = HmacSigner.buildAuthorizerJson(
            format: vector.params.format,
            keyId: vector.params.keyId,
            timestamp: vector.ts,
            hmac: hmac,
            nonce: vector.nonce
        )
        XCTAssertEqual(authJson, vector.expectedAuthorizerJson, "E2E attestation: authoriser JSON mismatch")
    }

    func testEndToEndIssuanceStartFlowMatchesGoldenVector() {
        guard let vector = vectors.endToEnd.first(where: { $0.id == "issuance_start_full_flow" }) else {
            XCTFail("issuance_start_full_flow vector not found")
            return
        }

        let canonJson = HmacSigner.canonicalStartJson(params: HmacSigner.StartJsonParams(
            actor: vector.params.actor!,
            format: vector.params.format,
            keyId: vector.params.keyId,
            ts: vector.ts,
            schema: vector.params.schema,
            validityDays: vector.params.validityDays,
            kid: vector.params.kid
        ))
        XCTAssertEqual(canonJson, vector.expectedCanonicalJson, "E2E start: canonical JSON mismatch")

        let canonMsg = HmacSigner.canonicalMessage(
            ts: vector.ts,
            method: vector.method,
            path: vector.endpoint,
            jsonWithoutHmac: canonJson,
            nonce: vector.nonce
        )
        XCTAssertEqual(canonMsg, vector.expectedCanonicalMessage, "E2E start: canonical message mismatch")

        let hmac = HmacSigner.hmacSha256Hex(secret: secret, data: canonMsg)
        XCTAssertEqual(hmac, vector.expectedHmac, "E2E start: HMAC mismatch")

        let authJson = HmacSigner.buildAuthorizerJson(
            format: vector.params.format,
            keyId: vector.params.keyId,
            timestamp: vector.ts,
            hmac: hmac,
            nonce: vector.nonce
        )
        XCTAssertEqual(authJson, vector.expectedAuthorizerJson, "E2E start: authoriser JSON mismatch")
    }

    // MARK: - Nonce Generation Tests

    func testGenerateNonceReturns64HexChars() throws {
        let nonce = try HmacSigner.generateNonce()
        XCTAssertEqual(nonce.count, 64, "Nonce must be 64 hex characters")
        let hexPattern = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let range = NSRange(nonce.startIndex..<nonce.endIndex, in: nonce)
        XCTAssertNotNil(hexPattern.firstMatch(in: nonce, range: range), "Nonce must be lowercase hex")
    }

    func testGenerateNonceReturnsUniqueValues() throws {
        var nonces = Set<String>()
        for _ in 0..<100 {
            nonces.insert(try HmacSigner.generateNonce())
        }
        XCTAssertEqual(nonces.count, 100, "100 nonces should all be unique")
    }
}
