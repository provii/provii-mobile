// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import Combine

/// Manages user consent for analytics and crash reporting, persisting all consent state in the
/// Keychain (NEVER UserDefaults) for MASVS-PRIVACY-2 compliance. Tracks a consent version
/// counter so that significant privacy policy changes trigger re-consent prompts. Provides
/// batch and individual consent setters, a data-deletion request flag, and a full wipe method
/// that removes every privacy-related Keychain key.
///
/// MASVS-STORAGE-1: Uses KeychainService for encrypted storage.
/// All consent data is stored with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
/// and does not require biometric authentication to read or write.
@MainActor
final class PrivacyPreferences: ObservableObject {

    // MARK: - Singleton

    static let shared = PrivacyPreferences()

    // MARK: - Published Properties

    @Published var analyticsEnabled: Bool = false
    @Published var crashReportingEnabled: Bool = false

    // MARK: - Constants

    /// Increment this when the privacy policy changes significantly.
    /// Users will be prompted to re-consent.
    static let currentConsentVersion: Int = 1

    private enum Keys {
        static let analyticsConsent = "privacy_analytics_consent"
        static let crashConsent = "privacy_crash_consent"
        static let consentVersion = "privacy_consent_version"
        static let consentTimestamp = "privacy_consent_timestamp"
        static let dataDeletion = "privacy_data_deletion"
    }

    private let keychain = KeychainService.shared
    private let logger = SecureLogger.shared

    // MARK: - Initialisation

    private init() {
        // Load persisted values from Keychain
        analyticsEnabled = loadBool(key: Keys.analyticsConsent)
        crashReportingEnabled = loadBool(key: Keys.crashConsent)
    }

    // MARK: - Consent Status

    /// Whether the user has provided any consent at all (first-time check).
    func hasProvidedConsent() -> Bool {
        return loadString(key: Keys.consentVersion) != nil
    }

    /// Whether the stored consent version is behind the current version,
    /// meaning we need to ask the user to review their choices again.
    func needsConsentRenewal() -> Bool {
        let stored = getConsentVersion()
        return stored < Self.currentConsentVersion
    }

    // MARK: - Individual Consent Setters

    func setAnalyticsConsent(enabled: Bool) {
        saveBool(key: Keys.analyticsConsent, value: enabled)
        analyticsEnabled = enabled
        stampConsent()
        logger.info("Analytics consent updated", redact: false)
    }

    func setCrashReportingConsent(enabled: Bool) {
        saveBool(key: Keys.crashConsent, value: enabled)
        crashReportingEnabled = enabled
        stampConsent()
        logger.info("Crash reporting consent updated", redact: false)
    }

    // MARK: - Batch Consent

    /// Record all consent choices at once (useful during onboarding or renewal).
    func recordConsent(analytics: Bool, crashReporting: Bool) {
        saveBool(key: Keys.analyticsConsent, value: analytics)
        saveBool(key: Keys.crashConsent, value: crashReporting)
        analyticsEnabled = analytics
        crashReportingEnabled = crashReporting
        stampConsent()
        logger.info("Privacy consent recorded", redact: false)
    }

    // MARK: - Data Deletion

    /// Flag the account for data deletion. The actual wipe happens
    /// via clearAllPrivacyData() after any server-side cleanup.
    func requestDataDeletion() {
        saveBool(key: Keys.dataDeletion, value: true)
        logger.info("Data deletion requested", redact: false)
    }

    /// Remove every privacy-related key from the Keychain and reset
    /// published properties to their defaults.
    func clearAllPrivacyData() {
        let allKeys = [
            Keys.analyticsConsent,
            Keys.crashConsent,
            Keys.consentVersion,
            Keys.consentTimestamp,
            Keys.dataDeletion
        ]
        for key in allKeys {
            keychain.delete(key: key)
        }

        analyticsEnabled = false
        crashReportingEnabled = false

        logger.info("All privacy data cleared", redact: false)
    }

    // MARK: - Consent Metadata

    /// Returns the timestamp of the most recent consent action, or nil
    /// if the user has never consented.
    func getConsentTimestamp() -> Date? {
        guard let raw = loadString(key: Keys.consentTimestamp),
              let interval = TimeInterval(raw) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    /// Returns the consent version the user last agreed to (0 if none).
    func getConsentVersion() -> Int {
        guard let raw = loadString(key: Keys.consentVersion),
              let version = Int(raw) else {
            return 0
        }
        return version
    }

    // MARK: - Private Helpers

    /// Write the current consent version and timestamp into the Keychain.
    private func stampConsent() {
        saveString(key: Keys.consentVersion, value: String(Self.currentConsentVersion))
        saveString(key: Keys.consentTimestamp, value: String(Date().timeIntervalSince1970))
    }

    private func saveBool(key: String, value: Bool) {
        saveString(key: key, value: value ? "1" : "0")
    }

    private func loadBool(key: String) -> Bool {
        return loadString(key: key) == "1"
    }

    private func saveString(key: String, value: String) {
        do {
            try keychain.save(key: key, value: value, requiresBiometric: false)
        } catch {
            logger.error("Failed to save privacy preference for key: \(key)")
        }
    }

    private func loadString(key: String) -> String? {
        do {
            return try keychain.getData(key: key, requireAuth: false)
                .flatMap { String(data: $0, encoding: .utf8) }
        } catch {
            logger.error("Failed to load privacy preference for key: \(key)")
            return nil
        }
    }
}
