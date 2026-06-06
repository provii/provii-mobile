// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import os.log

/// Centralised error handler that maps URLError, FfiError, NSError, and custom ProviiAppError
/// types to user friendly localised messages with retry and recovery guidance. Also provides
/// a SwiftUI ErrorAlert modifier for consistent error presentation across views.
class ErrorHandler {
    static let shared = ErrorHandler()

    private let logger = Logger(subsystem: "app.provii.wallet", category: "ErrorHandler")

    private init() {}

    // MARK: - Public Methods

    func handleError(_ error: Error) -> ErrorInfo {
        // Log error details (but not sensitive data)
        logger.error("Error occurred: \(String(describing: type(of: error))) - \(error.localizedDescription)")

        // Check for common error types first
        if let urlError = error as? URLError {
            return handleURLError(urlError)
        }

        // Check for SDK FFI errors
        if let ffiError = error as? FfiError {
            return handleFfiError(ffiError)
        }

        // Handle custom app errors before the NSError bridge. Every Swift Error
        // bridges to NSError via `as NSError?`, so the Cocoa catch-all below
        // would otherwise swallow ProviiAppError and misreport every case as a
        // generic retryable unknown.
        if let appError = error as? ProviiAppError {
            return handleAppError(appError)
        }

        // Check for common Cocoa errors
        if let nsError = error as NSError? {
            return handleNSError(nsError)
        }

        // Default handling
        return ErrorInfo(
            userMessage: LocalizedString.errorUnexpected.localized,
            errorType: .unknown,
            isRetryable: true
        )
    }

    // MARK: - Private Error Handlers

    private func handleURLError(_ error: URLError) -> ErrorInfo {
        switch error.code {
        case .notConnectedToInternet:
            return ErrorInfo(
                userMessage: LocalizedString.errorNoInternet.localized,
                errorType: .network,
                isRetryable: true
            )

        case .timedOut:
            return ErrorInfo(
                userMessage: LocalizedString.errorConnectionTimeout.localized,
                errorType: .network,
                isRetryable: true
            )

        case .cannotConnectToHost, .cannotFindHost:
            return ErrorInfo(
                userMessage: LocalizedString.errorUnableToConnect.localized,
                errorType: .network,
                isRetryable: true
            )

        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid:
            return ErrorInfo(
                userMessage: LocalizedString.errorSecureConnectionFailed.localized,
                errorType: .security,
                isRetryable: false
            )

        case .networkConnectionLost:
            return ErrorInfo(
                userMessage: LocalizedString.errorNetworkConnectionLost.localized,
                errorType: .network,
                isRetryable: true
            )

        case .dataNotAllowed:
            return ErrorInfo(
                userMessage: LocalizedString.errorCellularDataDisabled.localized,
                errorType: .network,
                isRetryable: false,
                actionLabel: LocalizedString.openSettings.localized
            )

        default:
            return ErrorInfo(
                userMessage: LocalizedString.errorNetworkGeneric.localized,
                errorType: .network,
                isRetryable: true
            )
        }
    }

    private func handleFfiError(_ error: FfiError) -> ErrorInfo {
        switch error {
        case .InvalidFormat(let msg):
            return loggedFfiError("InvalidFormat", msg: msg, type: .validation, retryable: false)
        case .Storage(let msg):
            return loggedFfiError("Storage", msg: msg, type: .storage, retryable: false)
        case .Network(let msg):
            return loggedFfiError("Network", msg: msg, type: .network, retryable: true)
        case .Prover(let msg):
            return loggedFfiError("Prover", msg: msg, type: .proof, retryable: true)
        case .RetryBudgetExceeded(let msg):
            return loggedFfiError("RetryBudgetExceeded", msg: msg, type: .network, retryable: true, message: LocalizedString.errorNetworkGeneric.localized)
        case .Generic(let msg):
            return loggedFfiError("Generic", msg: msg, type: .unknown, retryable: true)
        case .SecurityViolation(let msg):
            return loggedFfiError("SecurityViolation", msg: msg, type: .security, retryable: false)
        case .RequestTimeout, .CredentialNotFound, .CredentialExpired,
             .OperationInProgress, .OperationCancelled, .NotInitialized,
             .AgeRequirementNotMet, .BiometricNotAuthenticated:
            return handleFfiStateError(error)
        }
    }

    private func handleFfiStateError(_ error: FfiError) -> ErrorInfo {
        switch error {
        case .RequestTimeout(let seconds):
            return loggedFfiError("RequestTimeout", msg: "after \(seconds)s", type: .network, retryable: true, message: LocalizedString.errorConnectionTimeout.localized)
        case .CredentialNotFound:
            return ErrorInfo(userMessage: LocalizedString.errorAddCredentialFirst.localized, errorType: .credential, isRetryable: false)
        case .CredentialExpired:
            return ErrorInfo(userMessage: LocalizedString.errorCredentialExpiredGetNew.localized, errorType: .expiry, isRetryable: false)
        case .OperationInProgress:
            return ErrorInfo(userMessage: LocalizedString.errorOperationInProgress.localized, errorType: .state, isRetryable: false)
        case .OperationCancelled:
            return ErrorInfo(userMessage: LocalizedString.errorOperationCancelled.localized, errorType: .state, isRetryable: true)
        case .NotInitialized:
            return ErrorInfo(userMessage: LocalizedString.errorWalletNotReady.localized, errorType: .state, isRetryable: false)
        case .AgeRequirementNotMet:
            return ErrorInfo(userMessage: NSLocalizedString("error.age_requirement_not_met", comment: "Age requirement not met"), errorType: .validation, isRetryable: false)
        case .BiometricNotAuthenticated:
            return ErrorInfo(userMessage: LocalizedString.errorBiometricTryAgain.localized, errorType: .state, isRetryable: true)
        default:
            return ErrorInfo(userMessage: LocalizedString.errorUnexpected.localized, errorType: .unknown, isRetryable: false)
        }
    }

    private func loggedFfiError(
        _ label: String,
        msg: String,
        type: ErrorType,
        retryable: Bool,
        message: String? = nil
    ) -> ErrorInfo {
        SecureLogger.shared.error("FfiError.\(label): \(msg)")
        return ErrorInfo(
            userMessage: message ?? LocalizedString.errorUnexpected.localized,
            errorType: type,
            isRetryable: retryable
        )
    }

    private func handleNSError(_ error: NSError) -> ErrorInfo {
        // Handle common Cocoa error domains
        switch error.domain {
        case NSURLErrorDomain:
            // Already handled by URLError
            return handleURLError(URLError(URLError.Code(rawValue: error.code)))

        case NSCocoaErrorDomain:
            return handleCocoaError(error)

        case "kCLErrorDomain": // Core Location errors
            return ErrorInfo(
                userMessage: LocalizedString.errorLocationServices.localized,
                errorType: .validation,
                isRetryable: false
            )

        default:
            return ErrorInfo(
                userMessage: error.localizedDescription,
                errorType: .unknown,
                isRetryable: true
            )
        }
    }

    private func handleCocoaError(_ error: NSError) -> ErrorInfo {
        switch error.code {
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
            return ErrorInfo(
                userMessage: LocalizedString.errorFileNotFound.localized,
                errorType: .storage,
                isRetryable: false
            )

        case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
            return ErrorInfo(
                userMessage: LocalizedString.errorPermissionDenied.localized,
                errorType: .security,
                isRetryable: false
            )

        case NSFileWriteOutOfSpaceError:
            return ErrorInfo(
                userMessage: LocalizedString.errorNotEnoughStorage.localized,
                errorType: .storage,
                isRetryable: false,
                actionLabel: LocalizedString.manageStorage.localized
            )

        default:
            return ErrorInfo(
                userMessage: LocalizedString.errorFileOperationFailed.localized,
                errorType: .storage,
                isRetryable: true
            )
        }
    }

    private func mapHttpError(_ code: Int) -> ErrorInfo {
        switch code {
        case 403:
            return ErrorInfo(
                userMessage: LocalizedString.errorNotEligible.localized,
                errorType: .verification,
                isRetryable: false
            )
        case 404:
            return ErrorInfo(
                userMessage: LocalizedString.errorChallengeExpiredOrNotFound.localized,
                errorType: .verification,
                isRetryable: false
            )
        case 409:
            return ErrorInfo(
                userMessage: LocalizedString.errorRequestOutOfOrder.localized,
                errorType: .verification,
                isRetryable: true
            )
        case 410:
            return ErrorInfo(
                userMessage: LocalizedString.errorChallengeExpired.localized,
                errorType: .expiry,
                isRetryable: false
            )
        case 429:
            return ErrorInfo(
                userMessage: LocalizedString.errorTooManyRequests.localized,
                errorType: .rateLimit,
                isRetryable: true
            )
        case 500, 502, 503:
            return ErrorInfo(
                userMessage: LocalizedString.errorServerError.localized,
                errorType: .network,
                isRetryable: true
            )
        default:
            return ErrorInfo(
                userMessage: String(format: LocalizedString.errorRequestFailed.localized, code),
                errorType: .network,
                isRetryable: true
            )
        }
    }

    private func handleAppError(_ error: ProviiAppError) -> ErrorInfo {
        switch error {
        case .walletNotInitialized:
            return ErrorInfo(
                userMessage: LocalizedString.errorWalletNotReadyWait.localized,
                errorType: .wallet,
                isRetryable: true
            )

        case .credentialNotFound:
            return ErrorInfo(
                userMessage: LocalizedString.errorAddCredentialFirst.localized,
                errorType: .credential,
                isRetryable: false
            )

        case .credentialExpired:
            return ErrorInfo(
                userMessage: LocalizedString.errorCredentialExpiredGetNew.localized,
                errorType: .expiry,
                isRetryable: false,
                actionLabel: LocalizedString.getCredential.localized
            )

        case .biometricAuthFailed:
            return ErrorInfo(
                userMessage: LocalizedString.errorBiometricTryAgain.localized,
                errorType: .security,
                isRetryable: true
            )

        case .provingKeyNotFound:
            return ErrorInfo(
                userMessage: LocalizedString.errorRequiredFilesNotFound.localized,
                errorType: .storage,
                isRetryable: false,
                actionLabel: LocalizedString.retrySetup.localized
            )

        case .verificationFailed(let reason):
            return ErrorInfo(
                userMessage: String(format: LocalizedString.errorVerificationFailedWithReason.localized, reason),
                errorType: .verification,
                isRetryable: true
            )

        case .invalidQRCode:
            return ErrorInfo(
                userMessage: LocalizedString.errorInvalidQRCodeScanValid.localized,
                errorType: .validation,
                isRetryable: true
            )

        case .networkTimeout:
            return ErrorInfo(
                userMessage: LocalizedString.errorRequestTimedOut.localized,
                errorType: .network,
                isRetryable: true
            )
        }
    }

    // MARK: - Error Recovery

    func canRecover(from error: Error) -> Bool {
        let errorInfo = handleError(error)
        return errorInfo.isRetryable
    }

    func suggestedAction(for error: Error) -> ErrorAction? {
        let errorInfo = handleError(error)

        switch errorInfo.errorType {
        case .network:
            return .retry
        case .storage where errorInfo.actionLabel == "Manage Storage":
            return .openSettings
        case .credential, .expiry:
            return .navigate(to: "get_credential")
        case .state:
            return .restart
        case .security where errorInfo.actionLabel == "Open Settings":
            return .openSettings
        default:
            return errorInfo.isRetryable ? .retry : nil
        }
    }
}

// MARK: - Supporting Types

struct ErrorInfo {
    let userMessage: String
    let errorType: ErrorType
    let isRetryable: Bool
    let actionLabel: String?

    init(
        userMessage: String,
        errorType: ErrorType,
        isRetryable: Bool,
        actionLabel: String? = nil
    ) {
        self.userMessage = userMessage
        self.errorType = errorType
        self.isRetryable = isRetryable
        self.actionLabel = actionLabel
    }
}

enum ErrorType {
    case network
    case security
    case validation
    case state
    case wallet
    case credential
    case storage
    case expiry
    case revoked
    case rateLimit
    case verification
    case issuance
    case proof
    case sdk
    case unknown
}

enum ErrorAction {
    case retry
    case openSettings
    case navigate(to: String)
    case restart
    case dismiss
}

// MARK: - Custom App Errors

enum ProviiAppError: LocalizedError {
    case walletNotInitialized
    case credentialNotFound
    case credentialExpired
    case biometricAuthFailed
    case provingKeyNotFound
    case verificationFailed(reason: String)
    case invalidQRCode
    case networkTimeout

    var errorDescription: String? {
        switch self {
        case .walletNotInitialized:
            return NSLocalizedString("error.wallet.not_initialized", comment: "Wallet is not initialized error")
        case .credentialNotFound:
            return NSLocalizedString("error.credential.not_found", comment: "No credential found error")
        case .credentialExpired:
            return NSLocalizedString("error.credential.expired", comment: "Credential has expired error")
        case .biometricAuthFailed:
            return NSLocalizedString("error.biometric.auth_failed", comment: "Biometric authentication failed error")
        case .provingKeyNotFound:
            return NSLocalizedString("error.proving_key.not_found", comment: "Proving key not found error")
        case .verificationFailed(let reason):
            return String(format: NSLocalizedString("error.verification.failed_with_reason", comment: "Verification failed with reason error"), reason)
        case .invalidQRCode:
            return NSLocalizedString("error.qr_code.invalid_format", comment: "Invalid QR code format error")
        case .networkTimeout:
            return NSLocalizedString("error.network.timeout", comment: "Network request timed out error")
        }
    }
}

// MARK: - HTTP Error Type

struct ProviiHTTPError: Error {
    let code: Int
    let message: String?

    init(code: Int, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct ErrorAlert: ViewModifier {
    @Binding var error: Error?
    let handler = ErrorHandler.shared

    func body(content: Content) -> some View {
        content
            .alert(item: Binding<ErrorWrapper?>(
                get: { error.map(ErrorWrapper.init) },
                set: { _ in error = nil }
            )) { wrapper in
                let errorInfo = handler.handleError(wrapper.error)

                if errorInfo.isRetryable {
                    return Alert(
                        title: Text(NSLocalizedString("alert.error.title", comment: "Error alert title")),
                        message: Text(errorInfo.userMessage),
                        primaryButton: .default(Text(errorInfo.actionLabel ?? NSLocalizedString("alert.common.ok", comment: "OK button"))) {
                            if let action = handler.suggestedAction(for: wrapper.error) {
                                handleAction(action)
                            }
                        },
                        secondaryButton: .cancel(Text(NSLocalizedString("alert.common.cancel", comment: "Cancel button")))
                    )
                } else {
                    return Alert(
                        title: Text(NSLocalizedString("alert.error.title", comment: "Error alert title")),
                        message: Text(errorInfo.userMessage),
                        dismissButton: .default(Text(errorInfo.actionLabel ?? NSLocalizedString("alert.common.ok", comment: "OK button"))) {
                            if let action = handler.suggestedAction(for: wrapper.error) {
                                handleAction(action)
                            }
                        }
                    )
                }
            }
    }

    private func handleAction(_ action: ErrorAction) {
        switch action {
        case .retry:
            // Retry logic handled by the calling view
            break
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .navigate(let destination):
            // Navigation handled by the calling view
            #if DEBUG
            SecureLogger.shared.debug("Navigate to: \(destination)", redact: false)
            #endif
        case .restart:
            // App restart logic
            break
        case .dismiss:
            error = nil
        }
    }
}

// Helper wrapper for Identifiable conformance
private struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: Error
}

extension View {
    func errorAlert(error: Binding<Error?>) -> some View {
        self.modifier(ErrorAlert(error: error))
    }
}
