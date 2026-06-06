// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet

import android.app.Application
import android.os.Build
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.request.crossfade
import coil3.svg.SvgDecoder
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.sdk.AppInfo
import app.provii.wallet.sdk.WalletSdk
import app.provii.wallet.sdk.initAndroidLogging
import app.provii.wallet.sdk.sdkDiagnoseThreadConfig
import app.provii.wallet.sdk.sdkSetUserAgent
import app.provii.wallet.sdk.uniffiEnsureInitialized
import app.provii.wallet.security.SecurePreferencesManager
import app.provii.wallet.security.integrity.SignatureVerifier
import dagger.hilt.android.HiltAndroidApp
import app.provii.wallet.logging.SanitizingTree
import timber.log.Timber

/**
 * Application subclass that initialises the Rust SDK, UniFFI runtime, logging, and
 * environment configuration on startup. Restores the user's saved language preference
 * from encrypted storage before any UI is rendered. Also pre-warms the [KeystoreBridge]
 * to help FindClass on native threads.
 */
@HiltAndroidApp
class WalletApplication : Application(), SingletonImageLoader.Factory {
    // Tracks whether SDK initialisation failed during Application.onCreate so that
    // MainActivity can present an error instead of proceeding with a broken runtime.
    var sdkInitFailed: Boolean = false
        private set
    var sdkInitError: String? = null
        private set

    // MASVS-CODE-1: Use secure preferences manager
    private lateinit var securePrefsManager: SecurePreferencesManager

    override fun onCreate() {
        super.onCreate()

        // Use debug mode check without BuildConfig
        val isDebug = applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (isDebug) {
            Timber.plant(SanitizingTree())
        }

        // MASVS-RESILIENCE-2: Fail fast if signing certificate hash is still a placeholder
        // in a release build. Uncaught SecurityException terminates the process intentionally.
        SignatureVerifier.validateConfiguration(this)

        // Initialise secure preferences manager
        securePrefsManager = SecurePreferencesManager(this)

        // Restore saved language preference before other initialisation
        restoreLanguagePreference()

        // Initialise EnvironmentManager first
        try {
            EnvironmentManager.initialize(this)
            Timber.d("EnvironmentManager initialized with environment: ${EnvironmentManager.getCurrentEnvironment()}")
        } catch (e: Throwable) {
            Timber.e(e, "EnvironmentManager initialization failed, using defaults")
        }

        // initialise the sandbox credential fetcher so WorkManager
        // jobs running outside the main activity can reach the
        // EncryptedSharedPreferences store.
        try {
            app.provii.wallet.config.SandboxCredentialFetcher.initialize(this)
        } catch (e: Throwable) {
            Timber.e(e, "SandboxCredentialFetcher initialize failed")
        }

        // 1) Load native library (JNI_OnLoad) + hand native a Context
        try {
            val rc = WalletSdk.initAndroidContext(applicationContext)
            Timber.d("WalletSdk.initAndroidContext rc=$rc")
            // Verify native library integrity after loading
            WalletSdk.verifyNativeLibrary(applicationContext)
        } catch (e: SecurityException) {
            // Native library integrity check failed. Fatal.
            Timber.e(e, "Native library integrity verification failed")
            sdkInitFailed = true
            sdkInitError = "Native library integrity verification failed: ${e.message}"
            throw e
        } catch (e: Throwable) {
            Timber.e(e, "initAndroidContext failed")
            sdkInitFailed = true
            sdkInitError = "SDK native context initialisation failed: ${e.message}"
            return
        }

        // 2) Bring up UniFFI runtime; JNA will map functions
        try {
            uniffiEnsureInitialized()
            Timber.d("UniFFI runtime initialized")
        } catch (e: Throwable) {
            Timber.e(e, "uniffiEnsureInitialized failed")
            sdkInitFailed = true
            sdkInitError = "UniFFI runtime initialisation failed: ${e.message}"
        }

        // 3) Route Rust logs to Logcat
        try {
            initAndroidLogging()
            Timber.d("Rust logging initialized")
        } catch (e: Throwable) {
            Timber.e(e, "initAndroidLogging failed")
            sdkInitFailed = true
            sdkInitError = "Rust logging initialisation failed: ${e.message}"
        }

        // 4) Set SDK User-Agent for all HTTP requests
        try {
            initializeSdkUserAgent()
            Timber.d("SDK User-Agent initialized")
        } catch (e: Throwable) {
            Timber.e(e, "SDK User-Agent initialization failed")
        }

        // 5) Run thread configuration diagnostic
        try {
            val diagnostic = sdkDiagnoseThreadConfig()
            Timber.d("Thread Configuration Diagnostic:\n$diagnostic")

            // Parse and warn if single-threaded
            if (diagnostic.contains("NOT WORKING")) {
                Timber.e("WARNING: Multi-threading is NOT working! Proofs will be slow.")
            }
        } catch (e: Throwable) {
            Timber.e(e, "Thread diagnostic failed")
        }

        // 6) (Optional but helps FindClass on native threads)
        try {
            app.provii.wallet.KeystoreBridge.getInstance(applicationContext)
            Timber.d("KeystoreBridge prewarmed")
        } catch (e: Throwable) {
            Timber.w(e, "KeystoreBridge prewarm failed (will try lazily later)")
        }
    }

    private fun restoreLanguagePreference() {
        try {
            // MASVS-CODE-1: Use EncryptedSharedPreferences via SecurePreferencesManager
            val savedLanguage = securePrefsManager.getLanguageCode()
            if (!savedLanguage.isNullOrEmpty()) {
                val localeList = LocaleListCompat.forLanguageTags(savedLanguage)
                AppCompatDelegate.setApplicationLocales(localeList)
                Timber.d("Restored language preference: $savedLanguage")
            }
            // No legacy migration - if language not set, user will choose again
        } catch (e: Exception) {
            Timber.e(e, "Failed to restore language preference")
        }
    }

    private fun initializeSdkUserAgent() {
        // Get version info - using packageInfo since BuildConfig may not be available
        val packageInfo =
            try {
                packageManager.getPackageInfo(packageName, 0)
            } catch (e: Exception) {
                Timber.e(e, "Failed to get package info")
                null
            }

        val versionName = packageInfo?.versionName ?: "2.0.0"
        val versionCode =
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageInfo?.longVersionCode?.toString() ?: "1"
            } else {
                @Suppress("DEPRECATION")
                packageInfo?.versionCode?.toString() ?: "1"
            }

        val appInfo =
            AppInfo(
                version = versionName,
                buildNumber = versionCode,
                platform = "Android",
                deviceModel = Build.MODEL, // e.g., "Pixel 7"
                osVersion = Build.VERSION.RELEASE, // e.g., "14"
            )

        // Set the User-Agent for all SDK HTTP requests
        sdkSetUserAgent(appInfo)

        Timber.d("SDK User-Agent set: ProviiWallet/$versionName (Android ${Build.VERSION.RELEASE}; ${Build.MODEL})")
    }

    override fun newImageLoader(context: android.content.Context): ImageLoader {
        return ImageLoader.Builder(context)
            .components {
                add(SvgDecoder.Factory())
            }
            .crossfade(true)
            .build()
    }
}
