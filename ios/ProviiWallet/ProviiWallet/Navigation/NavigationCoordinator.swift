// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

#if canImport(ProviiSDK)
import ProviiSDK
#endif

// Coordinates navigation state for the wallet app using NavigationStack path management.
// Handles push, pop, and replace operations for screen destinations, sheet presentation
// for QR scanning and credential picking, deep link routing, alert display, and
// officer mode flow transitions.

// MARK: - Navigation Destinations

enum NavigationDestination: Hashable {
    // Main flow
    case credentialList
    case whereToGetCredentials

    // User onboarding
    case credentialSuccess

    // Deep link screens (app-to-app flows)
    case deepLinkVerification(challengeData: String)
    case deepLinkAttest(attestData: String)

    // Verification - manual QR scanning
    case verificationChallenge

    // Officer mode
    case officerEntry
    case officerDashboard
    case officerIssueDob
    case officerShowAttestation(attestationData: String)

    // Settings
    case settings

    // Detail views
    case credentialDetail(credentialId: String)
}

// MARK: - Sheet Destinations

enum SheetDestination: Identifiable {
    case qrScanner(mode: QRScanMode, completion: (String) -> Void)
    case credentialPicker(credentials: [CredentialInfo], completion: (CredentialInfo) -> Void)
    case loading(message: String)

    enum QRScanMode {
        case verification
        case general
    }

    var id: String {
        switch self {
        case .qrScanner(let mode, _):
            return "qrScanner_\(mode)"
        case .credentialPicker:
            return "credentialPicker"
        case .loading:
            return "loading"
        }
    }
}

// MARK: - Alert Item

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?

    init(title: String,
         message: String,
         primaryButton: Alert.Button = .default(Text(NSLocalizedString("alert.common.ok", comment: "OK button"))),
         secondaryButton: Alert.Button? = nil) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
}

// MARK: - Navigation Coordinator

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var path: [NavigationDestination] = []
    @Published var presentedSheet: SheetDestination?
    @Published var alertItem: AlertItem?
    @Published var isOfficerMode = false
    @Published var hasCredentials = false

    private let walletRepository = WalletRepository.shared
    private let deepLinkHandler = DeepLinkHandler.shared
    private let errorHandler = ErrorHandler.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe deep link changes
        deepLinkHandler.$pendingDeepLink
            .sink { [weak self] deepLink in
                self?.handlePendingDeepLink(deepLink)
            }
            .store(in: &cancellables)

        // Observe sandbox prompt requests from the deep-link handler
        // and surface them through the existing alert mechanism.
        deepLinkHandler.$pendingSandboxPrompt
            .sink { [weak self] prompt in
                self?.handleSandboxPrompt(prompt)
            }
            .store(in: &cancellables)

        // Observe credential state
        walletRepository.$credentialState
            .map { state in
                switch state {
                case .none:
                    return false
                case .hasCredentials:
                    return true
                }
            }
            .assign(to: &$hasCredentials)
    }

    // MARK: - Navigation Methods

    func push(_ destination: NavigationDestination) {
        path.append(destination)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path.removeAll()
    }

    func replace(with destination: NavigationDestination) {
        path = [destination]
    }

    func navigateTo(_ destination: NavigationDestination) {
        // Smart navigation that avoids duplicates
        if path.isEmpty {
            push(destination)
        } else {
            // Check if already at destination
            if let lastDestination = path.last,
               lastDestination == destination {
                return
            }
            push(destination)
        }
    }

    // MARK: - Sheet Presentation

    func presentQRScanner(mode: SheetDestination.QRScanMode = .general,
                          completion: @escaping (String) -> Void) {
        presentedSheet = .qrScanner(mode: mode, completion: completion)
    }

    func presentCredentialPicker(credentials: [CredentialInfo],
                                 completion: @escaping (CredentialInfo) -> Void) {
        presentedSheet = .credentialPicker(credentials: credentials, completion: completion)
    }

    func showLoadingSheet(message: String) {
        presentedSheet = .loading(message: message)
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    // MARK: - Alert Presentation

    func showAlert(title: String, message: String,
                   primaryButton: Alert.Button = .default(Text(NSLocalizedString("alert.common.ok", comment: "OK button"))),
                   secondaryButton: Alert.Button? = nil) {
        alertItem = AlertItem(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
    }

    func showError(_ error: Error) {
        let errorInfo = errorHandler.handleError(error)

        var primaryButton: Alert.Button = .default(Text(NSLocalizedString("alert.common.ok", comment: "OK button")))
        var secondaryButton: Alert.Button?

        if errorInfo.isRetryable {
            primaryButton = .default(Text(errorInfo.actionLabel ?? NSLocalizedString("alert.common.retry", comment: "Retry button")))
            secondaryButton = .cancel()
        }

        alertItem = AlertItem(
            title: NSLocalizedString("alert.error.title", comment: "Error alert title"),
            message: errorInfo.userMessage,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
    }

    // MARK: - Deep Link Handling

    private func handlePendingDeepLink(_ deepLink: DeepLinkHandler.DeepLink?) {
        guard let deepLink = deepLink else { return }

        switch deepLink {
        case .verification(let challengeData):
            // Navigate to deep link verification screen
            push(.deepLinkVerification(challengeData: challengeData))

        case .attest(let attestData):
            // Navigate to blind attestation screen
            push(.deepLinkAttest(attestData: attestData))
        }

        // Clear the pending deep link
        deepLinkHandler.clearPendingDeepLink()
    }

    /// Present the sandbox confirmation alert for a deep-link. Two triggers
    /// feed this path:
    ///
    /// - URL-level `?env=sandbox` advisory before the challenge is
    ///   decoded.
    /// - decoded challenge payload carries `environment: "sandbox"`
    ///   while the wallet is in production mode.
    ///
    /// The copy differs between the two sources so the user understands
    /// exactly which signal was picked up. In both cases the primary action
    /// enables sandbox and re-dispatches the link; the secondary action drops
    /// the link silently.
    private func handleSandboxPrompt(_ prompt: DeepLinkHandler.SandboxPrompt?) {
        guard let prompt = prompt else { return }

        let title: LocalizedString
        let body: LocalizedString
        let primary: LocalizedString
        let secondary: LocalizedString
        switch prompt.source {
        case .url:
            title = .deeplinkSandboxPromptTitle
            body = .deeplinkSandboxPromptBody
            primary = .deeplinkSandboxPromptPrimary
            secondary = .deeplinkSandboxPromptSecondary
        case .challenge:
            title = .challengeSandboxPromptTitle
            body = .challengeSandboxPromptBody
            primary = .challengeSandboxPromptPrimary
            secondary = .challengeSandboxPromptSecondary
        }

        alertItem = AlertItem(
            title: title.localized,
            message: body.localized,
            primaryButton: .default(
                Text(primary.localized),
                action: { [weak self] in
                    self?.deepLinkHandler.confirmSandboxPrompt()
                }
            ),
            secondaryButton: .cancel(
                Text(secondary.localized),
                action: { [weak self] in
                    self?.deepLinkHandler.dismissSandboxPrompt()
                }
            )
        )
    }

    // MARK: - QR Code Handling

    func handleScannedQR(_ qrContent: String, mode: SheetDestination.QRScanMode = .general) {
        Task {
            do {
                dismissSheet()
                showLoadingSheet(message: LocalizedString.processingQRCode.localized)

                let action = try await walletRepository.processQRCode(qrContent)

                dismissSheet()

                switch action {
                case .verificationChallenge(let challengeJson):
                    handleVerificationChallenge(challengeJson)

                case .attestation(let attestationData):
                    // Navigate to blind attestation flow
                    push(.deepLinkAttest(attestData: attestationData))

                case .unknown:
                    showAlert(title: NSLocalizedString("alert.qr.unknown_title", comment: "Unknown QR code alert title"),
                             message: NSLocalizedString("alert.qr.unknown_message", comment: "QR code not recognised message"))

                case .error(let message):
                    showAlert(title: NSLocalizedString("alert.qr.invalid_title", comment: "Invalid QR code alert title"), message: message)
                }

            } catch {
                dismissSheet()
                showError(error)
            }
        }
    }

    private func handleVerificationChallenge(_ challengeJson: String) {
        // Store the challenge data for the verification screen
        push(.verificationChallenge)

        // The verification screen will handle processing the challenge
    }

    // MARK: - Officer Flow Navigation

    func startOfficerFlow() {
        isOfficerMode = true
        replace(with: .officerEntry)
    }

    func exitOfficerMode() {
        isOfficerMode = false
        replace(with: .credentialList)
    }

    func navigateToOfficerDashboard() {
        if isOfficerMode {
            push(.officerDashboard)
        }
    }

    func startIssuanceFlow() {
        if isOfficerMode {
            push(.officerIssueDob)
        }
    }

    func showOfficerAttestationQR(attestationData: String) {
        if isOfficerMode {
            push(.officerShowAttestation(attestationData: attestationData))
        }
    }

    // MARK: - Credential Navigation

    func showCredentialDetail(credentialId: String) {
        if findStoredCredential(id: credentialId) != nil {
            push(.credentialDetail(credentialId: credentialId))
        } else {
            showAlert(title: NSLocalizedString("alert.credential.not_found_title", comment: "Credential not found alert title"), message: NSLocalizedString("alert.credential.not_found_message", comment: "Credential not located message"))
        }
    }

    /// Look up a StoredCredential by ID from WalletRepository credential state
    func findStoredCredential(id: String) -> StoredCredential? {
        switch walletRepository.credentialState {
        case .none:
            return nil
        case .hasCredentials(let primary, let managed):
            if let primary, primary.id == id {
                return primary
            }
            return managed.first { $0.id == id }
        }
    }

    func navigateToCredentials() {
        if path.isEmpty {
            push(.credentialList)
        } else {
            replace(with: .credentialList)
        }
    }

    func navigateToWhereToGet() {
        push(.whereToGetCredentials)
    }

    func navigateToSettings() {
        push(.settings)
    }

    // MARK: - Onboarding Navigation

    func showCredentialSuccess() {
        // Clear the onboarding flow and show success
        popToRoot()
        push(.credentialSuccess)
    }

    // MARK: - Verification Flow

    func startVerificationScan() {
        presentQRScanner(mode: .verification) { [weak self] qrContent in
            self?.handleScannedQR(qrContent, mode: .verification)
        }
    }

    func performVerification(with credentialId: String, challengeId: String) {
        Task {
            do {
                showLoadingSheet(message: LocalizedString.creatingProof.localized)

                let proof = try await walletRepository.createAgeProof(
                    credentialId: credentialId,
                    challengeId: challengeId
                )

                showLoadingSheet(message: LocalizedString.submittingProof.localized)

                let success = try await walletRepository.submitProof(proof)

                dismissSheet()

                if success {
                    showAlert(
                        title: NSLocalizedString("alert.verification.success_title", comment: "Success alert title"),
                        message: NSLocalizedString("alert.verification.success_message", comment: "Age verification completed successfully message"),
                        primaryButton: .default(Text(NSLocalizedString("alert.verification.done", comment: "Done button"))) { [weak self] in
                            self?.popToRoot()
                        }
                    )
                } else {
                    showAlert(
                        title: NSLocalizedString("alert.verification.failed_title", comment: "Verification failed alert title"),
                        message: NSLocalizedString("alert.verification.failed_message", comment: "Verification not successful message")
                    )
                }

            } catch {
                dismissSheet()
                showError(error)
            }
        }
    }

    // MARK: - Utility

    func getStartDestination() -> NavigationDestination {
        if isOfficerMode {
            return .officerEntry
        } else {
            return .credentialList
        }
    }
}

// MARK: - SwiftUI Integration

struct NavigationCoordinatorView<Content: View>: View {
    @StateObject private var coordinator = NavigationCoordinator()
    let content: (NavigationCoordinator) -> Content

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            content(coordinator)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetView(for: sheet)
        }
        .alert(item: $coordinator.alertItem) { alertItem in
            if let secondary = alertItem.secondaryButton {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    primaryButton: alertItem.primaryButton,
                    secondaryButton: secondary
                )
            } else {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: alertItem.primaryButton
                )
            }
        }
        .environmentObject(coordinator)
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .credentialList:
            CredentialListView()
        case .whereToGetCredentials:
            WhereToGetCredentialsView()
        case .credentialSuccess:
            CredentialSuccessView()
        case .deepLinkVerification(let challengeData):
            DeepLinkVerificationView(challengeData: challengeData)
        case .deepLinkAttest(let attestData):
            BlindAttestationView(attestationData: attestData)
        case .verificationChallenge:
            VerificationChallengeView()
        case .settings:
            SettingsView()
        case .credentialDetail(let credentialId):
            credentialDetailDestination(credentialId: credentialId)
        default:
            officerDestinationView(for: destination)
        }
    }

    @ViewBuilder
    private func officerDestinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .officerEntry:
            OfficerEntryView()
        case .officerDashboard:
            OfficerDashboardView()
        case .officerIssueDob:
            OfficerIssueDobView()
        case .officerShowAttestation(let attestationData):
            OfficerShowAttestationQrView(attestationData: attestationData)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func credentialDetailDestination(credentialId: String) -> some View {
        if let credential = coordinator.findStoredCredential(id: credentialId) {
            CredentialDetailView(credential: credential)
        } else {
            Text(NSLocalizedString("alert.credential.not_found_message", comment: "Credential not located message"))
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: SheetDestination) -> some View {
        switch sheet {
        case .qrScanner(let mode, let completion):
            QRScannerView(mode: mode, completion: completion)

        case .credentialPicker(let credentials, let completion):
            CredentialPickerView(credentials: credentials, completion: completion)

        case .loading(let message):
            LoadingView(message: message)
        }
    }
}

private struct CredentialPickerView: View {
    let credentials: [CredentialInfo]
    let completion: (CredentialInfo) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            listContent
        }
    }

    private var listContent: some View {
        List(credentials, id: \.id) { credential in
            Button {
                completion(credential)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(credential.issuerName)
                        .font(.headline)
                    Text(String(format: LocalizedString.idLabel.localized, credential.id))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(NSLocalizedString("picker.credential.title", comment: "Select credential navigation title"))
    }
}
