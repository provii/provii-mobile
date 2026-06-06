// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Protocol that all settings sections must conform to. Provides a unified contract for
/// storage key, default value, and schema version so that `SettingsRepository` can
/// generically load, save, and version-check any settings type. The default extension
/// adds convenience `load(from:)` and `save(to:)` methods.
public protocol SettingsSection: Codable, Equatable {
    /// Unique storage key for this settings section
    static var storageKey: String { get }

    /// Default value for this settings section
    static var defaultValue: Self { get }

    /// Schema version for this settings section.
    /// Used by the migration framework to determine if migration is needed.
    static var schemaVersion: SettingsVersion { get }
}

/// Extension providing common functionality to all settings sections
public extension SettingsSection {
    /// Load settings from storage
    static func load(from repository: SettingsRepository) -> Self {
        return repository.load(Self.self)
    }

    /// Save settings to storage
    func save(to repository: SettingsRepository) {
        repository.save(self)
    }
}

// MARK: - Versioned Settings Wrapper

/// Wrapper that stores settings data along with version information
struct VersionedSettingsWrapper<T: SettingsSection>: Codable {
    let version: SettingsVersion
    let settings: T
    let lastModified: Date

    init(settings: T, version: SettingsVersion, lastModified: Date = Date()) {
        self.settings = settings
        self.version = version
        self.lastModified = lastModified
    }

    enum CodingKeys: String, CodingKey {
        case version
        case settings
        case lastModified
    }
}
