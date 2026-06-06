// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Success screen displayed after a credential has been securely stored in the wallet.
/// Shows a confetti celebration animation with an automatic countdown that navigates
/// the user back to the home screen. Supports VoiceOver announcements and respects
/// the reduce-motion accessibility preference.
struct CredentialSuccessView: View {
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    // State management
    @State private var timeRemaining = 3
    @State private var shouldAutoNavigate = true
    @State private var hasAnnounced = false
    @State private var celebrationScale = 1.0

    // Timer for countdown
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background
            AccessibleColors.background
                .ignoresSafeArea()

            // Confetti effect (if motion enabled)
            if !accessibilityManager.settings.reduceMotion {
                ConfettiView()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    accessibleSuccessContent

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, accessibilityManager.settings.increaseTouchTargets ? 36 : 32)
            }
        }
        .navigationTitle(NSLocalizedString("credentials.success.navigation_title", comment: "Success navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(shouldAutoNavigate)
        .breadcrumb(breadcrumbPath)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            setupSuccess()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Success Content

    private var accessibleSuccessContent: some View {
        VStack(spacing: 32) {
            // Success icon with celebration animation
            successIcon

            // Success message
            successMessage

            // What's next info
            whatsNextCard

            // Navigation options
            navigationOptions
        }
        .accessibilityElement(children: .contain)
    }

    private var successIcon: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(AccessibleColors.success.opacity(0.1))
                .frame(width: 140, height: 140)

            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(AccessibleTypography.largeTitle)
                .foregroundColor(AccessibleColors.success)
                .scaleEffect(celebrationScale)
                .accessibilityHidden(true)
        }
        .onAppear {
            if !accessibilityManager.settings.reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    celebrationScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        celebrationScale = 1.0
                    }
                }
            }
        }
    }

    private var successMessage: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("credentials.success.title", comment: "Credential stored successfully"))
                .font(AccessibleTypography.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(AccessibleColors.success)
                .accessibilityAddTraits(.isHeader)

            Text(NSLocalizedString("credentials.success.message", comment: "Success message"))
                .font(AccessibleTypography.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            if accessibilityManager.settings.verboseDescriptions {
                Text(NSLocalizedString("credentials.success.privacy_message", comment: "Privacy protection message"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    private var whatsNextCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(NSLocalizedString("credentials.success.what_you_can_do", comment: "What you can do now"), systemImage: "sparkles")
                .font(AccessibleTypography.headline)
                .foregroundColor(AccessibleColors.primary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "qrcode.viewfinder",
                    text: NSLocalizedString("credentials.success.feature_scan_qr", comment: "Scan verification QR codes"),
                    description: accessibilityManager.settings.verboseDescriptions ?
                        NSLocalizedString("credentials.success.feature_scan_qr_desc", comment: "Present your credential") : nil
                )

                FeatureRow(
                    icon: "lock.shield",
                    text: NSLocalizedString("credentials.success.feature_prove_age", comment: "Prove your age privately"),
                    description: accessibilityManager.settings.verboseDescriptions ?
                        NSLocalizedString("credentials.success.feature_prove_age_desc", comment: "Without revealing birth date") : nil
                )

                FeatureRow(
                    icon: "checkmark.shield",
                    text: NSLocalizedString("credentials.success.feature_instant", comment: "Instant verification"),
                    description: accessibilityManager.settings.verboseDescriptions ?
                        NSLocalizedString("credentials.success.feature_instant_desc", comment: "Quick and secure checks") : nil
                )
            }
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.primary.opacity(0.1))
                .overlay(
                    accessibilityManager.settings.useHighContrast ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2) : nil
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.credentialsuccess.what_you_can_do.label", comment: ""))
    }

    private var navigationOptions: some View {
        VStack(spacing: 16) {
            if shouldAutoNavigate {
                // Auto-navigation indicator
                autoNavigationIndicator
            } else {
                // Manual navigation buttons
                manualNavigationButtons
            }

            // Skip/Continue button based on auto-navigation state
            Button(action: toggleAutoNavigation) {
                Text(shouldAutoNavigate ? NSLocalizedString("credentials.success.stay_on_page", comment: "Stay on this page") : NSLocalizedString("credentials.success.enable_auto_continue", comment: "Enable auto-continue"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.primary)
            }
            .accessibilityHint(shouldAutoNavigate ?
                NSLocalizedString("credentials.success.disable_auto_nav_hint", comment: "Disable automatic navigation") :
                NSLocalizedString("credentials.success.enable_auto_nav_hint", comment: "Enable automatic navigation"))
        }
    }

    private var autoNavigationIndicator: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if !accessibilityManager.settings.reduceMotion {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }

                Text(countdownText)
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
            }

            if accessibilityManager.settings.showStepNumbers {
                Text("\(timeRemaining)")
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true) // Hide since we announce it
            }

            Button(action: navigateNow) {
                Text(NSLocalizedString("credentials.success.continue_now", comment: "Continue now"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.credentialsuccess.countdown_seconds_remaining.label", comment: "%@. %d seconds remaining"), countdownText, timeRemaining))
        .accessibilityHint(NSLocalizedString("accessibility.credentialsuccess.wait_for_automatic_navigation.hint", comment: ""))
    }

    private var manualNavigationButtons: some View {
        VStack(spacing: 12) {
            Button(action: navigateToCredentials) {
                HStack {
                    Image(systemName: "wallet.pass")
                    Text(NSLocalizedString("credentials.success.view_credentials", comment: "View credentials"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())

            Button(action: navigateToVerify) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text(NSLocalizedString("credentials.success.verify_age_now", comment: "Verify age now"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !shouldAutoNavigate {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("credentials.success.done", comment: "Done")) {
                    navigateToCredentials()
                }
                .accessibilityLabel(NSLocalizedString("accessibility.credentialsuccess.done_return_to_credentials.label", comment: ""))
            }
        }
    }

    // MARK: - Actions

    private func setupSuccess() {
        let autoNavigationAllowed = accessibilityManager.settings.timeoutBehavior != .none

        if !autoNavigationAllowed && shouldAutoNavigate {
            shouldAutoNavigate = false
        }

        if autoNavigationAllowed && shouldAutoNavigate {
            timeRemaining = accessibilityManager.settings.timeoutBehavior == .extended ? 6 : 3
        } else {
            timeRemaining = 0
        }

        // Announce success with sound and haptic feedback
        if !hasAnnounced {
            hasAnnounced = true
            announceSuccess()
            VerificationSoundManager.shared.playVerificationSuccess()
        }

        guard autoNavigationAllowed && shouldAutoNavigate else {
            timer?.invalidate()
            return
        }

        startCountdown()
    }

    private func startCountdown() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1

                // Announce countdown for VoiceOver users at key intervals
                if UIAccessibility.isVoiceOverRunning && (timeRemaining == 3 || timeRemaining == 1) {
                    announceIfVoiceOver(String(format: NSLocalizedString("credentials.success.seconds_remaining", comment: "%d seconds"), timeRemaining))
                }
            } else {
                timer?.invalidate()
                navigateToCredentials()
            }
        }
    }

    private func toggleAutoNavigation() {
        shouldAutoNavigate.toggle()

        if shouldAutoNavigate {
            timeRemaining = accessibilityManager.settings.timeoutBehavior == .extended ? 6 : 3
            startCountdown()
            announceIfVoiceOver(String(format: NSLocalizedString("credentials.success.auto_continue_enabled", comment: "Auto-continue enabled"), timeRemaining))
        } else {
            timer?.invalidate()
            announceIfVoiceOver(NSLocalizedString("credentials.success.auto_continue_disabled", comment: "Auto-continue disabled"))
        }

        HapticFeedback.selection()
    }

    private func navigateNow() {
        timer?.invalidate()
        HapticFeedback.selection()
        navigateToCredentials()
    }

    private func navigateToCredentials() {
        timer?.invalidate()
        announceIfVoiceOver(NSLocalizedString("credentials.success.returning_to_credentials", comment: "Returning to credentials"))
        navigationCoordinator.popToRoot()
    }

    private func navigateToVerify() {
        timer?.invalidate()
        announceIfVoiceOver(NSLocalizedString("credentials.success.opening_scanner", comment: "Opening verification scanner"))
        navigationCoordinator.popToRoot()
        navigationCoordinator.push(.verificationChallenge)
    }

    // MARK: - Accessibility Helpers

    private var countdownText: String {
        if timeRemaining > 0 {
            return NSLocalizedString("credentials.success.returning_in", comment: "Returning to credentials in...")
        } else {
            return NSLocalizedString("credentials.success.returning_now", comment: "Returning now...")
        }
    }

    private func announceSuccess() {
        let autoNavPart = shouldAutoNavigate ?
            String(format: NSLocalizedString("credentials.success.announcement_auto_nav", comment: "Auto-nav announcement part"), timeRemaining) :
            NSLocalizedString("credentials.success.announcement_choose_option", comment: "Choose option announcement")

        let message = """
        \(NSLocalizedString("credentials.success.announcement_success", comment: "Success announcement"))
        \(NSLocalizedString("credentials.success.announcement_can_prove", comment: "Can prove age message"))
        \(autoNavPart)
        """
        announceIfVoiceOver(message)
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private var breadcrumbPath: [String] {
        [
            NSLocalizedString("breadcrumb.home", comment: "Home"),
            NSLocalizedString("breadcrumb.credentials", comment: "Credentials"),
            NSLocalizedString("breadcrumb.success", comment: "Success")
        ]
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    let icon: String
    let text: String
    let description: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.primary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(AccessibleTypography.body)
                    .foregroundColor(.primary)

                if let description = description {
                    Text(description)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { _ in
            ForEach(confettiPieces) { piece in
                Circle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .position(piece.position)
                    .opacity(piece.opacity)
            }
        }
        .onAppear {
            createConfetti()
        }
    }

    private func createConfetti() {
        for _ in 0..<30 {
            let piece = ConfettiPiece()
            confettiPieces.append(piece)

            withAnimation(.linear(duration: piece.duration)) {
                if let index = confettiPieces.firstIndex(where: { $0.id == piece.id }) {
                    let screenHeight = (UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.screen.bounds.height) ?? 800
                    confettiPieces[index].position.y = screenHeight + 100
                    confettiPieces[index].opacity = 0
                }
            }
        }

        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            confettiPieces.removeAll()
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
    let duration: Double

    init() {
        let screenWidth = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width) ?? 400
        self.position = CGPoint(
            x: CGFloat.random(in: 0...screenWidth),
            y: -20
        )
        self.color = [Color.red, .blue, .green, .yellow, .orange, .purple].randomElement() ?? .red
        self.size = CGFloat.random(in: 4...8)
        self.opacity = Double.random(in: 0.6...1.0)
        self.duration = Double.random(in: 2...3)
    }
}
