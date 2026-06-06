// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import Combine

/// Generic repository for loading, saving, and observing `SettingsSection` values. Each section
/// is JSON-serialised into UserDefaults under its `storageKey`. Change notifications are
/// dispatched via Combine publishers so that UI layers can react to settings updates without
/// polling.
///
/// SECURITY (MASVS-001/INV-WM-008): This repository stores only non-sensitive user preferences
/// in UserDefaults (accessibility settings, language, theme, environment selection). No secrets,
/// tokens, credentials, or PII are persisted here. All sensitive data is stored in the Keychain
/// via KeychainService.
public class SettingsRepository {
    /// Shared singleton instance
    public static let shared = SettingsRepository()

    private let logger = SecureLogger.shared
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Generic Settings API

    /// Load settings of a specific type
    public func load<T: SettingsSection>(_ type: T.Type) -> T {
        let key = T.storageKey
        if let data = userDefaults.data(forKey: key) {
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.warning("Failed to decode \(key): \(error.localizedDescription)", redact: false)
            }
        }
        return T.defaultValue
    }

    /// Save settings of a specific type
    public func save<T: SettingsSection>(_ settings: T) {
        let key = T.storageKey
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: key)
            logger.info("Saved settings for \(key)")
            notifyChange(for: T.self)
        } catch {
            logger.error("Failed to save \(key): \(error.localizedDescription)", redact: false)
        }
    }

    // MARK: - Publisher Support

    private var changePublishers: [String: PassthroughSubject<Any, Never>] = [:]

    /// Get a publisher for settings changes
    public func publisher<T: SettingsSection>(for type: T.Type) -> AnyPublisher<T, Never> {
        let key = T.storageKey
        if changePublishers[key] == nil {
            changePublishers[key] = PassthroughSubject<Any, Never>()
        }
        guard let publisher = changePublishers[key] else {
            // Should never happen since we just assigned above
            return Empty<T, Never>().eraseToAnyPublisher()
        }
        return publisher
            .compactMap { $0 as? T }
            .eraseToAnyPublisher()
    }

    /// Notify that settings changed
    public func notifyChange<T: SettingsSection>(for type: T.Type) {
        let key = T.storageKey
        let settings = load(type)
        changePublishers[key]?.send(settings)
    }
}
