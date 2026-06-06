// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class ValidatorsTests: XCTestCase {

    // MARK: - Birth Date Validation

    func testValidBirthDate() {
        let result = Validators.validateBirthDate("1990-06-15")
        XCTAssertTrue(result.isValid, "Valid past date must pass validation")
    }

    func testFutureBirthDateFails() {
        let future = "2090-01-01"
        let result = Validators.validateBirthDate(future)
        XCTAssertFalse(result.isValid, "Future birth date must fail validation")
    }

    func testMalformedBirthDateFails() {
        XCTAssertFalse(Validators.validateBirthDate("not-a-date").isValid)
        XCTAssertFalse(Validators.validateBirthDate("15/06/1990").isValid)
        XCTAssertFalse(Validators.validateBirthDate("").isValid)
    }

    func testExtremelyOldBirthDateFails() {
        let result = Validators.validateBirthDate("1800-01-01")
        XCTAssertFalse(result.isValid, "Birth date > 150 years ago must fail")
    }

    // MARK: - Age Calculation

    func testCalculateAgeFromValidDate() {
        // Use a date that is definitively old enough
        let age = Validators.calculateAge(from: "2000-01-01")
        XCTAssertNotNil(age, "Valid date must return an age")
        XCTAssertGreaterThanOrEqual(age!, 25, "Person born 2000-01-01 must be at least 25")
    }

    func testCalculateAgeFromInvalidDate() {
        let age = Validators.calculateAge(from: "garbage")
        XCTAssertNil(age, "Invalid date must return nil")
    }

    func testIsAtLeastAge() {
        XCTAssertTrue(Validators.isAtLeastAge(18, birthDate: "2000-01-01"))
        XCTAssertFalse(Validators.isAtLeastAge(18, birthDate: "2020-01-01"))
        XCTAssertFalse(Validators.isAtLeastAge(18, birthDate: "invalid"))
    }

    // MARK: - Officer ID Validation

    func testValidOfficerId() {
        XCTAssertTrue(Validators.validateOfficerId("ABC123").isValid)
        XCTAssertTrue(Validators.validateOfficerId("OFFICER1").isValid)
        XCTAssertTrue(Validators.validateOfficerId("A1B2C3D4E5F6").isValid)
    }

    func testOfficerIdTooShort() {
        XCTAssertFalse(Validators.validateOfficerId("ABC").isValid, "ID < 6 chars must fail")
    }

    func testOfficerIdTooLong() {
        XCTAssertFalse(Validators.validateOfficerId("ABCDEF1234567").isValid, "ID > 12 chars must fail")
    }

    func testOfficerIdEmptyFails() {
        XCTAssertFalse(Validators.validateOfficerId("").isValid)
        XCTAssertFalse(Validators.validateOfficerId("   ").isValid)
    }

    func testOfficerIdLowercaseFails() {
        XCTAssertFalse(Validators.validateOfficerId("abcdef").isValid, "Lowercase must fail (pattern requires A-Z0-9)")
    }

    func testOfficerIdSpecialCharsFails() {
        XCTAssertFalse(Validators.validateOfficerId("ABC-12").isValid)
        XCTAssertFalse(Validators.validateOfficerId("ABC 12").isValid)
    }

    // MARK: - Email Validation

    func testValidEmails() {
        XCTAssertTrue(Validators.validateEmail("user@example.com").isValid)
        XCTAssertTrue(Validators.validateEmail("a.b+c@domain.au").isValid)
    }

    func testInvalidEmails() {
        XCTAssertFalse(Validators.validateEmail("").isValid)
        XCTAssertFalse(Validators.validateEmail("notanemail").isValid)
        XCTAssertFalse(Validators.validateEmail("@domain.com").isValid)
    }

    // MARK: - URL Validation

    func testValidHttpsUrl() {
        XCTAssertTrue(Validators.validateURL("https://example.com").isValid)
    }

    func testHttpUrlFailsWhenHttpsRequired() {
        XCTAssertFalse(Validators.validateURL("http://example.com", requireHTTPS: true).isValid)
    }

    func testEmptyUrlFails() {
        XCTAssertFalse(Validators.validateURL("").isValid)
    }

    func testMissingSchemeFails() {
        XCTAssertFalse(Validators.validateURL("example.com").isValid)
    }

    // MARK: - ValidationResult

    func testValidationResultSuccess() {
        let result = Validators.ValidationResult.success
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidationResultError() {
        let result = Validators.ValidationResult.error("bad input")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "bad input")
    }

    func testValidationResultEquality() {
        XCTAssertEqual(Validators.ValidationResult.success, Validators.ValidationResult.success)
        XCTAssertEqual(
            Validators.ValidationResult.error("x"),
            Validators.ValidationResult.error("x")
        )
        XCTAssertNotEqual(
            Validators.ValidationResult.success,
            Validators.ValidationResult.error("x")
        )
    }
}
