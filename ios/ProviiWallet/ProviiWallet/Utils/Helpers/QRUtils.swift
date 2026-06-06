// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

// MARK: - QR Challenge Payload

struct QRChallengePayload: Codable {
    let challengeId: String
    let rpChallenge: String     // 32B base64url - must be 43 chars
    let cutoffDays: Int32
    let verifyingKeyId: UInt32
    let submitSecret: String    // 32B base64url - must be 43 chars
    let verifyUrl: String?
    let expiresAt: UInt64?
    let proofDirection: String? // "over_age" or "under_age"

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case rpChallenge = "rp_challenge"
        case cutoffDays = "cutoff_days"
        case verifyingKeyId = "verifying_key_id"
        case submitSecret = "submit_secret"
        case verifyUrl = "verify_url"
        case expiresAt = "expires_at"
        case proofDirection = "proof_direction"
    }
}

/// QR code parsing and validation utilities for Provii Wallet verification.
/// Handles both `provii://verify?d=<base64url>` deep links and raw JSON
/// QR payloads, validates field lengths and base64url encoding, and enforces
/// HTTPS in all environments (localhost excepted in DEBUG builds).
enum QRUtils {

    // MARK: - Constants

    private static let proviiWalletScheme = "provii://"
    private static let verifyHost = "verify"

    // Get default verify URL from EnvironmentManager
    private static var defaultVerifyURL: String {
        EnvironmentManager.shared.verifierVerifyUrl
    }

    // MARK: - Parsing

    /// Parse QR content or deep link.
    static func parseQRContent(_ qrContent: String) -> QRChallengePayload? {
        do {
            if qrContent.hasPrefix("\(proviiWalletScheme)\(verifyHost)?d=") {
                // New format: provii://verify?d=<base64url>
                let base64Part = qrContent
                    .components(separatedBy: "d=").last?
                    .components(separatedBy: "&").first ?? ""

                let jsonString = try base64UrlDecode(base64Part)

                guard let jsonData = jsonString.data(using: .utf8) else {
                    throw QRUtilsError.decodingFailed
                }
                let payload = try JSONDecoder().decode(QRChallengePayload.self, from: jsonData)
                try validatePayload(payload)
                return payload

            } else if qrContent.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                // Raw JSON format (for development/testing)
                guard let jsonData = qrContent.data(using: .utf8) else {
                    throw QRUtilsError.decodingFailed
                }
                let payload = try JSONDecoder().decode(QRChallengePayload.self, from: jsonData)
                try validatePayload(payload)
                return payload

            } else {
                #if DEBUG
                SecureLogger.shared.warning("Unsupported QR format", redact: false)
                #endif
                return nil
            }
        } catch {
            SecureLogger.shared.error("Failed to parse QR content: \(error.localizedDescription)")
            return nil
        }
    }

    /// Generate QR content for sharing.
    static func generateQRContent(from payload: QRChallengePayload) -> String? {
        do {
            let jsonData = try JSONEncoder().encode(payload)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }

            let base64 = base64UrlEncode(jsonString)
            return "\(proviiWalletScheme)\(verifyHost)?d=\(base64)"
        } catch {
            SecureLogger.shared.error("Failed to generate QR content: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Validation

    /// Validate QR payload according to spec.
    private static func validatePayload(_ payload: QRChallengePayload) throws {
        // 32-byte values must be exactly 43 characters in base64url
        guard payload.rpChallenge.count == 43 else {
            throw QRUtilsError.invalidFieldLength("rp_challenge", expected: 43, actual: payload.rpChallenge.count)
        }

        guard payload.submitSecret.count == 43 else {
            throw QRUtilsError.invalidFieldLength("submit_secret", expected: 43, actual: payload.submitSecret.count)
        }

        // Validate base64url alphabet (no +, /, or padding)
        guard isValidBase64Url(payload.rpChallenge) else {
            throw QRUtilsError.invalidBase64Url("rp_challenge")
        }

        guard isValidBase64Url(payload.submitSecret) else {
            throw QRUtilsError.invalidBase64Url("submit_secret")
        }

        // Validate URL if present - enforce HTTPS unconditionally
        if let verifyUrl = payload.verifyUrl {
            let url = URL(string: verifyUrl)
            let scheme = url?.scheme?.lowercased()
            #if DEBUG
            let localhostHosts = ["localhost", "127.0.0.1"]
            let isLocalhost = localhostHosts.contains(url?.host?.lowercased() ?? "")
            #else
            let isLocalhost = false
            #endif
            guard scheme != nil else { throw QRUtilsError.insecureURL(verifyUrl) }
            if !isLocalhost && scheme != "https" {
                throw QRUtilsError.insecureURL(verifyUrl)
            }
        }
    }

    /// Check if string uses valid base64url alphabet.
    static func isValidBase64Url(_ string: String) -> Bool {
        // Base64url uses only A-Z, a-z, 0-9, -, _ (no +, /, or =)
        let pattern = "^[A-Za-z0-9_-]+$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Base64 URL Encoding/Decoding

    /// Base64 URL decode (no padding, URL safe characters).
    static func base64UrlDecode(_ input: String) throws -> String {
        // Convert base64url to base64
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64),
              let string = String(data: data, encoding: .utf8) else {
            throw QRUtilsError.decodingFailed
        }

        return string
    }

    /// Base64 URL encode (no padding, URL safe characters).
    static func base64UrlEncode(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }

        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Utility Functions

    /// Check if a string is a valid Provii Wallet QR or deep link.
    static func isValidProviiQR(_ content: String) -> Bool {
        return content.hasPrefix("\(proviiWalletScheme)\(verifyHost)?d=") ||
               (content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") &&
                content.contains("\"challenge_id\""))
    }

    /// Extract verification URL from QR payload.
    /// Returns environment specific URL if not present in the payload.
    static func extractVerifyUrl(from qrContent: String) -> String? {
        guard let payload = parseQRContent(qrContent) else { return nil }
        // If verify_url is missing, use environment-specific default
        return payload.verifyUrl ?? defaultVerifyURL
    }

    /// Create a simple QR payload for testing.
    static func createTestPayload(
        challengeId: String = UUID().uuidString,
        minimumAge: UInt32 = 18
    ) throws -> QRChallengePayload {
        // Generate random 32-byte values as base64url (43 chars)
        let rpChallenge = try Data.random(count: 32).base64UrlString()
        let submitSecret = try Data.random(count: 32).base64UrlString()

        return QRChallengePayload(
            challengeId: challengeId,
            rpChallenge: rpChallenge,
            cutoffDays: Int32(minimumAge) * 365,
            verifyingKeyId: 2031517468,
            submitSecret: submitSecret,
            verifyUrl: defaultVerifyURL,
            expiresAt: UInt64(Date().addingTimeInterval(300).timeIntervalSince1970),
            proofDirection: nil
        )
    }
}

// MARK: - Error Types

enum QRUtilsError: LocalizedError {
    case invalidFieldLength(String, expected: Int, actual: Int)
    case invalidBase64Url(String)
    case insecureURL(String)
    case decodingFailed
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFieldLength(let field, let expected, let actual):
            return String(format: NSLocalizedString("error.qr_utils.invalid_field_length", comment: "Invalid field length error"), field, actual, expected)
        case .invalidBase64Url(let field):
            return String(format: NSLocalizedString("error.qr_utils.invalid_base64_url", comment: "Field contains invalid base64url characters error"), field)
        case .insecureURL(let url):
            return String(format: NSLocalizedString("error.qr_utils.insecure_url", comment: "Verify URL must use HTTPS error"), EnvironmentManager.shared.getCurrentEnvironment, url)
        case .decodingFailed:
            return NSLocalizedString("error.qr_utils.decoding_failed", comment: "Failed to decode QR content error")
        case .invalidFormat:
            return NSLocalizedString("error.qr_utils.invalid_format", comment: "Invalid QR code format error")
        }
    }
}

// MARK: - Data Extension

extension Data {
    static func random(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw CryptoError.randomGenerationFailed(status)
        }
        return Data(bytes)
    }

    func base64UrlString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
