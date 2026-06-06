/// Tests for LanguageSettings covering default values, save/load round-trips, RTL language
/// detection, settings existence checks, resets, and supported language validation.
import XCTest
@testable import ProviiWallet

@MainActor
final class LanguageSettingsTests: XCTestCase {
    var repository: SettingsRepository!

    override func setUp() async throws {
        try await super.setUp()
        // Use in-memory repository for testing
        repository = SettingsRepository.inMemory()
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - Basic Settings Tests

    func testDefaultLanguageSettings() throws {
        let settings = repository.load(LanguageSettings.self)

        XCTAssertEqual(settings.selectedLanguage, "en", "Default language should be English")
        XCTAssertFalse(settings.rtlEnabled, "English should not be RTL")
        XCTAssertTrue(settings.useSystemLanguage, "Should use system language by default")
    }

    func testSaveAndLoadLanguageSettings() throws {
        var settings = LanguageSettings()
        settings.selectedLanguage = "ar"
        settings.rtlEnabled = true
        settings.useSystemLanguage = false

        let saved = repository.save(settings)
        XCTAssertTrue(saved, "Settings should save successfully")

        let loaded = repository.load(LanguageSettings.self)
        XCTAssertEqual(loaded.selectedLanguage, "ar", "Loaded language should be Arabic")
        XCTAssertTrue(loaded.rtlEnabled, "Arabic should be RTL")
        XCTAssertFalse(loaded.useSystemLanguage, "System language should be disabled")
    }

    // MARK: - RTL Tests

    func testRTLLanguages() throws {
        let rtlLanguages = ["ar", "he", "fa", "fa-AF", "ur", "ku", "ps", "haz"]

        for code in rtlLanguages {
            if let language = Language.supportedLanguages.first(where: { $0.code == code }) {
                XCTAssertTrue(language.isRTL, "\(code) should be RTL")
            }
        }
    }

    func testNonRTLLanguages() throws {
        let ltrLanguages = ["en", "es", "fr", "de", "zh-Hans", "ja", "ko"]

        for code in ltrLanguages {
            if let language = Language.supportedLanguages.first(where: { $0.code == code }) {
                XCTAssertFalse(language.isRTL, "\(code) should not be RTL")
            }
        }
    }

    func testSetLanguageUpdatesRTL() throws {
        var settings = LanguageSettings()

        // Test setting RTL language
        if let arabic = Language.supportedLanguages.first(where: { $0.code == "ar" }) {
            settings.setLanguage(arabic)
            XCTAssertEqual(settings.selectedLanguage, "ar")
            XCTAssertTrue(settings.rtlEnabled)
            XCTAssertFalse(settings.useSystemLanguage)
        }

        // Test setting LTR language
        if let english = Language.supportedLanguages.first(where: { $0.code == "en" }) {
            settings.setLanguage(english)
            XCTAssertEqual(settings.selectedLanguage, "en")
            XCTAssertFalse(settings.rtlEnabled)
            XCTAssertFalse(settings.useSystemLanguage)
        }
    }

    // MARK: - Settings Repository Tests

    func testSettingsExists() throws {
        XCTAssertFalse(repository.exists(LanguageSettings.self), "Settings should not exist initially")

        let settings = LanguageSettings()
        repository.save(settings)

        XCTAssertTrue(repository.exists(LanguageSettings.self), "Settings should exist after saving")
    }

    func testSettingsReset() throws {
        var settings = LanguageSettings()
        settings.selectedLanguage = "fr"
        repository.save(settings)

        repository.reset(LanguageSettings.self)

        let loaded = repository.load(LanguageSettings.self)
        XCTAssertEqual(loaded.selectedLanguage, "en", "Reset should restore default language")
    }

    // MARK: - Language Helper Tests

    func testGetLanguageFromSettings() throws {
        var settings = LanguageSettings()
        settings.selectedLanguage = "es"

        if let language = settings.getLanguage() {
            XCTAssertEqual(language.code, "es")
            XCTAssertEqual(language.englishName, "Spanish")
            XCTAssertFalse(language.isRTL)
        } else {
            XCTFail("Should find Spanish language")
        }
    }

    func testIsRTLLanguageComputed() throws {
        var settings = LanguageSettings()

        settings.selectedLanguage = "ar"
        XCTAssertTrue(settings.isRTLLanguage, "Arabic should be RTL")

        settings.selectedLanguage = "en"
        XCTAssertFalse(settings.isRTLLanguage, "English should not be RTL")
    }

    func testResetToSystemLanguage() throws {
        var settings = LanguageSettings()
        settings.selectedLanguage = "de"
        settings.useSystemLanguage = false

        settings.resetToSystemLanguage()

        XCTAssertTrue(settings.useSystemLanguage, "Should enable system language")
        // Note: The exact language depends on test environment, but it should be valid
        XCTAssertNotNil(settings.getLanguage(), "Should have a valid language")
    }

    // MARK: - Supported Languages Tests

    func testSupportedLanguagesCount() throws {
        XCTAssertEqual(Language.supportedLanguages.count, LanguageSettings.LanguageInfo.supportedLanguages.count, "Language.supportedLanguages should match LanguageSettings.LanguageInfo.supportedLanguages")
    }

    func testAllSupportedLanguagesHaveValidCodes() throws {
        for language in Language.supportedLanguages {
            XCTAssertFalse(language.code.isEmpty, "Language code should not be empty")
            XCTAssertFalse(language.nativeName.isEmpty, "Native name should not be empty")
            XCTAssertFalse(language.englishName.isEmpty, "English name should not be empty")
        }
    }
}
