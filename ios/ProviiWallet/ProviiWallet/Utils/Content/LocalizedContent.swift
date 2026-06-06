// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI
import Combine

// Localised content system satisfying WCAG 2.2 AAA criterion 3.1.5 (Reading Level).
// Defines standard and simplified reading levels, content keys for all user facing text,
// and a content manager that automatically selects the appropriate text variant based on
// the user's accessibility settings.

// MARK: - Reading Level

enum ReadingLevel: String, Codable, CaseIterable {
    case standard = "Standard"
    case simplified = "Simplified (Grade 7-9)"

    var description: String {
        switch self {
        case .standard:
            return NSLocalizedString("reading_level_standard_description",
                                     value: "Regular text with technical terms",
                                     comment: "Description of standard reading level")
        case .simplified:
            return NSLocalizedString("reading_level_simplified_description",
                                     value: "Simpler words and shorter sentences (AAA compliant)",
                                     comment: "Description of simplified reading level")
        }
    }

    var localizedName: String {
        switch self {
        case .standard:
            return NSLocalizedString("reading_level_standard",
                                     value: "Standard",
                                     comment: "Standard reading level name")
        case .simplified:
            return NSLocalizedString("reading_level_simplified",
                                     value: "Simplified (Grade 7-9)",
                                     comment: "Simplified reading level name")
        }
    }
}

// MARK: - Content Keys

enum ContentKey: String {
    // Age Verification
    case ageVerificationTitle = "age_verification_title"
    case ageVerificationExplanation = "age_verification_explanation"
    case ageVerificationInstructions = "age_verification_instructions"
    case ageVerificationSuccess = "age_verification_success"
    case ageVerificationFailed = "age_verification_failed"

    // Technical Terms
    case credentialDescription = "credential_description"
    case zeroKnowledgeExplanation = "zero_knowledge_explanation"
    case setupProvingKey = "setup_proving_key"
    case processingChallenge = "processing_challenge"
    case creatingProof = "creating_proof"
    case submittingProof = "submitting_proof"

    // Errors
    case errorNoCredential = "error_no_credential"
    case errorNetworkFailed = "error_network_failed"
    case errorInvalidQR = "error_invalid_qr"
    case errorVerificationFailed = "error_verification_failed"

    // Officer Mode
    case officerAuthenticationTitle = "officer_authentication_title"
    case officerIssuanceTitle = "officer_issuance_title"
    case officerDobPrompt = "officer_dob_prompt"

    // Onboarding
    case onboardingWelcome = "onboarding_welcome"
    case onboardingPrivacy = "onboarding_privacy"
    case onboardingGetStarted = "onboarding_get_started"
}

// MARK: - Localized Content Manager

@MainActor
class LocalizedContentManager: ObservableObject {
    static let shared = LocalizedContentManager()

    private var contentDictionary: [String: [String: String]] = [:]

    /// Current language code (e.g., "en", "es", "fr")
    @Published var currentLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    private init() {
        loadContent()
    }

    /// Get localised text for a key with optional reading level
    func text(for key: ContentKey, level: ReadingLevel? = nil) -> String {
        let accessibilityManager = AccessibilityManager.shared
        let effectiveLevel = level ?? (accessibilityManager.settings.readingLevel == .simplified ? .simplified : .standard)

        // First check if we have custom content for this key
        let content = contentDictionary[key.rawValue] ?? [:]

        switch effectiveLevel {
        case .simplified:
            return content["simplified"] ?? content["standard"] ?? NSLocalizedString(key.rawValue, comment: "")
        case .standard:
            return content["standard"] ?? NSLocalizedString(key.rawValue, comment: "")
        }
    }

    /// Get localised string from StringCatalog enum
    func text(for localizedString: LocalizedString, level: ReadingLevel? = nil) -> String {
        // Check if this key exists in our reading-level content dictionary
        if let contentKey = ContentKey(rawValue: localizedString.rawValue) {
            return text(for: contentKey, level: level)
        }

        // Otherwise use standard NSLocalizedString
        return NSLocalizedString(localizedString.rawValue, comment: "")
    }

    /// Get localised string with format arguments
    func text(for localizedString: LocalizedString, _ arguments: CVarArg...) -> String {
        let format = text(for: localizedString)
        return String(format: format, arguments: arguments)
    }

    /// Change the app language (for future multi-language support)
    func changeLanguage(to languageCode: String) {
        currentLanguage = languageCode
        // Notify the app to reload localised content
        NotificationCenter.default.post(name: .languageDidChange, object: languageCode)
    }

    /// Get available languages
    func availableLanguages() -> [String] {
        return Bundle.main.localizations.filter { $0 != "Base" }
    }

    /// Get current language display name
    func currentLanguageDisplayName() -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: currentLanguage) ?? currentLanguage.uppercased()
    }

    private func loadContent() {
        var content = loadCoreContent()
        content.merge(loadScreenContent()) { _, new in new }
        contentDictionary = content
    }

    private func loadCoreContent() -> [String: [String: String]] {
        return [
            // Age Verification
            "age_verification_title": [
                "standard": NSLocalizedString("age_verification_title_standard", comment: "Age verification screen title (standard)"),
                "simplified": NSLocalizedString("age_verification_title_simple", comment: "Age verification screen title (simplified)")
            ],
            "age_verification_explanation": [
                "standard": NSLocalizedString("age_verification_explanation", comment: "Age verification explanation text (standard)"),
                "simplified": NSLocalizedString("age_verification_explanation_simple", comment: "Age verification explanation text (simplified)")
            ],
            "age_verification_instructions": [
                "standard": NSLocalizedString("age_verification_instructions", comment: "Age verification instructions (standard)"),
                "simplified": NSLocalizedString("age_verification_instructions_simple", comment: "Age verification instructions (simplified)")
            ],
            "age_verification_success": [
                "standard": NSLocalizedString("age_verification_success_standard", comment: "Age verification success message (standard)"),
                "simplified": NSLocalizedString("age_verification_success_simple", comment: "Age verification success message (simplified)")
            ],
            "age_verification_failed": [
                "standard": NSLocalizedString("age_verification_failed_standard", comment: "Age verification failure message (standard)"),
                "simplified": NSLocalizedString("age_verification_failed_simplified", comment: "Age verification failure message (simplified)")
            ],

            // Technical Terms
            "credential_description": [
                "standard": NSLocalizedString("credential_description", comment: "Credential description (standard)"),
                "simplified": NSLocalizedString("credential_description_simple", comment: "Credential description (simplified)")
            ],
            "mobile_drivers_license": [
                "standard": NSLocalizedString("mobile_drivers_license_standard", comment: "Mobile driver's licence label (standard)"),
                "simplified": NSLocalizedString("mobile_drivers_license_simple", comment: "Mobile driver's licence label (simplified)")
            ],
            "drivers_license": [
                "standard": NSLocalizedString("drivers_license_standard", comment: "Driver's licence label (standard)"),
                "simplified": NSLocalizedString("drivers_license_simple", comment: "Driver's licence label (simplified)")
            ],
            "verifiable_credential": [
                "standard": NSLocalizedString("verifiable_credential_standard", comment: "Verifiable credential label (standard)"),
                "simplified": NSLocalizedString("verifiable_credential_simple", comment: "Verifiable credential label (simplified)")
            ],
            "zero_knowledge_explanation": [
                "standard": NSLocalizedString("zero_knowledge_explanation", comment: "Zero knowledge proof explanation (standard)"),
                "simplified": NSLocalizedString("zero_knowledge_explanation_simple", comment: "Zero knowledge proof explanation (simplified)")
            ],
            "setup_proving_key": [
                "standard": NSLocalizedString("setup_proving_key", comment: "Proving key download status message (standard)"),
                "simplified": NSLocalizedString("setup_proving_key_simple", comment: "Proving key download status message (simplified)")
            ],
            "processing_challenge": [
                "standard": NSLocalizedString("processing_challenge", comment: "Challenge processing status message (standard)"),
                "simplified": NSLocalizedString("processing_challenge_simple", comment: "Challenge processing status message (simplified)")
            ],
            "creating_proof": [
                "standard": NSLocalizedString("creating_proof", comment: "Proof creation status message (standard)"),
                "simplified": NSLocalizedString("creating_proof_simple", comment: "Proof creation status message (simplified)")
            ],
            "submitting_proof": [
                "standard": NSLocalizedString("submitting_proof", comment: "Proof submission status message (standard)"),
                "simplified": NSLocalizedString("submitting_proof_simple", comment: "Proof submission status message (simplified)")
            ],

            // Errors
            "error_no_credential": [
                "standard": NSLocalizedString("error_no_credential_standard", comment: "No credential error message (standard)"),
                "simplified": NSLocalizedString("error_no_credential_simple", comment: "No credential error message (simplified)")
            ],
            "error_network_failed": [
                "standard": NSLocalizedString("error_network_failed_standard", comment: "Network failure error message (standard)"),
                "simplified": NSLocalizedString("error_network_failed_simple", comment: "Network failure error message (simplified)")
            ],
            "error_invalid_qr": [
                "standard": NSLocalizedString("error_invalid_qr_standard", comment: "Invalid QR code error message (standard)"),
                "simplified": NSLocalizedString("error_invalid_qr_simple", comment: "Invalid QR code error message (simplified)")
            ],
            "error_verification_failed": [
                "standard": NSLocalizedString("error_verification_failed_standard", comment: "Verification failure error message (standard)"),
                "simplified": NSLocalizedString("error_verification_failed_simple", comment: "Verification failure error message (simplified)")
            ],

            // Officer Mode
            "officer_authentication_title": [
                "standard": NSLocalizedString("officer_authentication_title_standard", comment: "Officer authentication screen title (standard)"),
                "simplified": NSLocalizedString("officer_authentication_title", comment: "Officer authentication screen title (simplified)")
            ],
            "officer_issuance_title": [
                "standard": NSLocalizedString("officer_issuance_title_standard", comment: "Officer credential issuance screen title (standard)"),
                "simplified": NSLocalizedString("officer_issuance_title_simple", comment: "Officer credential issuance screen title (simplified)")
            ],
            "officer_dob_prompt": [
                "standard": NSLocalizedString("officer_dob_prompt_standard", comment: "Officer date of birth entry prompt (standard)"),
                "simplified": NSLocalizedString("officer_dob_prompt_simple", comment: "Officer date of birth entry prompt (simplified)")
            ],

            // Onboarding
            "onboarding_welcome": [
                "standard": NSLocalizedString("onboarding_welcome", comment: "Onboarding welcome message (standard)"),
                "simplified": NSLocalizedString("onboarding_welcome_simple", comment: "Onboarding welcome message (simplified)")
            ],
            "onboarding_privacy": [
                "standard": NSLocalizedString("onboarding_privacy", comment: "Onboarding privacy message (standard)"),
                "simplified": NSLocalizedString("onboarding_privacy_simple", comment: "Onboarding privacy message (simplified)")
            ],
            "onboarding_get_started": [
                "standard": NSLocalizedString("onboarding_get_started", comment: "Onboarding get started message (standard)"),
                "simplified": NSLocalizedString("onboarding_get_started_simple", comment: "Onboarding get started message (simplified)")
            ],

            // Settings Screen
            "settings_title": [
                "standard": NSLocalizedString("settings_title_standard", comment: "Settings screen title (standard)"),
                "simplified": NSLocalizedString("settings_title_simple", comment: "Settings screen title (simplified)")
            ],
            "accessibility_settings": [
                "standard": NSLocalizedString("accessibility_settings", comment: "Accessibility settings label (standard)"),
                "simplified": NSLocalizedString("accessibility_settings_simple", comment: "Accessibility settings label (simplified)")
            ],
            "customize_experience": [
                "standard": NSLocalizedString("customize_experience_standard", comment: "Customise experience prompt (standard)"),
                "simplified": NSLocalizedString("customize_experience_simple", comment: "Customise experience prompt (simplified)")
            ],
            "language_settings": [
                "standard": NSLocalizedString("language_settings_standard", comment: "Language settings label (standard)"),
                "simplified": NSLocalizedString("language_settings_simple", comment: "Language settings label (simplified)")
            ],
            "help_and_support": [
                "standard": NSLocalizedString("help_and_support", comment: "Help and support label (standard)"),
                "simplified": NSLocalizedString("help_and_support_simple", comment: "Help and support label (simplified)")
            ],
            "help_description": [
                "standard": NSLocalizedString("help_description", comment: "Help section description (standard)"),
                "simplified": NSLocalizedString("help_description_simple", comment: "Help section description (simplified)")
            ],
            "delete_credential": [
                "standard": NSLocalizedString("delete_credential", comment: "Delete credential label (standard)"),
                "simplified": NSLocalizedString("delete_credential_simple", comment: "Delete credential label (simplified)")
            ],
            "delete_credential_description": [
                "standard": NSLocalizedString("delete_credential_description_standard", comment: "Delete credential description (standard)"),
                "simplified": NSLocalizedString("delete_credential_description_simple", comment: "Delete credential description (simplified)")
            ],
            "delete_credential_confirm": [
                "standard": NSLocalizedString("delete_credential_confirm", comment: "Delete credential confirmation prompt (standard)"),
                "simplified": NSLocalizedString("delete_credential_confirm_simple", comment: "Delete credential confirmation prompt (simplified)")
            ],
            "reset_proving_key": [
                "standard": NSLocalizedString("reset_proving_key", comment: "Reset proving key label (standard)"),
                "simplified": NSLocalizedString("reset_proving_key_simple", comment: "Reset proving key label (simplified)")
            ],
            "reset_proving_key_description": [
                "standard": NSLocalizedString("reset_proving_key_description_standard", comment: "Reset proving key description (standard)"),
                "simplified": NSLocalizedString("reset_proving_key_description_simple", comment: "Reset proving key description (simplified)")
            ]
        ]
    }

    private func loadScreenContent() -> [String: [String: String]] {
        return [
            // Credential Screen
            "no_credential": [
                "standard": NSLocalizedString("no_credential_standard", comment: "No credential available message (standard)"),
                "simplified": NSLocalizedString("no_credential_simple", comment: "No credential available message (simplified)")
            ],
            "no_credential_message": [
                "standard": NSLocalizedString("no_credential_message_standard", comment: "No credential detailed message (standard)"),
                "simplified": NSLocalizedString("no_credential_message_simple", comment: "No credential detailed message (simplified)")
            ],
            "get_credential": [
                "standard": NSLocalizedString("get_credential", comment: "Get credential button label (standard)"),
                "simplified": NSLocalizedString("get_credential_simple", comment: "Get credential button label (simplified)")
            ],
            "find_locations": [
                "standard": NSLocalizedString("find_locations", comment: "Find locations button label (standard)"),
                "simplified": NSLocalizedString("find_locations_simple", comment: "Find locations button label (simplified)")
            ],
            "credential_active": [
                "standard": NSLocalizedString("credential_active", comment: "Credential active status label (standard)"),
                "simplified": NSLocalizedString("credential_active_simple", comment: "Credential active status label (simplified)")
            ],
            "credential_ready_message": [
                "standard": NSLocalizedString("credential_ready_message_standard", comment: "Credential ready message (standard)"),
                "simplified": NSLocalizedString("credential_ready_message_simple", comment: "Credential ready message (simplified)")
            ],
            "verify_age_now": [
                "standard": NSLocalizedString("verify_age_now", comment: "Verify age now button label (standard)"),
                "simplified": NSLocalizedString("verify_age_now_simple", comment: "Verify age now button label (simplified)")
            ],
            "credential_expired": [
                "standard": NSLocalizedString("credential_expired", comment: "Credential expired status label (standard)"),
                "simplified": NSLocalizedString("credential_expired_simple", comment: "Credential expired status label (simplified)")
            ],
            "credential_expired_message": [
                "standard": NSLocalizedString("credential_expired_message_standard", comment: "Credential expired message (standard)"),
                "simplified": NSLocalizedString("credential_expired_message_simple", comment: "Credential expired message (simplified)")
            ],
            "replace_credential": [
                "standard": NSLocalizedString("replace_credential", comment: "Replace credential button label (standard)"),
                "simplified": NSLocalizedString("replace_credential_simple", comment: "Replace credential button label (simplified)")
            ],

            // Verification Flow
            "scan_qr_code": [
                "standard": NSLocalizedString("scan_qr_code", comment: "Scan QR code button label (standard)"),
                "simplified": NSLocalizedString("scan_qr_code_simple", comment: "Scan QR code button label (simplified)")
            ],
            "scan_qr_instructions": [
                "standard": NSLocalizedString("scan_qr_instructions_standard", comment: "QR scan instructions (standard)"),
                "simplified": NSLocalizedString("scan_qr_instructions_simple", comment: "QR scan instructions (simplified)")
            ],
            "enter_code_manually": [
                "standard": NSLocalizedString("enter_code_manually", comment: "Enter code manually button label (standard)"),
                "simplified": NSLocalizedString("enter_code_manually_simple", comment: "Enter code manually button label (simplified)")
            ],
            "manual_entry_instructions": [
                "standard": NSLocalizedString("manual_entry_instructions_standard", comment: "Manual code entry instructions (standard)"),
                "simplified": NSLocalizedString("manual_entry_instructions_simple", comment: "Manual code entry instructions (simplified)")
            ],
            "processing_verification": [
                "standard": NSLocalizedString("processing_verification", comment: "Verification processing status (standard)"),
                "simplified": NSLocalizedString("processing_verification_simple", comment: "Verification processing status (simplified)")
            ],
            "verification_success": [
                "standard": NSLocalizedString("verification_success", comment: "Verification success status (standard)"),
                "simplified": NSLocalizedString("verification_success_simple", comment: "Verification success status (simplified)")
            ],
            "verification_success_message": [
                "standard": NSLocalizedString("verification_success_message", comment: "Verification success message (standard)"),
                "simplified": NSLocalizedString("verification_success_message_simple", comment: "Verification success message (simplified)")
            ],
            "verification_failed": [
                "standard": NSLocalizedString("verification_failed", comment: "Verification failed status (standard)"),
                "simplified": NSLocalizedString("verification_failed_simple", comment: "Verification failed status (simplified)")
            ],
            "verification_failed_message": [
                "standard": NSLocalizedString("verification_failed_message", comment: "Verification failed message (standard)"),
                "simplified": NSLocalizedString("verification_failed_message_simple", comment: "Verification failed message (simplified)")
            ],

            // Accessibility Settings
            "reading_level": [
                "standard": NSLocalizedString("reading_level_standard", comment: "Reading level label (standard)"),
                "simplified": NSLocalizedString("reading_level_simple", comment: "Reading level label (simplified)")
            ],
            "reading_level_description": [
                "standard": NSLocalizedString("reading_level_description_standard", comment: "Reading level description (standard)"),
                "simplified": NSLocalizedString("reading_level_description_simple", comment: "Reading level description (simplified)")
            ],
            "standard_reading": [
                "standard": NSLocalizedString("standard_reading_standard", comment: "Standard reading level option (standard)"),
                "simplified": NSLocalizedString("standard_reading_simple", comment: "Standard reading level option (simplified)")
            ],
            "simplified_reading": [
                "standard": NSLocalizedString("simplified_reading_standard", comment: "Simplified reading level option (standard)"),
                "simplified": NSLocalizedString("simplified_reading_simple", comment: "Simplified reading level option (simplified)")
            ],
            "large_text": [
                "standard": NSLocalizedString("large_text", comment: "Large text setting label (standard)"),
                "simplified": NSLocalizedString("large_text_simple", comment: "Large text setting label (simplified)")
            ],
            "high_contrast": [
                "standard": NSLocalizedString("high_contrast", comment: "High contrast setting label (standard)"),
                "simplified": NSLocalizedString("high_contrast_simple", comment: "High contrast setting label (simplified)")
            ],
            "touch_targets": [
                "standard": NSLocalizedString("touch_targets_standard", comment: "Touch targets setting label (standard)"),
                "simplified": NSLocalizedString("touch_targets_simple", comment: "Touch targets setting label (simplified)")
            ],
            "reduce_motion": [
                "standard": NSLocalizedString("reduce_motion", comment: "Reduce motion setting label (standard)"),
                "simplified": NSLocalizedString("reduce_motion_simple", comment: "Reduce motion setting label (simplified)")
            ],
            "verbose_descriptions": [
                "standard": NSLocalizedString("verbose_descriptions", comment: "Verbose descriptions setting label (standard)"),
                "simplified": NSLocalizedString("verbose_descriptions_simple", comment: "Verbose descriptions setting label (simplified)")
            ],
            "simplified_ui": [
                "standard": NSLocalizedString("simplified_ui", comment: "Simplified interface setting label (standard)"),
                "simplified": NSLocalizedString("simplified_ui_simple", comment: "Simplified interface setting label (simplified)")
            ],

            // Button Labels
            "continue": [
                "standard": NSLocalizedString("continue_standard", comment: "Continue button label (standard)"),
                "simplified": NSLocalizedString("continue_simple", comment: "Continue button label (simplified)")
            ],
            "cancel": [
                "standard": NSLocalizedString("cancel", comment: "Cancel button label (standard)"),
                "simplified": NSLocalizedString("cancel_simple", comment: "Cancel button label (simplified)")
            ],
            "done": [
                "standard": NSLocalizedString("done", comment: "Done button label (standard)"),
                "simplified": NSLocalizedString("done_simple", comment: "Done button label (simplified)")
            ],
            "close": [
                "standard": NSLocalizedString("close", comment: "Close button label (standard)"),
                "simplified": NSLocalizedString("close_simple", comment: "Close button label (simplified)")
            ],
            "try_again": [
                "standard": NSLocalizedString("try_again", comment: "Try again button label (standard)"),
                "simplified": NSLocalizedString("try_again_simple", comment: "Try again button label (simplified)")
            ],
            "go_back": [
                "standard": NSLocalizedString("go_back_standard", comment: "Go back button label (standard)"),
                "simplified": NSLocalizedString("go_back_simple", comment: "Go back button label (simplified)")
            ],

            // Form Instructions
            "enter_date_of_birth": [
                "standard": NSLocalizedString("enter_date_of_birth_standard", comment: "Enter date of birth form label (standard)"),
                "simplified": NSLocalizedString("enter_date_of_birth_simple", comment: "Enter date of birth form label (simplified)")
            ],
            "date_of_birth": [
                "standard": NSLocalizedString("date_of_birth", comment: "Date of birth field label (standard)"),
                "simplified": NSLocalizedString("date_of_birth_simple", comment: "Date of birth field label (simplified)")
            ],
            "configure_notification_preferences": [
                "standard": NSLocalizedString("configure_notification_preferences_standard", comment: "Configure notifications prompt (standard)"),
                "simplified": NSLocalizedString("configure_notification_preferences_simple", comment: "Configure notifications prompt (simplified)")
            ],
            "authentication_required": [
                "standard": NSLocalizedString("authentication_required_standard", comment: "Authentication required prompt (standard)"),
                "simplified": NSLocalizedString("authentication_required_simple", comment: "Authentication required prompt (simplified)")
            ],
            "tap_to_authenticate": [
                "standard": NSLocalizedString("tap_to_authenticate_standard", comment: "Tap to authenticate prompt (standard)"),
                "simplified": NSLocalizedString("tap_to_authenticate_simple", comment: "Tap to authenticate prompt (simplified)")
            ]
        ]
    }
}

// MARK: - Accessible Text View

struct AccessibleText: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @ObservedObject private var content = LocalizedContentManager.shared

    let key: ContentKey
    let level: ReadingLevel?

    init(_ key: ContentKey, level: ReadingLevel? = nil) {
        self.key = key
        self.level = level
    }

    var body: some View {
        Text(content.text(for: key, level: level))
            .font(AccessibleTypography.body)
            .accessibleText()
    }
}

// MARK: - String Extension

extension String {
    /// Returns a localised version of the string using NSLocalizedString
    func localized(level: ReadingLevel? = nil) -> String {
        let localized = NSLocalizedString(self, comment: "")

        // If a specific reading level is requested, check for simplified versions
        if let level = level, level == .simplified {
            // Try to get a simplified version by appending _simple suffix
            let simplifiedKey = "\(self)_simple"
            let simplified = NSLocalizedString(simplifiedKey, comment: "")
            if simplified != simplifiedKey {
                return simplified
            }
        }

        return localized
    }

    /// Returns a localised version with format arguments
    func localized(with arguments: CVarArg...) -> String {
        let format = localized()
        return String(format: format, arguments: arguments)
    }

    /// Returns a localised version with explicit locale
    func localized(locale: Locale) -> String {
        // For advanced localization scenarios
        return NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
}

// MARK: - Content Extension for AccessibilitySettings

extension AccessibilitySettings {
    /// Updates the reading level based on accessibility preferences
    /// - If simplified UI or verbose descriptions are enabled, defaults to simplified reading
    mutating func updateReadingLevel() {
        // If simplified UI is requested, use simplified reading level
        if simplifiedUI {
            readingLevel = .simplified
        }

        // If verbose descriptions are requested but simplified UI is not,
        // use standard level (verbose gives more detail, not simpler language)
        if verboseDescriptions && !simplifiedUI {
            readingLevel = .standard
        }
    }

    /// Checks if simplified reading is appropriate based on current settings
    var shouldUseSimplifiedReading: Bool {
        return readingLevel == .simplified || simplifiedUI
    }

    /// Returns the appropriate text for the current reading level
    func textForReadingLevel(standard: String, simplified: String) -> String {
        return shouldUseSimplifiedReading ? simplified : standard
    }
}
