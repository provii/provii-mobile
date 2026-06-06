// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.di

import android.content.Context
import app.provii.wallet.data.*
import app.provii.wallet.deeplink.DeepLinkHandler
import app.provii.wallet.navigation.NavigationPayloadStore
import app.provii.wallet.privacy.PrivacyPreferences
import app.provii.wallet.KeystoreBridge
import app.provii.wallet.error.ErrorHandler
import app.provii.wallet.network.NetworkManager
import app.provii.wallet.officer.OfficerAuthManager
import app.provii.wallet.security.AuditLogger
import app.provii.wallet.security.NativeKeystoreManager
import app.provii.wallet.security.SecurePreferencesManager
import app.provii.wallet.ui.accessibility.WalletAccessibilityManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import java.util.Locale
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

/**
 * Hilt dependency injection module for the Provii Wallet application. Provides
 * singleton-scoped instances of core services including secure storage, networking,
 * deep link handling, and accessibility management. All bindings are installed into
 * the [SingletonComponent] and live for the duration of the application process.
 */
@Module
@InstallIn(SingletonComponent::class)
class AppModule {
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor { chain ->
                // Send Accept-Language on all requests (matching iOS behaviour)
                val request =
                    chain.request().newBuilder()
                        .addHeader("Accept-Language", Locale.getDefault().toLanguageTag())
                        .build()
                chain.proceed(request)
            }
            .build()
    }

    @Provides
    @Singleton
    fun provideKeystoreBridge(
        @ApplicationContext context: Context,
        keystoreManager: NativeKeystoreManager,
    ): KeystoreBridge {
        return KeystoreBridge(context, keystoreManager)
    }

    @Provides
    @Singleton
    fun provideWalletRepository(
        @ApplicationContext context: Context,
        auditLogger: AuditLogger,
        keystoreBridge: KeystoreBridge,
        httpClient: OkHttpClient,
    ): WalletRepository {
        return WalletRepository(context, auditLogger, keystoreBridge, httpClient)
    }

    @Provides
    @Singleton
    fun provideIssuersRepository(
        @ApplicationContext context: Context,
        httpClient: OkHttpClient,
    ): IssuersRepository {
        return IssuersRepository(context, httpClient)
    }

    @Provides
    @Singleton
    fun provideYubikeyManager(
        @ApplicationContext context: Context,
        auditLogger: AuditLogger,
    ): YubikeyManager {
        return YubikeyManager(context, auditLogger)
    }

    @Provides
    @Singleton
    fun provideNativeKeystoreManager(
        @ApplicationContext context: Context,
    ): NativeKeystoreManager {
        return NativeKeystoreManager(context)
    }

    @Provides
    @Singleton
    fun provideQrCoder(): QrCoder {
        return QrCoder()
    }

    @Provides
    @Singleton
    fun provideNavigationPayloadStore(): NavigationPayloadStore {
        return NavigationPayloadStore()
    }

    @Provides
    @Singleton
    fun provideDeepLinkHandler(
        @ApplicationContext context: Context,
        auditLogger: AuditLogger,
        navigationPayloadStore: NavigationPayloadStore,
    ): DeepLinkHandler {
        return DeepLinkHandler(context, auditLogger, navigationPayloadStore)
    }

    @Provides
    @Singleton
    fun provideErrorHandler(): ErrorHandler {
        return ErrorHandler()
    }

    @Provides
    @Singleton
    fun provideOfficerAuthManager(
        @ApplicationContext context: Context,
        yubikeyManager: YubikeyManager,
        keystoreManager: NativeKeystoreManager,
        dataPreservationManager: app.provii.wallet.ui.accessibility.DataPreservationManager,
        auditLogger: AuditLogger,
        httpClient: OkHttpClient,
    ): OfficerAuthManager {
        return OfficerAuthManager(context, yubikeyManager, keystoreManager, dataPreservationManager, auditLogger, httpClient)
    }

    @Provides
    @Singleton
    fun provideAuditLogger(
        @ApplicationContext context: Context,
    ): AuditLogger {
        return AuditLogger(context)
    }

    @Provides
    @Singleton
    fun provideNetworkManager(): NetworkManager {
        return NetworkManager()
    }

    @Provides
    @Singleton
    fun provideAccessibilityManager(
        @ApplicationContext context: Context,
    ): WalletAccessibilityManager {
        return WalletAccessibilityManager(context)
    }

    @Provides
    @Singleton
    fun provideSecurePreferencesManager(
        @ApplicationContext context: Context,
        auditLogger: AuditLogger,
    ): SecurePreferencesManager {
        return SecurePreferencesManager(context, auditLogger)
    }

    @Provides
    @Singleton
    fun providePrivacyPreferences(
        @ApplicationContext context: Context,
    ): PrivacyPreferences {
        return PrivacyPreferences(context)
    }
}
