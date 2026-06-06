// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.privacy

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages user consent for data collection activities (analytics, crash reporting) and
 * exposes observable state flows for each preference. Backs all values with
 * EncryptedSharedPreferences (AES256-GCM values, AES256-SIV keys) so consent decisions
 * are protected at rest. Supports consent versioning so the app can prompt again when the
 * privacy policy changes, and provides a data deletion request flag for GDPR-style flows.
 */
@Singleton
class PrivacyPreferences
    @Inject
    constructor(
        private val context: Context,
    ) {
        companion object {
            private const val TAG = "PrivacyPreferences"
            private const val PREFS_NAME = "privacy_preferences_secure"
            private const val KEY_ANALYTICS_CONSENT = "analytics_consent"
            private const val KEY_CRASH_REPORTING_CONSENT = "crash_reporting_consent"
            private const val KEY_CONSENT_VERSION = "consent_version"
            private const val KEY_CONSENT_TIMESTAMP = "consent_timestamp"
            private const val KEY_DATA_DELETION_REQUESTED = "data_deletion_requested"

            // Current consent version. Increment when privacy policy changes significantly.
            const val CURRENT_CONSENT_VERSION = 1
        }

        /**
         * Encrypted SharedPreferences using AES256-GCM for values and AES256-SIV for keys.
         * Falls back to deletion and recreation if the backing file becomes corrupted.
         */
        private val prefs: SharedPreferences by lazy {
            createEncryptedPrefs()
        }

        private fun createEncryptedPrefs(): SharedPreferences {
            return try {
                val masterKey =
                    MasterKey.Builder(context)
                        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                        .build()

                EncryptedSharedPreferences.create(
                    context,
                    PREFS_NAME,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Failed to create encrypted prefs, attempting recovery")
                // Try to delete corrupted prefs and recreate
                try {
                    context.deleteSharedPreferences(PREFS_NAME)
                    val masterKey =
                        MasterKey.Builder(context)
                            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                            .build()

                    EncryptedSharedPreferences.create(
                        context,
                        PREFS_NAME,
                        masterKey,
                        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                    )
                } catch (e2: Exception) {
                    Timber.e(e2, "$TAG: Recovery failed, privacy preferences unavailable")
                    // Return a no-op SharedPreferences that doesn't persist.
                    // This ensures the app doesn't crash but consent won't be saved.
                    throw IllegalStateException("Cannot create secure privacy preferences", e2)
                }
            }
        }

        // Analytics opt-in state (default: false, opt-out by default)
        private val _analyticsEnabled =
            MutableStateFlow(
                try {
                    prefs.getBoolean(KEY_ANALYTICS_CONSENT, false)
                } catch (e: Exception) {
                    false
                },
            )
        val analyticsEnabled: StateFlow<Boolean> = _analyticsEnabled.asStateFlow()

        // Crash reporting opt-in state (default: false, opt-out by default)
        private val _crashReportingEnabled =
            MutableStateFlow(
                try {
                    prefs.getBoolean(KEY_CRASH_REPORTING_CONSENT, false)
                } catch (e: Exception) {
                    false
                },
            )
        val crashReportingEnabled: StateFlow<Boolean> = _crashReportingEnabled.asStateFlow()

        // Data deletion requested state
        private val _dataDeletionRequested =
            MutableStateFlow(
                try {
                    prefs.getBoolean(KEY_DATA_DELETION_REQUESTED, false)
                } catch (e: Exception) {
                    false
                },
            )
        val dataDeletionRequested: StateFlow<Boolean> = _dataDeletionRequested.asStateFlow()

        /**
         * Check if user has provided any consent (first-time setup).
         */
        fun hasProvidedConsent(): Boolean {
            return try {
                prefs.contains(KEY_CONSENT_VERSION)
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error checking consent status")
                false
            }
        }

        /**
         * Check if consent needs to be renewed (policy version changed).
         */
        fun needsConsentRenewal(): Boolean {
            return try {
                val savedVersion = prefs.getInt(KEY_CONSENT_VERSION, 0)
                savedVersion < CURRENT_CONSENT_VERSION
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error checking consent renewal")
                true // Assume renewal needed if we can't check
            }
        }

        /**
         * Set analytics consent with timestamp.
         */
        fun setAnalyticsConsent(enabled: Boolean) {
            try {
                prefs.edit()
                    .putBoolean(KEY_ANALYTICS_CONSENT, enabled)
                    .putInt(KEY_CONSENT_VERSION, CURRENT_CONSENT_VERSION)
                    .putLong(KEY_CONSENT_TIMESTAMP, System.currentTimeMillis())
                    .apply()
                _analyticsEnabled.value = enabled
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error setting analytics consent")
            }
        }

        /**
         * Set crash reporting consent with timestamp.
         */
        fun setCrashReportingConsent(enabled: Boolean) {
            try {
                prefs.edit()
                    .putBoolean(KEY_CRASH_REPORTING_CONSENT, enabled)
                    .putInt(KEY_CONSENT_VERSION, CURRENT_CONSENT_VERSION)
                    .putLong(KEY_CONSENT_TIMESTAMP, System.currentTimeMillis())
                    .apply()
                _crashReportingEnabled.value = enabled
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error setting crash reporting consent")
            }
        }

        /**
         * Record all consent choices at once.
         */
        fun recordConsent(
            analyticsEnabled: Boolean,
            crashReportingEnabled: Boolean,
        ) {
            try {
                prefs.edit()
                    .putBoolean(KEY_ANALYTICS_CONSENT, analyticsEnabled)
                    .putBoolean(KEY_CRASH_REPORTING_CONSENT, crashReportingEnabled)
                    .putInt(KEY_CONSENT_VERSION, CURRENT_CONSENT_VERSION)
                    .putLong(KEY_CONSENT_TIMESTAMP, System.currentTimeMillis())
                    .apply()
                _analyticsEnabled.value = analyticsEnabled
                _crashReportingEnabled.value = crashReportingEnabled
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error recording consent")
            }
        }

        /**
         * Request data deletion. This flags the account for data deletion.
         * The actual deletion is performed by clearAllPrivacyData().
         */
        fun requestDataDeletion() {
            try {
                prefs.edit()
                    .putBoolean(KEY_DATA_DELETION_REQUESTED, true)
                    .apply()
                _dataDeletionRequested.value = true
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error requesting data deletion")
            }
        }

        /**
         * Clear all privacy-related data and preferences.
         * This should be called as part of a data deletion request.
         */
        fun clearAllPrivacyData() {
            try {
                prefs.edit().clear().apply()
                _analyticsEnabled.value = false
                _crashReportingEnabled.value = false
                _dataDeletionRequested.value = false
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error clearing privacy data")
            }
        }

        /**
         * Get consent timestamp if available.
         */
        fun getConsentTimestamp(): Long? {
            return try {
                if (prefs.contains(KEY_CONSENT_TIMESTAMP)) {
                    prefs.getLong(KEY_CONSENT_TIMESTAMP, 0L)
                } else {
                    null
                }
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error getting consent timestamp")
                null
            }
        }

        /**
         * Get current consent version.
         */
        fun getConsentVersion(): Int {
            return try {
                prefs.getInt(KEY_CONSENT_VERSION, 0)
            } catch (e: Exception) {
                Timber.e(e, "$TAG: Error getting consent version")
                0
            }
        }
    }
