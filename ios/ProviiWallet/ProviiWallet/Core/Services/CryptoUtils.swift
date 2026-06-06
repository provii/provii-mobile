// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Cryptographic utilities for AES-GCM encryption, base64url encoding,
/// and PBKDF2 key derivation. Wire format matches the Android implementation
/// (IV || ciphertext || tag).

import Foundation
import CryptoKit
import CommonCrypto
enum CryptoUtils {

    // MARK: - Constants

    private static let gcmTagLengthBits = 128
    private static let gcmIVLengthBytes = 12

    // MARK: - Key Generation

    /**
     * Generate a random 32-byte key for AES-256
     */
    static func randomKey32() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        guard status == errSecSuccess else {
            throw CryptoError.randomGenerationFailed(status)
        }
        return Data(bytes)
    }

    // MARK: - AES-GCM Encryption/Decryption

    /**
     * Encrypt data using AES-GCM
     * Returns: IV (12 bytes) || ciphertext || tag (16 bytes)
     */
    static func encryptAesGcm(plaintext: Data, key: Data) throws -> Data {
        guard key.count == 32 else {
            throw CryptoError.invalidKeySize
        }

        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)

        // Combine IV + ciphertext + tag to match Android format
        var result = Data()
        result.append(sealedBox.nonce.withUnsafeBytes { Data($0) })
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)

        return result
    }

    /**
     * Decrypt data using AES-GCM
     * Input format: IV (12 bytes) || ciphertext || tag (16 bytes)
     * Returns a SensitiveDataHolder for automatic zeroisation of decrypted plaintext.
     */
    static func decryptAesGcm(ivPlusCt: Data, key: Data) throws -> SensitiveDataHolder {
        guard ivPlusCt.count > gcmIVLengthBytes else {
            throw CryptoError.ciphertextTooShort
        }

        guard key.count == 32 else {
            throw CryptoError.invalidKeySize
        }

        // Extract components
        let iv = ivPlusCt.prefix(gcmIVLengthBytes)
        let ctAndTag = ivPlusCt.dropFirst(gcmIVLengthBytes)

        // The tag is the last 16 bytes
        let tagLength = 16
        guard ctAndTag.count >= tagLength else {
            throw CryptoError.invalidFormat
        }

        let ciphertext = ctAndTag.dropLast(tagLength)
        let tag = ctAndTag.suffix(tagLength)

        // Create sealed box
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag
        )

        // Decrypt
        let symmetricKey = SymmetricKey(data: key)
        let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)

        return SensitiveDataHolder(decrypted)
    }

    // MARK: - Base64URL Encoding/Decoding

    /**
     * Encode data to base64url format (no padding, URL-safe)
     */
    static func b64UrlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /**
     * Decode base64url string to data
     */
    static func b64UrlDecode(_ string: String) throws -> Data {
        // Convert base64url to base64
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64) else {
            throw CryptoError.invalidBase64
        }

        return data
    }

    // MARK: - Credential Decryption

    /**
     * Decrypt an encrypted credential blob
     * Handles the JSON envelope format: {"enc": "A256GCM", "ct": "base64url_ciphertext"}
     */
    static func decryptCredentialBlob(_ blob: String, key: String) throws -> String {
        let trimmed = blob.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            throw CryptoError.missingKey
        }

        // Parse as JSON if it starts with {
        if trimmed.hasPrefix("{") {
            guard let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let enc = json["enc"] as? String,
                  let ct = json["ct"] as? String else {
                throw CryptoError.invalidEnvelope
            }

            guard enc == "A256GCM" else {
                throw CryptoError.unsupportedAlgorithm(enc)
            }

            // Decode the key and ciphertext
            let keyBytes = try b64UrlDecode(key)
            let ctBytes = try b64UrlDecode(ct)

            // Decrypt - returns SensitiveDataHolder for automatic zeroisation
            let plaintextHolder = try decryptAesGcm(ivPlusCt: ctBytes, key: keyBytes)
            defer { plaintextHolder.close() }

            guard let result = String(data: plaintextHolder.data, encoding: .utf8) else {
                throw CryptoError.invalidUTF8
            }

            return result
        } else {
            throw CryptoError.invalidEnvelope
        }
    }

    // MARK: - PBKDF2 (for PIN hashing if needed)

    /**
     * Derive a key from a PIN using PBKDF2
     * SECURITY FIX: Now throws on encoding failure instead of returning weak all-zeros key
     */
    /// OWASP minimum for PBKDF2-HMAC-SHA256 is 600,000 iterations.
    /// See https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
    static func deriveKey(from pin: String, salt: Data, rounds: Int = 600_000) throws -> SensitiveDataHolder {
        guard let pinData = pin.data(using: .utf8) else {
            // SECURITY FIX: Throw error instead of returning weak all-zeros key
            // Returning zeros would allow attackers to trivially decrypt data
            throw CryptoError.pinEncodingFailed
        }
        var derivedKey = [UInt8](repeating: 0, count: 32)

        let status = pinData.withUnsafeBytes { pinBytes in
            salt.withUnsafeBytes { saltBytes -> Int32 in
                guard let pinBase = pinBytes.bindMemory(to: Int8.self).baseAddress,
                      let saltBase = saltBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return Int32(kCCParamError)
                }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinBase,
                    pinData.count,
                    saltBase,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    &derivedKey,
                    32
                )
            }
        }

        guard status == kCCSuccess else {
            // ADV-WM-004: Zeroize the buffer even on failure before throwing
            memset_s(&derivedKey, derivedKey.count, 0, derivedKey.count)
            throw CryptoError.keyDerivationFailed(status)
        }

        // takeOwnership zeros the source [UInt8] buffer via memset_s
        return SensitiveDataHolder.takeOwnership(&derivedKey)
    }
}

// MARK: - Error Types

enum CryptoError: LocalizedError {
    case invalidKeySize
    case ciphertextTooShort
    case invalidFormat
    case invalidBase64
    case missingKey
    case invalidEnvelope
    case unsupportedAlgorithm(String)
    case invalidUTF8
    case pinEncodingFailed
    case keyDerivationFailed(CCCryptorStatus)
    case randomGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidKeySize:
            return NSLocalizedString("error.crypto.invalid_key_size", comment: "Invalid key size error")
        case .ciphertextTooShort:
            return NSLocalizedString("error.crypto.ciphertext_too_short", comment: "Ciphertext too short error")
        case .invalidFormat:
            return NSLocalizedString("error.crypto.invalid_format", comment: "Invalid ciphertext format error")
        case .invalidBase64:
            return NSLocalizedString("error.crypto.invalid_base64", comment: "Invalid base64 encoding error")
        case .missingKey:
            return NSLocalizedString("error.crypto.missing_key", comment: "Decryption key is missing error")
        case .invalidEnvelope:
            return NSLocalizedString("error.crypto.invalid_envelope", comment: "Invalid encryption envelope format error")
        case .unsupportedAlgorithm(let alg):
            return String(format: NSLocalizedString("error.crypto.unsupported_algorithm", comment: "Unsupported encryption algorithm error"), alg)
        case .invalidUTF8:
            return NSLocalizedString("error.crypto.invalid_utf8", comment: "Decrypted data is not valid UTF-8 error")
        case .pinEncodingFailed:
            return NSLocalizedString("error.crypto.pin_encoding_failed", comment: "PIN contains invalid characters error")
        case .keyDerivationFailed(let status):
            return String(format: NSLocalizedString("error.crypto.key_derivation_failed", comment: "PBKDF2 key derivation failed error"), status)
        case .randomGenerationFailed(let status):
            return String(format: NSLocalizedString("error.crypto.random_generation_failed", comment: "Secure random generation failed error"), status)
        }
    }
}
