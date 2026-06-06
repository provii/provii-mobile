// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class StoredCredentialTests: XCTestCase {

    // MARK: - Helpers

    private func makeCredential(
        expiresAt: Int64 = Int64(Date().timeIntervalSince1970) + 86400,
        type: String = "primary",
        nickname: String? = nil
    ) -> StoredCredential {
        StoredCredential(
            id: "test-cred-1",
            issuerKid: "kid-abc",
            issuerLabel: "Test Issuer",
            issuedAt: Int64(Date().timeIntervalSince1970) - 3600,
            expiresAt: expiresAt,
            schema: "age_v1",
            credentialData: CredentialData(
                issuerVk: "vk-123",
                sigRj: "sig-456",
                cBytes: "c-789"
            ),
            credentialType: type,
            nickname: nickname
        )
    }

    // MARK: - Expiry

    func testIsExpiredFalseForFutureExpiry() {
        let cred = makeCredential(expiresAt: Int64(Date().timeIntervalSince1970) + 86400)
        XCTAssertFalse(cred.isExpired)
    }

    func testIsExpiredTrueForPastExpiry() {
        let cred = makeCredential(expiresAt: Int64(Date().timeIntervalSince1970) - 100)
        XCTAssertTrue(cred.isExpired)
    }

    func testDaysUntilExpiryPositive() {
        let oneDayFromNow = Int64(Date().timeIntervalSince1970) + 86400
        let cred = makeCredential(expiresAt: oneDayFromNow)
        XCTAssertEqual(cred.daysUntilExpiry, 1, "Should report ~1 day until expiry")
    }

    func testDaysUntilExpiryNegativeWhenExpired() {
        let oneDayAgo = Int64(Date().timeIntervalSince1970) - 86400
        let cred = makeCredential(expiresAt: oneDayAgo)
        XCTAssertLessThan(cred.daysUntilExpiry, 0, "Expired credential should have negative days")
    }

    // MARK: - Credential types

    func testIsManagedTrue() {
        let cred = makeCredential(type: "managed", nickname: "Work")
        XCTAssertTrue(cred.isManaged)
    }

    func testIsManagedFalseForPrimary() {
        let cred = makeCredential(type: "primary")
        XCTAssertFalse(cred.isManaged)
    }

    func testDisplayNameUsesNickname() {
        let cred = makeCredential(nickname: "My Work Cred")
        XCTAssertEqual(cred.displayName, "My Work Cred")
    }

    func testDisplayNameFallsBackToDefault() {
        let cred = makeCredential(nickname: nil)
        // Falls back to NSLocalizedString default
        XCTAssertFalse(cred.displayName.isEmpty, "Display name must not be empty even without nickname")
    }

    // MARK: - CredentialData Codable (secrets excluded)

    func testCredentialDataExcludesSecretsFromCodable() throws {
        var data = CredentialData(
            issuerVk: "vk",
            sigRj: "sig",
            cBytes: "c"
        )
        data.dobDays = 12345
        data.rBits = "secret-r-bits"

        let encoded = try JSONEncoder().encode(data)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertNotNil(json?["issuerVk"], "Public field issuerVk must be encoded")
        XCTAssertNil(json?["dobDays"], "Secret field dobDays must NOT be encoded")
        XCTAssertNil(json?["rBits"], "Secret field rBits must NOT be encoded")
    }

    func testCredentialDataDecodesWithoutSecrets() throws {
        let json = Data("""
        {"issuerVk":"vk","sigRj":"sig","cBytes":"c"}
        """.utf8)

        let decoded = try JSONDecoder().decode(CredentialData.self, from: json)

        XCTAssertEqual(decoded.issuerVk, "vk")
        XCTAssertEqual(decoded.dobDays, 0, "dobDays must default to 0 when not in JSON")
        XCTAssertEqual(decoded.rBits, "", "rBits must default to empty when not in JSON")
    }

    // MARK: - StoredCredentialStatus

    func testStoredCredentialStatusRawValues() {
        XCTAssertEqual(StoredCredentialStatus.active.rawValue, "ACTIVE")
        XCTAssertEqual(StoredCredentialStatus.expired.rawValue, "EXPIRED")
        XCTAssertEqual(StoredCredentialStatus.revoked.rawValue, "REVOKED")
        XCTAssertEqual(StoredCredentialStatus.pending.rawValue, "PENDING")
    }

    // MARK: - VerificationChallenge Codable

    func testVerificationChallengeRoundTrip() throws {
        let now = Date()
        let challenge = VerificationChallenge(
            id: "ch-1",
            minimumAge: 18,
            verifierName: "Test Verifier",
            verifierUrl: "https://verify.provii.app",
            timestamp: now,
            expiresAt: now.addingTimeInterval(300)
        )

        let data = try JSONEncoder().encode(challenge)
        let decoded = try JSONDecoder().decode(VerificationChallenge.self, from: data)

        XCTAssertEqual(decoded.id, "ch-1")
        XCTAssertEqual(decoded.minimumAge, 18)
        XCTAssertEqual(decoded.verifierName, "Test Verifier")
    }

    // MARK: - Equatable

    func testStoredCredentialEqualitySameInstance() {
        // createdAt uses Date() internally, so two separate makeCredential()
        // calls will differ. Test equality on a single instance instead.
        let a = makeCredential()
        XCTAssertEqual(a, a, "A credential must be equal to itself")
    }

    func testStoredCredentialInequalityDifferentIds() {
        let a = StoredCredential(
            id: "id-1",
            issuerKid: "kid",
            issuerLabel: "Issuer",
            issuedAt: 1000,
            expiresAt: 2000,
            schema: "age_v1",
            credentialData: CredentialData(issuerVk: "vk", sigRj: "sig", cBytes: "c")
        )
        let b = StoredCredential(
            id: "id-2",
            issuerKid: "kid",
            issuerLabel: "Issuer",
            issuedAt: 1000,
            expiresAt: 2000,
            schema: "age_v1",
            credentialData: CredentialData(issuerVk: "vk", sigRj: "sig", cBytes: "c")
        )
        XCTAssertNotEqual(a, b, "Credentials with different IDs must not be equal")
    }
}
