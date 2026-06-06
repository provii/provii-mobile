// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Speech
import AVFoundation

/// QR code scanner for initiating age verification challenges in person. Supports
/// camera scanning, manual code entry, and voice control input modes. Displays an
/// accessible step indicator showing progress through the verification flow and a
/// timeout warning when the challenge nonce is about to expire.
struct VerificationChallengeView: View {
    @StateObject private var walletRepository = WalletRepository.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @StateObject private var abbreviations = AbbreviationManager.shared
    @StateObject private var focusManager = FocusManager.shared
    @StateObject private var animationManager = AnimationStateManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var scanMode: ScanMode = .scanning
    @State private var progressMessage = ""
    @State private var errorMessage: String?

    // Credential picker states
    @State private var showCredentialPicker = false
    @State private var pendingChallengeId: String?
    @State private var provableCredentials: [CredentialSuitability] = []

    // Accessibility states
    @State private var manualCode = ""
    @State private var isListeningForCode = false
    @State private var showManualInput = false
    @State private var currentStep = 1
    @State private var totalSteps = 3
    @State private var showConfirmationDialog = false
    @State private var pendingQRContent: String?

    // WCAG 2.2 AA: Focus management
    @FocusState private var focusedField: FocusableField?

    // Voice control
    @StateObject private var speechRecognizer = EnhancedSpeechRecognizer()
    @State private var voiceInstructions = ""

    // Timeout handling
    @State private var timeoutTask: Task<Void, Never>?
    @State private var remainingTime = 30

    // Keyboard navigation for modals
    @State private var confirmDialogId = UUID()
    @State private var confirmButtonIds: [UUID] = []

    var body: some View {
        ZStack {
            // Background color for accessibility
            AccessibleColors.background
                .ignoresSafeArea()

            switch scanMode {
            case .scanning:
                accessibleScannerView
            case .processing:
                accessibleProcessingView
            case .success:
                accessibleSuccessView
            case .error:
                accessibleErrorView
            }
        }
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of verification challenge QR scanner
        .navigationTitle(accessibilityTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(scanMode == .processing)
        // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
        .setNavigationPath(["Home", "Verification"])
        .toolbar {
            toolbarContent
        }
        .background(scanMode.accessibleBackgroundColor)
        .sheet(isPresented: $showManualInput) {
            accessibleManualInputSheet
                .sheetKeyboardNavigation(isPresented: $showManualInput)
        }
        .sheet(isPresented: $showCredentialPicker) {
            credentialPickerSheet
                .sheetKeyboardNavigation(isPresented: $showCredentialPicker)
        }
        .alert(accessibilityManager.settings.confirmBeforeActions ? NSLocalizedString("verification.challenge.confirm_verification", comment: "Confirm verification alert title") : "",
               isPresented: $showConfirmationDialog) {
            confirmationAlert
        } message: {
            Text(String(format: NSLocalizedString("verification.challenge.proceed_with_verification", comment: "Ask user to proceed with age verification using QR code"), abbreviations.text(for: .qr)))
                .accessibilityLabel(String(format: NSLocalizedString("accessibility.verificationchallenge.confirmation_required_proceed.label", comment: "Accessibility label for confirmation dialog asking to proceed with age verification using QR code"), abbreviations.text(for: .qr)))
        }
        .modalKeyboardNavigation(
            modalId: confirmDialogId,
            buttonIds: confirmButtonIds,
            onDismiss: {
                showConfirmationDialog = false
                pendingQRContent = nil
            },
            onConfirm: {
                if let content = pendingQRContent {
                    handleScannedContent(content)
                }
            }
        )
        .onAppear {
            setupAccessibility()
            setupModalButtonIds()
            startTimeoutIfNeeded()
        }
        .onDisappear {
            cleanupAccessibility()
        }
    }

    // MARK: - Accessible Scanner View

    private var accessibleScannerView: some View {
        ZStack {
            if !accessibilityManager.settings.simplifiedUI {
                QRScannerView(mode: .verification) { content in
                    handleScannedContent(content)
                }
                .edgesIgnoringSafeArea(.all)
                .opacity(accessibilityManager.settings.reduceTransparency ? 0.8 : 1)
            }

            VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 24 : 16) {
                // Step indicator
                if accessibilityManager.shouldShowStepIndicator() {
                    AccessibleStepIndicator(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                        stepDescription: NSLocalizedString("verification.challenge.step.scan_qr", comment: "Step description for scanning verification QR code")
                    )
                    .padding(.top, 32)
                }

                // Instructions with enhanced visibility
                accessibleInstructionsCard
                    .padding(.top, accessibilityManager.settings.increaseTouchTargets ? 40 : 32)

                Spacer()

                // Alternative input methods (manual entry always available; voice input gated by setting)
                accessibleAlternativeInputCard
                    .padding(.bottom, 16)

                // Error display with accessibility
                if let errorMessage = errorMessage {
                    accessibleErrorCard(message: errorMessage)
                        .padding(.bottom, 16)
                        .transition(accessibilityManager.settings.reduceMotion ?
                                   .opacity : .scale.combined(with: .opacity))
                }

                // Timeout indicator (WCAG 2.2 AAA: 2.2.3 - only show if timeout is active)
                if accessibilityManager.settings.timeoutBehavior != .none && remainingTime < 10 {
                    AccessibleTimeoutWarning(remainingTime: remainingTime)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(getAccessibilityLabelForScanning())
    }

    private var accessibleInstructionsCard: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 12 : 8) {
            Image(systemName: "qrcode.viewfinder")
                .font(iconSize)
                .foregroundColor(AccessibleColors.primary)
                .accessibilityHidden(true)

            // WCAG 2.2 AAA: 3.1.4 Abbreviations - expand on first use
            Text(String(format: NSLocalizedString("verification.challenge.point_camera", comment: "Point camera at verification QR code"), abbreviations.text(for: .qr)))
                .font(AccessibleTypography.body)
                .fontWeight(accessibilityManager.settings.useHighContrast ? .bold : .medium)
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)

            if accessibilityManager.settings.verboseDescriptions {
                Text(NSLocalizedString("verification.challenge.align_qr_code", comment: "Align the QR code within the camera frame for automatic scanning"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(cardPadding)
        .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .overlay(
                    accessibilityManager.settings.useHighContrast ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2) : nil
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.verificationchallenge.instructions_point_camera.label", comment: "Accessibility label for instructions to point camera at verification QR code"), abbreviations.text(for: .qr)))
        .accessibilityHint(accessibilityManager.settings.verboseDescriptions ?
                         NSLocalizedString("accessibility.verificationchallenge.align_qr_code_for_scanning.hint", comment: "Accessibility hint to align QR code for automatic scanning") : "")
    }

    private var accessibleAlternativeInputCard: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 16 : 12) {
            Button(action: {
                showManualInput = true
                HapticFeedback.selection()
            }, label: {
                HStack {
                    Image(systemName: "keyboard")
                        .font(AccessibleTypography.body)
                    Text(NSLocalizedString("verification.challenge.enter_code_manually", comment: "Enter verification code manually button"))
                        .font(AccessibleTypography.body)
                }
                .foregroundColor(AccessibleColors.primary)
            })
            .buttonStyle(AccessibleSecondaryButtonStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.enter_code_manually.label", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.double_tap_to_open.hint", comment: ""))
            .accessibilitySortPriority(2)

            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceInput) {
                    HStack {
                        VoiceInputIndicator(isListening: isListeningForCode, size: 32)
                        Text(isListeningForCode ? NSLocalizedString("verification.challenge.listening", comment: "Listening for voice input") : NSLocalizedString("verification.challenge.speak_code", comment: "Speak verification code button"))
                            .font(AccessibleTypography.body)
                    }
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .accessibilityLabel(
                    isListeningForCode
                        ? NSLocalizedString("accessibility.verificationchallenge.stop_voice_input.label", comment: "Accessibility label for button to stop voice input")
                        : NSLocalizedString("accessibility.verificationchallenge.start_voice_input.label", comment: "Accessibility label for button to start voice input"))
                .accessibilityValue(
                    isListeningForCode
                        ? NSLocalizedString("accessibility.state.listening", comment: "Listening")
                        : NSLocalizedString("accessibility.state.not_listening", comment: "Not listening"))
                .accessibilityHint(String(
                    format: NSLocalizedString("accessibility.verificationchallenge.double_tap_to_control_voice.hint", comment: "Accessibility hint for double tap to start or stop voice input"),
                    isListeningForCode
                        ? NSLocalizedString("accessibility.verificationchallenge.stop.label", comment: "Stop action")
                        : NSLocalizedString("accessibility.verificationchallenge.start.label", comment: "Start action")))
                .accessibilitySortPriority(1)
            }

            // Voice error display
            if let errorMessage = speechRecognizer.errorMessage {
                VoiceInputError(errorMessage: errorMessage)
                    .environmentObject(accessibilityManager)
            }

            if isListeningForCode && !voiceInstructions.isEmpty {
                Text(String(format: NSLocalizedString("verification.challenge.say_instructions", comment: "Voice input instructions to say"), voiceInstructions))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
    }

    // MARK: - Accessible Processing View

    private var accessibleProcessingView: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 32 : 24) {
            // Step indicator
            if accessibilityManager.shouldShowStepIndicator() {
                AccessibleStepIndicator(
                    currentStep: 2,
                    totalSteps: totalSteps,
                    stepDescription: NSLocalizedString("verification.challenge.step.processing", comment: "Step description for processing verification")
                )
            }

            // WCAG 2.2 AA: Accessible progress view with pause control
            AccessibleProgressView(
                message: progressMessage.isEmpty ? NSLocalizedString("verification.challenge.processing", comment: "Processing status message") : progressMessage,
                progress: nil
            )
            .controlledAnimation(id: "verification-processing", duration: 0.8)
            .accessibilityValue(progressMessage)
            .accessibilityAddTraits(.updatesFrequently)

            // Cancel button for extended/no timeouts (WCAG 2.2 AAA: 2.2.3)
            if accessibilityManager.settings.timeoutBehavior != .standard {
                Button(NSLocalizedString("verification.challenge.cancel", comment: "Cancel button")) {
                    cancelProcessing()
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .padding(.top)
                .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.cancel_verification.label", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.stops_the_verification_process.hint", comment: ""))
            }
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 40 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AccessibleColors.cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLanguage(Locale.current.language.languageCode?.identifier ?? "en")
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.verificationchallenge.processing_verification.label", comment: "Accessibility label for processing verification with current message"), progressMessage))
        .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.please_wait_while_verification.hint", comment: "Accessibility hint to wait while verification is processing"))
    }

    // MARK: - Accessible Success View

    private var accessibleSuccessView: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 32 : 24) {
            // Step indicator
            if accessibilityManager.shouldShowStepIndicator() {
                AccessibleStepIndicator(
                    currentStep: 3,
                    totalSteps: totalSteps,
                    stepDescription: NSLocalizedString("verification.challenge.step.complete", comment: "Step description for verification complete")
                )
            }

            // Success icon with animation consideration
            Image(systemName: "checkmark.circle.fill")
                .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.largeTitle : AccessibleTypography.title)
                .foregroundColor(AccessibleColors.success)
                .scaleEffect(accessibilityManager.settings.reduceMotion ? 1.0 : 1.0)
                .accessibilityHidden(true)

            Text(LocalizedString.ageVerified.localized)
                .font(AccessibleTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AccessibleColors.success)
                .multilineTextAlignment(.center)

            Text(LocalizedString.ageVerifiedPrivately.localized)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if accessibilityManager.settings.verboseDescriptions {
                Text(LocalizedString.verificationSuccessDetailed.localized)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text(accessibilityManager.settings.timeoutBehavior == .none ?
                 LocalizedString.returnNow.localized :
                 LocalizedString.returningToBrowser.localized)
                .font(AccessibleTypography.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Manual dismiss button for accessibility (WCAG 2.2 AAA: 2.2.3)
            if accessibilityManager.settings.timeoutBehavior != .standard {
                Button(LocalizedString.returnNow.localized) {
                    dismiss()
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
                .padding(.top)
            }
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 40 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AccessibleColors.cardBackground)
        .onAppear {
            announceSuccess()
            if accessibilityManager.settings.timeoutBehavior != .none {
                scheduleAutoDismiss()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.success_age_verified_your.label", comment: "Accessibility label for successful age verification"))
    }

    // MARK: - Accessible Error View

    private var accessibleErrorView: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 32 : 24) {
            // Error icon
            Image(systemName: "exclamationmark.circle.fill")
                .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title : AccessibleTypography.title2)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            Text(LocalizedString.verificationFailed.localized)
                .font(AccessibleTypography.title2)
                .fontWeight(.semibold)
                .foregroundColor(AccessibleColors.error)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(errorMessage ?? LocalizedString.verificationFailedMessage.localized)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if accessibilityManager.settings.verboseDescriptions {
                Text(LocalizedString.verificationFailedDetailed.localized)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons with proper spacing
            HStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 20 : 16) {
                Button {
                    HapticFeedback.notification(.warning)
                    dismiss()
                } label: {
                    Text(LocalizedString.cancel.localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .accessibilitySortPriority(2)
                .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.cancel_verification.label", comment: "Cancel verification"))
                .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.dismiss_and_return.hint", comment: "Dismisses this screen and returns to the previous screen"))

                Button {
                    HapticFeedback.selection()
                    resetAndRetry()
                } label: {
                    Text(LocalizedString.tryAgain.localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
                .accessibilitySortPriority(1)
                .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.try_again.label", comment: "Try verification again"))
                .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.return_to_scanner.hint", comment: "Returns to the scanner to try verification again"))
            }
            .padding(.horizontal)
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 40 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AccessibleColors.cardBackground)
        .onAppear {
            announceError()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "accessibility.verificationchallenge.error_verification_failed.label",
                comment: "Accessibility label for verification failure error"),
            errorMessage ?? NSLocalizedString(
                "accessibility.verificationchallenge.an_error_occurred.label",
                comment: "Default error message")))
    }

    // MARK: - Manual Input Sheet

    private var accessibleManualInputSheet: some View {
        NavigationView {
            VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 24 : 20) {
                Text(LocalizedString.enterVerificationCode.localized)
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                    .accessibilityAddTraits(.isHeader)

                if accessibilityManager.settings.verboseDescriptions {
                    Text(NSLocalizedString("verification.challenge.manual_input.description", comment: "Description for entering 12-digit verification code"))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // WCAG 2.2 AA: Focus management with keyboard accessory
                TextField(NSLocalizedString("verification.challenge.manual_input.placeholder", comment: "Placeholder for 12-digit code"), text: $manualCode)
                    .font(AccessibleTypography.title3)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                    .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
                    .focused($focusedField, equals: .verificationCodeEntry)
                    .submitLabel(.done)
                    .onSubmit {
                        if !manualCode.isEmpty {
                            let code = manualCode
                            manualCode = ""
                            showManualInput = false
                            processManualCode(code)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.12_digit_verification_code_ent.label", comment: ""))
                    .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.enter_the_12_digit_code.hint", comment: ""))
                    .keyboardAccessory(
                        onDone: {
                            if !manualCode.isEmpty {
                                let code = manualCode
                                manualCode = ""
                                showManualInput = false
                                processManualCode(code)
                            } else {
                                focusedField = nil
                            }
                        }
                    )
                    .onChange(of: manualCode) { newValue in
                        let digits = newValue.unicodeScalars.filter {
                            CharacterSet(charactersIn: "0123456789").contains($0)
                        }
                        let filtered = String(String.UnicodeScalarView(digits)).prefix(12)
                        if manualCode != String(filtered) {
                            manualCode = String(filtered)
                        }
                    }
                    .onAppear {
                        // Auto-focus on field when sheet appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            focusedField = .verificationCodeEntry
                        }
                    }

                Spacer()

                HStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 20 : 16) {
                    Button(NSLocalizedString("verification.challenge.manual_input.cancel", comment: "Cancel button in manual input sheet")) {
                        showManualInput = false
                        manualCode = ""
                    }
                    .buttonStyle(AccessibleSecondaryButtonStyle())
                    .accessibilitySortPriority(1)

                    Button(NSLocalizedString("verification.challenge.manual_input.submit", comment: "Submit button in manual input sheet")) {
                        if !manualCode.isEmpty {
                            let code = manualCode
                            manualCode = ""
                            showManualInput = false
                            processManualCode(code)
                        }
                    }
                    .buttonStyle(AccessiblePrimaryButtonStyle())
                    .disabled(manualCode.isEmpty)
                    .accessibilitySortPriority(2)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("verification.challenge.manual_input.cancel", comment: "Cancel button in manual input sheet")) {
                        showManualInput = false
                        manualCode = ""
                    }
                    .font(AccessibleTypography.body)
                }
            }
        }
    }

    // MARK: - Credential Picker Sheet

    private var credentialPickerSheet: some View {
        NavigationView {
            VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 24 : 20) {
                Text(NSLocalizedString("verification.challenge.credential_picker.title", comment: "Choose a credential title"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                    .accessibilityAddTraits(.isHeader)

                ScrollView {
                    LazyVStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 12 : 8) {
                        ForEach(provableCredentials, id: \.id) { credential in
                            Button {
                                showCredentialPicker = false
                                HapticFeedback.selection()
                                if let challengeId = pendingChallengeId {
                                    continueProofGeneration(credentialId: credential.id, challengeId: challengeId)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(credential.nickname ?? NSLocalizedString("verification.challenge.credential_picker.default_name", comment: "Default credential display name"))
                                        .font(AccessibleTypography.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(textColor)

                                    if credential.canSatisfy {
                                        Text(NSLocalizedString("verification.challenge.credential_picker.meets_requirement", comment: "Meets age requirement"))
                                            .font(AccessibleTypography.caption)
                                            .foregroundColor(AccessibleColors.success)
                                    } else {
                                        Text(credential.failureReason ?? NSLocalizedString("verification.challenge.credential_picker.does_not_meet", comment: "Does not meet age requirement"))
                                            .font(AccessibleTypography.caption)
                                            .foregroundColor(AccessibleColors.error)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(cardBackgroundColor)
                                        .overlay(
                                            accessibilityManager.settings.useHighContrast ?
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.black, lineWidth: 1) : nil
                                        )
                                )
                            }
                            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
                            .accessibilityLabel(credential.nickname ?? NSLocalizedString("verification.challenge.credential_picker.default_name", comment: "Default credential display name"))
                            .accessibilityHint(NSLocalizedString("verification.challenge.credential_picker.tap_to_use", comment: "Tap to use this credential for verification"))
                        }
                    }
                    .padding(.horizontal)
                }

                Button(NSLocalizedString("verification.challenge.credential_picker.cancel", comment: "Cancel credential selection")) {
                    showCredentialPicker = false
                    pendingChallengeId = nil
                    provableCredentials = []
                    scanMode = .scanning
                    currentStep = 1
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
                .accessibilityLabel(NSLocalizedString("verification.challenge.credential_picker.cancel", comment: "Cancel credential selection"))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("verification.challenge.credential_picker.cancel", comment: "Cancel credential selection")) {
                        showCredentialPicker = false
                        pendingChallengeId = nil
                        provableCredentials = []
                        scanMode = .scanning
                        currentStep = 1
                    }
                    .font(AccessibleTypography.body)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if scanMode == .scanning || scanMode == .error {
                Button {
                    HapticFeedback.selection()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.subheadline)
                        if accessibilityManager.settings.verboseDescriptions {
                            Text(NSLocalizedString("verification.challenge.back", comment: "Back button"))
                                .font(AccessibleTypography.body)
                        }
                    }
                }
                .accessibilityLabel(AccessibilityLabels.back)
                .accessibilityHint(NSLocalizedString("accessibility.verificationchallenge.return_to_previous_screen.hint", comment: ""))
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if accessibilityManager.settings.enableVoiceInput && scanMode == .scanning {
                Button(action: toggleVoiceInput) {
                    VoiceInputIndicator(isListening: isListeningForCode, size: accessibilityManager.settings.useExtraLargeText ? 32 : 28)
                }
                .accessibilityLabel(isListeningForCode ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
                .accessibilityValue(isListeningForCode ? NSLocalizedString("accessibility.state.listening", comment: "Listening") : NSLocalizedString("accessibility.state.not_listening", comment: "Not listening"))
            }
        }
    }

    // MARK: - Confirmation Alert

    private var confirmationAlert: some View {
        Group {
            Button(NSLocalizedString("verification.challenge.alert.cancel", comment: "Cancel button in confirmation alert"), role: .cancel) {
                pendingQRContent = nil
                announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.cancelled", comment: "VoiceOver announcement for verification cancelled"))
            }
            Button(NSLocalizedString("verification.challenge.alert.verify", comment: "Verify button in confirmation alert")) {
                if let content = pendingQRContent {
                    processChallenge(qrContent: content)
                }
            }
            .accessibilityLabel(NSLocalizedString("accessibility.verificationchallenge.confirm_and_verify.label", comment: ""))
        }
    }

    // MARK: - Helper Methods

    private func handleScannedContent(_ content: String) {
        HapticFeedback.selection()

        if accessibilityManager.settings.confirmBeforeActions {
            pendingQRContent = content
            showConfirmationDialog = true
        } else {
            processChallenge(qrContent: content)
        }
    }

    private func processChallenge(qrContent: String) {
        scanMode = .scanning
        errorMessage = nil
        currentStep = 2

        Task {
            do {
                await MainActor.run {
                    scanMode = .processing
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: NSLocalizedString("verification.challenge.voiceover.processing", comment: "VoiceOver announcement for processing verification"))
                }

                progressMessage = NSLocalizedString("verification.challenge.progress.reading_request", comment: "Reading verification request progress message")
                // WCAG 4.1.2: Announce progress update to screen readers
                UIAccessibility.post(notification: .announcement, argument: progressMessage)
                let multiplier: Double = accessibilityManager.settings.timeoutBehavior == .extended ? 1.5 : 1.0
                try await Task.sleep(nanoseconds: UInt64(500_000_000 * multiplier))

                progressMessage = NSLocalizedString("verification.challenge.progress.processing_challenge", comment: "Processing challenge progress message")
                // WCAG 4.1.2: Announce progress update to screen readers
                UIAccessibility.post(notification: .announcement, argument: progressMessage)
                announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.processing_challenge", comment: "VoiceOver announcement for processing challenge"))

                // Process QR code content (JSON or provii:// URL)
                let challengeId = try await walletRepository.processVerificationChallenge(qrContent)

                // Resolve which credential to use, showing picker if multiple
                try await resolveCredentialAndProve(challengeId: challengeId)
            } catch {
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handleError(error).userMessage
                    scanMode = .error
                    // WCAG 4.1.2: Announce error state
                    UIAccessibility.post(notification: .announcement,
                        argument: String(format: NSLocalizedString("verification.challenge.voiceover.error", comment: "VoiceOver announcement for verification error"), errorMessage ?? ""))
                }
            }
        }
    }

    private func processManualCode(_ shortCode: String) {
        let digits = shortCode.unicodeScalars.filter {
            CharacterSet(charactersIn: "0123456789").contains($0)
        }
        let filtered = String(String.UnicodeScalarView(digits))
        guard filtered.count == 12 else {
            errorMessage = NSLocalizedString("verification.challenge.error.invalid_code_format", comment: "Error when manual code is not exactly 12 digits")
            scanMode = .error
            UIAccessibility.post(notification: .announcement,
                argument: NSLocalizedString("verification.challenge.error.invalid_code_format", comment: "Error when manual code is not exactly 12 digits"))
            return
        }
        scanMode = .scanning
        errorMessage = nil
        currentStep = 2

        Task {
            do {
                await MainActor.run {
                    scanMode = .processing
                    announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.processing_code", comment: "VoiceOver announcement for processing verification code"))
                }

                progressMessage = NSLocalizedString("verification.challenge.progress.reading_code", comment: "Reading verification code progress message")
                UIAccessibility.post(notification: .announcement, argument: progressMessage)
                let multiplier: Double = accessibilityManager.settings.timeoutBehavior == .extended ? 1.5 : 1.0
                try await Task.sleep(nanoseconds: UInt64(500_000_000 * multiplier))

                progressMessage = NSLocalizedString("verification.challenge.progress.processing_challenge", comment: "Processing challenge progress message")
                // WCAG 4.1.2: Announce progress update to screen readers
                UIAccessibility.post(notification: .announcement, argument: progressMessage)
                announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.processing_challenge", comment: "VoiceOver announcement for processing challenge"))

                // Process 12-digit short code
                let challengeId = try await walletRepository.processManualEntry(filtered)

                // Resolve which credential to use, showing picker if multiple
                try await resolveCredentialAndProve(challengeId: challengeId)
            } catch {
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handleError(error).userMessage
                    scanMode = .error
                    // WCAG 4.1.2: Announce error state
                    UIAccessibility.post(notification: .announcement,
                        argument: String(format: NSLocalizedString("verification.challenge.voiceover.error", comment: "VoiceOver announcement for verification error"), errorMessage ?? ""))
                }
            }
        }
    }

    /// Checks provable credentials with suitability and either auto-selects (single credential)
    /// or presents a picker sheet (multiple credentials).
    private func resolveCredentialAndProve(challengeId: String) async throws {
        let credentials: [CredentialSuitability]
        do {
            credentials = try walletRepository.getProvableCredentialsForChallenge(challengeId: challengeId)
        } catch {
            await MainActor.run {
                errorMessage = NSLocalizedString("verification.challenge.error.no_credential", comment: "Error message when no credential is available")
                scanMode = .error
                UIAccessibility.post(notification: .announcement,
                    argument: String(format: NSLocalizedString("verification.challenge.voiceover.error", comment: "VoiceOver announcement for verification error"), errorMessage ?? ""))
            }
            return
        }

        if credentials.isEmpty {
            await MainActor.run {
                errorMessage = NSLocalizedString("verification.challenge.error.no_credential", comment: "Error message when no credential is available")
                scanMode = .error
                UIAccessibility.post(notification: .announcement,
                    argument: String(format: NSLocalizedString("verification.challenge.voiceover.error", comment: "VoiceOver announcement for verification error"), errorMessage ?? ""))
            }
            return
        }

        if credentials.count == 1 {
            // Single credential: auto-proceed
            try await generateAndSubmitProof(credentialId: credentials[0].id, challengeId: challengeId)
        } else {
            // Multiple credentials: show picker and pause
            await MainActor.run {
                provableCredentials = credentials
                pendingChallengeId = challengeId
                scanMode = .scanning
                showCredentialPicker = true
                announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.choose_credential", comment: "VoiceOver announcement asking user to choose a credential"))
            }
        }
    }

    /// Called from the credential picker sheet when a credential is selected,
    /// or directly when only one provable credential exists.
    private func continueProofGeneration(credentialId: String, challengeId: String) {
        pendingChallengeId = nil
        provableCredentials = []
        currentStep = 2

        Task {
            do {
                await MainActor.run {
                    scanMode = .processing
                    // WCAG 4.1.2: Announce state change
                    UIAccessibility.post(notification: .announcement,
                        argument: NSLocalizedString("verification.challenge.voiceover.processing", comment: "VoiceOver announcement for processing verification"))
                }

                try await generateAndSubmitProof(credentialId: credentialId, challengeId: challengeId)
            } catch {
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handleError(error).userMessage
                    scanMode = .error
                    // WCAG 4.1.2: Announce error state
                    UIAccessibility.post(notification: .announcement,
                        argument: String(format: NSLocalizedString("verification.challenge.voiceover.error", comment: "VoiceOver announcement for verification error"), errorMessage ?? ""))
                }
            }
        }
    }

    /// Generates and submits the age proof for a given credential and challenge.
    private func generateAndSubmitProof(credentialId: String, challengeId: String) async throws {
        progressMessage = NSLocalizedString("verification.challenge.progress.creating_proof", comment: "Creating age proof progress message")
        announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.creating_proof", comment: "VoiceOver announcement for creating age proof"))
        let proofMultiplier: Double = accessibilityManager.settings.timeoutBehavior == .extended ? 1.5 : 1.0
        try await Task.sleep(nanoseconds: UInt64(500_000_000 * proofMultiplier))

        let proofJson = try await walletRepository.createAgeProof(
            credentialId: credentialId,
            challengeId: challengeId
        )

        progressMessage = NSLocalizedString("verification.challenge.progress.submitting_proof", comment: "Submitting proof progress message")
        announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.submitting_proof", comment: "VoiceOver announcement for submitting proof"))
        let submitMultiplier: Double = accessibilityManager.settings.timeoutBehavior == .extended ? 1.5 : 1.0
        try await Task.sleep(nanoseconds: UInt64(500_000_000 * submitMultiplier))

        let success = try await walletRepository.submitProof(proofJson)

        if success {
            progressMessage = NSLocalizedString("verification.challenge.progress.verified", comment: "Age verified success progress message")
            currentStep = 3
            await MainActor.run {
                scanMode = .success
                // WCAG 4.1.2: Announce success state
                UIAccessibility.post(notification: .announcement,
                    argument: NSLocalizedString("verification.challenge.voiceover.success", comment: "VoiceOver announcement for successful verification"))
            }
        } else {
            await MainActor.run {
                errorMessage = NSLocalizedString("verification.challenge.error.failed", comment: "Verification failed error message")
                scanMode = .error
                // WCAG 4.1.2: Announce error state
                UIAccessibility.post(notification: .announcement,
                    argument: String(format: NSLocalizedString("verification.challenge.voiceover.error", comment: "VoiceOver announcement for verification error"), errorMessage ?? ""))
            }
        }
    }

    private func resetAndRetry() {
        withAnimation(accessibilityManager.settings.reduceMotion ? .none : .easeInOut) {
            scanMode = .scanning
            errorMessage = nil
            currentStep = 1
            manualCode = ""
        }
        UIAccessibility.post(notification: .screenChanged, argument: NSLocalizedString("verification.challenge.voiceover.ready_to_scan", comment: "VoiceOver announcement for ready to scan again"))
    }

    private func cancelProcessing() {
        timeoutTask?.cancel()
        scanMode = .scanning
        currentStep = 1
        announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.processing_cancelled", comment: "VoiceOver announcement for processing cancelled"))
    }

    // MARK: - Voice Control

    private func toggleVoiceInput() {
        if isListeningForCode {
            speechRecognizer.stopListening()
            isListeningForCode = false
            voiceInstructions = ""
            // WCAG 4.1.2: Announce state change
            UIAccessibility.post(notification: .announcement,
                argument: NSLocalizedString("verification.challenge.voiceover.voice_stopped", comment: "VoiceOver announcement for voice input stopped"))
        } else {
            speechRecognizer.startListening()
            isListeningForCode = true
            voiceInstructions = NSLocalizedString("verification.challenge.voice_instructions", comment: "Voice instructions text")
            // WCAG 4.1.2: Announce state change
            UIAccessibility.post(notification: .announcement,
                argument: NSLocalizedString("verification.challenge.voiceover.voice_started", comment: "VoiceOver announcement for voice input started"))
        }
        HapticFeedback.selection()
    }

    // MARK: - Accessibility Setup

    private func setupAccessibility() {
        if UIAccessibility.isVoiceOverRunning {
            announceIfVoiceOver(String(format: NSLocalizedString("verification.challenge.voiceover.scanner_opened", comment: "VoiceOver announcement for scanner opened"), getAccessibilityLabelForScanning()))
        }

        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }
    }

    private func setupModalButtonIds() {
        // Generate unique IDs for confirmation dialog buttons
        confirmButtonIds = [UUID(), UUID()] // Cancel, Confirm
    }

    private func cleanupAccessibility() {
        timeoutTask?.cancel()
        if isListeningForCode {
            speechRecognizer.stopListening()
        }
    }

    private func setupVoiceCommands() {
        speechRecognizer.onRecognizedCommand = { command in
            handleVoiceCommand(command)
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let lowercased = command.lowercased()

        if lowercased.contains("cancel") || lowercased.contains("back") {
            dismiss()
        } else if lowercased.contains("manual") || lowercased.contains("type") {
            showManualInput = true
        } else if lowercased.contains("retry") || lowercased.contains("again") {
            resetAndRetry()
        } else if !lowercased.isEmpty && scanMode == .scanning {
            // Filter to digits only and validate before processing
            let digits = command.unicodeScalars.filter {
                CharacterSet(charactersIn: "0123456789").contains($0)
            }
            let filtered = String(String.UnicodeScalarView(digits))
            guard filtered.count == 12 else {
                UIAccessibility.post(notification: .announcement,
                    argument: NSLocalizedString("verification.challenge.error.invalid_code_format", comment: "Error when manual code is not exactly 12 digits"))
                return
            }
            processManualCode(filtered)
        }
    }

    // MARK: - Timeout Handling

    private func startTimeoutIfNeeded() {
        // WCAG 2.2 AAA: 2.2.3 No Timing
        guard let duration = accessibilityManager.getTimeoutDuration(standard: 30) else {
            // No timeout - user can take as long as needed
            return
        }

        remainingTime = Int(duration)

        timeoutTask = Task {
            for i in (0..<Int(duration)).reversed() {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remainingTime = i

                if i == 10 {
                    announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.10_seconds", comment: "VoiceOver announcement for 10 seconds remaining"))
                } else if i == 5 {
                    announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.5_seconds", comment: "VoiceOver announcement for 5 seconds remaining"))
                }
            }
        }
    }

    private func scheduleAutoDismiss() {
        // WCAG 2.2 AAA: 2.2.3 No Timing
        guard let duration = accessibilityManager.getTimeoutDuration(standard: 2.0) else {
            // No timeout - wait for manual dismiss
            return
        }

        let delay = duration

        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                dismiss()
            }
        }
    }

    // MARK: - Announcements

    private func announceSuccess() {
        // Play verification success sound and haptic feedback
        VerificationSoundManager.shared.playVerificationSuccess()
        announceIfVoiceOver(NSLocalizedString("verification.challenge.voiceover.success", comment: "VoiceOver announcement for successful verification"))
    }

    private func announceError() {
        HapticFeedback.notification(.error)
        UIAccessibility.post(notification: .screenChanged, argument: NSLocalizedString("verification.challenge.voiceover.verification_failed", comment: "VoiceOver announcement that verification failed"))
    }

    // MARK: - Helper Properties

    private var accessibilityTitle: String {
        if accessibilityManager.settings.verboseDescriptions {
            return scanMode.verboseTitle
        }
        return scanMode.title
    }

    private func getAccessibilityLabelForScanning() -> String {
        // WCAG 2.2 AAA: 3.1.4 Abbreviations - expand on first use
        var label = String(format: NSLocalizedString("verification.challenge.accessibility.scan_screen", comment: "Accessibility label for scan verification screen"), abbreviations.text(for: .qr))

        label += " " + NSLocalizedString("verification.challenge.accessibility.manual_available", comment: "Manual code entry available")

        if accessibilityManager.settings.enableVoiceInput {
            label += " " + NSLocalizedString("verification.challenge.accessibility.voice_available", comment: "Voice input available")
        }
        if let error = errorMessage {
            label += " " + String(format: NSLocalizedString("verification.challenge.accessibility.error_label", comment: "Error label for accessibility"), error)
        }

        return label
    }

    private func accessibleErrorCard(message: String) -> some View {
        // WCAG 2.2 AA: Enhanced error identification with suggestion
        AccessibleErrorMessage(
            error: message,
            suggestion: getSuggestionForError(message),
            onDismiss: { errorMessage = nil }
        )
    }

    private func getSuggestionForError(_ error: String) -> String? {
        if error.contains("credential") {
            return NSLocalizedString("verification.challenge.error.suggestion.credential", comment: "Error suggestion for credential issue")
        } else if error.contains("network") || error.contains("connection") {
            return NSLocalizedString("verification.challenge.error.suggestion.network", comment: "Error suggestion for network issue")
        } else if error.contains("QR") || error.contains("code") {
            return NSLocalizedString("verification.challenge.error.suggestion.qr_code", comment: "Error suggestion for QR code issue")
        }
        return nil
    }

    // MARK: - Computed Properties

    private var iconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title3 : AccessibleTypography.title3
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var cardBackgroundColor: Color {
        if accessibilityManager.settings.reduceTransparency {
            return Color(uiColor: .systemBackground)
        }
        return Color(uiColor: .systemBackground).opacity(0.9)
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    // MARK: - Accessibility Helpers

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - Scan Mode Extension

private enum ScanMode {
    case scanning
    case processing
    case success
    case error

    var title: String {
        switch self {
        case .scanning: return NSLocalizedString("verification.challenge.mode.scanning", comment: "Scan QR title")
        case .processing: return NSLocalizedString("verification.challenge.mode.processing", comment: "Verifying title")
        case .success: return NSLocalizedString("verification.challenge.mode.success", comment: "Verified title")
        case .error: return NSLocalizedString("verification.challenge.mode.error", comment: "Failed title")
        }
    }

    var verboseTitle: String {
        // Note: Cannot use AbbreviationManager in extension as it requires StateObject
        // The first visible use in the view will expand the abbreviation
        switch self {
        case .scanning: return NSLocalizedString("verification.challenge.mode.scanning_verbose", comment: "Scan Verification QR Code verbose title")
        case .processing: return NSLocalizedString("verification.challenge.mode.processing_verbose", comment: "Verifying Your Age verbose title")
        case .success: return NSLocalizedString("verification.challenge.mode.success_verbose", comment: "Age Successfully Verified verbose title")
        case .error: return NSLocalizedString("verification.challenge.mode.error_verbose", comment: "Verification Failed verbose title")
        }
    }

    @MainActor
    var accessibleBackgroundColor: Color {
        switch self {
        case .success: return AccessibleColors.success.opacity(0.05)
        case .error: return AccessibleColors.error.opacity(0.05)
        default: return AccessibleColors.background
        }
    }
}

// MARK: - Supporting Components

struct AccessibleStepIndicator: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let currentStep: Int
    let totalSteps: Int
    let stepDescription: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: manager.settings.increaseTouchTargets ? 12 : 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? AccessibleColors.primary : Color.gray.opacity(0.6))
                        .frame(width: manager.settings.increaseTouchTargets ? 12 : 8,
                               height: manager.settings.increaseTouchTargets ? 12 : 8)
                        .overlay(
                            manager.settings.useHighContrast && step <= currentStep ?
                            Circle().stroke(Color.black, lineWidth: 1) : nil
                        )
                }
            }

            Text(String(format: NSLocalizedString("verification.challenge.step_indicator", comment: "Step indicator showing current and total steps"), currentStep, totalSteps))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)

            if manager.settings.verboseDescriptions {
                Text(stepDescription)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.verificationchallenge.step_indicator.label", comment: "Accessibility label for step indicator showing current step, total steps, and description"), currentStep, totalSteps, stepDescription))
    }
}

struct AccessibleTimeoutWarning: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let remainingTime: Int

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(AccessibleColors.warning)
            Text(String(format: NSLocalizedString("verification.challenge.timeout.seconds_remaining", comment: "Timeout warning showing seconds remaining"), remainingTime))
                .font(AccessibleTypography.caption)
                .foregroundColor(AccessibleColors.warning)
        }
        .padding(8)
        .background(AccessibleColors.warning.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.verificationchallenge.seconds_remaining.label", comment: "Accessibility label for timeout warning showing seconds remaining"), remainingTime))
        .accessibilityValue(String(format: "%d", remainingTime))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    NavigationStack {
        VerificationChallengeView()
            .environmentObject(NavigationCoordinator())
    }
}
