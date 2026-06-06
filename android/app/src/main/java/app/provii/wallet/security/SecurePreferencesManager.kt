// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import timber.log.Timber
import java.io.Closeable

/**
 * Encrypted SharedPreferences manager for all non-credential application preferences.
 * Provides separate encrypted stores for general settings (language, flags) and session
 * state (browser-return flag, deep link preservation). All keys and values are encrypted
 * with AES256-SIV and AES256-GCM respectively via Android's security-crypto library,
 * with graceful recovery if the backing file becomes corrupted.
 */
class SecurePreferencesManager(
    private val context: Context,
    private val auditLogger: AuditLogger? = null,
) : Closeable {
    companion object {
        private const val TAG = "SecurePreferencesManager"

        // Preference file names
        private const val PREFS_NAME_GENERAL = "provii_wallet_secure"
        private const val PREFS_NAME_SESSION = "provii_wallet_session"

        // General preference keys
        const val KEY_LANGUAGE_CODE = "selectedLanguageCode"
        const val KEY_HAS_SELECTED_LANGUAGE = "hasSelectedLanguage"

        // Session/state preference keys
        const val KEY_SHOULD_RETURN_TO_BROWSER = "should_return_to_browser"
        const val KEY_VERIFICATION_COMPLETED = "verification_completed"

        // Walkthrough state keys
        const val KEY_HAS_COMPLETED_WALKTHROUGH = "has_completed_walkthrough"

        // Deep link state keys
        const val KEY_PENDING_DEEP_LINK_TYPE = "pending_deep_link_type"
        const val KEY_PENDING_DEEP_LINK_DATA = "pending_deep_link_data"
        const val KEY_PENDING_DEEP_LINK_TIMESTAMP = "pending_deep_link_timestamp"

        // Deep link state expiration (5 minutes)
        private const val DEEP_LINK_STATE_EXPIRY_MS = 5 * 60 * 1000L
    }

    /**
     * General encrypted preferences (no user authentication required).
     * Used for language preferences and other non-critical settings.
     */
    private val generalPrefs: SharedPreferences by lazy {
        createGeneralEncryptedPrefs()
    }

    /**
     * Session encrypted preferences (no user authentication required).
     * Used for temporary session state like browser return flags.
     */
    private val sessionPrefs: SharedPreferences by lazy {
        createSessionEncryptedPrefs()
    }

    private fun createGeneralEncryptedPrefs(): SharedPreferences {
        try {
            val masterKey =
                MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

            return EncryptedSharedPreferences.create(
                context,
                PREFS_NAME_GENERAL,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            Timber.e(e, "Failed to create general encrypted prefs, attempting recovery")
            auditLogger?.logEncryptedPrefsRecovery(
                prefsName = PREFS_NAME_GENERAL,
                errorMessage = e.message ?: e.javaClass.simpleName,
            )
            // If there's an issue with the encrypted prefs, try to delete and recreate
            try {
                context.getSharedPreferences(PREFS_NAME_GENERAL, Context.MODE_PRIVATE)
                    .edit().clear().apply()
                context.deleteSharedPreferences(PREFS_NAME_GENERAL)
            } catch (deleteError: Exception) {
                Timber.w(deleteError, "Could not delete corrupted prefs file")
            }

            val masterKey =
                MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

            return EncryptedSharedPreferences.create(
                context,
                PREFS_NAME_GENERAL,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }

    private fun createSessionEncryptedPrefs(): SharedPreferences {
        try {
            val masterKey =
                MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

            return EncryptedSharedPreferences.create(
                context,
                PREFS_NAME_SESSION,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            Timber.e(e, "Failed to create session encrypted prefs, attempting recovery")
            auditLogger?.logEncryptedPrefsRecovery(
                prefsName = PREFS_NAME_SESSION,
                errorMessage = e.message ?: e.javaClass.simpleName,
            )
            // Session prefs contain only ephemeral navigation state; delete and recreate
            // rather than crashing. No credential data is stored here.
            try {
                context.getSharedPreferences(PREFS_NAME_SESSION, Context.MODE_PRIVATE)
                    .edit().clear().apply()
                context.deleteSharedPreferences(PREFS_NAME_SESSION)
            } catch (deleteError: Exception) {
                Timber.w(deleteError, "Could not delete corrupted session prefs file")
            }

            val masterKey =
                MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

            return EncryptedSharedPreferences.create(
                context,
                PREFS_NAME_SESSION,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }

    // === Language Preference Operations ===

    /**
     * Save the selected language code securely.
     */
    fun saveLanguageCode(languageCode: String) {
        generalPrefs.edit()
            .putString(KEY_LANGUAGE_CODE, languageCode)
            .putBoolean(KEY_HAS_SELECTED_LANGUAGE, true)
            .apply()
        Timber.d("Language code saved securely: $languageCode")
    }

    /**
     * Get the saved language code.
     */
    fun getLanguageCode(): String? {
        return generalPrefs.getString(KEY_LANGUAGE_CODE, null)
    }

    /**
     * Check if user has selected a language.
     */
    fun hasSelectedLanguage(): Boolean {
        return generalPrefs.getBoolean(KEY_HAS_SELECTED_LANGUAGE, false)
    }

    // === Walkthrough State ===

    /**
     * Check if user has completed the post-setup walkthrough.
     */
    fun hasCompletedWalkthrough(): Boolean {
        return generalPrefs.getBoolean(KEY_HAS_COMPLETED_WALKTHROUGH, false)
    }

    /**
     * Mark the walkthrough as completed (or skipped).
     */
    fun setWalkthroughCompleted() {
        generalPrefs.edit()
            .putBoolean(KEY_HAS_COMPLETED_WALKTHROUGH, true)
            .apply()
        Timber.d("Walkthrough completed flag set")
    }

    // === Session State Operations ===

    /**
     * Set browser return flag.
     */
    fun setShouldReturnToBrowser(shouldReturn: Boolean) {
        sessionPrefs.edit()
            .putBoolean(KEY_SHOULD_RETURN_TO_BROWSER, shouldReturn)
            .apply()
    }

    /**
     * Check and consume the browser return flag.
     */
    fun checkAndConsumeShouldReturnToBrowser(): Boolean {
        val shouldReturn = sessionPrefs.getBoolean(KEY_SHOULD_RETURN_TO_BROWSER, false)
        if (shouldReturn) {
            sessionPrefs.edit()
                .putBoolean(KEY_SHOULD_RETURN_TO_BROWSER, false)
                .apply()
        }
        return shouldReturn
    }

    /**
     * Mark verification as completed.
     */
    fun setVerificationCompleted(completed: Boolean) {
        sessionPrefs.edit()
            .putBoolean(KEY_VERIFICATION_COMPLETED, completed)
            .apply()
    }

    /**
     * Check if verification was completed.
     */
    fun isVerificationCompleted(): Boolean {
        return sessionPrefs.getBoolean(KEY_VERIFICATION_COMPLETED, false)
    }

    // === Deep Link State Preservation ===

    /**
     * Save pending deep link state for restoration after process death.
     */
    fun savePendingDeepLinkState(
        type: String,
        data: String,
    ) {
        sessionPrefs.edit()
            .putString(KEY_PENDING_DEEP_LINK_TYPE, type)
            .putString(KEY_PENDING_DEEP_LINK_DATA, data)
            .putLong(KEY_PENDING_DEEP_LINK_TIMESTAMP, System.currentTimeMillis())
            .apply()
        Timber.d("Saved pending deep link state: type=$type")
    }

    /**
     * Get and clear pending deep link state.
     * Returns null if no state or if state has expired.
     */
    fun getAndClearPendingDeepLinkState(): DeepLinkState? {
        val type = sessionPrefs.getString(KEY_PENDING_DEEP_LINK_TYPE, null)
        val data = sessionPrefs.getString(KEY_PENDING_DEEP_LINK_DATA, null)
        val timestamp = sessionPrefs.getLong(KEY_PENDING_DEEP_LINK_TIMESTAMP, 0)

        // Clear the state regardless
        sessionPrefs.edit()
            .remove(KEY_PENDING_DEEP_LINK_TYPE)
            .remove(KEY_PENDING_DEEP_LINK_DATA)
            .remove(KEY_PENDING_DEEP_LINK_TIMESTAMP)
            .apply()

        // Return null if no state or expired
        if (type == null || data == null) {
            return null
        }

        val elapsed = System.currentTimeMillis() - timestamp
        if (elapsed > DEEP_LINK_STATE_EXPIRY_MS) {
            Timber.d("Deep link state expired (${elapsed}ms > ${DEEP_LINK_STATE_EXPIRY_MS}ms)")
            return null
        }

        return DeepLinkState(type, data, timestamp)
    }

    /**
     * Clear all session state (for security during logout/reset).
     */
    fun clearSessionState() {
        sessionPrefs.edit().clear().apply()
        Timber.d("Session state cleared")
    }

    /**
     * Clear all stored preferences (for full reset).
     */
    fun clearAll() {
        generalPrefs.edit().clear().apply()
        sessionPrefs.edit().clear().apply()
        Timber.d("All secure preferences cleared")
    }

    /**
     * Closeable implementation for resource cleanup.
     */
    override fun close() {
        // SharedPreferences doesn't need explicit cleanup,
        // but this satisfies the Closeable contract
        Timber.d("SecurePreferencesManager closed")
    }

    /**
     * Data class for deep link state.
     */
    data class DeepLinkState(
        val type: String,
        val data: String,
        val timestamp: Long,
    )
}
