// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Right to left focus order management for Arabic, Hebrew, Persian, Urdu and other
// RTL languages. Ensures VoiceOver traverses elements in the correct direction by
// reversing accessibility sort priorities in horizontal stacks, providing an RTL aware
// HStack wrapper, and resolving navigation chevron icons based on layout direction.

// MARK: - RTL Focus Order Helper

/// Provides proper accessibility sort priority for RTL languages
/// In RTL languages, focus should move from right to left, top to bottom
@MainActor
struct RTLFocusOrder {
    private let languageManager = LanguageManager.shared

    /// Get accessibility sort priority for an element based on RTL status
    /// - Parameters:
    ///   - ltrPriority: Priority for LTR languages (higher = later in focus order)
    ///   - rtlPriority: Priority for RTL languages (higher = later in focus order)
    /// - Returns: The appropriate priority based on current language direction
    func priority(ltr ltrPriority: Double, rtl rtlPriority: Double) -> Double {
        return languageManager.isRTL ? rtlPriority : ltrPriority
    }

    /// Get accessibility sort priority for horizontal stack elements
    /// In LTR: first element gets priority 1, second gets priority 2, etc.
    /// In RTL: first element gets priority 2, second gets priority 1, etc.
    /// - Parameters:
    ///   - index: Zero-based index of element in the horizontal stack
    ///   - count: Total number of elements in the stack
    /// - Returns: The appropriate priority for this element
    func horizontalPriority(index: Int, count: Int) -> Double {
        if languageManager.isRTL {
            // Reverse order for RTL: rightmost (highest index) should be focused first
            return Double(count - index)
        } else {
            // Normal order for LTR: leftmost (lowest index) should be focused first
            return Double(index + 1)
        }
    }

    /// Returns true if current language is RTL
    var isRTL: Bool {
        languageManager.isRTL
    }
}

// MARK: - View Extension for RTL-Aware Focus Order

extension View {
    /// Apply accessibility sort priority that adapts to RTL languages
    /// - Parameters:
    ///   - ltrPriority: Priority when in LTR mode
    ///   - rtlPriority: Priority when in RTL mode
    /// - Returns: Modified view with appropriate sort priority
    @MainActor
    func rtlAwareSortPriority(ltr ltrPriority: Double, rtl rtlPriority: Double) -> some View {
        let focusOrder = RTLFocusOrder()
        return self.accessibilitySortPriority(focusOrder.priority(ltr: ltrPriority, rtl: rtlPriority))
    }

    /// Apply accessibility sort priority for horizontal stack elements
    /// Automatically reverses focus order in RTL languages
    /// - Parameters:
    ///   - index: Zero-based index in the horizontal stack
    ///   - count: Total number of elements
    /// - Returns: Modified view with appropriate sort priority
    @MainActor
    func horizontalStackPriority(index: Int, count: Int) -> some View {
        let focusOrder = RTLFocusOrder()
        return self.accessibilitySortPriority(focusOrder.horizontalPriority(index: index, count: count))
    }
}

// MARK: - RTL-Aware HStack Wrapper

/// A horizontal stack that automatically handles RTL focus order for accessibility
struct RTLAwareHStack<Content: View>: View {
    @StateObject private var languageManager = LanguageManager.shared

    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content

    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
        // SwiftUI automatically handles layout direction based on environment
        // but we need to ensure focus order follows the same pattern
        .environment(\.layoutDirection, languageManager.isRTL ? .rightToLeft : .leftToRight)
    }
}

// MARK: - Accessibility Focus Order Helper Functions

/// Helper to get correct chevron icon for navigation based on language direction
/// - Parameter isForward: True for forward navigation, false for back navigation
/// - Returns: The correct system image name for the current language direction
@MainActor
func navigationChevron(isForward: Bool) -> String {
    let isRTL = LanguageManager.shared.isRTL

    if isForward {
        return isRTL ? "chevron.left" : "chevron.right"
    } else {
        return isRTL ? "chevron.right" : "chevron.left"
    }
}

// MARK: - Preview Helper

#if DEBUG
struct RTLFocusOrderPreview: View {
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Focus Order Test")
                .font(.title)

            Text("Language: \(languageManager.currentLanguage.englishName)")
            Text("RTL: \(languageManager.isRTL ? "Yes" : "No")")

            // Test horizontal focus order
            HStack(spacing: 16) {
                Text("First")
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .horizontalStackPriority(index: 0, count: 3)
                    .accessibilityLabel("First element")

                Text("Second")
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .horizontalStackPriority(index: 1, count: 3)
                    .accessibilityLabel("Second element")

                Text("Third")
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .horizontalStackPriority(index: 2, count: 3)
                    .accessibilityLabel("Third element")
            }

            Text("In RTL mode, focus should go: Third → Second → First")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("In LTR mode, focus should go: First → Second → Third")
                .font(.caption)
                .foregroundColor(.secondary)

            // Test navigation icons
            HStack {
                Image(systemName: navigationChevron(isForward: false))
                Text("Back")
                Spacer()
                Text("Forward")
                Image(systemName: navigationChevron(isForward: true))
            }
            .padding()
        }
        .padding()
    }
}

struct RTLFocusOrder_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RTLFocusOrderPreview()
                .previewDisplayName("LTR Mode")

            RTLFocusOrderPreview()
                .previewDisplayName("RTL Mode")
                .environment(\.layoutDirection, .rightToLeft)
                .onAppear {
                    // Simulate Arabic language
                    if let arabic = LanguageManager.shared.supportedLanguages.first(where: { $0.code == "ar" }) {
                        LanguageManager.shared.changeLanguage(to: arabic)
                    }
                }
        }
    }
}
#endif
