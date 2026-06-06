// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

import android.content.Context
import app.provii.wallet.R
import app.provii.wallet.sdk.FfiException
import retrofit2.HttpException
import java.net.UnknownHostException
import java.net.SocketTimeoutException

/**
 * Maps exceptions to localised, user-friendly error messages. Handles FFI errors
 * from the Rust SDK, HTTP errors from Retrofit, and standard JVM exceptions.
 * Verification-specific HTTP codes (403, 404, 409, 410) are mapped separately
 * via [mapVerificationError] to provide contextual guidance.
 */
object ErrorMapper {
    fun mapToUserMessage(
        error: Throwable,
        context: Context,
    ): String {
        return when (error) {
            is FfiException -> mapSdkError(error, context)
            is HttpException -> mapHttpError(error, context)
            is SecurityException -> context.getString(R.string.error_security)
            is UnknownHostException -> context.getString(R.string.error_no_internet_short)
            is SocketTimeoutException -> context.getString(R.string.error_connection_timeout_short)
            is IllegalArgumentException -> context.getString(R.string.error_invalid_input_provided)
            else -> context.getString(R.string.error_unexpected_try_again)
        }
    }

    private fun mapSdkError(
        error: FfiException,
        context: Context,
    ): String {
        return when (error) {
            is FfiException.InvalidFormat -> context.getString(R.string.error_invalid_data_format_short)
            is FfiException.Storage -> context.getString(R.string.error_storage_check_device)
            is FfiException.Network -> context.getString(R.string.error_network_check_connection)
            is FfiException.Prover -> context.getString(R.string.error_proof_generation_failed_short)
            is FfiException.OperationInProgress -> context.getString(R.string.error_operation_in_progress_short)
            is FfiException.OperationCancelled -> context.getString(R.string.error_operation_cancelled)
            is FfiException.NotInitialized -> context.getString(R.string.error_wallet_not_initialized)
            is FfiException.AgeRequirementNotMet -> context.getString(R.string.error_age_requirement_not_met)
            is FfiException.BiometricNotAuthenticated -> context.getString(R.string.error_biometric_required)
            is FfiException.RetryBudgetExceeded -> context.getString(R.string.error_network_check_connection)
            is FfiException.RequestTimeout -> context.getString(R.string.error_connection_timeout_short)
            is FfiException.CredentialNotFound -> context.getString(R.string.wallet_error_credential_not_found)
            is FfiException.CredentialExpired -> context.getString(R.string.credential_expired_message)
            is FfiException.SecurityViolation -> context.getString(R.string.error_security_verification_failed)
            is FfiException.Generic -> context.getString(R.string.error_unexpected_try_again)
        }
    }

    private fun mapHttpError(
        error: HttpException,
        context: Context,
    ): String {
        return when (error.code()) {
            403 -> context.getString(R.string.error_not_eligible)
            404 -> context.getString(R.string.error_challenge_expired)
            409 -> context.getString(R.string.error_request_out_of_order)
            410 -> context.getString(R.string.error_challenge_expired_scan_new)
            429 -> context.getString(R.string.error_too_many_requests)
            500, 502, 503 -> context.getString(R.string.error_server)
            else -> context.getString(R.string.error_request_failed, error.code())
        }
    }

    fun mapVerificationError(
        code: Int,
        context: Context,
    ): String {
        return when (code) {
            403 -> context.getString(R.string.error_not_eligible_short)
            404 -> context.getString(R.string.error_challenge_not_found)
            409 -> context.getString(R.string.error_complete_steps_in_order)
            410 -> context.getString(R.string.error_challenge_expired_short)
            else -> context.getString(R.string.verification_failed)
        }
    }
}
