// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Manages pronunciation guides for technical and UI terms so VoiceOver pronounces
/// acronyms, brand names, and common phrases correctly. Provides both exact match
/// and contextual pattern replacement, along with SwiftUI view extensions for
/// pronunciation friendly labels, hints, and values.
@MainActor
class PronunciationManager {
    static let shared = PronunciationManager()

    private init() {}

    /// Dictionary mapping terms to their pronunciation-friendly forms
    /// Using spaces between letters forces VoiceOver to spell them out
    /// Using phonetic spellings helps with proper pronunciation
    private let pronunciations: [String: String] = [
        // Acronyms - spell out letter by letter
        "QR": "Q R",
        "API": "A P I",
        "URL": "U R L",
        "ID": "I D",
        "UI": "U I",
        "iOS": "eye O S",
        "mDL": "M D L",
        "PIN": "P I N",
        "UX": "U X",

        // Brand names and special terms
        "Provii": "par lee",

        // Common phrases
        "QR code": "Q R code",
        "QR Code": "Q R code",
        "API endpoint": "A P I endpoint",
        "URL link": "U R L link",
        "user ID": "user I D",
        "iOS app": "eye O S app"
    ]

    /// Additional context-aware pronunciations
    /// These are more complex patterns that need special handling
    private let contextualPronunciations: [(pattern: String, replacement: String)] = [
        ("QR scanner", "Q R scanner"),
        ("scan QR", "scan Q R"),
        ("QR scanning", "Q R scanning"),
        ("mDL credential", "M D L credential"),
        ("your ID", "your I D"),
        ("enter ID", "enter I D"),
        ("ID card", "I D card"),
        ("ID verification", "I D verification")
    ]

    // MARK: - Public Methods

    /// Apply pronunciation guides to a text string
    /// - Parameter text: Original text
    /// - Returns: Text with pronunciation-friendly replacements
    func applyPronunciation(to text: String) -> String {
        var result = text

        // Apply contextual (multi-word) patterns first so they take priority
        // over single-term matches. E.g. "QR code" matches before standalone "QR".
        for (pattern, replacement) in contextualPronunciations {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .caseInsensitive
            )
        }

        // Then apply single-term matches with word boundary regex to avoid
        // replacing substrings inside larger words (e.g. "ID" inside "IDENTIFICATION").
        for (term, pronunciation) in pronunciations {
            let escaped = NSRegularExpression.escapedPattern(for: term)
            let pattern = "\\b\(escaped)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: pronunciation)
            }
        }

        return result
    }

    /// Get pronunciation-friendly version of a term
    /// - Parameter term: The term to get pronunciation for
    /// - Returns: Pronunciation-friendly version, or original if not in dictionary
    func pronunciation(for term: String) -> String {
        return pronunciations[term] ?? term
    }

    /// Check if a term has a pronunciation guide
    /// - Parameter term: The term to check
    /// - Returns: True if pronunciation guide exists
    func hasPronunciation(for term: String) -> Bool {
        return pronunciations[term] != nil
    }

    /// Get all terms with pronunciation guides
    /// - Returns: Dictionary of all terms and their pronunciations
    func allPronunciations() -> [String: String] {
        return pronunciations
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Apply pronunciation-friendly accessibility label
    /// - Parameter label: The label text to make pronunciation-friendly
    /// - Returns: View with pronunciation-friendly accessibility label
    func pronunciationFriendly(_ label: String) -> some View {
        let friendlyLabel = PronunciationManager.shared.applyPronunciation(to: label)
        return self.accessibilityLabel(friendlyLabel)
    }

    /// Apply pronunciation-friendly accessibility hint
    /// - Parameter hint: The hint text to make pronunciation-friendly
    /// - Returns: View with pronunciation-friendly accessibility hint
    func pronunciationFriendlyHint(_ hint: String) -> some View {
        let friendlyHint = PronunciationManager.shared.applyPronunciation(to: hint)
        return self.accessibilityHint(friendlyHint)
    }

    /// Apply pronunciation-friendly accessibility value
    /// - Parameter value: The value text to make pronunciation-friendly
    /// - Returns: View with pronunciation-friendly accessibility value
    func pronunciationFriendlyValue(_ value: String) -> some View {
        let friendlyValue = PronunciationManager.shared.applyPronunciation(to: value)
        return self.accessibilityValue(friendlyValue)
    }

    /// Apply pronunciation guides to label, hint, and value
    /// - Parameters:
    ///   - label: Optional label text
    ///   - hint: Optional hint text
    ///   - value: Optional value text
    /// - Returns: View with all pronunciation-friendly accessibility properties
    func pronunciationFriendlyAccessibility(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        var view = AnyView(self)

        if let label = label {
            let friendlyLabel = PronunciationManager.shared.applyPronunciation(to: label)
            view = AnyView(view.accessibilityLabel(friendlyLabel))
        }

        if let hint = hint {
            let friendlyHint = PronunciationManager.shared.applyPronunciation(to: hint)
            view = AnyView(view.accessibilityHint(friendlyHint))
        }

        if let value = value {
            let friendlyValue = PronunciationManager.shared.applyPronunciation(to: value)
            view = AnyView(view.accessibilityValue(friendlyValue))
        }

        return view
    }
}

// MARK: - String Extension (Removed - defined in String+Pronunciation.swift)

// MARK: - Preview Helper

#if DEBUG
extension PronunciationManager {
    static var preview: PronunciationManager {
        return PronunciationManager()
    }

    /// Test pronunciation replacements
    func testPronunciations() {
        let testCases = [
            "Scan QR code to continue",
            "Enter your ID number",
            "The API is processing your request",
            "Visit this URL for more info",
            "Your mDL credential is ready",
            "Welcome to Provii Wallet for iOS",
            "The UI has been updated"
        ]

        print("Pronunciation Test Results:")
        print("=" * 50)
        for testCase in testCases {
            let result = applyPronunciation(to: testCase)
            print("Original: \(testCase)")
            print("Friendly:  \(result)")
            print("-" * 50)
        }
    }
}

private func * (lhs: String, rhs: Int) -> String {
    return String(repeating: lhs, count: rhs)
}
#endif
