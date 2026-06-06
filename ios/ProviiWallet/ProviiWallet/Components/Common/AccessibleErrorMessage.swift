// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// WCAG 2.2 AA compliant error message component. Meets 3.3.1 Error Identification (A),
/// 3.3.3 Error Suggestion (AA), and 1.4.3 Contrast (AA) with high contrast colours.
/// Optionally displays an actionable suggestion to help the user resolve the issue.
struct AccessibleErrorMessage: View {
    let error: String
    let suggestion: String?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            // Error Title
            Text(LocalizedString.error.localized)
                .font(AccessibleTypography.headlineMedium)
                .foregroundColor(AccessibleColors.error)
                .accessibilityAddTraits(.isHeader)

            // Error Message
            Text(error)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Suggestion (if provided)
            if let suggestion = suggestion {
                VStack(spacing: 8) {
                    Text(LocalizedString.suggestionLabel.localized)
                        .font(AccessibleTypography.bodyBold)
                        .foregroundColor(AccessibleColors.text)

                    Text(suggestion)
                        .font(AccessibleTypography.body)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }

            // Dismiss Button
            Button(action: onDismiss) {
                Text(LocalizedString.dismiss.localized)
                    .font(AccessibleTypography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: accessibilityManager.settings.increaseTouchTargets ? 60 : 44)
                    .background(AccessibleColors.primary)
                    .cornerRadius(8)
            }
            .accessibilityLabel(NSLocalizedString("accessibility.error.dismiss_error_message.label", comment: "Dismiss error message"))
            .accessibilityHint(NSLocalizedString("accessibility.error.dismiss_error_message.hint", comment: "Double tap to close this error"))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.cardBackground)
                .shadow(
                    color: Color.black.opacity(reduceMotion ? 0.1 : 0.2),
                    radius: reduceMotion ? 4 : 8,
                    x: 0,
                    y: reduceMotion ? 2 : 4
                )
        )
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.error.error_message.label", comment: "Error: %@. %@"), error, suggestion ?? ""))
        .accessibilityAddTraits(.isModal)
    }
}

#if DEBUG
struct AccessibleErrorMessage_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AccessibleErrorMessage(
                error: "Unable to process verification",
                suggestion: "Please check your network connection and try again",
                onDismiss: {}
            )
            .previewDisplayName("With Suggestion")

            AccessibleErrorMessage(
                error: "QR code not recognised",
                suggestion: nil,
                onDismiss: {}
            )
            .previewDisplayName("Without Suggestion")

            AccessibleErrorMessage(
                error: "Unable to process verification",
                suggestion: "Please check your network connection and try again",
                onDismiss: {}
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
