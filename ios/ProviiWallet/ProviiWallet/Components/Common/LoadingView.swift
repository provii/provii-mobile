// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Full-screen loading indicator with a descriptive message. Announces its state
/// to VoiceOver and marks itself as frequently updating so assistive technologies
/// can poll for progress changes.
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.headline)
                .foregroundColor(AccessibleColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(NSLocalizedString("ui.loading.accessibility_label_prefix", comment: "Loading accessibility label prefix")). \(message)")
        .accessibilityValue(NSLocalizedString("ui.loading.accessibility_value_in_progress", comment: "Loading in progress accessibility value"))
        .accessibilityAddTraits(.updatesFrequently)
    }
}
