// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine
import os.log

/// Application entry point for Provii Wallet on iOS. Manages the top-level window group,
/// environment injection, privacy overlay behaviour, and deep link routing. Also hosts the
/// AppDelegate which performs security checks, SDK initialisation, and wallet instance setup
/// before any credential material is loaded.
@main
struct ProviiWalletApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if SecurityManager.shared.isDeviceCompromised {
                    // MASVS-RESILIENCE: Show restricted screen when device integrity is compromised
                    DeviceCompromisedView()
                        .environmentObject(accessibilityManager)
                        .environmentObject(languageManager)
                } else {
                    RootView()
                        .environmentObject(appState)
                        .environmentObject(accessibilityManager)
                        .environmentObject(languageManager)
                        .withGlobalToast()
                        .accessibleStyle() // Apply global accessibility modifiers
                        .accessibilityLanguage(languageManager.currentLanguage.code) // WCAG 2.2 AA: 3.1.1 Language of Page
                        .onAppear {
                            Task {
                                await appState.initialize()
                            }
                        }
                        .onOpenURL { url in
                            // Deep link validation and routing handled by DeepLinkHandler
                            appState.handleDeepLink(url)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .proviiEnvironmentChanged)) { _ in
                            Task {
                                await appState.handleEnvironmentChange()
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { notification in
                            // Language changed; UI will update automatically via @Published properties
                            #if DEBUG
                            if let languageCode = notification.object as? String {
                                SecureLogger.shared.debug("Language changed to: \(languageCode)", redact: false)
                            }
                            #endif
                        }
                }

                // MASVS-STORAGE: Privacy overlay to prevent app switcher from showing credentials
                if showPrivacyOverlay {
                    PrivacyOverlayView()
                        .ignoresSafeArea()
                        .transition(
                            UIAccessibility.isReduceMotionEnabled
                                ? .opacity
                                : .opacity.animation(.easeInOut(duration: 0.15))
                        )
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            // Rebuilding the ZStack with a new identity causes SwiftUI to
            // destroy and recreate all child views, applying the new locale
            // immediately. @StateObject properties on ProviiWalletApp (appState,
            // languageManager, accessibilityManager) are NOT recreated. They
            // belong to the App struct, not the ZStack.
            .id(languageManager.currentLanguage.code)
        }
    }

    /// Manage privacy overlay based on scene phase transitions.
    /// When the app moves away from active, overlay a privacy screen so the
    /// app switcher snapshot does not expose credential data.
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App returned to foreground; remove privacy overlay
            if UIAccessibility.isReduceMotionEnabled {
                showPrivacyOverlay = false
            } else {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showPrivacyOverlay = false
                }
            }
        case .inactive, .background:
            // App is leaving foreground; show privacy overlay immediately (no animation)
            // so the very next frame captured by the app switcher is already obscured
            showPrivacyOverlay = true
        @unknown default:
            showPrivacyOverlay = true
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        #if DEBUG
        SecureLogger.shared.info("AppDelegate didFinishLaunching", redact: false)
        SecureLogger.shared.info("Environment: \(EnvironmentManager.shared.getCurrentEnvironment)", redact: false)
        SecureLogger.shared.debug("Debug mode enabled", redact: false)
        #endif

        // Initialise EnvironmentManager
        _ = EnvironmentManager.shared

        // register the sandbox credential refresh handler before
        // `didFinishLaunching` returns, per BGTaskScheduler contract.
        SandboxCredentialFetcher.registerBackgroundTask()

        // Initialise AccessibilityManager
        _ = AccessibilityManager.shared

        // CRITICAL: Security checks MUST run BEFORE KeychainBridge initialisation.
        // KeychainBridge accesses the Keychain which may be compromised on a
        // jailbroken device. Performing checks first ensures we detect and respond
        // to threats before any key material is loaded into memory.
        // (MASVS RESILIENCE-1 through RESILIENCE-4)
        performSecurityChecks()

        // Initialise KeychainBridge (after security checks have passed)
        _ = KeychainBridge.shared
        #if DEBUG
        SecureLogger.shared.debug("KeychainBridge initialized", redact: false)
        #endif

        // Set SDK User-Agent
        initialiseSdkUserAgent()

        // NOTE: Wallet instance creation and verifier URL configuration are
        // handled by WalletRepository.initialiseWallet(), called from
        // AppState.initialize(). Do not create a separate ProviiWallet here.

        // Run thread configuration diagnostic
        runThreadDiagnostic()

        return true
    }

    private func initialiseSdkUserAgent() {
        let appInfo = AppInfo(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            platform: "iOS",
            deviceModel: getDeviceModel(),
            osVersion: UIDevice.current.systemVersion
        )

        sdkSetUserAgent(appInfo: appInfo)

        #if DEBUG
        SecureLogger.shared.debug("User-Agent set: ProviiWallet/\(appInfo.version) (iOS \(appInfo.osVersion ?? ""); \(appInfo.deviceModel ?? ""))", redact: false)
        #endif
    }

    private func runThreadDiagnostic() {
        let diagnostic = sdkDiagnoseThreadConfig()
        #if DEBUG
        SecureLogger.shared.debug("Thread Configuration Diagnostic: \(diagnostic)", redact: false)
        #endif

        if diagnostic.contains("NOT WORKING") {
            SecureLogger.shared.warning("Multi-threading is NOT working! Proofs will be slow.", redact: false)
        }
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private func performSecurityChecks() {
        // Use performStartupChecks() which includes ptrace denial before any
        // detection logic. Critical threats (debugger, Frida, integrity) will
        // terminate the process. Jailbreak sets isDeviceCompromised which the
        // UI layer checks to show a restricted screen.
        let isSecure = SecurityManager.shared.performStartupChecks()

        if !isSecure {
            let threats = SecurityManager.shared.detectedThreats
            SecureLogger.shared.warning("Device security compromised - threats detected", redact: false)
            #if DEBUG
            SecureLogger.shared.debug("Detected threats: \(threats)", redact: false)
            #endif
        } else {
            #if DEBUG
            SecureLogger.shared.debug("All security checks passed", redact: false)
            #endif
        }
    }
}

// MARK: - Root View (Enhanced with Accessibility)
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showingSplash = true

    // Onboarding flow states (matching Android)
    @State private var showLanguageOnboarding = false
    @State private var showFullLanguagePicker = false
    @State private var showAccessibilityOnboarding = false
    @State private var showFullAccessibilitySettings = false

    // track the last-observed sandbox state so the environment-
    // changed notification can fire an accessibility announcement only on
    // the production -> sandbox transition. Re-affirmations of the same
    // state (expected during startup and when the handler publishes
    // redundantly) stay silent.
    @State private var lastObservedSandboxState: Bool?

    var body: some View {
        Group {
            if showingSplash {
                ProviiSplashView(onComplete: {
                    withAnimation {
                        showingSplash = false
                    }
                })
                .onAppear {
                    checkOnboardingStatus()
                }
            } else if showLanguageOnboarding {
                // Step 1: Simple language choice (matches Android)
                SimpleLanguageChoiceView(
                    onUseEnglish: {
                        // User chose English; mark language selected and proceed
                        languageManager.markLanguageSelected()
                        withAnimation {
                            showLanguageOnboarding = false
                            showAccessibilityOnboarding = true
                        }
                    },
                    onChangeLanguage: {
                        // User wants to see full language picker
                        withAnimation {
                            showLanguageOnboarding = false
                            showFullLanguagePicker = true
                        }
                    }
                )
                .transition(.opacity)
            } else if showFullLanguagePicker {
                // Step 2 (optional): Full language picker
                LanguageSelectionView(
                    onLanguageSelected: {
                        // Language was selected; proceed to accessibility
                        withAnimation {
                            showFullLanguagePicker = false
                            showAccessibilityOnboarding = true
                        }
                    },
                    showBreadcrumbs: false,
                    isOnboarding: true,
                    onBack: {
                        // Go back to simple language choice
                        withAnimation {
                            showFullLanguagePicker = false
                            showLanguageOnboarding = true
                        }
                    }
                )
                .transition(.opacity)
            } else if showAccessibilityOnboarding {
                // Step 3: Simple accessibility choice (matches Android)
                SimpleAccessibilityChoiceView(
                    onUseDefaults: {
                        // User chose defaults; mark onboarding complete and proceed
                        accessibilityManager.markOnboardingComplete()
                        withAnimation {
                            showAccessibilityOnboarding = false
                        }
                    },
                    onOpenSettings: {
                        // User wants to customise accessibility
                        withAnimation {
                            showAccessibilityOnboarding = false
                            showFullAccessibilitySettings = true
                        }
                    }
                )
                .transition(.opacity)
            } else if showFullAccessibilitySettings {
                // Step 4 (optional): Full accessibility settings
                AccessibilitySettingsView(
                    isOnboarding: true,
                    onComplete: {
                        withAnimation {
                            showFullAccessibilitySettings = false
                        }
                    }
                )
                .transition(.opacity)
            } else {
                MainContentView()
            }
        }
        .background(
            // Add subtle orange tint when in sandbox mode
            EnvironmentManager.shared.isSandboxEnabled ?
                Color.orange.opacity(0.05).ignoresSafeArea() : nil
        )
        .overlay(alignment: .top) {
            if EnvironmentManager.shared.isSandboxEnabled {
                SandboxBanner()
                    .accessibilityLabel(NSLocalizedString("accessibility.app.sandbox_mode.label", comment: "Sandbox mode banner"))
                    .accessibilityLanguage("en")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLanguage(languageManager.currentLanguage.code) // WCAG 2.2 AA: 3.1.1 Language of Page
        // announce the environment switch to VoiceOver on a
        // production -> sandbox transition. The SandboxBanner overlay carries
        // its own `accessibilityLabel`, but the user may already be focused
        // elsewhere (settings, a list item) when the toggle flips. Firing an
        // `UIAccessibility.post(.announcement)` guarantees the user hears the
        // state change regardless of their current focus position. Seed
        // `lastObservedSandboxState` on first delivery to suppress the
        // startup-time notification that Combine replays on subscribe.
        .onAppear {
            if lastObservedSandboxState == nil {
                lastObservedSandboxState = EnvironmentManager.shared.isSandboxEnabled
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .proviiEnvironmentChanged)) { _ in
            let current = EnvironmentManager.shared.isSandboxEnabled
            defer { lastObservedSandboxState = current }
            // Only announce on false -> true. sandbox -> production and
            // redundant sandbox -> sandbox re-affirmations stay silent.
            guard current, lastObservedSandboxState != true else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: LocalizedString.sandboxModeEnabledAnnouncement.localized
            )
        }
    }

    private func checkOnboardingStatus() {
        let hasLanguage = languageManager.hasSelectedLanguage
        let hasAccessibility = accessibilityManager.settings.hasCompletedAccessibilityOnboarding

        if !hasLanguage {
            // Start with language selection
            showLanguageOnboarding = true
        } else if !hasAccessibility {
            // Language done, need accessibility
            showAccessibilityOnboarding = true
        }
        // Otherwise go straight to main content
    }
}

// MARK: - Sandbox Banner (with accessibility)
struct SandboxBanner: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.subheadline.weight(.bold))
                .accessibilityHidden(true)
            Text(NSLocalizedString("app.sandbox_banner.text", comment: "Sandbox mode active banner text"))
                .font(.subheadline.weight(.bold))
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.subheadline.weight(.bold))
                .accessibilityHidden(true)
        }
        .foregroundColor(accessibilityManager.settings.useHighContrast ? .black : .white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(accessibilityManager.settings.useHighContrast ? Color.yellow : Color.orange)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        )
        .padding(.top, 50)
        .scaleEffect(isPulsing ? 1.05 : 1.0)
        .animation(accessibilityManager.settings.reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            if !accessibilityManager.settings.reduceMotion {
                isPulsing = true
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Main Content View (with accessibility)
struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        switch appState.state {
        case .uninitialized:
            AccessibleLoadingView(message: NSLocalizedString("app.main.initializing.message", comment: "Initializing message"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AccessibleColors.background)

        case .needsSetup:
            SetupView(onSetupComplete: {
                Task {
                    await appState.onSetupComplete()
                }
            })

        case .initializationError(let error):
            InitializationErrorView(
                error: error,
                retry: {
                    Task {
                        await appState.initialize()
                    }
                },
                reset: {
                    Task {
                        await appState.resetAndRedownload()
                    }
                }
            )

        case .ready:
            TabBarView()
                .environmentObject(NavigationCoordinator())
        }
    }
}

// MARK: - App State Management
@MainActor
class AppState: ObservableObject {
    enum State {
        case uninitialized
        case needsSetup
        case initializationError(Error)
        case ready
    }

    @Published var state: State = .uninitialized
    @Published var hasCredentials = false
    @Published var isOfficerMode = false
    @Published var isWalletInitialized = false

    private let walletRepository = WalletRepository.shared
    private let yubikeyManager = YubikeyManager.shared
    private var deepLinkToProcess: URL?

    func initialize() async {
        #if DEBUG
        SecureLogger.shared.info("AppState initialize()", redact: false)
        SecureLogger.shared.info("Environment: \(EnvironmentManager.shared.getCurrentEnvironment)", redact: false)
        #endif

        do {
            let hasProvingKey = walletRepository.checkProvingKeyStatus()
            #if DEBUG
            SecureLogger.shared.debug("Proving key available: \(hasProvingKey)", redact: false)
            #endif

            if !hasProvingKey {
                state = .needsSetup
                return
            }

            #if DEBUG
            SecureLogger.shared.debug("Initializing wallet...", redact: false)
            #endif
            try await walletRepository.initialiseWallet()

            isWalletInitialized = true
            state = .ready
            #if DEBUG
            SecureLogger.shared.info("Wallet initialized successfully", redact: false)
            #endif

            await loadCredentials()

            if let url = deepLinkToProcess {
                handleDeepLink(url)
                deepLinkToProcess = nil
            }
        } catch {
            SecureLogger.shared.error("Initialization failed: \(error.localizedDescription)")

            if error.localizedDescription.contains("storage") {
                state = .initializationError(ProviiWalletError.storageError)
            } else {
                state = .initializationError(error)
            }
        }
    }

    func handleEnvironmentChange() async {
        #if DEBUG
        SecureLogger.shared.info("Environment changed to: \(EnvironmentManager.shared.getCurrentEnvironment)", redact: false)
        #endif

        isWalletInitialized = false
        state = .uninitialized

        do {
            try await walletRepository.clearProvingKey()
        } catch {
            SecureLogger.shared.error("Failed to clear proving key: \(error.localizedDescription)")
        }

        await initialize()
    }

    func loadCredentials() async {
        do {
            let credentials = try await walletRepository.listCredentials()
            hasCredentials = !credentials.isEmpty
        } catch {
            SecureLogger.shared.error("Failed to load credentials: \(error.localizedDescription)")
            hasCredentials = false
        }
    }

    func handleDeepLink(_ url: URL) {
        guard isWalletInitialized else {
            deepLinkToProcess = url
            return
        }

        // Route all deep links through DeepLinkHandler (validation, parsing, navigation)
        _ = DeepLinkHandler.shared.handleURL(url)
    }

    func resetAndRedownload() async {
        do {
            try await walletRepository.clearProvingKey()
            isWalletInitialized = false
            state = .needsSetup
        } catch {
            SecureLogger.shared.error("Failed to clear proving key: \(error.localizedDescription)")
        }
    }

    func onSetupComplete() async {
        await initialize()
    }
}

// MARK: - Initialisation Error View (with accessibility)
struct InitializationErrorView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let error: Error
    let retry: () -> Void
    let reset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.title2)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            Text(NSLocalizedString("app.error.initialization.title", comment: "Initialization error title"))
                .font(AccessibleTypography.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text(ErrorHandler.shared.handleError(error).userMessage)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel(String(format: NSLocalizedString("accessibility.app.error_message.label", comment: "Error message for WCAG compliance"), ErrorHandler.shared.handleError(error).userMessage)) // WCAG 2.2 AA: 3.3.1 Error Identification

            VStack(spacing: 12) {
                Button(action: retry) {
                    Text(NSLocalizedString("app.error.retry.button", comment: "Retry button"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())

                Button(action: reset) {
                    Text(NSLocalizedString("app.error.reset_and_redownload.button", comment: "Reset and re-download button"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .foregroundColor(AccessibleColors.error)
            }
            .padding()
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLanguage("en")
    }
}

// MARK: - Accessible Empty State View
struct AccessibleEmptyStateView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @State private var showAccessibilitySettings = false

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case moreOptionsMenu
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AccessibleColors.primary.opacity(0.25),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "person.badge.shield.checkmark")
                        .font(AccessibleTypography.title2)
                        .foregroundColor(AccessibleColors.primary)
                        .accessibilityHidden(true)
                }

                Spacer().frame(height: 32)

                Text(NSLocalizedString("app.empty_state.welcome.title", comment: "Welcome to Provii Wallet title"))
                    .font(AccessibleTypography.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Spacer().frame(height: 12)

                Text(NSLocalizedString("app.empty_state.add_credential.subtitle", comment: "Add your first credential subtitle"))
                    .font(AccessibleTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .padding(.horizontal, 16)

                Spacer().frame(height: 40)

                VStack(spacing: 12) {
                    actionCard(
                        title: NSLocalizedString("app.empty_state.scan_qr.title", comment: "Scan QR code title"),
                        subtitle: NSLocalizedString("app.empty_state.scan_qr.subtitle", comment: "Get credential from authorised issuer"),
                        icon: "qrcode",
                        isPrimary: true
                    ) {
                        if accessibilityManager.settings.enableManualCodeEntry {
                            navigationCoordinator.presentQRScanner(mode: .general) { qrContent in
                                navigationCoordinator.handleScannedQR(qrContent)
                            }
                        } else {
                            navigationCoordinator.presentQRScanner(mode: .general) { qrContent in
                                navigationCoordinator.handleScannedQR(qrContent)
                            }
                        }
                    }

                    if accessibilityManager.settings.enableManualCodeEntry {
                        actionCard(
                            title: NSLocalizedString("app.empty_state.enter_code.title", comment: "Enter code manually title"),
                            subtitle: NSLocalizedString("app.empty_state.enter_code.subtitle", comment: "Type the code instead of scanning"),
                            icon: "keyboard",
                            isPrimary: false
                        ) {
                            // Show manual entry
                        }
                    }

                    actionCard(
                        title: NSLocalizedString("app.empty_state.find_locations.title", comment: "Find locations title"),
                        subtitle: NSLocalizedString("app.empty_state.find_locations.subtitle", comment: "Discover nearby issuers"),
                        icon: "location",
                        isPrimary: false
                    ) {
                        navigationCoordinator.navigateToWhereToGet()
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(24)
        }
        .background(AccessibleColors.background)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showAccessibilitySettings = true
                    } label: {
                        Label(NSLocalizedString("app.toolbar.accessibility.label", comment: "Accessibility menu item"), systemImage: "accessibility")
                    }

                    Button {
                        navigationCoordinator.navigateToSettings()
                    } label: {
                        Label(NSLocalizedString("app.toolbar.settings.label", comment: "Settings menu item"), systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel(NSLocalizedString("accessibility.app.more_options.label", comment: "More options menu"))
                }
                .focused($focusedElement, equals: .moreOptionsMenu)
            }
        }
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
    }

    private func actionCard(title: String, subtitle: String, icon: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isPrimary ? AccessibleColors.primary : Color(uiColor: .secondarySystemFill))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(AccessibleTypography.title3)
                        .foregroundColor(isPrimary ? .white : .primary)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AccessibleTypography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(AccessibleColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AccessibleTypography.subheadline.weight(.semibold))
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 24 : 20)
            .frame(maxWidth: .infinity)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPrimary ?
                        AccessibleColors.primary.opacity(0.15) :
                        AccessibleColors.cardBackground)
                    .overlay(
                        Group {
                            if !isPrimary || accessibilityManager.settings.useHighContrast {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        accessibilityManager.settings.useHighContrast ?
                                        Color.black : Color(uiColor: .separator),
                                        lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
                                    )
                            }
                        }
                    )
                    .shadow(
                        color: Color.black.opacity(isPrimary && !accessibilityManager.settings.reduceTransparency ? 0.08 : 0),
                        radius: 8,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.app.action_card.label", comment: "Action card with title and subtitle"), title, subtitle))
        .accessibilityHint(String(format: NSLocalizedString("accessibility.app.tap_to_action.hint", comment: "Tap to perform action hint"), title.lowercased()))
    }
}

// MARK: - Wallet Error
enum ProviiWalletError: LocalizedError {
    case walletInitializationFailed
    case storageError
    case provingKeyMissing

    var errorDescription: String? {
        switch self {
        case .walletInitializationFailed:
            return NSLocalizedString("app.error.wallet_init_failed.description", comment: "Failed to initialize wallet error message")
        case .storageError:
            return NSLocalizedString("app.error.storage_failed.description", comment: "Storage initialization failed error message")
        case .provingKeyMissing:
            return NSLocalizedString("app.error.proving_key_missing.description", comment: "Proving key not found error message")
        }
    }
}

// MARK: - Privacy Overlay (Background Snapshot Protection)

/// Full-screen overlay shown when the app enters the inactive or background state.
/// Prevents the app switcher from displaying credential data in the snapshot.
/// Uses a solid colour rather than a blur so that no content leaks through,
/// even on devices where blur rendering may expose partial information.
struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                Text(NSLocalizedString(
                    "security.app_locked.title",
                    comment: "Title shown on privacy overlay when app is in background"
                ))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "accessibility.security.app_locked.label",
            comment: "VoiceOver announcement when privacy overlay is shown"
        ))
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Device Compromised View

/// Shown when SecurityManager detects the device is compromised (e.g. jailbroken).
/// Blocks all credential operations and wallet functionality.
struct DeviceCompromisedView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            Text(NSLocalizedString(
                "security.device_compromised.title",
                comment: "Title shown when device integrity check fails"
            ))
                .font(AccessibleTypography.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(NSLocalizedString(
                "security.device_compromised.message",
                comment: "Explanation that the device has been modified and the wallet cannot operate safely"
            ))
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Text(NSLocalizedString(
                "security.device_compromised.hint",
                comment: "Hint to restore device to unmodified state"
            ))
                .font(AccessibleTypography.footnote)
                .foregroundColor(AccessibleColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AccessibleColors.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}
