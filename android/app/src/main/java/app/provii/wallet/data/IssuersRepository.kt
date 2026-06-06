// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import android.content.Context
import app.provii.wallet.R
import app.provii.wallet.config.EnvironmentManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton
import java.util.concurrent.TimeUnit

@Serializable
data class IssuerRegistry(
    val version: String,
    val lastUpdated: String,
    val description: String,
    val categories: List<IssuerCategory>,
    val issuers: List<Issuer>,
)

@Serializable
data class IssuerCategory(
    val id: String,
    val name: String,
    val description: String,
)

@Serializable
data class Issuer(
    val id: String,
    val name: String,
    val description: String,
    val type: String,
    val category: String,
    val status: String,
    val brandColor: String,
    val logoUrl: String?,
    val verified: Boolean,
    val instructions: String,
    val deepLink: String?,
    val website: String,
    val minimumAppVersion: String? = null,
    val expectedLaunch: String? = null,
    val platforms: List<String>? = null,
    val locations: List<Location>? = null,
)

@Serializable
data class Location(
    val name: String,
    val address: String,
    val hours: String,
)

/**
 * Fetches and caches the issuer registry from the environment-specific registry URL.
 * Registry entries are cached for 24 hours, with expired cache served as a fallback
 * during network failures. When both the network and cache are unavailable, a hardcoded
 * fallback registry containing only trusted Provii issuers is returned to prevent
 * arbitrary issuer URLs from bypassing validation.
 */
@Singleton
class IssuersRepository
    @Inject
    constructor(
        private val context: Context,
        private val httpClient: OkHttpClient,
    ) {
        private val json =
            Json {
                ignoreUnknownKeys = true
                coerceInputValues = true
            }

        private var cachedRegistry: IssuerRegistry? = null
        private var lastFetchTime: Long = 0
        private val CACHE_DURATION_MS = TimeUnit.HOURS.toMillis(24) // Cache for 24 hours

        // Get registry URL from EnvironmentManager
        private val registryUrl: String
            get() = EnvironmentManager.getIssuersRegistry()

        suspend fun loadIssuers(): IssuerRegistry =
            withContext(Dispatchers.IO) {
                // Return cached if still valid
                cachedRegistry?.let { cached ->
                    if (System.currentTimeMillis() - lastFetchTime < CACHE_DURATION_MS) {
                        return@withContext cached
                    }
                }

                try {
                    Timber.d("Loading issuers from: $registryUrl (${EnvironmentManager.getCurrentEnvironment()} environment)")

                    val request =
                        Request.Builder()
                            .url(registryUrl)
                            .addHeader("User-Agent", "ProviiWallet-Android/1.0")
                            .build()

                    val response = httpClient.newCall(request).execute()

                    if (response.isSuccessful) {
                        val body = response.body?.string() ?: throw Exception("Empty response")
                        val registry = json.decodeFromString<IssuerRegistry>(body)

                        cachedRegistry = registry
                        lastFetchTime = System.currentTimeMillis()

                        Timber.d("Loaded ${registry.issuers.size} issuers from registry (${EnvironmentManager.getCurrentEnvironment()})")
                        registry
                    } else {
                        throw Exception("Failed to fetch issuers: ${response.code}")
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Failed to load issuer registry from $registryUrl")

                    // Return cached version if available, even if expired
                    cachedRegistry?.let {
                        Timber.w("Using expired cache due to network failure")
                        return@withContext it
                    }

                    // SECURITY FIX: Return hardcoded fallback instead of empty registry
                    // Empty registry allows arbitrary issuer URLs to bypass validation
                    Timber.w("Using hardcoded fallback registry due to network failure and no cache")
                    getHardcodedFallbackRegistry()
                }
            }

        /**
         * SECURITY FIX: Hardcoded fallback registry with trusted issuers only.
         * Used when network fails and no cache is available.
         * This prevents arbitrary issuer URLs from being accepted.
         */
        private fun getHardcodedFallbackRegistry(): IssuerRegistry {
            val environment = EnvironmentManager.getCurrentEnvironment()
            return when (environment) {
                "sandbox" ->
                    IssuerRegistry(
                        version = "fallback-1.0-sandbox",
                        lastUpdated = "2024-01-01",
                        description = context.getString(R.string.issuer_fallback_sandbox_description),
                        categories =
                            listOf(
                                IssuerCategory(
                                    id = "government",
                                    name = context.getString(R.string.issuer_fallback_category_government),
                                    description = context.getString(R.string.issuer_fallback_category_government_description),
                                ),
                            ),
                        issuers =
                            listOf(
                                Issuer(
                                    id = "provii-sandbox-issuer",
                                    name = context.getString(R.string.issuer_fallback_sandbox_issuer_name),
                                    description = context.getString(R.string.issuer_fallback_sandbox_issuer_description),
                                    type = "government",
                                    category = "government",
                                    status = "available",
                                    brandColor = "#1E40AF",
                                    logoUrl = null,
                                    verified = true,
                                    instructions = context.getString(R.string.issuer_fallback_sandbox_issuer_instructions),
                                    deepLink = null,
                                    website = "https://sandbox-issuer.provii.app",
                                ),
                            ),
                    )
                else ->
                    IssuerRegistry(
                        version = "fallback-1.0",
                        lastUpdated = "2024-01-01",
                        description = context.getString(R.string.issuer_fallback_production_description),
                        categories =
                            listOf(
                                IssuerCategory(
                                    id = "government",
                                    name = context.getString(R.string.issuer_fallback_category_government),
                                    description = context.getString(R.string.issuer_fallback_category_government_description),
                                ),
                            ),
                        issuers =
                            listOf(
                                Issuer(
                                    id = "provii-dmv",
                                    name = context.getString(R.string.issuer_fallback_production_issuer_name),
                                    description = context.getString(R.string.issuer_fallback_production_issuer_description),
                                    type = "government",
                                    category = "government",
                                    status = "available",
                                    brandColor = "#1E40AF",
                                    logoUrl = null,
                                    verified = true,
                                    instructions = context.getString(R.string.issuer_fallback_production_issuer_instructions),
                                    deepLink = null,
                                    website = "https://issuer.provii.app",
                                ),
                            ),
                    )
            }
        }

        /**
         * SECURITY FIX: Validate that an issuer URL is in the trusted registry.
         * Prevents arbitrary issuer URLs from being accepted.
         */
        suspend fun validateIssuerUrl(url: String): Boolean {
            val normalizedUrl = url.trimEnd('/').lowercase()
            val registry = loadIssuers()
            return registry.issuers.any { issuer ->
                val issuerUrl = issuer.website.trimEnd('/').lowercase()
                normalizedUrl.startsWith(issuerUrl)
            }
        }

        suspend fun refreshIssuers() {
            lastFetchTime = 0 // Force refresh
            loadIssuers()
        }

        fun getIssuersByCategory(categoryId: String): List<Issuer> {
            return cachedRegistry?.issuers?.filter {
                it.category == categoryId
            } ?: emptyList()
        }

        fun getAvailableIssuers(): List<Issuer> {
            return cachedRegistry?.issuers?.filter {
                it.status == "available"
            } ?: emptyList()
        }
    }
