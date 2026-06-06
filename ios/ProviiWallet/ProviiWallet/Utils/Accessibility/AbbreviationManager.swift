// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

/// Manages abbreviation expansion across the app to satisfy WCAG 2.2 AAA criterion 3.1.4.
/// Tracks which abbreviations have already been shown in the current session or per view,
/// ensuring the first occurrence is always expanded (e.g. "QR (Quick Response)").
/// Provides convenience methods for common abbreviations and pronunciation friendly text.
@MainActor
class AbbreviationManager: ObservableObject {
    static let shared = AbbreviationManager()

    /// Track which abbreviations have been shown in current session
    private var expandedAbbreviations: Set<String> = []

    /// Track which abbreviations have been shown per view
    private var viewExpandedAbbreviations: [String: Set<String>] = [:]

    private init() {
        // Load persisted state if needed
        loadPersistedState()
    }

    // MARK: - Session-Level Tracking

    /// Get text for abbreviation, expanding on first use
    /// - Parameters:
    ///   - abbreviation: The short form (e.g., "QR")
    ///   - fullForm: The expanded form (e.g., "Quick Response")
    /// - Returns: Expanded text on first use, abbreviation on subsequent uses
    /// - Note: The fullForm should be localised before passing to this method
    func text(for abbreviation: String, fullForm: String) -> String {
        if !expandedAbbreviations.contains(abbreviation) {
            expandedAbbreviations.insert(abbreviation)
            return "\(fullForm) (\(abbreviation))"
        }
        return abbreviation
    }

    // MARK: - View-Level Tracking

    /// Get text for abbreviation with view-specific tracking
    /// Useful for views that may be revisited
    /// - Parameters:
    ///   - abbreviation: The short form
    ///   - fullForm: The expanded form
    ///   - viewId: Unique identifier for the view
    /// - Returns: Expanded text on first use in this view
    func text(for abbreviation: String, fullForm: String, viewId: String) -> String {
        var viewExpanded = viewExpandedAbbreviations[viewId] ?? Set<String>()

        if !viewExpanded.contains(abbreviation) {
            viewExpanded.insert(abbreviation)
            viewExpandedAbbreviations[viewId] = viewExpanded
            return "\(fullForm) (\(abbreviation))"
        }
        return abbreviation
    }

    /// Reset tracking for a specific view
    func resetView(_ viewId: String) {
        viewExpandedAbbreviations.removeValue(forKey: viewId)
    }

    /// Reset all tracking (useful for testing or session reset)
    func resetAll() {
        expandedAbbreviations.removeAll()
        viewExpandedAbbreviations.removeAll()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Could load from UserDefaults if we want persistence across app launches
        // For now, session-only is sufficient for AAA compliance
    }

    private func savePersistedState() {
        // Could save to UserDefaults if needed
    }
}

// MARK: - Common Abbreviations

extension AbbreviationManager {
    /// Pre-defined abbreviations used in the app
    enum CommonAbbreviation {
        case qr
        case api
        case url
        case pin
        case id
        case ui
        case ux
        case mdl
        case ios

        var abbreviation: String {
            switch self {
            case .qr: return "QR"
            case .api: return "API"
            case .url: return "URL"
            case .pin: return "PIN"
            case .id: return "ID"
            case .ui: return "UI"
            case .ux: return "UX"
            case .mdl: return "mDL"
            case .ios: return "iOS"
            }
        }

        var fullForm: String {
            switch self {
            case .qr: return NSLocalizedString("abbreviation.qr.full", comment: "Quick Response (localized)")
            case .api: return NSLocalizedString("abbreviation.api.full", comment: "Application Programming Interface (localized)")
            case .url: return NSLocalizedString("abbreviation.url.full", comment: "Uniform Resource Locator (localized)")
            case .pin: return NSLocalizedString("abbreviation.pin.full", comment: "Personal Identification Number (localized)")
            case .id: return NSLocalizedString("abbreviation.id.full", comment: "Identification (localized)")
            case .ui: return NSLocalizedString("abbreviation.ui.full", comment: "User Interface (localized)")
            case .ux: return NSLocalizedString("abbreviation.ux.full", comment: "User Experience (localized)")
            case .mdl: return NSLocalizedString("abbreviation.mdl.full", comment: "Mobile Driver's License (localized)")
            case .ios: return NSLocalizedString("abbreviation.ios.full", comment: "Apple's mobile operating system (localized)")
            }
        }

        /// Get pronunciation-friendly version for screen readers
        @MainActor
        var pronunciation: String {
            return PronunciationManager.shared.pronunciation(for: abbreviation)
        }
    }

    /// Convenience method for common abbreviations
    func text(for common: CommonAbbreviation) -> String {
        return text(for: common.abbreviation, fullForm: common.fullForm)
    }

    /// View-specific convenience method for common abbreviations
    func text(for common: CommonAbbreviation, viewId: String) -> String {
        return text(for: common.abbreviation, fullForm: common.fullForm, viewId: viewId)
    }

    /// Get pronunciation-friendly text for accessibility
    /// - Parameter common: The common abbreviation
    /// - Returns: Pronunciation-friendly text for screen readers
    func accessibilityText(for common: CommonAbbreviation) -> String {
        let displayText = text(for: common)
        return PronunciationManager.shared.applyPronunciation(to: displayText)
    }

    /// Get pronunciation-friendly text for accessibility (view-specific)
    /// - Parameters:
    ///   - common: The common abbreviation
    ///   - viewId: Unique identifier for the view
    /// - Returns: Pronunciation-friendly text for screen readers
    func accessibilityText(for common: CommonAbbreviation, viewId: String) -> String {
        let displayText = text(for: common, viewId: viewId)
        return PronunciationManager.shared.applyPronunciation(to: displayText)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Add abbreviation expansion capability to a view
    func withAbbreviationManager() -> some View {
        self.environmentObject(AbbreviationManager.shared)
    }
}

// MARK: - Preview Helper

#if DEBUG
extension AbbreviationManager {
    static var preview: AbbreviationManager {
        let manager = AbbreviationManager()
        return manager
    }
}
#endif
