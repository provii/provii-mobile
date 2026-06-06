// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security

import android.content.Context
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKey
import app.provii.wallet.BuildConfig
import app.provii.wallet.logging.redactId
import timber.log.Timber
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import dagger.hilt.android.qualifiers.ApplicationContext

/**
 * MASVS-STORAGE compliant audit logger that encrypts all log entries at rest using
 * AES-256-GCM via Android's security-crypto library. Entries are stored as newline-delimited
 * JSON in an encrypted app-private file. The logger redacts sensitive identifiers before
 * writing to Logcat and performs automatic log rotation when the file exceeds 5 MB or
 * 10,000 entries.
 */
@Singleton
class AuditLogger
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
    ) {
        companion object {
            private const val AUDIT_LOG_FILENAME = "audit_encrypted.log"
            private const val AUDIT_LOG_TEMP_FILENAME = "audit_encrypted_temp.log"
            private const val MAX_LOG_SIZE_BYTES = 5 * 1024 * 1024 // 5MB
            private const val MAX_LOG_ENTRIES = 10000
        }

        // DateTimeFormatter is thread-safe, unlike SimpleDateFormat which
        // would require synchronisation or ThreadLocal in this singleton.
        private val dateFormat: DateTimeFormatter =
            DateTimeFormatter
                .ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                .withZone(ZoneOffset.UTC)

        // / All mutable state (file I/O in persistLog, readEncryptedLogContent,
        // writeEncryptedLogContent) must be synchronised. EncryptedFile operations are not
        // thread-safe, and concurrent read-modify-write cycles can corrupt the log file.
        private val logLock = Any()

        /**
         * Get or create the MasterKey for encrypting audit logs.
         * Uses AES-256-GCM encryption scheme.
         */
        private fun getMasterKey(): MasterKey {
            return MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
        }

        /**
         * Create an EncryptedFile instance for the given file.
         * Each file is encrypted with AES-256-GCM using the app's MasterKey.
         */
        private fun getEncryptedFile(file: File): EncryptedFile {
            return EncryptedFile.Builder(
                context,
                file,
                getMasterKey(),
                EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB,
            ).build()
        }

        fun logWebAuthnAuthentication(
            officerId: String,
            credentialId: String,
            success: Boolean,
        ) {
            val event = if (success) "webauthn_auth_success" else "webauthn_auth_failure"
            // SECURITY: Redact officer ID and credential ID before logging.
            // Officer IDs and credential IDs are sensitive and MUST NOT appear
            // in Logcat, even in debug builds (audit finding HIGH).
            val redactedOfficerId = redactId(officerId)
            val redactedCredentialId = redactId(credentialId)

            val data =
                mapOf(
                    "officer_id" to redactedOfficerId,
                    "credential_id" to redactedCredentialId,
                    "success" to success,
                )

            if (success) {
                Timber.d("Officer authenticated via WebAuthn: %s", redactedOfficerId)
            } else {
                Timber.w("WebAuthn authentication failed for officer: %s", redactedOfficerId)
            }

            persistLog(event, data)
        }

        fun logCredentialIssuance(
            officerId: String?,
            requestId: String,
            issuerKid: String,
            success: Boolean,
            error: String? = null,
        ) {
            // SECURITY: Redact all IDs before logging to Logcat.
            // Officer IDs, request IDs, and key IDs are sensitive and MUST NOT
            // appear in full in Logcat, even in debug builds (audit finding HIGH).
            val redactedIssuer = redactId(officerId ?: "self-service")
            val redactedRequestId = redactId(requestId)
            val redactedKid = redactId(issuerKid)

            val event = if (success) "credential_issuance_success" else "credential_issuance_failure"
            val data =
                mutableMapOf(
                    "officer_id" to redactedIssuer,
                    "request_id" to redactedRequestId,
                    "issuer_kid" to redactedKid,
                    "success" to success,
                )

            error?.let { data["error"] = it }

            if (success) {
                Timber.d("Credential issued: requestId=%s, issuer=%s, kid=%s", redactedRequestId, redactedIssuer, redactedKid)
            } else {
                Timber.e("Credential issuance failed: %s", error ?: "unknown")
            }

            persistLog(event, data)
        }

        fun logVerificationAttempt(
            credentialId: String,
            challengeId: String,
            verifyUrl: String,
            result: String,
        ) {
            // SECURITY: Redact credential and challenge IDs in Logcat output.
            val redactedCredentialId = redactId(credentialId)
            val redactedChallengeId = redactId(challengeId)

            val data =
                mapOf(
                    "credential_id" to redactedCredentialId,
                    "challenge_id" to redactedChallengeId,
                    "verify_url" to verifyUrl,
                    "result" to result,
                )

            Timber.d("Verification: credentialId=%s, challenge=%s, result=%s", redactedCredentialId, redactedChallengeId, result)
            persistLog("verification_attempt", data)
        }

        fun logDeepLink(
            scheme: String,
            action: String,
            details: Map<String, Any?> = emptyMap(),
        ) {
            val data =
                mutableMapOf<String, Any?>(
                    "scheme" to scheme,
                    "action" to action,
                )
            data.putAll(details)

            Timber.d("Deep link received: $scheme://$action")
            persistLog("deeplink_received", data)
        }

        fun logYubiKeyEvent(
            event: String,
            details: String? = null,
        ) {
            val data =
                mutableMapOf<String, Any>(
                    "event" to event,
                )
            details?.let { data["details"] = it }

            Timber.d("YubiKey event: $event ${details?.let { "- $it" } ?: ""}")
            persistLog("yubikey_event", data)
        }

        /**
         * Log a Keystore-backed encrypted preferences recovery event. Called when
         * EncryptedSharedPreferences fails to open and the file is deleted and recreated.
         *
         * @param prefsName The SharedPreferences file name that was recovered.
         * @param errorMessage The exception message from the original failure, truncated to 200 chars.
         */
        fun logEncryptedPrefsRecovery(
            prefsName: String,
            errorMessage: String,
        ) {
            val truncated = errorMessage.take(200)
            val data =
                mapOf(
                    "prefs_name" to prefsName,
                    "error_message" to truncated,
                )
            Timber.w("Encrypted prefs recovery: prefs=%s", prefsName)
            persistLog("encrypted_prefs_recovery", data)
        }

        /**
         * Persist audit log entry to encrypted app-private file.
         * Format: JSON lines (newline-delimited JSON), encrypted at rest.
         *
         * MASVS-STORAGE: Uses EncryptedFile with AES-256-GCM to protect audit data.
         */
        private fun persistLog(
            event: String,
            data: Map<String, Any?>,
        ) {
            synchronized(logLock) {
                try {
                    // Create log entry as JSON
                    val logEntry =
                        JSONObject().apply {
                            put("timestamp", dateFormat.format(Instant.now()))
                            put("timestamp_ms", System.currentTimeMillis())
                            put("event", event)
                            put("data", JSONObject(data.filterValues { it != null }))
                        }

                    // Read existing entries (if file exists), append new entry, re-encrypt
                    val existingContent = readEncryptedLogContent()
                    val newContent =
                        if (existingContent.isNotEmpty()) {
                            "$existingContent\n$logEntry"
                        } else {
                            logEntry.toString()
                        }

                    // Check if rotation is needed (based on entry count or size)
                    val lines = newContent.lines()
                    val contentToWrite =
                        if (lines.size > MAX_LOG_ENTRIES || newContent.length > MAX_LOG_SIZE_BYTES) {
                            // Keep only the most recent half of entries
                            lines.takeLast(lines.size / 2).joinToString("\n")
                        } else {
                            newContent
                        }

                    // Write encrypted content
                    writeEncryptedLogContent(contentToWrite)

                    Timber.v("Audit log persisted: $event")
                } catch (e: Exception) {
                    Timber.e(e, "Failed to persist audit log entry: $event")
                }
            }
        }

        /**
         * Read the current encrypted log content.
         * Returns empty string if file doesn't exist or can't be read.
         */
        private fun readEncryptedLogContent(): String {
            val logFile = File(context.filesDir, AUDIT_LOG_FILENAME)
            if (!logFile.exists()) {
                return ""
            }

            return try {
                val encryptedFile = getEncryptedFile(logFile)
                encryptedFile.openFileInput().use { inputStream ->
                    inputStream.bufferedReader().use { reader ->
                        reader.readText()
                    }
                }
            } catch (e: Exception) {
                Timber.w(e, "Failed to read encrypted audit log, starting fresh")
                // If we can't decrypt (e.g., key rotated), start fresh
                logFile.delete()
                ""
            }
        }

        /**
         * Write content to the encrypted log file.
         * Overwrites existing content (for atomic write with encryption).
         */
        private fun writeEncryptedLogContent(content: String) {
            val logFile = File(context.filesDir, AUDIT_LOG_FILENAME)
            val tempFile = File(context.filesDir, AUDIT_LOG_TEMP_FILENAME)

            // Delete temp file if it exists from a previous failed write
            if (tempFile.exists()) {
                tempFile.delete()
            }

            // Write to temp file first (atomic write pattern)
            val encryptedTempFile = getEncryptedFile(tempFile)
            encryptedTempFile.openFileOutput().use { outputStream ->
                outputStream.write(content.toByteArray(Charsets.UTF_8))
                outputStream.flush()
            }

            // Atomically replace the log file. On the same filesystem (context.filesDir),
            // POSIX rename replaces the destination without a data-loss window, so no
            // pre-delete is required. If rename fails (e.g. cross-device edge case),
            // fall back to copy-then-delete.
            if (!tempFile.renameTo(logFile)) {
                Timber.w("AuditLogger: atomic rename failed, falling back to copy-then-delete")
                tempFile.inputStream().use { input ->
                    logFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                tempFile.delete()
            }
        }

        /**
         * Get audit log contents for debugging/export.
         * Returns decrypted content; use with care.
         *
         * Restricted to debug builds only. Release builds return an empty
         * string to prevent exfiltration of decrypted audit data via reflection or
         * instrumentation.
         */
        @JvmSynthetic
        internal fun getAuditLog(): String {
            if (!BuildConfig.DEBUG) {
                Timber.w("getAuditLog() called in release build, returning empty")
                return ""
            }
            return synchronized(logLock) {
                try {
                    readEncryptedLogContent()
                } catch (e: Exception) {
                    Timber.e(e, "Failed to read audit log")
                    ""
                }
            }
        }

        /**
         * Get the number of log entries.
         */
        @JvmSynthetic
        internal fun getLogEntryCount(): Int {
            return synchronized(logLock) {
                try {
                    val content = readEncryptedLogContent()
                    if (content.isEmpty()) 0 else content.lines().size
                } catch (e: Exception) {
                    Timber.e(e, "Failed to count audit log entries")
                    0
                }
            }
        }

        /**
         * Clear audit log (for testing/debugging only).
         * Also clears any temp files.
         *
         * Restricted to debug builds only. Release builds are no-ops
         * to prevent audit log destruction via reflection or instrumentation.
         */
        @JvmSynthetic
        internal fun clearAuditLog() {
            if (!BuildConfig.DEBUG) {
                Timber.w("clearAuditLog() called in release build, ignoring")
                return
            }
            synchronized(logLock) {
                try {
                    val logFile = File(context.filesDir, AUDIT_LOG_FILENAME)
                    val tempFile = File(context.filesDir, AUDIT_LOG_TEMP_FILENAME)
                    logFile.delete()
                    tempFile.delete()
                    Timber.d("Audit log cleared")
                } catch (e: Exception) {
                    Timber.e(e, "Failed to clear audit log")
                }
            }
        }

        /**
         * Check if audit log is encrypted (file exists but cannot be read as plaintext).
         * Useful for verifying MASVS-STORAGE compliance.
         */
        fun isLogEncrypted(): Boolean {
            val logFile = File(context.filesDir, AUDIT_LOG_FILENAME)
            if (!logFile.exists()) {
                return true // No file means we would create encrypted one
            }

            // Try to read as plaintext JSON. If it parses, it is not encrypted.
            return try {
                val rawContent = logFile.readBytes()
                val firstLine = String(rawContent.take(100).toByteArray(), Charsets.UTF_8)
                // Encrypted content will not parse as valid JSON
                JSONObject(firstLine)
                false // Was able to parse as JSON = not encrypted
            } catch (e: Exception) {
                true // Failed to parse = encrypted (or corrupted, but we assume encrypted)
            }
        }
    }
