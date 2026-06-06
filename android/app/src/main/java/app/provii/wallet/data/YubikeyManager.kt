// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import android.content.Context
import app.provii.wallet.R
import com.yubico.yubikit.android.YubiKitManager
import com.yubico.yubikit.android.transport.usb.UsbConfiguration
import com.yubico.yubikit.android.transport.usb.UsbYubiKeyDevice
import com.yubico.yubikit.core.util.Result
import com.yubico.yubikit.yubiotp.Slot
import com.yubico.yubikit.yubiotp.YubiOtpSession
import com.yubico.yubikit.core.application.CommandState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Manages USB YubiKey discovery and HMAC-SHA1 challenge-response operations. Listens for
 * USB device attach/detach events via [YubiKitManager] and exposes a reactive
 * [isYubikeyConnected] state flow. Challenge-response uses Slot 2 by default, pads input
 * to 64 bytes, and blocks on the device until the user touches the key (if touch is
 * configured). All YubiKey events are recorded through [AuditLogger].
 */
@Singleton
class YubikeyManager
    @Inject
    constructor(
        private val context: Context,
        private val auditLogger: app.provii.wallet.security.AuditLogger,
    ) {
        companion object {
            // HMAC-SHA1 challenge must be 64 bytes (or less if configured with UseSmallChallenge)
            private const val HMAC_CHALLENGE_SIZE = 64

            // Slot 2 is typically used for challenge-response
            private val CHALLENGE_RESPONSE_SLOT = Slot.TWO
        }

        private val yubiKitManager = YubiKitManager(context)
        private val _isYubikeyConnected = MutableStateFlow(false)
        val isYubikeyConnected: StateFlow<Boolean> = _isYubikeyConnected.asStateFlow()

        private var currentDevice: UsbYubiKeyDevice? = null

        init {
            setupUsbDiscovery()
        }

        private fun setupUsbDiscovery() {
            Timber.d("Setting up USB discovery")

            // Configure USB settings
            val usbConfiguration = UsbConfiguration()

            // Start USB discovery
            yubiKitManager.startUsbDiscovery(usbConfiguration) { device ->
                Timber.d("YubiKey connected via USB: ${device.usbDevice.deviceName}")
                currentDevice = device
                _isYubikeyConnected.value = true

                auditLogger.logYubiKeyEvent(
                    event = "connected",
                    details = "USB device: ${device.usbDevice.deviceName}",
                )

                // Set callback for when device is removed
                device.setOnClosed {
                    Timber.d("YubiKey disconnected")
                    currentDevice = null
                    _isYubikeyConnected.value = false

                    auditLogger.logYubiKeyEvent(
                        event = "disconnected",
                        details = null,
                    )
                }
            }
        }

        /**
         * Refresh the YubiKey connection by stopping USB discovery, clearing stale device
         * references, and restarting discovery. This ensures the next HMAC challenge uses
         * a fresh USB session rather than a potentially stale one.
         */
        fun refreshConnection() {
            Timber.d("Refreshing YubiKey connection")
            try {
                yubiKitManager.stopUsbDiscovery()
            } catch (e: Exception) {
                Timber.w("Error stopping USB discovery during refresh: ${e.message}")
            }
            currentDevice = null
            _isYubikeyConnected.value = false
            setupUsbDiscovery()
        }

        suspend fun performHmacChallenge(challenge: ByteArray): kotlin.Result<ByteArray> =
            withContext(Dispatchers.IO) {
                try {
                    Timber.d("Starting HMAC challenge-response")
                    Timber.d("Challenge size: ${challenge.size} bytes")

                    val device =
                        currentDevice
                            ?: return@withContext kotlin.Result.failure(Exception(context.getString(R.string.yubikey_error_no_key_connected)))

                    Timber.d("Device connected: ${device.usbDevice.deviceName}")

                    // Pad challenge to 64 bytes if necessary
                    val paddedChallenge =
                        if (challenge.size < HMAC_CHALLENGE_SIZE) {
                            Timber.d("Padding challenge from ${challenge.size} to $HMAC_CHALLENGE_SIZE bytes")
                            challenge + ByteArray(HMAC_CHALLENGE_SIZE - challenge.size)
                        } else {
                            challenge.take(HMAC_CHALLENGE_SIZE).toByteArray()
                        }

                    Timber.d("Padded challenge size: ${paddedChallenge.size}")

                    // Use suspendCancellableCoroutine to convert callback to suspension
                    val response =
                        suspendCancellableCoroutine<ByteArray> { continuation ->
                            Timber.d("Creating YubiOtpSession...")

                            YubiOtpSession.create(device) { result ->
                                try {
                                    Timber.d("YubiOtpSession.create callback invoked")

                                    if (result.isSuccess) {
                                        // Get the session using getValue() which will throw if error
                                        val session = result.getValue()
                                        Timber.d("YubiOtpSession created successfully")

                                        try {
                                            Timber.d("=== TOUCH YOUR YUBIKEY NOW - IT SHOULD BE BLINKING ===")
                                            Timber.d("Calling calculateHmacSha1 on slot ${CHALLENGE_RESPONSE_SLOT}")

                                            // Create a CommandState to monitor the touch requirement
                                            val commandState = CommandState()

                                            // This call BLOCKS until the user touches the key (if touch is required)
                                            // or completes immediately if no touch is required
                                            val hmacResponse =
                                                session.calculateHmacSha1(
                                                    CHALLENGE_RESPONSE_SLOT,
                                                    paddedChallenge,
                                                    commandState,
                                                )

                                            Timber.d("HMAC calculation complete! Got ${hmacResponse.size} bytes")

                                            auditLogger.logYubiKeyEvent(
                                                event = "hmac_challenge_success",
                                                details = "Challenge size: ${challenge.size} bytes, Response size: ${hmacResponse.size} bytes",
                                            )

                                            // Close the session
                                            try {
                                                session.close()
                                                Timber.d("Session closed successfully")
                                            } catch (e: Exception) {
                                                Timber.w("Error closing session: ${e.message}")
                                            }

                                            // Resume coroutine with success
                                            continuation.resume(hmacResponse)
                                        } catch (e: Exception) {
                                            Timber.e(e, "Error during HMAC calculation")
                                            Timber.e("Exception type: ${e.javaClass.simpleName}")
                                            Timber.e("Exception message: ${e.message}")

                                            // Log the failure
                                            auditLogger.logYubiKeyEvent(
                                                event = "hmac_challenge_failed",
                                                details = "Error: ${e.message}",
                                            )

                                            // Try to close session on error
                                            try {
                                                session.close()
                                            } catch (closeError: Exception) {
                                                Timber.e(closeError, "Error closing session after HMAC error")
                                            }

                                            // Provide more specific error messages
                                            val errorMessage =
                                                when {
                                                    e.message?.contains("timeout", ignoreCase = true) == true ->
                                                        context.getString(R.string.yubikey_error_timeout)
                                                    e.message?.contains("not supported", ignoreCase = true) == true ->
                                                        context.getString(R.string.yubikey_error_not_supported)
                                                    e.message?.contains("no such", ignoreCase = true) == true ->
                                                        context.getString(R.string.yubikey_error_no_slot)
                                                    else -> context.getString(R.string.yubikey_error_hmac_failed, e.message ?: "Unknown error")
                                                }

                                            continuation.resumeWithException(Exception(errorMessage, e))
                                        }
                                    } else {
                                        // Result is an error, try to get the exception
                                        Timber.e("Failed to create YubiOtpSession")
                                        try {
                                            // This will throw the contained exception
                                            result.getValue()
                                            // If we get here somehow, throw generic error
                                            continuation.resumeWithException(Exception("Unknown error creating session"))
                                        } catch (e: Exception) {
                                            Timber.e(e, "Session creation error: ${e.message}")
                                            continuation.resumeWithException(
                                                Exception(context.getString(R.string.yubikey_error_session_failed, e.message ?: "Unknown error"), e),
                                            )
                                        }
                                    }
                                } catch (e: Exception) {
                                    Timber.e(e, "Unexpected error in YubiOtpSession callback")
                                    continuation.resumeWithException(e)
                                }
                            }

                            // Handle cancellation
                            continuation.invokeOnCancellation {
                                Timber.d("HMAC challenge cancelled")
                            }
                        }

                    Timber.d("HMAC challenge successful")
                    kotlin.Result.success(response)
                } catch (e: Exception) {
                    Timber.e(e, "HMAC challenge failed: ${e.message}")
                    kotlin.Result.failure(e)
                }
            }

        fun cleanup() {
            try {
                Timber.d("Cleaning up YubiKey manager")
                yubiKitManager.stopUsbDiscovery()
                currentDevice?.close()
                currentDevice = null
                _isYubikeyConnected.value = false
            } catch (e: Exception) {
                Timber.e(e, "Error during cleanup")
            }
        }
    }
