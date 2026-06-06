// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Bridge between the UniFFI-generated provii-mobile-sdk bindings and the iOS app.
///
/// Translates Rust FFI types into native Swift models, manages the SDK
/// runtime (init, credential CRUD, proof generation, storage), and
/// provides `@MainActor` `ObservableObject` state for SwiftUI views.

import Foundation
import SwiftUI
import Combine

#if canImport(ProviiSDK)
import ProviiSDK
#endif

import LocalAuthentication
import UIKit
@MainActor
class WalletSDKBridge: ObservableObject {

    // MARK: - Singleton
    static let shared = WalletSDKBridge()

    /// SECURITY: Non-isolated reference to the wallet for emergency zeroisation.
    /// Set once during initialize() before any security check can fire.
    /// The nonisolated(unsafe) annotation is safe because:
    ///   (1) the write in initialize() completes before the wallet is operational,
    ///   (2) SecurityManager only reads this during termination, which cannot
    ///       race with initialisation.
    nonisolated(unsafe) static var _walletForEmergency: ProviiWallet?

    /// Release the wallet reference held for emergency zeroisation.
    /// Called from SecurityManager before process termination. Releasing the
    /// last strong reference triggers the Rust deinit (uniffi_provii_mobile_sdk_ffi_fn_free_proviiwallet),
    /// which zeroes secret material inside the SDK. Must be nonisolated so it
    /// can run from any thread without an actor hop.
    nonisolated static func emergencyZeroize() {
        _walletForEmergency = nil
    }

    // MARK: - Published Properties for SwiftUI
    @Published var credentials: [CredentialInfo] = []
    @Published var isInitialized = false
    @Published var isProcessing = false
    @Published var verificationStatus: VerificationStatus = .notStarted

    // MARK: - Private Properties
    private var wallet: ProviiWallet?
    private var storageHandle: SecureStorageHandle?
    private var progressTracker: ProgressTracker?

    private var documentsPath: String {
        get throws {
            guard let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
                throw WalletSDKBridgeError.documentsDirectoryUnavailable
            }
            return path
        }
    }

    private init() {}

    // MARK: - Biometric Gate

    /// Require biometric authentication before proceeding with a sensitive operation.
    /// Fails CLOSED: if biometrics are unavailable or the user declines, this throws
    /// and the calling operation MUST NOT proceed.
    private func requireBiometric(reason: String) async throws {
        // SECURITY: Re-check for runtime threats (debugger attach, Frida injection)
        // before every sensitive operation to catch post-startup attacks.
        guard SecurityManager.shared.shouldAllowOperation() else {
            throw WalletSDKBridgeError.securityCheckFailed
        }

        let authenticated = await BiometricService.shared.authenticate(reason: reason)
        if !authenticated {
            SecureLogger.shared.warning("Biometric authentication failed for: \(reason)")
            throw WalletSDKBridgeError.biometricAuthRequired
        }
    }

    // MARK: - Initialisation

    /// Initialise the wallet SDK
    func initialize() async throws {
        guard !isInitialized else { return }

        do {
            // Get app info
            let appInfo = AppInfo(
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                platform: "iOS",
                deviceModel: await getDeviceModel(),
                osVersion: await getOSVersion()
            )

            // CRITICAL: Set User-Agent for all SDK HTTP requests
            #if DEBUG
            SecureLogger.shared.debug("Setting User-Agent with app info", redact: false)
            #endif
            sdkSetUserAgent(appInfo: appInfo)

            // IMPORTANT: Run thread diagnostic
            #if DEBUG
            SecureLogger.shared.debug("Running thread configuration diagnostic", redact: false)
            let diagnostic = sdkDiagnoseThreadConfig()
            SecureLogger.shared.debug("Thread Config: \(diagnostic)", redact: false)
            #else
            let diagnostic = sdkDiagnoseThreadConfig()
            #endif

            if diagnostic.contains("NOT WORKING") {
                SecureLogger.shared.warning("Multi-threading is NOT working!", redact: false)
            }

            // Create secure storage
            #if DEBUG
            storageHandle = try createDevelopmentSecureStore()
            #else
            storageHandle = try createDefaultSecureStore()
            #endif

            // Create wallet with config from EnvironmentManager
            let config = WalletConfig(
                autoSelect: true,
                networkTimeout: 30000,
                cacheProvingKeys: true,
                issuerApiUrl: EnvironmentManager.shared.issuerApi,
                verifierApiUrl: EnvironmentManager.shared.verifierApi,
                verifierApiKey: nil,
                verifierOrigin: nil,
                environment: EnvironmentManager.shared.getCurrentEnvironment,
                enableParallelProver: true,
                maxProverThreads: 2
            )

            wallet = ProviiWallet.withConfig(appInfo: appInfo, config: config)
            WalletSDKBridge._walletForEmergency = wallet

            // Set storage handle
            if let storage = storageHandle, let wallet = wallet {
                try wallet.setStorageHandle(handle: storage)
            }

            // Initialise proving key if needed
            if !provingKeyIsAvailable(appFilesDir: try documentsPath) {
                try provingKeyInit(appFilesDir: try documentsPath)
            }

            // Initialise prover
            if let pkPath = Bundle.main.url(forResource: "proving_key", withExtension: "bin") {
                let pkData = try Data(contentsOf: pkPath)
                try wallet?.initializeProver(pkBytes: pkData)
            }

            isInitialized = true
            #if DEBUG
            SecureLogger.shared.info("WalletSDK initialisation complete", redact: false)
            #endif

            // Load credentials
            await loadCredentials()

        } catch {
            SecureLogger.shared.error("Failed to initialise wallet: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Credential Management

    /// Load all credentials from storage
    func loadCredentials() async {
        guard let wallet = wallet else { return }

        do {
            let creds = try wallet.listCredentials()
            await MainActor.run {
                self.credentials = creds
            }
        } catch {
            SecureLogger.shared.error("Failed to load credentials: \(error.localizedDescription)")
        }
    }

    /// Store a new credential
    /// SECURITY: Requires biometric authentication before writing to secure storage
    func storeCredential(credentialJson: String) async throws -> String {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }

        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.store_credential", comment: "Authenticate to store a new credential")
        )

        isProcessing = true
        defer { isProcessing = false }

        let credentialId = try wallet.storeCredential(credentialJson: credentialJson)
        await loadCredentials()
        return credentialId
    }

    /// Delete a credential
    /// SECURITY: Requires biometric authentication before deleting from secure storage
    func deleteCredential(credentialId: String) async throws {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }

        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.delete_credential", comment: "Authenticate to delete a credential")
        )

        try wallet.deleteCredential(credentialId: credentialId)
        await loadCredentials()
    }

    /// Get a specific credential
    /// SECURITY: Requires biometric authentication as this returns secret credential data
    func getCredential(credentialId: String) async throws -> String? {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }

        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.view_credential", comment: "Authenticate to view credential details")
        )

        return try wallet.getCredential(credentialId: credentialId)
    }

    // MARK: - QR Code Processing

    /// Process a scanned QR code
    func processQRCode(_ qrContent: String) async throws -> QrAction {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }

        return try wallet.processScannedQr(qrContent: qrContent)
    }

    /// Handle QR code action
    func handleQRAction(_ action: QrAction) async throws {
        switch action {
        case .verificationChallenge(let challengeJson):
            try await startVerification(challengeJson: challengeJson)
        case .attestation:
            // Attestation is handled via deep links in DeepLinkHandler
            break
        }
    }

    // MARK: - Age Verification

    /// Start age verification process
    /// SECURITY: Requires biometric authentication before generating or submitting proofs
    func startVerification(challengeJson: String) async throws {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }

        // SECURITY: Gate before accessing credentials and generating proofs
        try await requireBiometric(
            reason: NSLocalizedString("biometric.reason.verify_age", comment: "Authenticate to verify your age")
        )

        verificationStatus = .challengeReceived

        // Parse challenge to get ID
        let challengeId = try extractChallengeIdFromQr(qrContent: challengeJson)

        // Select credential (auto-select if only one)
        let credentialId = try await selectCredentialForVerification()

        // Create progress tracker
        progressTracker = wallet.createProgressTracker()

        // Generate proof
        verificationStatus = .proofGenerated
        let proofJson = try wallet.createAgeProof(
            credentialId: credentialId,
            challengeId: challengeId
        )

        // Submit proof
        verificationStatus = .submitting
        let success = try wallet.submitProof(proofJson: proofJson)

        verificationStatus = success ? .verified : .failed(reason: "Verification failed")
    }

    /// Select credential for verification (auto-select if only one)
    private func selectCredentialForVerification() async throws -> String {
        let validCredentials = credentials.filter { $0.canProve && !$0.isExpired }

        guard let firstCredential = validCredentials.first else {
            throw FfiError.Generic(msg: "No valid credentials for verification")
        }

        // Auto-select if only one credential
        if validCredentials.count == 1 {
            return firstCredential.id
        }

        return firstCredential.id
    }

    // MARK: - Biometric Authentication

    /// Authenticate using biometrics via native LAContext
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        guard wallet != nil else {
            throw FfiError.NotInitialized
        }

        return await BiometricService.shared.authenticate(reason: reason)
    }

    // MARK: - Deep Links

    /// Handle deep link URLs
    /// SECURITY: Requires biometric authentication before processing deep link actions
    /// that access secrets (verification proofs). Attestation navigation does not need
    /// gating here as the actual issuance flow gates via WalletRepository.
    func handleDeepLink(_ url: URL) async throws {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }

        let action = try wallet.handleDeeplink(url: url.absoluteString)

        switch action {
        case .scanChallenge(let payloadJson):
            // startVerification already includes its own biometric gate
            try await startVerification(challengeJson: payloadJson)
        case .attest:
            // Attestation is handled via deep links in DeepLinkHandler
            break
        }
    }

    // MARK: - Utility Methods

    /// Get SDK version
    func getSDKVersion() -> String {
        return getSdkVersion()
    }

    /// Get device model
    private func getDeviceModel() async -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToDevice(identifier: identifier) ?? identifier
    }

    /// Get OS version
    private func getOSVersion() async -> String {
        return UIDevice.current.systemVersion
    }

    /// Map device identifier to friendly name
    private func mapToDevice(identifier: String) -> String? {
        let deviceMap = [
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,6": "iPhone SE (3rd generation)",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus"
        ]
        return deviceMap[identifier]
    }

    // MARK: - Network & Diagnostics

    /// Get wallet diagnostic information
    func getDiagnosticInfo() async -> DiagnosticInfo? {
        guard let wallet = wallet else { return nil }
        return wallet.getDiagnosticInfo()
    }

    /// Check network status
    func checkNetworkStatus() async -> NetworkStatus? {
        guard let wallet = wallet else { return nil }
        return wallet.checkNetworkStatus()
    }

    /// Get verification status
    func getVerificationStatus() -> VerificationStatus {
        guard let wallet = wallet else { return .notStarted }
        return wallet.getVerificationStatus()
    }

    // MARK: - Session Management

    /// Validate session freshness
    /// Note: SDK no longer provides this - sessions are validated server-side
    func validateSessionFreshness(sessionId: String) -> Bool {
        // Session freshness is now validated server-side during verification
        return !sessionId.isEmpty
    }

    /// Clean up expired challenges
    func cleanupExpiredChallenges() async -> UInt32 {
        guard let wallet = wallet else { return 0 }
        return wallet.cleanupExpiredChallenges()
    }

    // MARK: - Configuration

    /// Update wallet configuration
    func updateConfig(_ config: WalletConfig) async throws {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }
        try wallet.updateConfig(config: config)
    }

    /// Get current configuration
    func getConfig() -> WalletConfig? {
        guard let wallet = wallet else { return nil }
        return wallet.getConfig()
    }

    /// Set verifier base URL
    func setVerifierBaseUrl(_ baseUrl: String) async throws {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }
        try wallet.setVerifierBaseUrl(baseUrl: baseUrl)
    }

    /// Get verifier base URL
    func getVerifierBaseUrl() -> String? {
        guard let wallet = wallet else { return nil }
        return wallet.getVerifierBaseUrl()
    }

    // MARK: - Proving Key Management

    /// Check if proving key is available
    func isProvingKeyAvailable() -> Bool {
        guard let path = try? documentsPath else { return false }
        return provingKeyIsAvailable(appFilesDir: path)
    }

    /// Download proving key with progress
    func downloadProvingKey(progressListener: ProvingKeyProgressListener) async throws {
        try provingKeyDownload(appFilesDir: try documentsPath, progressListener: progressListener)
    }

    /// Delete proving key
    func deleteProvingKey() async throws {
        try provingKeyDelete(appFilesDir: try documentsPath)
    }

    /// Get proving key info
    func getProvingKeyInfo() -> String {
        guard let path = try? documentsPath else { return "Documents directory unavailable" }
        return provingKeyGetInfo(appFilesDir: path)
    }

    /// Check storage for proving key
    func checkProvingKeyStorage() throws -> StorageCheckResult {
        return provingKeyCheckStorage(appFilesDir: try documentsPath)
    }

    // MARK: - Debug & Diagnostics

    /// Diagnose proof failure
    func diagnoseProofFailure(credentialId: String, challengeId: String) async throws -> String {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }
        return try wallet.diagnoseProofFailure(credentialId: credentialId, challengeId: challengeId)
    }

    /// Debug preflight check
    func debugPreflight(credentialId: String, challengeId: String) async throws -> String {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }
        return try wallet.debugPreflight(credentialId: credentialId, challengeId: challengeId)
    }

    /// Get challenge diagnostics
    func getChallengeDiagnostics(challengeId: String) async throws -> String {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }
        return try wallet.getChallengeDiagnostics(challengeId: challengeId)
    }

    /// Diagnose thread configuration
    func diagnoseThreadConfig() -> String {
        return sdkDiagnoseThreadConfig()
    }

    // MARK: - Cleanup

    /// Clean up resources
    func cleanup() {
        progressTracker = nil
        WalletSDKBridge._walletForEmergency = nil
        wallet = nil
        storageHandle = nil
        isInitialized = false
    }

}

// MARK: - Progress Listener Implementation

/// Progress listener for long-running operations
class WalletProgressListener: ProgressListener {
    private let onUpdate: (ProgressUpdate) -> Void

    init(onUpdate: @escaping (ProgressUpdate) -> Void) {
        self.onUpdate = onUpdate
    }

    func onProgress(update: ProgressUpdate) {
        DispatchQueue.main.async {
            self.onUpdate(update)
        }
    }
}

// MARK: - Proving Key Progress Listener

/// Progress listener for proving key downloads
class ProvingKeyDownloadListener: ProvingKeyProgressListener {
    private let onProgress: (UInt64, UInt64, UInt8) -> Void

    init(onProgress: @escaping (UInt64, UInt64, UInt8) -> Void) {
        self.onProgress = onProgress
    }

    func onProgress(bytesDownloaded: UInt64, totalBytes: UInt64, percentage: UInt8) {
        DispatchQueue.main.async {
            self.onProgress(bytesDownloaded, totalBytes, percentage)
        }
    }
}

// MARK: - Helper Extensions

extension WalletSDKBridge {
    /// Check if biometrics are available on device
    func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get biometric type
    func getBiometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Get biometric type as string
    func getBiometricTypeString() -> String {
        switch getBiometricType() {
        case .faceID:
            return LocalizedString.biometricFaceId.localized
        case .touchID:
            return LocalizedString.biometricTouchId.localized
        case .opticID:
            return LocalizedString.biometricOpticId.localized
        case .none:
            return LocalizedString.biometricNone.localized
        @unknown default:
            return LocalizedString.biometricUnknown.localized
        }
    }

    /// Calculate age from DOB
    func calculateAge(from dobIso: String) async throws -> UInt32 {
        guard let wallet = wallet else {
            throw FfiError.NotInitialized
        }
        return try wallet.calculateAgeFromDob(dobIso: dobIso)
    }

    /// Check if user has any valid credentials
    func hasValidCredentials() -> Bool {
        guard let wallet = wallet else { return false }
        return wallet.hasValidCredential()
    }

    /// Parse QR code content
    func parseQRContent(_ content: String) async throws -> String {
        return try parseQrCode(qrContent: content)
    }

    /// Check if QR is for verification
    func isVerificationQR(_ qrJson: String) -> Bool {
        return isVerificationQr(qrJson: qrJson)
    }
}

// MARK: - WalletSDKBridge Errors

enum WalletSDKBridgeError: LocalizedError {
    case biometricAuthRequired
    case securityCheckFailed
    case documentsDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .biometricAuthRequired:
            return NSLocalizedString(
                "error.biometric_auth_required",
                comment: "Biometric authentication is required to perform this operation"
            )
        case .securityCheckFailed:
            return NSLocalizedString(
                "error.security_check_failed",
                comment: "Operation blocked due to a security threat detected on this device"
            )
        case .documentsDirectoryUnavailable:
            return NSLocalizedString(
                "error.documents_directory_unavailable",
                comment: "Documents directory not available"
            )
        }
    }
}
