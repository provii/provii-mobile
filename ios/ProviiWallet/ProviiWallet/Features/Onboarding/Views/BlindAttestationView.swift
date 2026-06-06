// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Handles blind attestation deep links for secure credential issuance.
///
/// Implements the client-side blind issuance protocol: decode the Ed25519 signed
/// attestation from the issuer, generate r_bits locally so the user controls
/// randomness, send attestation plus r_bits to Provii, receive and verify the
/// signed credential header, then finalise the credential.
///
/// MASVS-CRYPTO-2: Uses cryptographically secure random generation.
/// MASVS-PLATFORM-3: Validates deep link data before processing.
struct BlindAttestationView: View {
    @StateObject private var walletRepository = WalletRepository.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    let attestationData: String

    // State management
    @State private var state: AttestationState = .loading
    @State private var progressMessage = ""
    @State private var currentStep: ProcessingStep = .decoding
    @State private var progressPercentage: Double = 0
    @State private var errorMessage: String?
    @State private var errorDetails: ErrorDetails?
    @State private var retryCount = 0

    // Credential type selection
    @State private var credentialType: String = "primary"
    @State private var childNickname: String = ""
    @State private var showSlotFullAlert = false

    // Parsed attestation info (for display)
    @State private var issuerId: String?
    @State private var attestationTimestamp: Date?

    // Accessibility
    @State private var lastAnnouncedMessage: String?

    private let maxRetries = 3

    enum AttestationState: Equatable {
        case loading
        case confirmingAttestation
        case choosingType
        case enteringNickname
        case processing
        case success
        case error
    }

    enum ProcessingStep: CaseIterable {
        case decoding
        case generating
        case sending
        case verifying
        case storing
        case complete

        var localizedName: String {
            switch self {
            case .decoding:
                return NSLocalizedString("attestation.step.decoding", comment: "Decoding attestation")
            case .generating:
                return NSLocalizedString("attestation.step.generating", comment: "Generating randomness")
            case .sending:
                return NSLocalizedString("attestation.step.sending", comment: "Sending to issuer")
            case .verifying:
                return NSLocalizedString("attestation.step.verifying", comment: "Verifying commitment")
            case .storing:
                return NSLocalizedString("attestation.step.storing", comment: "Storing securely")
            case .complete:
                return NSLocalizedString("attestation.step.complete", comment: "Complete")
            }
        }

        var icon: String {
            switch self {
            case .decoding: return "doc.text.magnifyingglass"
            case .generating: return "dice"
            case .sending: return "arrow.up.circle"
            case .verifying: return "checkmark.shield"
            case .storing: return "internaldrive"
            case .complete: return "checkmark.circle"
            }
        }
    }

    struct ErrorDetails {
        let title: String
        let message: String
        let suggestion: String?
        let canRetry: Bool
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
        .navigationTitle(String(localized: "Receive Credential"))
        .navigationBarBackButtonHidden(state == .processing)
        .toolbar {
            toolbarContent
        }
        .task {
            await decodeAttestation()
        }
        .onAppear {
            setupAccessibility()
        }
        .alert(
            NSLocalizedString("attestation.slots_full.title", comment: "Managed Slots Full alert title"),
            isPresented: $showSlotFullAlert
        ) {
            Button(NSLocalizedString("attestation.slots_full.ok", comment: "OK"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("attestation.slots_full.message", comment: "You have reached the maximum of 5 managed credentials. Delete one to add another."))
        }
    }

    // MARK: - Header

    private var accessibleHeaderView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if state == .processing {
                    if !accessibilityManager.settings.reduceMotion {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(AccessibleColors.primary)
                    }
                }

                Text(stateTitle)
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)
            }

            if accessibilityManager.settings.verboseDescriptions && state == .processing {
                Text(stateSubtitle)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .background(stateBackgroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.attestation.state_title_subtitle.label", comment: "%@. %@"), stateTitle, stateSubtitle))
        .accessibilityAddTraits(state == .processing ? .updatesFrequently : [])
    }

    // MARK: - Content

    @ViewBuilder
    private var accessibleContentView: some View {
        switch state {
        case .loading:
            loadingView
        case .confirmingAttestation:
            confirmationView
        case .choosingType:
            credentialTypeChoiceView
        case .enteringNickname:
            nicknameEntryView
        case .processing:
            processingView
        case .success:
            successView
        case .error:
            errorView
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text(NSLocalizedString("attestation.loading", comment: "Loading attestation..."))
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.attestation.loading", comment: "Loading attestation"))
    }

    // MARK: - Confirmation View

    private var confirmationView: some View {
        VStack(spacing: 32) {
            // Privacy icon
            ZStack {
                Circle()
                    .fill(AccessibleColors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(AccessibleTypography.title2)
                    .foregroundColor(AccessibleColors.primary)
            }
            .accessibilityHidden(true)

            // Title
            VStack(spacing: 12) {
                Text(NSLocalizedString("attestation.confirm.title", comment: "Receive Age Credential"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("attestation.confirm.subtitle", comment: "You're about to receive a privacy preserving age credential."))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Issuer info card
            if let issuerId = issuerId {
                issuerInfoCard(issuerId: issuerId)
            }

            // Privacy notice
            privacyNoticeCard

            // Action buttons
            VStack(spacing: 12) {
                Button(action: startBlindIssuance) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text(NSLocalizedString("attestation.confirm.accept", comment: "Accept Credential"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())

                Button(action: { dismiss() }, label: {
                    Text(NSLocalizedString("attestation.confirm.cancel", comment: "Cancel"))
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(AccessibleSecondaryButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func issuerInfoCard(issuerId: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(AccessibleTypography.title3)
                .foregroundColor(AccessibleColors.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("attestation.issuer.label", comment: "Issuer"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)

                Text(formatIssuerId(issuerId))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(.primary)

                if let timestamp = attestationTimestamp {
                    Text(formatTimestamp(timestamp))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(AccessibleTypography.title3)
                .foregroundColor(AccessibleColors.success)
                .accessibilityHidden(true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AccessibleColors.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.attestation.issuer_info.label", comment: "Issuer: %@"), formatIssuerId(issuerId)))
    }

    private var privacyNoticeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(AccessibleTypography.headline)
                .foregroundColor(AccessibleColors.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("attestation.privacy.title", comment: "Privacy Protected"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(.primary)

                Text(NSLocalizedString("attestation.privacy.description", comment: "Your date of birth will be hidden using cryptographic commitments. Only your age can be verified."))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AccessibleColors.success.opacity(0.5), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.attestation.privacy_notice", comment: "Privacy Protected. Your date of birth will be hidden using cryptographic commitments."))
    }

    // MARK: - Credential Type Choice View

    private var credentialTypeChoiceView: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(AccessibleColors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2.fill")
                    .font(AccessibleTypography.title2)
                    .foregroundColor(AccessibleColors.primary)
            }
            .accessibilityHidden(true)

            // Title
            VStack(spacing: 12) {
                Text(NSLocalizedString("attestation.choice.title", comment: "This credential is for..."))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("attestation.choice.subtitle", comment: "Choose who this age credential belongs to."))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Choice buttons
            VStack(spacing: 12) {
                Button(action: selectForMe) {
                    HStack {
                        Image(systemName: "person.fill")
                        Text(NSLocalizedString("attestation.choice.me", comment: "Me"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())

                Button(action: selectForChild) {
                    HStack {
                        Image(systemName: "person.and.background.dotted")
                        Text(NSLocalizedString("attestation.choice.child", comment: "A Child"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Nickname Entry View

    private var nicknameEntryView: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(AccessibleColors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.and.background.dotted")
                    .font(AccessibleTypography.title2)
                    .foregroundColor(AccessibleColors.primary)
            }
            .accessibilityHidden(true)

            // Title
            VStack(spacing: 12) {
                Text(NSLocalizedString("attestation.nickname.title", comment: "Child's Nickname"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("attestation.nickname.subtitle", comment: "Enter a nickname to identify this credential. This is stored only on your device."))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Nickname text field
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("attestation.nickname.label", comment: "Nickname"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)

                TextField(
                    NSLocalizedString("attestation.nickname.placeholder", comment: "e.g. Alex"),
                    text: $childNickname
                )
                .textFieldStyle(.roundedBorder)
                .font(AccessibleTypography.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit {
                    confirmNicknameAndProceed()
                }
                .accessibilityLabel(NSLocalizedString("accessibility.attestation.nickname_field", comment: "Child's nickname"))
                .accessibilityHint(NSLocalizedString("accessibility.attestation.nickname_hint", comment: "Required. Enter a nickname for this child's credential."))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AccessibleColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AccessibleColors.primary.opacity(0.3), lineWidth: 1)
                    )
            )

            // Action buttons
            VStack(spacing: 12) {
                Button(action: confirmNicknameAndProceed) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text(NSLocalizedString("attestation.nickname.continue", comment: "Continue"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
                .disabled(childNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(childNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

                Button(action: { state = .choosingType }, label: {
                    Text(NSLocalizedString("attestation.nickname.back", comment: "Back"))
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(AccessibleSecondaryButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Processing View

    private var processingView: some View {
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
                    Text("\(Int(progressPercentage * 100))\(LocalizedString.percentComplete.localized)")
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                }
            }

            // Progress steps (if verbose)
            if accessibilityManager.settings.verboseDescriptions {
                progressStepsView
            }

            // Wait message
            Text(NSLocalizedString("attestation.processing.wait", comment: "This may take a few seconds..."))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .contain)
        .onChange(of: progressMessage) { _, newMessage in
            announceProgress(newMessage)
        }
    }

    private var progressIndicator: some View {
        Group {
            if accessibilityManager.settings.reduceMotion {
                ZStack {
                    Circle()
                        .fill(AccessibleColors.primary.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: currentStep.icon)
                        .font(AccessibleTypography.title3)
                        .foregroundColor(AccessibleColors.primary)
                }
            } else {
                ZStack {
                    ProgressView()
                        .scaleEffect(2.5)
                        .frame(height: 100)

                    if accessibilityManager.settings.showStepNumbers {
                        Text("\(Int(progressPercentage * 100))%")
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
            ForEach(ProcessingStep.allCases, id: \.self) { step in
                HStack(spacing: 12) {
                    Image(systemName: stepIcon(for: step))
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(stepColor(for: step))
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Text(step.localizedName)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(step == currentStep ? .primary : .secondary)

                    Spacer()

                    if isStepComplete(step) {
                        Image(systemName: "checkmark")
                            .font(AccessibleTypography.caption)
                            .foregroundColor(AccessibleColors.success)
                            .accessibilityLabel(NSLocalizedString("accessibility.attestation.complete", comment: "Complete"))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.attestation.progress_steps_current", comment: "Progress steps. Current: %@"), currentStep.localizedName))
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            // Success icon
            ZStack {
                Circle()
                    .fill(AccessibleColors.success.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(AccessibleTypography.title)
                    .foregroundColor(AccessibleColors.success)
                    .accessibilityHidden(true)
            }
            .accessibleAnimation(state)

            // Success message
            VStack(spacing: 12) {
                Text(NSLocalizedString("attestation.success.title", comment: "Credential Received"))
                    .font(AccessibleTypography.title)
                    .fontWeight(.bold)
                    .foregroundColor(AccessibleColors.success)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(NSLocalizedString("attestation.success.subtitle", comment: "Your privacy preserving age credential has been securely stored."))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Auto-continue or manual button
            if accessibilityManager.settings.timeoutBehavior != .none {
                VStack(spacing: 8) {
                    if !accessibilityManager.settings.reduceMotion {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    Text(LocalizedString.continuing.localized)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            } else {
                Button(action: continueToNext) {
                    Text(LocalizedString.continueButton.localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
                .padding(.top)
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            announceSuccess()
            if accessibilityManager.settings.timeoutBehavior != .none {
                scheduleNavigation()
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.title2)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(errorDetails?.title ?? NSLocalizedString("attestation.error.title", comment: "Failed to Receive Credential"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AccessibleColors.error)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(errorDetails?.message ?? errorMessage ?? NSLocalizedString("attestation.error.unknown", comment: "An error occurred"))
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

            // Action buttons
            VStack(spacing: 12) {
                if errorDetails?.canRetry ?? false && retryCount < maxRetries {
                    Button(action: retryOperation) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(LocalizedString.tryAgain.localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccessiblePrimaryButtonStyle())
                }

                Button(action: { dismiss() }, label: {
                    Text(LocalizedString.goBack.localized)
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(AccessibleSecondaryButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            announceError()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if state != .processing {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }, label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        if accessibilityManager.settings.verboseDescriptions {
                            Text(LocalizedString.back.localized)
                        }
                    }
                })
                .accessibilityLabel(AccessibilityLabels.back)
            }
        }
    }

    // MARK: - State Properties

    private var stateTitle: String {
        switch state {
        case .loading: return NSLocalizedString("attestation.state.loading", comment: "Loading")
        case .confirmingAttestation: return NSLocalizedString("attestation.state.confirm", comment: "Confirm Credential")
        case .choosingType: return NSLocalizedString("attestation.state.choosing", comment: "Credential Recipient")
        case .enteringNickname: return NSLocalizedString("attestation.state.nickname", comment: "Child's Nickname")
        case .processing: return NSLocalizedString("attestation.state.processing", comment: "Receiving Credential")
        case .success: return NSLocalizedString("attestation.state.success", comment: "Success")
        case .error: return NSLocalizedString("attestation.state.error", comment: "Error")
        }
    }

    private var stateSubtitle: String {
        switch state {
        case .loading: return NSLocalizedString("attestation.subtitle.loading", comment: "Decoding attestation...")
        case .confirmingAttestation: return NSLocalizedString("attestation.subtitle.confirm", comment: "Review and accept")
        case .choosingType: return NSLocalizedString("attestation.subtitle.choosing", comment: "Who is this credential for?")
        case .enteringNickname: return NSLocalizedString("attestation.subtitle.nickname", comment: "Enter a nickname for this child")
        case .processing: return NSLocalizedString("attestation.subtitle.processing", comment: "Processing your credential")
        case .success: return NSLocalizedString("attestation.subtitle.success", comment: "Credential received successfully")
        case .error: return NSLocalizedString("attestation.subtitle.error", comment: "Unable to complete")
        }
    }

    private var stateBackgroundColor: Color {
        switch state {
        case .success: return AccessibleColors.success.opacity(0.15)
        case .error: return AccessibleColors.error.opacity(0.15)
        default: return AccessibleColors.cardBackground
        }
    }

    // MARK: - Processing Logic

    private func decodeAttestation() async {
        state = .loading

        do {
            // Decode and parse the attestation
            // In a full implementation, this would use the wallet SDK
            let decoded = try decodeBase64Url(attestationData)

            // Parse JSON to extract issuer info
            if let data = decoded.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                issuerId = json["issuer_id"] as? String
                if let timestamp = json["timestamp"] as? TimeInterval {
                    attestationTimestamp = Date(timeIntervalSince1970: timestamp)
                }
            }

            await MainActor.run {
                state = .confirmingAttestation
            }
        } catch {
            await handleError(error)
        }
    }

    private func startBlindIssuance() {
        state = .choosingType
    }

    private func selectForMe() {
        credentialType = "primary"
        childNickname = ""
        state = .processing
        Task {
            await processBlindIssuance()
        }
    }

    private var managedSlotsFull: Bool {
        if case .hasCredentials(_, let managed) = walletRepository.credentialState {
            return managed.count >= 15
        }
        return false
    }

    private func selectForChild() {
        if managedSlotsFull {
            showSlotFullAlert = true
            return
        }
        credentialType = "managed"
        childNickname = ""
        state = .enteringNickname
    }

    private func confirmNicknameAndProceed() {
        let trimmed = childNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        childNickname = trimmed
        state = .processing
        Task {
            await processBlindIssuance()
        }
    }

    private func processBlindIssuance() async {
        do {
            // Step 1: Decode attestation
            await updateProgress(.decoding, message: NSLocalizedString("attestation.progress.decoding", comment: "Decoding attestation..."), progress: 0.1)
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

            // Step 2: Generate r_bits
            await updateProgress(.generating, message: NSLocalizedString("attestation.progress.generating", comment: "Generating secure randomness..."), progress: 0.3)
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

            // Step 3: Send to Provii
            await updateProgress(.sending, message: NSLocalizedString("attestation.progress.sending", comment: "Sending to issuer..."), progress: 0.5)

            // Call the blind issuance flow
            let nicknameToSend: String? = credentialType == "managed" ? childNickname : nil
            try await walletRepository.processBlindIssuance(
                attestationData: attestationData,
                credentialType: credentialType,
                nickname: nicknameToSend
            )

            // Step 4: Verify commitment
            await updateProgress(.verifying, message: NSLocalizedString("attestation.progress.verifying", comment: "Verifying commitment..."), progress: 0.7)
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

            // Step 5: Store credential
            await updateProgress(.storing, message: NSLocalizedString("attestation.progress.storing", comment: "Storing securely..."), progress: 0.9)
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(0.3) * 1_000_000_000))

            // Complete
            await updateProgress(.complete, message: NSLocalizedString("attestation.progress.complete", comment: "Credential received!"), progress: 1.0)

            await MainActor.run {
                state = .success
                HapticFeedback.notification(.success)
            }

        } catch {
            await handleError(error)
        }
    }

    private func updateProgress(_ step: ProcessingStep, message: String, progress: Double) async {
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
            state = .error
            HapticFeedback.notification(.error)
        }
    }

    private func parseError(_ error: Error) -> ErrorDetails {
        let message = error.localizedDescription.lowercased()

        if message.contains("expired") {
            return ErrorDetails(
                title: NSLocalizedString("attestation.error.expired.title", comment: "Attestation Expired"),
                message: NSLocalizedString("attestation.error.expired.message", comment: "This attestation has expired."),
                suggestion: NSLocalizedString("attestation.error.expired.suggestion", comment: "Please request a new attestation from the issuer."),
                canRetry: false
            )
        } else if message.contains("network") || message.contains("connection") {
            return ErrorDetails(
                title: NSLocalizedString("attestation.error.network.title", comment: "Connection Error"),
                message: NSLocalizedString("attestation.error.network.message", comment: "Unable to connect to the server."),
                suggestion: NSLocalizedString("attestation.error.network.suggestion", comment: "Check your internet connection and try again."),
                canRetry: true
            )
        } else if message.contains("invalid") || message.contains("signature") {
            return ErrorDetails(
                title: NSLocalizedString("attestation.error.invalid.title", comment: "Invalid Attestation"),
                message: NSLocalizedString("attestation.error.invalid.message", comment: "The attestation could not be verified."),
                suggestion: NSLocalizedString("attestation.error.invalid.suggestion", comment: "Please request a new attestation from a trusted issuer."),
                canRetry: false
            )
        } else {
            return ErrorDetails(
                title: NSLocalizedString("attestation.error.generic.title", comment: "Issuance Failed"),
                message: error.localizedDescription,
                suggestion: nil,
                canRetry: retryCount < maxRetries
            )
        }
    }

    // MARK: - Actions

    private func retryOperation() {
        retryCount += 1
        state = .processing
        currentStep = .decoding
        progressPercentage = 0
        errorMessage = nil
        errorDetails = nil

        HapticFeedback.selection()
        announceIfVoiceOver(String(format: LocalizedString.retryingAttemptFormat.localized, retryCount + 1, maxRetries))

        Task {
            await processBlindIssuance()
        }
    }

    private func continueToNext() {
        HapticFeedback.selection()
        navigationCoordinator.push(.credentialSuccess)
    }

    private func scheduleNavigation() {
        Task {
            try await Task.sleep(nanoseconds: UInt64(accessibilityManager.timeoutDuration(2.0) * 1_000_000_000))
            await MainActor.run {
                navigationCoordinator.push(.credentialSuccess)
            }
        }
    }

    // MARK: - Helpers

    private func decodeBase64Url(_ encoded: String) throws -> String {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64) else {
            throw DeepLinkError.invalidBase64
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw DeepLinkError.invalidUTF8
        }

        return string
    }

    private func formatIssuerId(_ issuerId: String) -> String {
        // Format issuer ID for display (e.g., "provii:issuer:dmv-ca" -> "DMV California")
        if issuerId.contains("dmv") {
            return NSLocalizedString("attestation.issuer.dmv", comment: "Department of Motor Vehicles")
        }
        return issuerId.replacingOccurrences(of: "provii:issuer:", with: "").capitalized
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func stepIcon(for step: ProcessingStep) -> String {
        isStepComplete(step) ? "checkmark.circle.fill" : step.icon
    }

    private func stepColor(for step: ProcessingStep) -> Color {
        if isStepComplete(step) {
            return AccessibleColors.success
        } else if step == currentStep {
            return AccessibleColors.primary
        } else {
            return Color.gray600
        }
    }

    private func isStepComplete(_ step: ProcessingStep) -> Bool {
        let steps = ProcessingStep.allCases
        guard let currentIndex = steps.firstIndex(of: currentStep),
              let stepIndex = steps.firstIndex(of: step) else {
            return false
        }
        return stepIndex < currentIndex
    }

    // MARK: - Accessibility

    private func setupAccessibility() {
        if UIAccessibility.isVoiceOverRunning {
            announceIfVoiceOver(NSLocalizedString("accessibility.attestation.starting", comment: "Blind attestation starting"))
        }
    }

    private func announceProgress(_ message: String) {
        guard message != lastAnnouncedMessage else { return }
        lastAnnouncedMessage = message
        announceIfVoiceOver(message)
    }

    private func announceSuccess() {
        let continuation = accessibilityManager.settings.timeoutBehavior == .none ?
            LocalizedString.tapContinueWhenReady.localized :
            LocalizedString.continuingAutomatically.localized
        announceIfVoiceOver("\(NSLocalizedString("attestation.success.announcement", comment: "Credential received successfully.")) \(continuation)")
    }

    private func announceError() {
        let message = errorDetails?.message ?? errorMessage ?? NSLocalizedString("attestation.error.unknown", comment: "An error occurred")
        let retry = errorDetails?.canRetry ?? false && retryCount < maxRetries
        let action = retry ?
            LocalizedString.errorTryAgainOrScan.localized :
            LocalizedString.errorScanOrGoBack.localized
        announceIfVoiceOver("\(LocalizedString.error.localized): \(message). \(action)")
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
