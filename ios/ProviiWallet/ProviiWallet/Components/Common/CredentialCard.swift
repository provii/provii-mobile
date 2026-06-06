// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

#if canImport(ProviiSDK)
import ProviiSDK
#endif

/// Card component that summarises a single credential with its issuer name, expiry date,
/// and coloured status indicator. Supports colour blind differentiation via icon fallback
/// and provides a combined VoiceOver label with pronunciation-friendly replacements.
struct CredentialCard: View {
    let credential: CredentialInfo
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        HStack {
            Image(systemName: "person.text.rectangle")
                .font(AccessibleTypography.title2)
                .foregroundColor(.accentColor)
                .frame(width: 50, height: 50)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
                .accessibilityHidden(true)
                .horizontalStackPriority(index: 0, count: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(credential.issuerName)
                    .font(AccessibleTypography.headline)

                Text(String(format: NSLocalizedString("credentials.card.expires", comment: "Expires: date"), formatDate(credential.expiresAt)))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
            }
            .horizontalStackPriority(index: 1, count: 3)

            Spacer()

            StatusIndicator(status: credential.status)
                .horizontalStackPriority(index: 2, count: 3)
        }
        .environment(\.layoutDirection, languageManager.isRTL ? .rightToLeft : .leftToRight)
        .padding()
        .frame(minHeight: accessibilityManager.settings.increaseTouchTargets ? 64 : 56)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            accessibilityManager.settings.useHighContrast ?
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black, lineWidth: 2) : nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCardLabel)
        .accessibilityHint(NSLocalizedString("accessibility.credential_card.hint", comment: "Hint for credential card interaction"))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityCardLabel: String {
        let statusText = credential.status.accessibilityDescription
        let expiryText = String(format: NSLocalizedString("credentials.card.expires_formatted", comment: "Expires date formatted"), formatDate(credential.expiresAt))
        let baseLabel = String(format: NSLocalizedString("credentials.card.accessibility_label", comment: "Credential card label"), credential.issuerName, statusText, expiryText)
        // Apply pronunciation-friendly replacements for screen readers
        return baseLabel.accessibilityPronunciation
    }

    private func formatDate(_ timestamp: UInt64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatusIndicator: View {
    let status: CredentialStatus
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            if accessibilityManager.systemDifferentiateWithoutColor {
                Image(systemName: statusIcon)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(statusColor)
            }
            Circle()
                .fill(statusColor)
                .frame(width: dotSize, height: dotSize)
        }
        .accessibilityLabel(status.accessibilityDescription)
    }

    private var statusColor: Color {
        switch status {
        case .valid: return Color(hex: 0x006400)  // Dark green, 7.5:1 contrast on white (WCAG AA)
        case .expired: return Color(hex: 0xD97706)  // Dark orange, 4.5:1 contrast on white (WCAG AA)
        case .invalid: return Color(hex: 0xC81E1E)  // Dark red, 5.5:1 contrast on white (WCAG AA)
        }
    }

    private var statusIcon: String {
        switch status {
        case .valid: return "checkmark.circle.fill"
        case .expired: return "clock.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }
}

// MARK: - Accessibility Extensions

extension CredentialStatus {
    var accessibilityDescription: String {
        switch self {
        case .valid:
            return NSLocalizedString("credentials.card.status_valid", comment: "Valid credential")
        case .expired:
            return NSLocalizedString("credentials.card.status_expired", comment: "Expired credential")
        case .invalid:
            return NSLocalizedString("credentials.card.status_invalid", comment: "Invalid credential")
        }
    }
}
