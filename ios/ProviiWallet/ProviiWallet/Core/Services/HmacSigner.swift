// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// HMAC-SHA256 signing for officer authentication against the issuer API.
///
/// Builds canonical JSON representations of issuance and attestation requests,
/// computes `HMAC-SHA256(key, timestamp:METHOD:path:canonicalJson:nonce)`, and assembles
/// the authoriser object with nonce for replay prevention. Wire format and field
/// ordering match the Android implementation exactly.

import Foundation
import CryptoKit
enum HmacSigner {

    // MARK: - Private Helpers

    /**
     * RFC 8259 compliant JSON string escaping.
     * Escapes backslash, double quote, named control characters (BS, HT, LF, FF, CR),
     * and remaining U+0000-U+001F as \u00xx (lowercase hex).
     * Forward slash is NOT escaped.
     * Iterates over unicodeScalars to avoid grapheme cluster issues.
     */
    private static func jsonEscape(_ s: String) -> String {
        var result = ""
        result.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\u{08}":
                result += "\\b"
            case "\t":
                result += "\\t"
            case "\n":
                result += "\\n"
            case "\u{0C}":
                result += "\\f"
            case "\r":
                result += "\\r"
            default:
                if scalar.value <= 0x1F {
                    result += String(format: "\\u%04x", scalar.value)
                } else {
                    result += String(scalar)
                }
            }
        }
        return result
    }

    /**
     * Convert bytes to hex string
     */
    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public Methods

    /**
     * Generate HMAC-SHA256 and return as hex string
     */
    static func hmacSha256Hex(secret: Data, data: String) throws -> String {
        guard let messageData = data.data(using: .utf8) else {
            throw CryptoError.invalidUTF8
        }

        var secretCopy = [UInt8](secret)
        defer { SensitiveDataHolder.zeroise(&secretCopy) }
        let key = SymmetricKey(data: secretCopy)
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: key)
        return hex(Data(signature))
    }

    // Canonical HMAC format: {ts}:{METHOD}:{path}:{json}:{nonce}
    // Source of truth: provii-issuer/src/session.rs::create_canonical_message_for_attestation
    // All implementations (Rust, Swift, Kotlin) must produce byte-identical output.

    /**
     * Build canonical message for HMAC signing
     * Format: "{timestamp}:{METHOD}:{PATH}:{jsonWithoutHmac}:{nonce}"
     */
    static func canonicalMessage(ts: Int64, method: String, path: String, jsonWithoutHmac: String, nonce: String) -> String {
        let msg = "\(ts):\(method.uppercased()):\(path):\(jsonWithoutHmac):\(nonce)"
        return msg
    }

    struct StartJsonParams {
        let actor: String
        let format: String
        let keyId: String
        let ts: Int64
        let schema: String?
        let validityDays: Int?
        let kid: String?
    }

    /**
     * Build canonical JSON for /v1/issuance/start
     * CRITICAL: Must use exact field order and "key_id" (snake_case)
     */
    static func canonicalStartJson(params: StartJsonParams) -> String {
        let actor = params.actor
        let format = params.format
        let keyId = params.keyId
        let ts = params.ts
        let schema = params.schema
        let validityDays = params.validityDays
        let kid = params.kid
        // Helper to escape and quote strings
        func jstr(_ s: String) -> String {
            return "\"" + Self.jsonEscape(s) + "\""
        }

        func joptStr(_ v: String?) -> String {
            guard let v = v else { return "null" }
            return jstr(v)
        }

        func joptNum(_ v: Int?) -> String {
            guard let v = v else { return "null" }
            return String(v)
        }

        // IMPORTANT: "key_id" not "keyId" in the canonical form
        return "{\"actor\":\(jstr(actor)),\"authorizer\":{\"format\":\(jstr(format)),\"key_id\":\(jstr(keyId)),\"timestamp\":\(ts)},\"schema\":\(joptStr(schema)),\"validity_days\":\(joptNum(validityDays)),\"kid\":\(joptStr(kid))}"
    }

    /**
     * Build canonical JSON for /v1/issuance/blind
     * CRITICAL: Must use exact field order and "key_id" (snake_case)
     */
    static func canonicalSignJson(
        sessionId: String,
        commitmentB64: String,
        format: String,
        keyId: String,
        ts: Int64
    ) -> String {
        func jstr(_ s: String) -> String {
            return "\"" + Self.jsonEscape(s) + "\""
        }

        // IMPORTANT: "key_id" not "keyId" in the canonical form
        return "{\"session_id\":\(jstr(sessionId)),\"commitment\":\(jstr(commitmentB64)),\"authorizer\":{\"format\":\(jstr(format)),\"key_id\":\(jstr(keyId)),\"timestamp\":\(ts)}}"
    }

    /**
     * Generate a 64 hex character nonce (256 bits) for replay prevention
     */
    static func generateNonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw CryptoError.randomGenerationFailed(status)
        }
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        SensitiveDataHolder.zeroise(&bytes)
        return hex
    }

    /**
     * Build the actual authorizer JSON object for the request.
     * Uses "keyId" (camelCase) for the actual API request.
     * When challengeId is provided it is appended as "challengeId" (camelCase),
     * matching the backend serde rename attribute.
     */
    static func buildAuthorizerJson(
        format: String,
        keyId: String,
        timestamp: Int64,
        hmac: String,
        nonce: String,
        challengeId: String? = nil
    ) -> String {
        let f = Self.jsonEscape(format)
        let k = Self.jsonEscape(keyId)
        let h = Self.jsonEscape(hmac)
        let n = Self.jsonEscape(nonce)
        var json = "{\"format\":\"\(f)\",\"keyId\":\"\(k)\",\"timestamp\":\(timestamp),\"hmac\":\"\(h)\",\"nonce\":\"\(n)\""
        if let cid = challengeId {
            let c = Self.jsonEscape(cid)
            json += ",\"challengeId\":\"\(c)\""
        }
        json += "}"
        return json
    }

    /**
     * Create full authorizer object for issuance start
     */
    static func createStartAuthorizer(
        secret: Data,
        actor: String,
        format: String,
        keyId: String,
        schema: String? = nil,
        validityDays: Int? = nil,
        kid: String? = nil
    ) throws -> (authorizer: String, timestamp: Int64) {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let nonce = try generateNonce()

        // Build canonical JSON (with snake_case key_id)
        let canonicalJson = canonicalStartJson(params: StartJsonParams(
            actor: actor,
            format: format,
            keyId: keyId,
            ts: timestamp,
            schema: schema,
            validityDays: validityDays,
            kid: kid
        ))

        // Build canonical message (includes nonce as 5th field)
        let canonicalMsg = canonicalMessage(
            ts: timestamp,
            method: "POST",
            path: "/v1/issuance/start",
            jsonWithoutHmac: canonicalJson,
            nonce: nonce
        )

        // Generate HMAC
        let hmac = try hmacSha256Hex(secret: secret, data: canonicalMsg)

        // Build authorizer JSON (with camelCase keyId for API)
        let authorizer = buildAuthorizerJson(
            format: format,
            keyId: keyId,
            timestamp: timestamp,
            hmac: hmac,
            nonce: nonce
        )

        return (authorizer, timestamp)
    }

    /**
     * Build canonical JSON for /v1/attestation/create
     * CRITICAL: Must use exact field order and "key_id" (snake_case)
     */
    static func canonicalAttestationJson(
        dobDays: Int32,
        format: String,
        keyId: String,
        ts: Int64
    ) -> String {
        func jstr(_ s: String) -> String {
            return "\"" + Self.jsonEscape(s) + "\""
        }

        // IMPORTANT: "key_id" not "keyId" in the canonical form
        return "{\"dob_days\":\(dobDays),\"authorizer\":{\"format\":\(jstr(format)),\"key_id\":\(jstr(keyId)),\"timestamp\":\(ts)}}"
    }

    /**
     * Create full authorizer object for /v1/attestation/create
     */
    static func createAttestationAuthorizer(
        secret: Data,
        dobDays: Int32,
        format: String,
        keyId: String
    ) throws -> (authorizer: String, timestamp: Int64) {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let nonce = try generateNonce()

        let canonicalJson = canonicalAttestationJson(
            dobDays: dobDays,
            format: format,
            keyId: keyId,
            ts: timestamp
        )

        let canonicalMsg = canonicalMessage(
            ts: timestamp,
            method: "POST",
            path: "/v1/attestation/create",
            jsonWithoutHmac: canonicalJson,
            nonce: nonce
        )

        let hmac = try hmacSha256Hex(secret: secret, data: canonicalMsg)

        let authorizer = buildAuthorizerJson(
            format: format,
            keyId: keyId,
            timestamp: timestamp,
            hmac: hmac,
            nonce: nonce
        )

        return (authorizer, timestamp)
    }

}

// MARK: - Extensions for convenience

extension String {
    /**
     * Convert hex string to Data
     */
    func hexToData() -> Data? {
        var data = Data()
        var hex = self

        // Remove any spaces or non-hex characters
        hex = hex.replacingOccurrences(of: " ", with: "")

        // Ensure even number of characters
        if hex.count % 2 != 0 {
            return nil
        }

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        return data
    }
}

extension Data {
    /**
     * Convert Data to hex string
     */
    func hexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
