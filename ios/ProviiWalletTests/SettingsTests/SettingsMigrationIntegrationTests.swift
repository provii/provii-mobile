/// End-to-end integration tests for settings migration, covering fresh install, v1.0 to v1.1
/// upgrade, downgrade handling, corrupted data recovery, export/import, and concurrent access.
import XCTest
@testable import ProviiWallet

class SettingsMigrationIntegrationTests: XCTestCase {

    var repository: SettingsRepository!
    var userDefaults: UserDefaults!
    let suiteName = "app.provii.wallet.tests.integration"

    override func setUp() {
        super.setUp()

        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)

        repository = SettingsRepository(
            userDefaults: userDefaults,
            migrationManager: SettingsMigrationManager()
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        repository = nil

        super.tearDown()
    }

    // MARK: - Fresh Install Scenario

    func testScenario_FreshInstall() throws {
        // Scenario: User installs app for the first time

        // When: App loads settings
        let settings = try repository.loadSettings()

        // Then: Should have current version with all defaults
        XCTAssertEqual(settings.version, .current)

        // All current settings should be present
        XCTAssertNotNil(settings.data["notificationsEnabled"])
        XCTAssertNotNil(settings.data["biometricAuthEnabled"])
        XCTAssertNotNil(settings.data["theme"])
        XCTAssertNotNil(settings.data["language"])

        // v1.1 accessibility features should be present
        XCTAssertNotNil(settings.data["reduceMotion"])
        XCTAssertNotNil(settings.data["preferredFontSize"])
        XCTAssertNotNil(settings.data["highContrastMode"])
        XCTAssertNotNil(settings.data["colorBlindMode"])

        // Defaults should be sensible
        XCTAssertEqual(settings.data["notificationsEnabled"]?.value as? Bool, true)
        XCTAssertEqual(settings.data["reduceMotion"]?.value as? Bool, false)
        XCTAssertEqual(settings.data["preferredFontSize"]?.value as? String, "medium")
    }

    // MARK: - Upgrade from v1.0 to v1.1 Scenario

    func testScenario_UpgradeFromV1_0ToV1_1() throws {
        // Scenario: User has app with v1.0 settings, upgrades to v1.1

        // Given: User has been using the app with v1.0 settings
        let userV1Settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(false), // User disabled notifications
                "biometricAuthEnabled": AnyCodable(true),  // User enabled biometrics
                "theme": AnyCodable("dark"),               // User prefers dark mode
                "language": AnyCodable("es")               // User speaks Spanish
            ]
        )

        // Save these settings as if they were from v1.0
        let encoder = JSONEncoder()
        let data = try encoder.encode(userV1Settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")
        userDefaults.set("1.0.0", forKey: "app.provii.wallet.settings.version")

        // When: App updates to v1.1 and loads settings
        let upgradedSettings = try repository.loadSettings()

        // Then: Should be migrated to v1.1
        XCTAssertEqual(upgradedSettings.version, .v1_1_0)

        // User's original preferences should be preserved
        XCTAssertEqual(upgradedSettings.data["notificationsEnabled"]?.value as? Bool, false)
        XCTAssertEqual(upgradedSettings.data["biometricAuthEnabled"]?.value as? Bool, true)
        XCTAssertEqual(upgradedSettings.data["theme"]?.value as? String, "dark")
        XCTAssertEqual(upgradedSettings.data["language"]?.value as? String, "es")

        // New accessibility settings should be added with defaults
        XCTAssertEqual(upgradedSettings.data["reduceMotion"]?.value as? Bool, false)
        XCTAssertEqual(upgradedSettings.data["preferredFontSize"]?.value as? String, "medium")
        XCTAssertEqual(upgradedSettings.data["highContrastMode"]?.value as? Bool, false)
        XCTAssertEqual(upgradedSettings.data["colorBlindMode"]?.value as? String, "none")

        // Verify settings are persisted
        let reloaded = try repository.loadSettings()
        XCTAssertEqual(reloaded.version, .v1_1_0)
        XCTAssertEqual(reloaded.data["theme"]?.value as? String, "dark")
    }

    // MARK: - Multi-Step Migration Scenario

    func testScenario_MultiStepMigration() throws {
        // Scenario: Future test for when we have v1.0 -> v1.1 -> v2.0 migrations

        // Given: Settings at v1.0
        let v1Settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "theme": AnyCodable("light")
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1Settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading (triggers migration)
        let migrated = try repository.loadSettings()

        // Then: Should successfully migrate through all steps
        XCTAssertEqual(migrated.version, .current)

        // All intermediate migration changes should be applied
        XCTAssertNotNil(migrated.data["reduceMotion"]) // Added in v1.1
    }

    // MARK: - Downgrade Handling Scenario

    func testScenario_DowngradeAttempt() throws {
        // Scenario: User has v2.0 settings but app is rolled back to v1.1

        // Given: Settings from a future version
        let futureVersion = SettingsVersion(major: 2, minor: 0, patch: 0)
        let futureSettings = VersionedSettings(
            version: futureVersion,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "futureFeature": AnyCodable("some value")
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(futureSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When/Then: App should detect incompatible version
        XCTAssertThrowsError(try repository.loadSettings()) { error in
            if case MigrationError.incompatibleVersion(let from, let to) = error {
                XCTAssertEqual(from, futureVersion)
                XCTAssertEqual(to, .current)
            } else {
                XCTFail("Expected incompatibleVersion error, got \(error)")
            }
        }
    }

    // MARK: - Corrupted Data Recovery Scenario

    func testScenario_CorruptedDataRecovery() throws {
        // Scenario: Settings file is corrupted or invalid

        // Given: Corrupted JSON data
        let corruptedData = Data("{invalid json".utf8)
        userDefaults.set(corruptedData, forKey: "app.provii.wallet.settings")

        // When/Then: Should fail gracefully
        XCTAssertThrowsError(try repository.loadSettings())

        // Scenario continues: App resets to defaults
        try repository.resetToDefaults()

        // Then: Should have valid settings
        let recovered = try repository.loadSettings()
        XCTAssertEqual(recovered.version, .current)
        XCTAssertFalse(recovered.data.isEmpty)
    }

    func testScenario_PartiallyCorruptedData() throws {
        // Scenario: Settings are valid JSON but missing required fields

        // Given: Settings with missing version
        let incompleteJSON = Data("""
        {
            "data": {
                "notificationsEnabled": true
            }
        }
        """.utf8)

        userDefaults.set(incompleteJSON, forKey: "app.provii.wallet.settings")

        // When/Then: Should handle gracefully
        XCTAssertThrowsError(try repository.loadSettings())

        // Recovery: Reset to defaults
        try repository.resetToDefaults()
        let recovered = try repository.loadSettings()
        XCTAssertEqual(recovered.version, .current)
    }

    // MARK: - User Customization Preservation Scenario

    func testScenario_UserCustomizationsDuringUpgrade() throws {
        // Scenario: User has heavily customized v1.0 settings, upgrades to v1.1

        // Given: User's customized settings
        let customizedSettings = VersionedSettings(
            version: .v1_0_0,
            data: [
                // Standard settings
                "notificationsEnabled": AnyCodable(false),
                "biometricAuthEnabled": AnyCodable(true),
                "theme": AnyCodable("dark"),
                "language": AnyCodable("fr"),

                // Custom/unknown fields (for forward compatibility)
                "customPreference1": AnyCodable("userValue"),
                "customPreference2": AnyCodable(42),
                "customPreference3": AnyCodable(["item1", "item2"])
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(customizedSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Upgrading to v1.1
        let upgraded = try repository.loadSettings()

        // Then: All customizations should be preserved
        XCTAssertEqual(upgraded.data["notificationsEnabled"]?.value as? Bool, false)
        XCTAssertEqual(upgraded.data["biometricAuthEnabled"]?.value as? Bool, true)
        XCTAssertEqual(upgraded.data["theme"]?.value as? String, "dark")
        XCTAssertEqual(upgraded.data["language"]?.value as? String, "fr")

        // Custom fields should be preserved
        XCTAssertEqual(upgraded.data["customPreference1"]?.value as? String, "userValue")
        XCTAssertEqual(upgraded.data["customPreference2"]?.value as? Int, 42)

        // New v1.1 fields should be added
        XCTAssertNotNil(upgraded.data["reduceMotion"])
    }

    // MARK: - Export/Import Across Versions Scenario

    func testScenario_ExportImportAcrossVersions() throws {
        // Scenario: User exports settings on v1.0, imports on v1.1

        // Phase 1: User on v1.0 exports settings
        let v1Settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(false),
                "theme": AnyCodable("dark")
            ]
        )

        let encoder = JSONEncoder()
        let exportedData = try encoder.encode(v1Settings)

        // Phase 2: User upgrades to v1.1 and imports
        try repository.importSettings(from: exportedData)

        // Then: Settings should be auto-migrated during import
        let imported = try repository.loadSettings()
        XCTAssertEqual(imported.version, .current)

        // Original data preserved
        XCTAssertEqual(imported.data["notificationsEnabled"]?.value as? Bool, false)
        XCTAssertEqual(imported.data["theme"]?.value as? String, "dark")

        // New v1.1 fields added
        XCTAssertNotNil(imported.data["reduceMotion"])
    }

    // MARK: - Concurrent User Actions During Migration Scenario

    func testScenario_UserActionsDuringMigration() throws {
        // Scenario: User performs actions while migration is occurring

        // Given: v1.0 settings
        let v1Settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true)
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1Settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Loading settings (triggers migration)
        let migrated = try repository.loadSettings()

        // User immediately changes a setting
        try repository.updateSetting(key: "theme", value: "dark")

        // Then: Settings should be at current version
        let updated = try repository.loadSettings()
        XCTAssertEqual(updated.version, .current)
        XCTAssertEqual(updated.data["theme"]?.value as? String, "dark")

        // Migration should have completed successfully
        XCTAssertNotNil(updated.data["reduceMotion"])
    }

    // MARK: - App Reinstall Scenario

    func testScenario_AppReinstallWithBackup() throws {
        // Scenario: User uninstalls app, reinstalls, and restores from backup

        // Phase 1: User has settings
        let originalSettings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(false),
                "theme": AnyCodable("dark"),
                "language": AnyCodable("de")
            ]
        )

        // User exports before uninstalling
        let encoder = JSONEncoder()
        let backup = try encoder.encode(originalSettings)

        // Phase 2: User reinstalls (fresh state)
        userDefaults.removePersistentDomain(forName: suiteName)

        // User restores from backup
        try repository.importSettings(from: backup)

        // Then: Settings should be restored and migrated
        let restored = try repository.loadSettings()
        XCTAssertEqual(restored.version, .current)
        XCTAssertEqual(restored.data["notificationsEnabled"]?.value as? Bool, false)
        XCTAssertEqual(restored.data["theme"]?.value as? String, "dark")
        XCTAssertEqual(restored.data["language"]?.value as? String, "de")

        // New features should be available
        XCTAssertNotNil(restored.data["reduceMotion"])
    }

    // MARK: - Accessibility User Journey Scenario

    func testScenario_AccessibilityUserJourney() throws {
        // Scenario: Accessibility user upgrades from v1.0 to v1.1

        // Phase 1: User on v1.0 (no accessibility features)
        let v1Settings = VersionedSettings(
            version: .v1_0_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "theme": AnyCodable("light")
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(v1Settings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // Phase 2: App updates to v1.1, user discovers accessibility features
        var settings = try repository.loadSettings()

        // User enables accessibility features
        try repository.updateSetting(key: "reduceMotion", value: true)
        try repository.updateSetting(key: "preferredFontSize", value: "large")
        try repository.updateSetting(key: "highContrastMode", value: true)
        try repository.updateSetting(key: "colorBlindMode", value: "deuteranopia")

        // Phase 3: User reopens app
        settings = try repository.loadSettings()

        // Then: All accessibility preferences should be preserved
        XCTAssertEqual(settings.data["reduceMotion"]?.value as? Bool, true)
        XCTAssertEqual(settings.data["preferredFontSize"]?.value as? String, "large")
        XCTAssertEqual(settings.data["highContrastMode"]?.value as? Bool, true)
        XCTAssertEqual(settings.data["colorBlindMode"]?.value as? String, "deuteranopia")

        // Original preferences still intact
        XCTAssertEqual(settings.data["theme"]?.value as? String, "light")
    }

    // MARK: - Beta to Production Scenario

    func testScenario_BetaToProduction() throws {
        // Scenario: User participates in beta with v1.1, stable release is v1.1

        // Given: Beta user with v1.1 settings
        let betaSettings = VersionedSettings(
            version: .v1_1_0,
            data: [
                "notificationsEnabled": AnyCodable(true),
                "reduceMotion": AnyCodable(false),
                "preferredFontSize": AnyCodable("medium")
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(betaSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")
        userDefaults.set("1.1.0", forKey: "app.provii.wallet.settings.version")

        // When: Switching to production release
        let productionSettings = try repository.loadSettings()

        // Then: No migration needed, settings load normally
        XCTAssertEqual(productionSettings.version, .v1_1_0)
        XCTAssertEqual(productionSettings.data["notificationsEnabled"]?.value as? Bool, true)

        // Should not need migration
        XCTAssertFalse(repository.needsMigration())
    }

    // MARK: - Performance Test

    func testScenario_LargeSettingsMigrationPerformance() throws {
        // Scenario: Migration performance with large settings dataset

        // Given: Large settings file with many custom fields
        var largeData: [String: AnyCodable] = [
            "notificationsEnabled": AnyCodable(true),
            "theme": AnyCodable("dark")
        ]

        // Add 100 custom settings
        for i in 0..<100 {
            largeData["custom_\(i)"] = AnyCodable("value_\(i)")
        }

        let largeSettings = VersionedSettings(
            version: .v1_0_0,
            data: largeData
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(largeSettings)
        userDefaults.set(data, forKey: "app.provii.wallet.settings")

        // When: Measuring migration performance
        let startTime = Date()
        let migrated = try repository.loadSettings()
        let duration = Date().timeIntervalSince(startTime)

        // Then: Migration should complete quickly (< 1 second)
        XCTAssertLessThan(duration, 1.0)
        XCTAssertEqual(migrated.version, .current)

        // All custom data should be preserved
        for i in 0..<100 {
            XCTAssertEqual(migrated.data["custom_\(i)"]?.value as? String, "value_\(i)")
        }
    }
}
