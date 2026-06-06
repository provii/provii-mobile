// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Input validation utilities for birth dates, officer IDs, QR content, emails, and URLs.
/// Returns strongly typed ValidationResult values with localised error messages and
/// includes a SwiftUI ViewModifier for inline validation display.
enum Validators {

    // MARK: - Birth Date Validation

    /// Validate birth date format and ensure it is not in the future.
    static func validateBirthDate(_ birthDate: String) -> ValidationResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        // Keep en_US_POSIX ONLY for ISO 8601 parsing, not display
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = dateFormatter.date(from: birthDate) else {
            return .error(NSLocalizedString("error.validation.invalid_date_format", comment: "Invalid date format error"))
        }

        if date > Date() {
            return .error(NSLocalizedString("error.validation.birth_date_future", comment: "Birth date cannot be in the future error"))
        }

        // Optional: Check if person is too old (e.g., 150 years)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: date, to: Date())
        if let years = components.year, years > 150 {
            return .error(NSLocalizedString("error.validation.invalid_birth_date", comment: "Invalid birth date error"))
        }

        return .success
    }

    /// Calculate age from birth date.
    static func calculateAge(from birthDate: String) -> Int? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        // Keep en_US_POSIX ONLY for ISO 8601 parsing, not display
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = dateFormatter.date(from: birthDate) else {
            return nil
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: date, to: Date())
        return components.year
    }

    /// Check if person is at least a certain age.
    static func isAtLeastAge(_ minimumAge: Int, birthDate: String) -> Bool {
        guard let age = calculateAge(from: birthDate) else {
            return false
        }
        return age >= minimumAge
    }

    // MARK: - Officer ID Validation

    /// Validate officer ID format (6-12 uppercase alphanumeric characters).
    static func validateOfficerId(_ officerId: String) -> ValidationResult {
        let trimmedId = officerId.trimmingCharacters(in: .whitespacesAndNewlines)

        switch true {
        case trimmedId.isEmpty:
            return .error(NSLocalizedString("error.validation.officer_id_required", comment: "Officer ID is required error"))
        case trimmedId.count < 6:
            return .error(NSLocalizedString("error.validation.officer_id_too_short", comment: "Officer ID too short error"))
        case trimmedId.count > 12:
            return .error(NSLocalizedString("error.validation.officer_id_too_long", comment: "Officer ID too long error"))
        case !isValidOfficerIdFormat(trimmedId):
            return .error(NSLocalizedString("error.validation.officer_id_invalid_format", comment: "Invalid Officer ID format error"))
        default:
            return .success
        }
    }

    private static func isValidOfficerIdFormat(_ id: String) -> Bool {
        let pattern = "^[A-Z0-9]{6,12}$"
        return id.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - QR Content Validation

    /// Validate QR code content.
    static func validateQRContent(_ qrContent: String) -> ValidationResult {
        let trimmedContent = qrContent.trimmingCharacters(in: .whitespacesAndNewlines)

        switch true {
        case trimmedContent.isEmpty:
            return .error(NSLocalizedString("error.validation.qr_code_empty", comment: "Empty QR code error"))
        case trimmedContent.count > 10000:
            return .error(NSLocalizedString("error.validation.qr_code_too_large", comment: "QR code too large error"))
        case !QRUtils.isValidProviiQR(trimmedContent):
            return .error(NSLocalizedString("error.validation.qr_code_invalid", comment: "Invalid Provii Wallet QR code error"))
        default:
            return .success
        }
    }

    // MARK: - Email Validation (if needed in future)

    /// Validate email format.
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            return .error(NSLocalizedString("error.validation.email_required", comment: "Email is required error"))
        }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if emailPredicate.evaluate(with: trimmedEmail) {
            return .success
        } else {
            return .error(NSLocalizedString("error.validation.email_invalid_format", comment: "Invalid email format error"))
        }
    }

    // MARK: - URL Validation

    /// Validate URL format and scheme.
    static func validateURL(_ urlString: String, requireHTTPS: Bool = true) -> ValidationResult {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty else {
            return .error(NSLocalizedString("error.validation.url_required", comment: "URL is required error"))
        }

        guard let url = URL(string: trimmedURL) else {
            return .error(NSLocalizedString("error.validation.url_invalid_format", comment: "Invalid URL format error"))
        }

        guard let scheme = url.scheme else {
            return .error(NSLocalizedString("error.validation.url_missing_scheme", comment: "URL must include scheme error"))
        }

        if requireHTTPS && scheme != "https" {
            #if DEBUG
            // Allow localhost for development (debug builds only)
            if url.host == "localhost" || url.host == "127.0.0.1" {
                return .success
            }
            #endif
            return .error(NSLocalizedString("error.validation.url_must_use_https", comment: "URL must use HTTPS error"))
        }

        return .success
    }

    // MARK: - Validation Result

    enum ValidationResult: Equatable {
        case success
        case error(String)

        var isValid: Bool {
            switch self {
            case .success:
                return true
            case .error:
                return false
            }
        }

        var errorMessage: String? {
            switch self {
            case .success:
                return nil
            case .error(let message):
                return message
            }
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// ViewModifier for input validation.
struct ValidationModifier: ViewModifier {
    let validation: Validators.ValidationResult
    @State private var showError = false

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .foregroundColor(validation.isValid ? .primary : .red)

            if !validation.isValid, let errorMessage = validation.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

extension View {
    func validated(_ result: Validators.ValidationResult) -> some View {
        self.modifier(ValidationModifier(validation: result))
    }
}
