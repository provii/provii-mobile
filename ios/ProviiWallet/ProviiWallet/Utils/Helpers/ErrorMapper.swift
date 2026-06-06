// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Thin error to string mapper wrapping ErrorHandler for backward compatibility.
/// For full error handling with retry guidance, use ErrorHandler directly.
enum ErrorMapper {

    /// Map any error to a user-friendly message string
    static func mapToUserMessage(_ error: Error) -> String {
        return ErrorHandler.shared.handleError(error).userMessage
    }

    /// Map HTTP status codes to user messages
    static func mapHttpError(_ code: Int) -> String {
        let error = ProviiHTTPError(code: code)
        return ErrorHandler.shared.handleError(error).userMessage
    }

    /// Map verification-specific HTTP errors
    static func mapVerificationError(code: Int) -> String {
        switch code {
        case 403:
            return LocalizedString.errorNotEligible.localized
        case 404:
            return LocalizedString.errorChallengeExpiredOrNotFound.localized
        case 409:
            return LocalizedString.errorRequestOutOfOrder.localized
        case 410:
            return LocalizedString.errorChallengeExpired.localized
        default:
            return LocalizedString.errorVerificationFailed.localized
        }
    }

    /// Extract error code from various error types
    static func extractErrorCode(from error: Error) -> Int? {
        if let httpError = error as? ProviiHTTPError {
            return httpError.code
        }

        if let urlError = error as? URLError {
            return urlError.errorCode
        }

        if let nsError = error as NSError? {
            return nsError.code
        }

        return nil
    }
}
