// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import os.log

/// Onboarding setup screen that downloads and initialises the proving key required
/// for zero knowledge proof generation. Guides the user through consent, download
/// progress, and initialisation states with accessible status indicators. Handles
/// error recovery with retry and contact-support actions.
struct SetupView: View {
    @StateObject private var walletRepository = WalletRepository.shared
    @State private var hasUserConsented = false
    @State private var hasCheckedForKey = false
    @State private var keyExists = false
    @State private var stuckInCheckingTimeout = false

    let onSetupComplete: () -> Void

    private let logger = Logger(subsystem: "app.provii.wallet", category: "SetupView")

    var body: some View {
        ZStack {
            Color.proviiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // App icon
                    Image(systemName: "qrcode")
                        .font(AccessibleTypography.title2)
                        .foregroundColor(.proviiPrimary)
                        .padding(.top, 40)

                    Text(LocalizedString.welcomeTitle.localized)
                        .font(ProviiTypography.headlineMedium)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    // Main content based on state
                    if !hasCheckedForKey {
                        CheckingStatusView()
                    } else if keyExists {
                        AlreadySetupView()
                    } else {
                        SetupContentView(
                            setupState: walletRepository.setupState,
                            hasUserConsented: $hasUserConsented,
                            stuckInCheckingTimeout: stuckInCheckingTimeout,
                            onRetry: retrySetup
                        )
                    }

                    // Privacy info card (conditional display)
                    if shouldShowPrivacyCard {
                        PrivacyInfoCard()
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(String(localized: "Setup"))
        .task {
            await checkExistingKey()
        }
        .onChange(of: hasUserConsented) { consented in
            if consented {
                Task {
                    await startDownload()
                }
            }
        }
        .onChange(of: walletRepository.setupState) { state in
            handleStateChange(state)
        }
    }

    // MARK: - Helper Views

    private var shouldShowPrivacyCard: Bool {
        guard hasCheckedForKey, !keyExists else { return false }
        switch walletRepository.setupState {
        case .error:
            return false
        case .notStarted:
            return hasUserConsented
        default:
            return true
        }
    }

    // MARK: - Actions

    private func checkExistingKey() async {
        logger.info("Checking for existing proving key...")

        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            let hasKey = walletRepository.checkProvingKeyStatus()

            await MainActor.run {
                keyExists = hasKey
                hasCheckedForKey = true
            }

            if hasKey {
                logger.info("Proving key already exists! Completing setup...")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    onSetupComplete()
                }
            } else {
                logger.info("Proving key not found, download required")
            }
        } catch {
            logger.error("Error checking for proving key: \(error)")
            await MainActor.run {
                hasCheckedForKey = true
                keyExists = false
            }
        }
    }

    private func startDownload() async {
        guard hasUserConsented else { return }

        if case .notStarted = walletRepository.setupState {
            logger.info("User consented, initiating download")

            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                try await walletRepository.downloadProvingKey()
                logger.info("downloadProvingKey() completed successfully")
            } catch {
                logger.error("downloadProvingKey() failed: \(error)")
            }
        }
    }

    private func handleStateChange(_ state: WalletRepository.SetupState) {
        logger.info("State changed to: \(String(describing: state))")

        switch state {
        case .checking:
            // Start timeout monitor
            Task {
                try? await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
                if case .checking = walletRepository.setupState {
                    logger.error("Still stuck in Checking after 20 seconds!")
                    await MainActor.run {
                        stuckInCheckingTimeout = true
                    }
                }
            }

        case .ready:
            logger.info("Ready state reached, setup complete!")
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    onSetupComplete()
                }
            }

        case .downloading(let progress, let downloadedMB, let totalMB):
            logger.info("Download progress: \(Int(progress * 100))% (\(downloadedMB)MB / \(totalMB)MB)")

        case .error(let message, _, _):
            logger.error("Error state: \(message)")

        default:
            break
        }
    }

    private func retrySetup() {
        Task {
            logger.info("Retrying setup...")
            stuckInCheckingTimeout = false
            try? await walletRepository.retryProvingKeyDownload()
        }
    }
}

// MARK: - Sub Views

struct CheckingStatusView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text(LocalizedString.checkingSetupStatus.localized)
                .font(ProviiTypography.bodyLarge)
                .foregroundColor(.gray600)

            ProgressView()
                .scaleEffect(1.2)
        }
        .padding(.vertical, 40)
    }
}

struct AlreadySetupView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(AccessibleTypography.title2)
                .foregroundColor(.proviiPrimary)

            Text(LocalizedString.alreadySetUp.localized)
                .font(ProviiTypography.headlineSmall)
                .foregroundColor(.proviiPrimary)

            Text(LocalizedString.alreadySetUpMessage.localized)
                .font(ProviiTypography.bodyMedium)
                .foregroundColor(.gray600)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

struct SetupContentView: View {
    let setupState: WalletRepository.SetupState
    @Binding var hasUserConsented: Bool
    let stuckInCheckingTimeout: Bool
    let onRetry: () -> Void

    var body: some View {
        switch setupState {
        case .notStarted:
            if !hasUserConsented {
                ConsentView(hasUserConsented: $hasUserConsented)
            } else {
                PreparingView()
            }

        case .checking:
            CheckingView(
                stuckInCheckingTimeout: stuckInCheckingTimeout,
                onRetry: onRetry
            )

        case .downloading(let progress, let downloadedMB, let totalMB):
            DownloadingView(
                progress: progress,
                downloadedMB: downloadedMB,
                totalMB: totalMB
            )

        case .initialising:
            InitializingView()

        case .ready:
            ReadyView()

        case .error(let message, let canRetry, let requiresAction):
            SetupErrorView(
                message: message,
                canRetry: canRetry,
                requiresAction: requiresAction,
                onRetry: onRetry,
                hasUserConsented: $hasUserConsented
            )
        }
    }
}

struct ConsentView: View {
    @Binding var hasUserConsented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(LocalizedString.setupRequired.localized)
                .font(ProviiTypography.titleLarge)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.proviiPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedString.downloadRequired.localized)
                            .font(ProviiTypography.titleMedium)

                        Text(LocalizedString.downloadRequiredMessage.localized)
                            .font(ProviiTypography.bodyMedium)
                            .foregroundColor(.gray600)

                        HStack {
                            Image(systemName: "wifi")
                                .font(AccessibleTypography.subheadline)
                            Text(LocalizedString.wifiRecommended.localized)
                                .font(ProviiTypography.labelLarge)
                        }
                        .foregroundColor(.proviiSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray100)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.proviiPrimaryContainer.opacity(0.5))
            .cornerRadius(12)

            Button(action: { hasUserConsented = true }, label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text(LocalizedString.downloadNow.localized)
                }
            })
            .buttonStyle(ProviiPrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilitySortPriority(2)

            Button(action: openWiFiSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text(LocalizedString.checkWifiSettings.localized)
                }
            }
            .buttonStyle(ProviiSecondaryButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilitySortPriority(1)
        }
    }

    private func openWiFiSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct PreparingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("onboarding.setup.preparing.message", comment: "Preparing secure verification system message"))
                .font(ProviiTypography.bodyLarge)
                .foregroundColor(.gray600)
                .multilineTextAlignment(.center)

            ProgressView()
                .scaleEffect(1.2)
        }
        .padding(.vertical, 40)
    }
}

struct CheckingView: View {
    let stuckInCheckingTimeout: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("onboarding.setup.checking.message", comment: "Checking security components message"))
                .font(ProviiTypography.bodyLarge)
                .foregroundColor(.gray600)
                .multilineTextAlignment(.center)
                .accessibilityLabel(PronunciationGuide.accessiblePhrase(
                    NSLocalizedString("onboarding.setup.checking.message", comment: "Checking security components message"),
                    expandingTerms: ["cryptographic"]))

            ProgressView()
                .scaleEffect(1.2)

            if stuckInCheckingTimeout {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("onboarding.setup.checking.timeout_title", comment: "Taking longer than expected message"))
                            .font(ProviiTypography.labelLarge)
                        Text(NSLocalizedString("onboarding.setup.checking.timeout_description", comment: "Setup might be stuck, try restarting"))
                            .font(ProviiTypography.bodySmall)
                    }
                    .foregroundColor(.proviiError)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)

                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(NSLocalizedString("onboarding.setup.checking.retry_button", comment: "Retry Setup button"))
                        }
                    }
                    .buttonStyle(ProviiPrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct DownloadingView: View {
    let progress: Float
    let downloadedMB: Float
    let totalMB: Float

    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("onboarding.setup.downloading.title", comment: "Downloading security components title"))
                .font(ProviiTypography.bodyLarge)
                .foregroundColor(.gray600)

            VStack(spacing: 16) {
                ProgressView(value: Double(progress))
                    .progressViewStyle(.linear)
                    .frame(height: 8)
                    .scaleEffect(x: 1, y: 2, anchor: .center)

                Text("\(Int(progress * 100))%")
                    .font(ProviiTypography.titleLarge)
                    .foregroundColor(.proviiPrimary)

                Text(String(format: "%.1f MB / %.1f MB", downloadedMB, totalMB))
                    .font(ProviiTypography.bodyMedium)
                    .foregroundColor(.gray600)
            }

            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.proviiPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("onboarding.setup.downloading.info_title", comment: "One-time download label"))
                        .font(ProviiTypography.labelLarge)
                    Text(NSLocalizedString("onboarding.setup.downloading.info_description", comment: "Enables zero knowledge proofs description"))
                        .font(ProviiTypography.bodySmall)
                        .foregroundColor(.gray600)
                        .accessibilityLabel(PronunciationGuide.accessiblePhrase(
                            NSLocalizedString("onboarding.setup.downloading.info_description", comment: "Enables zero knowledge proofs description"),
                            expandingTerms: ["ZKP"]))
                }
            }
            .padding()
            .background(Color.proviiPrimaryContainer.opacity(0.3))
            .cornerRadius(8)
        }
    }
}

struct InitializingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("onboarding.setup.initializing.message", comment: "Initializing security components message"))
                .font(ProviiTypography.bodyLarge)
                .foregroundColor(.gray600)
                .multilineTextAlignment(.center)

            ProgressView()
                .scaleEffect(1.2)
        }
        .padding(.vertical, 40)
    }
}

struct ReadyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(AccessibleTypography.title2)
                .foregroundColor(.proviiPrimary)

            Text(LocalizedString.setupComplete.localized)
                .font(ProviiTypography.headlineSmall)
                .foregroundColor(.proviiPrimary)

            Text(LocalizedString.setupCompleteMessage.localized)
                .font(ProviiTypography.bodyMedium)
                .foregroundColor(.gray600)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

struct SetupErrorView: View {
    let message: String
    let canRetry: Bool
    let requiresAction: WalletRepository.SetupAction?
    let onRetry: () -> Void
    @Binding var hasUserConsented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon)
                .font(AccessibleTypography.title2)
                .foregroundColor(.proviiError)

            Text(errorTitle)
                .font(ProviiTypography.headlineSmall)
                .foregroundColor(.proviiError)

            Text(errorMessage)
                .font(ProviiTypography.bodyMedium)
                .foregroundColor(.gray700)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)

            ErrorActionButtons(
                message: message,
                canRetry: canRetry,
                requiresAction: requiresAction,
                onRetry: onRetry,
                hasUserConsented: $hasUserConsented
            )
        }
    }

    private var errorIcon: String {
        switch requiresAction {
        case .freeStorage:
            return "externaldrive.badge.exclamationmark"
        case .checkNetwork:
            return "wifi.exclamationmark"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private var errorTitle: String {
        if message.lowercased().contains("jvm") {
            return NSLocalizedString("onboarding.setup.error.initialization_title", comment: "Initialization Error title")
        }

        switch requiresAction {
        case .freeStorage:
            return NSLocalizedString("onboarding.setup.error.storage_full_title", comment: "Storage Full error title")
        case .checkNetwork:
            return NSLocalizedString("onboarding.setup.error.connection_title", comment: "Connection Error title")
        default:
            return NSLocalizedString("onboarding.setup.error.setup_failed_title", comment: "Setup Failed error title")
        }
    }

    private var errorMessage: String {
        if message.lowercased().contains("jvm") {
            return NSLocalizedString("onboarding.setup.error.initialization_message", comment: "App needs to restart message")
        }
        return message
    }
}

struct ErrorActionButtons: View {
    let message: String
    let canRetry: Bool
    let requiresAction: WalletRepository.SetupAction?
    let onRetry: () -> Void
    @Binding var hasUserConsented: Bool

    var body: some View {
        VStack(spacing: 12) {
            if message.lowercased().contains("jvm") {
                Button(action: restartSetup) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(NSLocalizedString("onboarding.setup.error.restart_button", comment: "Restart Setup button"))
                    }
                }
                .buttonStyle(ProviiPrimaryButtonStyle())
                .frame(maxWidth: .infinity)

            } else if let action = requiresAction {
                switch action {
                case .freeStorage:
                    Button(action: openStorageSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text(NSLocalizedString("onboarding.setup.error.manage_storage_button", comment: "Manage Storage button"))
                        }
                    }
                    .buttonStyle(ProviiSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Text(NSLocalizedString("onboarding.setup.error.free_storage_message", comment: "Free up storage message"))
                        .font(ProviiTypography.bodySmall)
                        .foregroundColor(.gray600)

                case .checkNetwork:
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(NSLocalizedString("onboarding.setup.error.retry_download_button", comment: "Retry Download button"))
                        }
                    }
                    .buttonStyle(ProviiPrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilitySortPriority(2)

                    Button(action: openWiFiSettings) {
                        HStack {
                            Image(systemName: "wifi")
                            Text(NSLocalizedString("onboarding.setup.error.check_wifi_button", comment: "Check WiFi Settings button"))
                        }
                    }
                    .buttonStyle(ProviiSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilitySortPriority(1)

                default:
                    if canRetry {
                        RetryButton(onRetry: onRetry)
                    }
                }

            } else if canRetry {
                RetryButton(onRetry: {
                    hasUserConsented = true
                    onRetry()
                })
            }
        }
    }

    private func restartSetup() {
        Task {
            hasUserConsented = false
            try? await WalletRepository.shared.retryProvingKeyDownload()
        }
    }

    private func openStorageSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openWiFiSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct RetryButton: View {
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text(NSLocalizedString("onboarding.setup.error.try_again_button", comment: "Try Again button"))
            }
        }
        .buttonStyle(ProviiPrimaryButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

struct PrivacyInfoCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(AccessibleTypography.body)
                .foregroundColor(.proviiPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedString.privacyProtected.localized)
                    .font(ProviiTypography.labelLarge)
                Text(LocalizedString.privacyMessageDetailed.localized)
                    .font(ProviiTypography.bodySmall)
                    .foregroundColor(.gray600)
            }
        }
        .padding()
        .background(Color.gray100)
        .cornerRadius(12)
    }
}
