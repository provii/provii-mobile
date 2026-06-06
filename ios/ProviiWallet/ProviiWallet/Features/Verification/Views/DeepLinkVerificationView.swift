// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Deep link verification flow triggered by `provii.app/verify?d=...` URLs.
/// Decodes the challenge data, presents a credential picker when multiple credentials
/// exist, generates the zero knowledge proof, and delivers the result back to the
/// verifier via the optional return URL or in-app confirmation.
struct DeepLinkVerificationView: View {
    @StateObject private var walletRepository = WalletRepository.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let challengeData: String
    var returnURL: String? // Optional return URL for the verifier

    // State management
    @State private var verificationState: VerificationState = .processing
    @State private var progressMessage = ""
    @State private var errorMessage: String?
    @State private var errorDetails: ErrorDetails?
    @State private var currentStep: VerificationStep = .preparing
    @State private var progressPercentage: Double = 0
    @State private var retryCount = 0
    @State private var verifierInfo: VerifierInfo?

    // Credential picker states
    @State private var showCredentialPicker = false
    @State private var pendingChallengeId: String?
    @State private var provableCredentials: [CredentialSuitability] = []

    // Accessibility
    @State private var lastAnnouncedStep: VerificationStep?
    @State private var shouldReturnAutomatically = true

    // Parsed verify_url origin for browser return navigation
    @State private var verifyUrlOrigin: URL?

    private let maxRetries = 2

    enum VerificationStep: CaseIterable {
        case preparing
        case checkingCredential
        case processingChallenge
        case creatingProof
        case submittingProof
        case complete

        var localizedName: String {
            switch self {
            case .preparing:
                return NSLocalizedString("verification.step.preparing", comment: "Preparing verification")
            case .checkingCredential:
                return NSLocalizedString("verification.step.checking_credential", comment: "Checking credential")
            case .processingChallenge:
                return NSLocalizedString("verification.step.processing_challenge", comment: "Processing challenge")
            case .creatingProof:
                return NSLocalizedString("verification.step.creating_proof", comment: "Creating secure proof")
            case .submittingProof:
                return NSLocalizedString("verification.step.submitting_proof", comment: "Submitting proof")
            case .complete:
                return NSLocalizedString("verification.step.complete", comment: "Verification complete")
            }
        }

        var progress: Double {
            let index = Double(VerificationStep.allCases.firstIndex(of: self) ?? 0)
            return index / Double(VerificationStep.allCases.count - 1)
        }

        var icon: String {
            switch self {
            case .preparing: return "gear"
            case .checkingCredential: return "person.text.rectangle"
            case .processingChallenge: return "qrcode"
            case .creatingProof: return "lock.shield"
            case .submittingProof: return "arrow.up.circle"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }

    struct VerifierInfo {
        let name: String
        let domain: String
        let minimumAge: Int?
        let proofDirection: String? // "over_age" or "under_age"

        /// Display text for the age requirement (e.g., "18+" or "Under 18")
        var ageDisplayText: String? {
            guard let age = minimumAge else { return nil }
            if proofDirection == "under_age" {
                return String(format: NSLocalizedString("verification.deeplink.age_display.under", comment: "Under age display"), age)
            }
            return String(format: NSLocalizedString("verification.deeplink.age_display.over", comment: "Age+ display"), age)
        }
    }

    enum AlternativeAction {
        case getCredential
        case scanQR
        case contactSupport
    }

    struct ErrorDetails {
        let title: String
        let message: String
        let suggestion: String?
        let canRetry: Bool
        let alternativeAction: AlternativeAction?
    }

    var body: some View {
        ZStack {
            AccessibleColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                accessibleHeaderView

                ScrollView {
                    accessibleContentView
                        .padding(accessibilityManager.settings.increaseTouchTargets ? 36 : 32)
                }
            }
        }
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of verification challenge data
        .navigationTitle(NSLocalizedString("verification.deeplink.navigation_title", comment: "Age Verification navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
        .setNavigationPath([
            NSLocalizedString("verification.deeplink.breadcrumb.home", comment: "Home breadcrumb"),
            NSLocalizedString("verification.deeplink.breadcrumb.verification", comment: "Verification breadcrumb")
        ])
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showCredentialPicker) {
            deepLinkCredentialPickerSheet
        }
        .task {
            await processVerification()
        }
        .onAppear {
            setupAccessibility()
            parseVerifierInfo()
        }
    }

    // MARK: - Header

    private var accessibleHeaderView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if verificationState == .processing {
                    if !accessibilityManager.settings.reduceMotion {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: currentStep.icon)
                            .foregroundColor(AccessibleColors.primary)
                    }
                }

                Text(verificationState.title)
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)
            }

            if let verifierInfo = verifierInfo, accessibilityManager.settings.verboseDescriptions {
                Text(String(format: NSLocalizedString("verification.deeplink.verifying_for", comment: "Verifying for verifier name"), verifierInfo.name))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .background(verificationState.accessibleBackgroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
        .accessibilityAddTraits(verificationState == .processing ? .updatesFrequently : [])
    }

    private var headerAccessibilityLabel: String {
        var label = verificationState.title
        if let verifierInfo = verifierInfo {
            label += ". " + String(format: NSLocalizedString("verification.deeplink.accessibility.verifying_for", comment: "Accessibility: Verifying for verifier name"), verifierInfo.name)
            if let ageText = verifierInfo.ageDisplayText {
                label += ". " + String(format: NSLocalizedString("verification.deeplink.accessibility.age_requirement", comment: "Accessibility: Age requirement"), ageText)
            }
        }
        return label
    }

    // MARK: - Content Views

    @ViewBuilder
    private var accessibleContentView: some View {
        switch verificationState {
        case .processing:
            accessibleProcessingView
        case .success:
            accessibleSuccessView
        case .error:
            accessibleErrorView
        }
    }

    // MARK: - Processing View

    private var accessibleProcessingView: some View {
        VStack(spacing: 32) {
            // Progress indicator
            progressIndicator

            // Progress message
            VStack(spacing: 12) {
                Text(progressMessage)
                    .font(AccessibleTypography.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.updatesFrequently)

                if accessibilityManager.settings.showStepNumbers {
                    Text(String(format: NSLocalizedString("verification.deeplink.progress.percent_complete", comment: "Percentage complete"), Int(progressPercentage * 100)))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                }

                if accessibilityManager.settings.verboseDescriptions {
                    Text(stepDescription)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Progress steps view
            if !accessibilityManager.settings.simplifiedUI {
                progressStepsView
            }

            // Security indicator
            securityIndicator

            // Wait message
            Text(accessibilityManager.settings.timeoutBehavior == .extended ?
                 NSLocalizedString("verification.deeplink.wait_message.extended", comment: "Extended wait message") :
                 NSLocalizedString("verification.deeplink.wait_message.standard", comment: "Standard wait message"))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Cancel option for extended operations
            if accessibilityManager.settings.confirmBeforeActions {
                Button(action: cancelVerification) {
                    Text(NSLocalizedString("verification.deeplink.cancel_button", comment: "Cancel verification button"))
                        .frame(minWidth: 120)
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: currentStep) { newStep in
            announceStepChange(newStep)
        }
    }

    private var progressIndicator: some View {
        Group {
            if accessibilityManager.settings.reduceMotion {
                // Static icon
                ZStack {
                    Circle()
                        .fill(AccessibleColors.primary.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: currentStep.icon)
                        .font(AccessibleTypography.title3)
                        .foregroundColor(AccessibleColors.primary)
                }
            } else {
                // Animated progress
                ZStack {
                    CircularProgressView(progress: progressPercentage)
                        .frame(width: 100, height: 100)

                    if accessibilityManager.settings.showStepNumbers {
                        Text(String(format: NSLocalizedString("verification.deeplink.progress.percent", comment: "Percentage"), Int(progressPercentage * 100)))
                            .font(AccessibleTypography.headline)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var progressStepsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(VerificationStep.allCases, id: \.self) { step in
                HStack(spacing: 12) {
                    Image(systemName: stepIcon(for: step))
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(stepColor(for: step))
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Text(step.localizedName)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(stepTextColor(for: step))

                    Spacer()

                    if isStepComplete(step) {
                        Image(systemName: "checkmark")
                            .font(AccessibleTypography.caption)
                            .foregroundColor(AccessibleColors.success)
                            .accessibilityLabel(NSLocalizedString("accessibility.deeplinkverification.complete.label", comment: "Accessibility label for completed step checkmark"))
                    }
                }
                .opacity(isStepReached(step) ? 1 : 0.5)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.deeplinkverification.verification_progress.label", comment: "Accessibility label for verification progress showing current step"), currentStep.localizedName))
    }

    private var securityIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("verification.deeplink.security.zkp_title", comment: "Zero Knowledge Proof title"))
                    .font(AccessibleTypography.body)
                    .fontWeight(.medium)

                if accessibilityManager.settings.verboseDescriptions {
                    Text(NSLocalizedString("verification.deeplink.security.zkp_description", comment: "Zero Knowledge Proof description"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AccessibleColors.success, lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.deeplinkverification.zero_knowledge_proof_your_date.label", comment: "Accessibility label explaining zero knowledge proof privacy protection"))
    }

    // MARK: - Success View

    private var accessibleSuccessView: some View {
        VStack(spacing: 24) {
            // Success icon
            ZStack {
                Circle()
                    .fill(AccessibleColors.success.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.shield.fill")
                    .font(AccessibleTypography.title)
                    .foregroundColor(AccessibleColors.success)
                    .accessibilityHidden(true)
            }
            .accessibleAnimation(verificationState)

            // Success message
            VStack(spacing: 12) {
                Text(NSLocalizedString("verification.deeplink.success.title", comment: "Age Verified success title"))
                    .font(AccessibleTypography.title)
                    .fontWeight(.bold)
                    .foregroundColor(AccessibleColors.success)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if let verifierInfo = verifierInfo {
                    Text(String(format: NSLocalizedString("verification.deeplink.success.verified_for", comment: "Verified for verifier name"), verifierInfo.name))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.primary)
                }

                if accessibilityManager.settings.verboseDescriptions {
                    Text(NSLocalizedString("verification.deeplink.success.description", comment: "Success verification description"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Return options
            if isAutoReturnEnabled {
                VStack(spacing: 8) {
                    if !accessibilityManager.settings.reduceMotion {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    Text(NSLocalizedString("verification.deeplink.success.returning", comment: "Returning to browser message"))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: returnToBrowser) {
                        Text(NSLocalizedString("verification.deeplink.success.return_button", comment: "Return to Browser button"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccessiblePrimaryButtonStyle())

                    Text(NSLocalizedString("verification.deeplink.success.return_message", comment: "Tap when ready to return message"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            announceSuccess()
            if isAutoReturnEnabled {
                scheduleReturn()
            }
        }
    }

    // MARK: - Error View

    private var accessibleErrorView: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: "exclamationmark.shield.fill")
                .font(AccessibleTypography.title2)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            // Error message
            VStack(spacing: 12) {
                Text(errorDetails?.title ?? NSLocalizedString("verification.deeplink.error.title", comment: "Verification Failed error title"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AccessibleColors.error)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(errorDetails?.message ?? errorMessage ?? NSLocalizedString("verification.deeplink.error.message", comment: "An error occurred during verification"))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if let suggestion = errorDetails?.suggestion {
                    Text(suggestion)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )
                }
            }

            // Error actions
            errorActionButtons
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            announceError()
        }
    }

    @ViewBuilder
    private var errorActionButtons: some View {
        VStack(spacing: 12) {
            if errorDetails?.canRetry ?? false && retryCount < maxRetries {
                Button(action: retryVerification) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(NSLocalizedString("verification.deeplink.error.try_again", comment: "Try Again button"))
                        if retryCount > 0 {
                            Text(String(format: NSLocalizedString("verification.deeplink.error.retry_count", comment: "Retry count display"), retryCount, maxRetries))
                                .font(AccessibleTypography.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
            }

            if let action = errorDetails?.alternativeAction {
                alternativeActionButton(for: action)
            }

            Button(action: returnToBrowser) {
                Text(NSLocalizedString("verification.deeplink.error.return_button", comment: "Return to Browser button on error"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func alternativeActionButton(for action: AlternativeAction) -> some View {
        switch action {
        case .getCredential:
            Button(action: navigateToGetCredential) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text(NSLocalizedString("verification.deeplink.error.get_credential", comment: "Get a Credential button"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())

        case .scanQR:
            Button(action: navigateToScanQR) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text(NSLocalizedString("verification.deeplink.error.scan_qr", comment: "Scan QR Code button"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())

        case .contactSupport:
            Button(action: contactSupport) {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text(NSLocalizedString("verification.deeplink.error.get_help", comment: "Get Help button"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if verificationState == .error {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: returnToBrowser) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        if accessibilityManager.settings.verboseDescriptions {
                            Text(NSLocalizedString("verification.deeplink.toolbar.back", comment: "Back button in toolbar"))
                        }
                    }
                }
                .accessibilityLabel(NSLocalizedString("accessibility.deeplinkverification.return_to_browser.label", comment: "Accessibility label for button to return to browser"))
            }
        }
    }

    // MARK: - Processing Logic

    private func processVerification() async {
        do {
            #if DEBUG
            SecureLogger.shared.debug("DeepLinkVerification: Starting verification process", redact: false)
            SecureLogger.shared.debug("Challenge data length: \(challengeData.count)", redact: false)
            #endif

            verificationState = .processing

            // Step 1: Preparing
            await updateProgress(.preparing, message: NSLocalizedString("verification.deeplink.process.preparing", comment: "Preparing verification progress message"), progress: 0.1)
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

            // Step 2: Process challenge first (need challengeId for suitability check)
            await updateProgress(.processingChallenge, message: NSLocalizedString("verification.deeplink.process.processing_challenge", comment: "Processing challenge progress message"), progress: 0.3)
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

            let challengeId = try await walletRepository.processVerificationChallenge(challengeData)
            #if DEBUG
            SecureLogger.shared.debug("Challenge processed, ID: \(SecureLogger.shared.redactId(challengeId))", redact: false)
            #endif

            // Step 3: Check credentials with suitability
            await updateProgress(.checkingCredential, message: NSLocalizedString("verification.deeplink.process.checking_credential", comment: "Checking credential progress message"), progress: 0.4)

            let credentials: [CredentialSuitability]
            do {
                credentials = try walletRepository.getProvableCredentialsForChallenge(challengeId: challengeId)
            } catch {
                #if DEBUG
                SecureLogger.shared.debug("Failed to get provable credentials: \(error.localizedDescription)", redact: false)
                #endif
                await handleError(NoCredentialError())
                return
            }

            guard !credentials.isEmpty else {
                #if DEBUG
                SecureLogger.shared.debug("No provable credentials found", redact: false)
                #endif
                await handleError(NoCredentialError())
                return
            }

            if credentials.count == 1 {
                // Single credential: auto-proceed
                #if DEBUG
                SecureLogger.shared.debug("Single credential found, auto-selecting: \(SecureLogger.shared.redactId(credentials[0].id))", redact: false)
                #endif
                try await generateAndSubmitProof(credentialId: credentials[0].id, challengeId: challengeId)
            } else {
                // Multiple credentials: show picker with suitability
                #if DEBUG
                SecureLogger.shared.debug("Multiple credentials found (\(credentials.count)), showing picker", redact: false)
                #endif
                await MainActor.run {
                    provableCredentials = credentials
                    pendingChallengeId = challengeId
                    showCredentialPicker = true
                }
            }

        } catch {
            SecureLogger.shared.error("Unexpected error during verification: \(error.localizedDescription)")
            await handleError(error)
        }
    }

    /// Generates and submits the age proof for a given credential and challenge.
    private func generateAndSubmitProof(credentialId: String, challengeId: String) async throws {
        // Step 4: Create proof
        await updateProgress(.creatingProof, message: NSLocalizedString("verification.deeplink.process.creating_proof", comment: "Creating secure proof progress message"), progress: 0.6)

        let proofJson = try await walletRepository.createAgeProof(
            credentialId: credentialId,
            challengeId: challengeId
        )
        #if DEBUG
        SecureLogger.shared.debug("Proof created, size: \(proofJson.count)", redact: false)
        #endif

        // Step 5: Submit proof
        await updateProgress(.submittingProof, message: NSLocalizedString("verification.deeplink.process.submitting_proof", comment: "Submitting proof progress message"), progress: 0.8)
        try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

        let success = try await walletRepository.submitProof(proofJson)

        if success {
            // Complete
            await updateProgress(.complete, message: NSLocalizedString("verification.deeplink.process.verified_success", comment: "Age verified successfully message"), progress: 1.0)
            #if DEBUG
            SecureLogger.shared.info("Verification successful", redact: false)
            #endif

            await MainActor.run {
                verificationState = .success
                HapticFeedback.notification(.success)
            }
        } else {
            #if DEBUG
            SecureLogger.shared.warning("Verification failed", redact: false)
            #endif
            await handleError(VerificationFailedError())
        }
    }

    /// Called from the credential picker sheet when a credential is selected.
    private func continueProofGeneration(credentialId: String, challengeId: String) {
        pendingChallengeId = nil
        provableCredentials = []

        Task {
            do {
                await MainActor.run {
                    verificationState = .processing
                }
                try await generateAndSubmitProof(credentialId: credentialId, challengeId: challengeId)
            } catch {
                SecureLogger.shared.error("Error during proof generation: \(error.localizedDescription)")
                await handleError(error)
            }
        }
    }

    private func updateProgress(_ step: VerificationStep, message: String, progress: Double) async {
        await MainActor.run {
            currentStep = step
            progressMessage = message
            progressPercentage = progress
        }
    }

    private func handleError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            errorDetails = parseError(error)
            verificationState = .error
            HapticFeedback.notification(.error)
        }
    }

    private func parseError(_ error: Error) -> ErrorDetails {
        if error is NoCredentialError {
            return ErrorDetails(
                title: NSLocalizedString("verification.deeplink.error.no_credential.title", comment: "No Credential Found error title"),
                message: NSLocalizedString("verification.deeplink.error.no_credential.message", comment: "You need an age credential to verify"),
                suggestion: NSLocalizedString("verification.deeplink.error.no_credential.suggestion", comment: "Get a credential from an authorised issuer first"),
                canRetry: false,
                alternativeAction: .getCredential
            )
        } else if error is VerificationFailedError {
            return ErrorDetails(
                title: NSLocalizedString("verification.deeplink.error.failed.title", comment: "Verification Failed error title"),
                message: NSLocalizedString("verification.deeplink.error.failed.message", comment: "Unable to verify age requirement"),
                suggestion: NSLocalizedString("verification.deeplink.error.failed.suggestion", comment: "You may not meet the minimum age requirement"),
                canRetry: true,
                alternativeAction: nil
            )
        } else {
            let message = error.localizedDescription.lowercased()
            if message.contains("network") || message.contains("connection") {
                return ErrorDetails(
                    title: NSLocalizedString("verification.deeplink.error.connection.title", comment: "Connection Error title"),
                    message: NSLocalizedString("verification.deeplink.error.connection.message", comment: "Unable to connect to verifier"),
                    suggestion: NSLocalizedString("verification.deeplink.error.connection.suggestion", comment: "Check your internet connection and try again"),
                    canRetry: true,
                    alternativeAction: nil
                )
            } else {
                return ErrorDetails(
                    title: NSLocalizedString("verification.deeplink.error.generic.title", comment: "Verification Error title"),
                    message: error.localizedDescription,
                    suggestion: nil,
                    canRetry: retryCount < maxRetries,
                    alternativeAction: .contactSupport
                )
            }
        }
    }

    // MARK: - Credential Picker Sheet

    private var deepLinkCredentialPickerSheet: some View {
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
                                        .foregroundColor(.primary)

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
                                        .fill(Color(uiColor: .systemBackground))
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
                    verificationState = .error
                    errorMessage = NSLocalizedString("verification.deeplink.error.cancelled", comment: "Verification cancelled")
                    errorDetails = ErrorDetails(
                        title: NSLocalizedString("verification.deeplink.error.cancelled.title", comment: "Cancelled"),
                        message: NSLocalizedString("verification.deeplink.error.cancelled", comment: "Verification cancelled"),
                        suggestion: nil,
                        canRetry: true,
                        alternativeAction: nil
                    )
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("verification.challenge.credential_picker.cancel", comment: "Cancel credential selection")) {
                        showCredentialPicker = false
                        pendingChallengeId = nil
                        provableCredentials = []
                    }
                    .font(AccessibleTypography.body)
                }
            }
        }
    }

    // MARK: - Actions

    private func retryVerification() {
        retryCount += 1
        verificationState = .processing
        currentStep = .preparing
        progressPercentage = 0
        errorMessage = nil
        errorDetails = nil

        HapticFeedback.selection()
        announceIfVoiceOver(String(format: NSLocalizedString("verification.deeplink.voiceover.retrying", comment: "VoiceOver announcement for retrying verification"), retryCount + 1, maxRetries + 1))

        Task {
            await processVerification()
        }
    }

    private func cancelVerification() {
        HapticFeedback.notification(.warning)
        announceIfVoiceOver(NSLocalizedString("verification.deeplink.voiceover.cancelled", comment: "VoiceOver announcement for verification cancelled"))
        returnToBrowser()
    }

    private func returnToBrowser() {
        #if DEBUG
        SecureLogger.shared.debug("Returning to browser...", redact: false)
        #endif

        // MASVS-STORAGE-1: Mark completion in Keychain, not UserDefaults
        let flagData = Data("true".utf8)
        _ = KeychainBridge.shared.storeSecure(
            key: "verification_completed",
            data: flagData,
            useSecureEnclave: false,
            requireBiometrics: false
        )

        // Dismiss view
        dismiss()

        // Try to switch back to the browser using the verify_url origin,
        // falling back to a provided returnURL if available
        if let origin = verifyUrlOrigin {
            openURL(origin)
        } else if let returnURL = returnURL, let url = URL(string: returnURL) {
            openURL(url)
        }
    }

    private func scheduleReturn() {
        guard isAutoReturnEnabled else { return }

        let delay = accessibilityManager.timeoutDuration(1.5)

        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                if isAutoReturnEnabled {
                    returnToBrowser()
                }
            }
        }
    }

    private func navigateToGetCredential() {
        announceIfVoiceOver(NSLocalizedString("verification.deeplink.voiceover.opening_credential_setup", comment: "VoiceOver announcement for opening credential setup"))

        // Dismiss the current view first
        dismiss()

        // Navigate to the "Where to Get Credentials" screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak navigationCoordinator] in
            navigationCoordinator?.navigateToWhereToGet()
        }
    }

    private func navigateToScanQR() {
        announceIfVoiceOver(NSLocalizedString("verification.deeplink.voiceover.opening_qr_scanner", comment: "VoiceOver announcement for opening QR scanner"))

        // Dismiss the current view first
        dismiss()

        // Present the QR scanner for credential
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak navigationCoordinator] in
            navigationCoordinator?.presentQRScanner(mode: .general) { qrContent in
                navigationCoordinator?.handleScannedQR(qrContent, mode: .general)
            }
        }
    }

    private func contactSupport() {
        // Get app version information
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Build email body with context
        var body = "Please describe your issue:\n\n\n\n"
        body += "---\nApp Information:\n"
        body += "Version: \(appVersion) (Build \(buildNumber))\n"
        body += "Device: \(UIDevice.current.model)\n"
        body += "iOS: \(UIDevice.current.systemVersion)\n"

        if let verifierInfo = verifierInfo {
            body += "\nVerification Context:\n"
            body += "Verifier: \(verifierInfo.name)\n"
            if !verifierInfo.domain.isEmpty {
                body += "Domain: \(verifierInfo.domain)\n"
            }
            if let ageText = verifierInfo.ageDisplayText {
                body += "Age Requirement: \(ageText)\n"
            }
            if let direction = verifierInfo.proofDirection {
                body += "Proof Direction: \(direction)\n"
            }
        }

        if let errorDetails = errorDetails {
            body += "\nError Context:\n"
            body += "Error Type: \(errorDetails.title)\n"
            body += "Error Message: \(errorDetails.message)\n"
            if let suggestion = errorDetails.suggestion {
                body += "Suggestion: \(suggestion)\n"
            }
        } else if let errorMessage = errorMessage {
            body += "\nError: \(errorMessage)\n"
        }

        // URL encode
        let encodedSubject = "Verification%20Issue"
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        // Create mailto URL using AppConstants
        if let mailURL = URL(string: "mailto:\(AppConstants.supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"),
           UIApplication.shared.canOpenURL(mailURL) {
            openURL(mailURL)
            HapticFeedback.selection()
        } else {
            // Fallback: show alert with support email
            navigationCoordinator.showAlert(
                title: NSLocalizedString("verification.deeplink.support.alert_title", comment: "Contact Support alert title"),
                message: String(format: NSLocalizedString("verification.deeplink.support.alert_message", comment: "Contact support alert message with email"), AppConstants.supportEmail),
                primaryButton: .default(Text(NSLocalizedString("verification.deeplink.support.ok", comment: "OK button")))
            )
        }

        announceIfVoiceOver(NSLocalizedString("verification.deeplink.voiceover.opening_support_email", comment: "VoiceOver announcement for opening support email"))
    }

    // MARK: - Helper Methods

    private var isAutoReturnEnabled: Bool {
        shouldReturnAutomatically &&
        accessibilityManager.settings.timeoutBehavior != .none
    }

    private func parseVerifierInfo() {
        // Parse verifier info from challenge data if available
        if let data = challengeData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let proofDirection = json["proof_direction"] as? String
            // Compute display age from cutoff_days if minimum_age not directly provided
            let minimumAge: Int? = json["minimum_age"] as? Int ?? {
                if let cutoffDays = json["cutoff_days"] as? Int {
                    return Int(round(Double(cutoffDays) / 365.2425))
                }
                return nil
            }()

            verifierInfo = VerifierInfo(
                name: json["verifier_name"] as? String ?? NSLocalizedString("verification.deeplink.unknown_verifier", comment: "Unknown Verifier default name"),
                domain: json["domain"] as? String ?? "",
                minimumAge: minimumAge,
                proofDirection: proofDirection
            )

            // Extract verify_url origin (scheme + host) for browser return navigation
            if let verifyUrlString = json["verify_url"] as? String,
               let verifyUrl = URL(string: verifyUrlString),
               let scheme = verifyUrl.scheme,
               let host = verifyUrl.host {
                var originComponents = URLComponents()
                originComponents.scheme = scheme
                originComponents.host = host
                if let port = verifyUrl.port {
                    originComponents.port = port
                }
                verifyUrlOrigin = originComponents.url
            }
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case .preparing:
            return NSLocalizedString("verification.deeplink.step_description.preparing", comment: "Setting up secure verification description")
        case .checkingCredential:
            return NSLocalizedString("verification.deeplink.step_description.checking_credential", comment: "Verifying your credential is valid description")
        case .processingChallenge:
            return NSLocalizedString("verification.deeplink.step_description.processing_challenge", comment: "Reading verification requirements description")
        case .creatingProof:
            return NSLocalizedString("verification.deeplink.step_description.creating_proof", comment: "Generating zero knowledge proof description")
        case .submittingProof:
            return NSLocalizedString("verification.deeplink.step_description.submitting_proof", comment: "Sending proof to verifier description")
        case .complete:
            return NSLocalizedString("verification.deeplink.step_description.complete", comment: "Verification complete description")
        }
    }

    private func stepIcon(for step: VerificationStep) -> String {
        isStepComplete(step) ? "checkmark.circle.fill" : step.icon
    }

    private func stepColor(for step: VerificationStep) -> Color {
        if isStepComplete(step) {
            return AccessibleColors.success
        } else if step == currentStep {
            return AccessibleColors.primary
        } else {
            return Color.gray600  // 7.35:1 contrast on white (WCAG AAA compliant)
        }
    }

    private func stepTextColor(for step: VerificationStep) -> Color {
        if step == currentStep {
            return .primary
        } else if isStepComplete(step) {
            return .secondary
        } else {
            return Color.gray600  // 7.35:1 contrast on white (WCAG AAA compliant)
        }
    }

    private func isStepComplete(_ step: VerificationStep) -> Bool {
        guard let currentIndex = VerificationStep.allCases.firstIndex(of: currentStep),
              let stepIndex = VerificationStep.allCases.firstIndex(of: step) else {
            return false
        }
        return stepIndex < currentIndex
    }

    private func isStepReached(_ step: VerificationStep) -> Bool {
        guard let currentIndex = VerificationStep.allCases.firstIndex(of: currentStep),
              let stepIndex = VerificationStep.allCases.firstIndex(of: step) else {
            return false
        }
        return stepIndex <= currentIndex
    }

    // MARK: - Accessibility Helpers

    private func setupAccessibility() {
        if UIAccessibility.isVoiceOverRunning {
            announceIfVoiceOver(NSLocalizedString("verification.deeplink.voiceover.setup", comment: "VoiceOver announcement for age verification from deep link"))
        }
    }

    private func announceStepChange(_ step: VerificationStep) {
        guard step != lastAnnouncedStep else { return }
        lastAnnouncedStep = step

        HapticFeedback.selection()
        announceIfVoiceOver(step.localizedName)
    }

    private func announceSuccess() {
        var message = NSLocalizedString("verification.deeplink.voiceover.success", comment: "VoiceOver success message")
        if let verifierInfo = verifierInfo {
            message += " " + String(format: NSLocalizedString("verification.deeplink.voiceover.verified_for", comment: "Verified for verifier"), verifierInfo.name)
        }
        message += accessibilityManager.settings.timeoutBehavior == .none ?
            " " + NSLocalizedString("verification.deeplink.voiceover.tap_return", comment: "Tap return to browser when ready") :
            " " + NSLocalizedString("verification.deeplink.voiceover.returning_auto", comment: "Returning to browser automatically")

        announceIfVoiceOver(message)
    }

    private func announceError() {
        let message = errorDetails?.message ?? errorMessage ?? NSLocalizedString("verification.deeplink.error.failed_default", comment: "Verification failed default message")
        let retry = errorDetails?.canRetry ?? false && retryCount < maxRetries
        let retryMessage = retry ? NSLocalizedString("verification.deeplink.voiceover.can_try_again", comment: "You can try again") : NSLocalizedString("verification.deeplink.voiceover.return_to_browser", comment: "Please return to browser")
        announceIfVoiceOver(String(format: NSLocalizedString("verification.deeplink.voiceover.error_format", comment: "Error format with message"), message, retryMessage))
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - Supporting Types

private enum VerificationState {
    case processing
    case success
    case error

    var title: String {
        switch self {
        case .processing: return NSLocalizedString("verification.deeplink.state.processing", comment: "Verifying Age state title")
        case .success: return NSLocalizedString("verification.deeplink.state.success", comment: "Verified state title")
        case .error: return NSLocalizedString("verification.deeplink.state.error", comment: "Verification Failed state title")
        }
    }

    @MainActor
    var accessibleBackgroundColor: Color {
        switch self {
        case .success:
            return AccessibleColors.success.opacity(0.15)
        case .error:
            return AccessibleColors.error.opacity(0.15)
        case .processing:
            return AccessibleColors.cardBackground
        }
    }
}

// Custom error types
struct NoCredentialError: Error {}
struct VerificationFailedError: Error {}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AccessibleColors.primary,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    accessibilityManager.settings.reduceMotion ? nil :
                        .linear(duration: 0.3),
                    value: progress
                )
        }
    }
}
