// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.privacy

import java.util.regex.Pattern

/**
 * Minimal error message sanitiser for UI display. Strips credential material and
 * email addresses from error strings before they are shown to the user. This is NOT
 * a logging interceptor; it exists solely to prevent accidental PII leakage into
 * user-visible error text.
 */
object ErrorSanitizer {
    private const val MASKED_EMAIL = "[email@redacted]"
    private const val MASKED_CREDENTIAL = "[credential-redacted]"

    private val EMAIL_PATTERN =
        Pattern.compile(
            "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            Pattern.CASE_INSENSITIVE,
        )

    private val CREDENTIAL_PATTERN =
        Pattern.compile(
            "eyJ[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+",
        )

    private val BASE64_FIELD_PATTERN =
        Pattern.compile(
            "\"(?:r_bits|commitment|credential|secret|key)\"\\s*:\\s*\"[A-Za-z0-9+/=]{32,}\"",
            Pattern.CASE_INSENSITIVE,
        )

    /**
     * Sanitise an error message for safe UI display.
     */
    fun sanitize(message: String): String {
        var result = message
        result = EMAIL_PATTERN.matcher(result).replaceAll(MASKED_EMAIL)
        result = CREDENTIAL_PATTERN.matcher(result).replaceAll(MASKED_CREDENTIAL)
        result = BASE64_FIELD_PATTERN.matcher(result).replaceAll(MASKED_CREDENTIAL)
        return result
    }
}
