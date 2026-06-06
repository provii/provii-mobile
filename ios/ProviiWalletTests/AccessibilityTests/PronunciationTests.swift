/// Unit tests for the PronunciationManager, verifying acronym expansion (QR, API, URL, ID,
/// iOS, mDL, PIN, UI), case insensitivity, multi-occurrence handling, and performance.
import XCTest
@testable import ProviiWallet

@MainActor
final class PronunciationTests: XCTestCase {

    var pronunciationManager: PronunciationManager!

    override func setUp() {
        super.setUp()
        pronunciationManager = PronunciationManager.shared
    }

    override func tearDown() {
        pronunciationManager = nil
        super.tearDown()
    }

    // MARK: - Basic Pronunciation Tests

    func testQRPronunciation() {
        let input = "Scan QR code"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("Q R"), "QR should be pronounced as 'Q R'")
    }

    func testAPIPronunciation() {
        let input = "Connect to API"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("A P I"), "API should be pronounced as 'A P I'")
    }

    func testURLPronunciation() {
        let input = "Visit this URL"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("U R L"), "URL should be pronounced as 'U R L'")
    }

    func testIDPronunciation() {
        let input = "Enter your ID"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("I D"), "ID should be pronounced as 'I D'")
    }

    func testiOSPronunciation() {
        let input = "iOS application"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("eye O S"), "iOS should be pronounced as 'eye O S'")
    }

    func testmDLPronunciation() {
        let input = "Your mDL credential"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("M D L"), "mDL should be pronounced as 'M D L'")
    }

    func testProviiPronunciation() {
        let input = "Welcome to Provii"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("par lee"), "Provii should be pronounced as 'par lee'")
    }

    func testPINPronunciation() {
        let input = "Enter PIN"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("P I N"), "PIN should be pronounced as 'P I N'")
    }

    func testUIPronunciation() {
        let input = "The UI is updated"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("U I"), "UI should be pronounced as 'U I'")
    }

    // MARK: - Context-Aware Tests

    func testQRScannerPhrase() {
        let input = "QR scanner ready"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("Q R scanner"), "QR scanner should be pronunciation-friendly")
    }

    func testScanQRPhrase() {
        let input = "scan QR code"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("scan Q R"), "scan QR should be pronunciation-friendly")
    }

    func testIDCardPhrase() {
        let input = "Show ID card"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("I D card"), "ID card should be pronunciation-friendly")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveQR() {
        let inputs = ["QR code", "qr code", "Qr Code", "QR Code"]
        for input in inputs {
            let output = pronunciationManager.applyPronunciation(to: input)
            XCTAssertTrue(output.contains("Q R"), "Should handle case variations for QR: \(input)")
        }
    }

    func testCaseInsensitiveAPI() {
        let inputs = ["API endpoint", "api endpoint", "Api Endpoint"]
        for input in inputs {
            let output = pronunciationManager.applyPronunciation(to: input)
            XCTAssertTrue(output.lowercased().contains("a p i"), "Should handle case variations for API: \(input)")
        }
    }

    // MARK: - Complex Sentence Tests

    func testComplexSentence() {
        let input = "Use the QR scanner to scan the QR code and connect to the API using your ID"
        let output = pronunciationManager.applyPronunciation(to: input)

        XCTAssertTrue(output.contains("Q R"), "Should pronounce QR correctly")
        XCTAssertTrue(output.contains("A P I"), "Should pronounce API correctly")
        XCTAssertTrue(output.contains("I D"), "Should pronounce ID correctly")
    }

    func testMultipleOccurrences() {
        let input = "QR QR QR"
        let output = pronunciationManager.applyPronunciation(to: input)
        // Count occurrences of "Q R"
        let count = output.components(separatedBy: "Q R").count - 1
        XCTAssertEqual(count, 3, "Should replace all occurrences")
    }

    // MARK: - Preservation Tests

    func testPreservesOtherText() {
        let input = "This is a normal sentence without acronyms"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertEqual(input, output, "Should not modify text without acronyms")
    }

    func testPreservesWhitespace() {
        let input = "QR   code   with   spaces"
        let output = pronunciationManager.applyPronunciation(to: input)
        XCTAssertTrue(output.contains("   "), "Should preserve extra whitespace")
    }

    // MARK: - Specific Term Tests

    func testGetPronunciation() {
        XCTAssertEqual(pronunciationManager.pronunciation(for: "QR"), "Q R")
        XCTAssertEqual(pronunciationManager.pronunciation(for: "API"), "A P I")
        XCTAssertEqual(pronunciationManager.pronunciation(for: "URL"), "U R L")
        XCTAssertEqual(pronunciationManager.pronunciation(for: "ID"), "I D")
        XCTAssertEqual(pronunciationManager.pronunciation(for: "iOS"), "eye O S")
        XCTAssertEqual(pronunciationManager.pronunciation(for: "mDL"), "M D L")
        XCTAssertEqual(pronunciationManager.pronunciation(for: "Provii"), "par lee")
    }

    func testHasPronunciation() {
        XCTAssertTrue(pronunciationManager.hasPronunciation(for: "QR"))
        XCTAssertTrue(pronunciationManager.hasPronunciation(for: "API"))
        XCTAssertTrue(pronunciationManager.hasPronunciation(for: "URL"))
        XCTAssertFalse(pronunciationManager.hasPronunciation(for: "RandomTerm"))
    }

    func testAllPronunciations() {
        let all = pronunciationManager.allPronunciations()
        XCTAssertTrue(all.count > 0, "Should have pronunciation entries")
        XCTAssertNotNil(all["QR"], "Should include QR")
        XCTAssertNotNil(all["API"], "Should include API")
        XCTAssertNotNil(all["URL"], "Should include URL")
    }

    // MARK: - String Extension Tests

    func testStringExtension() {
        let input = "Scan QR code"
        let output = input.pronunciationFriendly
        XCTAssertTrue(output.contains("Q R"), "String extension should work")
    }

    // MARK: - Real-World Usage Tests

    func testQRScannerLabel() {
        let label = "QR Code Scanner"
        let friendly = pronunciationManager.applyPronunciation(to: label)
        XCTAssertTrue(friendly.contains("Q R"), "Should make QR scanner label pronunciation-friendly")
    }

    func testIDVerificationLabel() {
        let label = "ID Verification Required"
        let friendly = pronunciationManager.applyPronunciation(to: label)
        XCTAssertTrue(friendly.contains("I D"), "Should make ID verification label pronunciation-friendly")
    }

    func testAPIErrorMessage() {
        let message = "API connection failed. Check your URL."
        let friendly = pronunciationManager.applyPronunciation(to: message)
        XCTAssertTrue(friendly.contains("A P I"), "Should make API pronunciation-friendly")
        XCTAssertTrue(friendly.contains("U R L"), "Should make URL pronunciation-friendly")
    }

    func testiOSAppLabel() {
        let label = "Provii Wallet for iOS"
        let friendly = pronunciationManager.applyPronunciation(to: label)
        XCTAssertTrue(friendly.contains("par lee"), "Should make Provii pronunciation-friendly")
        XCTAssertTrue(friendly.contains("eye O S"), "Should make iOS pronunciation-friendly")
    }

    // MARK: - Performance Tests

    func testPerformance() {
        let input = "QR API URL ID iOS mDL Provii"
        measure {
            for _ in 0..<1000 {
                _ = pronunciationManager.applyPronunciation(to: input)
            }
        }
    }

    func testLongTextPerformance() {
        let longText = String(repeating: "Use QR scanner to connect to API and verify your ID. ", count: 100)
        measure {
            _ = pronunciationManager.applyPronunciation(to: longText)
        }
    }
}
