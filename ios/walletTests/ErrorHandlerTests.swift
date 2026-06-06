// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class ErrorHandlerTests: XCTestCase {

    private let handler = ErrorHandler.shared

    // MARK: - URLError mapping

    func testNoInternetMapsToRetryableNetwork() {
        let error = URLError(.notConnectedToInternet)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable, "No internet must be retryable")
    }

    func testTimeoutMapsToRetryableNetwork() {
        let error = URLError(.timedOut)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable, "Timeout must be retryable")
    }

    func testUntrustedCertificateNotRetryable() {
        let error = URLError(.serverCertificateUntrusted)
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable, "Cert errors must not be retryable")
    }

    // MARK: - FfiError mapping

    func testFfiInvalidFormatNotRetryable() {
        let error = FfiError.InvalidFormat(msg: "bad json")
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testFfiNetworkRetryable() {
        let error = FfiError.Network(msg: "timeout")
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiOperationInProgressNotRetryable() {
        let error = FfiError.OperationInProgress
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testFfiBiometricNotAuthenticatedRetryable() {
        let error = FfiError.BiometricNotAuthenticated
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiRequestTimeoutRetryable() {
        let error = FfiError.RequestTimeout(seconds: 30)
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testFfiCredentialNotFoundNotRetryable() {
        let error = FfiError.CredentialNotFound
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testFfiCredentialExpiredNotRetryable() {
        let error = FfiError.CredentialExpired
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testFfiSecurityViolationNotRetryable() {
        let error = FfiError.SecurityViolation(msg: "tampered")
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    // MARK: - ProviiAppError mapping

    func testWalletNotInitializedRetryable() {
        let error = ProviiAppError.walletNotInitialized
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    func testCredentialNotFoundNotRetryable() {
        let error = ProviiAppError.credentialNotFound
        let info = handler.handleError(error)
        XCTAssertFalse(info.isRetryable)
    }

    func testBiometricAuthFailedRetryable() {
        let error = ProviiAppError.biometricAuthFailed
        let info = handler.handleError(error)
        XCTAssertTrue(info.isRetryable)
    }

    // MARK: - ErrorMapper

    func testErrorMapperMapToUserMessage() {
        let error = URLError(.notConnectedToInternet)
        let message = ErrorMapper.mapToUserMessage(error)
        XCTAssertFalse(message.isEmpty, "Must return a user message")
    }

    func testErrorMapperVerificationErrors() {
        // 403 = not eligible
        let msg403 = ErrorMapper.mapVerificationError(code: 403)
        XCTAssertFalse(msg403.isEmpty)

        // 410 = expired
        let msg410 = ErrorMapper.mapVerificationError(code: 410)
        XCTAssertFalse(msg410.isEmpty)

        // 500 = generic
        let msg500 = ErrorMapper.mapVerificationError(code: 500)
        XCTAssertFalse(msg500.isEmpty)
    }

    func testErrorMapperExtractErrorCode() {
        let urlError = URLError(.timedOut)
        XCTAssertNotNil(ErrorMapper.extractErrorCode(from: urlError))

        let httpError = ProviiHTTPError(code: 404)
        XCTAssertEqual(ErrorMapper.extractErrorCode(from: httpError), 404)
    }

    // MARK: - ProviiHTTPError

    func testProviiHTTPErrorProperties() {
        let error = ProviiHTTPError(code: 500, message: "Internal Server Error")
        XCTAssertEqual(error.code, 500)
        XCTAssertEqual(error.message, "Internal Server Error")
    }

    // MARK: - CryptoError descriptions

    func testCryptoErrorDescriptions() {
        let errors: [CryptoError] = [
            .invalidKeySize,
            .ciphertextTooShort,
            .invalidFormat,
            .invalidBase64,
            .missingKey,
            .invalidEnvelope,
            .unsupportedAlgorithm("XYZ"),
            .invalidUTF8,
            .pinEncodingFailed,
            .keyDerivationFailed(-1),
            .randomGenerationFailed(-1)
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) must have a description")
        }
    }

    // MARK: - Recovery suggestion

    func testCanRecoverFromNetworkError() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertTrue(handler.canRecover(from: error))
    }

    func testSuggestedActionForNetworkError() {
        let error = URLError(.timedOut)
        let action = handler.suggestedAction(for: error)
        XCTAssertNotNil(action)
        if case .retry = action {} else {
            XCTFail("Network errors should suggest retry")
        }
    }
}
