// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.error

import android.content.Context
import app.provii.wallet.R
import app.provii.wallet.sdk.FfiException
import timber.log.Timber
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.inject.Inject
import javax.inject.Singleton
import javax.net.ssl.SSLException

/**
 * Centralised error handler that maps exceptions to user-facing messages. Categorises
 * errors by type (network, security, validation, SDK) and indicates whether the
 * operation is retryable. FFI exceptions from the Rust SDK are mapped through
 * [handleFfiException] to provide specific guidance to the user.
 */
@Singleton
class ErrorHandler
    @Inject
    constructor() {
        fun handleError(
            error: Throwable,
            context: Context,
        ): ErrorInfo {
            // Log error details (but not sensitive data)
            Timber.e(error, "Error occurred: ${error.javaClass.simpleName}")

            return when (error) {
                // Network errors
                is UnknownHostException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_no_internet),
                        errorType = ErrorType.NETWORK,
                        isRetryable = true,
                    )

                is SocketTimeoutException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_connection_timeout),
                        errorType = ErrorType.NETWORK,
                        isRetryable = true,
                    )

                is ConnectException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_unable_to_connect),
                        errorType = ErrorType.NETWORK,
                        isRetryable = true,
                    )

                is SSLException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_secure_connection_failed),
                        errorType = ErrorType.SECURITY,
                        isRetryable = false,
                    )

                // SDK errors - Using actual FfiException types
                is FfiException -> handleFfiException(error, context)

                // Security errors
                is SecurityException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_security_verification_failed),
                        errorType = ErrorType.SECURITY,
                        isRetryable = false,
                    )

                // Validation errors
                is IllegalArgumentException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_invalid_input),
                        errorType = ErrorType.VALIDATION,
                        isRetryable = false,
                    )

                is IllegalStateException ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_unexpected),
                        errorType = ErrorType.STATE,
                        isRetryable = false,
                    )

                // Default
                else ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_unexpected_try_again),
                        errorType = ErrorType.UNKNOWN,
                        isRetryable = true,
                    )
            }
        }

        private fun handleFfiException(
            error: FfiException,
            context: Context,
        ): ErrorInfo {
            return when (error) {
                is FfiException.InvalidFormat ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_invalid_data_format_short),
                        errorType = ErrorType.VALIDATION,
                        isRetryable = false,
                    )

                is FfiException.Storage ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_storage_check_device),
                        errorType = ErrorType.STORAGE,
                        isRetryable = false,
                    )

                is FfiException.Network ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_network_check_connection),
                        errorType = ErrorType.NETWORK,
                        isRetryable = true,
                    )

                is FfiException.Prover ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_proof_generation_failed_short),
                        errorType = ErrorType.PROOF,
                        isRetryable = true,
                    )

                is FfiException.OperationInProgress ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_operation_in_progress),
                        errorType = ErrorType.STATE,
                        isRetryable = false,
                    )

                is FfiException.OperationCancelled ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_operation_cancelled),
                        errorType = ErrorType.STATE,
                        isRetryable = true,
                    )

                is FfiException.NotInitialized ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_wallet_not_initialized),
                        errorType = ErrorType.STATE,
                        isRetryable = false,
                    )

                is FfiException.AgeRequirementNotMet ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_age_requirement_not_met),
                        errorType = ErrorType.VALIDATION,
                        isRetryable = false,
                    )

                is FfiException.BiometricNotAuthenticated ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_biometric_required),
                        errorType = ErrorType.STATE,
                        isRetryable = true,
                    )

                is FfiException.RetryBudgetExceeded ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_network_check_connection),
                        errorType = ErrorType.NETWORK,
                        isRetryable = true,
                    )

                is FfiException.RequestTimeout ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_connection_timeout_short),
                        errorType = ErrorType.NETWORK,
                        isRetryable = true,
                    )

                is FfiException.CredentialNotFound ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.wallet_error_credential_not_found),
                        errorType = ErrorType.STORAGE,
                        isRetryable = false,
                    )

                is FfiException.CredentialExpired ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.credential_expired_message),
                        errorType = ErrorType.VALIDATION,
                        isRetryable = false,
                    )

                is FfiException.SecurityViolation ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_security_verification_failed),
                        errorType = ErrorType.SECURITY,
                        isRetryable = false,
                    )

                is FfiException.Generic ->
                    ErrorInfo(
                        userMessage = context.getString(R.string.error_unexpected_try_again),
                        errorType = ErrorType.UNKNOWN,
                        isRetryable = true,
                    )
            }
        }

        data class ErrorInfo(
            val userMessage: String,
            val errorType: ErrorType,
            val isRetryable: Boolean,
            val actionLabel: String? = null,
        )

        enum class ErrorType {
            NETWORK,
            SECURITY,
            VALIDATION,
            STATE,
            STORAGE,
            PROOF,
            UNKNOWN,
        }
    }
