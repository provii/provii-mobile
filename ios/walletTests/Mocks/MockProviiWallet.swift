// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
@testable import ProviiWallet

#if canImport(ProviiSDK)
import ProviiSDK
#endif

// MARK: - MockProviiWallet

/// Test double for ProviiWalletProtocol. All methods return canned values by
/// default. Override individual closures to simulate error conditions or
/// inspect call arguments.
final class MockProviiWallet: ProviiWalletProtocol, @unchecked Sendable {

    // MARK: - Configuration

    var processQrChallengeResult: Result<String, Error> = .success("challenge-id-abc123")
    var createAgeProofResult: Result<String, Error> = .success("{\"proof\":\"valid\",\"challenge_id\":\"challenge-id-abc123\",\"credential_id\":\"cred-id-xyz789\"}")
    var submitProofResult: Result<Bool, Error> = .success(true)
    var listCredentialsResult: Result<[CredentialInfo], Error> = .success([])
    var finalizeAndStoreCredentialResult: Result<String, Error> = .success("stored-cred-id-001")
    var getCredentialResult: String? = "{\"id\":\"cred-id-xyz789\",\"credentialType\":\"primary\"}"
    var getDiagnosticInfoValue: DiagnosticInfo = DiagnosticInfo(
        sdkVersion: "0.0.0-test",
        appVersion: "1.0.0",
        platform: "iOS",
        proverInitialized: true,
        credentialCount: 0,
        storageAvailable: true,
        configEnvironment: "test",
        lastProofGenerated: nil
    )
    var processScannedQrResult: QrAction = .verificationChallenge(challengeJson: "{\"challenge_id\":\"challenge-id-abc123\"}")
    var processManualEntryResult: Result<String, Error> = .success("challenge-id-abc123")

    // MARK: - Call tracking

    var processQrChallengeCallCount = 0
    var createAgeProofCallCount = 0
    var submitProofCallCount = 0
    var finalizeAndStoreCredentialCallCount = 0

    // MARK: - ProviiWalletProtocol conformance

    func processQrChallenge(qrContent: String) throws -> String {
        processQrChallengeCallCount += 1
        switch processQrChallengeResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func processScannedQr(qrContent: String) throws -> QrAction {
        return processScannedQrResult
    }

    func processManualEntry(input: String) throws -> String {
        switch processManualEntryResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func createAgeProof(credentialId: String, challengeId: String) throws -> String {
        createAgeProofCallCount += 1
        switch createAgeProofResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func createAgeProofAuto(challengeId: String) throws -> String {
        switch createAgeProofResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func submitProof(proofJson: String) throws -> Bool {
        submitProofCallCount += 1
        switch submitProofResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func listCredentials() throws -> [CredentialInfo] {
        switch listCredentialsResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func getCredential(credentialId: String) throws -> String? {
        return getCredentialResult
    }

    func getDiagnosticInfo() -> DiagnosticInfo {
        getDiagnosticInfoValue
    }

    // swiftlint:disable:next function_parameter_count
    func finalizeAndStoreCredential(
        headerJson: String,
        dobDays: Int32,
        rBitsB64: String,
        label: String?,
        credentialType: String,
        nickname: String?
    ) throws -> String {
        finalizeAndStoreCredentialCallCount += 1
        switch finalizeAndStoreCredentialResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    func storeCredentialWithLabel(
        credentialJson: String,
        label: String?,
        credentialType: String,
        nickname: String?
    ) throws -> String {
        return "stored-cred-id-002"
    }

    func deleteCredential(credentialId: String) throws {}

    func deleteSandboxCredentials() throws {}

    func updateCredentialNickname(credentialId: String, nickname: String?) throws {}

    func storeCredential(credentialJson: String) throws -> String {
        return "stored-cred-id-003"
    }

    func importCredential(credentialJson: String) throws -> String {
        return "imported-cred-id-001"
    }

    func importCredentialWithType(credentialJson: String, credentialType: String, nickname: String?) throws -> String {
        return "imported-cred-id-002"
    }

    func initializeProver(pkBytes: Data) throws {}

    func isBiometricAvailable() -> Bool {
        return true
    }

    func setStorageHandle(handle: SecureStorageHandle) throws {}

    func setVerifierBaseUrl(baseUrl: String) throws {}

    func getVerifierBaseUrl() -> String {
        return "https://verifier.example.test"
    }

    func getConfig() -> WalletConfig {
        return WalletConfig(
            autoSelect: true,
            networkTimeout: 30,
            cacheProvingKeys: false,
            issuerApiUrl: "https://issuer.example.test",
            verifierApiUrl: "https://verifier.example.test",
            verifierApiKey: nil,
            verifierOrigin: nil,
            environment: "test",
            enableParallelProver: false,
            maxProverThreads: 1 as UInt8
        )
    }

    func updateConfig(config: WalletConfig) throws {}

    func getAvailableSlotCount() throws -> UInt8 {
        return 1
    }

    func hasValidCredential() -> Bool {
        return false
    }

    func hasCredentialSecrets(credentialId: String) throws -> Bool {
        return true
    }

    func getProvableCredentialsForChallenge(challengeId: String) throws -> [CredentialSuitability] {
        return []
    }

    func getVerificationStatus() -> VerificationStatus {
        return VerificationStatus.notStarted
    }

    func cancelVerification(challengeId: String) throws {}

    func cleanupExpiredChallenges() -> UInt32 {
        return 0
    }

    func cleanupExpiredCredentials() -> UInt32 {
        return 0
    }

    func calculateAgeFromDob(dobIso: String) throws -> UInt32 {
        return 25
    }

    func checkNetworkStatus() -> NetworkStatus {
        return NetworkStatus(connected: true)
    }

    func createProgressTracker() -> ProgressTracker {
        fatalError("createProgressTracker not implemented in MockProviiWallet")
    }

    func reportProgress(tracker: ProgressTracker, stage: ProgressStage, message: String) {}

    func debugPreflight(credentialId: String, challengeId: String) throws -> String {
        return "{\"status\":\"ok\"}"
    }

    func diagnoseProofFailure(credentialId: String, challengeId: String) throws -> String {
        return "{\"diagnosis\":\"none\"}"
    }

    func fetchChallengeByShortCode(shortCode: String) throws -> String {
        return "{\"challenge_id\":\"challenge-id-abc123\"}"
    }

    func fetchChallengeDetails(challengeId: String) throws -> String {
        return "{\"challenge_id\":\"\(challengeId)\"}"
    }

    func getChallengeDiagnostics(challengeId: String) throws -> String {
        return "{\"cutoff_days\":6570}"
    }

    func handleDeeplink(url: String) throws -> DeeplinkAction {
        return DeeplinkAction.scanChallenge(payloadJson: "{\"challenge_id\":\"challenge-id-abc123\"}")
    }

    func parseQr(qrContent: String) throws -> String {
        return "{\"type\":\"verification_challenge\"}"
    }

    func parseQrPayload(qrContent: String) throws -> String {
        return "{\"type\":\"verification_challenge\"}"
    }

    func validateQr(qrContent: String) throws -> Bool {
        return true
    }

    func emergencyZeroize() {}

    func refreshIssuerKeys(jwksJson: String) throws {}
}
