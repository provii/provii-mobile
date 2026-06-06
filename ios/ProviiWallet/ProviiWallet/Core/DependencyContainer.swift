// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Dependency injection container for the iOS wallet app.
///
/// Manages singleton service instances and app lifecycle initialisation,
/// matching Android's `AppModule.kt` pattern. Exposed as an
/// `ObservableObject` for SwiftUI environment injection.

import Foundation
import SwiftUI
import Combine
@MainActor
class DependencyContainer: ObservableObject {

    // MARK: - Singleton
    static let shared = DependencyContainer()

    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var initializationError: Error?

    // MARK: - Services (Lazy initialisation)

    private(set) lazy var walletSDK: WalletSDKBridge = {
        WalletSDKBridge.shared
    }()

    private(set) lazy var keychainService: KeychainService = {
        KeychainService.shared
    }()

    private(set) lazy var biometricService: BiometricService = {
        BiometricService.shared
    }()

    private(set) lazy var networkManager: NetworkManager = {
        NetworkManager.shared
    }()

    private(set) lazy var auditLogger: AuditLogger = {
        AuditLogger.shared
    }()

    private(set) lazy var storageHelper: StorageHelper = {
        StorageHelper.shared
    }()

    private(set) lazy var deepLinkHandler: DeepLinkHandler = {
        DeepLinkHandler.shared
    }()

    // MARK: - Repositories (Lazy initialisation)

    private(set) lazy var walletRepository: WalletRepository = {
        WalletRepository.shared
    }()

    private(set) lazy var issuersRepository: IssuersRepository = {
        IssuersRepository.shared
    }()

    // MARK: - Managers (Lazy initialisation)

    private(set) lazy var officerAuthManager: OfficerAuthManager = {
        OfficerAuthManager.shared
    }()

    private(set) lazy var yubikeyManager: YubikeyManager = {
        YubikeyManager.shared
    }()

    // MARK: - Initialisation

    private init() {
        // Private to enforce singleton
    }

    /**
     * Initialise all dependencies
     * Should be called from ProviiWalletApp on launch
     */
    func initialize() async {
        guard !isInitialized else { return }

        do {
            // Log startup
            auditLogger.logAppEvent(event: "app_startup")

            // Initialize network monitoring
            networkManager.startMonitoring()

            // Initialize wallet SDK
            try await walletSDK.initialize()

            // Load initial data
            await walletRepository.loadCredentials()

            // Mark as initialised
            isInitialized = true

            auditLogger.logAppEvent(event: "app_initialized_successfully")

        } catch {
            SecureLogger.shared.error("Failed to initialise dependencies: \(error.localizedDescription)")
            initializationError = error
            auditLogger.logAppEvent(event: "app_initialization_failed", metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    /**
     * Clean up resources on app termination
     */
    func cleanup() {
        auditLogger.logAppEvent(event: "app_shutdown")

        // Stop network monitoring
        networkManager.stopMonitoring()

        // Clean up SDK
        walletSDK.cleanup()

        // Clear any temporary data
        try? storageHelper.clearTemporaryFiles()

        isInitialized = false
    }

    // MARK: - Environment Object Access

    /**
     * Inject all dependencies into SwiftUI environment
     */
    func injectEnvironment<Content: View>(into view: Content) -> some View {
        view
            .environmentObject(self)
            .environmentObject(walletSDK)
            .environmentObject(walletRepository)
            .environmentObject(officerAuthManager)
            .environmentObject(yubikeyManager)
            .environmentObject(deepLinkHandler)
    }
}

// MARK: - SwiftUI Environment Keys

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - Convenience View Extension

extension View {
    /**
     * Inject dependencies into view hierarchy
     */
    func withDependencies() -> some View {
        DependencyContainer.shared.injectEnvironment(into: self)
    }
}

// MARK: - Feature Flags

/**
 * Feature flag management
 */
class FeatureFlags {
    static let shared = FeatureFlags()

    // Feature flags
    var enableParallelProver: Bool {
        get { UserDefaults.standard.bool(forKey: "feature_parallel_prover") }
        set { UserDefaults.standard.set(newValue, forKey: "feature_parallel_prover") }
    }

    var enableAdvancedLogging: Bool {
        get { UserDefaults.standard.bool(forKey: "feature_advanced_logging") }
        set { UserDefaults.standard.set(newValue, forKey: "feature_advanced_logging") }
    }

    var enableBiometricAuth: Bool {
        get {
            // Default to true
            if !KeychainService.shared.getFeatureBiometricAuthSet() {
                try? KeychainService.shared.saveFeatureBiometricAuth(true)
                try? KeychainService.shared.saveFeatureBiometricAuthSet(true)
            }
            return KeychainService.shared.getFeatureBiometricAuth() ?? true
        }
        set {
            try? KeychainService.shared.saveFeatureBiometricAuth(newValue)
            try? KeychainService.shared.saveFeatureBiometricAuthSet(true)
        }
    }

    var maxProverThreads: UInt8 {
        get {
            let value = UserDefaults.standard.integer(forKey: "feature_max_prover_threads")
            return value > 0 ? UInt8(min(value, 255)) : 2 // Default to 2 threads
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "feature_max_prover_threads") }
    }

    private init() {}

    func resetToDefaults() {
        enableParallelProver = true
        enableAdvancedLogging = false
        enableBiometricAuth = true
        maxProverThreads = 2
    }
}
