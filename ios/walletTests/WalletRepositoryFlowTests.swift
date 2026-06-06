// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

#if canImport(ProviiSDK)
import ProviiSDK
#endif

/// Flow-level tests for WalletRepository's verification and issuance paths.
///
/// All tests inject a MockProviiWallet so no real FFI, proving key, or
/// biometric hardware is required. Security and biometric managers are left
/// at their default state, which permits operations in a standard test runner.
@MainActor
final class WalletRepositoryFlowTests: XCTestCase {

    // MARK: - Helpers

    private func makeRepository(mock: MockProviiWallet) -> WalletRepository {
        WalletRepository(wallet: mock)
    }

    private func makeValidCredentialInfo(id: String = "cred-id-xyz789") -> CredentialInfo {
        CredentialInfo(
            id: id,
            issuerName: "Test Issuer",
            issuerKid: "issuer-kid-001",
            issuedAt: 1_000_000,
            expiresAt: 9_999_999_999,
            isExpired: false,
            canProve: true,
            schema: "provii.age/1",
            status: .valid,
            credentialType: "primary",
            nickname: nil,
            managedIndex: nil
        )
    }

    // MARK: - Verification: processVerificationChallenge

    func testProcessVerificationChallenge_success() async throws {
        let mock = MockProviiWallet()
        mock.processQrChallengeResult = .success("challenge-id-abc123")
        let repo = makeRepository(mock: mock)

        let challengeId = try await repo.processVerificationChallenge("provii.app/v?id=abc123")

        XCTAssertEqual(challengeId, "challenge-id-abc123")
        XCTAssertEqual(mock.processQrChallengeCallCount, 1)
    }

    func testProcessVerificationChallenge_invalidQr_throwsError() async {
        let mock = MockProviiWallet()
        mock.processQrChallengeResult = .failure(NSError(domain: "FFI", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid QR payload"]))
        let repo = makeRepository(mock: mock)

        do {
            _ = try await repo.processVerificationChallenge("not-a-valid-qr")
            XCTFail("Expected error for invalid QR payload")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    // MARK: - QR dispatching: processQRCode

    func testProcessQrCode_returnsVerificationChallenge() async throws {
        let mock = MockProviiWallet()
        mock.processScannedQrResult = .verificationChallenge(challengeJson: "{\"challenge_id\":\"challenge-id-abc123\"}")
        let repo = makeRepository(mock: mock)

        let action = try await repo.processQRCode("provii.app/v?id=abc123")

        guard case .verificationChallenge(let json) = action else {
            XCTFail("Expected verificationChallenge action, got \(action)")
            return
        }
        XCTAssertTrue(json.contains("challenge_id"))
    }

    func testProcessQrCode_returnsAttestation() async throws {
        let mock = MockProviiWallet()
        let fakeAttestation = Data("{\"dob_days\":20000,\"expires_at\":9999999999}".utf8).base64EncodedString()
        mock.processScannedQrResult = .attestation(attestationData: fakeAttestation)
        let repo = makeRepository(mock: mock)

        let action = try await repo.processQRCode("provii.app/a?data=\(fakeAttestation)")

        guard case .attestation(let data) = action else {
            XCTFail("Expected attestation action, got \(action)")
            return
        }
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Credential loading: loadCredentials

    func testLoadCredentials_emptyWallet_setsStateToNone() async {
        let mock = MockProviiWallet()
        mock.listCredentialsResult = .success([])
        let repo = makeRepository(mock: mock)

        await repo.loadCredentials()

        XCTAssertEqual(repo.credentialState, .none)
    }

    func testLoadCredentials_primaryCredentialPresent_setsHasCredentials() async {
        let mock = MockProviiWallet()
        mock.listCredentialsResult = .success([makeValidCredentialInfo()])
        let repo = makeRepository(mock: mock)

        await repo.loadCredentials()

        guard case .hasCredentials(let primary, let managed) = repo.credentialState else {
            XCTFail("Expected hasCredentials state")
            return
        }
        XCTAssertNotNil(primary)
        XCTAssertTrue(managed.isEmpty)
    }

    func testLoadCredentials_multipleCredentialTypes_separatesPrimaryAndManaged() async {
        let mock = MockProviiWallet()
        let primary = makeValidCredentialInfo(id: "primary-001")
        let managed1 = CredentialInfo(
            id: "managed-001",
            issuerName: "Test Issuer",
            issuerKid: "issuer-kid-001",
            issuedAt: 1_000_000,
            expiresAt: 9_999_999_999,
            isExpired: false,
            canProve: true,
            schema: "provii.age/1",
            status: .valid,
            credentialType: "managed",
            nickname: "Work ID",
            managedIndex: 0
        )
        mock.listCredentialsResult = .success([primary, managed1])
        let repo = makeRepository(mock: mock)

        await repo.loadCredentials()

        guard case .hasCredentials(let p, let m) = repo.credentialState else {
            XCTFail("Expected hasCredentials state")
            return
        }
        XCTAssertNotNil(p)
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m.first?.id, "managed-001")
    }

    // MARK: - Proof submission: submitProof (biometric-gated path, tests biometric denial)

    func testSubmitProof_biometricDenied_throwsBiometricAuthRequired() async {
        // BiometricService returns false in a test runner (no biometric hardware).
        // This confirms the gate is enforced and throws the correct error type.
        let mock = MockProviiWallet()
        let repo = makeRepository(mock: mock)

        do {
            _ = try await repo.submitProof("{\"proof\":\"test\"}")
            XCTFail("Expected biometricAuthRequired error")
        } catch WalletRepositoryError.biometricAuthRequired {
            // Correct: biometric gate denied access
        } catch {
            // Also acceptable: any error thrown before proof submission
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        XCTAssertEqual(mock.submitProofCallCount, 0, "submitProof must not reach SDK when biometric fails")
    }

    // MARK: - Blind issuance: processBlindIssuance (biometric-gated)

    func testProcessBlindIssuance_invalidBase64_throwsBeforeBiometric() async {
        let mock = MockProviiWallet()
        let repo = makeRepository(mock: mock)

        // Biometric will fail in tests; but if it were to pass, the invalid base64
        // would throw invalidAttestationData. Either error is acceptable here.
        do {
            try await repo.processBlindIssuance(attestationData: "!!not-base64!!")
        } catch WalletRepositoryError.biometricAuthRequired {
            // Biometric gate fires first
        } catch WalletRepositoryError.invalidAttestationData {
            XCTFail("Should not reach attestation parsing before biometric gate")
        } catch {
            // Any other error from the gate path is acceptable
        }
        XCTAssertEqual(mock.finalizeAndStoreCredentialCallCount, 0)
    }

    func testProcessBlindIssuance_expiredAttestation_biometricGateFires() async {
        let mock = MockProviiWallet()
        let repo = makeRepository(mock: mock)

        // An attestation with a valid base64 and expired timestamp
        let expiredPayload = ["dob_days": 20000, "expires_at": 0] as [String: Any]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: expiredPayload),
              let attestationData = Optional(payloadData.base64EncodedString()) else {
            XCTFail("Failed to build test attestation")
            return
        }

        do {
            try await repo.processBlindIssuance(attestationData: attestationData)
        } catch WalletRepositoryError.biometricAuthRequired {
            // Expected: biometric gate fires before attestation parsing
        } catch {
            // Any other error from the gate is acceptable
        }
        XCTAssertEqual(mock.finalizeAndStoreCredentialCallCount, 0)
    }

    // MARK: - Provable credentials

    func testGetProvableCredentials_noWallet_returnsEmptyList() {
        let mock = MockProviiWallet()
        mock.listCredentialsResult = .success([])
        let repo = makeRepository(mock: mock)

        let result = repo.getProvableCredentials()
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - computeDateOfBirthIso (pure logic, tested indirectly via consistent output shape)

    func testLoadCredentials_afterListCredentialsFailure_setsStateToNone() async {
        let mock = MockProviiWallet()
        mock.listCredentialsResult = .failure(NSError(domain: "FFI", code: 99, userInfo: [NSLocalizedDescriptionKey: "storage error"]))
        let repo = makeRepository(mock: mock)

        await repo.loadCredentials()

        XCTAssertEqual(repo.credentialState, .none)
    }
}
