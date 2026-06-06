// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI

/// Pronunciation guide for security and authentication terms used by screen readers.
/// Maps technical acronyms and terms (NFC, FIDO2, HMAC, Face ID, Touch ID) to phonetic
/// or spelled out forms so VoiceOver pronounces them correctly. Also provides SwiftUI
/// view extensions for applying pronunciation aware accessibility labels.
struct PronunciationGuide {

    // MARK: - Security Term Pronunciations

    /// Returns the phonetic pronunciation or expanded text for a security term
    /// - Parameter term: The technical term to pronounce
    /// - Returns: Screen reader-friendly version of the term
    private static let pronunciations: [String: String] = [
        // Authentication Methods
        "biometric": "by-oh-metric",
        "biometrics": "by-oh-metrics",
        "authentication": "authentication",
        "yubikey": "you-bee-key",
        "yubico": "you-bee-co",
        // Acronyms - spell out letter by letter
        "nfc": "N F C",
        "fido2": "fye-doh two",
        "fido": "fye-doh",
        "pin": "P I N",
        "api": "A P I",
        "url": "U R L",
        "qr": "Q R",
        // Cryptographic Terms
        "cryptographic": "crypto-graphic",
        "hmac": "H-mac",
        "sha1": "S H A one",
        "sha256": "S H A two fifty-six",
        "zkp": "Z K P",
        // Face ID and Touch ID
        "face id": "Face I D",
        "touch id": "Touch I D"
    ]

    static func pronounce(_ term: String) -> String {
        pronunciations[term.lowercased()] ?? term
    }

    /// Returns an accessibility label with proper pronunciation for a security term
    /// Expands terms on first use and provides pronunciation hints
    /// - Parameters:
    ///   - term: The security term
    ///   - fullExpansion: The full expanded text (e.g., "Personal Identification Number" for "PIN")
    /// - Returns: Accessibility-friendly label
    static func accessibilityLabel(for term: String, fullExpansion: String? = nil) -> String {
        let pronunciation = pronounce(term)

        if let expansion = fullExpansion {
            return "\(expansion), \(pronunciation)"
        }

        return pronunciation
    }

    /// Common security terms with their full expansions
    static let commonExpansions: [String: String] = [
        "PIN": "Personal Identification Number",
        "NFC": "Near Field Communication",
        "FIDO2": "Fast Identity Online version 2",
        "API": "Application Programming Interface",
        "URL": "Uniform Resource Locator",
        "QR": "Quick Response",
        "HMAC": "Hash-based Message Authentication Code",
        "ZKP": "Zero Knowledge Proof"
    ]

    /// Returns the full expansion for an acronym or abbreviation
    /// - Parameter term: The abbreviated term
    /// - Returns: Full expansion if available, nil otherwise
    static func expansion(for term: String) -> String? {
        return commonExpansions[term.uppercased()]
    }

    /// Creates an accessible phrase with proper pronunciation
    /// Example: "Enter your PIN" becomes "Enter your Personal Identification Number, P I N"
    /// - Parameters:
    ///   - phrase: The phrase containing security terms
    ///   - terms: Array of security terms to expand
    /// - Returns: Accessibility-friendly version of the phrase
    static func accessiblePhrase(_ phrase: String, expandingTerms terms: [String]) -> String {
        var result = phrase

        for term in terms {
            if let expansion = expansion(for: term) {
                let pronunciation = pronounce(term)
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: range,
                        withTemplate: "\(expansion), \(pronunciation)"
                    )
                }
            }
        }

        return result
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Applies pronunciation-aware accessibility label for security terms
    /// - Parameters:
    ///   - text: The text containing security terms
    ///   - terms: Security terms that need pronunciation guidance
    /// - Returns: View with enhanced accessibility
    func securityTermLabel(_ text: String, pronouncing terms: [String] = []) -> some View {
        let accessibleText = terms.isEmpty ?
            text :
            PronunciationGuide.accessiblePhrase(text, expandingTerms: terms)

        return self.accessibilityLabel(accessibleText)
    }

    /// Applies biometric authentication accessibility with proper pronunciation
    /// - Parameter biometricType: The type of biometric (Face ID, Touch ID, etc.)
    /// - Returns: View with biometric-specific accessibility
    func biometricAccessibilityLabel(_ biometricType: String) -> some View {
        let pronunciation = PronunciationGuide.pronounce(biometricType)
        return self.accessibilityLabel("Biometric authentication using \(pronunciation)")
    }
}

// MARK: - Text Extension for Pronunciation

extension Text {
    /// Creates text with pronunciation hints for screen readers
    /// - Parameter term: Security term requiring pronunciation guidance
    /// - Returns: Text configured for proper pronunciation
    static func pronouncedSecurityTerm(_ term: String) -> Text {
        let pronounced = PronunciationGuide.pronounce(term)
        return Text(term)
            .accessibilityLabel(pronounced)
    }

    /// Creates text with full expansion and pronunciation for an acronym
    /// - Parameter acronym: The acronym to expand
    /// - Returns: Text with full accessibility support
    static func expandedAcronym(_ acronym: String) -> Text {
        if let expansion = PronunciationGuide.expansion(for: acronym) {
            let pronunciation = PronunciationGuide.pronounce(acronym)
            return Text(acronym)
                .accessibilityLabel("\(expansion), \(pronunciation)")
        }
        return Text(acronym)
    }
}

// MARK: - BiometricType Extension

extension PronunciationGuide {
    /// Returns accessibility-friendly text for biometric types
    /// - Parameter type: The biometric type identifier
    /// - Returns: Properly pronounced biometric type description
    static func biometricType(_ type: String) -> String {
        switch type.lowercased() {
        case "faceid", "face id":
            return "Face I D"
        case "touchid", "touch id":
            return "Touch I D"
        case "biometric":
            return "by-oh-metric authentication"
        default:
            return type
        }
    }

    /// Creates a descriptive accessibility label for biometric authentication
    /// - Parameters:
    ///   - type: The biometric type (Face ID, Touch ID, etc.)
    ///   - action: The action being performed (authenticate, unlock, etc.)
    /// - Returns: Complete accessibility label
    static func biometricActionLabel(type: String, action: String) -> String {
        let pronouncedType = biometricType(type)
        return "\(action) using \(pronouncedType)"
    }
}
