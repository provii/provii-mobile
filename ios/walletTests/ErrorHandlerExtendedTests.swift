// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

/// Extended ErrorHandler tests to cover Cocoa errors, all ProviiAppError cases,
/// and the complete HTTP error mapping surface.
final class ErrorHandlerExtendedTests: XCTestCase {

    private let handler = ErrorHandler.shared

    // MARK: - Cocoa error domain via NSError

    func testCocoaFileNotFoundError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testCocoaNoPermissionError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testCocoaOutOfSpaceError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
        XCTAssertNotNil(info.actionLabel)
    }

    func testCocoaGenericFileError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 999)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testCoreLocationError() {
        let error = NSError(domain: "kCLErrorDomain", code: 1)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testGenericNSError() {
        let error = NSError(domain: "com.test.domain", code: 42)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    // MARK: - ProviiAppError complete coverage

    func testCredentialExpiredNotRetryable() {
        let error = ProviiAppError.credentialExpired
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testProvingKeyNotFoundNotRetryable() {
        let error = ProviiAppError.provingKeyNotFound
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
        XCTAssertNotNil(info.actionLabel)
    }

    func testVerificationFailedRetryable() {
        let error = ProviiAppError.verificationFailed(reason: "timeout")
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testInvalidQRCodeRetryable() {
        let error = ProviiAppError.invalidQRCode
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testNetworkTimeoutRetryable() {
        let error = ProviiAppError.networkTimeout
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    // MARK: - All ProviiAppError descriptions

    func testAllProviiAppErrorDescriptions() {
        let errors: [ProviiAppError] = [
            .walletNotInitialized, .credentialNotFound, .credentialExpired,
            .biometricAuthFailed, .provingKeyNotFound,
            .verificationFailed(reason: "test"), .invalidQRCode, .networkTimeout
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) must have a description")
        }
    }

    // MARK: - FfiError remaining cases

    func testFfiStorageNotRetryable() {
        let error = FfiError.Storage(msg: "disk full")
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testFfiProverRetryable() {
        let error = FfiError.Prover(msg: "witness error")
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiRetryBudgetExceeded() {
        let error = FfiError.RetryBudgetExceeded(msg: "5 of 5 used")
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiGenericRetryable() {
        let error = FfiError.Generic(msg: "something")
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiOperationCancelledRetryable() {
        let error = FfiError.OperationCancelled
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiNotInitializedNotRetryable() {
        let error = FfiError.NotInitialized
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testFfiAgeRequirementNotMetNotRetryable() {
        let error = FfiError.AgeRequirementNotMet
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    // MARK: - URLError remaining cases

    func testCannotConnectToHost() {
        let error = URLError(.cannotConnectToHost)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testNetworkConnectionLost() {
        let error = URLError(.networkConnectionLost)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testDataNotAllowed() {
        let error = URLError(.dataNotAllowed)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
        XCTAssertNotNil(info.actionLabel)
    }

    func testGenericURLError() {
        let error = URLError(.badURL)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testCertificateBadDate() {
        let error = URLError(.serverCertificateHasBadDate)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    // MARK: - Unknown error

    func testUnknownErrorDefaultsToRetryable() {
        struct CustomError: Error {}
        let info = handler.handleError(CustomError())
        XCTAssertTrue(info.isRetryable)
    }

    // MARK: - ErrorAction cases

    func testSuggestedActionForCredentialNotFound() {
        let error = ProviiAppError.credentialNotFound
        let action = handler.suggestedAction(for: error)
        if case .navigate = action {} else {
            XCTFail("Credential error should suggest navigation")
        }
    }

    func testSuggestedActionForCredentialExpired() {
        let error = ProviiAppError.credentialExpired
        let action = handler.suggestedAction(for: error)
        if case .navigate = action {} else {
            XCTFail("Expired credential should suggest navigation")
        }
    }

    // MARK: - ErrorMapper extended

    func testErrorMapperMapHttpError() {
        let msg = ErrorMapper.mapHttpError(500)
        XCTAssertFalse(msg.isEmpty)
    }

    func testErrorMapperVerificationError409() {
        let msg = ErrorMapper.mapVerificationError(code: 409)
        XCTAssertFalse(msg.isEmpty)
    }

    func testErrorMapperVerificationError404() {
        let msg = ErrorMapper.mapVerificationError(code: 404)
        XCTAssertFalse(msg.isEmpty)
    }
}
