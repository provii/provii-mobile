// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// String extensions and a credential pronunciation manager for screen reader support.
/// Converts credential related abbreviations (mDL, DL, ISO 18013-5, ZK proof, QR code)
/// into VoiceOver friendly text. Satisfies WCAG 2.2 AAA pronunciation guidance for
/// technical terms used throughout the wallet.

extension String {
    /// Replaces credential-related abbreviations with screen reader-friendly versions
    /// This ensures terms like "mDL" are pronounced correctly by VoiceOver
    var pronunciationFriendly: String {
        var result = self

        // Replace credential-related abbreviations with full pronunciations
        result = result.replacingOccurrences(
            of: "mDL",
            with: "mobile driver's licence",
            options: .caseInsensitive
        )

        result = result.replacingOccurrences(
            of: " DL ",
            with: " driver's licence ",
            options: .caseInsensitive
        )

        result = result.replacingOccurrences(
            of: " DL.",
            with: " driver's licence.",
            options: .caseInsensitive
        )

        result = result.replacingOccurrences(
            of: "ISO 18013-5",
            with: "I.S.O. one eight zero one three dash five",
            options: .caseInsensitive
        )

        result = result.replacingOccurrences(
            of: "ISO 18013",
            with: "I.S.O. one eight zero one three",
            options: .caseInsensitive
        )

        return result
    }

    /// Returns a version of the string with improved pronunciation for accessibility labels
    /// Use this for accessibility labels where screen reader clarity is critical
    var accessibilityPronunciation: String {
        var result = pronunciationFriendly

        // Additional accessibility-specific replacements
        result = result.replacingOccurrences(
            of: "verifiable credential",
            with: "verifiable credential",
            options: .caseInsensitive
        )

        // Make sure "credential" is not mispronounced as "cre-den-tial"
        // VoiceOver typically handles this well, but we can emphasize if needed

        return result
    }
}

// MARK: - Credential Term Pronunciation Manager

/// Manages pronunciation guidance for credential-related terms
/// Provides centralised pronunciation strings for consistency
@MainActor
class CredentialPronunciationManager {
    static let shared = CredentialPronunciationManager()

    private init() {}

    // MARK: - Pronunciation Dictionary

    /// Returns the screen reader-friendly version of credential terms
    func pronunciation(for term: CredentialTerm) -> String {
        switch term {
        case .mobileDriverLicense:
            return "mobile driver's licence"
        case .driverLicense:
            return "driver's licence"
        case .credential:
            return "credential"
        case .verifiableCredential:
            return "verifiable credential"
        case .iso18013_5:
            return "I.S.O. one eight zero one three dash five"
        case .iso18013:
            return "I.S.O. one eight zero one three"
        case .zkProof:
            return "zero knowledge proof"
        case .qrCode:
            return "Q.R. code"
        }
    }

    /// Returns the abbreviated form (for display)
    func abbreviation(for term: CredentialTerm) -> String {
        switch term {
        case .mobileDriverLicense:
            return "mDL"
        case .driverLicense:
            return "DL"
        case .credential:
            return "credential"
        case .verifiableCredential:
            return "verifiable credential"
        case .iso18013_5:
            return "ISO 18013-5"
        case .iso18013:
            return "ISO 18013"
        case .zkProof:
            return "ZK proof"
        case .qrCode:
            return "QR code"
        }
    }

    /// Returns the full descriptive form (for first use or verbose mode)
    func fullDescription(for term: CredentialTerm) -> String {
        switch term {
        case .mobileDriverLicense:
            return "mobile driver's licence (mDL)"
        case .driverLicense:
            return "driver's licence (DL)"
        case .credential:
            return "credential"
        case .verifiableCredential:
            return "verifiable credential"
        case .iso18013_5:
            return "ISO 18013-5 (International Standard for mobile driving licences)"
        case .iso18013:
            return "ISO 18013 (International Standard for driving licences)"
        case .zkProof:
            return "zero knowledge proof (ZK proof)"
        case .qrCode:
            return "Quick Response code (QR code)"
        }
    }
}

// MARK: - Credential Term Enum

enum CredentialTerm {
    case mobileDriverLicense
    case driverLicense
    case credential
    case verifiableCredential
    case iso18013_5
    case iso18013
    case zkProof
    case qrCode
}

// MARK: - SwiftUI View Extension

import SwiftUI

extension View {
    /// Adds pronunciation-friendly accessibility label
    /// Automatically converts credential abbreviations to screen reader-friendly text
    func accessibilityPronunciation(_ label: String) -> some View {
        self.accessibilityLabel(label.accessibilityPronunciation)
    }

    /// Adds pronunciation hint for credential terms
    func credentialTermLabel(_ term: CredentialTerm, displayText: String? = nil) -> some View {
        let pronunciation = CredentialPronunciationManager.shared.pronunciation(for: term)
        let display = displayText ?? CredentialPronunciationManager.shared.abbreviation(for: term)

        return self
            .accessibilityLabel(pronunciation)
            .accessibilityValue(display)
    }
}
