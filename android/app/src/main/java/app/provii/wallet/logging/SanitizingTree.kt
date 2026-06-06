// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.logging

import timber.log.Timber
import java.util.regex.Pattern

/**
 * Custom Timber.Tree that redacts JWT tokens and base64 credential fields from debug
 * log output. ProGuard strips all Timber/Log calls in release builds, so this tree
 * only operates in debug configurations as a defence in depth measure against
 * accidental credential leakage to Logcat during development.
 */
class SanitizingTree : Timber.DebugTree() {
    private companion object {
        private const val MASKED_JWT = "[JWT-REDACTED]"
        private const val MASKED_CREDENTIAL = "[CREDENTIAL-REDACTED]"
        private const val MASKED_ID = "[ID-REDACTED]"

        private val JWT_PATTERN =
            Pattern.compile(
                "eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+",
            )

        private val BASE64_FIELD_PATTERN =
            Pattern.compile(
                "\"(?:r_bits|commitment|credential|secret|key)\"\\s*:\\s*\"[A-Za-z0-9+/=]{32,}\"",
                Pattern.CASE_INSENSITIVE,
            )

        // Credential IDs and similar identifiers that appear as JSON values
        // e.g. "credential_id": "abc123-def456-..."
        private val CREDENTIAL_ID_FIELD_PATTERN =
            Pattern.compile(
                "\"(?:credential_id|credentialId|officer_id|officerId)\"\\s*:\\s*\"([^\"]{5,})\"",
                Pattern.CASE_INSENSITIVE,
            )
    }

    override fun log(
        priority: Int,
        tag: String?,
        message: String,
        t: Throwable?,
    ) {
        val sanitised = redact(message)
        super.log(priority, tag, sanitised, t)
    }

    private fun redact(message: String): String {
        var result = JWT_PATTERN.matcher(message).replaceAll(MASKED_JWT)
        result = BASE64_FIELD_PATTERN.matcher(result).replaceAll(MASKED_CREDENTIAL)
        result = CREDENTIAL_ID_FIELD_PATTERN.matcher(result).replaceAll(MASKED_ID)
        return result
    }
}
