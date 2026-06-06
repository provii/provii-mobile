// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Speech
import AVFoundation

/// Dashboard for authorised issuance officers, displaying session info (officer ID, station, daily issuance
/// count with progress towards the 50-credential limit), step by step issuance instructions, and session
/// management controls. Supports voice commands, session statistics, and adaptive accessibility layouts.

struct OfficerDashboardView: View {
    @StateObject private var officerAuthManager = OfficerAuthManager.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @State private var isEndingSession = false

    // Accessibility states
    @State private var voiceControlActive = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showDetailedInstructions = false
    @State private var currentInstructionStep = 0
    @State private var showSessionStats = false
    @State private var showConfirmEndSession = false
    @State private var issuanceCountAnnounced = false

    // Timer for session duration
    @State private var sessionDuration = 0
    @State private var sessionTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                // Accessibility Quick Status (if enabled)
                if accessibilityManager.settings.verboseDescriptions {
                    accessibleQuickStatusCard
                }

                // Officer Info Card
                if let sessionInfo = officerAuthManager.currentSession {
                    accessibleOfficerInfoCard(sessionInfo: sessionInfo)
                }

                // Main Action Card
                accessibleMainActionCard

                // Instructions Card
                accessibleInstructionsCard

                // Additional Help (for simplified UI)
                if accessibilityManager.settings.simplifiedUI {
                    accessibleHelpCard
                }

                // Session Statistics (verbose mode)
                if accessibilityManager.settings.verboseDescriptions && showSessionStats {
                    accessibleSessionStatsCard
                }
            }
            .padding(padding)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
        }
        .background(AccessibleColors.background)
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of officer session data
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(
            accessibilityManager.settings.useExtraLargeText ? .large : .inline
        )
        .toolbar {
            toolbarContent
        }
        .alert(
            LocalizedString.endSessionConfirm.localized,
            isPresented: $showConfirmEndSession
        ) {
            endSessionAlert
        } message: {
            Text(endSessionMessage)
                .accessibilityLabel(accessibleEndSessionMessage)
        }
        .onAppear {
            setupAccessibility()
            startSessionTimer()
        }
        .onDisappear {
            cleanupAccessibility()
        }
    }

    // MARK: - Accessible Components

    private var accessibleQuickStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)
                Text(LocalizedString.officerModeActive.localized)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(textColor)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(LocalizedString.officerModeMessage.localized)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if sessionDuration > 0 {
                Text("\(LocalizedString.sessionDuration.localized): \(formattedDuration)")
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(cardPadding)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerdashboard.officer_mode_active_session.label", comment: "Accessibility label for officer mode status with session duration"), formattedDuration))
    }

    private func accessibleOfficerInfoCard(sessionInfo: OfficerAuthManager.OfficerSession) -> some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            // Officer ID
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(iconSize)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedString.officerId.localized)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                    Text(sessionInfo.officerId)
                        .font(AccessibleTypography.headline)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)
                }
            }

            // Station
            HStack(spacing: 8) {
                Image(systemName: "building.2")
                    .font(smallIconSize)
                    .foregroundColor(.primary.opacity(0.7))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedString.station.localized)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                    Text(sessionInfo.stationId)
                        .font(AccessibleTypography.body)
                        .foregroundColor(textColor.opacity(0.9))
                }
            }

            // Issuance Count with Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "number.circle.fill")
                        .font(smallIconSize)
                        .foregroundColor(issuanceCountColor(sessionInfo.issuedToday))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedString.issuedToday.localized)
                            .font(AccessibleTypography.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("\(sessionInfo.issuedToday)")
                                .font(AccessibleTypography.headline)
                                .fontWeight(.bold)
                                .foregroundColor(issuanceCountColor(sessionInfo.issuedToday))

                            Text(NSLocalizedString("officer.dashboard.limit_separator", comment: "Limit separator / 50"))
                                .font(AccessibleTypography.body)
                                .foregroundColor(.secondary)

                            if sessionInfo.issuedToday >= 40 {
                                Text("(\(LocalizedString.limitApproaching.localized))")
                                    .font(AccessibleTypography.caption)
                                    .foregroundColor(AccessibleColors.warning)
                            }
                        }
                    }
                }

                // Progress bar
                if !accessibilityManager.settings.simplifiedUI {
                    ProgressView(value: Double(sessionInfo.issuedToday), total: 50)
                        .tint(issuanceCountColor(sessionInfo.issuedToday))
                        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerdashboard.credentials_issued_of_50.label", comment: "Accessibility label for progress bar showing credentials issued out of 50"), sessionInfo.issuedToday))
                }
            }

            // Additional stats button
            if accessibilityManager.settings.verboseDescriptions {
                Button {
                    withAnimation {
                        showSessionStats.toggle()
                    }
                    HapticFeedback.selection()
                } label: {
                    HStack {
                        Text(showSessionStats ? LocalizedString.hideStats.localized : LocalizedString.showStats.localized)
                            .font(AccessibleTypography.caption)
                        Spacer()
                        Image(systemName: showSessionStats ? "chevron.up" : "chevron.down")
                            .font(AccessibleTypography.caption)
                    }
                    .foregroundColor(AccessibleColors.primary)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(infoCardBackground)
        .accessibilityElement(children: .contain)
        .onAppear {
            announceIssuanceCount(sessionInfo.issuedToday)
        }
    }

    private var accessibleMainActionCard: some View {
        VStack(spacing: contentSpacing) {
            // Icon
            ZStack {
                if accessibilityManager.settings.useHighContrast {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 80, height: 80)
                }

                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(mainIconSize)
                    .foregroundColor(mainIconColor)
            }
            .accessibilityHidden(true)

            // Title
            Text(LocalizedString.issueAgeCredential.localized)
                .font(AccessibleTypography.title2)
                .fontWeight(.medium)
                .foregroundColor(textColor)

            // Description
            Text(mainActionDescription)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Action Button
            Button {
                startIssuance()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(buttonIconSize)
                    Text(LocalizedString.startNewIssuance.localized)
                        .font(AccessibleTypography.headline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, buttonPadding)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.officerdashboard.start_new_credential_issuance.label", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.officerdashboard.begin_the_process_of.hint", comment: ""))

            // Voice command hint
            if accessibilityManager.settings.enableVoiceInput && voiceControlActive {
                Text(LocalizedString.voiceHintIssuance.localized)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(mainCardPadding)
        .background(mainCardBackground)
        .accessibilityElement(children: .contain)
    }

    private var accessibleInstructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(LocalizedString.issuanceProcess.localized)
                    .font(AccessibleTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.7))

                Spacer()

                if accessibilityManager.settings.showStepNumbers {
                    Text(String(format: LocalizedString.stepsCount.localized, 5))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }

                if !accessibilityManager.settings.simplifiedUI {
                    Button {
                        withAnimation {
                            showDetailedInstructions.toggle()
                        }
                        HapticFeedback.selection()
                    } label: {
                        Image(systemName: showDetailedInstructions ? "chevron.up" : "chevron.down")
                            .font(AccessibleTypography.footnote)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(
                        showDetailedInstructions
                            ? NSLocalizedString("accessibility.officerdashboard.hide_detailed_instructions.label", comment: "Accessibility label for button to hide detailed instructions")
                            : NSLocalizedString("accessibility.officerdashboard.show_detailed_instructions.label", comment: "Accessibility label for button to show detailed instructions"))
                }
            }

            // Instructions
            VStack(alignment: .leading, spacing: instructionSpacing) {
                ForEach(instructions.indices, id: \.self) { index in
                    AccessibleInstructionRow(
                        number: index + 1,
                        text: instructions[index].brief,
                        detailedText: showDetailedInstructions ? instructions[index].detailed : nil,
                        isHighlighted: currentInstructionStep == index,
                        useHighContrast: accessibilityManager.settings.useHighContrast,
                        useExtraLargeText: accessibilityManager.settings.useExtraLargeText
                    )
                }
            }

            // Additional warning for verbose mode
            if accessibilityManager.settings.verboseDescriptions {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(AccessibleColors.warning)

                    Text(LocalizedString.issuanceImportantWarning.localized)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(instructionsCardBackground)
        .accessibilityElement(children: .contain)
    }

    private var accessibleHelpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(AccessibleColors.primary)
                Text(LocalizedString.needHelp.localized)
                    .font(AccessibleTypography.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    // Show help documentation
                    HapticFeedback.selection()
                } label: {
                    Label(LocalizedString.viewTrainingGuide.localized, systemImage: "book")
                        .font(AccessibleTypography.body)
                }

                Button {
                    // Contact support
                    HapticFeedback.selection()
                } label: {
                    Label(LocalizedString.contactSupport.localized, systemImage: "phone")
                        .font(AccessibleTypography.body)
                }
            }
            .foregroundColor(AccessibleColors.primary)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.primary.opacity(0.1))
        )
        .accessibilityElement(children: .contain)
    }

    private var accessibleSessionStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedString.sessionStatistics.localized)
                .font(AccessibleTypography.headline)

            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: LocalizedString.sessionStarted.localized, value: formattedSessionStartTime)
                StatRow(label: LocalizedString.sessionDuration.localized, value: formattedDuration)
                StatRow(label: LocalizedString.credentialsIssued.localized, value: "\(officerAuthManager.currentSession?.issuedToday ?? 0)")
                StatRow(label: LocalizedString.dailyLimit.localized, value: "50")
                StatRow(label: LocalizedString.remaining.localized, value: "\(50 - (officerAuthManager.currentSession?.issuedToday ?? 0))")
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .transition(.opacity)
        .accessibilityElement(children: .contain)
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
                .accessibilityLabel(voiceControlActive ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                if accessibilityManager.settings.confirmBeforeActions {
                    showConfirmEndSession = true
                } else {
                    endSession()
                }
            } label: {
                if isEndingSession {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel(NSLocalizedString("accessibility.officerdashboard.ending_session.label", comment: ""))
                } else {
                    HStack(spacing: 4) {
                        if accessibilityManager.settings.verboseDescriptions {
                            Text(NSLocalizedString("officer.dashboard.end_button", comment: "End button text"))
                                .font(AccessibleTypography.body)
                        }
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(toolbarIconSize)
                    }
                }
            }
            .disabled(isEndingSession)
            .accessibilityLabel(NSLocalizedString("accessibility.officerdashboard.end_officer_session.label", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.officerdashboard.log_out_of_officer.hint", comment: ""))
        }
    }

    // MARK: - Alert

    private var endSessionAlert: some View {
        Group {
            Button(LocalizedString.cancel.localized, role: .cancel) {
                announceIfVoiceOver(LocalizedString.sessionContinues.localized)
            }

            Button(LocalizedString.endSession.localized, role: .destructive) {
                endSession()
            }
        }
    }

    private var endSessionMessage: String {
        if let count = officerAuthManager.currentSession?.issuedToday, count > 0 {
            return String(format: LocalizedString.endSessionDetailedMessage.localized, count)
        }
        return LocalizedString.endSessionMessage.localized
    }

    private var accessibleEndSessionMessage: String {
        if let count = officerAuthManager.currentSession?.issuedToday, count > 0 {
            return String(format: LocalizedString.endSessionDetailedMessage.localized, count)
        }
        return LocalizedString.endSessionMessage.localized
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

    private var mainCardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var itemSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 16 : 12
    }

    private var contentSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var instructionSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 8 : 6
    }

    private var buttonPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var iconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.headline : AccessibleTypography.body
    }

    private var smallIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.subheadline
    }

    private var mainIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title2 : AccessibleTypography.title3
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

    private var mainIconColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .accentColor
    }

    private var navigationTitle: String {
        if accessibilityManager.settings.verboseDescriptions {
            return LocalizedString.officerDashboardVerbose.localized
        }
        return LocalizedString.officerDashboard.localized
    }

    private var mainActionDescription: String {
        if accessibilityManager.settings.verboseDescriptions {
            return LocalizedString.issueCredentialDetailed.localized
        }
        return LocalizedString.issueCredentialMessage.localized
    }

    private var formattedDuration: String {
        let hours = sessionDuration / 3600
        let minutes = (sessionDuration % 3600) / 60

        if hours > 0 {
            return String(format: NSLocalizedString("officer.dashboard.duration_hours_minutes", comment: "Duration format with hours and minutes"), hours, minutes)
        }
        return String(format: NSLocalizedString("officer.dashboard.duration_minutes", comment: "Duration format with only minutes"), minutes)
    }

    private var formattedSessionStartTime: String {
        // Would calculate from session start
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date().addingTimeInterval(-Double(sessionDuration)))
    }

    private var instructions: [(brief: String, detailed: String)] {
        [
            (LocalizedString.issuanceStep1.localized,
             LocalizedString.issuanceStep1Detail.localized),
            (LocalizedString.issuanceStep2.localized,
             LocalizedString.issuanceStep2Detail.localized),
            (LocalizedString.issuanceStep3.localized,
             LocalizedString.issuanceStep3Detail.localized),
            (LocalizedString.issuanceStep4.localized,
             LocalizedString.issuanceStep4Detail.localized),
            (LocalizedString.issuanceStep5.localized,
             LocalizedString.issuanceStep5Detail.localized)
        ]
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.cardBackground)
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var infoCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                accessibilityManager.settings.useHighContrast ?
                Color.yellow.opacity(0.2) :
                Color.accentColor.opacity(0.15)
            )
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var mainCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .systemBackground))
            .shadow(
                color: .black.opacity(accessibilityManager.settings.reduceTransparency ? 0 : 0.1),
                radius: accessibilityManager.settings.reduceMotion ? 0 : 4,
                y: accessibilityManager.settings.reduceMotion ? 0 : 2
            )
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var instructionsCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                accessibilityManager.settings.useHighContrast ?
                Color.yellow.opacity(0.1) :
                Color.blue.opacity(0.1)
            )
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1) : nil
            )
    }

    // MARK: - Methods

    private func issuanceCountColor(_ count: Int) -> Color {
        if count >= 45 {
            return AccessibleColors.error
        } else if count >= 40 {
            return AccessibleColors.warning
        } else {
            return AccessibleColors.success
        }
    }

    private func startIssuance() {
        HapticFeedback.selection()
        announceIfVoiceOver(LocalizedString.startingNewIssuance.localized)
        currentInstructionStep = 0
        navigationCoordinator.startIssuanceFlow()
    }

    private func endSession() {
        isEndingSession = true
        HapticFeedback.notification(.warning)
        announceIfVoiceOver(LocalizedString.endingOfficerSession.localized)

        Task {
            await officerAuthManager.endSession()
            await MainActor.run {
                isEndingSession = false
                sessionTimer?.invalidate()
                dismiss()
            }
        }
    }

    // MARK: - Voice Control

    private func toggleVoiceControl() {
        if voiceControlActive {
            speechRecognizer.stopListening()
            voiceControlActive = false
            announceIfVoiceOver(LocalizedString.voiceControlStopped.localized)
        } else {
            speechRecognizer.startListening()
            voiceControlActive = true
            announceIfVoiceOver("\(LocalizedString.voiceControlStarted.localized). \(LocalizedString.voiceHintDashboard.localized)")
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

        if lowercased.contains("start") || lowercased.contains("new") || lowercased.contains("issue") {
            startIssuance()
        } else if lowercased.contains("end") || lowercased.contains("logout") || lowercased.contains("exit") {
            if accessibilityManager.settings.confirmBeforeActions {
                showConfirmEndSession = true
            } else {
                endSession()
            }
        } else if lowercased.contains("help") {
            showDetailedInstructions = true
        } else if lowercased.contains("stats") || lowercased.contains("statistics") {
            showSessionStats = true
        }
    }

    // MARK: - Accessibility Setup

    private func setupAccessibility() {
        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }

        announceSessionStatus()
    }

    private func cleanupAccessibility() {
        if voiceControlActive {
            speechRecognizer.stopListening()
        }
        sessionTimer?.invalidate()
    }

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            sessionDuration += 60
        }
    }

    private func announceSessionStatus() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        if let session = officerAuthManager.currentSession {
            let announcement = String(format: LocalizedString.officerDashboardAnnouncement.localized, session.officerId, session.stationId, session.issuedToday)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(notification: .screenChanged, argument: announcement)
            }
        }
    }

    private func announceIssuanceCount(_ count: Int) {
        guard !issuanceCountAnnounced else { return }
        issuanceCountAnnounced = true

        if count >= 45 {
            announceIfVoiceOver(String(format: LocalizedString.warningApproachingLimit.localized, 50 - count))
        } else if count >= 40 {
            announceIfVoiceOver(String(format: LocalizedString.noticeCredentialsIssued.localized, count, 50 - count))
        }
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Supporting Components

struct AccessibleInstructionRow: View {
    let number: Int
    let text: String
    let detailedText: String?
    let isHighlighted: Bool
    let useHighContrast: Bool
    let useExtraLargeText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(useExtraLargeText ? AccessibleTypography.headline : AccessibleTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(numberColor)

                Text(text)
                    .font(useExtraLargeText ? AccessibleTypography.body : .body)
                    .foregroundColor(textColor)
            }
            .padding(.vertical, isHighlighted ? 8 : 0)
            .padding(.horizontal, isHighlighted ? 8 : 0)
            .background(
                isHighlighted ?
                RoundedRectangle(cornerRadius: 8)
                    .fill(highlightBackground) : nil
            )

            if let detailed = detailedText {
                Text(detailed)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerdashboard.instruction_step.label", comment: "Accessibility label for instruction step with number, text and optional details"), number, text, detailedText ?? ""))
    }

    private var numberColor: Color {
        if isHighlighted {
            return useHighContrast ? .black : .white
        }
        return useHighContrast ? .black : .accentColor
    }

    private var textColor: Color {
        if isHighlighted {
            return useHighContrast ? .black : .white
        }
        return useHighContrast ? .black : .primary
    }

    private var highlightBackground: Color {
        useHighContrast ? Color.yellow : Color.accentColor
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(AccessibleTypography.body)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officerdashboard.stat_row.label", comment: "Accessibility label for statistic row showing label and value"), label, value))
    }
}

#Preview {
    NavigationStack {
        OfficerDashboardView()
            .environmentObject(NavigationCoordinator())
    }
}
