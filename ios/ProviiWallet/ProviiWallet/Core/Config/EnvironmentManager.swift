// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI
import Combine

/// Singleton that manages environment selection (production, sandbox, staging, development) and
/// resolves API endpoint URLs for the active environment. Environment state is persisted in Keychain
/// rather than UserDefaults to prevent tampering, since the selected environment determines which
/// servers the app trusts. Falls back to hardcoded defaults when the bundled JSON config is missing.
class EnvironmentManager: ObservableObject {
    static let shared = EnvironmentManager()

    // SECURITY: Store environment selection in Keychain instead of plain UserDefaults.
    // Environment determines which server is trusted, so it must be tamper-resistant.
    private static let envKeychainKey = "provii_current_environment"
    private static let sandboxKeychainKey = "provii_sandbox_enabled"

    // In-memory cache to avoid repeated Keychain reads per property access.
    // Loaded once at init, updated on every write. Matches Android's EnvironmentManager
    // which caches in a `currentEnv` field after initialize().
    private var _cachedEnvironment: String?
    private var _cachedSandboxEnabled: Bool?

    private var currentEnvironment: String {
        get {
            _cachedEnvironment ?? "production"
        }
        set {
            do {
                try KeychainService.shared.save(key: Self.envKeychainKey, value: newValue, requiresBiometric: false)
            } catch {
                SecureLogger.shared.error("Failed to persist environment to Keychain: \(error.localizedDescription)")
            }
            // Update the in-memory value regardless of whether persistence
            // succeeded. The selected environment must take effect for the
            // current session even if the Keychain write fails (a locked
            // device, or a unit-test host without Keychain access); Keychain
            // persistence is best-effort for surviving relaunch.
            _cachedEnvironment = newValue
        }
    }

    private var sandboxEnabled: Bool {
        get {
            _cachedSandboxEnabled ?? false
        }
        set {
            do {
                try KeychainService.shared.save(key: Self.sandboxKeychainKey, value: newValue ? "true" : "false", requiresBiometric: false)
            } catch {
                SecureLogger.shared.error("Failed to persist sandbox state to Keychain: \(error.localizedDescription)")
            }
            // Update the in-memory value regardless of persistence (see
            // currentEnvironment above for the rationale).
            _cachedSandboxEnabled = newValue
        }
    }

    private var config: [String: Environment] = [:]

    struct Environment: Codable {
        let issuer: IssuerConfig
        let verifier: VerifierConfig
        let registry: RegistryConfig
        let cdn: CDNConfig
        let config: ConfigConfig?
    }

    struct IssuerConfig: Codable {
        let api: String
        let example: String
    }

    struct VerifierConfig: Codable {
        let api: String
        let verify: String
    }

    struct RegistryConfig: Codable {
        let issuers: String
    }

    struct CDNConfig: Codable {
        let provingKey: String
    }

    struct ConfigConfig: Codable {
        let api: String
    }

    private struct ConfigRoot: Codable {
        let environments: [String: Environment]
    }

    // Release builds only trust "production" and "sandbox". Any other value
    // stored in Keychain (e.g. a leftover "staging" entry from a debug install)
    // is silently reset to "production" so no internal endpoint leaks into a
    // distributed binary.
    private static let releaseAllowlist: Set<String> = ["production", "sandbox"]

    private static func sanitiseEnvironment(_ raw: String?) -> String {
        guard let value = raw else { return "production" }
        #if DEBUG
        return value
        #else
        if Self.releaseAllowlist.contains(value) {
            return value
        }
        SecureLogger.shared.warning("Blocked disallowed environment '\(value)' in release build; defaulting to production", redact: false)
        return "production"
        #endif
    }

    private init() {
        // Load environment state from Keychain once at startup, cache in memory.
        let raw = try? KeychainService.shared.getString(key: Self.envKeychainKey)
        _cachedEnvironment = Self.sanitiseEnvironment(raw)
        _cachedSandboxEnabled = (try? KeychainService.shared.getString(key: Self.sandboxKeychainKey)) == "true"
        loadConfiguration()
    }

    private func loadConfiguration() {
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: "api-endpoints", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            SecureLogger.shared.warning("Failed to load api-endpoints.json, using defaults", redact: false)
            #endif
            useDefaults()
            return
        }

        do {
            let decoder = JSONDecoder()
            let configData = try decoder.decode(ConfigRoot.self, from: data)
            self.config = configData.environments
            #if DEBUG
            SecureLogger.shared.debug("Loaded configuration with \(config.count) environments", redact: false)
            #endif
        } catch {
            SecureLogger.shared.error("Failed to parse configuration: \(error.localizedDescription)")
            useDefaults()
        }
    }

    private func useDefaults() {
        // Fallback to hardcoded defaults (must match api-endpoints.json and Android)
        config = [
            "production": Environment(
                issuer: IssuerConfig(
                    api: "https://issuer.provii.app",
                    example: "https://api.issuer.example"
                ),
                verifier: VerifierConfig(
                    api: "https://verify.provii.app",
                    verify: "https://verify.provii.app/v1/verify"
                ),
                registry: RegistryConfig(
                    issuers: "https://cdn.provii.app/v1/issuers.json"
                ),
                cdn: CDNConfig(
                    provingKey: "https://cdn.provii.app"
                ),
                config: nil
            ),
            "sandbox": Environment(
                issuer: IssuerConfig(
                    api: "https://sandbox-issuer.provii.app",
                    example: "https://sandbox-api.issuer.example"
                ),
                verifier: VerifierConfig(
                    api: "https://sandbox-verify.provii.app",
                    verify: "https://sandbox-verify.provii.app/v1/verify"
                ),
                registry: RegistryConfig(
                    issuers: "https://sandbox-cdn.provii.app/v1/issuers.json"
                ),
                cdn: CDNConfig(
                    provingKey: "https://cdn.provii.app"
                ),
                config: ConfigConfig(
                    api: "https://playground.provii.app"
                )
            )
        ]
        #if DEBUG
        config["staging"] = Environment(
            issuer: IssuerConfig(
                api: "https://staging-issuer.provii.app",
                example: "https://staging-api.issuer.example"
            ),
            verifier: VerifierConfig(
                api: "https://staging-verify.provii.app",
                verify: "https://staging-verify.provii.app/v1/verify"
            ),
            registry: RegistryConfig(
                issuers: "https://staging-cdn.provii.app/v1/issuers.json"
            ),
            cdn: CDNConfig(
                provingKey: "https://staging-cdn.provii.app"
            ),
            config: nil
        )
        config["development"] = Environment(
            issuer: IssuerConfig(
                api: "https://dev-issuer.provii.app",
                example: "https://dev-api.issuer.example"
            ),
            verifier: VerifierConfig(
                api: "https://dev-verify.provii.app",
                verify: "https://dev-verify.provii.app/v1/verify"
            ),
            registry: RegistryConfig(
                issuers: "https://dev-cdn.provii.app/v1/issuers.json"
            ),
            cdn: CDNConfig(
                provingKey: "https://dev-cdn.provii.app"
            ),
            config: nil
        )
        #endif
    }

    func enableSandbox(_ enable: Bool) {
        sandboxEnabled = enable
        currentEnvironment = enable ? "sandbox" : "production"

        if enable {
            // bootstrap the per-install credential via App Attest.
            // Runs best-effort; failures surface later when consumers actually
            // try to use the sandbox.
            Task {
                do {
                    await SandboxCredentialFetcher.shared.clearCache()
                    _ = try await SandboxCredentialFetcher.shared.currentCredential()
                } catch {
                    SecureLogger.shared.error("Failed to bootstrap sandbox credential: \(error.localizedDescription)")
                }
            }
        } else {
            Task {
                try? await SandboxCredentialFetcher.shared.revoke()
                do {
                    try await WalletRepository.shared.deleteSandboxCredentials()
                } catch {
                    SecureLogger.shared.error("Failed to delete sandbox credentials during environment switch: \(error.localizedDescription)")
                }
            }
        }

        // Post notification for app to respond
        NotificationCenter.default.post(name: .proviiEnvironmentChanged, object: nil)

        #if DEBUG
        SecureLogger.shared.info("Environment changed to: \(currentEnvironment)", redact: false)
        #endif
    }

    var isSandboxEnabled: Bool {
        return sandboxEnabled
    }

    var issuerApi: String {
        return config[actualEnvironment]?.issuer.api ?? "https://issuer.provii.app"
    }

    var verifierApi: String {
        return config[actualEnvironment]?.verifier.api ?? "https://verify.provii.app"
    }

    var verifierVerifyUrl: String {
        return config[actualEnvironment]?.verifier.verify ?? "https://verify.provii.app/v1/verify"
    }

    var issuersRegistry: String {
        return config[actualEnvironment]?.registry.issuers ?? "https://cdn.provii.app/v1/issuers.json"
    }

    var cdnProvingKey: String {
        return config[actualEnvironment]?.cdn.provingKey ?? "https://cdn.provii.app"
    }

    func getConfigApi() -> String {
        return config[actualEnvironment]?.config?.api ?? "https://playground.provii.app"
    }

    var getCurrentEnvironment: String {
        return actualEnvironment
    }

    private var actualEnvironment: String {
        return sandboxEnabled ? "sandbox" : currentEnvironment
    }
}

extension Notification.Name {
    static let proviiEnvironmentChanged = Notification.Name("proviiEnvironmentChanged")
}
