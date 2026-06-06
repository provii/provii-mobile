/// Unit tests for PronunciationGuide verifying security term pronunciations (biometric,
/// YubiKey, FIDO2, NFC), acronym expansions, accessible phrases, and glossary integration.
import XCTest
@testable import ProviiWallet

class PronunciationGuideTests: XCTestCase {

    // MARK: - Pronunciation Tests

    func testBiometricPronunciation() {
        XCTAssertEqual(PronunciationGuide.pronounce("biometric"), "by-oh-metric")
        XCTAssertEqual(PronunciationGuide.pronounce("biometrics"), "by-oh-metrics")
    }

    func testYubiKeyPronunciation() {
        XCTAssertEqual(PronunciationGuide.pronounce("yubikey"), "you-bee-key")
        XCTAssertEqual(PronunciationGuide.pronounce("YubiKey"), "you-bee-key")
        XCTAssertEqual(PronunciationGuide.pronounce("yubico"), "you-bee-co")
    }

    func testAcronymPronunciations() {
        // Acronyms should be spelled out
        XCTAssertEqual(PronunciationGuide.pronounce("NFC"), "N F C")
        XCTAssertEqual(PronunciationGuide.pronounce("nfc"), "N F C")
        XCTAssertEqual(PronunciationGuide.pronounce("PIN"), "P I N")
        XCTAssertEqual(PronunciationGuide.pronounce("pin"), "P I N")
        XCTAssertEqual(PronunciationGuide.pronounce("API"), "A P I")
        XCTAssertEqual(PronunciationGuide.pronounce("URL"), "U R L")
        XCTAssertEqual(PronunciationGuide.pronounce("QR"), "Q R")
        XCTAssertEqual(PronunciationGuide.pronounce("ZKP"), "Z K P")
    }

    func testFIDOPronunciations() {
        XCTAssertEqual(PronunciationGuide.pronounce("FIDO2"), "fye-doh two")
        XCTAssertEqual(PronunciationGuide.pronounce("fido2"), "fye-doh two")
        XCTAssertEqual(PronunciationGuide.pronounce("FIDO"), "fye-doh")
    }

    func testCryptographicTerms() {
        XCTAssertEqual(PronunciationGuide.pronounce("cryptographic"), "crypto-graphic")
        XCTAssertEqual(PronunciationGuide.pronounce("HMAC"), "H-mac")
        XCTAssertEqual(PronunciationGuide.pronounce("hmac"), "H-mac")
    }

    func testFaceIDAndTouchID() {
        XCTAssertEqual(PronunciationGuide.pronounce("Face ID"), "Face I D")
        XCTAssertEqual(PronunciationGuide.pronounce("Touch ID"), "Touch I D")
    }

    func testUnknownTermPassthrough() {
        // Unknown terms should pass through unchanged
        XCTAssertEqual(PronunciationGuide.pronounce("unknown"), "unknown")
        XCTAssertEqual(PronunciationGuide.pronounce("random"), "random")
    }

    // MARK: - Expansion Tests

    func testCommonExpansions() {
        XCTAssertEqual(PronunciationGuide.expansion(for: "PIN"), "Personal Identification Number")
        XCTAssertEqual(PronunciationGuide.expansion(for: "NFC"), "Near Field Communication")
        XCTAssertEqual(PronunciationGuide.expansion(for: "FIDO2"), "Fast Identity Online version 2")
        XCTAssertEqual(PronunciationGuide.expansion(for: "API"), "Application Programming Interface")
        XCTAssertEqual(PronunciationGuide.expansion(for: "URL"), "Uniform Resource Locator")
        XCTAssertEqual(PronunciationGuide.expansion(for: "QR"), "Quick Response")
        XCTAssertEqual(PronunciationGuide.expansion(for: "HMAC"), "Hash-based Message Authentication Code")
        XCTAssertEqual(PronunciationGuide.expansion(for: "ZKP"), "Zero Knowledge Proof")
    }

    func testExpansionCaseInsensitive() {
        XCTAssertEqual(PronunciationGuide.expansion(for: "pin"), "Personal Identification Number")
        XCTAssertEqual(PronunciationGuide.expansion(for: "nfc"), "Near Field Communication")
    }

    func testUnknownExpansion() {
        XCTAssertNil(PronunciationGuide.expansion(for: "unknown"))
    }

    // MARK: - Accessibility Label Tests

    func testAccessibilityLabelWithExpansion() {
        let label = PronunciationGuide.accessibilityLabel(
            for: "PIN",
            fullExpansion: "Personal Identification Number"
        )
        XCTAssertTrue(label.contains("Personal Identification Number"))
        XCTAssertTrue(label.contains("P I N"))
    }

    func testAccessibilityLabelWithoutExpansion() {
        let label = PronunciationGuide.accessibilityLabel(for: "YubiKey")
        XCTAssertEqual(label, "you-bee-key")
    }

    // MARK: - Accessible Phrase Tests

    func testAccessiblePhraseWithSingleTerm() {
        let phrase = "Connect your YubiKey"
        let accessible = PronunciationGuide.accessiblePhrase(phrase, expandingTerms: ["YubiKey"])

        // Should contain pronunciation
        XCTAssertTrue(accessible.contains("you-bee-key"))
    }

    func testAccessiblePhraseWithMultipleTerms() {
        let phrase = "Use your YubiKey with NFC"
        let accessible = PronunciationGuide.accessiblePhrase(phrase, expandingTerms: ["YubiKey", "NFC"])

        // Should contain both pronunciations
        XCTAssertTrue(accessible.contains("you-bee-key"))
        XCTAssertTrue(accessible.contains("Near Field Communication"))
    }

    func testAccessiblePhraseWithPIN() {
        let phrase = "Enter your PIN"
        let accessible = PronunciationGuide.accessiblePhrase(phrase, expandingTerms: ["PIN"])

        // Should expand PIN
        XCTAssertTrue(accessible.contains("Personal Identification Number"))
        XCTAssertTrue(accessible.contains("P I N"))
    }

    // MARK: - Biometric Type Tests

    func testBiometricTypeNames() {
        XCTAssertEqual(PronunciationGuide.biometricType("Face ID"), "Face I D")
        XCTAssertEqual(PronunciationGuide.biometricType("Touch ID"), "Touch I D")
        XCTAssertEqual(PronunciationGuide.biometricType("biometric"), "by-oh-metric authentication")
    }

    func testBiometricActionLabel() {
        let label = PronunciationGuide.biometricActionLabel(type: "Face ID", action: "Authenticate")
        XCTAssertEqual(label, "Authenticate using Face I D")
    }

    // MARK: - Integration Tests

    func testGlossaryIntegration() {
        let glossary = Glossary.shared

        // Test that glossary entries have pronunciations
        let yubiKeyEntry = glossary.entry(for: "YubiKey")
        XCTAssertNotNil(yubiKeyEntry)
        XCTAssertEqual(yubiKeyEntry?.pronunciation, "you-bee-key")

        let nfcEntry = glossary.entry(for: "NFC")
        XCTAssertNotNil(nfcEntry)
        XCTAssertEqual(nfcEntry?.pronunciation, "N F C")

        let pinEntry = glossary.entry(for: "PIN")
        XCTAssertNotNil(pinEntry)
        XCTAssertEqual(pinEntry?.pronunciation, "P I N")
    }

    func testGlossaryAccessibilityLabels() {
        let glossary = Glossary.shared

        let yubiKeyEntry = glossary.entry(for: "YubiKey")
        XCTAssertNotNil(yubiKeyEntry)

        let accessibilityLabel = yubiKeyEntry?.accessibilityLabel ?? ""
        XCTAssertTrue(accessibilityLabel.contains("you-bee-key"))
        XCTAssertTrue(accessibilityLabel.contains("hardware security key"))
    }

    // MARK: - Performance Tests

    func testPronunciationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = PronunciationGuide.pronounce("YubiKey")
                _ = PronunciationGuide.pronounce("NFC")
                _ = PronunciationGuide.pronounce("FIDO2")
                _ = PronunciationGuide.pronounce("biometric")
            }
        }
    }

    func testAccessiblePhrasePerformance() {
        let phrase = "Connect your YubiKey using NFC and enter your PIN for FIDO2 authentication"
        let terms = ["YubiKey", "NFC", "PIN", "FIDO2"]

        measure {
            for _ in 0..<100 {
                _ = PronunciationGuide.accessiblePhrase(phrase, expandingTerms: terms)
            }
        }
    }
}
