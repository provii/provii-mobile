// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import Combine
import UIKit

#if canImport(ProviiSDK)
import ProviiSDK
#endif

/// Central repository that owns the `ProviiWallet` instance and mediates all credential lifecycle
/// operations: issuance (blind attestation and sandbox), storage, proof generation, verification
/// challenge processing, and deletion. Every sensitive operation is gated behind biometric
/// authentication and a runtime security check. The proving key download/initialisation state
/// machine is also managed here, exposing progress via the published `setupState` property.

@MainActor
class WalletRepository: ObservableObject {
    static let shared = WalletRepository()

    // MARK: - Published Properties
    @Published private(set) var credentialState: CredentialState = .none
    @Published private(set) var isProcessing = false
    @Published private(set) var setupState: SetupState = .notStarted
    @Published private(set) var biometricEnabled = false

    // MARK: - Private Properties
    private var wallet: (any ProviiWalletProtocol)?
    private var proverInitialised = false
    private var proverNeedsReload = false
    private var lastProverInitTime: Date?
    private var initialisationTask: Task<Void, Error>?
    private var isInitialised = false

    // Dynamic URLs from EnvironmentManager
    private var issuerBaseURL: String {
        EnvironmentManager.shared.issuerApi
    }

    private var cdnProvingKeyURL: String {
        EnvironmentManager.shared.cdnProvingKey
    }

    private let vkID = 2031517468
    private var provingKeyFilename: String { "age_pk.\(vkID).bin" }

    private struct SandboxConstants {
        static let schema = "provii.age/1"
        static let label = "sandbox"
        static let maxValidityDays = 36500
        static let defaultValidityDays = 36500
    }

    // MARK: - Types
    enum CredentialState: Equatable {
        case none
        case hasCredentials(primary: StoredCredential?, managed: [StoredCredential])
    }

    enum SetupState: Equatable {
        case notStarted
        case checking
        case downloading(progress: Float, downloadedMB: Float, totalMB: Float)
        case initialising
        case ready
        case error(message: String, canRetry: Bool, requiresAction: SetupAction? = nil)
    }

    enum SetupAction: Equatable {
        case freeStorage
        case checkNetwork
        case contactSupport
    }

    enum QRAction {
        case verificationChallenge(challengeJson: String)
        case attestation(attestationData: String)
        case unknown
        case error(message: String)
    }

    // MARK: - Initialisation
    private init() {
        // Listen for environment changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnvironmentChange),
            name: .proviiEnvironmentChanged,
            object: nil
        )
    }

    /// Injects a pre-constructed wallet instance for unit testing.
    /// Not for production use.
    @MainActor
    internal init(wallet: any ProviiWalletProtocol) {
        self.wallet = wallet
        self.isInitialised = true
        self.proverInitialised = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEnvironmentChange() {
        // Mark prover as needing reload when environment changes
        proverNeedsReload = true
        // Force re-initialisation so verifier URL and sandbox config are refreshed
        isInitialised = false
    }

    // MARK: - Prover Lifecycle

    /// Mark prover as stale (needs reload on next use).
    /// Called when app returns from background.
    func markProverStale() {
        proverNeedsReload = true
    }

    /// Check if prover needs reload and reinitialise if necessary
    private func reloadProverIfNeeded() async throws {
        guard proverNeedsReload else { return }

        proverInitialised = false
        try await ensureProverInitialised()
        proverNeedsReload = false
    }

    // MARK: - Wallet Management
    func initialiseWallet() async throws {
        // Fast path: already initialised and wallet is valid
        if isInitialised, wallet != nil {
            return
        }

        // Join path: another caller already started initialisation, await its result
        if let existing = initialisationTask {
            try await existing.value
            return
        }

        // Create path: no initialisation in progress, start one.
        // @MainActor guarantees no TOCTOU between the nil check above and
        // the assignment below (no await between them).
        let task = Task { @MainActor in
            try await performInitialisation()
        }
        initialisationTask = task

        do {
            try await task.value
            isInitialised = true
            initialisationTask = nil
        } catch {
            isInitialised = false
            initialisationTask = nil
            // If the wallet was partially constructed before the error,
            // nil it so the next attempt starts fresh.
            wallet = nil
            throw error
        }
    }

    /// Performs the actual wallet initialisation work. Called exactly once per
    /// successful initialisation cycle via the task-join guard above.
    private func performInitialisation() async throws {
        // Check if wallet already exists and is valid
        if let existingWallet = wallet {
            do {
                let diagnostics = existingWallet.getDiagnosticInfo()

                // Always update verifier URL in case environment changed
                let verifierUrl = EnvironmentManager.shared.verifierApi
                try existingWallet.setVerifierBaseUrl(baseUrl: verifierUrl)

                if diagnostics.proverInitialized && !proverNeedsReload {
                    await configureWalletForSandbox()
                    await checkCredential()
                    return
                } else {
                    try await ensureProverInitialised()
                    proverNeedsReload = false
                    await configureWalletForSandbox()
                    await checkCredential()
                    return
                }
            } catch {
                wallet = nil
                proverInitialised = false
            }
        }

        let documentsPath = try getDocumentsDirectory().path

        // Check proving key
        guard provingKeyIsAvailable(appFilesDir: documentsPath) else {
            throw WalletRepositoryError.provingKeyNotAvailable
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let appInfo = AppInfo(
            version: version,
            buildNumber: buildNumber,
            platform: "iOS",
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion
        )

        // Create wallet
        let newWallet = ProviiWallet(appInfo: appInfo)

        // Set storage handle
        let secureStore = try createDefaultSecureStore()
        try newWallet.setStorageHandle(handle: secureStore)

        // Set verifier URL based on environment
        let verifierUrl = EnvironmentManager.shared.verifierApi
        try newWallet.setVerifierBaseUrl(baseUrl: verifierUrl)

        wallet = newWallet

        // Initialise prover
        try await ensureProverInitialised()
        proverNeedsReload = false

        // Configure sandbox verifier credentials if needed
        await configureWalletForSandbox()

        // Verify storage
        _ = try newWallet.listCredentials()

        await checkCredential()
    }

    private func ensureProverInitialised() async throws {
        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        // Check if already initialised
        let diagnostics = w.getDiagnosticInfo()
        if diagnostics.proverInitialized && proverInitialised && !proverNeedsReload {
            return
        }

        let documentsPath = try getDocumentsDirectory().path
        let pkFile = URL(fileURLWithPath: documentsPath).appendingPathComponent(provingKeyFilename)

        guard FileManager.default.fileExists(atPath: pkFile.path) else {
            throw WalletRepositoryError.provingKeyNotFound
        }

        do {
            let pkData = try Data(contentsOf: pkFile)

            // Try wallet method first
            do {
                try w.initializeProver(pkBytes: pkData)
            } catch {
                try sdkInitProver(pkBytes: pkData)
            }

            // Verify initialisation
            let postInitDiagnostics = w.getDiagnosticInfo()
            if postInitDiagnostics.proverInitialized {
                proverInitialised = true
                proverNeedsReload = false
                lastProverInitTime = Date()
            } else {
                proverInitialised = false
                throw WalletRepositoryError.proverInitialisationFailed
            }

        } catch {
            proverInitialised = false
            throw error
        }
    }

    /// Configure wallet with the per-install sandbox credential when sandbox
    /// is active. the gateway returns `client_id` (doubles as
    /// verifier api key) and `hmac_secret`; the verifier base URL and origin
    /// come from the sandbox entry in `api-endpoints.json`.
    private func configureWalletForSandbox() async {
        guard let w = wallet, EnvironmentManager.shared.isSandboxEnabled else { return }

        do {
            let credential = try await SandboxCredentialFetcher.shared.currentCredential()
            let currentConfig = w.getConfig()
            let updatedConfig = WalletConfig(
                autoSelect: currentConfig.autoSelect,
                networkTimeout: currentConfig.networkTimeout,
                cacheProvingKeys: currentConfig.cacheProvingKeys,
                issuerApiUrl: currentConfig.issuerApiUrl,
                verifierApiUrl: currentConfig.verifierApiUrl,
                verifierApiKey: credential.clientId,
                verifierOrigin: currentConfig.verifierOrigin,
                environment: currentConfig.environment,
                enableParallelProver: currentConfig.enableParallelProver,
                maxProverThreads: currentConfig.maxProverThreads
            )
            try w.updateConfig(config: updatedConfig)
        } catch {
            SecureLogger.shared.error("Failed to configure sandbox credential: \(error.localizedDescription)")
        }
    }

    // MARK: - Biometric Gate

    /// Require biometric authentication before proceeding with a sensitive operation.
    /// Fails CLOSED: if biometrics are unavailable or the user declines, this throws
    /// and the calling operation MUST NOT proceed.
    /// Secure Enclave key tag used for biometric key-binding during wallet operations.
    /// The key is created on first use and tied to `.biometryCurrentSet`, so re-enrolment
    /// of biometrics invalidates it automatically.
    private static let walletBiometricKeyTag = "app.provii.wallet.biometric.wallet-ops"

    private func requireBiometric(reason: String) async throws {
        // SECURITY: Re-check for runtime threats (debugger attach, Frida injection)
        // before every sensitive operation to catch post-startup attacks.
        guard SecurityManager.shared.shouldAllowOperation() else {
            throw WalletRepositoryError.securityCheckFailed
        }

        // SECURITY (MASVS-003): Use key-bound biometric authentication instead of
        // policy-only evaluation. This creates/uses a Secure Enclave P-256 key
        // protected by .biometryCurrentSet, which cryptographically proves biometric
        // presence rather than relying on LAContext policy evaluation alone.
        let authenticated = await BiometricService.shared.authenticateWithKeyBinding(
            reason: reason,
            keyTag: Self.walletBiometricKeyTag
        )
        if !authenticated {
            AuditLogger.shared.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "biometric_gate_denied",
                "operation": reason
            ])
            throw WalletRepositoryError.biometricAuthRequired
        }
    }

    // MARK: - Credential Management

    /// Process blind attestation issuance.
    ///
    /// This is the privacy preserving flow where:
    /// 1. Officer/sandbox creates a signed attestation containing only dob_days
    /// 2. User scans the attestation QR code
    /// 3. Wallet generates r_bits locally (officer never sees this)
    /// 4. Wallet calls /v1/issuance/blind with attestation + commitment
    /// 5. Server verifies attestation and signs the credential
    ///
    /// SECURITY: Requires biometric authentication before storing credentials
    func processBlindIssuance(
        attestationData: String,
        credentialType: String = "primary",
        nickname: String? = nil
    ) async throws {
        // SECURITY: Gate before credential issuance (writes to secure storage)
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.store_credential", comment: "Authenticate to store a new credential")
        )

        isProcessing = true
        defer { isProcessing = false }

        // Ensure wallet is initialised
        if wallet == nil {
            try await initialiseWallet()
        }

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        // Step 1: Decode and validate attestation

        // Size cap: reject oversized payloads before decoding (QR path allows up to 10,000 chars)
        guard attestationData.count <= 4096 else {
            SecureLogger.shared.error("Attestation string exceeds 4096 character limit (length=\(attestationData.count))", redact: false)
            throw WalletRepositoryError.invalidAttestationData
        }

        guard let attestationBytes = Data(base64Encoded: attestationData,
                                          options: .ignoreUnknownCharacters) else {
            SecureLogger.shared.error("Failed to decode attestation base64", redact: false)
            throw WalletRepositoryError.invalidAttestationData
        }

        guard let attestationJson = try? JSONSerialization.jsonObject(with: attestationBytes) as? [String: Any] else {
            SecureLogger.shared.error("Failed to parse attestation as JSON", redact: false)
            throw WalletRepositoryError.invalidAttestationData
        }

        // Required field presence check
        let requiredFields = ["dob_days", "issuer_id", "timestamp", "nonce"]
        let missingFields = requiredFields.filter { attestationJson[$0] == nil }
        guard missingFields.isEmpty else {
            SecureLogger.shared.error("Attestation missing required fields: \(missingFields)", redact: false)
            throw WalletRepositoryError.invalidAttestationData
        }

        // Unknown field warning (log only, hard rejection breaks forward compatibility)
        let knownFields: Set<String> = ["dob_days", "issuer_id", "timestamp", "nonce", "expires_at", "signature"]
        let unknownFields = Set(attestationJson.keys).subtracting(knownFields)
        if !unknownFields.isEmpty {
            SecureLogger.shared.warning("Attestation contains unknown fields (ignored for forward compatibility): \(unknownFields.sorted())", redact: false)
        }

        guard let dobDays = attestationJson["dob_days"] as? Int else {
            SecureLogger.shared.error("Attestation dob_days field is missing or not an integer", redact: false)
            throw WalletRepositoryError.invalidAttestationData
        }

        // dob_days range validation (matches server create_attestation bounds exactly)
        guard dobDays >= -25000 && dobDays <= 36500 else {
            SecureLogger.shared.error("Attestation dob_days=\(dobDays) is outside valid range [-25000, 36500]", redact: false)
            throw WalletRepositoryError.invalidAttestationData
        }

        // Step 2: Generate r_bits and compute commitment locally
        // This is the critical privacy step - r_bits never leaves the device
        // SEC: commitmentJson is an ephemeral UniFFI JSON boundary; fields extracted inline
        let commitmentJson = try sdkIssueComputeCommitment(dobIsoOrDays: String(dobDays))
        let commitmentData = Data(commitmentJson.utf8)
        guard let commitmentObj = try JSONSerialization.jsonObject(with: commitmentData) as? [String: Any],
              let commitDobDays = commitmentObj["dob_days"] as? Int,
              let commitRBits = commitmentObj["r_bits"] as? String else {
            throw WalletRepositoryError.invalidAttestationData
        }

        // Step 3: Call blind issuance via SDK (matches Android's sdkIssueBlind)
        let headerJson = try sdkIssueBlind(
            baseUrl: issuerBaseURL,
            attestationB64: attestationData,
            rBitsB64: commitRBits
        )

        // Step 4: Finalise credential with the signed header, passing type
        // and nickname. The returned credential id is unused at this layer:
        // the caller refreshes via loadCredentials() below, and the FFI
        // method already persists the credential side-effectfully.
        _ = try w.finalizeAndStoreCredential(
            headerJson: headerJson,
            dobDays: Int32(commitDobDays),
            rBitsB64: commitRBits,
            label: nil,
            credentialType: credentialType,
            nickname: nickname
        )

        // Update state
        await loadCredentials()
    }

    /// SECURITY: Requires biometric authentication before storing credentials
    func storeSandboxCredential(_ credentialJson: String) async throws -> String {
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.store_credential", comment: "Authenticate to store a new credential")
        )

        if wallet == nil {
            try await initialiseWallet()
        }
        guard let wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }
        let credentialId = try wallet.storeCredentialWithLabel(
            credentialJson: credentialJson,
            label: SandboxConstants.label,
            credentialType: "primary",
            nickname: nil
        )
        await loadCredentials()
        return credentialId
    }

    /// SECURITY: Requires biometric authentication before deleting sandbox credentials
    func deleteSandboxCredentials() async throws {
        guard let wallet else { return }

        // SECURITY: Re-check for runtime threats before credential deletion
        guard SecurityManager.shared.shouldAllowOperation() else {
            throw WalletRepositoryError.securityCheckFailed
        }

        let authenticated = await BiometricService.shared.authenticate(
            reason: NSLocalizedString("biometric.reason.delete_credential", comment: "Authenticate to delete credentials")
        )
        guard authenticated else {
            AuditLogger.shared.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "biometric_gate_denied",
                "operation": "deleteSandboxCredentials"
            ])
            throw WalletRepositoryError.biometricAuthRequired
        }

        do {
            try wallet.deleteSandboxCredentials()
            await loadCredentials()
        } catch {
            AuditLogger.shared.logSecurityEvent(.credentialDeletionFailed, details: [
                "operation": "deleteSandboxCredentials",
                "error": error.localizedDescription
            ])
            SecureLogger.shared.error("Failed to delete sandbox credentials: \(error.localizedDescription)")
            throw error
        }
    }

    /// SECURITY: Requires biometric authentication before generating and storing credentials
    func generateSandboxCredential(
        ageYears: Int,
        dateOfBirth: Date? = nil,
        validityDays: Int = SandboxConstants.defaultValidityDays,
        credentialType: String = "primary",
        nickname: String? = nil
    ) async throws -> String {
        guard EnvironmentManager.shared.isSandboxEnabled else {
            throw WalletRepositoryError.sandboxModeRequired
        }

        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.store_credential", comment: "Authenticate to store a new credential")
        )

        // fetch the per-install credential from the mobile sandbox
        // gateway. `clientId` doubles as the issuer api key; `hmacSecret` is
        // the base64url HMAC secret returned by `/register`.
        let credential: SandboxCredential
        do {
            credential = try await SandboxCredentialFetcher.shared.currentCredential()
        } catch {
            throw WalletRepositoryError.credentialFetchFailed(error.localizedDescription)
        }

        if wallet == nil {
            try await initialiseWallet()
        }
        guard let wallet = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        // Decode HMAC secret (base64url-safe, matching Android)
        guard var hmacSecret = try? CryptoUtils.b64UrlDecode(credential.hmacSecret) else {
            throw WalletRepositoryError.sandboxSecretInvalid
        }
        defer { SensitiveDataHolder.zeroise(&hmacSecret) }
        let sandboxIssuerBaseUrl = EnvironmentManager.shared.issuerApi

        // Compute DOB days and r_bits
        let dobISO: String
        if let dateOfBirth {
            dobISO = try computeDateOfBirthIso(from: dateOfBirth)
        } else {
            let age = max(ageYears, 0)
            dobISO = try computeDateOfBirthIso(forAge: age)
        }
        // SEC: commitmentJson is an ephemeral UniFFI JSON boundary; fields extracted inline
        let commitmentJson = try sdkIssueComputeCommitment(dobIsoOrDays: dobISO)
        let commitmentData = Data(commitmentJson.utf8)
        guard let commitmentObj = try JSONSerialization.jsonObject(with: commitmentData) as? [String: Any],
              let sandboxDobDays = commitmentObj["dob_days"] as? Int,
              let sandboxRBits = commitmentObj["r_bits"] as? String else {
            throw WalletRepositoryError.invalidAttestationData
        }

        // Create attestation via provii-issuer using HMAC-SHA256 authentication
        let (authorizerJson, _) = try HmacSigner.createAttestationAuthorizer(
            secret: hmacSecret,
            dobDays: Int32(sandboxDobDays),
            format: "client",
            keyId: credential.clientId
        )
        let attestationResponseJson = try sdkCreateAttestation(
            baseUrl: sandboxIssuerBaseUrl,
            dobDays: Int32(sandboxDobDays),
            authorizerJson: authorizerJson
        )

        // Extract attestation from response
        guard let responseData = attestationResponseJson.data(using: .utf8),
              let responseObj = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let attestationB64 = responseObj["attestation"] as? String else {
            throw WalletRepositoryError.invalidAttestationData
        }

        // Submit attestation + r_bits to provii-issuer via SDK (matches Android's sdkIssueBlind)
        let headerJson = try sdkIssueBlind(
            baseUrl: sandboxIssuerBaseUrl,
            attestationB64: attestationB64,
            rBitsB64: sandboxRBits
        )

        // Finalise and store the credential directly with sandbox label
        let credentialId = try wallet.finalizeAndStoreCredential(
            headerJson: headerJson,
            dobDays: Int32(sandboxDobDays),
            rBitsB64: sandboxRBits,
            label: SandboxConstants.label,
            credentialType: credentialType,
            nickname: nickname
        )

        await loadCredentials()
        return credentialId
    }

    /// SECURITY: Requires biometric authentication before deleting credentials
    func deleteCredential(credentialId: String) async throws {
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.delete_credential", comment: "Authenticate to delete a credential")
        )

        try wallet?.deleteCredential(credentialId: credentialId)
        await loadCredentials()
    }

    /// Deletes all credentials (primary + managed) from the wallet.
    /// SECURITY: Requires biometric authentication before bulk deletion.
    func deleteAllCredentials() async throws {
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.delete_credential", comment: "Authenticate to delete credentials")
        )

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }
        let credentials = try w.listCredentials()
        for cred in credentials {
            try w.deleteCredential(credentialId: cred.id)
        }
        await loadCredentials()
    }

    /// Returns the list of all provable credentials in the current namespace
    func getProvableCredentials() -> [CredentialInfo] {
        guard !SecurityManager.shared.isDeviceCompromised else { return [] }
        guard let w = wallet else { return [] }
        do {
            return try w.listCredentials().filter { $0.canProve }
        } catch {
            return []
        }
    }

    /// Get available credential slot count in the current namespace
    func getAvailableSlotCount() throws -> Int {
        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }
        return Int(try w.getAvailableSlotCount())
    }

    /// Returns provable credentials with suitability info for a specific challenge
    func getProvableCredentialsForChallenge(challengeId: String) throws -> [CredentialSuitability] {
        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }
        return try w.getProvableCredentialsForChallenge(challengeId: challengeId)
    }

    /// Update the nickname of a credential (metadata-only write).
    /// SECURITY: Requires biometric authentication before modifying credential data.
    func updateCredentialNickname(credentialId: String, nickname: String?) async throws {
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.modify_credential", comment: "Authenticate to modify credential")
        )

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }
        try w.updateCredentialNickname(credentialId: credentialId, nickname: nickname)
        await loadCredentials()
    }

    func loadCredentials() async {
        guard let w = wallet else { return }

        do {
            let credentials = try w.listCredentials()
            if credentials.isEmpty {
                credentialState = .none
            } else {
                let primary = credentials.first { $0.credentialType == "primary" }
                let managed = credentials.filter { $0.credentialType == "managed" }
                // Convert SDK CredentialInfo to StoredCredential for UI
                let primaryStored = primary.map { toStoredCredential($0) }
                let managedStored = managed.map { toStoredCredential($0) }
                credentialState = .hasCredentials(primary: primaryStored, managed: managedStored)
            }
        } catch {
            credentialState = .none
        }
    }

    private func toStoredCredential(_ info: CredentialInfo) -> StoredCredential {
        StoredCredential(
            id: info.id,
            issuerKid: info.issuerKid,
            issuerLabel: info.issuerName,
            issuedAt: Int64(info.issuedAt),
            expiresAt: Int64(info.expiresAt),
            schema: info.schema,
            credentialData: CredentialData(issuerVk: "", sigRj: "", cBytes: ""),
            credentialType: info.credentialType,
            nickname: info.nickname
        )
    }

    // MARK: - Verification
    func processVerificationChallenge(_ qrContent: String) async throws -> String {
        if wallet == nil {
            try await initialiseWallet()
        }

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        let challengeId = try w.processQrChallenge(qrContent: qrContent)

        return challengeId
    }

    /// Process manual entry input, detecting whether it's a 12-digit short code or UUID
    /// and fetching the appropriate challenge details.
    func processManualEntry(_ input: String) async throws -> String {
        if wallet == nil {
            try await initialiseWallet()
        }

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        // The SDK's processManualEntry method will detect if it's a short code or UUID
        let challengeId = try w.processManualEntry(input: input)

        return challengeId
    }

    func createAgeProof(credentialId: String, challengeId: String) async throws -> String {
        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        // SECURITY: Re-check for runtime threats before credential access
        guard SecurityManager.shared.shouldAllowOperation() else {
            throw WalletRepositoryError.securityCheckFailed
        }

        // SECURITY: Authenticate user before accessing credentials (matches Android)
        let authenticated = await BiometricService.shared.authenticate(
            reason: NSLocalizedString("biometric.reason.create_proof", comment: "Authenticate to verify your age")
        )
        if !authenticated {
            AuditLogger.shared.logVerificationAttempt(
                credentialId: credentialId,
                challengeId: challengeId,
                verifyUrl: "N/A",
                result: "auth_failed"
            )
            throw WalletRepositoryError.biometricAuthRequired
        }

        // Reload prover if stale
        try await reloadProverIfNeeded()

        // Ensure prover is initialised
        try await ensureProverInitialised()

        // Verify credential exists
        guard try w.getCredential(credentialId: credentialId) != nil else {
            throw WalletRepositoryError.credentialNotFound
        }

        // Generate proof
        do {
            let proofJson = try w.createAgeProof(
                credentialId: credentialId,
                challengeId: challengeId
            )

            return proofJson

        } catch {
            proverInitialised = false
            throw error
        }
    }

    /// SECURITY: Requires biometric authentication before submitting proofs.
    /// The proof JSON contains sensitive cryptographic material that must not be
    /// submitted without the credential holder's explicit biometric consent.
    func submitProof(_ proofJson: String) async throws -> Bool {
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.submit_proof", comment: "Authenticate to submit your age proof")
        )

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        let success = try w.submitProof(proofJson: proofJson)
        return success
    }

    func listCredentials() async throws -> [CredentialInfo] {
        guard !SecurityManager.shared.isDeviceCompromised else { return [] }
        if wallet == nil {
            _ = try await initialiseWallet()
        }
        guard let wallet = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }
        return try wallet.listCredentials()
    }

    // MARK: - QR Processing
    func processQRCode(_ qrContent: String) async throws -> QRAction {
        if wallet == nil {
            try await initialiseWallet()
        }

        guard let w = wallet else {
            throw WalletRepositoryError.walletNotInitialised
        }

        let action = try w.processScannedQr(qrContent: qrContent)

        switch action {
        case .verificationChallenge(let json):
            return .verificationChallenge(challengeJson: json)
        case .attestation(let data):
            return .attestation(attestationData: data)
        }
    }

    // MARK: - Proving Key Management
    func checkProvingKeyStatus() -> Bool {
        guard let documentsPath = try? getDocumentsDirectory().path else {
            return false
        }
        let available = provingKeyIsAvailable(appFilesDir: documentsPath)
        if available {
            // QA1719: defensively ensure the backup exclusion attribute is set on
            // every launch. Handles installs that predate this fix.
            excludeProvingKeyFromBackup()
        }
        return available
    }

    func downloadProvingKey() async throws {
        setupState = .checking

        let documentsPath = try getDocumentsDirectory().path

        if provingKeyIsAvailable(appFilesDir: documentsPath) {
            setupState = .ready
            return
        }

        // Check storage
        let availableBytes = getAvailableStorageBytes()
        let storageCheck = provingKeyCheckStorageWithBytes(
            appFilesDir: documentsPath,
            availableBytes: availableBytes
        )

        switch storageCheck {
        case .ready:
            break

        case .insufficientSpace(_, _, let message):
            setupState = .error(
                message: message,
                canRetry: false,
                requiresAction: .freeStorage
            )
            throw WalletRepositoryError.insufficientStorage(message: message)

        case .error(let message):
            setupState = .error(message: message, canRetry: true)
            throw WalletRepositoryError.storageCheckFailed(message: message)
        }

        setupState = .downloading(progress: 0, downloadedMB: 0, totalMB: 0)

        // Download with progress
        class ProgressHandler: ProvingKeyProgressListener {
            let repository: WalletRepository

            init(repository: WalletRepository) {
                self.repository = repository
            }

            func onProgress(bytesDownloaded: UInt64, totalBytes: UInt64, percentage: UInt8) {
                let downloadedMB = Float(bytesDownloaded) / (1024 * 1024)
                let totalMB = Float(totalBytes) / (1024 * 1024)
                let progress = Float(percentage) / 100.0

                Task { @MainActor in
                    self.repository.setupState = .downloading(
                        progress: progress,
                        downloadedMB: downloadedMB,
                        totalMB: totalMB
                    )
                }
            }
        }

        let progressHandler = ProgressHandler(repository: self)

        do {
            try provingKeyDownload(
                appFilesDir: documentsPath,
                progressListener: progressHandler
            )

            // Ensure UI updates to show initialising state
            self.setupState = .initialising

            // Small delay to ensure UI updates
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            try provingKeyInit(appFilesDir: documentsPath)

            // QA1719: exclude the proving key from iCloud backup immediately
            // after download. The file is ~52MB and re-downloadable on demand,
            // so backing it up wastes the user's iCloud quota.
            excludeProvingKeyFromBackup()

            self.setupState = .ready
        } catch {
            self.setupState = .error(
                message: error.localizedDescription,
                canRetry: true,
                requiresAction: nil
            )
            throw error
        }
    }
    func retryProvingKeyDownload() async throws {
        setupState = .notStarted
        try await downloadProvingKey()
    }

    func clearProvingKey() async throws {
        let documentsPath = try getDocumentsDirectory().path
        try provingKeyDelete(appFilesDir: documentsPath)
        setupState = .notStarted
        proverInitialised = false
        proverNeedsReload = false
        lastProverInitTime = nil
    }

    // MARK: - Debug Information

    /// Get debug information about wallet state
    func getDebugInfo() -> String {
        var info = """
        === Provii Wallet Debug Info ===

        Environment:
        - Current: \(EnvironmentManager.shared.getCurrentEnvironment)
        - Sandbox: \(EnvironmentManager.shared.isSandboxEnabled)

        URLs:
        - Issuer: \(issuerBaseURL)
        - Verifier: \(EnvironmentManager.shared.verifierApi)
        - Registry: \(EnvironmentManager.shared.issuersRegistry)
        - CDN: \(cdnProvingKeyURL)

        Credentials:
        - State: \(credentialState)

        Setup:
        - Proving key status: \(checkProvingKeyStatusSync())
        - Setup state: \(setupState)

        Prover:
        - Initialised: \(proverInitialised)
        - Needs reload: \(proverNeedsReload)
        - Last init: \(lastProverInitTime?.description ?? "never")

        SDK:
        """

        if let w = wallet {
            let diagnostics = w.getDiagnosticInfo()
            info += """

            - Wallet initialised: true
            - SDK prover initialised: \(diagnostics.proverInitialized)
            - Thread config: \(sdkDiagnoseThreadConfig())
            """
        } else {
            info += "\n- Wallet initialised: false"
        }

        info += """


        Storage:
        - Documents dir: \((try? getDocumentsDirectory().path) ?? "unavailable")
        - Available space: \(formatBytes(getAvailableStorageBytes()))

        Biometric:
        - Enabled: \(biometricEnabled)
        """

        return info
    }

    private func checkProvingKeyStatusSync() -> String {
        guard let documentsPath = try? getDocumentsDirectory().path else {
            return "unknown (documents directory unavailable)"
        }
        return provingKeyIsAvailable(appFilesDir: documentsPath) ? "available" : "not available"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.2f MB", mb)
    }

    // MARK: - Settings
    func setBiometricEnabled(_ enabled: Bool) async throws {
        if enabled {
            guard let w = wallet, w.isBiometricAvailable() else {
                throw WalletRepositoryError.biometricNotAvailable
            }

            let reason = NSLocalizedString("biometric_enable_title", comment: "")
            guard await BiometricService.shared.authenticate(reason: reason) else {
                throw WalletRepositoryError.authenticationFailed
            }
        }

        biometricEnabled = enabled
        try KeychainService.shared.saveBiometricEnabled(enabled)
    }

    /// SECURITY: Requires biometric authentication before wiping all wallet data.
    /// Clears credentials, Keychain entries, UserDefaults, issuer registry cache,
    /// sandbox credential cache, privacy preferences, and preserved form data.
    func clearAllData() async throws {
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.clear_all_data", comment: "Authenticate to erase all wallet data")
        )

        // Delete all credentials via SDK
        if let credentials = try wallet?.listCredentials() {
            for cred in credentials {
                try wallet?.deleteCredential(credentialId: cred.id)
            }
        }

        // Clear proving key
        try? await clearProvingKey()

        // Clear all Keychain entries (KeychainService owns app-level secrets,
        // KeychainBridge owns SDK-prefixed storage)
        KeychainService.shared.deleteAll()
        KeychainBridge.shared.clearAll()

        // Clear sandbox credential cache
        await SandboxCredentialFetcher.shared.clearCache()

        // Clear issuer registry cache (UserDefaults + in-memory)
        IssuersRepository.shared.clearCacheAndReset()

        // Clear privacy consent data
        PrivacyPreferences.shared.clearAllPrivacyData()

        // Clear preserved form data
        DataPreservationManager.shared.clearAll()

        // Wipe all remaining UserDefaults for this app
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        // Reset in-memory state
        credentialState = .none
        setupState = .notStarted
        biometricEnabled = false
        proverInitialised = false
        proverNeedsReload = false
        isInitialised = false
        initialisationTask = nil
        wallet = nil
    }

    // MARK: - Private Helpers

    /// Set `isExcludedFromBackup` on the proving key file so it is not uploaded
    /// to iCloud. The proving key is ~52MB and can be re-downloaded at any time,
    /// so backing it up wastes iCloud quota and violates Apple QA1719.
    ///
    /// Called both after a successful download and defensively on every app
    /// launch when the key already exists (to cover installs that predate this
    /// fix without requiring any migration logic).
    private func excludeProvingKeyFromBackup() {
        guard let documentsDir = try? getDocumentsDirectory() else { return }
        var pkURL = documentsDir.appendingPathComponent(provingKeyFilename)
        guard FileManager.default.fileExists(atPath: pkURL.path) else { return }
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try pkURL.setResourceValues(resourceValues)
        } catch {
            // Best-effort: log but do not propagate. The app remains functional
            // even if the attribute cannot be set (e.g. read-only filesystem in
            // a test harness).
            SecureLogger.shared.warning(
                "Failed to set isExcludedFromBackup on proving key: \(error.localizedDescription)",
                redact: false
            )
        }
    }

    private func checkCredential() async {
        await loadCredentials()
    }

    private func getDocumentsDirectory() throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw WalletRepositoryError.documentsDirectoryUnavailable
        }
        return documentsDirectory
    }

    private func getAvailableStorageBytes() -> UInt64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(
                forPath: try getDocumentsDirectory().path
            )
            return attributes[.systemFreeSize] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }

    private func decryptCredential(blob: String, key: String) throws -> String {
        return try CryptoUtils.decryptCredentialBlob(blob, key: key)
    }

    private func computeDateOfBirthIso(forAge ageYears: Int) throws -> String {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        guard let dob = calendar.date(byAdding: .year, value: -ageYears, to: today) else {
            throw WalletRepositoryError.sandboxIssuanceFailed("Unable to compute date of birth")
        }
        return try computeDateOfBirthIso(from: dob)
    }

    private func computeDateOfBirthIso(from date: Date) throws -> String {
        let calendar = Calendar(identifier: .gregorian)
        let clampedDate = min(date, Date())
        let components = calendar.dateComponents([.year, .month, .day], from: clampedDate)
        guard let normalizedDate = calendar.date(from: components) else {
            throw WalletRepositoryError.sandboxIssuanceFailed("Unable to normalise date of birth")
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        // Keep en_US_POSIX ONLY for ISO 8601 API/data parsing, NOT for display
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: normalizedDate)
    }
}

// MARK: - Issue Helper Models

private struct IssueSession: Decodable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

// MARK: - Error Types
enum WalletRepositoryError: LocalizedError {
    case walletNotInitialised
    case provingKeyNotAvailable
    case provingKeyNotFound
    case proverInitialisationFailed
    case credentialNotFound
    case biometricNotAvailable
    case authenticationFailed
    case insufficientStorage(message: String)
    case storageCheckFailed(message: String)
    case notImplemented
    case sandboxModeRequired
    case sandboxSecretInvalid
    case sandboxIssuanceFailed(String)
    case credentialFetchFailed(String)
    case invalidAttestationData
    case invalidURL
    case networkError
    case serverError(statusCode: Int, message: String)
    case biometricAuthRequired
    case securityCheckFailed
    case documentsDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .walletNotInitialised:
            return LocalizedString.errorWalletNotInitialized.localized
        case .provingKeyNotAvailable:
            return LocalizedString.errorProvingKeyNotAvailable.localized
        case .provingKeyNotFound:
            return LocalizedString.errorProvingKeyNotFound.localized
        case .proverInitialisationFailed:
            return LocalizedString.errorProverInitFailed.localized
        case .credentialNotFound:
            return LocalizedString.errorCredentialNotFound.localized
        case .biometricNotAvailable:
            return LocalizedString.errorBiometricNotAvailable.localized
        case .authenticationFailed:
            return LocalizedString.errorAuthenticationFailed.localized
        case .insufficientStorage(let message):
            return message
        case .storageCheckFailed(let message):
            return message
        case .notImplemented:
            return LocalizedString.errorFeatureNotImplemented.localized
        case .sandboxModeRequired:
            return LocalizedString.errorEnableSandboxMode.localized
        case .sandboxSecretInvalid:
            return LocalizedString.errorSandboxSecretInvalid.localized
        case .sandboxIssuanceFailed(let reason):
            return LocalizedString.errorSandboxGenerationFailed.localized(reason)
        case .credentialFetchFailed(let reason):
            return LocalizedString.errorSandboxFetchFailed.localized(reason)
        case .invalidAttestationData:
            return NSLocalizedString("error.invalid_attestation", comment: "Invalid attestation data")
        case .invalidURL:
            return NSLocalizedString("error.invalid_server_url", comment: "Invalid server URL")
        case .networkError:
            return NSLocalizedString("error.network_error", comment: "Network error occurred")
        case .serverError(let statusCode, let message):
            return String(format: NSLocalizedString("error.server_error", comment: "Server error (%d): %@"), statusCode, message)
        case .biometricAuthRequired:
            return NSLocalizedString("error.biometric_auth_required", comment: "Biometric authentication is required to create an age proof")
        case .securityCheckFailed:
            return NSLocalizedString("error.security_check_failed", comment: "Operation blocked due to a security threat detected on this device")
        case .documentsDirectoryUnavailable:
            return NSLocalizedString("error.documents_directory_unavailable", comment: "Documents directory not available")
        }
    }
}
