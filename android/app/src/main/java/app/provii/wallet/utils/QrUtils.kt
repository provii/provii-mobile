// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

import android.net.Uri
import android.util.Base64
import app.provii.wallet.BuildConfig
import app.provii.wallet.config.EnvironmentManager
import timber.log.Timber
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString

/**
 * Utilities for parsing, validating, and generating Provii Wallet QR code payloads.
 * Supports the provii://verify?d= deep link format as well as raw JSON for
 * development use. Validates base64url field lengths, character sets, and HTTPS
 * requirements in all environments (localhost excepted in DEBUG builds).
 */
object QrUtils {
    private const val PROVIIWALLET_SCHEME = "provii://"
    private const val VERIFY_HOST = "verify"

    private val json =
        Json {
            ignoreUnknownKeys = true
            isLenient = true
        }

    @Serializable
    data class QrChallengePayload(
        val challenge_id: String,
        val rp_challenge: String, // 32B base64url - must be 43 chars
        val cutoff_days: Int,
        val verifying_key_id: UInt,
        val submit_secret: String, // 32B base64url - must be 43 chars
        val verify_url: String? = null,
        val expires_at: ULong? = null,
        val proof_direction: String? = null, // "over_age" or "under_age"
    ) {
        override fun toString(): String =
            "QrChallengePayload(challenge_id=$challenge_id, rp_challenge=$rp_challenge, cutoff_days=$cutoff_days, verifying_key_id=$verifying_key_id, submit_secret=[REDACTED])"
    }

    /**
     * Parse QR content or deep link
     */
    fun parseQrContent(qrContent: String): QrChallengePayload? {
        return try {
            when {
                // New format: provii://verify?d=<base64url>
                qrContent.startsWith("$PROVIIWALLET_SCHEME$VERIFY_HOST?d=") -> {
                    val base64Part =
                        qrContent.substringAfter("d=")
                            .substringBefore("&") // Handle any additional params

                    val jsonStr = base64UrlDecode(base64Part)
                    Timber.d("Decoded QR payload (challenge_id present: ${jsonStr.contains("challenge_id")})")
                    val payload = json.decodeFromString<QrChallengePayload>(jsonStr)

                    // Validate field lengths
                    validatePayload(payload)
                    payload
                }

                // Raw JSON format (for development/testing)
                qrContent.trim().startsWith("{") -> {
                    Timber.d("Parsing raw JSON QR (environment: ${EnvironmentManager.getCurrentEnvironment()})")
                    val payload = json.decodeFromString<QrChallengePayload>(qrContent)
                    validatePayload(payload)
                    payload
                }

                else -> {
                    Timber.w("Unsupported QR format (len=%d): %.20s...", qrContent.length, qrContent)
                    null
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to parse QR content")
            null
        }
    }

    /**
     * Generate QR content for sharing (if needed)
     */
    fun generateQrContent(payload: QrChallengePayload): String {
        val jsonStr = json.encodeToString(payload)
        val base64 = base64UrlEncode(jsonStr)
        return "$PROVIIWALLET_SCHEME$VERIFY_HOST?d=$base64"
    }

    /**
     * Validate QR payload according to spec
     */
    private fun validatePayload(payload: QrChallengePayload) {
        // 32-byte values must be exactly 43 characters in base64url
        require(payload.rp_challenge.length == 43) {
            "Invalid rp_challenge length: ${payload.rp_challenge.length}, expected 43"
        }
        require(payload.submit_secret.length == 43) {
            "Invalid submit_secret length: ${payload.submit_secret.length}, expected 43"
        }

        // Validate base64url alphabet (no +, /, or padding)
        require(isValidBase64Url(payload.rp_challenge)) {
            "rp_challenge contains invalid base64url characters"
        }
        require(isValidBase64Url(payload.submit_secret)) {
            "submit_secret contains invalid base64url characters"
        }

        // Validate URL if present - enforce HTTPS unconditionally
        payload.verify_url?.let { url ->
            val uri = Uri.parse(url)
            val scheme = uri.scheme?.lowercase()
            val host = uri.host?.lowercase() ?: ""
            val isLocalhost = BuildConfig.DEBUG && (host == "localhost" || host == "127.0.0.1" || host == "10.0.2.2")
            if (!isLocalhost && scheme != "https") {
                throw IllegalArgumentException("verify_url must use HTTPS")
            }
        }
    }

    /**
     * Check if string uses valid base64url alphabet
     */
    private fun isValidBase64Url(str: String): Boolean {
        // Base64url uses only A-Z, a-z, 0-9, -, _ (no +, /, or =)
        return str.matches(Regex("^[A-Za-z0-9_-]+$"))
    }

    /**
     * Base64 URL decode (no padding, URL-safe characters)
     */
    fun base64UrlDecode(input: String): String {
        val bytes = Base64.decode(input, Base64.URL_SAFE or Base64.NO_PADDING)
        return String(bytes, Charsets.UTF_8)
    }

    /**
     * Base64 URL encode (no padding, URL-safe characters)
     */
    fun base64UrlEncode(input: String): String {
        val bytes = input.toByteArray(Charsets.UTF_8)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING)
    }

    /**
     * Check if a string is a valid Provii Wallet QR/deeplink
     */
    fun isValidProviiQr(content: String): Boolean {
        return content.startsWith("$PROVIIWALLET_SCHEME$VERIFY_HOST?d=") ||
            (content.trim().startsWith("{") && content.contains("\"challenge_id\""))
    }

    /**
     * Extract verification URL from QR payload
     * Returns environment-specific URL if not present in the payload
     */
    fun extractVerifyUrl(qrContent: String): String? {
        val payload = parseQrContent(qrContent)
        // If verify_url is missing, use environment-specific default
        return payload?.verify_url ?: run {
            if (payload != null) {
                EnvironmentManager.getVerifierVerifyUrl()
            } else {
                null
            }
        }
    }
}
