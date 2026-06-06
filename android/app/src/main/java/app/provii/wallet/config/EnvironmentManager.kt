// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.config

import android.content.Context
import android.content.SharedPreferences
// MasterKey and EncryptedSharedPreferences referenced via FQN to avoid
// import-level deprecation warnings (no replacement API in security-crypto 1.1.x)
import com.google.gson.Gson
import timber.log.Timber
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.InputStreamReader

/**
 * Manages environment switching between production and sandbox modes. Loads API endpoint
 * configuration from a bundled JSON asset and persists the active environment selection in
 * EncryptedSharedPreferences. Exposes typed accessors for issuer, verifier, registry, and
 * CDN URLs that reflect the currently selected environment.
 */
object EnvironmentManager {
    private const val PREF_NAME = "wallet_environment"
    private const val KEY_SANDBOX_ENABLED = "sandbox_enabled"
    private const val DEFAULT_ENV = "production"

    private var prefs: SharedPreferences? = null
    private var config: Map<String, Environment>? = null
    private var currentEnv: String = DEFAULT_ENV

    data class Environment(
        val issuer: IssuerConfig,
        val verifier: VerifierConfig,
        val registry: RegistryConfig,
        val cdn: CDNConfig,
        val config: ConfigConfig? = null,
    )

    data class IssuerConfig(
        val api: String,
        val example: String,
    )

    data class VerifierConfig(
        val api: String,
        val verify: String,
    )

    data class RegistryConfig(
        val issuers: String,
    )

    data class CDNConfig(
        val provingKey: String,
    )

    data class ConfigConfig(
        val api: String,
    )

    @Suppress("DEPRECATION")
    fun initialize(context: Context) {
        // Create encrypted preferences for environment data.
        // No user authentication required. Environment prefs are non-sensitive
        // configuration (selected environment name, sandbox toggle).
        // Suppressed: MasterKey and EncryptedSharedPreferences are deprecated
        // with no replacement API available yet in security-crypto 1.1.x.
        val masterKey =
            androidx.security.crypto.MasterKey.Builder(context)
                .setKeyScheme(androidx.security.crypto.MasterKey.KeyScheme.AES256_GCM)
                .build()

        prefs =
            androidx.security.crypto.EncryptedSharedPreferences.create(
                context,
                PREF_NAME,
                masterKey,
                androidx.security.crypto.EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                androidx.security.crypto.EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )

        // Load configuration from JSON
        loadConfig(context)

        // Check if sandbox mode is enabled
        if (isSandboxEnabled()) {
            currentEnv = "sandbox"
        } else {
            currentEnv = DEFAULT_ENV
        }
    }

    private fun loadConfig(context: Context) {
        try {
            val inputStream = context.assets.open("config/api-endpoints.json")
            val reader = InputStreamReader(inputStream)
            val configJson =
                Gson().fromJson<Map<String, Any>>(
                    reader,
                    object : TypeToken<Map<String, Any>>() {}.type,
                )

            @Suppress("UNCHECKED_CAST")
            val environments =
                configJson["environments"] as? Map<String, Any>
                    ?: throw IllegalStateException("Missing 'environments' key in config")
            config =
                Gson().fromJson(
                    Gson().toJson(environments),
                    object : TypeToken<Map<String, Environment>>() {}.type,
                )
        } catch (e: Exception) {
            throw RuntimeException("Failed to load environment configuration", e)
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    fun enableSandbox(enable: Boolean) {
        prefs?.edit()?.putBoolean(KEY_SANDBOX_ENABLED, enable)?.apply()
        currentEnv = if (enable) "sandbox" else DEFAULT_ENV
        if (enable) {
            // bootstrap the per-install credential on the
            // on-flip via Android Key Attestation.
            // HIGH-9: clear any production credential cache keyed to the
            // old environment so stale production state cannot leak.
            SandboxCredentialFetcher.clearCache()
            GlobalScope.launch(Dispatchers.IO) {
                runCatching { SandboxCredentialFetcher.currentCredential() }
            }
        } else {
            // HIGH-9: parity with iOS. Revoke the sandbox credential on the
            // gateway and wipe local sandbox records. Biometric gating for
            // wallet-level credentials is handled by WalletRepository
            // separately.
            GlobalScope.launch(Dispatchers.IO) {
                SandboxCredentialFetcher.revoke().onFailure { err ->
                    Timber.w(err, "Gateway revoke failed on sandbox disable")
                }
                SandboxCredentialFetcher.clearCache()
            }
        }
    }

    /**
     * Suspending counterpart to [enableSandbox]`(false)` that awaits gateway revocation
     * before returning. Used by [app.provii.wallet.ui.settings.SandboxToggleHandler] so
     * the process is not killed before revocation completes.
     *
     * Writes the sandbox-disabled preference and resets [currentEnv] synchronously first,
     * then suspends on the gateway revoke + cache-clear on [Dispatchers.IO]. On failure
     * the error is logged and execution continues so the caller can still kill the process.
     */
    suspend fun disableSandboxAndRevoke() {
        prefs?.edit()?.putBoolean(KEY_SANDBOX_ENABLED, false)?.apply()
        currentEnv = DEFAULT_ENV
        withContext(Dispatchers.IO) {
            SandboxCredentialFetcher.revoke().onFailure { err ->
                Timber.w(err, "Gateway revoke failed on sandbox disable")
            }
            SandboxCredentialFetcher.clearCache()
        }
    }

    fun isSandboxEnabled(): Boolean {
        return prefs?.getBoolean(KEY_SANDBOX_ENABLED, false) ?: false
    }

    fun getIssuerApi(): String = config?.get(currentEnv)?.issuer?.api ?: ""

    fun getVerifierApi(): String = config?.get(currentEnv)?.verifier?.api ?: ""

    fun getVerifierVerifyUrl(): String = config?.get(currentEnv)?.verifier?.verify ?: ""

    fun getIssuersRegistry(): String = config?.get(currentEnv)?.registry?.issuers ?: ""

    fun getCDNProvingKey(): String = config?.get(currentEnv)?.cdn?.provingKey ?: ""

    fun getConfigApi(): String = config?.get(currentEnv)?.config?.api ?: "https://playground.provii.app"

    fun getCurrentEnvironment(): String = currentEnv

    /**
     * Check if EnvironmentManager has been initialised.
     * Useful for tests to verify state.
     */
    fun isInitialized(): Boolean {
        return prefs != null && config != null
    }

    /**
     * Initialise for testing without encrypted preferences.
     * This allows unit tests to run without Android Keystore.
     *
     * @param testPrefs A simple SharedPreferences implementation (can be a mock)
     * @param testConfig The environment configuration map
     * @param environment The environment to use (default: "production")
     */
    @androidx.annotation.VisibleForTesting
    fun initializeForTesting(
        testPrefs: SharedPreferences,
        testConfig: Map<String, Environment>? = null,
        environment: String = DEFAULT_ENV,
    ) {
        prefs = testPrefs
        config = testConfig ?: mapOf(
            "production" to
                Environment(
                    issuer =
                        IssuerConfig(
                            api = "https://provii-issuer.provii.app",
                            example = "https://example-issuer.provii.app",
                        ),
                    verifier =
                        VerifierConfig(
                            api = "https://provii-verifier.provii.app",
                            verify = "https://verify.provii.app/v1/verify",
                        ),
                    registry =
                        RegistryConfig(
                            issuers = "https://registry.provii.app/issuers",
                        ),
                    cdn =
                        CDNConfig(
                            provingKey = "https://cdn.provii.app/proving-key",
                        ),
                ),
            "sandbox" to
                Environment(
                    issuer =
                        IssuerConfig(
                            api = "https://sandbox-provii-issuer.provii.app",
                            example = "https://sandbox-example-issuer.provii.app",
                        ),
                    verifier =
                        VerifierConfig(
                            api = "https://sandbox-provii-verifier.provii.app",
                            verify = "https://sandbox-verify.provii.app/v1/verify",
                        ),
                    registry =
                        RegistryConfig(
                            issuers = "https://sandbox-registry.provii.app/issuers",
                        ),
                    cdn =
                        CDNConfig(
                            provingKey = "https://sandbox-cdn.provii.app/proving-key",
                        ),
                ),
        )
        currentEnv = environment
    }

    /**
     * Reset state for testing. Allows tests to start with a clean slate.
     */
    @androidx.annotation.VisibleForTesting
    fun resetForTesting() {
        currentEnv = DEFAULT_ENV
        // Note: prefs and config will remain initialised but can be re-initialised
    }
}
