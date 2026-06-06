// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Breadcrumb navigation showing the user's current location in the app hierarchy.
/// Supports RTL layout, high contrast mode, and verbose VoiceOver descriptions
/// (WCAG 2.2 AAA: 2.4.8 Location).
struct BreadcrumbView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    let path: [String]

    var body: some View {
        if !path.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Image(systemName: navigationChevron(isForward: true))
                            .font(fontSize(for: .caption2))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }

                    Text(item)
                        .font(fontSize(for: .caption))
                        .foregroundColor(textColor(for: index))
                        .lineLimit(1)
                        .horizontalStackPriority(index: index, count: path.count)
                }
            }
            .environment(\.layoutDirection, languageManager.isRTL ? .rightToLeft : .leftToRight)
            .padding(.horizontal, manager.settings.increaseTouchTargets ? 20 : 16)
            .padding(.vertical, manager.settings.increaseTouchTargets ? 12 : 8)
            .background(backgroundColor)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Computed Properties

    private var accessibilityLabel: String {
        if manager.settings.verboseDescriptions {
            return String(format: NSLocalizedString("accessibility.breadcrumb.location_verbose", comment: "Verbose location"), path.joined(separator: ", then "))
        }
        return String(format: NSLocalizedString("accessibility.breadcrumb.location", comment: "Location"), path.joined(separator: ", "))
    }

    private func textColor(for index: Int) -> Color {
        let isLast = index == path.count - 1

        if manager.settings.useHighContrast {
            return isLast ? .black : Color(hex: 0x383838)
        }

        return isLast ? .primary : .secondary
    }

    private var backgroundColor: Color {
        if manager.settings.reduceTransparency {
            return Color(.systemBackground)
        }
        return Color(.systemBackground).opacity(0.95)
    }

    private func fontSize(for style: Font.TextStyle) -> Font {
        switch style {
        case .caption:
            return manager.settings.useExtraLargeText ? .footnote : .caption
        case .caption2:
            return manager.settings.useExtraLargeText ? .caption : .caption2
        default:
            return .caption
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add breadcrumb navigation to a view
    func breadcrumb(_ path: [String]) -> some View {
        self.safeAreaInset(edge: .top, spacing: 0) {
            BreadcrumbView(path: path)
        }
    }

    /// Add breadcrumb navigation with variadic parameters
    func breadcrumb(_ items: String...) -> some View {
        self.breadcrumb(items)
    }
}

// MARK: - Preview

#if DEBUG
struct BreadcrumbView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard mode
            VStack {
                BreadcrumbView(path: ["Home", "Settings", "Accessibility"])
                Spacer()
            }
            .previewDisplayName("Standard")

            // High contrast
            VStack {
                BreadcrumbView(path: ["Home", "Settings", "Accessibility", "Vision"])
                Spacer()
            }
            .environmentObject({
                let manager = AccessibilityManager.shared
                manager.settings.useHighContrast = true
                return manager
            }())
            .previewDisplayName("High Contrast")

            // Large text
            VStack {
                BreadcrumbView(path: ["Home", "Credentials"])
                Spacer()
            }
            .environmentObject({
                let manager = AccessibilityManager.shared
                manager.settings.useExtraLargeText = true
                return manager
            }())
            .previewDisplayName("Large Text")
        }
    }
}
#endif
