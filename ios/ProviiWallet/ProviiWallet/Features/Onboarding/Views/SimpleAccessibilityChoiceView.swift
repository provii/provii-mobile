// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Onboarding screen offering a choice between default accessibility settings and
/// the full accessibility configuration panel. Detects whether VoiceOver is active
/// and adjusts its layout accordingly. Matches the equivalent Android onboarding flow.
struct SimpleAccessibilityChoiceView: View {
    let onUseDefaults: () -> Void
    let onOpenSettings: () -> Void

    @StateObject private var accessibilityManager = AccessibilityManager.shared

    // Check VoiceOver status
    private var voiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    var body: some View {
        ZStack {
            Color.proviiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "accessibility")
                            .font(.system(size: 60))
                            .foregroundColor(.proviiPrimary)
                            .accessibilityHidden(true)

                        Text(NSLocalizedString("onboarding_accessibility_title", comment: "Accessibility"))
                            .font(ProviiTypography.headlineLarge)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text(NSLocalizedString("onboarding_accessibility_desc", comment: "Would you like to customize accessibility features like text size, touch targets, or reduced motion?"))
                            .font(ProviiTypography.bodyLarge)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    // VoiceOver detection banner
                    if voiceOverRunning {
                        voiceOverBanner
                            .padding(.horizontal, 24)
                    }

                    // Features list
                    featuresSection
                        .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 20)

                    // Buttons
                    VStack(spacing: 16) {
                        // Primary: Use Defaults
                        Button(action: onUseDefaults) {
                            Text(NSLocalizedString("onboarding_use_defaults", comment: "Use Defaults"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ProviiPrimaryButtonStyle())
                        .accessibilityHint(NSLocalizedString("onboarding_use_defaults_hint", comment: "Continue with default accessibility settings"))

                        // Secondary: Accessibility Settings
                        Button(action: onOpenSettings) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text(NSLocalizedString("onboarding_open_accessibility", comment: "Accessibility Settings"))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ProviiSecondaryButtonStyle())
                        .accessibilityHint(NSLocalizedString("onboarding_open_accessibility_hint", comment: "Open accessibility settings to customize"))
                    }
                    .padding(.horizontal, 24)

                    // Footer
                    Text(NSLocalizedString("onboarding_accessibility_later", comment: "You can change this later in Settings"))
                        .font(ProviiTypography.bodySmall)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - VoiceOver Banner

    private var voiceOverBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.proviiPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("onboarding_talkback_detected", comment: "VoiceOver Detected"))
                    .font(ProviiTypography.labelLarge)
                    .foregroundColor(.primary)

                Text(NSLocalizedString("onboarding_talkback_message", comment: "We've enabled detailed descriptions to help you navigate the app."))
                    .font(ProviiTypography.bodySmall)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.proviiPrimary.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("onboarding_accessibility_features_title", comment: "Features available:"))
                .font(ProviiTypography.labelLarge)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "textformat.size", text: NSLocalizedString("onboarding_feature_text_size", comment: "Larger text size"))
                featureRow(icon: "hand.tap", text: NSLocalizedString("onboarding_feature_touch_targets", comment: "Larger touch targets"))
                featureRow(icon: "figure.walk", text: NSLocalizedString("onboarding_feature_reduce_motion", comment: "Reduced motion"))
                featureRow(icon: "circle.lefthalf.filled", text: NSLocalizedString("onboarding_feature_high_contrast", comment: "High contrast mode"))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.proviiPrimary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(text)
                .font(ProviiTypography.bodyMedium)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SimpleAccessibilityChoiceView(
        onUseDefaults: { print("Use Defaults") },
        onOpenSettings: { print("Open Settings") }
    )
}
