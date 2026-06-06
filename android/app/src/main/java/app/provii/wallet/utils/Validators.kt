// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

import android.content.Context
import app.provii.wallet.R
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * Input validation helpers for the Provii Wallet. Validates birth dates against
 * ISO 8601 format with a future-date check, officer IDs against the expected
 * alphanumeric pattern, and QR code content for size and emptiness constraints.
 * All error messages are resolved from localised string resources.
 */
object Validators {
    // Keep for DOB validation
    fun validateBirthDate(
        context: Context,
        birthDate: String,
    ): ValidationResult {
        return try {
            val date = LocalDate.parse(birthDate, DateTimeFormatter.ISO_LOCAL_DATE)
            if (date.isAfter(LocalDate.now())) {
                ValidationResult.Error(context.getString(R.string.validation_error_birth_date_future))
            } else {
                ValidationResult.Success
            }
        } catch (e: Exception) {
            ValidationResult.Error(context.getString(R.string.validation_error_invalid_date_format))
        }
    }

    // Keep for officer ID
    fun validateOfficerId(
        context: Context,
        officerId: String,
    ): ValidationResult {
        return when {
            officerId.length < 6 -> ValidationResult.Error(context.getString(R.string.validation_error_officer_id_too_short))
            !officerId.matches(Regex("^[A-Z0-9]{6,12}$")) ->
                ValidationResult.Error(context.getString(R.string.validation_error_invalid_officer_id_format))
            else -> ValidationResult.Success
        }
    }

    // Delete PIN validation (not used)
    // Simplify QR validation
    fun validateQrContent(
        context: Context,
        qrContent: String,
    ): ValidationResult {
        return when {
            qrContent.isBlank() -> ValidationResult.Error(context.getString(R.string.validation_error_empty_qr_code))
            qrContent.length > 10000 -> ValidationResult.Error(context.getString(R.string.validation_error_qr_code_too_large))
            else -> ValidationResult.Success
        }
    }

    sealed class ValidationResult {
        object Success : ValidationResult()

        data class Error(val message: String) : ValidationResult()
    }
}
