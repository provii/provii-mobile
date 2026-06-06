// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Semantic version type for settings schemas. Supports comparison, compatibility checks, and
/// string round-tripping. Used by `SettingsSection` to declare schema versions and by
/// `SettingsRepository` to detect when stored data requires migration. Also includes `AnyCodable`,
/// a type-erased Codable wrapper for heterogeneous settings dictionaries.
public struct SettingsVersion: Codable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    /// Current version of the settings schema
    public static let current = SettingsVersion(major: 1, minor: 1, patch: 0)

    /// Initial version
    public static let v1_0_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

    /// Version with added feature settings
    public static let v1_1_0 = SettingsVersion(major: 1, minor: 1, patch: 0)

    /// Version 2.0.0 - New settings architecture
    public static let v2_0_0 = SettingsVersion(major: 2, minor: 0, patch: 0)

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Initialise from a version string like "1.2.3"
    public init?(string: String) {
        let components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }

        self.major = components[0]
        self.minor = components[1]
        self.patch = components.count > 2 ? components[2] : 0
    }

    public var description: String {
        return "\(major).\(minor).\(patch)"
    }

    // MARK: - Comparable

    public static func < (lhs: SettingsVersion, rhs: SettingsVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }

    // MARK: - Version Compatibility

    /// Check if this version is compatible with another version.
    /// Major versions must match, and this version must be >= target.
    public func isCompatible(with target: SettingsVersion) -> Bool {
        guard self.major == target.major else { return false }
        return self >= target
    }

    /// Check if this version requires migration to reach target
    public func requiresMigration(to target: SettingsVersion) -> Bool {
        return self < target
    }

    /// Check if this version is too new (downgrade scenario)
    public func isTooNew(for target: SettingsVersion) -> Bool {
        return self > target
    }
}

/// Represents versioned settings data
public struct VersionedSettings: Codable {
    public let version: SettingsVersion
    public var data: [String: AnyCodable]

    public init(version: SettingsVersion, data: [String: AnyCodable] = [:]) {
        self.version = version
        self.data = data
    }
}

/// Type-erased codable wrapper for heterogeneous settings data
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}
