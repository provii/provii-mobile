// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Centralised environment configuration: API endpoint overrides, sandbox mode, debug flags,
/// feature flags, and network tuning. Conforms to `SettingsSection` for unified persistence
/// via `SettingsRepository`. Computed properties expose the active environment accounting for
/// sandbox state, and helper methods allow safe bulk-reset of overrides and debug flags.
struct EnvironmentSettings: SettingsSection {
    static let storageKey = "environment"
    static let defaultValue = EnvironmentSettings()
    static let schemaVersion = SettingsVersion.v2_0_0

    // MARK: - Environment Configuration

    /// Current environment selection (production, sandbox, staging, development)
    var currentEnvironment: String = "production"

    /// Whether sandbox mode is enabled (shortcut for sandbox environment)
    var isSandboxEnabled: Bool = false

    // MARK: - Debug Flags

    /// Enable debug logging throughout the app
    var debugLoggingEnabled: Bool = false

    /// Enable verbose network logging
    var verboseNetworkLogging: Bool = false

    /// Enable performance monitoring
    var performanceMonitoringEnabled: Bool = false

    /// Show debug overlays in UI
    var showDebugOverlays: Bool = false

    // MARK: - Feature Flags

    /// Enable experimental features
    var experimentalFeaturesEnabled: Bool = false

    /// Enable beta features
    var betaFeaturesEnabled: Bool = false

    // MARK: - API Configuration

    /// Override for issuer API endpoint (nil = use environment default)
    var issuerApiOverride: String?

    /// Override for verifier API endpoint (nil = use environment default)
    var verifierApiOverride: String?

    /// Override for registry endpoint (nil = use environment default)
    var registryOverride: String?

    /// Override for CDN endpoint (nil = use environment default)
    var cdnOverride: String?

    /// Override for config API endpoint (nil = use environment default)
    var configApiOverride: String?

    // MARK: - Network Settings (Added in v2.0.0)

    /// API timeout in seconds
    var apiTimeout: Double = 30.0

    /// Number of retry attempts for failed requests
    var retryAttempts: Int = 3

    /// Whether caching is enabled
    var cacheEnabled: Bool = true

    // MARK: - Developer Settings

    /// Allow self-signed certificates (dangerous, dev only)
    var allowSelfSignedCertificates: Bool = false

    /// Network request timeout in seconds
    var networkTimeout: TimeInterval = 30

    /// Enable mock data for testing
    var useMockData: Bool = false

    // MARK: - Computed Properties

    /// The actual environment to use (considers sandbox flag)
    var activeEnvironment: String {
        return isSandboxEnabled ? "sandbox" : currentEnvironment
    }

    /// Whether any debug features are enabled
    var hasDebugFeaturesEnabled: Bool {
        return debugLoggingEnabled ||
               verboseNetworkLogging ||
               performanceMonitoringEnabled ||
               showDebugOverlays ||
               experimentalFeaturesEnabled ||
               betaFeaturesEnabled
    }

    /// Whether any dangerous overrides are active
    var hasDangerousOverridesActive: Bool {
        return allowSelfSignedCertificates ||
               issuerApiOverride != nil ||
               verifierApiOverride != nil ||
               registryOverride != nil ||
               cdnOverride != nil ||
               configApiOverride != nil
    }

    // MARK: - Helper Methods

    /// Reset all API overrides to environment defaults
    mutating func resetApiOverrides() {
        issuerApiOverride = nil
        verifierApiOverride = nil
        registryOverride = nil
        cdnOverride = nil
        configApiOverride = nil
    }

    /// Reset all debug flags to defaults
    mutating func resetDebugFlags() {
        debugLoggingEnabled = false
        verboseNetworkLogging = false
        performanceMonitoringEnabled = false
        showDebugOverlays = false
        experimentalFeaturesEnabled = false
        betaFeaturesEnabled = false
    }

    /// Reset all security overrides to safe defaults
    mutating func resetSecurityOverrides() {
        allowSelfSignedCertificates = false
    }

    /// Enable sandbox mode
    mutating func enableSandbox() {
        isSandboxEnabled = true
        currentEnvironment = "sandbox"
    }

    /// Disable sandbox mode and return to production
    mutating func disableSandbox() {
        isSandboxEnabled = false
        currentEnvironment = "production"
    }

    /// Switch to a specific environment.
    /// In release builds, only "production" and "sandbox" are accepted.
    /// Any other value is ignored and the environment remains unchanged.
    mutating func switchToEnvironment(_ environment: String) {
        #if DEBUG
        currentEnvironment = environment
        isSandboxEnabled = (environment == "sandbox")
        #else
        let allowed: Set<String> = ["production", "sandbox"]
        guard allowed.contains(environment) else {
            return
        }
        currentEnvironment = environment
        isSandboxEnabled = (environment == "sandbox")
        #endif
    }
}

// MARK: - Environment Type

extension EnvironmentSettings {
    enum EnvironmentType: String, CaseIterable {
        case production
        case sandbox
        #if DEBUG
        case staging
        case development
        #endif

        var displayName: String {
            switch self {
            case .production:
                return "Production"
            case .sandbox:
                return "Sandbox"
            #if DEBUG
            case .staging:
                return "Staging"
            case .development:
                return "Development"
            #endif
            }
        }

        var description: String {
            switch self {
            case .production:
                return "Live production environment"
            case .sandbox:
                return "Testing sandbox environment"
            #if DEBUG
            case .staging:
                return "Pre-production staging environment"
            case .development:
                return "Development environment"
            #endif
            }
        }
    }

    var environmentType: EnvironmentType? {
        return EnvironmentType(rawValue: activeEnvironment)
    }
}
