// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class OfficerModelsTests: XCTestCase {

    // MARK: - PolicyConfig Validation

    func testValidPolicyConfigPasses() {
        let policy = PolicyConfig(schema: "age_v1", validityDays: 365, v: 1)
        XCTAssertNoThrow(try policy.validate())
    }

    func testEmptySchemaPolicyFails() {
        let policy = PolicyConfig(schema: "", validityDays: 365, v: 1)
        XCTAssertThrowsError(try policy.validate()) { error in
            guard case OfficerError.invalidPolicy = error else {
                XCTFail("Expected invalidPolicy error")
                return
            }
        }
    }

    func testZeroValidityDaysFails() {
        let policy = PolicyConfig(schema: "age_v1", validityDays: 0, v: 1)
        XCTAssertThrowsError(try policy.validate())
    }

    func testNegativeValidityDaysFails() {
        let policy = PolicyConfig(schema: "age_v1", validityDays: -1, v: 1)
        XCTAssertThrowsError(try policy.validate())
    }

    func testExcessiveValidityDaysFails() {
        let policy = PolicyConfig(schema: "age_v1", validityDays: 36501, v: 1)
        XCTAssertThrowsError(try policy.validate())
    }

    func testZeroVersionFails() {
        let policy = PolicyConfig(schema: "age_v1", validityDays: 365, v: 0)
        XCTAssertThrowsError(try policy.validate())
    }

    // MARK: - OfficerIssuanceState

    func testIdleIsNotProcessing() {
        XCTAssertFalse(OfficerIssuanceState.idle.isProcessing)
    }

    func testCreatingSessionIsProcessing() {
        XCTAssertTrue(OfficerIssuanceState.creatingSession.isProcessing)
    }

    func testCompleteIsNotProcessing() {
        XCTAssertFalse(OfficerIssuanceState.complete(attestationData: "data").isProcessing)
    }

    func testErrorWithRetrySetsCanRetry() {
        XCTAssertTrue(OfficerIssuanceState.error(message: "fail", canRetry: true).canRetry)
        XCTAssertFalse(OfficerIssuanceState.error(message: "fail", canRetry: false).canRetry)
    }

    func testNonErrorStateCantRetry() {
        XCTAssertFalse(OfficerIssuanceState.idle.canRetry)
    }

    // MARK: - OfficerStartResponse Codable

    func testOfficerStartResponseCodableSnakeCase() throws {
        let json = Data("""
        {
            "session_id": "sess-1",
            "issuer_id": "iss-1",
            "kid": "key-1",
            "expires_at": 1717000000,
            "issuer_nonce": "nonce-abc",
            "policy": {
                "schema": "age_v1",
                "validity_days": 365,
                "v": 1
            }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(OfficerStartResponse.self, from: json)

        XCTAssertEqual(decoded.sessionId, "sess-1")
        XCTAssertEqual(decoded.issuerId, "iss-1")
        XCTAssertEqual(decoded.kid, "key-1")
        XCTAssertEqual(decoded.expiresAt, 1717000000)
        XCTAssertEqual(decoded.issuerNonce, "nonce-abc")
        XCTAssertEqual(decoded.policy.schema, "age_v1")
        XCTAssertEqual(decoded.policy.validityDays, 365)
    }

    func testOfficerStartResponseExpiry() {
        let json = Data("""
        {"session_id":"s","issuer_id":"i","kid":"k","expires_at":0,"issuer_nonce":"n","policy":{"schema":"a","validity_days":1,"v":1}}
        """.utf8)

        let decoded = try! JSONDecoder().decode(OfficerStartResponse.self, from: json)
        XCTAssertTrue(decoded.isExpired, "Session with expires_at=0 must be expired")
    }

    // MARK: - YubikeyChallenge

    func testYubikeyChallengeExpiryCheck() {
        let pastChallenge = YubikeyChallenge(
            challengeId: "ch-1",
            challenge: Data([0x01]),
            issuerId: "iss",
            officerId: "off",
            expiresAt: 0
        )
        XCTAssertTrue(pastChallenge.isExpired)

        let futureChallenge = YubikeyChallenge(
            challengeId: "ch-2",
            challenge: Data([0x02]),
            issuerId: "iss",
            officerId: "off",
            expiresAt: Int64(Date().timeIntervalSince1970) + 3600
        )
        XCTAssertFalse(futureChallenge.isExpired)
    }

    // MARK: - JSON encoding helpers

    func testEncodableToJSONString() throws {
        let policy = PolicyConfig(schema: "age_v1", validityDays: 30, v: 1)
        let jsonString = try policy.toJSONString()
        XCTAssertTrue(jsonString.contains("age_v1"))
        XCTAssertTrue(jsonString.contains("30"))
    }

    func testDecodableFromJSONString() throws {
        let json = "{\"schema\":\"test\",\"validity_days\":7,\"v\":2}"
        let policy = try PolicyConfig.from(jsonString: json)
        XCTAssertEqual(policy.schema, "test")
        XCTAssertEqual(policy.validityDays, 7)
        XCTAssertEqual(policy.v, 2)
    }

    // MARK: - OfficerCredentials

    func testOfficerCredentialsExpired() {
        let creds = OfficerCredentials(
            officerId: "OFF001",
            hmacSecret: Data([0x01]),
            kid: "kid-1",
            issuedAt: Date().addingTimeInterval(-7200),
            expiresAt: Date().addingTimeInterval(-3600)
        )
        XCTAssertTrue(creds.isExpired)
    }

    func testOfficerCredentialsNotExpired() {
        let creds = OfficerCredentials(
            officerId: "OFF001",
            hmacSecret: Data([0x01]),
            kid: "kid-1",
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(creds.isExpired)
    }

    // MARK: - OfficerSessionInfo

    func testSessionInfoExpired() {
        let info = OfficerSessionInfo(
            officerId: "OFF001",
            stationId: "STN001",
            authenticatedAt: Date().addingTimeInterval(-7200),
            expiresAt: Date().addingTimeInterval(-100),
            issuedToday: 5
        )
        XCTAssertTrue(info.isExpired)
        XCTAssertLessThan(info.remainingTime, 0)
    }

    func testSessionInfoValidateThrowsWhenExpired() {
        let info = OfficerSessionInfo(
            officerId: "OFF001",
            stationId: "STN001",
            authenticatedAt: Date(),
            expiresAt: Date().addingTimeInterval(-1),
            issuedToday: 0
        )
        XCTAssertThrowsError(try info.validate()) { error in
            guard case OfficerError.sessionExpired = error else {
                XCTFail("Expected sessionExpired error")
                return
            }
        }
    }

    func testSessionInfoValidateThrowsWhenExpiring() {
        let info = OfficerSessionInfo(
            officerId: "OFF001",
            stationId: "STN001",
            authenticatedAt: Date(),
            expiresAt: Date().addingTimeInterval(30), // < 60 seconds
            issuedToday: 0
        )
        XCTAssertThrowsError(try info.validate()) { error in
            guard case OfficerError.sessionExpiring = error else {
                XCTFail("Expected sessionExpiring error")
                return
            }
        }
    }

    func testSessionInfoValidatePassesWhenValid() {
        let info = OfficerSessionInfo(
            officerId: "OFF001",
            stationId: "STN001",
            authenticatedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            issuedToday: 0
        )
        XCTAssertNoThrow(try info.validate())
    }

    // MARK: - IssuanceStats Codable

    func testIssuanceStatsCodable() throws {
        let json = Data("{\"total_issued\":100,\"issued_today\":5,\"last_issued_at\":null,\"average_time_seconds\":2.5}".utf8)
        let decoded = try JSONDecoder().decode(IssuanceStats.self, from: json)
        XCTAssertEqual(decoded.totalIssued, 100)
        XCTAssertEqual(decoded.issuedToday, 5)
        XCTAssertNil(decoded.lastIssuedAt)
        XCTAssertEqual(decoded.averageTimeSeconds, 2.5, accuracy: 0.01)
    }

    // MARK: - StationInfo Codable

    func testStationInfoCodable() throws {
        let json = Data("{\"station_id\":\"s1\",\"name\":\"HQ\",\"location\":\"Sydney\",\"is_active\":true,\"supported_schemas\":[\"age_v1\"]}".utf8)
        let decoded = try JSONDecoder().decode(StationInfo.self, from: json)
        XCTAssertEqual(decoded.stationId, "s1")
        XCTAssertTrue(decoded.isActive)
        XCTAssertEqual(decoded.supportedSchemas, ["age_v1"])
    }

    // MARK: - UserIssuanceRequest Codable

    func testUserIssuanceRequestRoundTrip() throws {
        let request = UserIssuanceRequest(sessionId: "sess", commitment: "c", birthDate: "2000-01-01")
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(UserIssuanceRequest.self, from: data)
        XCTAssertEqual(decoded.sessionId, "sess")
        XCTAssertEqual(decoded.birthDate, "2000-01-01")
    }

    // MARK: - IssuanceAuditLog Codable

    func testIssuanceAuditLogCodable() throws {
        let json = Data("""
        {"id":"log-1","officer_id":"off-1","station_id":"stn-1","timestamp":"2024-01-01T00:00:00Z","action":"issue","credential_id":"cred-1","success":true,"error_message":null}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(IssuanceAuditLog.self, from: json)
        XCTAssertEqual(decoded.id, "log-1")
        XCTAssertTrue(decoded.success)
        XCTAssertNil(decoded.errorMessage)
    }

    // MARK: - OfficerIssuanceState additional cases

    func testWaitingForYubikeyIsProcessing() {
        XCTAssertTrue(OfficerIssuanceState.waitingForYubikeyTouch(message: "Touch", step: 1, totalSteps: 2).isProcessing)
    }

    func testValidatingInputIsProcessing() {
        XCTAssertTrue(OfficerIssuanceState.validatingInput.isProcessing)
    }

    func testComputingCommitmentIsProcessing() {
        XCTAssertTrue(OfficerIssuanceState.computingCommitment.isProcessing)
    }

    func testCreatingAttestationIsProcessing() {
        XCTAssertTrue(OfficerIssuanceState.creatingAttestation.isProcessing)
    }

    func testFinalisingCredentialIsProcessing() {
        XCTAssertTrue(OfficerIssuanceState.finalisingCredential.isProcessing)
    }

    func testErrorIsNotProcessing() {
        XCTAssertFalse(OfficerIssuanceState.error(message: "fail", canRetry: false).isProcessing)
    }

    // MARK: - Decodable.from helpers

    func testDecodableFromJSONData() throws {
        let data = Data("{\"schema\":\"s\",\"validity_days\":1,\"v\":1}".utf8)
        let policy = try PolicyConfig.from(jsonData: data)
        XCTAssertEqual(policy.schema, "s")
    }

    // MARK: - OfficerError descriptions

    func testOfficerErrorDescriptions() {
        // Verify all cases produce non-nil descriptions
        let errors: [OfficerError] = [
            .sessionExpired, .sessionExpiring, .invalidCredentials,
            .invalidPolicy("test"), .yubikeyNotConnected, .yubikeyTimeout,
            .hmacFailed, .issuanceQuotaExceeded, .invalidOfficerIdFormat,
            .invalidChallenge, .noActiveSession, .verificationIncomplete,
            .invalidDateFormat, .userTooYoung, .officerKeyNotFound
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) must have a description")
        }
    }
}
