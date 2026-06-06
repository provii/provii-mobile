// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Officer authentication and credential attestation manager.
///
/// Manages the officer session lifecycle: validates officer ID, fetches server
/// challenges, computes YubiKey HMAC-SHA1 responses, creates Ed25519 attestations
/// via the issuer API, and generates QR deep links for the blind issuance flow.
/// Preserves in-flight issuance data across session expiry. Compatible with the
/// Android implementation using the same backend API.

import Foundation
import Combine
import UIKit
import LocalAuthentication

// MARK: - Officer Auth Types

struct OfficerChallengeResponse: Codable {
    let challengeId: String
    let challenge: String // hex
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case challenge
        case expiresAt = "expires_at"
    }
}

struct OfficerStartSessionResponse: Codable {
    let sessionId: String
    let kid: String
    let schema: String
    let iat: Int64
    let exp: Int64
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case kid, schema, iat, exp
        case expiresAt = "expires_at"
    }
}

struct OfficerAttestationResponse: Codable {
    let attestation: String
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case attestation
        case expiresAt = "expires_at"
    }
}

struct OfficerSessionData {
    let sessionId: String
    let officerId: String
    let kid: String
    let expiresAt: Int64
    var issuedToday: Int = 0
    let stationId: String

    init(sessionId: String, officerId: String, kid: String, expiresAt: Int64) {
        self.sessionId = sessionId
        self.officerId = officerId
        self.kid = kid
        self.expiresAt = expiresAt
        self.issuedToday = 0

        // Create station ID from device model
        let model = UIDevice.current.model.replacingOccurrences(of: " ", with: "_").uppercased()
        self.stationId = "MOBILE_\(model)"
    }
}

struct OfficerPreservedSessionInfo: Codable {
    let sessionId: String
    let officerId: String
    let kid: String
    let expiresAt: Int64
    let issuedToday: Int
    let stationId: String
}

struct OfficerPreservedIssuanceData: Codable {
    let dobDays: Int32?
    let documentVerified: Bool
    let dobMatches: Bool
    let sessionInfo: OfficerPreservedSessionInfo?
    let timestamp: Date

    typealias PreservedSessionInfo = OfficerPreservedSessionInfo
}

@MainActor
class OfficerAuthManager: ObservableObject {
    static let shared = OfficerAuthManager()

    // MARK: - Constants

    // Get issuer URL from EnvironmentManager
    private var issuerBaseURL: String {
        EnvironmentManager.shared.issuerApi
    }

    private let officerKeyId = "officer_key_id"
    private let yubikeyTimeout: TimeInterval = 30

    // MARK: - Published Properties

    @Published private(set) var issuanceState: IssuanceState = .idle
    @Published private(set) var currentSession: OfficerSession?
    @Published var sessionExpiryWarning: Bool = false
    @Published var timeUntilExpiry: Int = 0

    // MARK: - Private Properties

    private let yubikeyManager: YubikeyManager
    private let keychainService: KeychainService
    private let biometricService = BiometricService.shared
    private let dataPreservationManager = DataPreservationManager.shared
    private let auditLogger = AuditLogger.shared
    private var sessionMonitorTask: Task<Void, Never>?

    /// Session timeout duration (default 30 minutes)
    private let sessionTimeoutSeconds: TimeInterval = 1800

    // MARK: - Types

    enum IssuanceState: Equatable {
        case idle
        case validatingInput
        case creatingSession
        case waitingForYubikeyTouch(message: String, step: Int, totalSteps: Int)
        case creatingAttestation
        case complete(attestationData: String, deeplink: String)
        case error(message: String, canRetry: Bool)

        static func == (lhs: IssuanceState, rhs: IssuanceState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.validatingInput, .validatingInput),
                 (.creatingSession, .creatingSession),
                 (.creatingAttestation, .creatingAttestation):
                return true
            case (.waitingForYubikeyTouch(let lMessage, let lStep, let lTotal),
                  .waitingForYubikeyTouch(let rMessage, let rStep, let rTotal)):
                return lMessage == rMessage && lStep == rStep && lTotal == rTotal
            case (.complete(let lData, let lLink), .complete(let rData, let rLink)):
                return lData == rData && lLink == rLink
            case (.error(let lMessage, let lRetry), .error(let rMessage, let rRetry)):
                return lMessage == rMessage && lRetry == rRetry
            default:
                return false
            }
        }
    }

    typealias ChallengeResponse = OfficerChallengeResponse
    typealias StartResponse = OfficerStartSessionResponse
    typealias AttestationResponse = OfficerAttestationResponse
    typealias OfficerSession = OfficerSessionData
    typealias PreservedIssuanceData = OfficerPreservedIssuanceData

    // MARK: - Initialization

    init(yubikeyManager: YubikeyManager = .shared,
         keychainService: KeychainService = .shared) {
        self.yubikeyManager = yubikeyManager
        self.keychainService = keychainService
    }

    // MARK: - Private Methods

    /**
     * Convert bytes to hex string
     */
    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /**
     * Fetch server challenge for authentication
     * Note: iOS version simulates YubiKey challenge but uses biometric auth
     */
    private func fetchServerChallenge(officerId: String) async throws -> (challengeId: String, challenge: Data) {
        let jsonResponse = try sdkIssueGetYubikeyChallenge(
            baseUrl: issuerBaseURL,
            officerId: officerId
        )

        guard let jsonData = jsonResponse.data(using: .utf8) else {
            throw OfficerAuthError.invalidChallenge
        }
        let challenge = try JSONDecoder().decode(ChallengeResponse.self, from: jsonData)

        // Convert hex challenge to bytes.
        guard let challengeData = challenge.challenge.hexToData() else {
            throw OfficerAuthError.invalidChallenge
        }

        // Decoded result must be exactly 32 bytes.
        guard challengeData.count == 32 else {
            throw OfficerAuthError.invalidChallenge
        }

        return (challenge.challengeId, challengeData)
    }

    // MARK: - Session Monitoring

    /**
     * Start monitoring session expiry
     */
    private func startSessionMonitoring() {
        guard let session = currentSession else { return }

        // Cancel any existing monitoring
        sessionMonitorTask?.cancel()

        sessionMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                let currentTime = Int64(Date().timeIntervalSince1970)
                let remaining = Int(session.expiresAt - currentTime)

                if remaining <= 0 {
                    // Session expired
                    await handleSessionExpiry()
                    break
                } else if remaining <= 120 && !sessionExpiryWarning {
                    // 2 minutes warning
                    sessionExpiryWarning = true
                    timeUntilExpiry = remaining
                    UIAccessibility.post(notification: .announcement, argument: "Session expiring in \(remaining) seconds")
                } else if remaining <= 120 {
                    timeUntilExpiry = remaining
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }

    /**
     * Handle session expiry by preserving data.
     * MASVS AUTH-2: Proper session timeout handling.
     * Preservation failure is logged but does not block session cleanup.
     */
    private func handleSessionExpiry() async {
        let sessionId = currentSession?.sessionId ?? "unknown"

        let preserved = await preserveIssuanceData()
        if !preserved {
            SecureLogger.shared.error("OfficerAuthManager: handleSessionExpiry preservation failed; session will still be cleared")
        }

        // Log session expiry
        auditLogger.logSecurityEvent(.sessionExpired, details: [
            "session_id": sessionId
        ])

        // Invalidate biometric context on session expiry
        biometricService.invalidateContext()

        currentSession = nil
        sessionExpiryWarning = false
        issuanceState = .error(message: LocalizedString.sessionExpiredReauth.localized, canRetry: true)
    }

    /**
     * Preserve current issuance data.
     * Returns true on success, false if the Keychain write failed.
     */
    func preserveIssuanceData(dobDays: Int32? = nil, documentVerified: Bool = false, dobMatches: Bool = false) async -> Bool {
        let sessionInfo: PreservedIssuanceData.PreservedSessionInfo? = currentSession.map {
            PreservedIssuanceData.PreservedSessionInfo(
                sessionId: $0.sessionId,
                officerId: $0.officerId,
                kid: $0.kid,
                expiresAt: $0.expiresAt,
                issuedToday: $0.issuedToday,
                stationId: $0.stationId
            )
        }

        let preservedData = PreservedIssuanceData(
            dobDays: dobDays,
            documentVerified: documentVerified,
            dobMatches: dobMatches,
            sessionInfo: sessionInfo,
            timestamp: Date()
        )

        let success = dataPreservationManager.preserve(preservedData, forKey: "officer_issuance")
        if success {
            SecureLogger.shared.debug("OfficerAuthManager: issuance data preserved", redact: false)
        } else {
            SecureLogger.shared.error("OfficerAuthManager: preservation failed for officer_issuance; user data may be lost on session expiry")
            auditLogger.logSecurityEvent(.sessionInvalidated, details: [
                "reason": "data_preservation_failed",
                "key": "officer_issuance"
            ])
        }
        return success
    }

    /**
     * Restore preserved issuance data
     */
    func restoreIssuanceData() -> PreservedIssuanceData? {
        let restored: PreservedIssuanceData? = dataPreservationManager.restore(forKey: "officer_issuance")
        return restored
    }

    /**
     * Clear preserved issuance data
     */
    func clearPreservedData() {
        dataPreservationManager.clear(forKey: "officer_issuance")
    }

    // MARK: - Public Methods

    /**
     * Validate officer ID and store it.
     * Matching Android: no YubiKey touch at this stage. The single touch
     * happens in createAttestation() when actually issuing a credential.
     */
    func authenticateOfficer(officerId: String) async throws {
        // Validate officer ID format
        guard officerId.range(of: "^[A-Z0-9_]+$", options: .regularExpression) != nil else {
            issuanceState = .error(message: LocalizedString.invalidOfficerIdFormat.localized, canRetry: true)
            throw OfficerAuthError.invalidOfficerIdFormat
        }

        // Store the officer ID for later use (matching Android's authenticateOfficer)
        try keychainService.save(key: officerKeyId, value: officerId)

        // Create a local session for tracking (no server call needed)
        let localExpiry = Int64(Date().timeIntervalSince1970) + Int64(sessionTimeoutSeconds)
        currentSession = OfficerSession(
            sessionId: UUID().uuidString,
            officerId: officerId,
            kid: "",
            expiresAt: localExpiry
        )

        // Log session creation
        auditLogger.logSecurityEvent(.sessionCreated, details: [
            "officer_id": officerId
        ])

        // Start monitoring session expiry
        startSessionMonitoring()

        issuanceState = .idle
    }

    /**
     * Create attestation for blind issuance flow
     *
     * Privacy improvement: Officer only provides DOB, never sees commitment or r_bits.
     * User's device will generate r_bits locally and complete blind issuance.
     *
     * Flow:
     * 1. Officer enters DOB and verifies document
     * 2. This method creates attestation with YubiKey HMAC auth
     * 3. Officer shows QR code with attestation deep link
     * 4. User scans QR, their device generates r_bits and calls blind issuance
     */
    func createAttestation(
        dobIso: String,
        documentVerified: Bool,
        dobMatches: Bool
    ) async throws -> String {
        do {
            issuanceState = .validatingInput

            // Validate inputs
            guard documentVerified && dobMatches else {
                issuanceState = .error(
                    message: LocalizedString.verifyDocumentAndDob.localized,
                    canRetry: false
                )
                throw OfficerAuthError.verificationIncomplete
            }

            // Log that the verification guard passed before proceeding
            SecureLogger.shared.logWithMetadata(
                "Officer verification guard passed",
                level: .info,
                metadata: ["document_verified": "\(documentVerified)", "dob_matches": "\(dobMatches)"]
            )

            // Validate DOB format and age
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            guard let dobDate = dateFormatter.date(from: dobIso) else {
                issuanceState = .error(
                    message: LocalizedString.invalidDateFormatMessage.localized,
                    canRetry: true
                )
                throw OfficerAuthError.invalidDateFormat
            }

            let age = Calendar.current.dateComponents([.year], from: dobDate, to: Date()).year ?? 0
            guard age >= 18 else {
                issuanceState = .error(
                    message: LocalizedString.userMustBe18.localized,
                    canRetry: false
                )
                throw OfficerAuthError.userTooYoung
            }

            // Convert DOB to days since epoch for attestation
            let dobDays = Int32(dobDate.timeIntervalSince1970 / 86400)

            // Get officer key for HMAC authentication
            guard let keyId = try keychainService.getString(key: officerKeyId) else {
                throw OfficerAuthError.officerKeyNotFound
            }

            // Step 1: Get server challenge for YubiKey auth
            let (challengeId, challengeBytes) = try await fetchServerChallenge(officerId: keyId)

            // Step 2: Wait for YubiKey touch and compute HMAC-SHA1(challenge)
            issuanceState = .waitingForYubikeyTouch(
                message: LocalizedString.touchYubikeyToIssue.localized,
                step: 1,
                totalSteps: 1
            )

            var hmacResponse = try await yubikeyManager.performHmacChallenge(challengeBytes)
            let hmacHex = hex(hmacResponse)
            SensitiveDataHolder.zeroise(&hmacResponse)

            // Step 3: Build authorizer with YubiKey HMAC
            let ts = Int64(Date().timeIntervalSince1970)
            let authorizerJson = HmacSigner.buildAuthorizerJson(
                format: "yubikey",
                keyId: keyId,
                timestamp: ts,
                hmac: hmacHex,
                nonce: try HmacSigner.generateNonce(),
                challengeId: challengeId
            )

            // Step 4: Create attestation via SDK
            issuanceState = .creatingAttestation

            let attestationJson = try sdkCreateAttestation(
                baseUrl: issuerBaseURL,
                dobDays: dobDays,
                authorizerJson: authorizerJson
            )

            guard let attestationData = attestationJson.data(using: .utf8) else {
                throw OfficerAuthError.invalidChallenge
            }
            let attestationResponse = try JSONDecoder().decode(
                AttestationResponse.self,
                from: attestationData
            )

            // Build attestation deep link
            let deeplink = "provii://attest?d=\(attestationResponse.attestation)"

            // Update session stats
            currentSession?.issuedToday += 1

            issuanceState = .complete(attestationData: attestationResponse.attestation, deeplink: deeplink)

            return attestationResponse.attestation

        } catch {
            if case IssuanceState.error = issuanceState {
                // Already set error state
            } else {
                issuanceState = .error(
                    message: error.localizedDescription,
                    canRetry: true
                )
            }
            throw error
        }
    }

    func resetIssuance() {
        issuanceState = .idle
    }

    func getSessionInfo() -> OfficerSession? {
        currentSession
    }

    func endSession() {
        let sessionId = currentSession?.sessionId ?? "unknown"

        // Stop monitoring
        sessionMonitorTask?.cancel()
        sessionMonitorTask = nil

        currentSession = nil
        issuanceState = .idle
        sessionExpiryWarning = false

        // MASVS AUTH-2: Invalidate biometric context on logout
        biometricService.invalidateContext()

        // Clear stored credentials securely
        clearAllCredentials()

        // Clear preserved data on normal logout
        clearPreservedData()

        // Log the session logout
        auditLogger.logSecurityEvent(.sessionLogout, details: [
            "session_id": sessionId
        ])
    }

    // MARK: - Secure Credential Clearing

    /// Clear all stored credentials on logout
    /// MASVS AUTH-2: Proper session invalidation
    private func clearAllCredentials() {
        // Clear officer key
        let officerKeyDeleted = keychainService.delete(key: officerKeyId)
        if !officerKeyDeleted {
            auditLogger.logKeychainAccess(operation: "delete", key: officerKeyId, success: false)
        }

        // Clear any session-related data
        keychainService.clearOfficerKey()
    }

    /// Check if session is still valid
    func isSessionValid() -> Bool {
        guard let session = currentSession else { return false }
        let currentTime = Int64(Date().timeIntervalSince1970)
        return currentTime < session.expiresAt
    }

    /// Get remaining session time in seconds
    func sessionTimeRemaining() -> Int? {
        guard let session = currentSession else { return nil }
        let currentTime = Int64(Date().timeIntervalSince1970)
        let remaining = Int(session.expiresAt - currentTime)
        return remaining > 0 ? remaining : nil
    }
}

// MARK: - Error Types

enum OfficerAuthError: LocalizedError {
    case invalidOfficerIdFormat
    case invalidChallenge
    case noActiveSession
    case verificationIncomplete
    case invalidDateFormat
    case userTooYoung
    case officerKeyNotFound

    var errorDescription: String? {
        switch self {
        case .invalidOfficerIdFormat:
            return LocalizedString.invalidOfficerIdFormat.localized
        case .invalidChallenge:
            return LocalizedString.errorInvalidChallenge.localized
        case .noActiveSession:
            return LocalizedString.errorNoActiveSession.localized
        case .verificationIncomplete:
            return LocalizedString.errorDocumentVerificationIncomplete.localized
        case .invalidDateFormat:
            return LocalizedString.errorInvalidDateFormat.localized
        case .userTooYoung:
            return LocalizedString.userMustBe18.localized
        case .officerKeyNotFound:
            return LocalizedString.errorOfficerKeyNotFound.localized
        }
    }
}
