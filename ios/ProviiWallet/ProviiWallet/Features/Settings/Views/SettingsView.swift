// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine
import Speech
import AVFoundation

/// Main settings screen exposing accessibility, language, privacy, help, and sandbox
/// configuration. Includes quick-access cards for common accessibility adjustments,
/// voice control activation, credential management, and app information. Contains
/// the hidden sandbox toggle handler for switching between production and sandbox
/// environments.
struct SettingsView: View {
    @StateObject private var walletRepository = WalletRepository.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @StateObject private var sandboxToggleHandler = SandboxToggleHandler()
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss

    // Accessibility states
    @State private var showAccessibilitySettings = false
    @State private var showLanguageSelection = false
    @State private var showHelpCenter = false
    @State private var showLicenses = false
    @State private var announceChanges = false

    // Original states
    @State private var showClearProvingKeyDialog = false
    @State private var showDeleteCredentialConfirmation = false
    @State private var showEnvironmentInfo = false
    @State private var isProcessing = false
    @State private var showSandboxGenerator = false

    // Keyboard navigation for modals
    @State private var deleteDialogId = UUID()
    @State private var deleteButtonIds: [UUID] = []
    @State private var resetDialogId = UUID()
    @State private var resetButtonIds: [UUID] = []
    @State private var envInfoDialogId = UUID()
    @State private var envInfoButtonId = UUID()

    // Voice control
    @State private var voiceControlEnabled = false
    @State private var isListening = false
    @StateObject private var speechRecognizer = SpeechRecognizer()

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case accessibilityRow
        case languageRow
        case helpRow
        case licensesRow
        case sandboxRow
        case deleteButton
        case resetButton
    }

    private var isSandboxMode: Bool {
        EnvironmentManager.shared.isSandboxEnabled
    }

    var body: some View {
        settingsContent
            .navigationTitle(LocalizedString.settings.localized)
            .navigationBarTitleDisplayMode(.large)
            // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
            .setNavigationPath(["Home", "Settings"])
            .toolbar {
                toolbarContent
            }
            .alert(LocalizedString.deleteCredentialConfirm.localized, isPresented: $showDeleteCredentialConfirmation) {
                deleteCredentialAlert
            } message: {
                Text(LocalizedString.deleteCredentialConfirmMessage.localized)
                    .accessibilityLabel(LocalizedString.deleteCredentialConfirmMessage.localized)
            }
            .modalKeyboardNavigation(
                modalId: deleteDialogId,
                buttonIds: deleteButtonIds,
                onDismiss: {
                    showDeleteCredentialConfirmation = false
                    announceIfVoiceOver(LocalizedString.cancel.localized)
                },
                onConfirm: {
                    deleteCredential()
                }
            )
            .alert(LocalizedString.resetProvingKeyConfirm.localized, isPresented: $showClearProvingKeyDialog) {
                resetProvingKeyAlert
            } message: {
                Text(LocalizedString.resetProvingKeyConfirmMessage.localized)
                    .accessibilityLabel(LocalizedString.resetProvingKeyConfirmMessage.localized)
            }
            .modalKeyboardNavigation(
                modalId: resetDialogId,
                buttonIds: resetButtonIds,
                onDismiss: {
                    showClearProvingKeyDialog = false
                    announceIfVoiceOver(NSLocalizedString("reset_cancelled", comment: "Reset cancelled"))
                },
                onConfirm: {
                    resetProvingKey()
                }
            )
            .alert(NSLocalizedString("environment_configuration", comment: "Environment Configuration"), isPresented: $showEnvironmentInfo) {
                Button(NSLocalizedString("ok", comment: "OK")) {
                    announceIfVoiceOver(NSLocalizedString("dismiss_environment_info", comment: "Environment information dismissed"))
                }
                .accessibilityLabel(NSLocalizedString("dismiss_environment_info", comment: "Dismiss environment information"))
            } message: {
                environmentInfoMessage
            }
            .modalKeyboardNavigation(
                modalId: envInfoDialogId,
                buttonIds: [envInfoButtonId],
                onDismiss: {
                    showEnvironmentInfo = false
                },
                onConfirm: {
                    showEnvironmentInfo = false
                    announceIfVoiceOver(NSLocalizedString("dismiss_environment_info", comment: "Environment information dismissed"))
                }
            )
            .sheet(isPresented: $showAccessibilitySettings) {
                AccessibilitySettingsView()
                    .sheetKeyboardNavigation(isPresented: $showAccessibilitySettings)
            }
            .onChange(of: showAccessibilitySettings) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .sheet(isPresented: $showLanguageSelection) {
                NavigationStack {
                    LanguageSelectionView(
                        onLanguageSelected: {
                            showLanguageSelection = false
                        },
                        showBreadcrumbs: true,
                        isOnboarding: false,
                        onBack: nil
                    )
                    .environmentObject(accessibilityManager)
                }
                .sheetKeyboardNavigation(isPresented: $showLanguageSelection)
            }
            .onChange(of: showLanguageSelection) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .sheet(isPresented: $showHelpCenter) {
                HelpCenterView()
                    .environmentObject(accessibilityManager)
                    .sheetKeyboardNavigation(isPresented: $showHelpCenter)
            }
            .onChange(of: showHelpCenter) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .sheet(isPresented: $showLicenses) {
                LicensesView()
                    .environmentObject(accessibilityManager)
                    .sheetKeyboardNavigation(isPresented: $showLicenses)
            }
            .onChange(of: showLicenses) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .sheet(isPresented: $showSandboxGenerator) {
                SandboxCredentialSheet(isPresented: $showSandboxGenerator)
                    .sheetKeyboardNavigation(isPresented: $showSandboxGenerator)
            }
            .onChange(of: showSandboxGenerator) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .overlay {
                if isProcessing {
                    AccessibleLoadingView(message: NSLocalizedString("processing", comment: "Processing..."))
                        .accessibilityAddTraits(.isModal)
                }
            }
            .onAppear {
                setupVoiceCommands()
                setupModalButtonIds()
                announceIfVoiceOver(String(format: NSLocalizedString("settings_screen_loaded", comment: "Settings screen loaded"), activeAccessibilityFeaturesSummary))
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 20 : 16) {
                // Accessibility Card - Always first for easy access
                AccessibilityQuickAccessCard(
                    activeFeatures: activeAccessibilityFeatureCount,
                    onTap: { showAccessibilitySettings = true }
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("accessibility.settings.accessibility_settings_features_active.label", comment: "Accessibility settings with feature count"), activeAccessibilityFeatureCount))
                .accessibilityHint(NSLocalizedString("accessibility.settings.double_tap_to_open_accessibility.hint", comment: "Double tap to open accessibility settings hint"))
                .accessibilityAddTraits(.isButton)

                // Language Selection Card (hidden when only one language is enabled)
                if LanguageSettings.LanguageInfo.hasMultipleLanguages {
                    LanguageQuickAccessCard(
                        onTap: { showLanguageSelection = true }
                    )
                }

                // Help & Support Card
                HelpSupportCard(
                    onTap: { showHelpCenter = true }
                )

                // Licences Card
                AccessibleActionCard(
                    title: NSLocalizedString("licenses_title", comment: "Open Source Licences"),
                    subtitle: NSLocalizedString("licenses_subtitle", comment: "View third-party licences"),
                    icon: "doc.text.fill",
                    iconColor: AccessibleColors.primary
                ) {
                    HapticFeedback.selection()
                    announceIfVoiceOver(NSLocalizedString("opening_licenses", comment: "Opening licences"))
                    showLicenses = true
                }

                // Voice Control Card (if enabled)
                if accessibilityManager.settings.enableVoiceInput {
                    VoiceControlCard(
                        isListening: $isListening,
                        recognizedText: speechRecognizer.recognizedText,
                        onToggle: toggleVoiceControl
                    )
                }

                // Sandbox Mode Warning Card (if enabled)
                if isSandboxMode {
                    AccessibleSandboxWarningCard()

                    AccessibleActionCard(
                        title: NSLocalizedString("mint_test_credential_as_issuer", comment: "Mint test credential as Issuer"),
                        subtitle: NSLocalizedString("mint_test_credential_subtitle", comment: "Issue a test credential to your wallet so you can verify against it from a relying party demo."),
                        icon: "testtube.2",
                        iconColor: AccessibleColors.primary
                    ) {
                        HapticFeedback.selection()
                        showSandboxGenerator = true
                    }
                }

                // App Info Card with hidden sandbox toggle
                AccessibleAppInfoCard(
                    tapCount: $sandboxToggleHandler.tapCount,
                    onTap: {
                        sandboxToggleHandler.onSettingsTap()
                        HapticFeedback.selection()
                    }
                )

                // Get Credential Card
                AccessibleActionCard(
                    title: NSLocalizedString("get_a_credential", comment: "Get a Credential"),
                    subtitle: NSLocalizedString("find_trusted_issuers", comment: "Find trusted issuers"),
                    icon: "plus.circle.fill",
                    iconColor: AccessibleColors.primary,
                    action: {
                        HapticFeedback.notification(.success)
                        announceIfVoiceOver(NSLocalizedString("navigating_to_credential_issuers", comment: "Navigating to credential issuers"))
                        navigationCoordinator.navigateToWhereToGet()
                    }
                )

                // Delete Credential Card
                if hasCredential {
                    AccessibleActionCard(
                        title: NSLocalizedString("delete_credential", comment: "Delete Credential"),
                        subtitle: NSLocalizedString("remove_current_credential", comment: "Remove current credential"),
                        icon: "trash.circle.fill",
                        iconColor: AccessibleColors.error,
                        isDestructive: true,
                        action: {
                            HapticFeedback.notification(.warning)
                            showDeleteCredentialConfirmation = true
                        }
                    )
                }

                // Reset Proving Key Card
                AccessibleActionCard(
                    title: NSLocalizedString("reset_proving_key", comment: "Reset Proving Key"),
                    subtitle: NSLocalizedString("re_download_security_components", comment: "Re-download security components"),
                    icon: "arrow.clockwise.circle.fill",
                    iconColor: AccessibleColors.secondaryText,
                    action: {
                        HapticFeedback.notification(.warning)
                        showClearProvingKeyDialog = true
                    }
                )

                // Environment Settings Card (only in non-production)
                if EnvironmentManager.shared.getCurrentEnvironment != "production" {
                    AccessibleActionCard(
                        title: NSLocalizedString("environment_settings", comment: "Environment Settings"),
                        subtitle: NSLocalizedString("view_current_configuration", comment: "View current configuration"),
                        icon: "info.circle.fill",
                        iconColor: AccessibleColors.primary,
                        action: {
                            HapticFeedback.selection()
                            showEnvironmentInfo = true
                        }
                    )
                }

                // Privacy Info Card
                AccessiblePrivacyProtectionCard()
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(maxWidth: textMaxWidth)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
        }
        .background(AccessibleColors.background)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isSandboxMode {
                Text(NSLocalizedString("sandbox", comment: "SANDBOX"))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accessibilityManager.settings.useHighContrast ? Color.yellow : Color.orange)
                    .foregroundColor(accessibilityManager.settings.useHighContrast ? .black : .white)
                    .cornerRadius(4)
                    .accessibilityLabel(NSLocalizedString("sandbox_mode_is_active", comment: "Sandbox mode is active"))
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceControl) {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .foregroundColor(isListening ? .red : .primary)
                        .accessibilityLabel(isListening ? NSLocalizedString("stop_voice_control", comment: "Stop voice control") : NSLocalizedString("start_voice_control", comment: "Start voice control"))
                }
                .accessibilityInputLabels(["microphone", "voice", "dictation", "speak"])
            }
        }
    }

    // MARK: - Alerts

    private var deleteCredentialAlert: some View {
        Group {
            Button(LocalizedString.cancel.localized, role: .cancel) {
                announceIfVoiceOver(LocalizedString.cancel.localized)
            }
            Button(LocalizedString.delete.localized, role: .destructive) {
                deleteCredential()
            }
        }
    }

    private var resetProvingKeyAlert: some View {
        Group {
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {
                announceIfVoiceOver(NSLocalizedString("reset_cancelled", comment: "Reset cancelled"))
            }
            Button(NSLocalizedString("reset", comment: "Reset"), role: .destructive) {
                resetProvingKey()
            }
        }
    }

    private var environmentInfoMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("current_environment", comment: "Current Environment"))
                .font(AccessibleTypography.headline)
            Text(EnvironmentManager.shared.getCurrentEnvironment.uppercased())
                .font(AccessibleTypography.title3)
                .fontWeight(.bold)

            Text(NSLocalizedString("api_endpoints", comment: "API Endpoints"))
                .font(AccessibleTypography.headline)
                .padding(.top)
            Text(String(format: NSLocalizedString("issuer_api", comment: "Issuer: %@"), EnvironmentManager.shared.issuerApi))
                .font(AccessibleTypography.caption)
            Text(String(format: NSLocalizedString("verifier_api", comment: "Verifier: %@"), EnvironmentManager.shared.verifierApi))
                .font(AccessibleTypography.caption)

        }
    }

    // MARK: - Helper Properties

    private var hasCredential: Bool {
        switch walletRepository.credentialState {
        case .none:
            return false
        case .hasCredentials:
            return true
        }
    }

    private var activeAccessibilityFeatureCount: Int {
        var count = 0
        let settings = accessibilityManager.settings

        if settings.useExtraLargeText { count += 1 }
        if settings.useHighContrast { count += 1 }
        if settings.increaseTouchTargets { count += 1 }
        if settings.reduceMotion { count += 1 }
        if settings.timeoutBehavior != .none { count += 1 }
        if settings.simplifiedUI { count += 1 }
        if settings.enableManualCodeEntry { count += 1 }
        if settings.enableVoiceInput { count += 1 }
        if settings.hapticFeedback { count += 1 }
        if settings.verboseDescriptions { count += 1 }

        return count
    }

    private var activeAccessibilityFeaturesSummary: String {
        guard activeAccessibilityFeatureCount > 0 else {
            return NSLocalizedString("no_accessibility_features_active", comment: "No accessibility features are currently active.")
        }

        var features: [String] = []
        let settings = accessibilityManager.settings

        if settings.useExtraLargeText { features.append(NSLocalizedString("settings.accessibility.feature.large_text", comment: "large text")) }
        if settings.useHighContrast { features.append(NSLocalizedString("settings.accessibility.feature.high_contrast", comment: "high contrast")) }
        if settings.increaseTouchTargets { features.append(NSLocalizedString("settings.accessibility.feature.larger_buttons", comment: "larger buttons")) }
        if settings.reduceMotion { features.append(NSLocalizedString("settings.accessibility.feature.reduced_motion", comment: "reduced motion")) }
        if settings.enableVoiceInput { features.append(NSLocalizedString("settings.accessibility.feature.voice_control", comment: "voice control")) }

        return String(format: NSLocalizedString("settings.accessibility.features_summary", comment: "%d accessibility features active including %@"), activeAccessibilityFeatureCount, features.joined(separator: ", "))
    }

    private var textMaxWidth: CGFloat? {
        switch accessibilityManager.settings.textWidth {
        case .full: return nil
        case .comfortable: return 600
        case .narrow: return 450
        }
    }

    // MARK: - Actions

    private func deleteCredential() {
        Task {
            isProcessing = true
            announceIfVoiceOver(NSLocalizedString("deleting_credential", comment: "Deleting credential"))

            do {
                try await walletRepository.deleteAllCredentials()
                HapticFeedback.notification(.success)
                announceIfVoiceOver(NSLocalizedString("credential_deleted_successfully", comment: "Credential deleted successfully"))
                dismiss()
            } catch {
                HapticFeedback.notification(.error)
                announceIfVoiceOver(NSLocalizedString("failed_to_delete_credential", comment: "Failed to delete credential"))
                ToastManager.shared.showError(NSLocalizedString("failed_to_delete_credential", comment: "Failed to delete credential"))
                SecureLogger.shared.error("Failed to delete credential: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    private func resetProvingKey() {
        Task {
            isProcessing = true
            announceIfVoiceOver(NSLocalizedString("resetting_proving_key", comment: "Resetting proving key"))

            do {
                try await walletRepository.clearProvingKey()
                HapticFeedback.notification(.success)
                announceIfVoiceOver(NSLocalizedString("proving_key_reset_successfully_restart", comment: "Proving key reset successfully. App will restart."))
                navigationCoordinator.popToRoot()
            } catch {
                HapticFeedback.notification(.error)
                announceIfVoiceOver(NSLocalizedString("failed_to_reset_proving_key", comment: "Failed to reset proving key"))
                ToastManager.shared.showError(NSLocalizedString("failed_to_reset_proving_key", comment: "Failed to reset proving key"))
                SecureLogger.shared.error("Failed to reset proving key: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    // MARK: - Voice Control

    private func setupVoiceCommands() {
        guard accessibilityManager.settings.enableVoiceInput else { return }

        speechRecognizer.onRecognizedCommand = { command in
            self.handleVoiceCommand(command)
        }
    }

    private func setupModalButtonIds() {
        // Generate unique IDs for modal buttons
        deleteButtonIds = [UUID(), UUID()] // Cancel, Delete
        resetButtonIds = [UUID(), UUID()] // Cancel, Reset
        envInfoButtonId = UUID() // OK button
    }

    private func toggleVoiceControl() {
        if isListening {
            speechRecognizer.stopListening()
            isListening = false
            announceIfVoiceOver(NSLocalizedString("voice_control_stopped", comment: "Voice control stopped"))
        } else {
            speechRecognizer.startListening()
            isListening = true
            announceIfVoiceOver(NSLocalizedString("voice_control_started_say_command", comment: "Voice control started. Say a command."))
        }
        HapticFeedback.selection()
    }

    private func handleVoiceCommand(_ command: String) {
        let lowercased = command.lowercased()

        if lowercased.contains("accessibility") {
            showAccessibilitySettings = true
            announceIfVoiceOver(NSLocalizedString("opening_accessibility_settings", comment: "Opening accessibility settings"))
        } else if lowercased.contains("delete") && lowercased.contains("credential") {
            showDeleteCredentialConfirmation = true
        } else if lowercased.contains("get") && lowercased.contains("credential") {
            navigationCoordinator.navigateToWhereToGet()
        } else if lowercased.contains("close") || lowercased.contains("back") {
            dismiss()
        }
    }

    // MARK: - Accessibility Helpers

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Accessible Component Cards

struct AccessibilityQuickAccessCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let activeFeatures: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "accessibility")
                    .font(accessibilityManager.settings.increaseTouchTargets ? AccessibleTypography.title3 : AccessibleTypography.headline)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AccessibleColors.primary)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.accessibility.localized)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)

                    Text(activeFeatures > 0 ? "\(activeFeatures) \(LocalizedString.featuresActive.localized)" : LocalizedString.customizeYourExperience.localized)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibleText(baseSize: 12)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            onTap()
            return .handled
        }
        .onKeyPress(.space) {
            onTap()
            return .handled
        }
    }
}

struct LanguageQuickAccessCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @StateObject private var languageManager = LanguageManager.shared
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(accessibilityManager.settings.increaseTouchTargets ? AccessibleTypography.title3 : AccessibleTypography.headline)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AccessibleColors.primary)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("language", comment: "Language"))
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)

                    Text(languageManager.currentLanguage.nativeName)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibleText(baseSize: 12)
                }

                Spacer()

                if languageManager.isRTL {
                    Text(NSLocalizedString("rtl", comment: "RTL"))
                        .font(AccessibleTypography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AccessibleColors.primary.opacity(0.2))
                        .foregroundColor(AccessibleColors.primary)
                        .cornerRadius(4)
                        .accessibilityHidden(true)
                }

                Image(systemName: "chevron.right")
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            onTap()
            return .handled
        }
        .onKeyPress(.space) {
            onTap()
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("language_currently", comment: "Currently %@"), languageManager.currentLanguage.nativeName))
        .accessibilityHint(NSLocalizedString("accessibility.settings.double_tap_to_change.hint", comment: ""))
        .accessibilityAddTraits(.isButton)
    }
}

struct VoiceControlCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Binding var isListening: Bool
    let recognizedText: String
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(AccessibleTypography.body)
                    .foregroundColor(isListening ? .red : AccessibleColors.primary)

                Text(NSLocalizedString("voice_control", comment: "Voice Control"))
                    .font(AccessibleTypography.headline)

                Spacer()

                Toggle("", isOn: $isListening)
                    .labelsHidden()
                    .onChange(of: isListening) { _ in
                        onToggle()
                    }
            }

            if isListening && !recognizedText.isEmpty {
                Text(String(format: NSLocalizedString("heard", comment: "Heard: %@"), recognizedText))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .accessibleText(baseSize: 12)
            }

            Text(NSLocalizedString("say_open_accessibility_or_delete", comment: "Say 'Open accessibility' or 'Delete credential'"))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)
                .accessibleText(baseSize: 12)
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .accessibleCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(NSLocalizedString("voice_control", comment: "Voice Control")). \(isListening ? NSLocalizedString("voice_control_listening", comment: "Listening") : NSLocalizedString("voice_control_not_listening", comment: "Not listening"))")
        .accessibilityHint(NSLocalizedString("voice_control_toggle_hint", comment: "Double tap to toggle voice control"))
    }
}

struct AccessibleSandboxWarningCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.headline : AccessibleTypography.body)
                .foregroundColor(accessibilityManager.settings.useHighContrast ? .black : .orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("sandbox_mode_active", comment: "Sandbox Mode Active"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(.primary)
                Text(NSLocalizedString("using_test_environment", comment: "Using test environment"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibleText(baseSize: 12)
            }

            Spacer()
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .background(
            (accessibilityManager.settings.useHighContrast ? Color.yellow : Color.orange)
                .opacity(0.1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    accessibilityManager.settings.useHighContrast ? Color.black : Color.orange,
                    lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
                )
        )
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("sandbox_warning_accessibility", comment: "Warning: Sandbox mode is active. Using test environment."))
    }
}

struct AccessibleAppInfoCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Binding var tapCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("provii_wallet", comment: "Provii Wallet"))
                    .font(AccessibleTypography.title3)
                    .fontWeight(.bold)

                HStack {
                    Text(NSLocalizedString("version_number", comment: "Version: 1.0.0"))
                        .font(AccessibleTypography.body)

                    Spacer()

                }

                if accessibilityManager.settings.verboseDescriptions {
                    Text(NSLocalizedString("private_age_verification_zkp", comment: "Private age verification using zero knowledge proofs"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibleText(baseSize: 12)
                        .accessibilityLabel(PronunciationGuide.accessiblePhrase(
                            NSLocalizedString("private_age_verification_zkp", comment: "Private age verification using zero knowledge proofs"),
                            expandingTerms: ["ZKP"]))
                }

                if EnvironmentManager.shared.getCurrentEnvironment != "production" && !accessibilityManager.settings.simplifiedUI {
                    HStack {
                        Image(systemName: "server.rack")
                            .font(AccessibleTypography.caption)
                        Text(String(format: NSLocalizedString("environment_label", comment: "Environment: %@"), EnvironmentManager.shared.getCurrentEnvironment))
                            .font(AccessibleTypography.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(AccessibleColors.primary)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(NSLocalizedString("app_info_version_accessibility_simple", comment: "App information. Version 1.0.0."))
    }
}

struct AccessibleActionCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(accessibilityManager.settings.increaseTouchTargets ? AccessibleTypography.title3 : AccessibleTypography.headline)
                    .foregroundColor(iconColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(isDestructive ? AccessibleColors.error : .primary)

                    if !accessibilityManager.settings.simplifiedUI || accessibilityManager.settings.verboseDescriptions {
                        Text(subtitle)
                            .font(AccessibleTypography.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                            .accessibleText(baseSize: 12)
                    }
                }

                Spacer()

                if !accessibilityManager.settings.simplifiedUI {
                    Image(systemName: "chevron.right")
                        .font(AccessibleTypography.footnote)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.settings.action_card.label", comment: "Action card title and subtitle"), title, subtitle))
        .accessibilityHint(String(format: NSLocalizedString("accessibility.settings.double_tap_to_action.hint", comment: "Double tap to perform action hint"), title.lowercased()))
        .accessibilityAddTraits(isDestructive ? .isButton : [.isButton])
    }
}

struct AccessiblePrivacyProtectionCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.headline : AccessibleTypography.body)
                .foregroundColor(AccessibleColors.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("privacy_protected", comment: "Privacy Protected"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.primary)

                Text(NSLocalizedString("privacy_message", comment: "Your date of birth is never shared. Verifiers only learn if you meet their age requirement."))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibleText(baseSize: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .background(AccessibleColors.primary.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("privacy_message", comment: "Privacy protected. Your date of birth is never shared. Verifiers only learn if you meet their age requirement."))
    }
}

struct HelpSupportCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(accessibilityManager.settings.increaseTouchTargets ? AccessibleTypography.title3 : AccessibleTypography.headline)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AccessibleColors.primary)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("help_and_support", comment: "Help & Support"))
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)

                    Text(NSLocalizedString("help_description", comment: "Get help with app features and accessibility"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibleText(baseSize: 12)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("help_and_support", comment: "Help & Support"))
        .accessibilityHint(NSLocalizedString("help_hint", comment: "Double tap to access help center and support"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Speech Recognition

class SpeechRecognizer: ObservableObject {
    @Published var recognizedText = ""
    @Published var isListening = false

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()

    var onRecognizedCommand: ((String) -> Void)?

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        do {
            try startRecognition()
            isListening = true
        } catch {
            SecureLogger.shared.error("Speech recognition failed: \(error.localizedDescription)")
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        recognizedText = ""
    }

    private func startRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString

                // Check for commands
                if result.isFinal {
                    self.onRecognizedCommand?(result.bestTranscription.formattedString)
                }
            }

            if error != nil || result?.isFinal == true {
                self.stopListening()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
}

struct SandboxCredentialSheet: View {
    @Binding var isPresented: Bool
    @State private var credentialType: String = "primary"
    @State private var nickname: String = ""
    @State private var selectedAge: Int = 18
    @State private var useCustomDob = false
    @State private var customDob: Date = Calendar(identifier: .gregorian)
        .date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var generatedCredentialId: String?

    private let nicknameMaxLength = 30
    private let ageOptions = [5, 10, 13, 16, 18, 21, 25]
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            Form {
                descriptionSection
                credentialTypeSection
                if credentialType == "managed" {
                    nicknameSection
                }
                ageSelectionSection
                dobSection
                generateButtonSection
                if successMessage != nil || errorMessage != nil {
                    statusSection
                }
            }
            .navigationTitle(NSLocalizedString("sandbox_credential", comment: "Sandbox Credential"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("close", comment: "Close")) { isPresented = false }
                }
            }
            .onChange(of: selectedAge) { newAge in
                guard !useCustomDob else { return }
                customDob = suggestedDob(for: newAge)
            }
            .onChange(of: useCustomDob) { isOn in
                if isOn {
                    customDob = suggestedDob(for: selectedAge)
                }
            }
        }
    }

    private var descriptionSection: some View {
        Section(header: Text(NSLocalizedString("test_credential", comment: "Test Credential"))) {
            Text(NSLocalizedString("sandbox_credential_description", comment: "Generate a sandbox credential to exercise verification flows without touching production data."))
                .font(.callout)
                .foregroundColor(.secondary)
                .accessibilityLabel(NSLocalizedString("sandbox_credential_accessibility", comment: "Generate a sandbox credential to test verification flows safely in the sandbox environment."))
        }
    }

    private var credentialTypeSection: some View {
        Section(header: Text(NSLocalizedString("sandbox_credential_type", comment: "Credential Type"))) {
            Picker(NSLocalizedString("sandbox_credential_type", comment: "Credential Type"), selection: $credentialType) {
                Text(NSLocalizedString("sandbox_type_your_credential", comment: "Your Credential")).tag("primary")
                Text(NSLocalizedString("sandbox_type_managed_credential", comment: "Managed Credential")).tag("managed")
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(NSLocalizedString("sandbox_credential_type", comment: "Credential Type"))
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField(
                NSLocalizedString("sandbox_nickname_placeholder", comment: "e.g. Sarah"),
                text: $nickname
            )
            .onChange(of: nickname) { newValue in
                if newValue.count > nicknameMaxLength {
                    nickname = String(newValue.prefix(nicknameMaxLength))
                }
            }
            .accessibilityLabel(NSLocalizedString("sandbox_nickname", comment: "Nickname"))
            .accessibilityHint(NSLocalizedString("sandbox_nickname_required", comment: "A nickname is required for managed credentials"))
        } header: {
            Text(NSLocalizedString("sandbox_nickname", comment: "Nickname"))
        } footer: {
            Text(NSLocalizedString("sandbox_nickname_footer", comment: "Give this credential a name so you can identify it in your wallet."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var ageSelectionSection: some View {
        Section(header: Text(NSLocalizedString("select_age", comment: "Select Age"))) {
            Picker(NSLocalizedString("age_label", comment: "Age"), selection: $selectedAge) {
                ForEach(ageOptions, id: \.self) { age in
                    Text(String(format: NSLocalizedString("years_format", comment: "%d years"), age)).tag(age)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(NSLocalizedString("select_simulated_age", comment: "Select simulated age"))

            Text(String(format: NSLocalizedString("default_date_of_birth", comment: "Default date of birth: %@"), isoString(for: suggestedDob(for: selectedAge))))
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel(String(format: NSLocalizedString("default_date_of_birth", comment: "Default date of birth: %@"), isoString(for: suggestedDob(for: selectedAge))))
        }
    }

    private var dobSection: some View {
        Section {
            Toggle(NSLocalizedString("override_default_dob", comment: "Override default date of birth"), isOn: $useCustomDob.animation())
                .accessibilityHint(NSLocalizedString("enable_exact_dob_hint", comment: "Enable to choose an exact date of birth instead of using the generated default."))

            if useCustomDob {
                DatePicker(
                    NSLocalizedString("date_of_birth", comment: "Date of birth"),
                    selection: Binding(
                        get: { customDobClamped },
                        set: { newValue in customDob = clampToRange(newValue) }
                    ),
                    in: dobRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .accessibilityLabel(NSLocalizedString("select_dob_sandbox", comment: "Select date of birth for sandbox credential"))
            }
        } header: {
            Text(NSLocalizedString("date_of_birth_optional", comment: "Date of Birth (Optional)"))
        } footer: {
            Text(NSLocalizedString("leave_off_based_on_age", comment: "Leave this off to base the credential on the age you selected above."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var generateButtonSection: some View {
        Section {
            Button(action: generateCredential) {
                HStack {
                    if isGenerating {
                        ProgressView()
                    }
                    Text(isGenerating ? NSLocalizedString("generating", comment: "Generating...") : NSLocalizedString("generate_credential", comment: "Generate Credential"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isGenerating || (credentialType == "managed" && nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            .accessibilityLabel(NSLocalizedString("generate_sandbox_credential", comment: "Generate sandbox credential"))
            .accessibilityHint(NSLocalizedString("creates_credential_sandbox_testing", comment: "Creates a credential saved only in sandbox mode for quick verification testing."))
        }
    }

    private var statusSection: some View {
        Section(NSLocalizedString("status", comment: "Status")) {
            if let successMessage, let credentialId = generatedCredentialId {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("test_credential_saved", comment: "Test credential saved"))
                            .fontWeight(.semibold)
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                        Text(String(format: NSLocalizedString("id_prefix", comment: "ID prefix: %@"), String(credentialId.prefix(8)) + "…"))
                            .font(.caption.monospaced())
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .accessibilityLabel("\(NSLocalizedString("test_credential_saved", comment: "Test credential saved")). \(successMessage)")
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .accessibilityLabel("\(NSLocalizedString("credential_generation_failed", comment: "Credential generation failed")). \(errorMessage)")
            }
        }
    }

    private func generateCredential() {
        guard !isGenerating else { return }
        errorMessage = nil
        successMessage = nil
        generatedCredentialId = nil
        isGenerating = true

        HapticFeedback.selection()

        Task {
            do {
                let dateOverride = useCustomDob ? customDobClamped : nil
                let dobDescription: String
                if let dateOverride {
                    dobDescription = "DOB \(isoString(for: dateOverride))"
                } else {
                    dobDescription = "Age \(selectedAge) (DOB \(isoString(for: suggestedDob(for: selectedAge))))"
                }

                let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                let id = try await WalletRepository.shared.generateSandboxCredential(
                    ageYears: selectedAge,
                    dateOfBirth: dateOverride,
                    credentialType: credentialType,
                    nickname: credentialType == "managed" ? trimmedNickname : nil
                )
                if credentialType == "managed" {
                    successMessage = "\(dobDescription) (managed: \(trimmedNickname))"
                } else {
                    successMessage = dobDescription
                }
                generatedCredentialId = String(id)
                HapticFeedback.notification(.success)
            } catch {
                errorMessage = error.localizedDescription
                HapticFeedback.notification(.error)
            }

            isGenerating = false
        }
    }

    private func suggestedDob(for age: Int) -> Date {
        let components = DateComponents(year: -max(age, 0))
        return calendar.date(byAdding: components, to: Date()) ?? Date()
    }

    private func isoString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        // Keep en_US_POSIX ONLY for ISO 8601 API/data parsing, NOT for display
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    private var dobRange: ClosedRange<Date> {
        let minDate = calendar.date(byAdding: .year, value: -120, to: Date()) ?? Date.distantPast
        return minDate...Date()
    }

    private var customDobClamped: Date {
        clampToRange(customDob)
    }

    private func clampToRange(_ date: Date) -> Date {
        let lowerBound = dobRange.lowerBound
        let upperBound = dobRange.upperBound
        return min(max(date, lowerBound), upperBound)
    }
}
