// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Speech
import AVFoundation

/// Officer authentication entry screen requiring YubiKey HMAC challenge-response.
/// Supports voice control, manual code entry, and step by step guided instructions
/// for officers authenticating with hardware security keys. All interactive elements
/// meet WCAG 2.2 AA touch target and labelling requirements.
struct OfficerEntryView: View {
    @StateObject private var yubikeyManager = YubikeyManager.shared
    @StateObject private var officerAuthManager = OfficerAuthManager.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @State private var officerId = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTouchPrompt = false

    // Accessibility states
    @State private var voiceControlActive = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showDetailedInstructions = false
    @State private var currentStep = 0
    @State private var showManualEntry = false
    @State private var showYubikeyHelp = false
    @State private var authenticationAttempts = 0
    @State private var lastAnnouncedStatus = ""

    // Focus management
    @FocusState private var isOfficerIdFocused: Bool

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case officerIdField
        case yubikeyStatusButton
        case authenticateButton
        case helpButton
    }

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                // Accessibility status card (verbose mode)
                if accessibilityManager.settings.verboseDescriptions {
                    accessibleStatusCard
                }

                // Header Icon with status
                accessibleHeaderIcon

                // YubiKey Status Card
                accessibleYubikeyStatusCard

                // Officer ID Input
                accessibleOfficerIdInput

                // Alternative entry methods (simplified UI)
                if accessibilityManager.settings.simplifiedUI || accessibilityManager.settings.enableManualCodeEntry {
                    alternativeEntryCard
                }

                // Error Message
                if let errorMessage = errorMessage {
                    accessibleErrorCard(message: errorMessage)
                }

                // Touch Prompt
                if showTouchPrompt {
                    accessibleTouchPromptCard
                }

                // Instructions Card
                accessibleInstructionsCard

                // Help resources (verbose mode)
                if accessibilityManager.settings.verboseDescriptions {
                    helpResourcesCard
                }

                Spacer()
                    .frame(minHeight: 20)

                // Authenticate Button
                accessibleAuthenticateButton

                // Voice command hints
                if accessibilityManager.settings.enableVoiceInput && voiceControlActive {
                    voiceCommandHints
                }
            }
            .padding(padding)
        }
        .background(AccessibleColors.background)
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of officer authentication
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(
            accessibilityManager.settings.useExtraLargeText ? .large : .inline
        )
        .toolbar {
            toolbarContent
        }
        .onAppear {
            setupAccessibility()
        }
        .onDisappear {
            cleanupAccessibility()
        }
        .onChange(of: yubikeyManager.isYubikeyConnected) { connected in
            announceYubikeyStatus(connected)
        }
        .sheet(isPresented: $showYubikeyHelp) {
            AccessibleYubikeyHelpView()
                .sheetKeyboardNavigation(isPresented: $showYubikeyHelp)
        }
        .onChange(of: showYubikeyHelp) { _, isShowing in
            if isShowing {
                savedFocus = focusedElement
            } else if let saved = savedFocus {
                focusedElement = saved
                savedFocus = nil
            }
        }
    }

    // MARK: - Accessible Components

    private var accessibleStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("officer.entry.officer_authentication", comment: "Officer authentication heading"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(textColor)
            }

            Text(NSLocalizedString("officer.entry.authentication_description", comment: "Description of secure officer login requirements"))
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(cardPadding)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.officerentry.officer_authentication_require.label", comment: ""))
    }

    private var accessibleHeaderIcon: some View {
        VStack(spacing: 12) {
            ZStack {
                if accessibilityManager.settings.useHighContrast {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 100, height: 100)
                }

                Image(systemName: "lock.shield.fill")
                    .font(headerIconSize)
                    .foregroundColor(headerIconColor)
            }
            .accessibilityHidden(true)

            if accessibilityManager.settings.showStepNumbers {
                Text(String(format: NSLocalizedString("officer.entry.step_of_total", comment: "Step X of total steps indicator"), currentStep, 4))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerentry.authentication_step_of_4.label", comment: "Accessibility label for step indicator showing current authentication step out of total 4 steps"), currentStep))
            }
        }
    }

    private var accessibleYubikeyStatusCard: some View {
        Button(action: {
            if !yubikeyManager.isYubikeyConnected {
                showYubikeyHelp = true
                HapticFeedback.selection()
            }
        }, label: {
            HStack(spacing: 12) {
                Image(systemName: yubikeyManager.isYubikeyConnected ? "key.fill" : "key")
                    .font(iconSize)
                    .foregroundColor(yubikeyStatusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(yubikeyManager.isYubikeyConnected ? NSLocalizedString("officer.entry.yubikey_connected", comment: "YubiKey connected status") : NSLocalizedString("officer.entry.yubikey_required", comment: "YubiKey required status"))
                        .font(AccessibleTypography.headline)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)
                        .accessibilityLabel(yubikeyManager.isYubikeyConnected ?
                            PronunciationGuide.accessiblePhrase(NSLocalizedString("officer.entry.yubikey_connected", comment: "YubiKey connected status"), expandingTerms: ["YubiKey"]) :
                            PronunciationGuide.accessiblePhrase(NSLocalizedString("officer.entry.yubikey_required", comment: "YubiKey required status"), expandingTerms: ["YubiKey"]))

                    if accessibilityManager.settings.verboseDescriptions {
                        Text(yubikeyManager.isYubikeyConnected ?
                             NSLocalizedString("officer.entry.yubikey_ready_description", comment: "YubiKey detected and ready description") :
                             NSLocalizedString("officer.entry.yubikey_connect_prompt", comment: "Prompt to connect YubiKey"))
                            .font(AccessibleTypography.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                            .accessibilityLabel(PronunciationGuide.accessiblePhrase(
                                yubikeyManager.isYubikeyConnected ?
                                    NSLocalizedString("officer.entry.yubikey_ready_description", comment: "YubiKey detected and ready description") :
                                    NSLocalizedString("officer.entry.yubikey_connect_prompt", comment: "Prompt to connect YubiKey"),
                                expandingTerms: ["YubiKey", "NFC"]))
                    }
                }

                Spacer()

                if yubikeyManager.isYubikeyConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AccessibleTypography.body)
                        .foregroundColor(AccessibleColors.success)
                } else if !accessibilityManager.settings.simplifiedUI {
                    Image(systemName: "questionmark.circle")
                        .font(AccessibleTypography.body)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(cardPadding)
            .background(yubikeyCardBackground)
        })
        .buttonStyle(PlainButtonStyle())
        .disabled(yubikeyManager.isYubikeyConnected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(yubikeyAccessibilityLabel)
        .accessibilityHint(yubikeyManager.isYubikeyConnected ? "" : NSLocalizedString("accessibility.officerentry.double_tap_for_help_connecting.hint", comment: "Accessibility hint for button to get help connecting YubiKey"))
    }

    private var accessibleOfficerIdInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(AccessibleColors.secondaryText)
                Text(NSLocalizedString("officer.entry.officer_id_label", comment: "Officer ID label"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(textColor)
            }

            // Input field
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)

                TextField(NSLocalizedString("officer.entry.officer_id_placeholder", comment: "Officer ID input placeholder"), text: $officerId)
                    .font(AccessibleTypography.body)
                    .textFieldStyle(.plain)
                    .textContentType(.username)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .disabled(isLoading)
                    .focused($isOfficerIdFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if canAuthenticate {
                            authenticate()
                        }
                    }
                    .onChange(of: officerId) { newValue in
                        // MASVS CODE-4: Input validation - limit character count and sanitize
                        let sanitized = String(newValue.uppercased().prefix(50))
                            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        if officerId != sanitized {
                            officerId = sanitized
                        }
                        validateOfficerId()
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.officerentry.officer_id_input_field.label", comment: ""))
                    .accessibilityHint(NSLocalizedString("accessibility.officerentry.enter_your_assigned_officer.hint", comment: ""))

                // Clear button
                if !officerId.isEmpty {
                    Button {
                        officerId = ""
                        HapticFeedback.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.officerentry.clear_officer_id.label", comment: ""))
                    .accessibilityInputLabels(["clear", "delete", "remove", "x"])
                }
            }
            .padding(inputPadding)
            .background(inputBackground)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())

            // Helper text
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("officer.entry.officer_id_helper", comment: "Helper text for officer ID input"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)

                Text(NSLocalizedString("officer.entry.officer_id_example", comment: "Example officer ID format"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)

                if accessibilityManager.settings.verboseDescriptions {
                    Text(NSLocalizedString("officer.entry.officer_id_format", comment: "Detailed officer ID format description"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .padding(.horizontal, 4)

            // Validation feedback
            if !officerId.isEmpty {
                HStack {
                    Image(systemName: isValidOfficerId ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundColor(isValidOfficerId ? AccessibleColors.success : AccessibleColors.warning)
                    Text(isValidOfficerId ? NSLocalizedString("officer.entry.valid_format", comment: "Valid format message") : NSLocalizedString("officer.entry.check_format", comment: "Check format message"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(isValidOfficerId ? AccessibleColors.success : AccessibleColors.warning)
                }
                .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var alternativeEntryCard: some View {
        VStack(spacing: 12) {
            if accessibilityManager.settings.enableManualCodeEntry {
                Button {
                    showManualEntry = true
                    HapticFeedback.selection()
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                            .font(AccessibleTypography.body)
                        Text(NSLocalizedString("officer.entry.manual_auth_code", comment: "Manual authentication code option"))
                        Spacer()
                    }
                    .foregroundColor(AccessibleColors.primary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AccessibleColors.primary, lineWidth: 1)
                )
                .accessibilityLabel(NSLocalizedString("accessibility.officerentry.use_manual_authentication_code.label", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.officerentry.alternative_authentication_met.hint", comment: ""))
            }

            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceControl) {
                    HStack {
                        Image(systemName: voiceControlActive ? "mic.fill" : "mic")
                            .font(AccessibleTypography.body)
                            .foregroundColor(voiceControlActive ? .red : AccessibleColors.primary)
                        Text(voiceControlActive ? NSLocalizedString("officer.entry.voice_input_active", comment: "Voice input active status") : NSLocalizedString("officer.entry.use_voice_input", comment: "Use voice input button"))
                        Spacer()
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(voiceControlActive ? Color.red.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(voiceControlActive ? Color.red : AccessibleColors.primary, lineWidth: 1)
                        )
                )
                .accessibilityLabel(
                    voiceControlActive
                        ? NSLocalizedString("accessibility.officerentry.voice_input_active.label", comment: "Accessibility label indicating voice input is currently active")
                        : NSLocalizedString("accessibility.officerentry.enable_voice_input.label", comment: "Accessibility label for button to enable voice input"))
                .accessibilityInputLabels(["microphone", "voice", "dictation", "speak"])
            }
        }
    }

    private func accessibleErrorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("officer.entry.auth_failed", comment: "Authentication failed title"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.error)

                Text(message)
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if authenticationAttempts >= 3 && accessibilityManager.settings.verboseDescriptions {
                    Text(NSLocalizedString("officer.entry.multiple_failed_attempts", comment: "Multiple failed attempts warning"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(errorCardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerentry.error_message.label", comment: "Accessibility label for error message display"), message))
    }

    private var accessibleTouchPromptCard: some View {
        HStack(spacing: 16) {
            if accessibilityManager.settings.reduceMotion {
                Image(systemName: "hand.tap.fill")
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.warning)
            } else {
                ProgressView()
                    .scaleEffect(accessibilityManager.settings.useExtraLargeText ? 1.2 : 0.9)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("officer.entry.touch_yubikey", comment: "Touch YubiKey prompt"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(textColor)
                    .accessibilityLabel(PronunciationGuide.accessiblePhrase(
                        NSLocalizedString("officer.entry.touch_yubikey", comment: "Touch YubiKey prompt"),
                        expandingTerms: ["YubiKey"]))

                Text(touchPromptMessage)
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityLabel(PronunciationGuide.accessiblePhrase(touchPromptMessage, expandingTerms: ["YubiKey", "NFC"]))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .background(touchPromptBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PronunciationGuide.accessiblePhrase(
            NSLocalizedString("accessibility.officerentry.action_required_touch_your.label", comment: ""),
            expandingTerms: ["YubiKey"]))
        .onAppear {
            announceIfVoiceOver(PronunciationGuide.accessiblePhrase(
                NSLocalizedString("officer.entry.touch_yubikey_announce", comment: "Touch YubiKey voice announcement"),
                expandingTerms: ["YubiKey"]))
        }
    }

    private var accessibleInstructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                withAnimation {
                    showDetailedInstructions.toggle()
                }
                HapticFeedback.selection()
            }, label: {
                HStack {
                    Text(NSLocalizedString("officer.entry.authentication_process", comment: "Authentication process heading"))
                        .font(AccessibleTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    Spacer()

                    if !accessibilityManager.settings.simplifiedUI {
                        Image(systemName: showDetailedInstructions ? "chevron.up" : "chevron.down")
                            .font(AccessibleTypography.footnote)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                }
            })
            .accessibilityLabel(NSLocalizedString("accessibility.officerentry.authentication_process_instruc.label", comment: "Accessibility label for authentication process instructions section"))
            .accessibilityHint(
                showDetailedInstructions
                    ? NSLocalizedString("accessibility.officerentry.collapse_instructions.hint", comment: "Accessibility hint to collapse detailed instructions")
                    : NSLocalizedString("accessibility.officerentry.expand_for_detailed_instructions.hint", comment: "Accessibility hint to expand detailed instructions"))

            // Steps
            VStack(alignment: .leading, spacing: instructionSpacing) {
                ForEach(instructionSteps.indices, id: \.self) { index in
                    AccessibleInstructionStep(
                        number: index + 1,
                        text: instructionSteps[index].brief,
                        detailedText: showDetailedInstructions ? instructionSteps[index].detailed : nil,
                        isCurrentStep: currentStep == index + 1,
                        useHighContrast: accessibilityManager.settings.useHighContrast
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(instructionsBackground)
        .accessibilityElement(children: .contain)
    }

    private var helpResourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("officer.entry.need_help", comment: "Need help heading"))
                .font(AccessibleTypography.headline)
                .foregroundColor(textColor)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showYubikeyHelp = true
                } label: {
                    Label(NSLocalizedString("officer.entry.yubikey_setup_guide", comment: "YubiKey setup guide button"), systemImage: "key")
                        .font(AccessibleTypography.body)
                        .foregroundColor(AccessibleColors.primary)
                }

                Button {
                    // Show troubleshooting
                } label: {
                    Label(NSLocalizedString("officer.entry.troubleshooting", comment: "Troubleshooting button"), systemImage: "wrench.and.screwdriver")
                        .font(AccessibleTypography.body)
                        .foregroundColor(AccessibleColors.primary)
                }

                Button {
                    // Contact IT
                } label: {
                    Label(NSLocalizedString("officer.entry.contact_it_support", comment: "Contact IT support button"), systemImage: "phone")
                        .font(AccessibleTypography.body)
                        .foregroundColor(AccessibleColors.primary)
                }
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.primary.opacity(0.1))
        )
    }

    private var accessibleAuthenticateButton: some View {
        Button {
            authenticate()
        } label: {
            HStack(spacing: 12) {
                if isLoading {
                    if accessibilityManager.settings.reduceMotion {
                        Image(systemName: "hourglass")
                            .font(AccessibleTypography.body)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: buttonProgressColor))
                            .scaleEffect(0.9)
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(buttonIconSize)
                }

                Text(buttonText)
                    .font(AccessibleTypography.headline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, buttonPadding)
        }
        .buttonStyle(AccessiblePrimaryButtonStyle())
        .disabled(!canAuthenticate)
        .accessibilityLabel(buttonAccessibilityLabel)
        .accessibilityHint(buttonAccessibilityHint)
    }

    private var voiceCommandHints: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("officer.entry.voice_commands_available", comment: "Voice commands available label"))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Text(NSLocalizedString("officer.entry.voice_cmd_authenticate", comment: "Authenticate voice command"))
                Text(NSLocalizedString("officer.entry.voice_cmd_clear", comment: "Clear voice command"))
                Text(NSLocalizedString("officer.entry.voice_cmd_help", comment: "Help voice command"))
            }
            .font(AccessibleTypography.caption)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(toolbarIconSize)
                    if accessibilityManager.settings.verboseDescriptions {
                        Text(NSLocalizedString("officer.entry.back_button", comment: "Back button"))
                            .font(AccessibleTypography.body)
                    }
                }
            }
            .accessibilityLabel(AccessibilityLabels.back)
            .accessibilityHint(NSLocalizedString("accessibility.officerentry.return_to_previous_screen.hint", comment: ""))
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceControl) {
                    Image(systemName: voiceControlActive ? "mic.fill" : "mic")
                        .foregroundColor(voiceControlActive ? .red : .primary)
                        .font(toolbarIconSize)
                }
.accessibilityLabel(voiceControlActive ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
                .accessibilityInputLabels(["microphone", "voice", "dictation", "speak"])
            }
        }
    }

    // MARK: - Helper Properties

    private var spacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var padding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var inputPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 16 : 12
    }

    private var buttonPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var instructionSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 8 : 6
    }

    private var headerIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title : AccessibleTypography.title2
    }

    private var iconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.headline : AccessibleTypography.body
    }

    private var buttonIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.callout
    }

    private var toolbarIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.subheadline
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    private var headerIconColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .accentColor
    }

    private var yubikeyStatusColor: Color {
        if yubikeyManager.isYubikeyConnected {
            return AccessibleColors.success
        }
        return AccessibleColors.error
    }

    private var buttonProgressColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .white
    }

    private var navigationTitle: String {
        if accessibilityManager.settings.verboseDescriptions {
            return NSLocalizedString("officer.entry.nav_title_verbose", comment: "Officer authentication navigation title (verbose)")
        }
        return NSLocalizedString("officer.entry.nav_title", comment: "Officer mode navigation title")
    }

    private var yubikeyAccessibilityLabel: String {
        let baseText = yubikeyManager.isYubikeyConnected ?
            NSLocalizedString("officer.entry.yubikey_connected_ready", comment: "YubiKey connected and ready") :
            NSLocalizedString("officer.entry.yubikey_not_connected", comment: "YubiKey not connected prompt")
        return PronunciationGuide.accessiblePhrase(baseText, expandingTerms: ["YubiKey", "NFC"])
    }

    private var touchPromptMessage: String {
        if accessibilityManager.settings.verboseDescriptions {
            return NSLocalizedString("officer.entry.touch_prompt_verbose", comment: "Touch YubiKey prompt (verbose)")
        }
        return NSLocalizedString("officer.entry.touch_prompt", comment: "Touch YubiKey prompt (short)")
    }

    private var buttonText: String {
        if isLoading {
            return NSLocalizedString("officer.entry.authenticating", comment: "Authenticating button text")
        }
        return NSLocalizedString("officer.entry.authenticate_hmac", comment: "Authenticate with HMAC button")
    }

    private var buttonAccessibilityLabel: String {
        if isLoading {
            return PronunciationGuide.accessiblePhrase(
                NSLocalizedString("officer.entry.auth_in_progress", comment: "Authentication in progress label"),
                expandingTerms: ["HMAC"])
        }
        if !canAuthenticate {
            return String(format: NSLocalizedString("officer.entry.auth_disabled_requirements", comment: "Authentication disabled with requirements"), authenticationRequirements)
        }
        return PronunciationGuide.accessiblePhrase(
            NSLocalizedString("officer.entry.authenticate_hmac", comment: "Authenticate with HMAC button"),
            expandingTerms: ["HMAC"])
    }

    private var buttonAccessibilityHint: String {
        if canAuthenticate {
            return NSLocalizedString("officer.entry.tap_to_authenticate", comment: "Double tap to authenticate hint")
        }
        return authenticationRequirements
    }

    private var authenticationRequirements: String {
        var requirements: [String] = []
        if !yubikeyManager.isYubikeyConnected {
            requirements.append(NSLocalizedString("officer.entry.req_connect_yubikey", comment: "Connect YubiKey requirement"))
        }
        if officerId.isEmpty {
            requirements.append(NSLocalizedString("officer.entry.req_enter_officer_id", comment: "Enter Officer ID requirement"))
        } else if !isValidOfficerId {
            requirements.append(NSLocalizedString("officer.entry.req_valid_officer_id", comment: "Valid Officer ID requirement"))
        }
        return requirements.joined(separator: NSLocalizedString("officer.entry.req_separator", comment: "Requirements separator"))
    }

    private var canAuthenticate: Bool {
        yubikeyManager.isYubikeyConnected && !officerId.isEmpty && !isLoading && isValidOfficerId
    }

    private var isValidOfficerId: Bool {
        // Basic validation
        let pattern = "^OFFICER_[A-Z]{2,3}_[A-Z]{3,5}_\\d{3}$"
        return officerId.range(of: pattern, options: .regularExpression) != nil || officerId.isEmpty
    }

    private var instructionSteps: [(brief: String, detailed: String)] {
        [
            (NSLocalizedString("officer.entry.step1_brief", comment: "Step 1 brief: Enter Officer ID"),
             NSLocalizedString("officer.entry.step1_detailed", comment: "Step 1 detailed: Type Officer ID format")),
            (NSLocalizedString("officer.entry.step2_brief", comment: "Step 2 brief: Click Authenticate"),
             NSLocalizedString("officer.entry.step2_detailed", comment: "Step 2 detailed: Press authenticate button")),
            (NSLocalizedString("officer.entry.step3_brief", comment: "Step 3 brief: Touch YubiKey"),
             NSLocalizedString("officer.entry.step3_detailed", comment: "Step 3 detailed: Touch YubiKey contact")),
            (NSLocalizedString("officer.entry.step4_brief", comment: "Step 4 brief: HMAC authentication"),
             NSLocalizedString("officer.entry.step4_detailed", comment: "Step 4 detailed: HMAC verification"))
        ]
    }

    // Background styles
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.cardBackground)
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var yubikeyCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                yubikeyManager.isYubikeyConnected ?
                AccessibleColors.success.opacity(0.15) :
                AccessibleColors.error.opacity(0.15)
            )
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isOfficerIdFocused ? AccessibleColors.primary : Color(uiColor: .separator),
                lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
            )
    }

    private var errorCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.error.opacity(0.15))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AccessibleColors.error, lineWidth: 2) : nil
            )
    }

    private var touchPromptBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.warning.opacity(0.15))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AccessibleColors.warning, lineWidth: 2) : nil
            )
    }

    private var instructionsBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.1))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1) : nil
            )
    }

    // MARK: - Methods

    private func authenticate() {
        isLoading = true
        showTouchPrompt = true
        errorMessage = nil
        currentStep = 3
        authenticationAttempts += 1

        HapticFeedback.selection()
        announceIfVoiceOver(NSLocalizedString("officer.entry.announce_starting_auth", comment: "Starting authentication announcement"))

        Task {
            do {
                try await officerAuthManager.authenticateOfficer(officerId: officerId)
                await MainActor.run {
                    showTouchPrompt = false
                    errorMessage = nil
                    currentStep = 4
                    HapticFeedback.notification(.success)
                    announceIfVoiceOver(NSLocalizedString("officer.entry.announce_auth_success", comment: "Authentication successful announcement"))
                    navigationCoordinator.navigateToOfficerDashboard()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    showTouchPrompt = false
                    errorMessage = error.localizedDescription
                    currentStep = 0
                    isLoading = false
                    HapticFeedback.notification(.error)
                    announceIfVoiceOver(String(format: NSLocalizedString("officer.entry.announce_auth_failed", comment: "Authentication failed announcement"), error.localizedDescription))
                }
            }
        }
    }

    private func validateOfficerId() {
        if !officerId.isEmpty && !isValidOfficerId {
            if accessibilityManager.settings.verboseDescriptions {
                announceIfVoiceOver(NSLocalizedString("officer.entry.announce_invalid_format", comment: "Officer ID format incorrect announcement"))
            }
        }
    }

    // MARK: - Voice Control

    private func toggleVoiceControl() {
        if voiceControlActive {
            speechRecognizer.stopListening()
            voiceControlActive = false
            announceIfVoiceOver(NSLocalizedString("officer.entry.announce_voice_stopped", comment: "Voice input stopped announcement"))
        } else {
            speechRecognizer.startListening()
            voiceControlActive = true
            announceIfVoiceOver(NSLocalizedString("officer.entry.announce_voice_started", comment: "Voice input started announcement"))
        }
        HapticFeedback.selection()
    }

    private func setupVoiceCommands() {
        speechRecognizer.onRecognizedCommand = { command in
            handleVoiceCommand(command)
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let lowercased = command.lowercased()

        if lowercased.contains("authenticate") || lowercased.contains("login") {
            if canAuthenticate {
                authenticate()
            }
        } else if lowercased.contains("clear") {
            officerId = ""
        } else if lowercased.contains("help") {
            showYubikeyHelp = true
        } else if lowercased.contains("back") || lowercased.contains("cancel") {
            dismiss()
        } else if command.starts(with: "OFFICER") {
            // Assume it's an officer ID
            officerId = command.uppercased()
        }
    }

    // MARK: - Accessibility Setup

    private func setupAccessibility() {
        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }

        currentStep = 1

        announceIfVoiceOver(NSLocalizedString("officer.entry.announce_screen_loaded", comment: "Officer authentication screen loaded announcement"))
    }

    private func cleanupAccessibility() {
        if voiceControlActive {
            speechRecognizer.stopListening()
        }
    }

    private func announceYubikeyStatus(_ connected: Bool) {
        if connected != (lastAnnouncedStatus == "connected") {
            lastAnnouncedStatus = connected ? "connected" : "disconnected"
            let statusKey = connected ? "officer.entry.announce_yubikey_connected" : "officer.entry.announce_yubikey_disconnected"
            announceIfVoiceOver(NSLocalizedString(statusKey, comment: "YubiKey connection status announcement"))

            if connected {
                currentStep = 2
            }
        }
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Supporting Components

struct AccessibleInstructionStep: View {
    let number: Int
    let text: String
    let detailedText: String?
    let isCurrentStep: Bool
    let useHighContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(AccessibleTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(numberColor)

                Text(text)
                    .font(AccessibleTypography.body)
                    .foregroundColor(textColor)
            }
            .padding(isCurrentStep ? 8 : 0)
            .background(
                isCurrentStep ?
                RoundedRectangle(cornerRadius: 6)
                    .fill(highlightBackground) : nil
            )

            if let detailed = detailedText {
                Text(detailed)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .padding(.leading, 24)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerentry.instruction_step.label", comment: "Accessibility label for instruction step with number, text and optional details"), number, text, detailedText ?? ""))
        .accessibilityAddTraits(isCurrentStep ? [.isSelected] : [])
    }

    private var numberColor: Color {
        if isCurrentStep {
            return useHighContrast ? .black : .white
        }
        return useHighContrast ? .black : .accentColor
    }

    private var textColor: Color {
        if isCurrentStep {
            return useHighContrast ? .black : .white
        }
        return useHighContrast ? .black : .primary
    }

    private var highlightBackground: Color {
        useHighContrast ? Color.yellow : Color.accentColor
    }
}

struct AccessibleYubikeyHelpView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("officer.entry.yubikey_help_title", comment: "YubiKey Setup Guide title"))
                        .font(AccessibleTypography.title)
                        .padding(.bottom)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("officer.entry.yubikey_help_step1_title", comment: "Connect YubiKey step title"))
                            .font(AccessibleTypography.headline)
                        Text(NSLocalizedString("officer.entry.yubikey_help_step1_desc", comment: "Connect YubiKey step description"))
                            .font(AccessibleTypography.body)
                            .foregroundColor(AccessibleColors.secondaryText)

                        Text(NSLocalizedString("officer.entry.yubikey_help_step2_title", comment: "Wait for Detection step title"))
                            .font(AccessibleTypography.headline)
                        Text(NSLocalizedString("officer.entry.yubikey_help_step2_desc", comment: "Wait for Detection step description"))
                            .font(AccessibleTypography.body)
                            .foregroundColor(AccessibleColors.secondaryText)

                        Text(NSLocalizedString("officer.entry.yubikey_help_step3_title", comment: "Touch When Prompted step title"))
                            .font(AccessibleTypography.headline)
                        Text(NSLocalizedString("officer.entry.yubikey_help_step3_desc", comment: "Touch When Prompted step description"))
                            .font(AccessibleTypography.body)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("officer.entry.done_button", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        OfficerEntryView()
            .environmentObject(NavigationCoordinator())
    }
}
