// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Accessible section header with proper heading hierarchy. Supports levels 1 through 3,
/// an optional subtitle, high contrast and extra large text modes, and verbose VoiceOver
/// descriptions that include the heading level (WCAG 2.2 AAA: 2.4.10 Section Headings).
struct AccessibleSectionHeader: View {
    @ObservedObject private var manager = AccessibilityManager.shared

    let title: String
    let level: Int // 1, 2, or 3 for heading hierarchy
    let subtitle: String?

    init(title: String, level: Int = 2, subtitle: String? = nil) {
        self.title = title
        self.level = min(max(level, 1), 3) // Clamp to 1-3
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subtitleSpacing) {
            Text(title)
                .font(fontForLevel)
                .fontWeight(fontWeight)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(accessibilityLabel)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundColor(subtitleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, bottomPadding)
    }

    // MARK: - Computed Properties

    private var fontForLevel: Font {
        switch level {
        case 1:
            return manager.settings.useExtraLargeText ?
                .system(size: 42, weight: .bold) : AccessibleTypography.title
        case 2:
            return manager.settings.useExtraLargeText ?
                .system(size: 33, weight: .semibold) : AccessibleTypography.title2
        case 3:
            return manager.settings.useExtraLargeText ?
                .system(size: 30, weight: .semibold) : AccessibleTypography.title3
        default:
            return AccessibleTypography.headline
        }
    }

    private var subtitleFont: Font {
        manager.settings.useExtraLargeText ?
            AccessibleTypography.body : AccessibleTypography.subheadline
    }

    private var fontWeight: Font.Weight {
        switch level {
        case 1: return .bold
        case 2, 3: return .semibold
        default: return .medium
        }
    }

    private var textColor: Color {
        if manager.settings.useHighContrast {
            return .black
        }
        return .primary
    }

    private var subtitleColor: Color {
        if manager.settings.useHighContrast {
            return Color(hex: 0x383838) // Ensures 10:1 contrast
        }
        return .secondary
    }

    private var accessibilityLabel: String {
        if manager.settings.verboseDescriptions {
            return String(format: NSLocalizedString("accessibility.section_header.heading_level", comment: "Heading level"), level, title)
        }
        return title
    }

    private var subtitleSpacing: CGFloat {
        manager.settings.increaseTouchTargets ? 8 : 4
    }

    private var bottomPadding: CGFloat {
        switch level {
        case 1: return manager.settings.increaseTouchTargets ? 16 : 12
        case 2: return manager.settings.increaseTouchTargets ? 12 : 8
        case 3: return manager.settings.increaseTouchTargets ? 8 : 4
        default: return 4
        }
    }
}

// MARK: - Convenience Initialisers

extension AccessibleSectionHeader {
    /// Create a level 1 heading (page title)
    static func h1(_ title: String, subtitle: String? = nil) -> AccessibleSectionHeader {
        AccessibleSectionHeader(title: title, level: 1, subtitle: subtitle)
    }

    /// Create a level 2 heading (major section)
    static func h2(_ title: String, subtitle: String? = nil) -> AccessibleSectionHeader {
        AccessibleSectionHeader(title: title, level: 2, subtitle: subtitle)
    }

    /// Create a level 3 heading (subsection)
    static func h3(_ title: String, subtitle: String? = nil) -> AccessibleSectionHeader {
        AccessibleSectionHeader(title: title, level: 3, subtitle: subtitle)
    }
}

// MARK: - Preview

#if DEBUG
struct AccessibleSectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AccessibleSectionHeader.h1("Level 1 Heading", subtitle: "Page title")
                Text("Content for level 1 section...")

                AccessibleSectionHeader.h2("Level 2 Heading", subtitle: "Major section")
                Text("Content for level 2 section...")

                AccessibleSectionHeader.h3("Level 3 Heading")
                Text("Content for level 3 section...")

                // Standard vs High Contrast
                Group {
                    AccessibleSectionHeader.h2("Standard Contrast")
                    AccessibleSectionHeader.h2("High Contrast")
                        .environmentObject({
                            let manager = AccessibilityManager.shared
                            manager.settings.useHighContrast = true
                            return manager
                        }())
                }
            }
            .padding()
        }
    }
}
#endif
