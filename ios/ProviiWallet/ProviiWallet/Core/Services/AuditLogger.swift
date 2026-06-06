// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// MASVS-STORAGE compliant audit logger with encryption at rest.
///
/// Entries are logged to Apple's unified logging system (os.log) for real-time
/// monitoring and persisted to an AES-256-GCM encrypted JSONL file for
/// compliance and forensic use. Matches Android's AuditLogger: encrypted JSONL,
/// 10K entry / 5MB rotation, `getAuditLog()` retrieval.

import Foundation
import os.log
import CryptoKit
class AuditLogger {
    static let shared = AuditLogger()

    private let logger = Logger(subsystem: "app.provii.wallet", category: "Security")
    private let sensitiveLogger = Logger(subsystem: "app.provii.wallet", category: "SensitiveOps")

    // Encrypted persistence
    private static let auditLogFilename = "audit_encrypted.log"
    private static let auditLogTempFilename = "audit_encrypted_temp.log"
    private static let maxLogSizeBytes = 5 * 1024 * 1024 // 5MB
    private static let maxLogEntries = 10000
    private static let encryptionKeyKeychainKey = "provii_audit_log_key"

    // Cache the AES-256 encryption key in memory. The key is created once and
    // never rotated during the app lifetime, so no TTL is needed. This avoids a
    // Keychain read on every single audit log entry.
    private var cachedEncryptionKey: SymmetricKey?

    private let persistQueue = DispatchQueue(label: "app.provii.wallet.auditlog", qos: .utility)
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    // MARK: - Redaction Helpers

    /// Redact a credential ID for safe inclusion in persisted audit logs.
    /// Keeps the first 4 characters for correlation, replaces the rest with `***`.
    /// Returns `[EMPTY]` for empty strings to avoid silent data loss.
    ///
    /// Examples:
    ///   - `"provii.cred.abc123xyz"` -> `"parl***"`
    ///   - `"ab"` -> `"ab***"` (shorter than 4 chars kept as-is + mask)
    func redactCredentialId(_ id: String) -> String {
        guard !id.isEmpty else { return "[EMPTY]" }
        let prefix = String(id.prefix(4))
        return "\(prefix)***"
    }

    /// Redact a Keychain key name for safe inclusion in persisted audit logs.
    /// Same truncation strategy as credential IDs: first 4 characters + `***`.
    func redactKeychainKey(_ key: String) -> String {
        guard !key.isEmpty else { return "[EMPTY]" }
        let prefix = String(key.prefix(4))
        return "\(prefix)***"
    }

    // MARK: - App Lifecycle Events

    func logAppEvent(event: String, metadata: [String: String] = [:]) {
        if metadata.isEmpty {
            logger.info("App event: \(event, privacy: .public)")
        } else {
            let detail = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logger.info("App event: \(event, privacy: .public) [\(detail, privacy: .public)]")
        }
        persistLog("app_event", data: metadata.merging(["event": event]) { _, new in new })
    }

    // MARK: - Authentication Events

    func logWebAuthnAuthentication(officerId: String, credentialId: String, success: Bool) {
        if success {
            logger.info("Officer authenticated via WebAuthn: \(officerId, privacy: .public)")
        } else {
            logger.warning("WebAuthn authentication failed for officer: \(officerId, privacy: .public)")
        }
        persistLog(success ? "webauthn_auth_success" : "webauthn_auth_failure", data: [
            "officer_id": officerId,
            "credential_id": redactCredentialId(credentialId)
        ])
    }

    func logYubiKeyAuthentication(officerId: String, success: Bool) {
        if success {
            logger.info("Officer authenticated via YubiKey: \(officerId, privacy: .public)")
        } else {
            logger.warning("YubiKey authentication failed for officer: \(officerId, privacy: .public)")
        }
        persistLog(success ? "yubikey_auth_success" : "yubikey_auth_failure", data: [
            "officer_id": officerId
        ])
    }

    // MARK: - Credential Events

    func logCredentialIssuance(
        officerId: String? = nil,
        requestId: String,
        issuerKid: String,
        success: Bool,
        error: String? = nil
    ) {
        let issuer = officerId ?? "self-service"
        if success {
            logger.info("Credential issued: requestId=\(requestId, privacy: .public), issuer=\(issuer, privacy: .public), kid=\(issuerKid, privacy: .public)")
        } else {
            logger.error("Credential issuance failed: \(error ?? "unknown error", privacy: .public)")
        }
        var data: [String: String] = [
            "officer_id": issuer,
            "request_id": requestId,
            "issuer_kid": redactCredentialId(issuerKid)
        ]
        if let error { data["error"] = error }
        persistLog(success ? "credential_issuance_success" : "credential_issuance_failure", data: data)
    }

    func logBlindAttestation(success: Bool, error: String? = nil) {
        if success {
            logger.info("Blind attestation credential issuance successful")
        } else {
            logger.error("Blind attestation failed: \(error ?? "unknown error")")
        }
        var data: [String: String] = [:]
        if let error { data["error"] = error }
        persistLog(success ? "blind_attestation_success" : "blind_attestation_failure", data: data)
    }

    // MARK: - Verification Events

    func logVerificationAttempt(
        credentialId: String,
        challengeId: String,
        verifyUrl: String,
        result: String
    ) {
        logger.info("Verification: credentialId=\(credentialId, privacy: .private), challenge=\(challengeId, privacy: .public), result=\(result, privacy: .public)")
        logger.debug("Verify URL: \(verifyUrl, privacy: .public)")
        persistLog("verification_attempt", data: [
            "credential_id": redactCredentialId(credentialId),
            "challenge_id": challengeId,
            "verify_url": verifyUrl,
            "result": result
        ])
    }

    func logProofGeneration(credentialId: String, duration: TimeInterval, success: Bool) {
        if success {
            logger.info("Proof generated in \(String(format: "%.2f", duration))s for credential: \(credentialId, privacy: .private)")
        } else {
            logger.error("Proof generation failed for credential: \(credentialId, privacy: .private)")
        }
        persistLog(success ? "proof_generation_success" : "proof_generation_failure", data: [
            "credential_id": redactCredentialId(credentialId),
            "duration_s": String(format: "%.3f", duration)
        ])
    }

    // MARK: - Deep Link Events

    func logDeepLink(scheme: String, action: String, details: [String: String]? = nil) {
        if let details = details {
            let detailStr = details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logger.info("Deep link received: \(scheme)://\(action) [\(detailStr)]")
        } else {
            logger.info("Deep link received: \(scheme)://\(action)")
        }
        var data: [String: String] = ["scheme": scheme, "action": action]
        if let details { data.merge(details) { _, new in new } }
        persistLog("deeplink_received", data: data)
    }

    func logDeepLinkProcessed(type: String, success: Bool) {
        if success {
            logger.info("Deep link processed successfully: type=\(type)")
        } else {
            logger.error("Deep link processing failed: type=\(type)")
        }
        persistLog(success ? "deeplink_processed" : "deeplink_failed", data: ["type": type])
    }

    // MARK: - YubiKey Events

    func logYubiKeyEvent(event: String, details: String? = nil) {
        if let details = details {
            logger.info("YubiKey event: \(event) - \(details)")
        } else {
            logger.info("YubiKey event: \(event)")
        }
        var data: [String: String] = ["event": event]
        if let details { data["details"] = details }
        persistLog("yubikey_event", data: data)
    }

    func logYubiKeyConnection(connected: Bool, connectionType: String) {
        if connected {
            logger.info("YubiKey connected via \(connectionType)")
        } else {
            logger.info("YubiKey disconnected")
        }
        persistLog("yubikey_connection", data: [
            "connected": String(connected),
            "connection_type": connectionType
        ])
    }

    // MARK: - Security Events

    func logSecurityEvent(_ event: SecurityEvent, details: [String: Any] = [:]) {
        let detailsString = details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")

        switch event.severity {
        case .info:
            logger.info("Security event: \(event.rawValue) [\(detailsString)]")
        case .warning:
            logger.warning("Security warning: \(event.rawValue) [\(detailsString)]")
        case .critical:
            logger.critical("SECURITY ALERT: \(event.rawValue) [\(detailsString)]")
        }

        // In production, send critical events to security monitoring service
        if event.severity == .critical {
            sendToSecurityMonitoring(event: event, details: details)
        }

        let stringDetails = details.mapValues { String(describing: $0) }
        persistLog("security_\(event.rawValue)", data: stringDetails)
    }

    // MARK: - Storage Events

    func logKeychainAccess(operation: String, key: String, success: Bool) {
        if success {
            logger.debug("Keychain \(operation) successful for key: \(key, privacy: .private)")
        } else {
            logger.error("Keychain \(operation) failed for key: \(key, privacy: .private)")
        }
        persistLog("keychain_\(operation)", data: ["key": redactKeychainKey(key), "success": String(success)])
    }

    func logProvingKeyEvent(event: String, size: Int64? = nil) {
        if let size = size {
            let sizeMB = Double(size) / (1024 * 1024)
            logger.info("Proving key event: \(event), size: \(String(format: "%.2f", sizeMB))MB")
        } else {
            logger.info("Proving key event: \(event)")
        }
        var data: [String: String] = ["event": event]
        if let size { data["size_bytes"] = String(size) }
        persistLog("proving_key_event", data: data)
    }

    // MARK: - Audit Log Retrieval

    /// Get decrypted audit log contents for export.
    func getAuditLog() -> String {
        return readEncryptedLogContent()
    }

    /// Get the number of persisted log entries.
    func getLogEntryCount() -> Int {
        let content = readEncryptedLogContent()
        if content.isEmpty { return 0 }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    /// Clear audit log.
    func clearAuditLog() {
        if let logFile = auditLogFileURL() {
            try? FileManager.default.removeItem(at: logFile)
        }
        if let tempFile = auditLogTempFileURL() {
            try? FileManager.default.removeItem(at: tempFile)
        }
    }

    // MARK: - Encrypted Persistence

    /// Persist a log entry to the encrypted JSONL file.
    private func persistLog(_ event: String, data: [String: String]) {
        persistQueue.async { [weak self] in
            guard let self else { return }

            do {
                let entry: [String: Any] = [
                    "timestamp": self.dateFormatter.string(from: Date()),
                    "timestamp_ms": Int(Date().timeIntervalSince1970 * 1000),
                    "event": event,
                    "data": data
                ]

                let entryData = try JSONSerialization.data(withJSONObject: entry)
                let entryLine = String(data: entryData, encoding: .utf8) ?? ""

                // Read existing content
                let existing = self.readEncryptedLogContent()
                var newContent: String
                if existing.isEmpty {
                    newContent = entryLine
                } else {
                    newContent = existing + "\n" + entryLine
                }

                // Rotation check
                let lines = newContent.components(separatedBy: "\n").filter { !$0.isEmpty }
                if lines.count > Self.maxLogEntries || newContent.utf8.count > Self.maxLogSizeBytes {
                    let kept = Array(lines.suffix(lines.count / 2))
                    newContent = kept.joined(separator: "\n")
                }

                self.writeEncryptedLogContent(newContent)
            } catch {
                // Silently fail persistence. os.log still has the entry
            }
        }
    }

    /// Read and decrypt the current log file. Returns empty string on failure.
    private func readEncryptedLogContent() -> String {
        guard let logFile = auditLogFileURL() else { return "" }
        guard FileManager.default.fileExists(atPath: logFile.path) else { return "" }

        do {
            let encryptedData = try Data(contentsOf: logFile)
            guard encryptedData.count > 12 else { return "" } // Need at least nonce + tag
            let key = try getOrCreateEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return String(data: decrypted, encoding: .utf8) ?? ""
        } catch {
            // If decryption fails (key rotated, corrupted), start fresh
            try? FileManager.default.removeItem(at: logFile)
            return ""
        }
    }

    /// Encrypt and write content to the log file using atomic temp-file pattern.
    private func writeEncryptedLogContent(_ content: String) {
        guard let logFile = auditLogFileURL(),
              let tempFile = auditLogTempFileURL() else { return }

        do {
            let key = try getOrCreateEncryptionKey()
            let plaintext = Data(content.utf8)
            let sealedBox = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealedBox.combined else { return }

            // Atomic write: temp file, then rename
            try combined.write(to: tempFile, options: [.atomic])

            // Replace original with temp
            let fm = FileManager.default
            if fm.fileExists(atPath: logFile.path) {
                try fm.removeItem(at: logFile)
            }
            try fm.moveItem(at: tempFile, to: logFile)
        } catch {
            // Silently fail. os.log still has the entry
            if let tempFile = auditLogTempFileURL() {
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
    }

    /// Get or create the AES-256 encryption key, stored in Keychain.
    /// Returns the in-memory cached key when available, falling back to
    /// Keychain only on the first call (or after key creation).
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        if let cached = cachedEncryptionKey {
            return cached
        }

        let keychainKey = Self.encryptionKeyKeychainKey

        // Try to read existing key (no auth required for audit log key)
        if let existingKeyData = try? KeychainService.shared.getData(key: keychainKey, requireAuth: false) {
            let key = SymmetricKey(data: existingKeyData)
            cachedEncryptionKey = key
            return key
        }

        // Generate new 256-bit key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try KeychainService.shared.save(key: keychainKey, data: keyData, requiresBiometric: false)
        cachedEncryptionKey = newKey
        return newKey
    }

    private func auditLogFileURL() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        return documentsDir.appendingPathComponent(Self.auditLogFilename)
    }

    private func auditLogTempFileURL() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDir.appendingPathComponent(Self.auditLogTempFilename)
    }

    // MARK: - Private Methods

    private func sendToSecurityMonitoring(event: SecurityEvent, details: [String: Any]) {
        // SECURITY FIX: Log critical security events in ALL builds (production & debug)
        let detailsString = details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.critical("SECURITY_EVENT: \(event.rawValue) [\(detailsString)]")

        #if DEBUG
        SecureLogger.shared.warning("SECURITY MONITORING: \(event.rawValue) - \(detailsString)", redact: true)
        #endif
    }
}

// MARK: - Security Event Types

enum SecurityEvent: String {
    // Authentication
    case authenticationSuccess = "auth_success"
    case authenticationFailure = "auth_failure"
    case suspiciousLoginAttempt = "suspicious_login"

    // PIN Verification
    case pinVerificationFailed = "pin_verification_failed"
    case pinVerificationLocked = "pin_verification_locked"

    // Biometric Authentication
    case biometricAuthSuccess = "biometric_auth_success"
    case biometricAuthFailure = "biometric_auth_failure"
    case biometricContextInvalidated = "biometric_context_invalidated"

    // Session Management
    case sessionCreated = "session_created"
    case sessionExpired = "session_expired"
    case sessionInvalidated = "session_invalidated"
    case sessionLogout = "session_logout"

    // Credentials
    case credentialCreated = "credential_created"
    case credentialExpired = "credential_expired"
    case credentialRevoked = "credential_revoked"
    case credentialDeletionFailed = "credential_deletion_failed"

    // Verification
    case verificationSuccess = "verification_success"
    case verificationFailure = "verification_failure"
    case invalidProof = "invalid_proof"

    // Security violations
    case tamperingDetected = "tampering_detected"
    case jailbreakDetected = "jailbreak_detected"
    case debuggerAttached = "debugger_attached"
    case invalidSignature = "invalid_signature"

    // UI Security
    case screenshotAttempt = "screenshot_attempt"
    case screenRecordingAttempt = "screen_recording_attempt"

    // Deep links
    case deeplinkFallback = "deeplink_fallback"

    var severity: SecuritySeverity {
        switch self {
        case .authenticationSuccess, .credentialCreated, .verificationSuccess,
             .biometricAuthSuccess, .sessionCreated:
            return .info
        case .authenticationFailure, .credentialExpired, .verificationFailure, .deeplinkFallback,
             .pinVerificationFailed, .biometricAuthFailure, .sessionExpired, .sessionInvalidated, .sessionLogout,
             .biometricContextInvalidated, .credentialDeletionFailed:
            return .warning
        case .suspiciousLoginAttempt, .credentialRevoked, .invalidProof,
             .tamperingDetected, .jailbreakDetected, .debuggerAttached, .invalidSignature,
             .screenshotAttempt, .screenRecordingAttempt, .pinVerificationLocked:
            return .critical
        }
    }
}

enum SecuritySeverity {
    case info
    case warning
    case critical
}
