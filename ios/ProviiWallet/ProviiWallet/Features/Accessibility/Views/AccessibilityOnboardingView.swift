// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Multi-step onboarding flow for configuring accessibility preferences on first launch.
/// Guides users through profile selection (vision, motor, cognitive, elderly) or custom configuration
/// of vision and interaction settings, with live preview and step by step progress tracking.

struct AccessibilityOnboardingView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var currentStep = 0
    @State private var selectedProfile: AccessibilityProfile?
    @State private var customSettings = AccessibilitySettings()

    let onComplete: () -> Void

    private let steps = [
        OnboardingStep.welcome,
        OnboardingStep.quickSetup,
        OnboardingStep.vision,
        OnboardingStep.interaction,
        OnboardingStep.complete
    ]

    var body: some View {
        ZStack {
            Color.proviiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                if currentStep > 0 && currentStep < steps.count - 1 {
                    ProgressBar(current: currentStep, total: steps.count - 1)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Content
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        stepContent(for: steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(accessibilityManager.settings.reduceMotion ? nil : .easeInOut, value: currentStep)

                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle(NSLocalizedString("accessibility.onboarding.navigation_title", comment: "Accessibility Setup"))
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
    }

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                switch step {
                case .welcome:
                    WelcomeStepView()

                case .quickSetup:
                    QuickSetupStepView(selectedProfile: $selectedProfile)

                case .vision:
                    VisionSettingsStepView(settings: $customSettings)

                case .interaction:
                    InteractionSettingsStepView(settings: $customSettings)

                case .complete:
                    CompleteStepView(settings: customSettings)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: previousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(NSLocalizedString("onboarding_back_button", comment: "Back"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProviiSecondaryButtonStyle())
                .accessibilityLabel(AccessibilityLabels.back)
            }

            Button(action: nextStep) {
                HStack {
                    Text(nextButtonTitle)
                    if currentStep < steps.count - 1 {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProviiPrimaryButtonStyle())
            .accessibilityLabel(nextButtonAccessibilityLabel)
        }
        .frame(minHeight: 50)
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case 0: return NSLocalizedString("onboarding_get_started", comment: "Get Started")
        case steps.count - 1: return NSLocalizedString("onboarding_finish_setup", comment: "Finish Setup")
        default: return NSLocalizedString("onboarding_next", comment: "Next")
        }
    }

    private var nextButtonAccessibilityLabel: String {
        switch currentStep {
        case 0: return NSLocalizedString("accessibility.onboarding.start_setup", comment: "Start accessibility setup")
        case steps.count - 1: return NSLocalizedString("accessibility.onboarding.complete_setup", comment: "Complete setup and continue to app")
        default: return NSLocalizedString("accessibility.onboarding.continue_next", comment: "Continue to next step")
        }
    }

    private func nextStep() {
        if currentStep == 1, let profile = selectedProfile {
            // Apply quick setup profile
            accessibilityManager.applyQuickSetup(profile)
            if profile != .default {
                // Skip to complete if a preset was chosen
                currentStep = steps.count - 1
                return
            }
        }

        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            completeOnboarding()
        }
    }

    private func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    private func completeOnboarding() {
        // Save custom settings if no profile was selected
        if selectedProfile == nil || selectedProfile == .default {
            accessibilityManager.updateSettings(customSettings)
        }

        // Mark onboarding as complete
        accessibilityManager.updateSetting(\.hasCompletedAccessibilityOnboarding, value: true)

        // Trigger completion
        onComplete()
    }
}

// MARK: - Step Views

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "accessibility")
                .font(AccessibleTypography.title)
                .foregroundColor(.proviiPrimary)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text(NSLocalizedString("onboarding_welcome_title", comment: "Welcome to Provii Wallet"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("onboarding_welcome_subtitle", comment: "Let's make sure this app works perfectly for you"))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureHighlightRow(
                    icon: "eye",
                    title: NSLocalizedString("onboarding_vision_support_title", comment: "Vision Support"),
                    description: NSLocalizedString("onboarding_vision_support_description", comment: "Large text, high contrast, and VoiceOver optimisation")
                )

                FeatureHighlightRow(
                    icon: "hand.raised",
                    title: NSLocalizedString("onboarding_easy_interaction_title", comment: "Easy Interaction"),
                    description: NSLocalizedString("onboarding_easy_interaction_description", comment: "Larger buttons, simplified gestures, and extended timeouts")
                )

                FeatureHighlightRow(
                    icon: "brain.head.profile",
                    title: NSLocalizedString("onboarding_cognitive_assistance_title", comment: "Cognitive Assistance"),
                    description: NSLocalizedString("onboarding_cognitive_assistance_description", comment: "Clear instructions, step indicators, and simplified interface")
                )
            }
            .padding(.top, 20)

            Text(NSLocalizedString("onboarding_quick_setup_time", comment: "This quick setup takes less than 2 minutes"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct QuickSetupStepView: View {
    @Binding var selectedProfile: AccessibilityProfile?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding_quick_setup_title", comment: "Quick Setup"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("onboarding_quick_setup_subtitle", comment: "Choose a preset or customise your settings"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ProfileButton(
                    profile: .visionImpaired,
                    title: NSLocalizedString("profile_vision_impaired_title", comment: "Vision Impaired"),
                    description: NSLocalizedString("profile_vision_impaired_description", comment: "Optimised for low vision or blindness"),
                    icon: "eye.slash",
                    isSelected: selectedProfile == .visionImpaired,
                    action: { selectedProfile = .visionImpaired }
                )

                ProfileButton(
                    profile: .motorImpaired,
                    title: NSLocalizedString("profile_motor_difficulties_title", comment: "Motor Difficulties"),
                    description: NSLocalizedString("profile_motor_difficulties_description", comment: "Easier touch targets and interactions"),
                    icon: "hand.raised",
                    isSelected: selectedProfile == .motorImpaired,
                    action: { selectedProfile = .motorImpaired }
                )

                ProfileButton(
                    profile: .elderly,
                    title: NSLocalizedString("profile_senior_friendly_title", comment: "Senior Friendly"),
                    description: NSLocalizedString("profile_senior_friendly_description", comment: "Larger text, simpler interface"),
                    icon: "person.crop.circle",
                    isSelected: selectedProfile == .elderly,
                    action: { selectedProfile = .elderly }
                )

                ProfileButton(
                    profile: .default,
                    title: NSLocalizedString("profile_custom_settings_title", comment: "Custom Settings"),
                    description: NSLocalizedString("profile_custom_settings_description", comment: "I'll choose my own settings"),
                    icon: "slider.horizontal.3",
                    isSelected: selectedProfile == .default,
                    action: { selectedProfile = .default }
                )
            }

            if selectedProfile == nil {
                Text(NSLocalizedString("onboarding_settings_changeable", comment: "You can change these settings anytime in Settings"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top)
            }
        }
    }
}

private struct VisionSettingsStepView: View {
    @Binding var settings: AccessibilitySettings

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding_vision_settings_title", comment: "Vision Settings"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("onboarding_vision_settings_subtitle", comment: "Adjust visual preferences"))
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                ToggleRow(
                    title: NSLocalizedString("setting_extra_large_text_title", comment: "Extra Large Text"),
                    description: NSLocalizedString("setting_extra_large_text_description", comment: "Make all text 50% larger"),
                    isOn: $settings.useExtraLargeText,
                    icon: "textformat.size"
                )

                ToggleRow(
                    title: NSLocalizedString("setting_high_contrast_title", comment: "High Contrast"),
                    description: NSLocalizedString("setting_high_contrast_description", comment: "Increase colour contrast for better visibility"),
                    isOn: $settings.useHighContrast,
                    icon: "circle.lefthalf.filled"
                )

                ToggleRow(
                    title: NSLocalizedString("setting_reduce_transparency_title", comment: "Reduce Transparency"),
                    description: NSLocalizedString("setting_reduce_transparency_description", comment: "Remove blur effects and transparency"),
                    isOn: $settings.reduceTransparency,
                    icon: "square.on.square"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Label(NSLocalizedString("setting_color_blind_mode_title", comment: "Colour Blind Mode"), systemImage: "eye.trianglebadge.exclamationmark")
                        .font(.headline)

                    Picker(NSLocalizedString("setting_color_blind_mode_title", comment: "Colour Blind Mode"), selection: $settings.colorBlindMode) {
                        ForEach(AccessibilitySettings.ColorBlindMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 8)
            }

            // Preview area
            PreviewCard(settings: settings)
                .padding(.top)
        }
    }
}

private struct InteractionSettingsStepView: View {
    @Binding var settings: AccessibilitySettings

    // Computed binding to bridge extendedTimeouts boolean to timeoutBehavior enum
    private var extendedTimeoutsBinding: Binding<Bool> {
        Binding(
            get: { settings.timeoutBehavior == .extended },
            set: { newValue in
                settings.timeoutBehavior = newValue ? .extended : .standard
            }
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding_interaction_settings_title", comment: "Interaction Settings"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("onboarding_interaction_settings_subtitle", comment: "Make the app easier to use"))
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                ToggleRow(
                    title: NSLocalizedString("setting_larger_touch_targets_title", comment: "Larger Touch Targets"),
                    description: NSLocalizedString("setting_larger_touch_targets_description", comment: "Make buttons and controls easier to tap"),
                    isOn: $settings.increaseTouchTargets,
                    icon: "hand.tap"
                )

                ToggleRow(
                    title: NSLocalizedString("setting_reduce_motion_title", comment: "Reduce Motion"),
                    description: NSLocalizedString("setting_reduce_motion_description", comment: "Minimise animations and transitions"),
                    isOn: $settings.reduceMotion,
                    icon: "figure.walk.motion"
                )

                ToggleRow(
                    title: NSLocalizedString("setting_extended_timeouts_title", comment: "Extended Timeouts"),
                    description: NSLocalizedString("setting_extended_timeouts_description", comment: "More time for timed actions"),
                    isOn: extendedTimeoutsBinding,
                    icon: "clock"
                )

                ToggleRow(
                    title: NSLocalizedString("setting_haptic_feedback_title", comment: "Haptic Feedback"),
                    description: NSLocalizedString("setting_haptic_feedback_description", comment: "Feel vibrations for important actions"),
                    isOn: $settings.hapticFeedback,
                    icon: "waveform"
                )

                ToggleRow(
                    title: NSLocalizedString("setting_manual_code_entry_title", comment: "Manual Code Entry"),
                    description: NSLocalizedString("setting_manual_code_entry_description", comment: "Alternative to QR code scanning"),
                    isOn: $settings.enableManualCodeEntry,
                    icon: "keyboard"
                )
            }
        }
    }
}

private struct CompleteStepView: View {
    let settings: AccessibilitySettings

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(AccessibleTypography.title)
                .foregroundColor(.green)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text(NSLocalizedString("onboarding_setup_complete_title", comment: "Setup Complete!"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("onboarding_setup_complete_subtitle", comment: "Your accessibility preferences have been saved"))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Summary of enabled features
            if hasEnabledFeatures(settings) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("onboarding_enabled_features_header", comment: "Enabled Features:"))
                        .font(.headline)

                    ForEach(enabledFeatures(settings), id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(feature)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }

            Text(NSLocalizedString("onboarding_settings_adjustable", comment: "You can adjust these settings anytime from the Settings menu"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func hasEnabledFeatures(_ settings: AccessibilitySettings) -> Bool {
        return settings.useExtraLargeText || settings.useHighContrast ||
               settings.increaseTouchTargets || settings.reduceMotion ||
               settings.timeoutBehavior != .none || settings.simplifiedUI
    }

    private func enabledFeatures(_ settings: AccessibilitySettings) -> [String] {
        var features: [String] = []
        if settings.useExtraLargeText { features.append(NSLocalizedString("feature_extra_large_text", comment: "Extra Large Text")) }
        if settings.useHighContrast { features.append(NSLocalizedString("feature_high_contrast", comment: "High Contrast")) }
        if settings.increaseTouchTargets { features.append(NSLocalizedString("feature_larger_touch_targets", comment: "Larger Touch Targets")) }
        if settings.reduceMotion { features.append(NSLocalizedString("feature_reduced_motion", comment: "Reduced Motion")) }
        if settings.timeoutBehavior != .none { features.append(NSLocalizedString("feature_extended_timeouts", comment: "Extended Timeouts")) }
        if settings.simplifiedUI { features.append(NSLocalizedString("feature_simplified_interface", comment: "Simplified Interface")) }
        return features
    }
}

// MARK: - Supporting Views

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var progress: Double {
        Double(current) / Double(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.proviiPrimary)
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("accessibility.onboarding.progress.label", comment: "Setup progress"))
        .accessibilityValue(String(format: NSLocalizedString("accessibility.onboarding.progress.value", comment: "Step %d of %d"), current, total))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct FeatureHighlightRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(AccessibleTypography.headline)
                .foregroundColor(.proviiPrimary)
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct ProfileButton: View {
    let profile: AccessibilityProfile
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(isSelected ? .white : .proviiPrimary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.proviiPrimary : Color.gray.opacity(0.1))
            )
        }
        .accessibilityLabel("\(title). \(description)")
        .accessibilityValue(isSelected ? NSLocalizedString("accessibility.value.selected", comment: "Selected") : NSLocalizedString("accessibility.value.not_selected", comment: "Not selected"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : NSLocalizedString("accessibility.hint.tap_to_select", comment: "Tap to select this option"))
    }
}

private struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(AccessibleTypography.body)
                .foregroundColor(.proviiPrimary)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.onboarding.toggle_row.label", comment: "Toggle row label"), title, description))
        .accessibilityValue(isOn ? NSLocalizedString("accessibility_value_enabled", comment: "Enabled") : NSLocalizedString("accessibility_value_disabled", comment: "Disabled"))
        .accessibilityHint(NSLocalizedString("accessibility.onboarding.toggle_row.hint", comment: "Toggle hint"))
    }
}

private struct PreviewCard: View {
    let settings: AccessibilitySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("preview_label", comment: "Preview"))
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(NSLocalizedString("preview_sample_text", comment: "Sample Text"))
                    .font(settings.useExtraLargeText ? .title : .body)

                HStack(spacing: 12) {
                    Button(NSLocalizedString("preview_button_label", comment: "Button")) {}
                        .buttonStyle(AccessibleButtonStyle())

                    Button(NSLocalizedString("preview_cancel_label", comment: "Cancel")) {}
                        .buttonStyle(LocalAccessibleSecondaryButtonStyle())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(settings.useHighContrast ? Color.white : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(settings.useHighContrast ? Color.black : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Accessible Button Styles

private struct AccessibleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AccessibleTypography.body)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.proviiPrimary)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private struct LocalAccessibleSecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var manager = AccessibilityManager.shared

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(manager.settings.useExtraLargeText ? .title3 : .body)
            .foregroundColor(manager.settings.useHighContrast ? .black : .proviiPrimary)
            .padding(.horizontal, manager.settings.increaseTouchTargets ? 24 : 16)
            .padding(.vertical, manager.settings.increaseTouchTargets ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(manager.settings.useHighContrast ? Color.black : Color.proviiPrimary, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Onboarding Steps

private enum OnboardingStep {
    case welcome
    case quickSetup
    case vision
    case interaction
    case complete
}
