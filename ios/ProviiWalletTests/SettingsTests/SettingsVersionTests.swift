/// Tests for SettingsVersion comparison, string parsing, Codable round-trips,
/// compatibility checks, migration requirements, and AnyCodable type support.
import XCTest
@testable import ProviiWallet

class SettingsVersionTests: XCTestCase {

    // MARK: - Version Comparison Tests

    func testVersionComparison_Equal() {
        let version1 = SettingsVersion(major: 1, minor: 2, patch: 3)
        let version2 = SettingsVersion(major: 1, minor: 2, patch: 3)

        XCTAssertEqual(version1, version2)
        XCTAssertFalse(version1 < version2)
        XCTAssertFalse(version1 > version2)
        XCTAssertTrue(version1 <= version2)
        XCTAssertTrue(version1 >= version2)
    }

    func testVersionComparison_MajorDifference() {
        let version1 = SettingsVersion(major: 1, minor: 2, patch: 3)
        let version2 = SettingsVersion(major: 2, minor: 0, patch: 0)

        XCTAssertNotEqual(version1, version2)
        XCTAssertTrue(version1 < version2)
        XCTAssertFalse(version1 > version2)
        XCTAssertTrue(version2 > version1)
    }

    func testVersionComparison_MinorDifference() {
        let version1 = SettingsVersion(major: 1, minor: 1, patch: 0)
        let version2 = SettingsVersion(major: 1, minor: 2, patch: 0)

        XCTAssertTrue(version1 < version2)
        XCTAssertFalse(version1 > version2)
        XCTAssertTrue(version2 > version1)
    }

    func testVersionComparison_PatchDifference() {
        let version1 = SettingsVersion(major: 1, minor: 1, patch: 1)
        let version2 = SettingsVersion(major: 1, minor: 1, patch: 2)

        XCTAssertTrue(version1 < version2)
        XCTAssertFalse(version1 > version2)
    }

    // MARK: - Version Parsing Tests

    func testVersionParsing_ValidString() {
        let version = SettingsVersion(string: "1.2.3")

        XCTAssertNotNil(version)
        XCTAssertEqual(version?.major, 1)
        XCTAssertEqual(version?.minor, 2)
        XCTAssertEqual(version?.patch, 3)
    }

    func testVersionParsing_ValidStringNoPatch() {
        let version = SettingsVersion(string: "1.2")

        XCTAssertNotNil(version)
        XCTAssertEqual(version?.major, 1)
        XCTAssertEqual(version?.minor, 2)
        XCTAssertEqual(version?.patch, 0)
    }

    func testVersionParsing_InvalidString() {
        let version1 = SettingsVersion(string: "invalid")
        XCTAssertNil(version1)

        let version2 = SettingsVersion(string: "1")
        XCTAssertNil(version2)

        let version3 = SettingsVersion(string: "")
        XCTAssertNil(version3)

        let version4 = SettingsVersion(string: "1.x.3")
        XCTAssertNil(version4)
    }

    func testVersionParsing_StringRepresentation() {
        let version = SettingsVersion(major: 1, minor: 2, patch: 3)
        XCTAssertEqual(version.description, "1.2.3")
    }

    func testVersionParsing_RoundTrip() {
        let original = SettingsVersion(major: 1, minor: 2, patch: 3)
        let stringRepresentation = original.description
        let parsed = SettingsVersion(string: stringRepresentation)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(original, parsed)
    }

    // MARK: - Current Version Tests

    func testCurrentVersion_Exists() {
        let current = SettingsVersion.current
        XCTAssertNotNil(current)
        XCTAssertGreaterThanOrEqual(current.major, 1)
    }

    func testCurrentVersion_IsGreaterThanV1_0() {
        let current = SettingsVersion.current
        let v1_0 = SettingsVersion.v1_0_0

        XCTAssertGreaterThanOrEqual(current, v1_0)
    }

    func testPredefinedVersions() {
        let v1_0_0 = SettingsVersion.v1_0_0
        XCTAssertEqual(v1_0_0.major, 1)
        XCTAssertEqual(v1_0_0.minor, 0)
        XCTAssertEqual(v1_0_0.patch, 0)

        let v1_1_0 = SettingsVersion.v1_1_0
        XCTAssertEqual(v1_1_0.major, 1)
        XCTAssertEqual(v1_1_0.minor, 1)
        XCTAssertEqual(v1_1_0.patch, 0)

        XCTAssertTrue(v1_1_0 > v1_0_0)
    }

    // MARK: - Version Compatibility Tests

    func testIsCompatible_SameMajor_HigherMinor() {
        let v1_1 = SettingsVersion(major: 1, minor: 1, patch: 0)
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

        XCTAssertTrue(v1_1.isCompatible(with: v1_0))
        XCTAssertFalse(v1_0.isCompatible(with: v1_1))
    }

    func testIsCompatible_DifferentMajor() {
        let v2_0 = SettingsVersion(major: 2, minor: 0, patch: 0)
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

        XCTAssertFalse(v2_0.isCompatible(with: v1_0))
        XCTAssertFalse(v1_0.isCompatible(with: v2_0))
    }

    func testIsCompatible_SameVersion() {
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

        XCTAssertTrue(v1_0.isCompatible(with: v1_0))
    }

    func testRequiresMigration_OlderVersion() {
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)
        let v1_1 = SettingsVersion(major: 1, minor: 1, patch: 0)

        XCTAssertTrue(v1_0.requiresMigration(to: v1_1))
        XCTAssertFalse(v1_1.requiresMigration(to: v1_0))
    }

    func testRequiresMigration_SameVersion() {
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

        XCTAssertFalse(v1_0.requiresMigration(to: v1_0))
    }

    func testIsTooNew_NewerVersion() {
        let v1_1 = SettingsVersion(major: 1, minor: 1, patch: 0)
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

        XCTAssertTrue(v1_1.isTooNew(for: v1_0))
        XCTAssertFalse(v1_0.isTooNew(for: v1_1))
    }

    func testIsTooNew_SameVersion() {
        let v1_0 = SettingsVersion(major: 1, minor: 0, patch: 0)

        XCTAssertFalse(v1_0.isTooNew(for: v1_0))
    }

    // MARK: - Codable Tests

    func testVersionCodable_Encoding() throws {
        let version = SettingsVersion(major: 1, minor: 2, patch: 3)
        let encoder = JSONEncoder()

        let data = try encoder.encode(version)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }

    func testVersionCodable_Decoding() throws {
        let version = SettingsVersion(major: 1, minor: 2, patch: 3)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(version)
        let decoded = try decoder.decode(SettingsVersion.self, from: data)

        XCTAssertEqual(version, decoded)
    }

    func testVersionCodable_RoundTrip() throws {
        let original = SettingsVersion(major: 2, minor: 5, patch: 17)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SettingsVersion.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.major, decoded.major)
        XCTAssertEqual(original.minor, decoded.minor)
        XCTAssertEqual(original.patch, decoded.patch)
    }

    // MARK: - VersionedSettings Tests

    func testVersionedSettings_Creation() {
        let version = SettingsVersion(major: 1, minor: 0, patch: 0)
        let data: [String: AnyCodable] = [
            "setting1": AnyCodable(true),
            "setting2": AnyCodable("value")
        ]

        let settings = VersionedSettings(version: version, data: data)

        XCTAssertEqual(settings.version, version)
        XCTAssertEqual(settings.data.count, 2)
    }

    func testVersionedSettings_Codable() throws {
        let version = SettingsVersion(major: 1, minor: 1, patch: 0)
        let data: [String: AnyCodable] = [
            "boolSetting": AnyCodable(true),
            "intSetting": AnyCodable(42),
            "stringSetting": AnyCodable("test")
        ]

        let settings = VersionedSettings(version: version, data: data)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(settings)
        let decoded = try decoder.decode(VersionedSettings.self, from: encodedData)

        XCTAssertEqual(settings.version, decoded.version)
        XCTAssertEqual(settings.data.count, decoded.data.count)
    }

    // MARK: - AnyCodable Tests

    func testAnyCodable_Bool() throws {
        let value = AnyCodable(true)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(value)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(value.value as? Bool, decoded.value as? Bool)
    }

    func testAnyCodable_Int() throws {
        let value = AnyCodable(42)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(value)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(value.value as? Int, decoded.value as? Int)
    }

    func testAnyCodable_Double() throws {
        let value = AnyCodable(3.14)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(value)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(value.value as? Double, decoded.value as? Double)
    }

    func testAnyCodable_String() throws {
        let value = AnyCodable("test")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(value)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(value.value as? String, decoded.value as? String)
    }
}
