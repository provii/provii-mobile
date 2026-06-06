// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

// Data models for the officer-assisted issuance flow, mirroring Android's OfficerQrModels.kt to
// keep cross-platform data structures consistent. Covers session lifecycle, YubiKey challenge/response,
// credential policy, issuance statistics, and audit logging. All Codable types use snake_case
// CodingKeys to match the provii-issuer JSON contract.

// MARK: - Officer Start Response

/// Response from starting an officer issuance session.
/// Matches OfficerStartResponse in Android.
struct OfficerStartResponse: Codable {
    let sessionId: String
    let issuerId: String
    let kid: String
    let expiresAt: Int64
    let issuerNonce: String
    let policy: PolicyConfig

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case issuerId = "issuer_id"
        case kid
        case expiresAt = "expires_at"
        case issuerNonce = "issuer_nonce"
        case policy
    }
}

// MARK: - Policy Config

/// Credential policy configuration.
/// Matches PolicyConfig in Android.
struct PolicyConfig: Codable {
    let schema: String
    let validityDays: Int
    let v: Int

    enum CodingKeys: String, CodingKey {
        case schema
        case validityDays = "validity_days"
        case v
    }
}

// MARK: - User Issuance Request

/// Request to send user's commitment to officer.
/// Matches UserIssuanceRequest in Android.
struct UserIssuanceRequest: Codable {
    let sessionId: String
    let commitment: String
    let birthDate: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case commitment
        case birthDate = "birth_date"
    }
}

// MARK: - Officer Session Info

/// Information about the current officer session
struct OfficerSessionInfo: Codable {
    let officerId: String
    let stationId: String
    let authenticatedAt: Date
    let expiresAt: Date
    let issuedToday: Int

    var isExpired: Bool {
        return Date() > expiresAt
    }

    var remainingTime: TimeInterval {
        return expiresAt.timeIntervalSince(Date())
    }
}

// MARK: - Officer Issuance State

/// States for the officer issuance flow
enum OfficerIssuanceState: Equatable {
    case idle
    case validatingInput
    case computingCommitment
    case creatingSession
    case creatingAttestation
    case finalisingCredential
    case waitingForYubikeyTouch(message: String, step: Int, totalSteps: Int)
    case complete(attestationData: String)
    case error(message: String, canRetry: Bool)

    var isProcessing: Bool {
        switch self {
        case .validatingInput, .computingCommitment, .creatingSession,
             .creatingAttestation, .finalisingCredential,
             .waitingForYubikeyTouch:
            return true
        default:
            return false
        }
    }

    var canRetry: Bool {
        if case .error(_, let retry) = self {
            return retry
        }
        return false
    }
}

// MARK: - Officer Credentials

/// Officer authentication credentials
struct OfficerCredentials: Codable {
    let officerId: String
    let hmacSecret: Data
    let kid: String
    let issuedAt: Date
    let expiresAt: Date

    var isExpired: Bool {
        return Date() > expiresAt
    }
}

// MARK: - Credential Issuance Stats

/// Statistics for credential issuance
struct IssuanceStats: Codable {
    let totalIssued: Int
    let issuedToday: Int
    let lastIssuedAt: Date?
    let averageTimeSeconds: Double

    enum CodingKeys: String, CodingKey {
        case totalIssued = "total_issued"
        case issuedToday = "issued_today"
        case lastIssuedAt = "last_issued_at"
        case averageTimeSeconds = "average_time_seconds"
    }
}

// MARK: - Station Info

/// Information about an issuance station
struct StationInfo: Codable {
    let stationId: String
    let name: String
    let location: String
    let isActive: Bool
    let supportedSchemas: [String]

    enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case name
        case location
        case isActive = "is_active"
        case supportedSchemas = "supported_schemas"
    }
}

// MARK: - Issuance Audit Log

/// Audit log entry for issuance
struct IssuanceAuditLog: Codable {
    let id: String
    let officerId: String
    let stationId: String
    let timestamp: Date
    let action: String
    let credentialId: String?
    let success: Bool
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case officerId = "officer_id"
        case stationId = "station_id"
        case timestamp
        case action
        case credentialId = "credential_id"
        case success
        case errorMessage = "error_message"
    }
}

// MARK: - YubiKey Challenge

/// YubiKey challenge data for officer authentication
struct YubikeyChallenge: Codable {
    let challengeId: String
    let challenge: Data
    let issuerId: String
    let officerId: String
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case challenge
        case issuerId = "issuer_id"
        case officerId = "officer_id"
        case expiresAt = "expires_at"
    }

    var isExpired: Bool {
        let now = Int64(Date().timeIntervalSince1970)
        return now > expiresAt
    }
}

// MARK: - YubiKey Response

/// YubiKey HMAC response
struct YubikeyResponse: Codable {
    let challengeId: String
    let response: Data
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case response
        case timestamp
    }
}

// MARK: - Helper Extensions

extension OfficerStartResponse {
    /// Check if session is expired
    var isExpired: Bool {
        let now = Int64(Date().timeIntervalSince1970)
        return now > expiresAt
    }

    /// Time until expiration
    var timeUntilExpiration: TimeInterval {
        let now = Int64(Date().timeIntervalSince1970)
        return TimeInterval(expiresAt - now)
    }
}

// MARK: - JSON Encoding/Decoding Helpers

extension Encodable {
    /// Convert to JSON string
    func toJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to convert to UTF-8 string"
                )
            )
        }
        return string
    }

    /// Convert to JSON data
    func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

extension Decodable {
    /// Decode from JSON string
    static func from(jsonString: String) throws -> Self {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid UTF-8 string"
                )
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }

    /// Decode from JSON data
    static func from(jsonData: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: jsonData)
    }
}

// MARK: - Validation Helpers

extension OfficerSessionInfo {
    /// Validate session is still valid
    func validate() throws {
        guard !isExpired else {
            throw OfficerError.sessionExpired
        }

        guard remainingTime > 60 else { // Less than 1 minute remaining
            throw OfficerError.sessionExpiring
        }
    }
}

extension PolicyConfig {
    /// Validate policy configuration
    func validate() throws {
        guard !schema.isEmpty else {
            throw OfficerError.invalidPolicy("Empty schema")
        }

        guard validityDays > 0 && validityDays <= 36500 else { // Max 100 years
            throw OfficerError.invalidPolicy("Invalid validity days: \(validityDays)")
        }

        guard v > 0 else {
            throw OfficerError.invalidPolicy("Invalid version: \(v)")
        }
    }
}

// MARK: - Officer Errors

enum OfficerError: LocalizedError {
    case sessionExpired
    case sessionExpiring
    case invalidCredentials
    case invalidPolicy(String)
    case yubikeyNotConnected
    case yubikeyTimeout
    case hmacFailed
    case issuanceQuotaExceeded
    case invalidOfficerIdFormat
    case invalidChallenge
    case noActiveSession
    case verificationIncomplete
    case invalidDateFormat
    case userTooYoung
    case officerKeyNotFound

    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return NSLocalizedString("error.officer.session_expired", comment: "Officer session has expired error")
        case .sessionExpiring:
            return NSLocalizedString("error.officer.session_expiring", comment: "Officer session is expiring soon error")
        case .invalidCredentials:
            return NSLocalizedString("error.officer.invalid_credentials", comment: "Invalid officer credentials error")
        case .invalidPolicy(let details):
            return String(format: NSLocalizedString("error.officer.invalid_policy", comment: "Invalid policy error"), details)
        case .yubikeyNotConnected:
            return NSLocalizedString("error.officer.yubikey_not_connected", comment: "YubiKey not connected error")
        case .yubikeyTimeout:
            return NSLocalizedString("error.officer.yubikey_timeout", comment: "YubiKey authentication timeout error")
        case .hmacFailed:
            return NSLocalizedString("error.officer.hmac_failed", comment: "HMAC authentication failed error")
        case .issuanceQuotaExceeded:
            return NSLocalizedString("error.officer.issuance_quota_exceeded", comment: "Daily issuance quota exceeded error")
        case .invalidOfficerIdFormat:
            return NSLocalizedString("error.officer.invalid_officer_id_format", comment: "Invalid officer ID format error")
        case .invalidChallenge:
            return NSLocalizedString("error.officer.invalid_challenge", comment: "Invalid authentication challenge error")
        case .noActiveSession:
            return NSLocalizedString("error.officer.no_active_session", comment: "No active officer session error")
        case .verificationIncomplete:
            return NSLocalizedString("error.officer.verification_incomplete", comment: "Verification is incomplete error")
        case .invalidDateFormat:
            return NSLocalizedString("error.officer.invalid_date_format", comment: "Invalid date format error")
        case .userTooYoung:
            return NSLocalizedString("error.officer.user_too_young", comment: "User does not meet minimum age requirement error")
        case .officerKeyNotFound:
            return NSLocalizedString("error.officer.officer_key_not_found", comment: "Officer key not found error")
        }
    }
}
