// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Full accessibility settings screen with sections for vision, typography, interaction, verification
/// feedback, cognitive assistance, and alternative input. Supports both standalone and onboarding modes,
/// with WCAG 2.2 AAA compliance including section headings, keyboard navigation, and state announcements.

struct AccessibilitySettingsView: View {
    @StateObject private var manager = AccessibilityManager.shared
    @State private var showResetConfirmation = false
    @Environment(\.dismiss) private var dismiss

    // Onboarding mode support
    let isOnboarding: Bool
    let onComplete: (() -> Void)?

    // Keyboard navigation for modals
    @State private var resetDialogId = UUID()
    @State private var resetButtonIds: [UUID] = []

    init(isOnboarding: Bool = false, onComplete: (() -> Void)? = nil) {
        self.isOnboarding = isOnboarding
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    quickSetupSection
                    visionSection
                    typographySection
                    interactionSection
                    verificationFeedbackSection
                    cognitiveSection
                    alternativeInputSection
                    resetSection
                }

                // Continue button for onboarding mode
                if isOnboarding {
                    onboardingContinueButton
                        .padding(24)
                        .background(Color(.systemBackground))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
            .navigationTitle(NSLocalizedString("accessibility.settings.navigation_title", comment: "Accessibility settings page title"))
            .navigationBarTitleDisplayMode(.large)
            // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
            .setNavigationPath(isOnboarding ? [] : ["Home", "Settings", "Accessibility"])
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("accessibility.settings.done_button", comment: "Done button")) {
                            dismiss()
                        }
                        .foregroundColor(AccessibleColors.primary)
                    }
                }
            }
        }
        .alert(NSLocalizedString("accessibility.settings.reset_alert.title", comment: "Reset settings alert title"), isPresented: $showResetConfirmation) {
            Button(NSLocalizedString("accessibility.settings.reset_alert.cancel", comment: "Cancel button"), role: .cancel) { }
            Button(NSLocalizedString("accessibility.settings.reset_alert.reset", comment: "Reset button"), role: .destructive) {
                manager.resetToDefaults()
            }
        } message: {
            Text(NSLocalizedString("accessibility.settings.reset_alert.message", comment: "Reset settings confirmation message"))
        }
        .modalKeyboardNavigation(
            modalId: resetDialogId,
            buttonIds: resetButtonIds,
            onDismiss: {
                showResetConfirmation = false
            },
            onConfirm: {
                manager.resetToDefaults()
            }
        )
        .onAppear {
            setupModalButtonIds()
        }
    }

    // MARK: - Setup

    private func setupModalButtonIds() {
        // Generate unique IDs for reset confirmation dialog buttons
        resetButtonIds = [UUID(), UUID()] // Cancel, Reset
    }

    // MARK: - Computed Properties

    private var contrastDescription: String {
        switch manager.settings.contrastLevel {
        case .standard:
            return NSLocalizedString("contrast_description_standard", comment: "Default colours")
        case .high:
            return NSLocalizedString("contrast_description_high", comment: "4.5:1 contrast ratio (AA)")
        case .maximum:
            return NSLocalizedString("contrast_description_maximum", comment: "7:1 contrast ratio (AAA)")
        }
    }

    private var timeoutDescription: String {
        switch manager.settings.timeoutBehavior {
        case .none:
            return NSLocalizedString("timeout_description_none", comment: "Operations never timeout")
        case .standard:
            return NSLocalizedString("timeout_description_standard", comment: "Standard 30 second timeout")
        case .extended:
            return NSLocalizedString("timeout_description_extended", comment: "Extended 60 second timeout")
        }
    }

    private var readingLevelDescription: String {
        switch manager.settings.readingLevel {
        case .standard:
            return NSLocalizedString("reading_level_description_standard", comment: "Regular text with technical terms")
        case .simplified:
            return NSLocalizedString("reading_level_description_simplified", comment: "Simpler words and shorter sentences")
        }
    }

    // MARK: - Quick Setup Section

    private var quickSetupSection: some View {
        Section {
            NavigationLink {
                QuickSetupView()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(AccessibleColors.primary)
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("accessibility.settings.quick_setup.title", comment: "Quick setup title"))
                            .font(.headline)
                        Text(NSLocalizedString("accessibility.settings.quick_setup.subtitle", comment: "Quick setup subtitle"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                }
            }
        } header: {
            Text(NSLocalizedString("accessibility.settings.quick_options.header", comment: "Quick options section header"))
        }
    }

    // MARK: - Vision Section

    private var visionSection: some View {
        Section {
            // WCAG 2.2 AAA: 2.4.10 Section Headings - hierarchical structure
            AccessibleSectionHeader.h2(NSLocalizedString("accessibility.settings.vision.section_title", comment: "Vision section title"), subtitle: NSLocalizedString("accessibility.settings.vision.section_subtitle", comment: "Vision section subtitle"))
            Toggle(isOn: Binding(
                get: { manager.settings.useExtraLargeText },
                set: { newValue in
                    manager.updateSetting(\.useExtraLargeText, value: newValue)
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: newValue ? NSLocalizedString("accessibility.settings.extra_large_text.enabled", comment: "Extra large text enabled") : NSLocalizedString("accessibility.settings.extra_large_text.disabled", comment: "Extra large text disabled"))
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.extra_large_text.label", comment: "Extra large text toggle label"))
                        Text(NSLocalizedString("accessibility.settings.extra_large_text.description", comment: "Extra large text description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "textformat.size")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            // WCAG 2.2 AAA: 1.4.6 Enhanced Contrast
            Picker(selection: Binding(
                get: { manager.settings.contrastLevel },
                set: { manager.updateSetting(\.contrastLevel, value: $0) }
            )) {
                ForEach(AccessibilitySettings.ContrastLevel.allCases, id: \.self) { level in
                    Text(level.localizedName).tag(level)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.contrast_level.label", comment: "Contrast level picker label"))
                        Text(contrastDescription)
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(AccessibleColors.primary)
                }
            }

            if manager.settings.contrastLevel == .maximum {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AccessibleColors.success)
                    Text(NSLocalizedString("accessibility.settings.contrast_level.aaa_achieved", comment: "AAA contrast ratio achieved message"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
                .padding(.leading, 36)
            }

            Toggle(isOn: Binding(
                get: { manager.settings.useHighContrast },
                set: { newValue in
                    manager.updateSetting(\.useHighContrast, value: newValue)
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: newValue ? NSLocalizedString("accessibility.settings.high_contrast.enabled", comment: "High contrast enabled") : NSLocalizedString("accessibility.settings.high_contrast.disabled", comment: "High contrast disabled"))
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.high_contrast.label", comment: "High contrast toggle label"))
                        Text(NSLocalizedString("accessibility.settings.high_contrast.description", comment: "High contrast description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.reduceTransparency },
                set: { newValue in
                    manager.updateSetting(\.reduceTransparency, value: newValue)
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: newValue ? NSLocalizedString("accessibility.settings.reduce_transparency.enabled", comment: "Reduce transparency enabled") : NSLocalizedString("accessibility.settings.reduce_transparency.disabled", comment: "Reduce transparency disabled"))
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.reduce_transparency.label", comment: "Reduce transparency toggle label"))
                        Text(NSLocalizedString("accessibility.settings.reduce_transparency.description", comment: "Reduce transparency description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "square.on.square")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Picker(selection: Binding(
                get: { manager.settings.colorBlindMode },
                set: { manager.updateSetting(\.colorBlindMode, value: $0) }
            )) {
                ForEach(AccessibilitySettings.ColorBlindMode.allCases, id: \.self) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.color_blind_mode.picker_label", comment: "Colour blind mode picker label"))
                        if manager.settings.colorBlindMode != .none {
                            Text(manager.settings.colorBlindMode.localizedName)
                                .font(.caption)
                                .foregroundColor(AccessibleColors.secondaryText)
                        }
                    }
                } icon: {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .accessibilityLabel(NSLocalizedString("accessibility.settings.color_blind_mode.label", comment: "Colour blind mode label"))
            .accessibilityHint(NSLocalizedString("accessibility.settings.color_blind_mode.hint", comment: "Colour blind mode hint"))

            // Colour filter preview
            if manager.settings.colorBlindMode != .none {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("accessibility.settings.color_preview.title", comment: "Colour preview title"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .padding(.leading, 36)

                    HStack(spacing: 8) {
                        ColorPreviewBox(
                            color: Color.proviiPrimary,
                            label: NSLocalizedString("accessibility.settings.color_preview.primary", comment: "Primary colour label")
                        )
                        ColorPreviewBox(
                            color: Color.proviiError,
                            label: NSLocalizedString("accessibility.settings.color_preview.error", comment: "Error colour label")
                        )
                        ColorPreviewBox(
                            color: Color(red: 0.0, green: 0.7, blue: 0.0),
                            label: NSLocalizedString("accessibility.settings.color_preview.success", comment: "Success colour label")
                        )
                        ColorPreviewBox(
                            color: Color.brandSecondary,
                            label: NSLocalizedString("accessibility.settings.color_preview.accent", comment: "Accent colour label")
                        )
                    }
                    .padding(.leading, 36)
                    .padding(.trailing, 16)

                    Text(String(format: NSLocalizedString("accessibility.settings.color_preview.description", comment: "Colour preview description with filter name"), manager.settings.colorBlindMode.localizedName))
                        .font(.caption2)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .padding(.leading, 36)
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 8)
            }

            Toggle(isOn: Binding(
                get: { manager.settings.useDyslexiaFont },
                set: { manager.updateSetting(\.useDyslexiaFont, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.dyslexia_font.toggle_label", comment: "Dyslexia friendly font toggle label"))
                        Text(NSLocalizedString("accessibility.settings.dyslexia_font.description", comment: "Dyslexia font description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "textformat")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.settings.dyslexia_font.label", comment: "Dyslexia font label"))
            .accessibilityHint(NSLocalizedString("accessibility.settings.dyslexia_font.hint", comment: "Dyslexia font hint"))
        } footer: {
            if manager.settings.useDyslexiaFont {
                Text(NSLocalizedString("accessibility.settings.dyslexia_font.footer", comment: "OpenDyslexic font licence note"))
                    .font(.caption)
            }
        }
    }

    // MARK: - Typography Section

    private var typographySection: some View {
        Section {
            // WCAG 2.2 AAA: 2.4.10 Section Headings - hierarchical structure
            AccessibleSectionHeader.h2(NSLocalizedString("accessibility.settings.typography.section_title", comment: "Typography section title"), subtitle: NSLocalizedString("accessibility.settings.typography.section_subtitle", comment: "Typography section subtitle"))

            // Line Spacing
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(AccessibleColors.primary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.typography.line_spacing.label", comment: "Line spacing label"))
                            .font(.body)
                        Text(String(format: NSLocalizedString("accessibility.settings.typography.line_spacing.current", comment: "Current line spacing value"), String(format: "%.1fx", manager.settings.lineSpacingMultiplier)))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                        if manager.settings.lineSpacingMultiplier >= 1.5 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(AccessibleColors.success)
                                Text(NSLocalizedString("accessibility.settings.typography.aaa_compliant", comment: "AAA compliant indicator"))
                                    .font(.caption)
                                    .foregroundColor(AccessibleColors.secondaryText)
                            }
                        }
                    }
                    Spacer()
                }

                Slider(
                    value: Binding(
                        get: { manager.settings.lineSpacingMultiplier },
                        set: { newValue in
                            manager.updateSetting(\.lineSpacingMultiplier, value: newValue)
                            // WCAG 4.1.2: Announce value change
                            UIAccessibility.post(notification: .announcement,
                                argument: String(format: NSLocalizedString("accessibility.settings.line_spacing.value_changed", comment: "Line spacing changed to %.1f"), newValue))
                        }
                    ),
                    in: 1.0...2.0,
                    step: 0.1
                )
                .tint(AccessibleColors.primary)
                .accessibilityLabel(NSLocalizedString("accessibility.settings.typography.line_spacing.slider_label", comment: "Line spacing slider"))
                .accessibilityValue(String(format: NSLocalizedString("accessibility.settings.typography.line_spacing.slider_value", comment: "%.1f times"), manager.settings.lineSpacingMultiplier))

                HStack {
                    Text(NSLocalizedString("accessibility.settings.typography.line_spacing.min", comment: "Minimum line spacing"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    Spacer()
                    Text(NSLocalizedString("accessibility.settings.typography.line_spacing.recommended", comment: "Recommended line spacing AAA"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    Spacer()
                    Text(NSLocalizedString("accessibility.settings.typography.line_spacing.max", comment: "Maximum line spacing"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .padding(.vertical, 4)

            // Paragraph Spacing
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.justify")
                        .foregroundColor(AccessibleColors.primary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.typography.paragraph_spacing.label", comment: "Paragraph spacing label"))
                            .font(.body)
                        Text(String(format: NSLocalizedString("accessibility.settings.typography.paragraph_spacing.current", comment: "Current paragraph spacing value"), String(format: "%.1fx", manager.settings.paragraphSpacingMultiplier)))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                        if manager.settings.paragraphSpacingMultiplier >= 2.0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(AccessibleColors.success)
                                Text(NSLocalizedString("accessibility.settings.typography.aaa_compliant", comment: "AAA compliant indicator"))
                                    .font(.caption)
                                    .foregroundColor(AccessibleColors.secondaryText)
                            }
                        }
                    }
                    Spacer()
                }

                Slider(
                    value: Binding(
                        get: { manager.settings.paragraphSpacingMultiplier },
                        set: { newValue in
                            manager.updateSetting(\.paragraphSpacingMultiplier, value: newValue)
                            // WCAG 4.1.2: Announce value change
                            UIAccessibility.post(notification: .announcement,
                                argument: String(format: NSLocalizedString("accessibility.settings.paragraph_spacing.value_changed", comment: "Paragraph spacing changed to %.1f"), newValue))
                        }
                    ),
                    in: 1.0...3.0,
                    step: 0.1
                )
                .tint(AccessibleColors.primary)
                .accessibilityLabel(NSLocalizedString("accessibility.settings.typography.paragraph_spacing.slider_label", comment: "Paragraph spacing slider"))
                .accessibilityValue(String(format: NSLocalizedString("accessibility.settings.typography.paragraph_spacing.slider_value", comment: "%.1f times"), manager.settings.paragraphSpacingMultiplier))

                HStack {
                    Text(NSLocalizedString("accessibility.settings.typography.paragraph_spacing.min", comment: "Minimum paragraph spacing"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    Spacer()
                    Text(NSLocalizedString("accessibility.settings.typography.paragraph_spacing.recommended", comment: "Recommended paragraph spacing AAA"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    Spacer()
                    Text(NSLocalizedString("accessibility.settings.typography.paragraph_spacing.max", comment: "Maximum paragraph spacing"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .padding(.vertical, 4)

            // Letter Spacing
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "character")
                        .foregroundColor(AccessibleColors.primary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.typography.letter_spacing.label", comment: "Letter spacing label"))
                            .font(.body)
                        Text(String(format: NSLocalizedString("accessibility.settings.typography.letter_spacing.current", comment: "Current letter spacing value"), String(format: "%.2fem", manager.settings.letterSpacingMultiplier)))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                        if manager.settings.letterSpacingMultiplier >= 0.12 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(AccessibleColors.success)
                                Text(NSLocalizedString("accessibility.settings.typography.aaa_compliant", comment: "AAA compliant indicator"))
                                    .font(.caption)
                                    .foregroundColor(AccessibleColors.secondaryText)
                            }
                        }
                    }
                    Spacer()
                }

                Slider(
                    value: Binding(
                        get: { manager.settings.letterSpacingMultiplier },
                        set: { newValue in
                            manager.updateSetting(\.letterSpacingMultiplier, value: newValue)
                            // WCAG 4.1.2: Announce value change
                            UIAccessibility.post(notification: .announcement,
                                argument: String(format: NSLocalizedString("accessibility.settings.letter_spacing.value_changed", comment: "Letter spacing changed to %.2f"), newValue))
                        }
                    ),
                    in: 0.0...0.2,
                    step: 0.01
                )
                .tint(AccessibleColors.primary)
                .accessibilityLabel(NSLocalizedString("accessibility.settings.typography.letter_spacing.slider_label", comment: "Letter spacing slider"))
                .accessibilityValue(String(format: NSLocalizedString("accessibility.settings.typography.letter_spacing.slider_value", comment: "%.2f em"), manager.settings.letterSpacingMultiplier))

                HStack {
                    Text(NSLocalizedString("accessibility.settings.typography.letter_spacing.min", comment: "Minimum letter spacing"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    Spacer()
                    Text(NSLocalizedString("accessibility.settings.typography.letter_spacing.recommended", comment: "Recommended letter spacing AAA"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    Spacer()
                    Text(NSLocalizedString("accessibility.settings.typography.letter_spacing.max", comment: "Maximum letter spacing"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .padding(.vertical, 4)

            // Text Width
            Picker(selection: Binding(
                get: { manager.settings.textWidth },
                set: { manager.updateSetting(\.textWidth, value: $0) }
            )) {
                ForEach(AccessibilitySettings.TextWidth.allCases, id: \.self) { width in
                    Text(width.localizedName).tag(width)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.typography.text_width.label", comment: "Text width label"))
                        Text(NSLocalizedString("accessibility.settings.typography.text_width.description", comment: "Text width description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "text.aligncenter")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
        } footer: {
            Text(NSLocalizedString("accessibility.settings.typography.footer", comment: "Typography AAA recommendations"))
                .font(.caption)
        }
    }

    // MARK: - Interaction Section

    private var interactionSection: some View {
        Section {
            // WCAG 2.2 AAA: 2.4.10 Section Headings - hierarchical structure
            AccessibleSectionHeader.h2(NSLocalizedString("accessibility.settings.interaction.section_title", comment: "Interaction section title"), subtitle: NSLocalizedString("accessibility.settings.interaction.section_subtitle", comment: "Interaction section subtitle"))
            Toggle(isOn: Binding(
                get: { manager.settings.increaseTouchTargets },
                set: { newValue in
                    manager.updateSetting(\.increaseTouchTargets, value: newValue)
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: newValue ? NSLocalizedString("accessibility.settings.larger_touch_targets.enabled", comment: "Larger touch targets enabled") : NSLocalizedString("accessibility.settings.larger_touch_targets.disabled", comment: "Larger touch targets disabled"))
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.interaction.larger_touch_targets.label", comment: "Larger touch targets toggle label"))
                        Text(NSLocalizedString("accessibility.settings.interaction.larger_touch_targets.description", comment: "Larger touch targets description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "hand.tap")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.enhancedTouchTargets },
                set: { manager.updateSetting(\.enhancedTouchTargets, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.interaction.enhanced_touch_targets.toggle_label", comment: "Enhanced touch targets toggle label"))
                        Text(NSLocalizedString("accessibility.settings.interaction.enhanced_touch_targets.description", comment: "Enhanced touch targets description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.settings.enhanced_touch_targets.label", comment: "Enhanced touch targets label"))
            .accessibilityHint(NSLocalizedString("accessibility.settings.enhanced_touch_targets.hint", comment: "Enhanced touch targets hint"))

            Toggle(isOn: Binding(
                get: { manager.settings.reduceMotion },
                set: { newValue in
                    manager.updateSetting(\.reduceMotion, value: newValue)
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: newValue ? NSLocalizedString("accessibility.settings.reduce_motion.enabled", comment: "Reduce motion enabled") : NSLocalizedString("accessibility.settings.reduce_motion.disabled", comment: "Reduce motion disabled"))
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.interaction.reduce_motion.label", comment: "Reduce motion toggle label"))
                        Text(NSLocalizedString("accessibility.settings.interaction.reduce_motion.description", comment: "Reduce motion description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "figure.walk.motion")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            // WCAG 2.2 AAA: 2.2.3 No Timing
            Picker(selection: Binding(
                get: { manager.settings.timeoutBehavior },
                set: { manager.updateSetting(\.timeoutBehavior, value: $0) }
            )) {
                ForEach(AccessibilitySettings.TimeoutBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.localizedName).tag(behavior)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.interaction.timeout_behavior.label", comment: "Timeout behaviour picker label"))
                        Text(timeoutDescription)
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(AccessibleColors.primary)
                }
            }

            if manager.settings.timeoutBehavior == .none {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AccessibleColors.success)
                    Text(NSLocalizedString("accessibility.settings.interaction.timeout_behavior.aaa_compliant", comment: "AAA compliant no timeouts message"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
                .padding(.leading, 36)

                Text(NSLocalizedString("accessibility.settings.interaction.timeout_behavior.note", comment: "Timeout behaviour note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }

            Toggle(isOn: Binding(
                get: { manager.settings.simplifiedGestures },
                set: { manager.updateSetting(\.simplifiedGestures, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.interaction.simplified_gestures.label", comment: "Simplified gestures toggle label"))
                        Text(NSLocalizedString("accessibility.settings.interaction.simplified_gestures.description", comment: "Simplified gestures description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "hand.draw")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.hapticFeedback },
                set: { manager.updateSetting(\.hapticFeedback, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.interaction.haptic_feedback.label", comment: "Haptic feedback toggle label"))
                        Text(NSLocalizedString("accessibility.settings.interaction.haptic_feedback.description", comment: "Haptic feedback description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "waveform")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())
        }
    }

    // MARK: - Verification Feedback Section

    private var verificationFeedbackSection: some View {
        Section {
            AccessibleSectionHeader.h2(
                NSLocalizedString("sound.section.verification_feedback", comment: "Verification Feedback"),
                subtitle: NSLocalizedString("sound.section.subtitle", comment: "Sound and vibration for successful verification")
            )

            // Sound Enable Toggle
            Toggle(isOn: Binding(
                get: { manager.settings.soundEnabled },
                set: { newValue in
                    manager.updateSetting(\.soundEnabled, value: newValue)
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: newValue ? NSLocalizedString("sound.enabled.announcement", comment: "Verification sound enabled") : NSLocalizedString("sound.disabled.announcement", comment: "Verification sound disabled"))
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("sound.play_on_success", comment: "Play sound on success"))
                        Text(NSLocalizedString("sound.play_on_success.description", comment: "Audio confirmation when verification succeeds"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())
            .accessibilityLabel(NSLocalizedString("sound.play_on_success.accessibility", comment: "Play verification sound toggle"))
            .accessibilityHint(NSLocalizedString("sound.play_on_success.accessibility.hint", comment: "Toggle to enable or disable verification sounds"))

            // Sound settings (only visible when sound is enabled)
            if manager.settings.soundEnabled {
                // Sound Style Picker
                Picker(selection: Binding(
                    get: { manager.settings.soundPreset },
                    set: { manager.updateSetting(\.soundPreset, value: $0) }
                )) {
                    ForEach(SoundPreset.allCases.filter { $0 != .silent }, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("sound.style", comment: "Sound style"))
                            Text(manager.settings.soundPreset.description)
                                .font(.caption)
                                .foregroundColor(AccessibleColors.secondaryText)
                        }
                    } icon: {
                        Image(systemName: "waveform.circle")
                            .foregroundColor(AccessibleColors.primary)
                    }
                }
                .accessibilityLabel(NSLocalizedString("sound.style.accessibility", comment: "Sound style selection"))

                // Preview Button
                Button(action: previewSound) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(AccessibleColors.primary)
                        Text(NSLocalizedString("sound.preview", comment: "Preview"))
                            .foregroundColor(AccessibleColors.primary)
                        Spacer()
                    }
                }
                .focusable()
                .onKeyPress(.return) {
                    previewSound()
                    return .handled
                }
                .onKeyPress(.space) {
                    previewSound()
                    return .handled
                }
                .accessibilityLabel(NSLocalizedString("sound.preview.accessibility", comment: "Preview selected sound"))
                .accessibilityHint(NSLocalizedString("sound.preview.accessibility.hint", comment: "Double tap to hear the selected verification sound"))

                // Volume Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(AccessibleColors.primary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("sound.volume", comment: "Volume"))
                                .font(.body)
                            Text("\(manager.settings.soundVolume)%")
                                .font(.caption)
                                .foregroundColor(AccessibleColors.secondaryText)
                        }
                        Spacer()
                    }

                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.soundVolume) },
                            set: { newValue in
                                let intValue = Int(newValue)
                                manager.updateSetting(\.soundVolume, value: intValue)
                                // WCAG 4.1.2: Announce value change
                                UIAccessibility.post(notification: .announcement,
                                    argument: String(format: NSLocalizedString("sound.volume.value_changed", comment: "Volume changed to %d percent"), intValue))
                            }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .tint(AccessibleColors.primary)
                    .accessibilityLabel(NSLocalizedString("sound.volume.accessibility", comment: "Sound volume"))
                    .accessibilityValue("\(manager.settings.soundVolume) percent")

                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                        Spacer()
                        Text("50%")
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                }
                .padding(.vertical, 4)
            }

            // Haptic Toggle (moved here from interaction section conceptually, but we keep original)
            Toggle(isOn: Binding(
                get: { manager.settings.hapticFeedback },
                set: { manager.updateSetting(\.hapticFeedback, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("sound.haptic", comment: "Vibrate on success"))
                        Text(NSLocalizedString("sound.haptic.description", comment: "Haptic feedback when verification succeeds"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())
        } footer: {
            Text(NSLocalizedString("sound.footer", comment: "Sound respects your device's silent mode"))
                .font(.caption)
        }
    }

    private func previewSound() {
        VerificationSoundManager.shared.previewSound(
            preset: manager.settings.soundPreset,
            volume: manager.settings.soundVolume
        )

        // Announce for VoiceOver
        if UIAccessibility.isVoiceOverRunning {
            AccessibilityAnnouncement.announce(
                String(format: NSLocalizedString("sound.preview.announced", comment: "Playing %@ sound"),
                       manager.settings.soundPreset.displayName)
            )
        }
    }

    // MARK: - Cognitive Section

    private var cognitiveSection: some View {
        Section {
            // WCAG 2.2 AAA: 2.4.10 Section Headings - hierarchical structure
            AccessibleSectionHeader.h2(NSLocalizedString("cognitive_assistance_title", comment: "Cognitive Assistance"), subtitle: NSLocalizedString("cognitive_assistance_subtitle", comment: "Features to make the app clearer and easier to understand"))
            Toggle(isOn: Binding(
                get: { manager.settings.simplifiedUI },
                set: { manager.updateSetting(\.simplifiedUI, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.cognitive.simplified_interface.label", comment: "Simplified interface toggle label"))
                        Text(NSLocalizedString("accessibility.settings.cognitive.simplified_interface.description", comment: "Simplified interface description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.showStepNumbers },
                set: { manager.updateSetting(\.showStepNumbers, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.cognitive.step_indicators.label", comment: "Step indicators toggle label"))
                        Text(NSLocalizedString("accessibility.settings.cognitive.step_indicators.description", comment: "Step indicators description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "list.number")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.verboseDescriptions },
                set: { manager.updateSetting(\.verboseDescriptions, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.cognitive.detailed_descriptions.label", comment: "Detailed descriptions toggle label"))
                        Text(NSLocalizedString("accessibility.settings.cognitive.detailed_descriptions.description", comment: "Detailed descriptions description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.confirmBeforeActions },
                set: { manager.updateSetting(\.confirmBeforeActions, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.cognitive.confirm_actions.label", comment: "Confirm actions toggle label"))
                        Text(NSLocalizedString("accessibility.settings.cognitive.confirm_actions.description", comment: "Confirm actions description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            // WCAG 2.2 AAA: 3.1.5 Reading Level
            Picker(selection: Binding(
                get: { manager.settings.readingLevel },
                set: { manager.updateSetting(\.readingLevel, value: $0) }
            )) {
                ForEach(AccessibilitySettings.ReadingLevel.allCases, id: \.self) { level in
                    Text(level.localizedName).tag(level)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.cognitive.reading_level.label", comment: "Reading level picker label"))
                        Text(readingLevelDescription)
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "book.pages")
                        .foregroundColor(AccessibleColors.primary)
                }
            }

            if manager.settings.readingLevel == .simplified {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AccessibleColors.success)
                    Text(NSLocalizedString("accessibility.settings.cognitive.reading_level.aaa_compliant", comment: "AAA compliant reading level message"))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
                .padding(.leading, 36)
            }
        }
    }

    // MARK: - Alternative Input Section

    private var alternativeInputSection: some View {
        Section {
            // WCAG 2.2 AAA: 2.4.10 Section Headings - hierarchical structure
            AccessibleSectionHeader.h2(NSLocalizedString("accessibility.settings.alternative_input.section_title", comment: "Alternative input section title"), subtitle: NSLocalizedString("accessibility.settings.alternative_input.section_subtitle", comment: "Alternative input section subtitle"))
            Toggle(isOn: Binding(
                get: { manager.settings.enableManualCodeEntry },
                set: { manager.updateSetting(\.enableManualCodeEntry, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.alternative_input.manual_code_entry.label", comment: "Manual code entry toggle label"))
                        Text(NSLocalizedString("accessibility.settings.alternative_input.manual_code_entry.description", comment: "Manual code entry description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "keyboard")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            Toggle(isOn: Binding(
                get: { manager.settings.enableVoiceInput },
                set: { manager.updateSetting(\.enableVoiceInput, value: $0) }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.alternative_input.voice_input.label", comment: "Voice input toggle label"))
                        Text(NSLocalizedString("accessibility.settings.alternative_input.voice_input.description", comment: "Voice input description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "mic")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .toggleStyle(AccessibleToggleStyle())

            NavigationLink {
                KeyboardShortcutsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("accessibility.settings.alternative_input.keyboard_shortcuts.label", comment: "Keyboard shortcuts label"))
                        Text(NSLocalizedString("accessibility.settings.alternative_input.keyboard_shortcuts.description", comment: "Keyboard shortcuts description"))
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "command")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
        }
    }

    // MARK: - Onboarding Continue Button

    private var onboardingContinueButton: some View {
        Button(action: {
            manager.markOnboardingComplete()
            onComplete?()
        }, label: {
            Text(NSLocalizedString("onboarding_continue_to_setup", comment: "Continue to Setup"))
                .frame(maxWidth: .infinity)
        })
        .buttonStyle(AccessiblePrimaryButtonStyle())
        .accessibilityHint(NSLocalizedString("onboarding_continue_to_setup_hint", comment: "Finish accessibility settings and continue to app setup"))
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(action: { showResetConfirmation = true }, label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.red)
                    Text(NSLocalizedString("accessibility.settings.reset.button", comment: "Reset all settings button"))
                        .foregroundColor(.red)
                }
            })
            .focusable()
            .onKeyPress(.return) {
                showResetConfirmation = true
                return .handled
            }
            .onKeyPress(.space) {
                showResetConfirmation = true
                return .handled
            }
        }
    }
}

// MARK: - Quick Setup View

private struct QuickSetupView: View {
    @StateObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ProfileRow(
                    profile: .visionImpaired,
                    title: NSLocalizedString("profile_vision_impaired_title", comment: "Vision Impaired"),
                    description: NSLocalizedString("profile_vision_impaired_description", comment: "Optimised for low vision or blindness"),
                    icon: "eye.slash"
                )

                ProfileRow(
                    profile: .motorImpaired,
                    title: NSLocalizedString("profile_motor_difficulties_title", comment: "Motor Difficulties"),
                    description: NSLocalizedString("profile_motor_difficulties_description", comment: "Easier touch targets and interactions"),
                    icon: "hand.raised"
                )

                ProfileRow(
                    profile: .cognitive,
                    title: NSLocalizedString("profile_cognitive_support_title", comment: "Cognitive Support"),
                    description: NSLocalizedString("profile_cognitive_support_description", comment: "Simplified interface with clear guidance"),
                    icon: "brain.head.profile"
                )

                ProfileRow(
                    profile: .elderly,
                    title: NSLocalizedString("profile_senior_friendly_title", comment: "Senior Friendly"),
                    description: NSLocalizedString("profile_senior_friendly_description", comment: "Larger text and simpler interface"),
                    icon: "person.crop.circle"
                )
            } header: {
                Text(NSLocalizedString("preset_profiles_header", comment: "Preset Profiles"))
            } footer: {
                Text(NSLocalizedString("preset_profiles_footer", comment: "Select a profile to automatically configure multiple settings"))
            }
        }
        .navigationTitle(NSLocalizedString("quick_setup_title", comment: "Quick Setup"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct ProfileRow: View {
        @StateObject private var manager = AccessibilityManager.shared
        @Environment(\.dismiss) private var dismiss

        let profile: AccessibilityProfile
        let title: String
        let description: String
        let icon: String

        var body: some View {
            Button {
                manager.applyQuickSetup(profile)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(AccessibleColors.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(description)
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AccessibleColors.secondaryText)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Colour Preview Box Helper

private struct ColorPreviewBox: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
