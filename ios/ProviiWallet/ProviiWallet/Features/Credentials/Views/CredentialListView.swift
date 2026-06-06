// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Speech
import AVFoundation

/// Primary credential management screen displaying owned and managed credentials, empty state onboarding,
/// voice control integration, accessibility quick menu, and a floating action button for age verification.
/// Applies screenshot protection and adapts layout based on accessibility preferences.

struct CredentialListView: View {
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @StateObject private var walletRepository = WalletRepository.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    // Voice control states
    @State private var voiceControlActive = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var voiceCommandHint = ""

    // Accessibility states
    @State private var showAccessibilityQuickMenu = false
    @State private var announcementTimer: Timer?
    @State private var lastAnnouncedState: WalletRepository.CredentialState?
    @State private var showSearch = false

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case accessibilityQuickMenuButton
        case searchButton
        case settingsButton
        case voiceControlButton
    }

    var body: some View {
        content
            .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of credential metadata
            .animation(
                accessibilityManager.settings.reduceMotion ? .none : .default,
                value: walletRepository.credentialState
            )
            .animation(
                accessibilityManager.settings.reduceMotion ? .none : .default,
                value: walletRepository.isProcessing
            )
            .onAppear {
                setupAccessibility()
            }
            .onDisappear {
                cleanupAccessibility()
            }
            .onChange(of: walletRepository.credentialState) { newState in
                announceStateChange(newState)
            }
    }

    private var content: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                accessibleContentView
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.main_content", comment: "Main content area"))

            // Processing overlay
            if walletRepository.isProcessing {
                accessibleLoadingOverlay
                    .onAppear {
                        // WCAG 4.1.2: Announce when processing starts
                        UIAccessibility.post(notification: .announcement, argument: LocalizedString.announcementProcessingCredential.localized)
                    }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(
            accessibilityManager.settings.useExtraLargeText ? .large : .inline
        )
        .toolbar {
            toolbarContent
        }
        .overlay(alignment: .bottomTrailing) {
            if case .hasCredentials = walletRepository.credentialState {
                accessibleFloatingActionButton
            }
        }
        .sheet(isPresented: $showAccessibilityQuickMenu) {
            AccessibilityQuickMenuView()
                .sheetKeyboardNavigation(isPresented: $showAccessibilityQuickMenu)
        }
        .onChange(of: showAccessibilityQuickMenu) { _, isShowing in
            if isShowing {
                savedFocus = focusedElement
            } else if let saved = savedFocus {
                focusedElement = saved
                savedFocus = nil
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView()
                .sheetKeyboardNavigation(isPresented: $showSearch)
        }
        .onChange(of: showSearch) { _, isShowing in
            if isShowing {
                savedFocus = focusedElement
            } else if let saved = savedFocus {
                focusedElement = saved
                savedFocus = nil
            }
        }
    }

    // MARK: - Accessible Content View

    @ViewBuilder
    private var accessibleContentView: some View {
        switch walletRepository.credentialState {
        case .none:
            AccessibleEmptyCredentialView(
                onGenerateInPerson: {
                    HapticFeedback.selection()
                    announceIfVoiceOver(LocalizedString.announcementOpeningLocations.localized)
                    navigationCoordinator.navigateToWhereToGet()
                },
                onWhereToGet: {
                    HapticFeedback.selection()
                    announceIfVoiceOver(LocalizedString.announcementOpeningLocations.localized)
                    navigationCoordinator.navigateToWhereToGet()
                }
            )
            .transition(accessibilityManager.settings.reduceMotion ? .opacity : .slide)
            .frame(maxWidth: textMaxWidth)

        case .hasCredentials(let primary, let managed):
            CredentialSectionsView(
                primary: primary,
                managed: managed,
                onCredentialTap: { credential in
                    HapticFeedback.selection()
                    navigationCoordinator.showCredentialDetail(credentialId: credential.id)
                },
                onGetCredential: {
                    HapticFeedback.selection()
                    announceIfVoiceOver(LocalizedString.announcementOpeningLocations.localized)
                    navigationCoordinator.navigateToWhereToGet()
                },
                onAddManaged: {
                    HapticFeedback.selection()
                    announceIfVoiceOver(LocalizedString.announcementOpeningLocations.localized)
                    navigationCoordinator.navigateToWhereToGet()
                },
                onVerify: {
                    HapticFeedback.selection()
                    announceIfVoiceOver(LocalizedString.announcementOpeningVerification.localized)
                    navigationCoordinator.push(.verificationChallenge)
                }
            )
            .transition(accessibilityManager.settings.reduceMotion ? .opacity : .slide)
            .frame(maxWidth: textMaxWidth)
        }
    }

    // MARK: - Accessible Loading Overlay

    private var accessibleLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(
                accessibilityManager.settings.reduceTransparency ? 0.8 : 0.5
            )
            .ignoresSafeArea()
            .transition(.opacity)

            AccessibleLoadingView(
                message: LocalizedString.announcementProcessingCredential.localized,
                progress: nil
            )
            .transition(accessibilityManager.settings.reduceMotion ? .opacity : .scale)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.processing_credential_please_w.label", comment: ""))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceControl) {
                    Image(systemName: voiceControlActive ? "mic.fill" : "mic")
                        .foregroundColor(voiceControlActive ? .red : .primary)
                        .font(toolbarIconSize)
                }
                .focused($focusedElement, equals: .voiceControlButton)
                .accessibilityLabel(voiceControlActive ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
                .accessibilityHint(NSLocalizedString("accessibility.credentiallist.voice_commands_available.hint", comment: ""))
                .accessibilityInputLabels([
                    NSLocalizedString("voice_control.microphone", comment: "microphone"),
                    NSLocalizedString("voice_control.voice", comment: "voice"),
                    NSLocalizedString("voice_control.dictation", comment: "dictation"),
                    NSLocalizedString("voice_control.speak", comment: "speak")
                ])
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 16 : 12) {
                // Search button
                Button(action: { showSearch = true }, label: {
                    Image(systemName: "magnifyingglass")
                        .font(toolbarIconSize)
                })
                .focused($focusedElement, equals: .searchButton)
                .accessibilityLabel(NSLocalizedString("accessibility.search.label", comment: "Search"))
                .accessibilityHint(NSLocalizedString("accessibility.search.hint", comment: "Search for settings, help, and features"))
                .accessibilityInputLabels([
                    NSLocalizedString("voice_control.search", comment: "search"),
                    NSLocalizedString("voice_control.find", comment: "find"),
                    NSLocalizedString("voice_control.magnifying_glass", comment: "magnifying glass")
                ])
                .horizontalStackPriority(index: 0, count: 3)

                // Accessibility quick menu
                let activeFeatureCount = accessibilityManager.settings.activeFeatureCount
                if activeFeatureCount > 0 {
                    Button(action: { showAccessibilityQuickMenu = true }, label: {
                        Image(systemName: "accessibility")
                            .font(toolbarIconSize)
                            .foregroundColor(AccessibleColors.primary)
                    })
                    .focused($focusedElement, equals: .accessibilityQuickMenuButton)
                    .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.accessibility_quick_menu.label", comment: ""))
                    .accessibilityHint(String(format: NSLocalizedString("accessibility.credentiallist.features_active.hint", comment: "%d features active"), activeFeatureCount))
                    .horizontalStackPriority(index: 1, count: 3)
                }

                // Settings button
                Button {
                    HapticFeedback.selection()
                    announceIfVoiceOver(LocalizedString.announcementOpeningSettings.localized)
                    navigationCoordinator.navigateToSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(toolbarIconSize)
                }
                .focused($focusedElement, equals: .settingsButton)
                .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.settings.label", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.credentiallist.open_app_settings.hint", comment: ""))
                .horizontalStackPriority(index: 2, count: 3)
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Accessible Floating Action Button

    private var accessibleFloatingActionButton: some View {
        Button {
            HapticFeedback.selection()
            announceIfVoiceOver(LocalizedString.announcementOpeningVerification.localized)
            navigationCoordinator.push(.verificationChallenge)
        } label: {
            HStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 16 : 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(fabIconSize)
                Text(LocalizedString.verifyAge)
                    .font(AccessibleTypography.headline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, fabPadding.horizontal)
            .padding(.vertical, fabPadding.vertical)
            .background(fabBackground)
            .foregroundColor(fabForegroundColor)
            .clipShape(Capsule())
            .shadow(
                color: .black.opacity(accessibilityManager.settings.reduceTransparency ? 0.3 : 0.2),
                radius: accessibilityManager.settings.reduceMotion ? 0 : 8,
                x: 0,
                y: accessibilityManager.settings.reduceMotion ? 0 : 4
            )
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .transition(
            accessibilityManager.settings.reduceMotion ?
                .opacity :
                .scale.combined(with: .opacity)
        )
        .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.verify_age.label", comment: ""))
        .accessibilityHint(NSLocalizedString("accessibility.credentiallist.start_age_verification_by.hint", comment: ""))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helper Properties

    private var navigationTitle: String {
        if accessibilityManager.settings.verboseDescriptions {
            switch walletRepository.credentialState {
            case .none: return "\(LocalizedString.proviiWallet.text()) - \(LocalizedString.noCredential.text())"
            case .hasCredentials: return "\(LocalizedString.proviiWallet.text()) - \(LocalizedString.credentialActive.text())"
            }
        }
        return LocalizedString.proviiWallet.text()
    }

    private var toolbarIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.subheadline
    }

    private var fabIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title3 : AccessibleTypography.headline
    }

    private var fabPadding: (horizontal: CGFloat, vertical: CGFloat) {
        if accessibilityManager.settings.increaseTouchTargets {
            return (24, 20)
        }
        return (20, 16)
    }

    private var fabBackground: Color {
        if accessibilityManager.settings.useHighContrast {
            return Color.yellow
        }
        return Color.accentColor
    }

    private var fabForegroundColor: Color {
        if accessibilityManager.settings.useHighContrast {
            return .black
        }
        return .white
    }

    private var textMaxWidth: CGFloat? {
        switch accessibilityManager.settings.textWidth {
        case .full: return nil
        case .comfortable: return 600
        case .narrow: return 450
        }
    }

    // MARK: - Voice Control

    private func toggleVoiceControl() {
        if voiceControlActive {
            speechRecognizer.stopListening()
            voiceControlActive = false
            voiceCommandHint = ""
            announceIfVoiceOver(LocalizedString.voiceControlStopped.localized)
        } else {
            speechRecognizer.startListening()
            voiceControlActive = true
            updateVoiceCommandHint()
            announceIfVoiceOver("\(LocalizedString.voiceControlStarted.localized). \(voiceCommandHint)")
        }
        HapticFeedback.selection()
    }

    private func updateVoiceCommandHint() {
        switch walletRepository.credentialState {
        case .none:
            voiceCommandHint = LocalizedString.voiceHintNoCredential.localized
        case .hasCredentials:
            voiceCommandHint = LocalizedString.voiceHintActiveCredential.localized
        }
    }

    private func setupVoiceCommands() {
        speechRecognizer.onRecognizedCommand = { command in
            handleVoiceCommand(command)
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let lowercased = command.lowercased()

        if lowercased.contains("verify") || lowercased.contains("age") {
            if case .hasCredentials = walletRepository.credentialState {
                navigationCoordinator.push(.verificationChallenge)
            }
        } else if lowercased.contains("get") || lowercased.contains("scan") {
            navigationCoordinator.navigateToWhereToGet()
        } else if lowercased.contains("find") || lowercased.contains("location") {
            navigationCoordinator.navigateToWhereToGet()
        } else if lowercased.contains("replace") {
            navigationCoordinator.navigateToWhereToGet()
        } else if lowercased.contains("settings") {
            navigationCoordinator.navigateToSettings()
        } else if lowercased.contains("accessibility") {
            showAccessibilityQuickMenu = true
        }
    }

    // MARK: - Accessibility Setup

    private func setupAccessibility() {
        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }

        announceCurrentState()
    }

    private func cleanupAccessibility() {
        if voiceControlActive {
            speechRecognizer.stopListening()
        }
        announcementTimer?.invalidate()
    }

    private func announceCurrentState() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let announcement: String
        switch walletRepository.credentialState {
        case .none:
            announcement = LocalizedString.announcementWelcomeNoCredential.localized
        case .hasCredentials:
            announcement = LocalizedString.announcementCredentialActive.localized
        }

        // Apply pronunciation-friendly replacements for screen readers
        let pronunciationFriendlyAnnouncement = announcement.accessibilityPronunciation

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .screenChanged, argument: pronunciationFriendlyAnnouncement)
        }
    }

    private func announceStateChange(_ newState: WalletRepository.CredentialState) {
        guard newState != lastAnnouncedState else { return }
        lastAnnouncedState = newState

        let announcement: String
        switch newState {
        case .none:
            announcement = LocalizedString.announcementCredentialRemoved.localized
        case .hasCredentials:
            announcement = LocalizedString.announcementCredentialNowActive.localized
        }

        // Apply pronunciation-friendly replacements for screen readers
        announceIfVoiceOver(announcement.accessibilityPronunciation)
    }

    // MARK: - Helpers

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Accessible Empty Credential View

private struct AccessibleEmptyCredentialView: View {
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    let onGenerateInPerson: () -> Void
    let onWhereToGet: () -> Void

    @State private var showDetailedInstructions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: spacing) {
                Spacer().frame(height: topSpacing)

                // Hero icon with accessibility considerations
                heroIcon

                Spacer().frame(height: 32)

                // Welcome text
                welcomeText

                Spacer().frame(height: contentSpacing)

                // Step indicator if enabled
                if accessibilityManager.settings.showStepNumbers {
                    stepIndicator
                }

                // Primary action card
                primaryActionCard

                Spacer().frame(height: 12)

                // Secondary action card
                secondaryActionCard

                // Additional help for simplified UI
                if accessibilityManager.settings.simplifiedUI {
                    additionalHelpCard
                }

                // Detailed instructions if verbose mode
                if accessibilityManager.settings.verboseDescriptions {
                    detailedInstructionsCard
                }

                Spacer().frame(height: 24)
            }
            .padding(padding)
        }
        .accessibilityElement(children: .contain)
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundStyle)
                .frame(width: iconSize, height: iconSize)
                .overlay(
                    accessibilityManager.settings.useHighContrast ?
                    Circle().stroke(Color.black, lineWidth: 2) : nil
                )

            Image(systemName: "person.badge.shield.checkmark")
                .font(iconImageSize)
                .foregroundColor(iconColor)
        }
        .accessibilityHidden(true)
    }

    private var welcomeText: some View {
        VStack(spacing: 12) {
            Text(LocalizedString.welcomeTitle)
                .font(AccessibleTypography.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)
                .accessibilityAddTraits(.isHeader)

            Text(welcomeSubtitle)
                .font(AccessibleTypography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(AccessibleColors.secondaryText)
                .padding(.horizontal, 16)
                .accessibleText(baseSize: 17)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.credentiallist.welcome_to_provii_wallet.label", comment: "Welcome to Provii Wallet. %@"), welcomeSubtitle))
    }

    private var stepIndicator: some View {
        VStack(spacing: 8) {
            Text(LocalizedString.step1Of2.localized)
                .font(AccessibleTypography.headline)
                .foregroundColor(AccessibleColors.primary)
            Text(LocalizedString.getYourFirstCredential.localized)
                .font(AccessibleTypography.caption)
                .foregroundColor(AccessibleColors.secondaryText)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.step_1_of_2.label", comment: ""))
    }

    private var primaryActionCard: some View {
        Button(action: onGenerateInPerson) {
            HStack(spacing: cardIconSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(primaryActionIconBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            accessibilityManager.settings.useHighContrast ?
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2) : nil
                        )

                    Image(systemName: "qrcode")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(primaryActionIconColor)
                }
                .accessibilityHidden(true)
                .horizontalStackPriority(index: 0, count: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.scanQRCode)
                        .font(AccessibleTypography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    Text(primaryActionSubtitle)
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(subtitleColor)
                        .accessibleText(baseSize: 15)
                }
                .horizontalStackPriority(index: 1, count: 3)

                Spacer()

                if !accessibilityManager.settings.simplifiedUI {
                    Image(systemName: navigationChevron(isForward: true))
                        .font(AccessibleTypography.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                        .accessibilityHidden(true)
                        .horizontalStackPriority(index: 2, count: 3)
                }
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(primaryActionBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            onGenerateInPerson()
            return .handled
        }
        .onKeyPress(.space) {
            onGenerateInPerson()
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.scan_qr_code_to.label", comment: ""))
        .accessibilityHint(NSLocalizedString("accessibility.credentiallist.double_tap_to_start.hint", comment: ""))
        .accessibilityAddTraits(.isButton)
    }

    private var secondaryActionCard: some View {
        Button(action: onWhereToGet) {
            HStack(spacing: cardIconSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemFill))
                        .frame(width: 48, height: 48)

                    Image(systemName: "location")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(.primary)
                }
                .accessibilityHidden(true)
                .horizontalStackPriority(index: 0, count: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.findLocations)
                        .font(AccessibleTypography.headline)
                        .fontWeight(.semibold)

                    Text(LocalizedString.findLocationsMessage)
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibleText(baseSize: 15)
                }
                .horizontalStackPriority(index: 1, count: 3)

                Spacer()

                if !accessibilityManager.settings.simplifiedUI {
                    Image(systemName: navigationChevron(isForward: true))
                        .font(AccessibleTypography.subheadline.weight(.semibold))
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                        .horizontalStackPriority(index: 2, count: 3)
                }
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(secondaryActionBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            onWhereToGet()
            return .handled
        }
        .onKeyPress(.space) {
            onWhereToGet()
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credentiallist.find_locations_to_discover.label", comment: ""))
        .accessibilityHint(NSLocalizedString("accessibility.credentiallist.double_tap_to_open.hint", comment: ""))
        .accessibilityAddTraits(.isButton)
    }

    private var additionalHelpCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedString.needHelp.localized)
                    .font(AccessibleTypography.headline)
                Text(LocalizedString.helpTapSettingsForOptions.localized)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.primary.opacity(0.1))
        )
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credential_list.help_hint.label", comment: "Help hint accessibility label"))
    }

    private var detailedInstructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                showDetailedInstructions.toggle()

                // WCAG 4.1.2: Announce state change to assistive technologies
                let announcement = showDetailedInstructions
                    ? NSLocalizedString("accessibility.credential_list.instructions_expanded", comment: "Instructions expanded")
                    : NSLocalizedString("accessibility.credential_list.instructions_collapsed", comment: "Instructions collapsed")
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }, label: {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(AccessibleColors.primary)
                    Text(LocalizedString.howItWorks.localized)
                        .font(AccessibleTypography.headline)
                    Spacer()
                    Image(systemName: showDetailedInstructions ? "chevron.up" : "chevron.down")
                        .font(AccessibleTypography.footnote)
                }
            })
            .foregroundColor(textColor)
            .accessibilityValue(showDetailedInstructions
                ? NSLocalizedString("accessibility.state.expanded", comment: "Expanded")
                : NSLocalizedString("accessibility.state.collapsed", comment: "Collapsed"))
            .accessibilityHint(showDetailedInstructions
                ? NSLocalizedString("accessibility.hint.double_tap_to_collapse", comment: "Double tap to collapse")
                : NSLocalizedString("accessibility.hint.double_tap_to_expand", comment: "Double tap to expand"))

            if showDetailedInstructions {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedString.instructionStep1.localized)
                    Text(LocalizedString.instructionStep2.localized)
                    Text(LocalizedString.instructionStep3.localized)
                    Text(LocalizedString.instructionStep4.localized)
                    Text(LocalizedString.instructionStep5.localized)
                }
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .accessibilityElement(children: .contain)
    }

    // Helper properties
    private var spacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var topSpacing: CGFloat {
        accessibilityManager.settings.useExtraLargeText ? 60 : 40
    }

    private var contentSpacing: CGFloat {
        accessibilityManager.settings.useExtraLargeText ? 60 : 40
    }

    private var padding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 32 : 24
    }

    private var iconSize: CGFloat {
        accessibilityManager.settings.useExtraLargeText ? 100 : 80
    }

    private var iconImageSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title : AccessibleTypography.title2
    }

    private var cardIconSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 24 : 20
    }

    private var iconBackgroundStyle: AnyShapeStyle {
        if accessibilityManager.settings.useHighContrast {
            return AnyShapeStyle(Color.yellow.opacity(0.3))
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.25),
                        Color.blue.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var iconColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .accentColor
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    private var subtitleColor: Color {
        textColor.opacity(0.7)
    }

    private var welcomeSubtitle: String {
        if accessibilityManager.settings.verboseDescriptions {
            return LocalizedString.welcomeSubtitleVerbose.localized
        }
        return LocalizedString.welcomeSubtitleSimple.localized
    }

    private var primaryActionSubtitle: String {
        if accessibilityManager.settings.simplifiedUI {
            return LocalizedString.getCredentialSimple.localized
        }
        return LocalizedString.getCredentialFromIssuer.localized
    }

    private var primaryActionIconBackground: Color {
        if accessibilityManager.settings.useHighContrast {
            return Color.yellow
        }
        return Color.accentColor
    }

    private var primaryActionIconColor: Color {
        if accessibilityManager.settings.useHighContrast {
            return .black
        }
        return .white
    }

    private var cardStrokeStyle: AnyShapeStyle {
        if accessibilityManager.settings.useHighContrast {
            return AnyShapeStyle(Color.black)
        }
        return AnyShapeStyle(Color.accentColor.opacity(0.3))
    }

    private var primaryActionBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                accessibilityManager.settings.useHighContrast ?
                Color.yellow.opacity(0.2) :
                Color.accentColor.opacity(0.15)
            )
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var secondaryActionBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        accessibilityManager.settings.useHighContrast ?
                        Color.black :
                        Color(uiColor: .separator),
                        lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
                    )
            )
    }
}

// MARK: - Credential Sections View

private struct CredentialSectionsView: View {
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    let primary: StoredCredential?
    let managed: [StoredCredential]
    let onCredentialTap: (StoredCredential) -> Void
    let onGetCredential: () -> Void
    let onAddManaged: () -> Void
    let onVerify: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: sectionSpacing) {
                // MARK: My Credential section
                myCredentialSection

                // MARK: Managed Credentials section
                managedCredentialsSection
            }
            .padding(padding)
        }
    }

    // MARK: - My Credential Section

    private var myCredentialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("credential_section.my_credential", comment: "My Credential"))
                .font(AccessibleTypography.headline)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .accessibilityAddTraits(.isHeader)

            if let credential = primary {
                CredentialNicknameCard(
                    credential: credential,
                    useHighContrast: accessibilityManager.settings.useHighContrast,
                    increaseTouchTargets: accessibilityManager.settings.increaseTouchTargets,
                    onTap: { onCredentialTap(credential) }
                )
            } else {
                getCredentialButton
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var getCredentialButton: some View {
        Button(action: onGetCredential) {
            HStack(spacing: cardIconSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(getCredentialIconBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            accessibilityManager.settings.useHighContrast ?
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2) : nil
                        )

                    Image(systemName: "qrcode")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(getCredentialIconColor)
                }
                .accessibilityHidden(true)

                Text(NSLocalizedString("credential_section.get_credential", comment: "Get Credential"))
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)

                Spacer()

                if !accessibilityManager.settings.simplifiedUI {
                    Image(systemName: navigationChevron(isForward: true))
                        .font(AccessibleTypography.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(getCredentialBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            onGetCredential()
            return .handled
        }
        .onKeyPress(.space) {
            onGetCredential()
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credential_section.get_credential.label", comment: "Get a new credential"))
        .accessibilityHint(NSLocalizedString("accessibility.credential_section.get_credential.hint", comment: "Double tap to start getting a credential"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Managed Credentials Section

    private var managedCredentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(NSLocalizedString("credential_section.managed_credentials", comment: "Managed Credentials"))
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                    .accessibilityAddTraits(.isHeader)

                Text(String(format: NSLocalizedString("credential_section.managed_count", comment: "%d of 15"), managed.count))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }

            if managed.isEmpty {
                Text(NSLocalizedString("credential_section.managed_empty", comment: "Add a credential for someone you care for"))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            ForEach(managed) { credential in
                CredentialNicknameCard(
                    credential: credential,
                    useHighContrast: accessibilityManager.settings.useHighContrast,
                    increaseTouchTargets: accessibilityManager.settings.increaseTouchTargets,
                    onTap: { onCredentialTap(credential) }
                )
            }

            if managed.count < 15 {
                addManagedButton
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var addManagedButton: some View {
        Button(action: onAddManaged) {
            HStack(spacing: cardIconSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemFill))
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(.primary)
                }
                .accessibilityHidden(true)

                Text(NSLocalizedString("credential_section.add_managed", comment: "Add Managed Credential"))
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !accessibilityManager.settings.simplifiedUI {
                    Image(systemName: navigationChevron(isForward: true))
                        .font(AccessibleTypography.subheadline.weight(.semibold))
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(addManagedBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            onAddManaged()
            return .handled
        }
        .onKeyPress(.space) {
            onAddManaged()
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credential_section.add_managed.label", comment: "Add a managed credential"))
        .accessibilityHint(NSLocalizedString("accessibility.credential_section.add_managed.hint", comment: "Double tap to add a managed credential"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helper Properties

    private var sectionSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var padding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 32 : 24
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 24 : 20
    }

    private var cardIconSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    private var getCredentialIconBackground: Color {
        accessibilityManager.settings.useHighContrast ? Color.yellow : Color.accentColor
    }

    private var getCredentialIconColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .white
    }

    private var getCredentialBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                accessibilityManager.settings.useHighContrast ?
                Color.yellow.opacity(0.2) :
                Color.accentColor.opacity(0.15)
            )
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var addManagedBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        accessibilityManager.settings.useHighContrast ?
                        Color.black :
                        Color(uiColor: .separator),
                        lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
                    )
            )
    }
}

// MARK: - Credential Nickname Card

private struct CredentialNicknameCard: View {
    let credential: StoredCredential
    let useHighContrast: Bool
    let increaseTouchTargets: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: iconSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            useHighContrast ?
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2) : nil
                        )

                    Image(systemName: credential.isManaged ? "person.2.fill" : "person.fill")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(iconForeground)
                }
                .accessibilityHidden(true)

                Text(credential.displayName)
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)

                Spacer()

                Image(systemName: navigationChevron(isForward: true))
                    .font(AccessibleTypography.subheadline.weight(.semibold))
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background(cardBackground)
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
        .accessibilityLabel(credential.isManaged
            ? String(format: NSLocalizedString("accessibility.credentiallist.managed_credential_named", comment: "Managed credential: %@"), credential.displayName)
            : credential.displayName)
        .accessibilityHint(NSLocalizedString("accessibility.credential_card.tap_to_view.hint", comment: "Double tap to view credential details"))
        .accessibilityAddTraits(.isButton)
    }

    private var iconSpacing: CGFloat {
        increaseTouchTargets ? 20 : 16
    }

    private var cardPadding: CGFloat {
        increaseTouchTargets ? 24 : 20
    }

    private var minHeight: CGFloat {
        increaseTouchTargets ? 64 : 56
    }

    private var textColor: Color {
        useHighContrast ? .black : .primary
    }

    private var iconBackground: Color {
        if useHighContrast {
            return Color.yellow.opacity(0.3)
        }
        return Color.accentColor.opacity(0.15)
    }

    private var iconForeground: Color {
        useHighContrast ? .black : .accentColor
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        useHighContrast ? Color.black : Color(uiColor: .separator),
                        lineWidth: useHighContrast ? 2 : 1
                    )
            )
    }
}

// MARK: - Accessibility Quick Menu

struct AccessibilityQuickMenuView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(LocalizedString.quickSettings.localized) {
                    Toggle(LocalizedString.largeText.localized, isOn: $manager.settings.useExtraLargeText)
                    Toggle(LocalizedString.highContrast.localized, isOn: $manager.settings.useHighContrast)
                    Toggle(LocalizedString.reduceMotion.localized, isOn: $manager.settings.reduceMotion)
                    Toggle(LocalizedString.voiceInput.localized, isOn: $manager.settings.enableVoiceInput)
                }

                Section {
                    Button(LocalizedString.openFullSettings.localized) {
                        dismiss()
                        // Navigate to full accessibility settings
                    }
                }
            }
            .navigationTitle(LocalizedString.accessibility.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedString.done.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CredentialListView()
            .environmentObject(NavigationCoordinator())
    }
}
