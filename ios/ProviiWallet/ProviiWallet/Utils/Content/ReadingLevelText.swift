// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Reusable SwiftUI components for WCAG 2.2 AAA criterion 3.1.5 (Reading Level).
// Provides `ReadingLevelText` and `ReadingLevelTextString` views that automatically
// switch between standard and simplified text based on the user's accessibility
// settings, plus String and View extensions for inline reading level selection.

// MARK: - Reading Level Text Component

/// A reusable SwiftUI component that displays text based on the user's reading level preference.
/// Automatically switches between standard and simplified text based on AccessibilityManager settings.
struct ReadingLevelText: View {
    let standard: LocalizedStringKey
    let simplified: LocalizedStringKey
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    init(_ standard: LocalizedStringKey, simplified: LocalizedStringKey) {
        self.standard = standard
        self.simplified = simplified
    }

    var body: some View {
        Text(accessibilityManager.settings.readingLevel == .simplified ? simplified : standard)
    }
}

// MARK: - String-based variant

/// String-based variant for cases where LocalizedStringKey is not available
struct ReadingLevelTextString: View {
    let standard: String
    let simplified: String
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    init(standard: String, simplified: String) {
        self.standard = standard
        self.simplified = simplified
    }

    var body: some View {
        Text(accessibilityManager.settings.readingLevel == .simplified ? simplified : standard)
    }
}

// MARK: - Helper function for inline text selection

extension AccessibilitySettings {
    /// Returns the appropriate string based on current reading level
    func text(standard: String, simplified: String) -> String {
        return readingLevel == .simplified ? simplified : standard
    }
}

// MARK: - View extension for easy usage

extension View {
    /// Apply reading-level-aware text based on current accessibility settings
    @MainActor
    func readingLevelText(standard: LocalizedStringKey, simplified: LocalizedStringKey) -> Text {
        let manager = AccessibilityManager.shared
        return Text(manager.settings.readingLevel == .simplified ? simplified : standard)
    }
}

// MARK: - String extension for reading level

extension String {
    /// Returns a simplified version of the text if reading level requires it
    @MainActor
    func simplifiedIfNeeded(simplified: String) -> String {
        let manager = AccessibilityManager.shared
        return manager.settings.readingLevel == .simplified ? simplified : self
    }
}
