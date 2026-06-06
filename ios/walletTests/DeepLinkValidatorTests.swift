// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class DeepLinkValidatorTests: XCTestCase {

    private let validator = DeepLinkValidator.shared

    // MARK: - Scheme validation

    func testAcceptsProviiScheme() {
        let url = URL(string: "provii://verify?d=abc")!
        let result = validator.validate(url)
        XCTAssertTrue(result.isAccepted, "provii:// scheme must be accepted")
    }

    func testAcceptsHttpsScheme() {
        let url = URL(string: "https://provii.app/verify?d=abc")!
        let result = validator.validate(url)
        XCTAssertTrue(result.isAccepted, "https:// scheme must be accepted")
    }

    func testRejectsHttpScheme() {
        let url = URL(string: "http://provii.app/verify?d=abc")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "http:// scheme must be rejected")
    }

    func testRejectsFtpScheme() {
        let url = URL(string: "ftp://provii.app/verify")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "ftp:// scheme must be rejected")
    }

    // MARK: - Host validation

    func testAcceptsProviiAppHost() {
        let url = URL(string: "https://provii.app/verify?d=test")!
        XCTAssertTrue(validator.validate(url).isAccepted)
    }

    func testAcceptsSandboxHost() {
        let url = URL(string: "https://sandbox.provii.app/verify?d=test")!
        XCTAssertTrue(validator.validate(url).isAccepted)
    }

    func testRejectsUntrustedHost() {
        let url = URL(string: "https://evil.com/verify?d=test")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Untrusted hosts must be rejected")
    }

    func testRejectsSuffixSpoofHost() {
        // evil-provii.app must NOT match provii.app
        let url = URL(string: "https://evil-provii.app/verify?d=test")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Suffix-spoof hosts must be rejected (subdomain boundary check)")
    }

    func testAcceptsSubdomainOfAllowedHost() {
        let url = URL(string: "https://sub.provii.app/verify?d=test")!
        let result = validator.validate(url)
        XCTAssertTrue(result.isAccepted, "Genuine subdomains of allowed hosts must be accepted")
    }

    // MARK: - Custom scheme path validation

    func testAcceptsVerifyPath() {
        let url = URL(string: "provii://verify?d=test")!
        XCTAssertTrue(validator.validate(url).isAccepted)
    }

    func testAcceptsAttestPath() {
        let url = URL(string: "provii://attest?d=test")!
        XCTAssertTrue(validator.validate(url).isAccepted)
    }

    func testRejectsUnknownPath() {
        let url = URL(string: "provii://unknown?d=test")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Unknown paths must be rejected")
    }

    func testRejectsEmptyPath() {
        // provii:// with no host/path
        let url = URL(string: "provii://")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Empty path must be rejected")
    }

    // MARK: - Sensitive operation blocking

    func testBlocksDeletePath() {
        let url = URL(string: "https://provii.app/delete")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "/delete must be blocked as sensitive operation")
    }

    func testBlocksAdminPath() {
        let url = URL(string: "https://provii.app/admin")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "/admin must be blocked as sensitive operation")
    }

    func testBlocksWalletResetPath() {
        let url = URL(string: "https://provii.app/wallet/reset")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "/wallet/reset must be blocked as sensitive operation")
    }

    // MARK: - Injection detection

    func testRejectsXSSInQueryParams() {
        let url = URL(string: "provii://verify?d=%3Cscript%3Ealert(1)%3C/script%3E")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "XSS patterns in query params must be rejected")
    }

    func testRejectsPathTraversal() {
        let url = URL(string: "provii://verify?d=../../etc/passwd")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Path traversal patterns must be rejected")
    }

    func testRejectsSQLInjection() {
        let url = URL(string: "provii://verify?d=1%27%20or%20%271%27%3D%271")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "SQL injection patterns must be rejected")
    }

    func testRejectsTemplateInjection() {
        let url = URL(string: "provii://verify?d=%24%7Btest%7D")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Template injection (${ }) must be rejected")
    }

    func testRejectsDoubleEncodedAttack() {
        // %252e%252e = double-encoded ".."
        let url = URL(string: "provii://verify?d=%252e%252e%252f")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Double-encoded path traversal must be rejected")
    }

    // MARK: - Parameter size limits

    func testRejectsOversizedParameter() {
        let longValue = String(repeating: "a", count: 2049)
        let url = URL(string: "provii://verify?d=\(longValue)")!
        let result = validator.validate(url)
        XCTAssertFalse(result.isAccepted, "Parameter values > 2048 chars must be rejected")
    }

    func testAcceptsParameterAtSizeLimit() {
        let okValue = String(repeating: "a", count: 2048)
        let url = URL(string: "provii://verify?d=\(okValue)")!
        let result = validator.validate(url)
        XCTAssertTrue(result.isAccepted, "Parameter values at exactly 2048 chars must be accepted")
    }

    // MARK: - DeepLinkValidationResult

    func testRejectionReasonAccessor() {
        let url = URL(string: "ftp://evil.com/hack")!
        let result = validator.validate(url)
        XCTAssertNotNil(result.rejectionReason, "Rejected result must have a reason")
    }

    func testAcceptedHasNoRejectionReason() {
        let url = URL(string: "provii://verify?d=test")!
        let result = validator.validate(url)
        XCTAssertNil(result.rejectionReason, "Accepted result must not have a rejection reason")
    }

    // MARK: - URL extension

    func testURLValidateAsDeepLinkExtension() {
        let url = URL(string: "provii://verify?d=test")!
        let result = url.validateAsDeepLink()
        XCTAssertTrue(result.isAccepted, "URL.validateAsDeepLink() must delegate to DeepLinkValidator")
    }
}
