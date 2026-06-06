// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Value types representing credentials stored in the wallet. `StoredCredential` is the top-level
/// container holding issuer metadata, expiry timestamps, and an inner `CredentialData` that
/// separates public cryptographic fields (issuer_vk, sig_rj, c_bytes) from private secrets
/// (dob_days, r_bits). The private fields are intentionally excluded from Codable serialisation
/// and stored separately via platform-secure storage.

struct StoredCredential: Identifiable, Codable, Equatable {
    let id: String
    let issuerKid: String
    let issuerLabel: String
    let issuedAt: Int64
    let expiresAt: Int64
    let schema: String
    let createdAt: TimeInterval
    let credentialData: CredentialData
    /// "primary" or "managed"
    let credentialType: String
    /// User-assigned nickname (required for managed credentials)
    let nickname: String?

    init(
        id: String,
        issuerKid: String,
        issuerLabel: String,
        issuedAt: Int64,
        expiresAt: Int64,
        schema: String,
        credentialData: CredentialData,
        credentialType: String = "primary",
        nickname: String? = nil
    ) {
        self.id = id
        self.issuerKid = issuerKid
        self.issuerLabel = issuerLabel
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.schema = schema
        self.createdAt = Date().timeIntervalSince1970
        self.credentialData = credentialData
        self.credentialType = credentialType
        self.nickname = nickname
    }

    var isExpired: Bool {
        Int64(Date().timeIntervalSince1970) > expiresAt
    }

    var daysUntilExpiry: Int {
        let remaining = expiresAt - Int64(Date().timeIntervalSince1970)
        return Int(remaining / (24 * 60 * 60))
    }

    /// Display name: nickname for managed, localised default for primary
    var displayName: String {
        nickname ?? NSLocalizedString("credential_display_name_default", comment: "My Credential")
    }

    var isManaged: Bool {
        credentialType == "managed"
    }
}

struct CredentialData: Codable, Equatable {
    let issuerVk: String
    let sigRj: String
    let cBytes: String
    // SECURITY: Private fields excluded from serialisation.
    // These are stored separately with platform-secure storage.
    var dobDays: Int32 = 0
    var rBits: String = ""

    // Exclude sensitive fields from encoding/decoding
    enum CodingKeys: String, CodingKey {
        case issuerVk, sigRj, cBytes
        // dobDays and rBits are intentionally excluded from serialisation
    }

}

struct CredentialDisplay: Identifiable {
    let id: String
    let issuerLabel: String
    let status: StoredCredentialStatus
    let expiresInDays: Int
    let createdAt: TimeInterval
}

enum StoredCredentialStatus: String, Codable {
    case active = "ACTIVE"
    case expired = "EXPIRED"
    case revoked = "REVOKED"
    case pending = "PENDING"
}

struct IssuanceConfirmation: Codable {
    let requestId: String
    let credentialId: String
    let officerId: String?
    let stationId: String?
    let issuedAt: Int64
    let issuerKid: String
}

struct VerificationResult {
    let challengeId: String
    let status: VerificationResultStatus
    let verifierName: String?
    let timestamp: TimeInterval

    init(
        challengeId: String,
        status: VerificationResultStatus,
        verifierName: String? = nil
    ) {
        self.challengeId = challengeId
        self.status = status
        self.verifierName = verifierName
        self.timestamp = Date().timeIntervalSince1970
    }
}

enum VerificationResultStatus {
    case success
    case waitingForRedeem
    case notEligible
    case expired
    case failed
}
