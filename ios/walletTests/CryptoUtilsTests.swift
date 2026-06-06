// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class CryptoUtilsTests: XCTestCase {

    // MARK: - Base64URL Encoding

    func testBase64UrlEncodeEmpty() {
        let result = CryptoUtils.b64UrlEncode(Data())
        XCTAssertEqual(result, "", "Empty data must encode to empty string")
    }

    func testBase64UrlEncodeKnownVector() {
        // "Hello" in base64 = "SGVsbG8=", base64url = "SGVsbG8"
        let data = Data("Hello".utf8)
        let result = CryptoUtils.b64UrlEncode(data)
        XCTAssertFalse(result.contains("+"), "base64url must not contain +")
        XCTAssertFalse(result.contains("/"), "base64url must not contain /")
        XCTAssertFalse(result.contains("="), "base64url must not contain padding")
        XCTAssertEqual(result, "SGVsbG8")
    }

    func testBase64UrlRoundTrip() throws {
        let original = Data([0x00, 0xFF, 0x3E, 0x3F, 0xFB, 0xFC])
        let encoded = CryptoUtils.b64UrlEncode(original)
        let decoded = try CryptoUtils.b64UrlDecode(encoded)
        XCTAssertEqual(decoded, original, "base64url round-trip must preserve bytes")
    }

    func testBase64UrlDecodeInvalidCharacters() {
        XCTAssertThrowsError(try CryptoUtils.b64UrlDecode("not valid!!!")) { error in
            XCTAssertTrue(error is CryptoError, "Invalid base64 must throw CryptoError")
        }
    }

    func testBase64UrlDecodePaddingVariants() throws {
        // Base64url without padding for 1-byte, 2-byte remainder cases
        let oneByte = CryptoUtils.b64UrlEncode(Data([0xAA]))
        let twoByte = CryptoUtils.b64UrlEncode(Data([0xAA, 0xBB]))
        let threeByte = CryptoUtils.b64UrlEncode(Data([0xAA, 0xBB, 0xCC]))

        XCTAssertEqual(try CryptoUtils.b64UrlDecode(oneByte), Data([0xAA]))
        XCTAssertEqual(try CryptoUtils.b64UrlDecode(twoByte), Data([0xAA, 0xBB]))
        XCTAssertEqual(try CryptoUtils.b64UrlDecode(threeByte), Data([0xAA, 0xBB, 0xCC]))
    }

    // MARK: - AES-GCM

    func testAesGcmEncryptDecryptRoundTrip() throws {
        let key = try CryptoUtils.randomKey32()
        let plaintext = Data("This is sensitive data for testing".utf8)

        let ciphertext = try CryptoUtils.encryptAesGcm(plaintext: plaintext, key: key)
        let holder = try CryptoUtils.decryptAesGcm(ivPlusCt: ciphertext, key: key)
        defer { holder.close() }

        XCTAssertEqual(holder.data, plaintext, "Decrypted plaintext must match original")
    }

    func testAesGcmRejectsWrongKey() throws {
        let key1 = try CryptoUtils.randomKey32()
        let key2 = try CryptoUtils.randomKey32()
        let plaintext = Data("secret".utf8)

        let ciphertext = try CryptoUtils.encryptAesGcm(plaintext: plaintext, key: key1)

        XCTAssertThrowsError(try CryptoUtils.decryptAesGcm(ivPlusCt: ciphertext, key: key2),
                             "Decrypting with wrong key must throw")
    }

    func testAesGcmRejectsInvalidKeySize() {
        let shortKey = Data([0x01, 0x02, 0x03])
        let plaintext = Data("test".utf8)

        XCTAssertThrowsError(try CryptoUtils.encryptAesGcm(plaintext: plaintext, key: shortKey)) { error in
            guard let cryptoError = error as? CryptoError else {
                XCTFail("Expected CryptoError, got \(type(of: error))")
                return
            }
            if case .invalidKeySize = cryptoError {
                // Expected
            } else {
                XCTFail("Expected .invalidKeySize, got \(cryptoError)")
            }
        }
    }

    func testAesGcmRejectsTruncatedCiphertext() {
        let key = Data(repeating: 0xAA, count: 32)
        let tooShort = Data([0x01, 0x02, 0x03])

        XCTAssertThrowsError(try CryptoUtils.decryptAesGcm(ivPlusCt: tooShort, key: key),
                             "Ciphertext shorter than IV must be rejected")
    }

    func testAesGcmWireFormat() throws {
        // Verify IV (12) || ciphertext || tag (16) format
        let key = try CryptoUtils.randomKey32()
        let plaintext = Data("test".utf8)

        let result = try CryptoUtils.encryptAesGcm(plaintext: plaintext, key: key)

        // 12 (IV) + plaintext.count + 16 (tag)
        XCTAssertEqual(result.count, 12 + plaintext.count + 16,
                       "Wire format must be IV(12) || ciphertext || tag(16)")
    }

    // MARK: - Random Key Generation

    func testRandomKey32Length() throws {
        let key = try CryptoUtils.randomKey32()
        XCTAssertEqual(key.count, 32, "Random key must be 32 bytes")
    }

    func testRandomKey32Uniqueness() throws {
        let key1 = try CryptoUtils.randomKey32()
        let key2 = try CryptoUtils.randomKey32()
        XCTAssertNotEqual(key1, key2, "Two random keys must not be equal")
    }

    // MARK: - PBKDF2

    func testDeriveKeyProduces32Bytes() throws {
        let salt = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        // Use low rounds for test speed
        let holder = try CryptoUtils.deriveKey(from: "1234", salt: salt, rounds: 1000)
        defer { holder.close() }
        XCTAssertEqual(holder.size, 32, "Derived key must be 32 bytes")
    }

    func testDeriveKeyDeterministic() throws {
        let salt = Data([0xAA, 0xBB, 0xCC, 0xDD])
        let h1 = try CryptoUtils.deriveKey(from: "pin", salt: salt, rounds: 1000)
        let h2 = try CryptoUtils.deriveKey(from: "pin", salt: salt, rounds: 1000)
        defer { h1.close(); h2.close() }
        XCTAssertEqual(h1.data, h2.data, "Same PIN and salt must produce identical keys")
    }

    func testDeriveKeyDifferentSaltsProduceDifferentKeys() throws {
        let salt1 = Data([0x01, 0x02, 0x03, 0x04])
        let salt2 = Data([0x05, 0x06, 0x07, 0x08])
        let h1 = try CryptoUtils.deriveKey(from: "pin", salt: salt1, rounds: 1000)
        let h2 = try CryptoUtils.deriveKey(from: "pin", salt: salt2, rounds: 1000)
        defer { h1.close(); h2.close() }
        XCTAssertNotEqual(h1.data, h2.data, "Different salts must produce different keys")
    }

    // MARK: - Credential Blob Decryption

    func testDecryptCredentialBlobMissingKeyThrows() {
        XCTAssertThrowsError(try CryptoUtils.decryptCredentialBlob("{\"enc\":\"A256GCM\",\"ct\":\"dGVzdA\"}", key: "")) { error in
            guard let cryptoError = error as? CryptoError, case .missingKey = cryptoError else {
                XCTFail("Expected .missingKey")
                return
            }
        }
    }

    func testDecryptCredentialBlobInvalidEnvelopeThrows() {
        XCTAssertThrowsError(try CryptoUtils.decryptCredentialBlob("not json", key: "key")) { error in
            guard let cryptoError = error as? CryptoError, case .invalidEnvelope = cryptoError else {
                XCTFail("Expected .invalidEnvelope")
                return
            }
        }
    }

    func testDecryptCredentialBlobUnsupportedAlgorithmThrows() throws {
        let blob = "{\"enc\":\"RSA-OAEP\",\"ct\":\"dGVzdA\"}"
        XCTAssertThrowsError(try CryptoUtils.decryptCredentialBlob(blob, key: "dGVzdA")) { error in
            guard let cryptoError = error as? CryptoError, case .unsupportedAlgorithm(let alg) = cryptoError else {
                XCTFail("Expected .unsupportedAlgorithm")
                return
            }
            XCTAssertEqual(alg, "RSA-OAEP")
        }
    }

    func testDecryptCredentialBlobRoundTrip() throws {
        let key = try CryptoUtils.randomKey32()
        let keyB64 = CryptoUtils.b64UrlEncode(key)
        let plaintext = "credential-json-data"

        // Encrypt
        let ciphertext = try CryptoUtils.encryptAesGcm(plaintext: Data(plaintext.utf8), key: key)
        let ctB64 = CryptoUtils.b64UrlEncode(ciphertext)

        let blob = "{\"enc\":\"A256GCM\",\"ct\":\"\(ctB64)\"}"
        let decrypted = try CryptoUtils.decryptCredentialBlob(blob, key: keyB64)
        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - AES-GCM additional edge cases

    func testAesGcmDecryptRejectsInvalidFormat() {
        let key = Data(repeating: 0xAA, count: 32)
        // 12 bytes IV + less than 16 bytes for tag
        let tooShort = Data(repeating: 0x00, count: 20)
        XCTAssertThrowsError(try CryptoUtils.decryptAesGcm(ivPlusCt: tooShort, key: key))
    }

    func testAesGcmDecryptRejectsBadKeySize() {
        let badKey = Data(repeating: 0xAA, count: 16)
        let fakeData = Data(repeating: 0x00, count: 40)
        XCTAssertThrowsError(try CryptoUtils.decryptAesGcm(ivPlusCt: fakeData, key: badKey))
    }

    func testDeriveKeyDifferentPinsProduceDifferentKeys() throws {
        let salt = Data([0x01, 0x02, 0x03, 0x04])
        let h1 = try CryptoUtils.deriveKey(from: "1111", salt: salt, rounds: 1000)
        let h2 = try CryptoUtils.deriveKey(from: "2222", salt: salt, rounds: 1000)
        defer { h1.close(); h2.close() }
        XCTAssertNotEqual(h1.data, h2.data, "Different PINs must produce different keys")
    }
}
