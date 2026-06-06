// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Navigation related View extensions for WCAG 2.2 compliance. Provides breadcrumb
// path setting (AAA 2.4.8 Location) and accessibility language overrides for
// VoiceOver pronunciation of content in specific languages.

// MARK: - Navigation Path Extension
extension View {
    /// Sets the navigation breadcrumb path for WCAG 2.2 AAA 2.4.8 Location
    /// This provides users with information about their location within the app hierarchy
    func setNavigationPath(_ path: [String]) -> some View {
        self.modifier(NavigationPathModifier(path: path))
    }
}

struct NavigationPathModifier: ViewModifier {
    let path: [String]
    @AccessibilityFocusState private var isAccessibilityFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(String(format: LocalizedString.navigationPathPrefix.localized, path.joined(separator: " > ")))
    }
}

// MARK: - Accessibility Language Extension
extension View {
    /// Sets the accessibility language for VoiceOver
    /// Helps VoiceOver properly pronounce content in the specified language
    func accessibilityLanguage(_ languageCode: String) -> some View {
        self.modifier(AccessibilityLanguageModifier(languageCode: languageCode))
    }
}

struct AccessibilityLanguageModifier: ViewModifier {
    let languageCode: String

    func body(content: Content) -> some View {
        // Note: SwiftUI doesn't have direct language override, but we can
        // provide it as an accessibility value for context
        content
            .environment(\.locale, Locale(identifier: languageCode))
    }
}
