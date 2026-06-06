/// Unit tests for SettingsMigrationManager covering v1.0 to v1.1 migration, default values,
/// preservation of existing data, rollback behaviour, error handling, and custom migration registration.
import XCTest
@testable import ProviiWallet

class SettingsMigrationTests: XCTestCase {

    var migrationManager: SettingsMigrationManager!

    override func setUp() {
        super.setUp()
        migrationManager = SettingsMigrationManager()
    }

    override func tearDown() {
        migrationManager = nil
        super.tearDown()
    }

    // MARK: - Migration from v1.0 to v1.1 Tests

    func testMigrationFromV1_0ToV1_1_AddsNewSettings() throws {
        // Given: Settings at v1.0 with only basic data
        let v1_0_data: [String: AnyCodable] = [
            "notificationsEnabled": AnyCodable(true),
            "biometricAuthEnabled": AnyCodable(false)
        ]
        let migration = MigrationV1_0_ToV1_1()

        // When: Migrating to v1.1
        let migrated = try migration.migrate(data: v1_0_data)

        // Then: New accessibility settings should be added
        XCTAssertNotNil(migrated["reduceMotion"])
        XCTAssertNotNil(migrated["preferredFontSize"])
        XCTAssertNotNil(migrated["highContrastMode"])
        XCTAssertNotNil(migrated["colorBlindMode"])

        // Original settings should be preserved
        XCTAssertEqual(migrated["notificationsEnabled"]?.value as? Bool, true)
        XCTAssertEqual(migrated["biometricAuthEnabled"]?.value as? Bool, false)
    }

    func testMigrationFromV1_0ToV1_1_DefaultValues() throws {
        // Given: Empty settings data
        let emptyData: [String: AnyCodable] = [:]
        let migration = MigrationV1_0_ToV1_1()

        // When: Migrating to v1.1
        let migrated = try migration.migrate(data: emptyData)

        // Then: Default values should be set
        XCTAssertEqual(migrated["reduceMotion"]?.value as? Bool, false)
        XCTAssertEqual(migrated["preferredFontSize"]?.value as? String, "medium")
        XCTAssertEqual(migrated["highContrastMode"]?.value as? Bool, false)
        XCTAssertEqual(migrated["colorBlindMode"]?.value as? String, "none")
    }

    func testMigrationFromV1_0ToV1_1_PreservesExistingValues() throws {
        // Given: Settings already have some v1.1 values (partial upgrade scenario)
        let partialData: [String: AnyCodable] = [
            "notificationsEnabled": AnyCodable(true),
            "reduceMotion": AnyCodable(true) // Already exists
        ]
        let migration = MigrationV1_0_ToV1_1()

        // When: Migrating
        let migrated = try migration.migrate(data: partialData)

        // Then: Existing value should be preserved
        XCTAssertEqual(migrated["reduceMotion"]?.value as? Bool, true)

        // Missing values should be added with defaults
        XCTAssertEqual(migrated["preferredFontSize"]?.value as? String, "medium")
    }

    func testMigrationV1_0ToV1_1_VersionIdentity() {
        let migration = MigrationV1_0_ToV1_1()

        XCTAssertEqual(migration.fromVersion, .v1_0_0)
        XCTAssertEqual(migration.toVersion, .v1_1_0)
    }

    // MARK: - Multi-Version Migration Tests

    func testMultiVersionMigration_V1_0ToV1_1() throws {
        // Given: Settings at v1.0
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "theme": AnyCodable("dark")
            ]
        )

        // When: Migrating to v1.1
        let migrated = try migrationManager.migrate(
            versionedSettings: v1_0_settings,
            to: .v1_1_0
        )

        // Then: Version should be updated
        XCTAssertEqual(migrated.version, .v1_1_0)

        // New settings should be added
        XCTAssertNotNil(migrated.data["reduceMotion"])
        XCTAssertNotNil(migrated.data["preferredFontSize"])

        // Original settings should be preserved
        XCTAssertEqual(migrated.data["notificationsEnabled"]?.value as? Bool, true)
        XCTAssertEqual(migrated.data["theme"]?.value as? String, "dark")
    }

    func testMultiVersionMigration_NoMigrationNeeded() throws {
        // Given: Settings already at target version
        let currentSettings = VersionedSettings(
            version: .v1_1_0,
            data: ["test": AnyCodable(true)]
        )

        // When: Attempting to migrate to same version
        let result = try migrationManager.migrate(
            versionedSettings: currentSettings,
            to: .v1_1_0
        )

        // Then: Settings should remain unchanged
        XCTAssertEqual(result.version, currentSettings.version)
        XCTAssertEqual(result.data.count, currentSettings.data.count)
    }

    func testMultiVersionMigration_FindsPath() {
        // Given: Migration manager with registered migrations
        // When: Finding path from v1.0 to v1.1
        let path = migrationManager.findMigrationPath(
            from: .v1_0_0,
            to: .v1_1_0
        )

        // Then: Path should be found
        XCTAssertNotNil(path)
        XCTAssertEqual(path?.count, 1)
        XCTAssertEqual(path?.first?.fromVersion, .v1_0_0)
        XCTAssertEqual(path?.first?.toVersion, .v1_1_0)
    }

    func testMultiVersionMigration_NoPathForSameVersion() {
        // When: Finding path from same version
        let path = migrationManager.findMigrationPath(
            from: .v1_1_0,
            to: .v1_1_0
        )

        // Then: No path should be returned
        XCTAssertNil(path)
    }

    func testMultiVersionMigration_NoPathForDowngrade() {
        // When: Finding path for downgrade (newer to older)
        let path = migrationManager.findMigrationPath(
            from: .v1_1_0,
            to: .v1_0_0
        )

        // Then: No path should be returned
        XCTAssertNil(path)
    }

    // MARK: - Migration with Missing Data Tests

    func testMigrationWithMissingData_EmptySettings() throws {
        // Given: Completely empty settings
        let emptySettings = VersionedSettings(version: .v1_0_0, data: [:])

        // When: Migrating to v1.1
        let migrated = try migrationManager.migrate(
            versionedSettings: emptySettings,
            to: .v1_1_0
        )

        // Then: Migration should succeed with default values
        XCTAssertEqual(migrated.version, .v1_1_0)
        XCTAssertNotNil(migrated.data["reduceMotion"])
        XCTAssertNotNil(migrated.data["preferredFontSize"])
    }

    func testMigrationWithMissingData_PartialSettings() throws {
        // Given: Settings with only some fields
        let partialSettings = VersionedSettings(
            version: .v1_0_0,
            data: ["notificationsEnabled": AnyCodable(true)]
        )

        // When: Migrating
        let migrated = try migrationManager.migrate(
            versionedSettings: partialSettings,
            to: .v1_1_0
        )

        // Then: Existing data should be preserved
        XCTAssertEqual(migrated.data["notificationsEnabled"]?.value as? Bool, true)

        // Missing v1.1 fields should be added
        XCTAssertNotNil(migrated.data["reduceMotion"])
    }

    // MARK: - Migration Rollback Tests

    func testMigrationRollback_V1_1ToV1_0() {
        // Given: Settings at v1.1 with accessibility features
        let v1_1_data: [String: AnyCodable] = [
            "notificationsEnabled": AnyCodable(true),
            "reduceMotion": AnyCodable(true),
            "preferredFontSize": AnyCodable("large"),
            "highContrastMode": AnyCodable(true),
            "colorBlindMode": AnyCodable("deuteranopia")
        ]
        let migration = MigrationV1_0_ToV1_1()

        // When: Rolling back to v1.0
        let rolledBack = migration.rollback(data: v1_1_data)

        // Then: Rollback should succeed
        XCTAssertNotNil(rolledBack)

        // v1.1 specific settings should be removed
        XCTAssertNil(rolledBack?["reduceMotion"])
        XCTAssertNil(rolledBack?["preferredFontSize"])
        XCTAssertNil(rolledBack?["highContrastMode"])
        XCTAssertNil(rolledBack?["colorBlindMode"])

        // v1.0 settings should be preserved
        XCTAssertEqual(rolledBack?["notificationsEnabled"]?.value as? Bool, true)
    }

    func testMigrationRollback_ThroughManager() {
        // Given: Settings at v1.1
        let v1_1_settings = VersionedSettings(
            version: .v1_1_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "reduceMotion": AnyCodable(true)
            ]
        )

        // When: Rolling back to v1.0
        let rolledBack = migrationManager.rollback(
            versionedSettings: v1_1_settings,
            to: .v1_0_0
        )

        // Then: Rollback should succeed
        XCTAssertNotNil(rolledBack)
        XCTAssertEqual(rolledBack?.version, .v1_0_0)
        XCTAssertNil(rolledBack?.data["reduceMotion"])
    }

    func testMigrationRollback_NoRollbackNeeded() {
        // Given: Settings already at target version
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: ["test": AnyCodable(true)]
        )

        // When: Attempting to rollback to same version
        let result = migrationManager.rollback(
            versionedSettings: v1_0_settings,
            to: .v1_0_0
        )

        // Then: Should return original settings
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, v1_0_settings.version)
    }

    // MARK: - Migration Error Handling Tests

    func testMigrationError_IncompatibleVersion() {
        // Given: Settings at v1.1
        let newerSettings = VersionedSettings(
            version: .v1_1_0,
            data: [:]
        )

        // When/Then: Attempting to migrate to older version should throw
        XCTAssertThrowsError(try migrationManager.migrate(
            versionedSettings: newerSettings,
            to: .v1_0_0
        )) { error in
            if case MigrationError.incompatibleVersion = error {
                // Expected error
            } else {
                XCTFail("Expected incompatibleVersion error, got \(error)")
            }
        }
    }

    func testMigrationError_NoMigrationPath() {
        // Given: Settings at v1.0
        let settings = VersionedSettings(
            version: .v1_0_0,
            data: [:]
        )

        // When/Then: Attempting to migrate to non-existent version
        let futureVersion = SettingsVersion(major: 99, minor: 0, patch: 0)

        XCTAssertThrowsError(try migrationManager.migrate(
            versionedSettings: settings,
            to: futureVersion
        )) { error in
            if case MigrationError.migrationNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected migrationNotFound error, got \(error)")
            }
        }
    }

    // MARK: - Custom Migration Tests

    func testCustomMigration_Registration() {
        // Given: A custom migration
        class CustomMigration: SettingsMigration {
            var fromVersion = SettingsVersion(major: 1, minor: 1, patch: 0)
            var toVersion = SettingsVersion(major: 1, minor: 2, patch: 0)

            func migrate(data: [String: AnyCodable]) throws -> [String: AnyCodable] {
                var migrated = data
                migrated["customSetting"] = AnyCodable("added")
                return migrated
            }

            func rollback(data: [String: AnyCodable]) -> [String: AnyCodable]? {
                var rolledBack = data
                rolledBack.removeValue(forKey: "customSetting")
                return rolledBack
            }
        }

        let customMigration = CustomMigration()

        // When: Registering custom migration
        migrationManager.register(migration: customMigration)

        // Then: Migration path should include custom migration
        let path = migrationManager.findMigrationPath(
            from: SettingsVersion(major: 1, minor: 1, patch: 0),
            to: SettingsVersion(major: 1, minor: 2, patch: 0)
        )

        XCTAssertNotNil(path)
        XCTAssertEqual(path?.count, 1)
    }

    // MARK: - Migration Error Descriptions

    func testMigrationError_ErrorDescriptions() {
        let error1 = MigrationError.missingRequiredData("testKey")
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription?.contains("testKey") ?? false)

        let error2 = MigrationError.invalidDataFormat("test format")
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription?.contains("Invalid data format") ?? false)

        let error3 = MigrationError.incompatibleVersion(from: .v1_0_0, to: .v1_1_0)
        XCTAssertNotNil(error3.errorDescription)

        let error4 = MigrationError.migrationNotFound(from: .v1_0_0, to: .v1_1_0)
        XCTAssertNotNil(error4.errorDescription)

        let error5 = MigrationError.rollbackFailed("test reason")
        XCTAssertNotNil(error5.errorDescription)

        struct TestError: Error {}
        let error6 = MigrationError.unknownError(TestError())
        XCTAssertNotNil(error6.errorDescription)
    }
}
