// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI

// Localisation helper utilities that bridge StringCatalog, LocalizedContent, reading level
// support, abbreviation expansion, and number/date formatting. Provides extensions on
// LocalizedString, View, Text, String, Bundle, and DefaultStringInterpolation for
// convenient access to localised content throughout the app.

// MARK: - LocalizedString Extension

extension LocalizedString {
    /// Returns localised text with reading level support
    /// - Parameter level: Optional reading level override
    /// - Returns: Localised string appropriate for the reading level
    @MainActor
    func text(level: ReadingLevel? = nil) -> String {
        return LocalizedContentManager.shared.text(for: self, level: level)
    }

    /// Returns localised text with format arguments
    /// - Parameter arguments: Values to substitute into the format string
    /// - Returns: Formatted localised string
    @MainActor
    func text(_ arguments: CVarArg...) -> String {
        let format = text()
        return String(format: format, arguments: arguments)
    }

    /// Returns localised text with explicit comment for translators
    func textWithComment(_ comment: String) -> String {
        return NSLocalizedString(self.rawValue, comment: comment)
    }
}

// MARK: - View Extension for Localization

extension View {
    /// Apply localised text to a view element
    @MainActor
    func localizedText(_ key: LocalizedString, level: ReadingLevel? = nil) -> Text {
        Text(key.text(level: level))
    }

    /// Apply localised accessibility label
    @MainActor
    func localizedAccessibilityLabel(_ key: LocalizedString, level: ReadingLevel? = nil) -> some View {
        self.accessibilityLabel(key.text(level: level))
    }

    /// Apply localised accessibility hint
    @MainActor
    func localizedAccessibilityHint(_ key: LocalizedString) -> some View {
        self.accessibilityHint(key.text())
    }
}

// MARK: - Localization Helpers

@MainActor
struct LocalizationHelper {

    // MARK: - Language Detection

    /// Get the current app language
    static func currentLanguage() -> String {
        return LocalizedContentManager.shared.currentLanguage
    }

    /// Get available languages
    static func availableLanguages() -> [String] {
        return LocalizedContentManager.shared.availableLanguages()
    }

    /// Get display name for current language
    static func currentLanguageDisplayName() -> String {
        return LocalizedContentManager.shared.currentLanguageDisplayName()
    }

    // MARK: - Formatted Strings

    /// Format a localised string with multiple arguments
    static func format(_ key: LocalizedString, with arguments: [CVarArg]) -> String {
        let format = key.text()
        return String(format: format, arguments: arguments)
    }

    /// Format a localised string with a single argument
    static func format(_ key: LocalizedString, with argument: CVarArg) -> String {
        return format(key, with: [argument])
    }

    // MARK: - Pluralization

    /// Get plural form of a localised string
    /// - Parameters:
    ///   - key: Base localization key
    ///   - count: Number to determine plural form
    /// - Returns: Properly pluralised localised string
    static func plural(_ key: LocalizedString, count: Int) -> String {
        // iOS handles pluralization via .stringsdict files
        // For now, return the base string with count
        return key.text(count)
    }

    // MARK: - Time & Date Formatting

    /// Format a relative time string (e.g., "5 minutes ago")
    static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format an absolute date with localised format
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    /// Format a time duration in seconds to readable string
    static func formatDuration(seconds: Int) -> String {
        if seconds < 60 {
            return LocalizedString.secondsRemaining.text(seconds)
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) \(LocalizedString.minutes.localized)"
        } else {
            let hours = seconds / 3600
            return "\(hours) \(LocalizedString.hours.localized)"
        }
    }

    // MARK: - Reading Level Support

    /// Get text for a key with automatic reading level detection
    static func text(for key: LocalizedString) -> String {
        return LocalizedContentManager.shared.text(for: key)
    }

    /// Get text for a key with explicit reading level
    static func text(for key: LocalizedString, level: ReadingLevel) -> String {
        return LocalizedContentManager.shared.text(for: key, level: level)
    }

    /// Check if simplified reading level is active
    static func isSimplifiedReading() -> Bool {
        return AccessibilityManager.shared.settings.readingLevel == .simplified
    }

    // MARK: - Abbreviation Expansion

    /// Get full form of an abbreviation (for WCAG 2.2 AAA: 3.1.4)
    static func expandAbbreviation(_ key: LocalizedString) -> String {
        // Map common abbreviations to their full forms
        switch key {
        case .qr:
            return LocalizedString.qrFull.localized
        case .zkp:
            return LocalizedString.zkpFull.localized
        case .dob:
            return LocalizedString.dobFull.localized
        case .id:
            return LocalizedString.idFull.localized
        default:
            return key.text()
        }
    }

    // MARK: - Currency & Numbers

    /// Format a number with localised formatting
    static func formatNumber(_ number: Double, style: NumberFormatter.Style = .decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Format bytes to human-readable size (e.g., "87 MB")
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useAll]
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Error Messages

    /// Get localised error message with optional suggestion
    static func errorMessage(for error: Error, withSuggestion: Bool = true) -> String {
        let description = error.localizedDescription

        if withSuggestion {
            if let suggestion = errorSuggestion(for: description) {
                return "\(description)\n\n\(suggestion)"
            }
        }

        return description
    }

    /// Get suggested action for an error
    private static func errorSuggestion(for errorDescription: String) -> String? {
        let lowercased = errorDescription.lowercased()

        if lowercased.contains("credential") {
            return LocalizedString.errorSuggestionCredential.localized
        } else if lowercased.contains("network") || lowercased.contains("connection") {
            return LocalizedString.errorSuggestionNetwork.localized
        } else if lowercased.contains("qr") || lowercased.contains("code") {
            return LocalizedString.errorSuggestionQRCode.localized
        }

        return nil
    }

    // MARK: - Accessibility Helpers

    /// Get verbose description if accessibility requires it
    static func verboseText(standard: LocalizedString, verbose: LocalizedString) -> String {
        let manager = AccessibilityManager.shared
        return manager.settings.verboseDescriptions ? verbose.text() : standard.text()
    }

    /// Get simplified text if reading level requires it
    static func simplifiedText(standard: String, simplified: String) -> String {
        return isSimplifiedReading() ? simplified : standard
    }

    // MARK: - Debugging

    /// Check if a localization key exists
    static func keyExists(_ key: LocalizedString) -> Bool {
        let localized = NSLocalizedString(key.rawValue, comment: "")
        return localized != key.rawValue
    }

    /// Get all missing localization keys (for development)
    /// - Returns: Array of LocalizedString cases that don't have translations
    static func findMissingKeys() -> [LocalizedString] {
        #if DEBUG
        var missing: [LocalizedString] = []

        // Iterate through all LocalizedString cases
        for key in LocalizedString.allCases {
            if !keyExists(key) {
                missing.append(key)
            }
        }

        // Log missing keys count for debugging
        if !missing.isEmpty {
            print("[LocalizationHelper] Found \(missing.count) missing localization keys:")
            for key in missing.prefix(10) {
                print("  - \(key.rawValue)")
            }
            if missing.count > 10 {
                print("  ... and \(missing.count - 10) more")
            }
        }

        return missing
        #else
        // In release builds, skip the check for performance
        return []
        #endif
    }

    /// Validate all localization keys at app launch (debug only)
    #if DEBUG
    static func validateAllKeys() {
        let missing = findMissingKeys()
        if !missing.isEmpty {
            assertionFailure("[LocalizationHelper] Missing \(missing.count) localization keys. Run in debug mode to see the list.")
        }
    }
    #endif
}

// MARK: - Text Extension

extension Text {
    /// Create a Text view with localised string
    @MainActor
    init(_ key: LocalizedString, level: ReadingLevel? = nil) {
        self.init(key.text(level: level))
    }

    /// Create a Text view with formatted localised string
    @MainActor
    init(_ key: LocalizedString, _ arguments: CVarArg...) {
        let format = key.text()
        let formatted = String(format: format, arguments: arguments)
        self.init(formatted)
    }
}

// MARK: - String Interpolation Extension

extension DefaultStringInterpolation {
    /// Custom string interpolation for LocalizedString
    @MainActor
    mutating func appendInterpolation(_ value: LocalizedString) {
        appendLiteral(value.text())
    }

    /// Custom string interpolation with reading level
    @MainActor
    mutating func appendInterpolation(_ value: LocalizedString, level: ReadingLevel) {
        appendLiteral(value.text(level: level))
    }
}

// MARK: - Bundle Extension for Localization

extension Bundle {
    /// Get localised string with fallback
    func localizedString(forKey key: String, value: String?, table: String? = nil) -> String {
        return NSLocalizedString(key, tableName: table, bundle: self, value: value ?? key, comment: "")
    }

    /// Check if bundle supports a language
    func supportsLanguage(_ languageCode: String) -> Bool {
        return localizations.contains(languageCode)
    }
}

// MARK: - Preview Helper

#if DEBUG
struct LocalizationPreviewHelper {
    /// Force a specific language for SwiftUI previews
    static func setPreviewLanguage(_ languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    /// Reset to system language
    static func resetPreviewLanguage() {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}
#endif
