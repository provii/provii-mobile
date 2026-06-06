// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import CoreImage.CIFilterBuiltins

/// QR code display screen for delivering a signed attestation to the citizen's wallet.
/// Renders the attestation payload as a scannable QR code with brightness boost, automatic
/// timeout handling, and accessible labelling. Officers can also trigger manual completion
/// if the citizen confirms receipt.
struct OfficerShowAttestationQrView: View {
    @StateObject private var officerAuthManager = OfficerAuthManager.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    let attestationData: String

    @State private var userScanned = false
    @State private var qrImage: UIImage?
    @State private var qrData: String?
    @State private var timeElapsed = 0
    @State private var timer: Timer?
    @State private var showAlternatives = false
    @State private var copiedToClipboard = false

    // Accessibility states
    @State private var voiceControlActive = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var lastAnnouncedStatus = ""

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                if qrImage != nil && qrData != nil {
                    accessibleSuccessContent
                } else {
                    accessibleErrorContent
                }
            }
            .padding(padding)
        }
        .background(AccessibleColors.background)
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of attestation QR codes
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(
            accessibilityManager.settings.useExtraLargeText ? .large : .inline
        )
        // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
        .setNavigationPath(["Home", "Officer Mode", "Issue Credential", "Show Attestation QR"])
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
        }
        .task {
            await generateQRCode()
            startTimer()
        }
        .onAppear {
            setupAccessibility()
        }
        .onDisappear {
            cleanupAccessibility()
        }
    }

    // MARK: - Accessible Success Content

    private var accessibleSuccessContent: some View {
        VStack(spacing: contentSpacing) {
            // Success header
            accessibleSuccessHeader

            // Instructions
            accessibleInstructions

            // QR Code Card
            if let qrImage = qrImage {
                accessibleQRCodeCard(image: qrImage)
            }

            // Alternative methods (simplified UI)
            if accessibilityManager.settings.simplifiedUI || showAlternatives {
                accessibleAlternativeMethods
            }

            // Deeplink Display (verbose mode)
            if accessibilityManager.settings.verboseDescriptions, let qrData = qrData {
                accessibleDeeplinkDisplay(data: qrData)
            }

            // Status and Actions
            if !userScanned {
                accessibleWaitingStatus
            } else {
                accessibleCompleteStatus
            }

            // Voice command hints
            if accessibilityManager.settings.enableVoiceInput && voiceControlActive {
                voiceCommandHints
            }
        }
    }

    private var accessibleSuccessHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                if accessibilityManager.settings.useHighContrast {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 80, height: 80)
                }

                Image(systemName: "checkmark.circle.fill")
                    .font(headerIconSize)
                    .foregroundColor(AccessibleColors.success)
            }
            .accessibilityHidden(true)

            Text(NSLocalizedString("officer.attestation_qr.attestation_created", comment: "Attestation created title"))
                .font(AccessibleTypography.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)

            if accessibilityManager.settings.showStepNumbers {
                Text(NSLocalizedString("officer.attestation_qr.step_user_scan", comment: "Step 3 of 3: User Scan"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }

            if timeElapsed > 0 {
                Text(String(format: NSLocalizedString("officer.attestation_qr.time_elapsed", comment: "Time elapsed display"), formattedTime))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.officershowattestationqr.time_elapsed.label", comment: "Accessibility label for time elapsed display"), formattedTime))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.attestation_created_successfully.label", comment: ""))
    }

    private var accessibleInstructions: some View {
        VStack(spacing: 8) {
            Text(instructionText)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if accessibilityManager.settings.verboseDescriptions {
                Text(NSLocalizedString("officer.attestation_qr.qr_description", comment: "QR code description"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private func accessibleQRCodeCard(image: UIImage) -> some View {
        VStack(spacing: 12) {
            if !accessibilityManager.settings.simplifiedUI {
                Text(NSLocalizedString("officer.attestation_qr.scan_label", comment: "SCAN WITH PROVII WALLET label"))
                    .font(AccessibleTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: qrCodeSize, height: qrCodeSize)
                .padding(qrCodePadding)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            accessibilityManager.settings.useHighContrast ?
                            Color.black : Color.clear,
                            lineWidth: 3
                        )
                )
                .shadow(
                    color: .black.opacity(shadowOpacity),
                    radius: accessibilityManager.settings.reduceMotion ? 0 : 8,
                    y: accessibilityManager.settings.reduceMotion ? 0 : 4
                )

            if !showAlternatives {
                Button(NSLocalizedString("officer.attestation_qr.show_alternatives", comment: "Show alternative methods button")) {
                    withAnimation {
                        showAlternatives = true
                    }
                    HapticFeedback.selection()
                }
                .font(AccessibleTypography.caption)
                .foregroundColor(AccessibleColors.primary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.qr_code_for_attestation.label", comment: "Accessibility label for QR code display for attestation"))
        .accessibilityHint(showAlternatives ? "" : NSLocalizedString("accessibility.officershowattestationqr.alternative_methods_available.hint", comment: "Accessibility hint indicating alternative methods are available"))
    }

    private var accessibleAlternativeMethods: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("officer.attestation_qr.alternative_methods", comment: "Alternative methods heading"))
                .font(AccessibleTypography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy link button
            Button {
                copyLinkToClipboard()
            } label: {
                HStack {
                    Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.clipboard")
                    Text(copiedToClipboard ? NSLocalizedString("officer.attestation_qr.copied", comment: "Copied confirmation") : NSLocalizedString("officer.attestation_qr.copy_link", comment: "Copy attestation link button"))
                    Spacer()
                }
                .foregroundColor(AccessibleColors.primary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AccessibleColors.primary, lineWidth: 1)
            )
            .accessibilityLabel(
                copiedToClipboard
                    ? NSLocalizedString("accessibility.officershowattestationqr.link_copied_to_clipboard.label", comment: "Accessibility label confirming link was copied to clipboard")
                    : NSLocalizedString("accessibility.officershowattestationqr.copy_attestation_link.label", comment: "Accessibility label for button to copy attestation link"))
            .accessibilitySortPriority(2)

            // Share button
            Button {
                shareAttestationLink()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(NSLocalizedString("officer.attestation_qr.share_link", comment: "Share attestation link button"))
                    Spacer()
                }
                .foregroundColor(AccessibleColors.primary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AccessibleColors.primary, lineWidth: 1)
            )
            .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.share_attestation_link.label", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.officershowattestationqr.opens_share_sheet.hint", comment: ""))
            .accessibilitySortPriority(1)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func accessibleDeeplinkDisplay(data: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(NSLocalizedString("officer.attestation_qr.deeplink_label", comment: "ATTESTATION DEEPLINK label"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary.opacity(0.7))

                Spacer()

                Button {
                    copyLinkToClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(AccessibleTypography.footnote)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.copy_deeplink.label", comment: ""))
            }

            Text(truncatedDeeplink(data))
                .font(AccessibleTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemFill))
        )
        .accessibilityElement(children: .contain)
    }

    private var accessibleWaitingStatus: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("officer.attestation_qr.waiting_for_user", comment: "Waiting for user title"))
                        .font(AccessibleTypography.headline)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)

                    Text(waitingDescription)
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)

                    if timeElapsed > 60 {
                        Text(NSLocalizedString("officer.attestation_qr.taking_longer_warning", comment: "Taking longer than expected warning"))
                            .font(AccessibleTypography.caption)
                            .foregroundColor(AccessibleColors.warning)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(cardPadding)
            .background(waitingStatusBackground)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("accessibility.officershowattestationqr.waiting_for_user_to_scan.label", comment: "Accessibility label for waiting status with description"), waitingDescription))

            Button {
                confirmUserScanned()
            } label: {
                Text(NSLocalizedString("officer.attestation_qr.user_scanned_button", comment: "User has scanned successfully button"))
                    .font(AccessibleTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.confirm_user_has_scanned.label", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.officershowattestationqr.mark_the_credential_as.hint", comment: ""))
        }
    }

    private var accessibleCompleteStatus: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.success)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("officer.attestation_qr.issuance_complete", comment: "Issuance complete title"))
                        .font(AccessibleTypography.headline)
                        .fontWeight(.medium)
                        .foregroundColor(AccessibleColors.success)

                    Text(NSLocalizedString("officer.attestation_qr.user_received_credential", comment: "User received credential message"))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)

                    if let sessionInfo = officerAuthManager.currentSession {
                        Text(String(format: NSLocalizedString("officer.attestation_qr.total_issued_today", comment: "Total issued today count"), sessionInfo.issuedToday))
                            .font(AccessibleTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(cardPadding)
            .background(completeStatusBackground)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.issuance_complete_user_has.label", comment: ""))

            Button {
                returnToDashboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                    Text(NSLocalizedString("officer.attestation_qr.return_dashboard_button", comment: "Return to dashboard button"))
                }
                .font(AccessibleTypography.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.officershowattestationqr.return_to_dashboard.label", comment: ""))
            .accessibilityHint(NSLocalizedString("accessibility.officershowattestationqr.go_back_to_officer.hint", comment: ""))
        }
        .onAppear {
            announceIfVoiceOver(NSLocalizedString("officer.attestation_qr.announce_complete", comment: "Credential successfully issued announcement"))
        }
    }

    private var voiceCommandHints: some View {
        Text(NSLocalizedString("officer.attestation_qr.voice_hints", comment: "Voice command hints"))
            .font(AccessibleTypography.caption)
            .foregroundColor(.secondary)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }

    // MARK: - Error Content

    private var accessibleErrorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(AccessibleTypography.title3)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            Text(NSLocalizedString("officer.attestation_qr.error_title", comment: "Failed to generate QR code title"))
                .font(AccessibleTypography.headline)
                .foregroundColor(AccessibleColors.error)

            Text(NSLocalizedString("officer.attestation_qr.error_message", comment: "Failed to generate QR code message"))
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                officerAuthManager.resetIssuance()
                dismiss()
            } label: {
                Text(NSLocalizedString("officer.attestation_qr.go_back_button", comment: "Go back button"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())
            .accessibilityLabel(AccessibilityLabels.back)
            .accessibilityHint(NSLocalizedString("accessibility.officershowattestationqr.return_to_issuance_form.hint", comment: ""))
        }
        .padding(cardPadding)
        .background(errorBackground)
        .accessibilityElement(children: .contain)
        .onAppear {
            announceIfVoiceOver(NSLocalizedString("officer.attestation_qr.announce_error", comment: "Error announcement for QR generation failure"))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceControl) {
                    Image(systemName: voiceControlActive ? "mic.fill" : "mic")
                        .foregroundColor(voiceControlActive ? .red : .primary)
                }
                .accessibilityLabel(voiceControlActive ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                returnToDashboard()
            } label: {
                HStack(spacing: 4) {
                    if accessibilityManager.settings.verboseDescriptions {
                        Text(userScanned ? NSLocalizedString("officer.attestation_qr.done_button", comment: "Done button") : NSLocalizedString("officer.attestation_qr.skip_button", comment: "Skip button"))
                            .font(AccessibleTypography.body)
                    }
                    Image(systemName: userScanned ? "checkmark" : "xmark")
                }
            }
            .accessibilityLabel(
                userScanned
                    ? NSLocalizedString("accessibility.officershowattestationqr.complete_and_return.label", comment: "Accessibility label for button to complete and return")
                    : NSLocalizedString("accessibility.officershowattestationqr.skip_waiting.label", comment: "Accessibility label for button to skip waiting"))
            .accessibilityHint(NSLocalizedString("accessibility.officershowattestationqr.return_to_dashboard.hint", comment: "Accessibility hint for returning to dashboard"))
        }
    }

    // MARK: - Helper Properties

    private var spacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var padding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var contentSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var qrCodeSize: CGFloat {
        accessibilityManager.settings.useExtraLargeText ? 320 : 280
    }

    private var qrCodePadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 24 : 20
    }

    private var headerIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title2 : AccessibleTypography.title2
    }

    private var shadowOpacity: Double {
        accessibilityManager.settings.reduceTransparency ? 0 : 0.15
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    private var navigationTitle: String {
        if accessibilityManager.settings.verboseDescriptions {
            return userScanned ? NSLocalizedString("officer.attestation_qr.nav_title_delivered", comment: "Credential delivered nav title") : NSLocalizedString("officer.attestation_qr.nav_title_ready", comment: "Ready for issuance nav title")
        }
        return NSLocalizedString("officer.attestation_qr.nav_title", comment: "Credential ready nav title")
    }

    private var instructionText: String {
        if accessibilityManager.settings.verboseDescriptions {
            return NSLocalizedString("officer.attestation_qr.instructions_verbose", comment: "Scan QR code instructions verbose")
        }
        return NSLocalizedString("officer.attestation_qr.instructions", comment: "Scan QR code instructions")
    }

    private var waitingDescription: String {
        if accessibilityManager.settings.verboseDescriptions {
            return NSLocalizedString("officer.attestation_qr.waiting_description_verbose", comment: "Waiting description verbose")
        }
        return NSLocalizedString("officer.attestation_qr.waiting_description", comment: "Waiting description")
    }

    private var formattedTime: String {
        let minutes = timeElapsed / 60
        let seconds = timeElapsed % 60
        if minutes > 0 {
            return String(format: NSLocalizedString("officer.attestation_qr.time_format_minutes", comment: "Time format with minutes and seconds"), minutes, seconds)
        }
        return String(format: NSLocalizedString("officer.attestation_qr.time_format_seconds", comment: "Time format with seconds only"), seconds)
    }

    private func truncatedDeeplink(_ data: String) -> String {
        if data.count > 60 {
            return String(data.prefix(50)) + "..."
        }
        return data
    }

    // Background styles
    private var waitingStatusBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.1))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1) : nil
            )
    }

    private var completeStatusBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.success.opacity(0.1))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AccessibleColors.success, lineWidth: 2) : nil
            )
    }

    private var errorBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.error.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AccessibleColors.error, lineWidth: 2)
            )
    }

    // MARK: - Methods

    private func generateQRCode() async {
        // Build attestation deep link
        let deeplink = "provii://attest?d=\(attestationData)"
        qrData = deeplink

        if let image = createQRCode(from: deeplink) {
            qrImage = image
            announceIfVoiceOver(NSLocalizedString("officer.attestation_qr.announce_qr_generated", comment: "QR code generated announcement"))
        }
    }

    private func createQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func confirmUserScanned() {
        userScanned = true
        HapticFeedback.notification(.success)
        announceIfVoiceOver(NSLocalizedString("officer.attestation_qr.announce_marked_complete", comment: "Marked as complete announcement"))
    }

    private func returnToDashboard() {
        officerAuthManager.resetIssuance()
        HapticFeedback.selection()
        navigationCoordinator.replace(with: .officerDashboard)
    }

    private func copyLinkToClipboard() {
        guard let qrData = qrData else { return }
        // Use ClipboardManager for automatic expiration (60 seconds)
        ClipboardManager.shared.copy(qrData)
        copiedToClipboard = true
        HapticFeedback.notification(.success)
        announceIfVoiceOver(NSLocalizedString("officer.attestation_qr.announce_link_copied", comment: "Link copied to clipboard announcement"))

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }

    private func shareAttestationLink() {
        guard let qrData = qrData else { return }
        let activityVC = UIActivityViewController(
            activityItems: [qrData],
            applicationActivities: nil
        )
        activityVC.excludedActivityTypes = [
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToVimeo,
            .postToFlickr,
            .postToTencentWeibo,
            .addToReadingList,
            .openInIBooks
        ]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        HapticFeedback.selection()
    }

    // Timer management
    private func startTimer() {
        // Cancel any existing timer to prevent duplicate counters when the
        // view reappears or the .task block re-fires.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeElapsed += 1
        }
    }

    // Voice control
    private func toggleVoiceControl() {
        if voiceControlActive {
            speechRecognizer.stopListening()
            voiceControlActive = false
        } else {
            speechRecognizer.startListening()
            voiceControlActive = true
            announceIfVoiceOver(NSLocalizedString("officer.attestation_qr.announce_voice_active", comment: "Voice control active announcement"))
        }
        HapticFeedback.selection()
    }

    private func setupAccessibility() {
        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }
    }

    private func cleanupAccessibility() {
        timer?.invalidate()
        if voiceControlActive {
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

        if lowercased.contains("complete") || lowercased.contains("done") {
            confirmUserScanned()
        } else if lowercased.contains("dashboard") || lowercased.contains("return") {
            returnToDashboard()
        } else if lowercased.contains("copy") {
            copyLinkToClipboard()
        } else if lowercased.contains("share") {
            shareAttestationLink()
        }
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
