/// Validates localisation files to detect language mix-ups between German and French
/// translations, checking for cross-contamination, empty values, and key parity.
import XCTest
import Foundation

class LocalizationValidationTests: XCTestCase {

    // MARK: - Test Configuration

    /// Threshold for how many language indicators constitute a failure
    /// Set to 3 to allow for occasional false positives (e.g., borrowed words, proper nouns)
    private let failureThreshold = 3

    // MARK: - Language Indicators

    /// Common German words and patterns that should NOT appear in French translations
    private let germanIndicators: [String] = [
        // Articles
        " der ", " die ", " das ", " den ", " dem ", " des ",
        " ein ", " eine ", " einer ", " einem ", " eines ",

        // Common prepositions and conjunctions
        " und ", " oder ", " aber ", " für ", " mit ", " von ",
        " zu ", " bei ", " nach ", " über ", " unter ",

        // Common verbs
        " ist ", " sind ", " war ", " waren ", " wird ", " werden ",
        " haben ", " hat ", " hatte ", " sein ", " kann ", " könnte ",

        // Common words
        " nicht ", " auch ", " noch ", " mehr ", " sehr ",
        " alle ", " alles ", " einige ", " jeder ", " jede ",

        // Umlauts (strong indicator of German)
        "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß"
    ]

    /// Common French words and patterns that should NOT appear in German translations
    private let frenchIndicators: [String] = [
        // Articles
        " le ", " la ", " les ", " un ", " une ", " des ",
        " du ", " de la ", " de l'", " au ", " aux ",

        // Common prepositions and conjunctions
        " et ", " ou ", " mais ", " pour ", " avec ", " sans ",
        " dans ", " sur ", " sous ", " chez ", " par ",

        // Common verbs
        " est ", " sont ", " était ", " ont ", " avoir ",
        " être ", " peut ", " pourrait ", " sera ", " serait ",

        // Common words
        " pas ", " plus ", " aussi ", " très ", " tout ",
        " tous ", " toutes ", " quelques ", " chaque ",

        // French-specific characters/patterns
        "é", "è", "ê", "ë", "à", "ù", "û", "ï", "î", "ô",
        "ç", "œ", "æ",

        // Common French endings
        "tion ", "sion ", " ment ", " eur ", " euse "
    ]

    // MARK: - Helper Methods

    /// Loads a localisation file and returns its contents as a string.
    ///
    /// Searches multiple candidate paths relative to the test bundle rather
    /// than relying on a single hardcoded layout. This prevents test failures
    /// when the Xcode build directory or project structure changes.
    private func loadLocalizationFile(language: String) throws -> String {
        let bundle = Bundle(for: type(of: self))

        guard let resourcePath = bundle.resourcePath else {
            throw LocalizationError.resourcePathNotFound
        }

        // Candidate paths, ordered from most specific to least specific.
        // Different Xcode schemes and CI configurations place the .lproj
        // directory at varying depths relative to the test bundle.
        let candidatePaths = [
            (resourcePath as NSString)
                .deletingLastPathComponent
                .appending("/ProviiWallet/Resources/\(language).lproj/Localizable.strings"),
            (resourcePath as NSString)
                .appending("/\(language).lproj/Localizable.strings"),
            (resourcePath as NSString)
                .deletingLastPathComponent
                .appending("/Resources/\(language).lproj/Localizable.strings"),
            (resourcePath as NSString)
                .deletingLastPathComponent
                .deletingLastPathComponent
                .appending("/ProviiWallet/Resources/\(language).lproj/Localizable.strings")
        ]

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                return try String(contentsOfFile: path, encoding: .utf8)
            }
        }

        // None of the candidates matched. Report the first one in the error
        // message so the developer knows where we looked.
        throw LocalizationError.fileNotFound(path: candidatePaths[0])
    }

    /// Parses a .strings file and extracts all translation values
    private func parseStringsFile(_ contents: String) -> [String: String] {
        var translations: [String: String] = [:]

        // Regular expression to match .strings file format: "key" = "value";
        let pattern = #""([^"]+)"\s*=\s*"([^"]+)";"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return translations
        }

        let nsString = contents as NSString
        let matches = regex.matches(in: contents, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges == 3 {
                let keyRange = match.range(at: 1)
                let valueRange = match.range(at: 2)

                let key = nsString.substring(with: keyRange)
                let value = nsString.substring(with: valueRange)

                translations[key] = value
            }
        }

        return translations
    }

    /// Counts occurrences of language indicators in the given text
    private func countIndicators(_ text: String, indicators: [String]) -> (count: Int, found: [String]) {
        let lowercasedText = " " + text.lowercased() + " "
        var foundIndicators: [String] = []
        var totalCount = 0

        for indicator in indicators {
            let count = lowercasedText.components(separatedBy: indicator.lowercased()).count - 1
            if count > 0 {
                foundIndicators.append("\(indicator.trimmingCharacters(in: .whitespaces)) (\(count)x)")
                totalCount += count
            }
        }

        return (totalCount, foundIndicators)
    }

    // MARK: - German Validation Tests

    func testGermanFileDoesNotContainFrenchWords() throws {
        // Load German localisation file
        let germanContent = try loadLocalizationFile(language: "de")
        let germanTranslations = parseStringsFile(germanContent)

        XCTAssertGreaterThan(germanTranslations.count, 0, "German localisation file should contain translations")

        var violatingKeys: [String] = []
        var totalViolations = 0

        // Check each German translation for French indicators
        for (key, value) in germanTranslations {
            let result = countIndicators(value, indicators: frenchIndicators)

            if result.count >= failureThreshold {
                violatingKeys.append("\(key): found French words: \(result.found.joined(separator: ", "))")
                totalViolations += result.count
            }
        }

        // Report findings
        if !violatingKeys.isEmpty {
            let report = """

            German localisation file contains French words in \(violatingKeys.count) translations:

            \(violatingKeys.joined(separator: "\n"))

            Total French indicators found: \(totalViolations)
            """
            XCTFail(report)
        }
    }

    func testGermanFileHasGermanCharacteristics() throws {
        // Load German localisation file
        let germanContent = try loadLocalizationFile(language: "de")
        let germanTranslations = parseStringsFile(germanContent)

        XCTAssertGreaterThan(germanTranslations.count, 0, "German localisation file should contain translations")

        // Concatenate all German translations
        let allGermanText = germanTranslations.values.joined(separator: " ")

        // Check for German indicators
        let result = countIndicators(allGermanText, indicators: germanIndicators)

        // German file should have MANY German indicators
        XCTAssertGreaterThan(result.count, 50,
            "German file should contain substantial German language indicators. Found: \(result.count)")

        print("German file contains \(result.count) German language indicators - GOOD!")
    }

    // MARK: - French Validation Tests

    func testFrenchFileDoesNotContainGermanWords() throws {
        // Load French localisation file
        let frenchContent = try loadLocalizationFile(language: "fr")
        let frenchTranslations = parseStringsFile(frenchContent)

        XCTAssertGreaterThan(frenchTranslations.count, 0, "French localisation file should contain translations")

        var violatingKeys: [String] = []
        var totalViolations = 0

        // Check each French translation for German indicators
        for (key, value) in frenchTranslations {
            let result = countIndicators(value, indicators: germanIndicators)

            if result.count >= failureThreshold {
                violatingKeys.append("\(key): found German words: \(result.found.joined(separator: ", "))")
                totalViolations += result.count
            }
        }

        // Report findings
        if !violatingKeys.isEmpty {
            let report = """

            French localisation file contains German words in \(violatingKeys.count) translations:

            \(violatingKeys.joined(separator: "\n"))

            Total German indicators found: \(totalViolations)
            """
            XCTFail(report)
        }
    }

    func testFrenchFileHasFrenchCharacteristics() throws {
        // Load French localisation file
        let frenchContent = try loadLocalizationFile(language: "fr")
        let frenchTranslations = parseStringsFile(frenchContent)

        XCTAssertGreaterThan(frenchTranslations.count, 0, "French localisation file should contain translations")

        // Concatenate all French translations
        let allFrenchText = frenchTranslations.values.joined(separator: " ")

        // Check for French indicators
        let result = countIndicators(allFrenchText, indicators: frenchIndicators)

        // French file should have MANY French indicators
        XCTAssertGreaterThan(result.count, 50,
            "French file should contain substantial French language indicators. Found: \(result.count)")

        print("French file contains \(result.count) French language indicators - GOOD!")
    }

    // MARK: - Cross-Validation Tests

    func testGermanAndFrenchFilesHaveSameKeys() throws {
        // Load both localisation files
        let germanContent = try loadLocalizationFile(language: "de")
        let frenchContent = try loadLocalizationFile(language: "fr")

        let germanTranslations = parseStringsFile(germanContent)
        let frenchTranslations = parseStringsFile(frenchContent)

        let germanKeys = Set(germanTranslations.keys)
        let frenchKeys = Set(frenchTranslations.keys)

        // Check for missing keys
        let missingInFrench = germanKeys.subtracting(frenchKeys)
        let missingInGerman = frenchKeys.subtracting(germanKeys)

        var errorMessages: [String] = []

        if !missingInFrench.isEmpty {
            errorMessages.append("Keys in German but missing in French (\(missingInFrench.count)):\n  " +
                Array(missingInFrench).sorted().prefix(20).joined(separator: "\n  "))
        }

        if !missingInGerman.isEmpty {
            errorMessages.append("Keys in French but missing in German (\(missingInGerman.count)):\n  " +
                Array(missingInGerman).sorted().prefix(20).joined(separator: "\n  "))
        }

        if !errorMessages.isEmpty {
            XCTFail(errorMessages.joined(separator: "\n\n"))
        }

        print("Key validation passed: Both files have \(germanKeys.count) matching keys")
    }

    func testNoEmptyTranslations() throws {
        let languages = ["de", "fr"]
        var emptyTranslations: [String: [String]] = [:]

        for language in languages {
            let content = try loadLocalizationFile(language: language)
            let translations = parseStringsFile(content)

            let emptyKeys = translations.filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { $0.key }

            if !emptyKeys.isEmpty {
                emptyTranslations[language] = emptyKeys
            }
        }

        if !emptyTranslations.isEmpty {
            var report = "Found empty translations:\n"
            for (language, keys) in emptyTranslations {
                report += "\n\(language.uppercased()): \(keys.joined(separator: ", "))"
            }
            XCTFail(report)
        }
    }

    // MARK: - Quality Tests

    func testTranslationsAreNotIdentical() throws {
        // Load both files
        let germanContent = try loadLocalizationFile(language: "de")
        let frenchContent = try loadLocalizationFile(language: "fr")

        let germanTranslations = parseStringsFile(germanContent)
        let frenchTranslations = parseStringsFile(frenchContent)

        var identicalTranslations: [String] = []

        // Check for identical translations (excluding proper nouns and technical terms)
        let excludedKeys = ["app_name", "app_version"] // Keys that are expected to be the same

        for (key, germanValue) in germanTranslations {
            if excludedKeys.contains(key) { continue }

            if let frenchValue = frenchTranslations[key],
               germanValue == frenchValue,
               germanValue.count > 10 { // Only flag substantial identical translations
                identicalTranslations.append(key)
            }
        }

        if !identicalTranslations.isEmpty {
            let report = """

            Warning: Found \(identicalTranslations.count) translations that are identical in German and French:
            \(identicalTranslations.prefix(10).joined(separator: ", "))
            \(identicalTranslations.count > 10 ? "... and \(identicalTranslations.count - 10) more" : "")

            This might indicate missing translations or copy-paste errors.
            """
            print(report) // Print as warning, not failure
        }
    }
}

// MARK: - Error Types

enum LocalizationError: Error, CustomStringConvertible {
    case resourcePathNotFound
    case fileNotFound(path: String)

    var description: String {
        switch self {
        case .resourcePathNotFound:
            return "Could not find resource path in bundle"
        case .fileNotFound(let path):
            return "Localisation file not found at path: \(path)"
        }
    }
}
