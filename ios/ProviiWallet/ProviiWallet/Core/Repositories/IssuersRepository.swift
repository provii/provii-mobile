// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import Combine
import SwiftUI

// Fetches, caches, and exposes the issuer registry that lists all known credential issuers.
// The registry is loaded from a CDN endpoint determined by EnvironmentManager, cached in
// UserDefaults for 24 hours per environment, and falls back to a hardcoded registry of
// trusted issuers when the network is unavailable. Also provides URL validation so that
// only URLs belonging to registered issuers are accepted during deep-link processing.
//
// SECURITY (MASVS-001/INV-WM-008): This repository stores only PUBLIC issuer registry
// data in UserDefaults (issuer names, descriptions, URLs, categories). No secrets, tokens,
// credentials, or PII are cached here. Sensitive credential data is stored exclusively in
// the Keychain via KeychainService.

// MARK: - Data Models

struct IssuerRegistry: Codable {
    let version: String
    let lastUpdated: String
    let description: String
    let categories: [IssuerCategory]
    let issuers: [Issuer]
}

struct IssuerCategory: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
}

struct Issuer: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: String
    let category: String
    let status: String
    let brandColor: String?
    let logoUrl: String?
    let verified: Bool
    let instructions: String
    let deepLink: String?
    let website: String
    let minimumAppVersion: String?
    let expectedLaunch: String?
    let platforms: [String]?
    let locations: [Location]?

    var isAvailable: Bool {
        return status == "available"
    }

    var color: Color? {
        guard let brandColor = brandColor,
              brandColor.hasPrefix("#") else { return nil }
        let hex = String(brandColor.dropFirst())
        guard hex.count == 6,
              let rgb = Int(hex, radix: 16) else { return nil }

        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct Location: Codable {
    let name: String
    let address: String
    let hours: String
}

// MARK: - Repository

@MainActor
class IssuersRepository: ObservableObject {
    static let shared = IssuersRepository()

    @Published var registry: IssuerRegistry?
    @Published var isLoading = false
    @Published var error: Error?

    // Get registry URL from EnvironmentManager
    private var registryURL: String {
        EnvironmentManager.shared.issuersRegistry
    }

    private let cacheKey = "cached_issuer_registry"
    private let cacheTimestampKey = "issuer_registry_cache_timestamp"
    private let cacheEnvironmentKey = "issuer_registry_cache_environment"
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    init() {
        // Load cached registry on init
        loadCachedRegistry()

        // Listen for environment changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnvironmentChange),
            name: .proviiEnvironmentChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEnvironmentChange() {
        #if DEBUG
        SecureLogger.shared.debug("IssuersRepository: Environment changed, clearing cache", redact: false)
        #endif
        // Clear cache when environment changes
        clearCache()
        // Reload issuers
        Task {
            _ = await loadIssuers()
        }
    }

    // MARK: - Public Methods

    func loadIssuers() async -> IssuerRegistry {
        // Check cache first
        if let cached = getCachedRegistryIfValid() {
            #if DEBUG
            SecureLogger.shared.debug("IssuersRepository: Using cached registry", redact: false)
            #endif
            registry = cached
            return cached
        }

        // Fetch from network
        do {
            isLoading = true
            defer { isLoading = false }

            let registry = try await fetchRegistry()
            self.registry = registry
            cacheRegistry(registry)
            error = nil

            #if DEBUG
            SecureLogger.shared.debug("Loaded \(registry.issuers.count) issuers from registry", redact: false)
            SecureLogger.shared.debug("Environment: \(EnvironmentManager.shared.getCurrentEnvironment)", redact: false)
            #endif
            return registry

        } catch let fetchError {
            SecureLogger.shared.error("Network fetch failed: \(fetchError.localizedDescription)")
            error = fetchError

            // Return cached version even if expired
            if let cached = registry {
                #if DEBUG
                SecureLogger.shared.warning("Using expired cache due to network failure", redact: false)
                #endif
                return cached
            }

            // Return hardcoded fallback with trusted issuers only
            // This prevents arbitrary issuer URLs from being accepted when offline
            let fallback = getHardcodedFallbackRegistry()
            self.registry = fallback
            return fallback
        }
    }

    func refreshIssuers() async {
        // Force refresh by clearing cache
        clearCache()
        _ = await loadIssuers()
    }

    func getIssuersByCategory(_ categoryId: String) -> [Issuer] {
        return registry?.issuers.filter { $0.category == categoryId } ?? []
    }

    func getAvailableIssuers() -> [Issuer] {
        return registry?.issuers.filter { $0.isAvailable } ?? []
    }

    func getIssuer(by id: String) -> Issuer? {
        return registry?.issuers.first { $0.id == id }
    }

    /// Validate that a URL belongs to a known, trusted issuer in the registry
    func validateIssuerUrl(_ url: String) async -> Bool {
        let normalizedUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let registryData = await loadIssuers()
        return registryData.issuers.contains { issuer in
            let issuerUrl = issuer.website.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            return normalizedUrl.hasPrefix(issuerUrl)
        }
    }

    // MARK: - Private Methods

    private func fetchRegistry() async throws -> IssuerRegistry {
        guard let url = URL(string: registryURL) else {
            throw URLError(.badURL)
        }

        #if DEBUG
        SecureLogger.shared.debug("Fetching registry from URL", redact: false)
        #endif

        var request = URLRequest(url: url)
        request.setValue("ProviiWallet-iOS/2.0", forHTTPHeaderField: "User-Agent")
        request.setValue(LanguageManager.shared.currentLanguage.code, forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }

        return try decoder.decode(IssuerRegistry.self, from: data)
    }

    private func getCachedRegistryIfValid() -> IssuerRegistry? {
        // Check if cache is for current environment
        let cachedEnvironment = UserDefaults.standard.string(forKey: cacheEnvironmentKey)
        if cachedEnvironment != EnvironmentManager.shared.getCurrentEnvironment {
            #if DEBUG
            SecureLogger.shared.debug("Cache is for different environment, invalidating", redact: false)
            #endif
            return nil
        }

        // Check timestamp
        let timestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        guard timestamp > 0 else { return nil }

        let age = Date().timeIntervalSince1970 - timestamp
        guard age < cacheDuration else {
            #if DEBUG
            SecureLogger.shared.debug("Cache expired (age: \(Int(age/3600)) hours)", redact: false)
            #endif
            return nil
        }

        // Load cached data
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }

        do {
            let registry = try decoder.decode(IssuerRegistry.self, from: data)
            #if DEBUG
            SecureLogger.shared.debug("Loaded valid cache (age: \(Int(age/3600)) hours)", redact: false)
            #endif
            return registry
        } catch {
            SecureLogger.shared.error("Failed to decode cached registry: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadCachedRegistry() {
        registry = getCachedRegistryIfValid()
    }

    private func cacheRegistry(_ registry: IssuerRegistry) {
        do {
            let data = try encoder.encode(registry)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
            UserDefaults.standard.set(EnvironmentManager.shared.getCurrentEnvironment, forKey: cacheEnvironmentKey)
            #if DEBUG
            SecureLogger.shared.debug("Registry cached for \(EnvironmentManager.shared.getCurrentEnvironment) environment", redact: false)
            #endif
        } catch {
            SecureLogger.shared.error("Failed to cache registry: \(error.localizedDescription)")
        }
    }

    private func getHardcodedFallbackRegistry() -> IssuerRegistry {
        let environment = EnvironmentManager.shared.getCurrentEnvironment
        if environment == "sandbox" {
            return IssuerRegistry(
                version: "fallback-1.0-sandbox",
                lastUpdated: "2024-01-01",
                description: NSLocalizedString("issuer_fallback_sandbox_description", comment: ""),
                categories: [
                    IssuerCategory(
                        id: "government",
                        name: NSLocalizedString("issuer_fallback_category_government", comment: ""),
                        description: NSLocalizedString("issuer_fallback_category_government_description", comment: "")
                    )
                ],
                issuers: [
                    Issuer(
                        id: "provii-sandbox-issuer",
                        name: NSLocalizedString("issuer_fallback_sandbox_issuer_name", comment: ""),
                        description: NSLocalizedString("issuer_fallback_sandbox_issuer_description", comment: ""),
                        type: "government",
                        category: "government",
                        status: "available",
                        brandColor: "#1E40AF",
                        logoUrl: nil,
                        verified: true,
                        instructions: NSLocalizedString("issuer_fallback_sandbox_issuer_instructions", comment: ""),
                        deepLink: nil,
                        website: "https://sandbox-issuer.provii.app",
                        minimumAppVersion: nil,
                        expectedLaunch: nil,
                        platforms: ["ios", "android"],
                        locations: nil
                    )
                ]
            )
        } else {
            return IssuerRegistry(
                version: "fallback-1.0",
                lastUpdated: "2024-01-01",
                description: NSLocalizedString("issuer_fallback_production_description", comment: ""),
                categories: [
                    IssuerCategory(
                        id: "government",
                        name: NSLocalizedString("issuer_fallback_category_government", comment: ""),
                        description: NSLocalizedString("issuer_fallback_category_government_description", comment: "")
                    )
                ],
                issuers: [
                    Issuer(
                        id: "provii-dmv",
                        name: NSLocalizedString("issuer_fallback_production_issuer_name", comment: ""),
                        description: NSLocalizedString("issuer_fallback_production_issuer_description", comment: ""),
                        type: "government",
                        category: "government",
                        status: "available",
                        brandColor: "#1E40AF",
                        logoUrl: nil,
                        verified: true,
                        instructions: NSLocalizedString("issuer_fallback_production_issuer_instructions", comment: ""),
                        deepLink: nil,
                        website: "https://issuer.provii.app",
                        minimumAppVersion: nil,
                        expectedLaunch: nil,
                        platforms: ["ios", "android"],
                        locations: nil
                    )
                ]
            )
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        UserDefaults.standard.removeObject(forKey: cacheEnvironmentKey)
        #if DEBUG
        SecureLogger.shared.debug("IssuersRepository cache cleared", redact: false)
        #endif
    }

    /// Clears the cached registry from both UserDefaults and memory.
    /// Called during full data wipe (e.g. "Delete My Data") without triggering
    /// a network refetch.
    func clearCacheAndReset() {
        clearCache()
        registry = nil
        error = nil
    }
}
