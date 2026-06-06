// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Generic error view that displays a warning icon, a localised title, the error
/// description, and an optional retry button. Used across multiple screens when
/// an operation fails and the user needs clear feedback on what went wrong.
struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(AccessibleTypography.title2)
                    .foregroundColor(.red)
                    .accessibilityHidden(true)

                Text(NSLocalizedString("ui.error.title", comment: "Error view title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(ErrorHandler.shared.handleError(error).userMessage)
                    .font(.body)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(NSLocalizedString("ui.error.accessibility_label_prefix", comment: "Error accessibility label prefix")). \(NSLocalizedString("ui.error.title", comment: "Error view title")). \(ErrorHandler.shared.handleError(error).userMessage)")

            if let retry = retry {
                Button(NSLocalizedString("ui.error.retry_button", comment: "Try again button text"), action: retry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(NSLocalizedString("ui.error.retry_button", comment: "Try again button text"))
                    .accessibilityHint(NSLocalizedString("ui.error.retry_button_hint", comment: "Try again button accessibility hint"))
            }
        }
        .padding()
    }
}
