/// Tests for SettingsRepository auto-migration on load, data preservation through upgrades,
/// export/import round-trips, persistence verification, concurrent access safety, and edge cases.
import XCTest
@testable import ProviiWallet

class SettingsRepositoryMigrationTests: XCTestCase {

    var repository: SettingsRepository!
    var userDefaults: UserDefaults!
    let suiteName = "app.provii.wallet.tests.settings"

    override func setUp() {
        super.setUp()

        // Create a fresh UserDefaults instance for testing
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)

        repository = SettingsRepository(
            userDefaults: userDefaults,
            migrationManager: SettingsMigrationManager()
        )
    }

    override func tearDown() {
        // Clean up
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        repository = nil

        super.tearDown()
    }

    // MARK: - Auto Migration on Load Tests

    func testAutoMigrationOnLoad_FreshInstall() throws {
        // Given: No existing settings (fresh install)

        // When: Loading settings
        let settings = try repository.loadSettings()

        // Then: Should create settings with current version
        XCTAssertEqual(settings.version, .current)
        XCTAssertFalse(settings.data.isEmpty)

        // Should have default values
        XCTAssertNotNil(settings.data["notificationsEnabled"])
        XCTAssertNotNil(settings.data["theme"])
    }

    func testAutoMigrationOnLoad_V1_0Upgrade() throws {
        // Given: Settings stored at v1.0
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "biometricAuthEnabled": AnyCodable(false),
                "theme": AnyCodable("dark")
            ]
        )

        // Save v1.0 settings
        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")
        userDefaults.set("1.0.0", forKey: "app.provii.wallet.settings.version")

        // When: Loading settings (should trigger auto-migration)
        let loaded = try repository.loadSettings()

        // Then: Should be migrated to current version
        XCTAssertEqual(loaded.version, .current)

        // Original data should be preserved
        XCTAssertEqual(loaded.data["notificationsEnabled"]?.value as? Bool, true)
        XCTAssertEqual(loaded.data["biometricAuthEnabled"]?.value as? Bool, false)
        XCTAssertEqual(loaded.data["theme"]?.value as? String, "dark")

        // New v1.1 fields should be added
        XCTAssertNotNil(loaded.data["reduceMotion"])
        XCTAssertNotNil(loaded.data["preferredFontSize"])
        XCTAssertNotNil(loaded.data["highContrastMode"])
    }

    func testAutoMigrationOnLoad_AlreadyCurrent() throws {
        // Given: Settings already at current version
        let currentSettings = VersionedSettings(
            version: .current,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "reduceMotion": AnyCodable(false)
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(currentSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading settings
        let loaded = try repository.loadSettings()

        // Then: Should load without migration
        XCTAssertEqual(loaded.version, .current)
        XCTAssertEqual(loaded.data["notificationsEnabled"]?.value as? Bool, true)
    }

    func testAutoMigrationOnLoad_VersionTooNew() throws {
        // Given: Settings with a future version
        let futureVersion = SettingsVersion(major: 99, minor: 0, patch: 0)
        let futureSettings = VersionedSettings(
            version: futureVersion,
            data: ["test": AnyCodable(true)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(futureSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When/Then: Loading should throw incompatible version error
        XCTAssertThrowsError(try repository.loadSettings()) { error in
            if case MigrationError.incompatibleVersion = error {
                // Expected error
            } else {
                XCTFail("Expected incompatibleVersion error, got \(error)")
            }
        }
    }

    // MARK: - Migration Preserves Data Tests

    func testMigrationPreservesData_AllFields() throws {
        // Given: v1.0 settings with all expected fields
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "biometricAuthEnabled": AnyCodable(true),
                "theme": AnyCodable("light"),
                "language": AnyCodable("es")
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading (auto-migrating)
        let migrated = try repository.loadSettings()

        // Then: All original data should be preserved
        XCTAssertEqual(migrated.data["notificationsEnabled"]?.value as? Bool, true)
        XCTAssertEqual(migrated.data["biometricAuthEnabled"]?.value as? Bool, true)
        XCTAssertEqual(migrated.data["theme"]?.value as? String, "light")
        XCTAssertEqual(migrated.data["language"]?.value as? String, "es")
    }

    func testMigrationPreservesData_WithExtraFields() throws {
        // Given: Settings with extra/unknown fields
        let settingsWithExtra = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "customField1": AnyCodable("custom"),
                "customField2": AnyCodable(123)
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(settingsWithExtra)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading
        let migrated = try repository.loadSettings()

        // Then: Extra fields should be preserved
        XCTAssertEqual(migrated.data["customField1"]?.value as? String, "custom")
        XCTAssertEqual(migrated.data["customField2"]?.value as? Int, 123)
    }

    func testMigrationPreservesData_EmptyData() throws {
        // Given: Settings with empty data
        let emptySettings = VersionedSettings(version: .v1_0_0, data: [:])

        let encoder = JSONEncoder()
        let data = try encoder.encode(emptySettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading
        let migrated = try repository.loadSettings()

        // Then: Should succeed with defaults added
        XCTAssertEqual(migrated.version, .current)
        XCTAssertNotNil(migrated.data["reduceMotion"]) // v1.1 field should be added
    }

    // MARK: - Migration Logging Tests

    func testMigrationLogging_SuccessfulMigration() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: ["test": AnyCodable(true)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading (triggers migration)
        let migrated = try repository.loadSettings()

        // Then: Migration should complete successfully
        XCTAssertEqual(migrated.version, .current)

        // Verify settings were persisted
        let currentVersion = repository.getCurrentVersion()
        XCTAssertEqual(currentVersion, .current)
    }

    // MARK: - Repository Operations Tests

    func testUpdateSetting_PreservesMigration() throws {
        // Given: Migrated settings
        _ = try repository.loadSettings()

        // When: Updating a setting
        try repository.updateSetting(key: "notificationsEnabled", value: false)

        // Then: Settings should still be at current version
        let settings = try repository.loadSettings()
        XCTAssertEqual(settings.version, .current)
        XCTAssertEqual(settings.data["notificationsEnabled"]?.value as? Bool, false)
    }

    func testGetSetting_AfterMigration() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: ["notificationsEnabled": AnyCodable(true)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Getting a new v1.1 setting
        let reduceMotion: Bool? = repository.getSetting(key: "reduceMotion")

        // Then: Should return the default value added during migration
        XCTAssertNotNil(reduceMotion)
        XCTAssertEqual(reduceMotion, false)
    }

    func testResetToDefaults_UsesCurrentVersion() throws {
        // Given: Any state
        _ = try repository.loadSettings()

        // When: Resetting to defaults
        try repository.resetToDefaults()

        // Then: Should create settings with current version
        let settings = try repository.loadSettings()
        XCTAssertEqual(settings.version, .current)
        XCTAssertFalse(settings.data.isEmpty)
    }

    func testNeedsMigration_V1_0() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: [:]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")
        userDefaults.set("1.0.0", forKey: "app.provii.wallet.settings.version")

        // When: Checking if migration needed
        let needs = repository.needsMigration()

        // Then: Should need migration if current > v1.0
        if SettingsVersion.current > .v1_0_0 {
            XCTAssertTrue(needs)
        } else {
            XCTAssertFalse(needs)
        }
    }

    func testNeedsMigration_CurrentVersion() throws {
        // Given: Current version settings
        let currentSettings = VersionedSettings(
            version: .current,
            data: [:]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(currentSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")
        userDefaults.set(SettingsVersion.current.description, forKey: "app.provii.wallet.settings.version")

        // When: Checking if migration needed
        let needs = repository.needsMigration()

        // Then: Should not need migration
        XCTAssertFalse(needs)
    }

    func testPerformMigration_Explicitly() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: ["test": AnyCodable(true)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Explicitly performing migration
        try repository.performMigration()

        // Then: Settings should be migrated
        let currentVersion = repository.getCurrentVersion()
        XCTAssertEqual(currentVersion, .current)
    }

    // MARK: - Export/Import Tests

    func testExportSettings_AfterMigration() throws {
        // Given: Migrated settings
        _ = try repository.loadSettings()

        // When: Exporting settings
        let exportedData = try repository.exportSettings()

        // Then: Export should succeed
        XCTAssertGreaterThan(exportedData.count, 0)

        // Should be valid JSON
        let decoder = JSONDecoder()
        let exported = try decoder.decode(VersionedSettings.self, from: exportedData)
        XCTAssertEqual(exported.version, .current)
    }

    func testImportSettings_V1_0_AutoMigrates() throws {
        // Given: Exported v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(false),
                "theme": AnyCodable("dark")
            ]
        )

        let encoder = JSONEncoder()
        let exportedData = try encoder.encode(v1_0_settings)

        // When: Importing
        try repository.importSettings(from: exportedData)

        // Then: Should auto-migrate to current version
        let settings = try repository.loadSettings()
        XCTAssertEqual(settings.version, .current)

        // Original data should be preserved
        XCTAssertEqual(settings.data["notificationsEnabled"]?.value as? Bool, false)
        XCTAssertEqual(settings.data["theme"]?.value as? String, "dark")

        // v1.1 fields should be added
        XCTAssertNotNil(settings.data["reduceMotion"])
    }

    func testImportSettings_CurrentVersion() throws {
        // Given: Exported current version settings
        let currentSettings = VersionedSettings(
            version: .current,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "reduceMotion": AnyCodable(true)
            ]
        )

        let encoder = JSONEncoder()
        let exportedData = try encoder.encode(currentSettings)

        // When: Importing
        try repository.importSettings(from: exportedData)

        // Then: Should import without migration
        let settings = try repository.loadSettings()
        XCTAssertEqual(settings.version, .current)
        XCTAssertEqual(settings.data["notificationsEnabled"]?.value as? Bool, true)
        XCTAssertEqual(settings.data["reduceMotion"]?.value as? Bool, true)
    }

    // MARK: - Persistence Tests

    func testMigration_PersistsToStorage() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: ["test": AnyCodable(true)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading (triggers migration)
        _ = try repository.loadSettings()

        // Then: Migrated settings should be persisted
        let persistedData = userDefaults.data(forKey: "app.provii.wallet.settings")
        XCTAssertNotNil(persistedData)

        let decoder = JSONDecoder()
        let persisted = try decoder.decode(VersionedSettings.self, from: persistedData!)
        XCTAssertEqual(persisted.version, .current)
    }

    func testMigration_UpdatesVersionKey() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: [:]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")
        userDefaults.set("1.0.0", forKey: "app.provii.wallet.settings.version")

        // When: Loading (triggers migration)
        _ = try repository.loadSettings()

        // Then: Version key should be updated
        let versionString = userDefaults.string(forKey: "app.provii.wallet.settings.version")
        XCTAssertEqual(versionString, SettingsVersion.current.description)
    }

    // MARK: - Concurrent Access Tests

    func testMigration_ThreadSafe() throws {
        // Given: v1.0 settings
        let v1_0_settings = VersionedSettings(
            version: .v1_0_0,
            data: ["counter": AnyCodable(0)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1_0_settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Multiple threads access settings
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 5

        for i in 0..<5 {
            DispatchQueue.global().async {
                do {
                    let settings = try self.repository.loadSettings()
                    XCTAssertEqual(settings.version, .current)
                    expectation.fulfill()
                } catch {
                    XCTFail("Thread \(i) failed: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Edge Cases

    func testMigration_CorruptedData() {
        // Given: Corrupted settings data
        let corruptedData = Data("not valid json".utf8)
        userDefaults.set(corruptedData, forKey: "app.provii.wallet.settings")

        // When/Then: Should handle gracefully
        XCTAssertThrowsError(try repository.loadSettings())
    }

    func testMigration_MissingVersionField() throws {
        // Given: Settings with missing version in data (but version key exists)
        let settingsDict: [String: Any] = [
            "data": [
                "notificationsEnabled": true
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: settingsDict)
        userDefaults.set(jsonData, forKey: "app.provii.wallet.settings")
        userDefaults.set("1.0.0", forKey: "app.provii.wallet.settings.version")

        // When/Then: Should handle gracefully or throw appropriate error
        XCTAssertThrowsError(try repository.loadSettings())
    }
}
