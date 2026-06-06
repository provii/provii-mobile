// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Persists in-progress form data using [EncryptedSharedPreferences] so that users do not
 * lose input when the app times out or is interrupted. Data expires after 24 hours and is
 * cleared automatically to prevent stale accumulation. Satisfies WCAG 2.2 AAA criterion
 * 2.2.6 (Timeouts) and MASVS-STORAGE-1 for encrypted storage.
 */

/**
 * WCAG 2.2 AAA: 2.2.6 Timeouts - Data Preservation
 *
 * Automatically saves form data before timeouts and allows restoration.
 * Data expires after 24 hours to prevent stale data accumulation.
 *
 * MASVS-STORAGE-1: Uses EncryptedSharedPreferences to protect stored data.
 */

internal const val PRESERVATION_EXPIRY_MS = 24 * 60 * 60 * 1000L // 24 hours
private const val PREFS_FILE_NAME = "data_preservation_secure"

@Singleton
class DataPreservationManager
    @Inject
    constructor(
        @ApplicationContext internal val context: Context,
    ) {
        internal val json =
            Json {
                ignoreUnknownKeys = true
                encodeDefaults = true
            }

        /**
         * MASVS-STORAGE-1: Create encrypted SharedPreferences for secure data storage.
         * Fails closed: if EncryptedSharedPreferences cannot be created, data is not preserved.
         */
        private val encryptedPrefs: SharedPreferences? by lazy {
            try {
                val masterKey =
                    MasterKey.Builder(context)
                        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                        .build()

                EncryptedSharedPreferences.create(
                    context,
                    PREFS_FILE_NAME,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (e: Exception) {
                Timber.w("EncryptedSharedPreferences unavailable, data preservation disabled")
                null
            }
        }

        /**
         * Saves data to preservation storage with a timestamp.
         * Data will be available for 24 hours.
         * Returns true on success, false if encrypted storage is unavailable or serialisation fails.
         */
        internal suspend inline fun <reified T> preserve(
            key: String,
            data: T,
        ): Boolean {
            val prefs =
                encryptedPrefs ?: run {
                    Timber.w("DataPreservationManager: encrypted storage unavailable, data not preserved for key: $key")
                    return false
                }
            val dataKey = "${key}_data"
            val timestampKey = "${key}_timestamp"

            return try {
                val jsonString = json.encodeToString(data)
                prefs.edit()
                    .putString(dataKey, jsonString)
                    .putLong(timestampKey, System.currentTimeMillis())
                    .apply()
                true
            } catch (e: Exception) {
                Timber.e(e, "DataPreservationManager: failed to preserve data for key: $key")
                false
            }
        }

        /**
         * Restores data from preservation storage if it exists and hasn't expired.
         * Returns null if data is not found or has expired.
         */
        internal suspend inline fun <reified T> restore(key: String): T? {
            val prefs = encryptedPrefs ?: return null
            val dataKey = "${key}_data"
            val timestampKey = "${key}_timestamp"

            val jsonString = prefs.getString(dataKey, null) ?: return null
            val timestamp = prefs.getLong(timestampKey, 0L)

            // Check if data has expired (24 hours)
            val elapsed = System.currentTimeMillis() - timestamp
            if (elapsed > PRESERVATION_EXPIRY_MS) {
                // Clear expired data
                clear(key)
                return null
            }

            return try {
                json.decodeFromString<T>(jsonString)
            } catch (e: Exception) {
                Timber.e(e, "Failed to restore data for key: $key")
                null
            }
        }

        /**
         * Checks if preserved data exists for a key.
         */
        suspend fun hasPreservedData(key: String): Boolean {
            val prefs = encryptedPrefs ?: return false
            val dataKey = "${key}_data"
            val timestampKey = "${key}_timestamp"

            val hasData = prefs.contains(dataKey)
            val timestamp = prefs.getLong(timestampKey, 0L)
            val isValid = (System.currentTimeMillis() - timestamp) < PRESERVATION_EXPIRY_MS

            return hasData && isValid
        }

        /**
         * Clears preserved data for a specific key.
         */
        suspend fun clear(key: String) {
            val prefs = encryptedPrefs ?: return
            val dataKey = "${key}_data"
            val timestampKey = "${key}_timestamp"

            prefs.edit()
                .remove(dataKey)
                .remove(timestampKey)
                .apply()
        }

        /**
         * Clears all expired preservation data.
         * Should be called periodically to prevent storage bloat.
         */
        suspend fun clearExpired() {
            val prefs = encryptedPrefs ?: return
            val keysToRemove = mutableSetOf<String>()
            val allEntries = prefs.all

            allEntries.forEach { (key, _) ->
                if (key.endsWith("_timestamp")) {
                    val timestamp = prefs.getLong(key, 0L)
                    val elapsed = System.currentTimeMillis() - timestamp

                    if (elapsed > PRESERVATION_EXPIRY_MS) {
                        val baseKey = key.removeSuffix("_timestamp")
                        keysToRemove.add("${baseKey}_data")
                        keysToRemove.add(key)
                    }
                }
            }

            if (keysToRemove.isNotEmpty()) {
                val editor = prefs.edit()
                keysToRemove.forEach { editor.remove(it) }
                editor.apply()
            }
        }

        /**
         * Clears all preserved data.
         */
        suspend fun clearAll() {
            encryptedPrefs?.edit()?.clear()?.apply()
        }
    }

/**
 * Common preservation keys for the app.
 */
object PreservationKeys {
    const val VERIFICATION_FORM = "verification_form"
    const val CREDENTIAL_ISSUANCE = "credential_issuance"
    const val OFFICER_SESSION = "officer_session"
    const val SETTINGS_FORM = "settings_form"
}
