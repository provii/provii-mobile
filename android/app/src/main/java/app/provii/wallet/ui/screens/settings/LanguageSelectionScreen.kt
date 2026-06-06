// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.settings

import android.app.Activity
import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Language
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import app.provii.wallet.ui.components.accessibility.AccessibleCard
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.os.LocaleListCompat
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.security.SecurePreferencesManager
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem
import app.provii.wallet.utils.Language
import app.provii.wallet.utils.LanguageConfig
import timber.log.Timber

/**
 * Language selection screen for changing app language
 * Supports all 62 languages with proper RTL support
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LanguageSelectionScreen(navController: NavController) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current

    // Get current locale
    val currentLocales = AppCompatDelegate.getApplicationLocales()
    val currentLanguageCode =
        if (currentLocales.isEmpty) {
            configuration.locales[0].language
        } else {
            currentLocales[0]?.language ?: "en"
        }

    var selectedLanguage by remember { mutableStateOf(currentLanguageCode) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(R.string.language_selection_title),
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.content_desc_back),
                        )
                    }
                },
            )
        },
    ) { paddingValues ->
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Breadcrumb Navigation (WCAG 2.4.8 AAA)
            item {
                Breadcrumb(
                    items =
                        listOf(
                            BreadcrumbItem(stringResource(R.string.breadcrumb_home)),
                            BreadcrumbItem(stringResource(R.string.breadcrumb_settings)),
                            BreadcrumbItem(stringResource(R.string.breadcrumb_language)),
                        ),
                    onNavigate = { index ->
                        when (index) {
                            0 -> navController.popBackStack(navController.graph.startDestinationId, false)
                            1 -> navController.popBackStack()
                        }
                    },
                )
            }

            // Language selection description
            item {
                Card(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp),
                ) {
                    Row(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Default.Language,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                stringResource(R.string.language_selection_description),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            // List of all supported languages
            items(LanguageConfig.ENABLED_LANGUAGES) { language ->
                LanguageItem(
                    language = language,
                    isSelected = selectedLanguage == language.code,
                    onClick = {
                        selectedLanguage = language.code
                        setAppLanguage(context, language.code)
                    },
                )
            }
        }
    }
}

@Composable
private fun LanguageItem(
    language: Language,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = language.nativeName,
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = language.nativeName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                )
                Text(
                    text = language.englishName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (isSelected) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = stringResource(R.string.language_selected),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

/**
 * Sets the app language and restarts the activity to apply changes
 * MASVS-CODE-1: Uses EncryptedSharedPreferences via SecurePreferencesManager
 */
private fun setAppLanguage(
    context: Context,
    languageCode: String,
) {
    try {
        Timber.d("Setting app language: $languageCode")

        // MASVS-CODE-1: Save to EncryptedSharedPreferences for secure persistence
        val securePrefs = SecurePreferencesManager(context)
        securePrefs.saveLanguageCode(languageCode)

        // Apply language using AndroidX AppCompat
        val localeList = LocaleListCompat.forLanguageTags(languageCode)
        AppCompatDelegate.setApplicationLocales(localeList)

        Timber.d("Language applied successfully: $languageCode")

        // Force activity recreation to fully apply language changes
        // This ensures all system resources (strings, layouts) are reloaded
        (context as? Activity)?.recreate()
    } catch (e: Exception) {
        Timber.e(e, "Failed to set app language: $languageCode")
    }
}
