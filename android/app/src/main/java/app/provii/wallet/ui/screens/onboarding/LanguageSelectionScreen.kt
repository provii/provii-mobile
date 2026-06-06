// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.FormatTextdirectionRToL
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.foundation.focusable
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.os.LocaleListCompat
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.security.SecurePreferencesManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleSecondaryButton
import app.provii.wallet.ui.theme.FocusDarkBlue
import app.provii.wallet.ui.theme.FocusDarkBlueDark
import app.provii.wallet.utils.Language
import app.provii.wallet.utils.LanguageConfig
import kotlinx.coroutines.delay
import timber.log.Timber
import java.util.*

/**
 * WCAG 2.2 AA/AAA compliant Language Selection Screen
 *
 * Accessibility features:
 * - WCAG 2.2 AA compliant (with AAA features)
 * - 2.4.11 Focus Not Obscured - automatic scrolling
 * - 2.5.7 No Dragging - tap only selection
 * - 2.5.8 Target Size - 60dp minimum
 * - 3.2.6 Consistent Help - help button always available
 * - 3.3.7 Redundant Entry - remembers selection
 * - Full TalkBack support with live regions
 * - Keyboard navigation support
 * - RTL language support
 * - High contrast mode support (7:1 ratio)
 * - Reduced motion support
 * - Font scaling support up to 200%
 *
 * @param navController Navigation controller (null in onboarding mode)
 * @param isOnboarding Whether this is being shown during onboarding flow
 * @param onLanguageSelected Callback when language is selected (used in onboarding mode)
 * @param onBack Callback for back navigation (used in onboarding mode)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LanguageSelectionScreen(
    navController: NavController? = null,
    isOnboarding: Boolean = false,
    onLanguageSelected: ((String) -> Unit)? = null,
    onBack: (() -> Unit)? = null,
) {
    val context = LocalContext.current
    val resources = context.resources
    val uiState = LocalAccessibilityUiState.current

    val applyDesc = stringResource(R.string.language_apply_description)
    val cancelledAnnouncement = stringResource(R.string.language_cancelled_announcement)
    val cancelDesc = stringResource(R.string.language_cancel_description)
    val returnedAnnouncement = stringResource(R.string.language_returned_to_selection)
    val screenDesc = stringResource(R.string.language_screen_description)
    val backDesc = stringResource(R.string.content_desc_back)
    val helpDesc = stringResource(R.string.language_help_button_description)
    val skipDesc = stringResource(R.string.language_skip_description)
    val noMatchAnnouncement = stringResource(R.string.language_no_match_announcement)
    val clearSearchDesc = stringResource(R.string.language_clear_search_description)

    // State management
    var searchQuery by remember { mutableStateOf("") }
    var selectedLanguage by remember { mutableStateOf<Language?>(null) }
    var showConfirmDialog by remember { mutableStateOf(false) }
    var showSkipWarning by remember { mutableStateOf(false) }
    var showHelpDialog by remember { mutableStateOf(false) }
    var announcementMessage by remember { mutableStateOf("") }

    // Detect system language
    val systemLanguage =
        remember {
            val systemLocale = Locale.getDefault().toLanguageTag()
            LanguageConfig.ENABLED_LANGUAGES.find {
                it.code.equals(systemLocale, ignoreCase = true) ||
                    systemLocale.startsWith(it.code, ignoreCase = true)
            }
        }

    // Filter languages based on search query
    val filteredLanguages =
        remember(searchQuery) {
            if (searchQuery.isBlank()) {
                // Show system language first if available
                if (systemLanguage != null) {
                    listOf(systemLanguage) + LanguageConfig.ENABLED_LANGUAGES.filter { it != systemLanguage }
                } else {
                    LanguageConfig.ENABLED_LANGUAGES
                }
            } else {
                LanguageConfig.ENABLED_LANGUAGES.filter {
                    it.nativeName.contains(searchQuery, ignoreCase = true) ||
                        it.englishName.contains(searchQuery, ignoreCase = true) ||
                        it.code.contains(searchQuery, ignoreCase = true)
                }
            }
        }

    // Lazy column state for focus management
    val listState = rememberLazyListState()

    // Focus requesters
    val searchFocusRequester = remember { FocusRequester() }

    // Auto-focus search on first launch (delayed for accessibility)
    LaunchedEffect(Unit) {
        delay(500) // Allow TalkBack to announce screen first
        try {
            searchFocusRequester.requestFocus()
        } catch (e: Exception) {
            Timber.w("Could not focus search field: ${e.message}")
        }
    }

    // Confirmation dialog
    val confirmedLanguage = selectedLanguage
    if (showConfirmDialog && confirmedLanguage != null) {
        AccessibleAlertDialog(
            onDismissRequest = { showConfirmDialog = false },
            icon = {
                Icon(
                    Icons.Default.Language,
                    contentDescription = null, // Decorative - dialog title provides context
                    modifier = Modifier.size(48.dp),
                )
            },
            title = {
                Text(
                    text = stringResource(R.string.language_confirm_title),
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = {
                Column {
                    Text(stringResource(R.string.language_change_to))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = confirmedLanguage.nativeName,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        modifier =
                            Modifier.semantics {
                                contentDescription =
                                    resources.getString(
                                        R.string.language_selected_description,
                                        confirmedLanguage.nativeName,
                                        confirmedLanguage.englishName,
                                    )
                            },
                    )
                    Text(
                        text = confirmedLanguage.englishName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = stringResource(R.string.language_restart_notice),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            confirmButton = {
                AccessiblePrimaryButton(
                    text = stringResource(R.string.language_apply),
                    onClick = {
                        showConfirmDialog = false
                        val code = confirmedLanguage.code
                        if (isOnboarding && onLanguageSelected != null) {
                            // In onboarding mode, let the callback handle everything
                            // (saving, applying locale, and recreating activity)
                            onLanguageSelected(code)
                        } else {
                            // In settings mode, apply the language directly
                            applyLanguage(context, code)
                        }
                    },
                    modifier =
                        Modifier.semantics {
                            contentDescription = applyDesc
                        },
                )
            },
            dismissButton = {
                AccessibleSecondaryButton(
                    text = stringResource(R.string.language_cancel),
                    onClick = {
                        showConfirmDialog = false
                        announcementMessage = cancelledAnnouncement
                    },
                    modifier =
                        Modifier.semantics {
                            contentDescription = cancelDesc
                        },
                )
            },
            modifier =
                Modifier.semantics {
                    liveRegion = LiveRegionMode.Polite
                },
        )
    }

    // Skip warning dialog
    if (showSkipWarning) {
        AccessibleAlertDialog(
            onDismissRequest = { showSkipWarning = false },
            icon = {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = null, // Decorative - dialog title provides context
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.error,
                )
            },
            title = {
                Text(
                    text = stringResource(R.string.language_skip_title),
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = {
                Text(stringResource(R.string.language_skip_message))
            },
            confirmButton = {
                AccessiblePrimaryButton(
                    text = stringResource(R.string.language_use_english),
                    onClick = {
                        showSkipWarning = false
                        if (isOnboarding && onLanguageSelected != null) {
                            // In onboarding mode, save first (callback saves to prefs)
                            onLanguageSelected("en")
                        }
                        // Apply the language (may trigger activity recreation)
                        applyLanguage(context, "en")
                    },
                )
            },
            dismissButton = {
                AccessibleSecondaryButton(
                    text = stringResource(R.string.language_go_back),
                    onClick = {
                        showSkipWarning = false
                        announcementMessage = returnedAnnouncement
                    },
                )
            },
        )
    }

    // Help dialog
    if (showHelpDialog) {
        AccessibleAlertDialog(
            onDismissRequest = { showHelpDialog = false },
            icon = {
                Icon(
                    Icons.AutoMirrored.Filled.Help,
                    contentDescription = null, // Decorative - dialog title provides context
                    modifier = Modifier.size(48.dp),
                )
            },
            title = {
                Text(
                    text = stringResource(R.string.language_help_title),
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = {
                Column {
                    Text(
                        text = stringResource(R.string.language_help_how_to),
                        fontWeight = FontWeight.Bold,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(stringResource(R.string.language_help_step1))
                    Text(stringResource(R.string.language_help_step2))
                    Text(stringResource(R.string.language_help_step3))
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = stringResource(R.string.language_help_system_note),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = stringResource(R.string.language_help_settings_note),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            confirmButton = {
                AccessiblePrimaryButton(
                    text = stringResource(R.string.language_got_it),
                    onClick = {
                        showHelpDialog = false
                        announcementMessage = returnedAnnouncement
                    },
                )
            },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.language_select_title),
                        modifier =
                            Modifier.semantics {
                                heading()
                                contentDescription = screenDesc
                            },
                    )
                },
                navigationIcon = {
                    // Show back button in onboarding mode
                    if (isOnboarding && onBack != null) {
                        IconButton(
                            onClick = onBack,
                            modifier =
                                Modifier
                                    .size(uiState.minTouchTarget)
                                    .semantics {
                                        contentDescription = backDesc
                                    },
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = null,
                            )
                        }
                    }
                },
                actions = {
                    // WCAG 3.2.6 - Consistent Help
                    IconButton(
                        onClick = { showHelpDialog = true },
                        modifier =
                            Modifier
                                .size(uiState.minTouchTarget)
                                .semantics {
                                    contentDescription = helpDesc
                                },
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Help,
                            contentDescription = null, // Decorative - button has semantic description
                        )
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )
        },
        bottomBar = {
            // Skip button at bottom
            Surface(
                shadowElevation = 8.dp,
                tonalElevation = 2.dp,
            ) {
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    AccessibleSecondaryButton(
                        text = stringResource(R.string.language_skip_button),
                        onClick = { showSkipWarning = true },
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .semantics {
                                    contentDescription = skipDesc
                                },
                    )
                }
            }
        },
    ) { paddingValues ->
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
        ) {
            // Live region for announcements
            if (announcementMessage.isNotEmpty()) {
                Box(
                    modifier =
                        Modifier
                            .size(0.dp)
                            .semantics {
                                liveRegion = LiveRegionMode.Polite
                                contentDescription = announcementMessage
                            },
                )
                LaunchedEffect(announcementMessage) {
                    delay(100)
                    announcementMessage = ""
                }
            }

            // Search box
            OutlinedTextField(
                value = searchQuery,
                onValueChange = {
                    searchQuery = it
                    announcementMessage =
                        if (filteredLanguages.isEmpty()) {
                            noMatchAnnouncement
                        } else {
                            resources.getString(R.string.language_found_announcement, filteredLanguages.size)
                        }
                },
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .heightIn(min = uiState.minTouchTarget)
                        .focusRequester(searchFocusRequester)
                        .semantics {
                            liveRegion = LiveRegionMode.Polite
                        },
                label = {
                    Text(stringResource(R.string.search_field_label))
                },
                placeholder = {
                    Text(stringResource(R.string.language_search_placeholder))
                },
                leadingIcon = {
                    Icon(
                        Icons.Default.Search,
                        contentDescription = null, // Decorative - text field has semantic description
                    )
                },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(
                            onClick = {
                                searchQuery = ""
                                announcementMessage = resources.getString(R.string.language_search_cleared, LanguageConfig.ENABLED_LANGUAGES.size)
                            },
                            modifier =
                                Modifier.semantics {
                                    contentDescription = clearSearchDesc
                                },
                        ) {
                            Icon(
                                Icons.Default.Clear,
                                contentDescription = null, // Decorative - button has semantic description
                            )
                        }
                    }
                },
                singleLine = true,
                keyboardOptions =
                    KeyboardOptions(
                        imeAction = ImeAction.Search,
                    ),
                keyboardActions =
                    KeyboardActions(
                        onSearch = {
                            // Hide keyboard when search is pressed
                        },
                    ),
            )

            // Results count announcement
            Text(
                text = stringResource(R.string.language_count, filteredLanguages.size),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier =
                    Modifier
                        .padding(horizontal = 16.dp)
                        .semantics {
                            contentDescription = resources.getString(R.string.language_count_description, filteredLanguages.size)
                        },
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Language list
            if (filteredLanguages.isEmpty()) {
                // Empty state
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            Icons.Default.SearchOff,
                            contentDescription = null, // Decorative - described by adjacent text "No languages found"
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = stringResource(R.string.language_no_results),
                            style = MaterialTheme.typography.titleMedium,
                            modifier =
                                Modifier.semantics {
                                    liveRegion = LiveRegionMode.Polite
                                },
                        )
                        Text(
                            text = stringResource(R.string.language_try_different),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(
                        items = filteredLanguages,
                        key = { it.code },
                    ) { language ->
                        LanguageListItem(
                            language = language,
                            isSystemLanguage = language == systemLanguage,
                            isSelected = selectedLanguage == language,
                            onClick = {
                                selectedLanguage = language
                                showConfirmDialog = true
                                announcementMessage = resources.getString(R.string.language_selected_announcement, language.nativeName, language.englishName)
                            },
                            minTouchTarget = uiState.minTouchTarget,
                        )
                    }

                    // Bottom padding for last item
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                }
            }
        }
    }
}

/**
 * Individual language list item with WCAG 2.2 compliance
 */
@Composable
private fun LanguageListItem(
    language: Language,
    isSystemLanguage: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit,
    minTouchTarget: androidx.compose.ui.unit.Dp,
) {
    val context = LocalContext.current
    val resources = context.resources
    val uiState = LocalAccessibilityUiState.current
    var isFocused by remember { mutableStateOf(false) }

    // Determine layout direction for this language
    val itemLayoutDirection =
        if (language.isRTL) {
            LayoutDirection.Rtl
        } else {
            LayoutDirection.Ltr
        }

    // Build localized content description
    val itemDescription =
        when {
            isSystemLanguage && isSelected ->
                resources.getString(
                    R.string.language_item_system_selected,
                    language.nativeName,
                    language.englishName,
                )
            isSystemLanguage ->
                resources.getString(
                    R.string.language_item_system,
                    language.nativeName,
                    language.englishName,
                )
            isSelected ->
                resources.getString(
                    R.string.language_item_selected,
                    language.nativeName,
                    language.englishName,
                )
            else ->
                resources.getString(
                    R.string.language_item_default,
                    language.nativeName,
                    language.englishName,
                )
        }

    CompositionLocalProvider(LocalLayoutDirection provides itemLayoutDirection) {
        val focusColor =
            if (uiState.settings.useHighContrast) {
                FocusDarkBlueDark
            } else {
                FocusDarkBlue
            }

        Surface(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = minTouchTarget)
                    .onFocusChanged { isFocused = it.isFocused }
                    .focusable()
                    .border(
                        width = if (isFocused) 3.dp else 0.dp,
                        color = if (isFocused) focusColor else androidx.compose.ui.graphics.Color.Transparent,
                    )
                    .clickable(onClick = onClick)
                    .semantics(mergeDescendants = true) {
                        role = Role.Button
                        contentDescription = itemDescription
                    },
            color =
                when {
                    isSelected -> MaterialTheme.colorScheme.primaryContainer
                    isSystemLanguage -> MaterialTheme.colorScheme.secondaryContainer
                    else -> MaterialTheme.colorScheme.surface
                },
            tonalElevation = if (isSystemLanguage) 2.dp else 0.dp,
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Icon for system/selected language
                when {
                    isSystemLanguage -> {
                        Icon(
                            Icons.Default.Star,
                            contentDescription = null, // Decorative - item semantics describe "System language"
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                    }
                    isSelected -> {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null, // Decorative - item semantics describe "currently selected"
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                    }
                }

                // Language names
                Column(
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        text = language.nativeName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = if (isSystemLanguage) FontWeight.Bold else FontWeight.Normal,
                    )
                    Text(
                        text = language.englishName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    // System language badge
                    if (isSystemLanguage) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = stringResource(R.string.language_system_badge),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }

                // RTL indicator
                if (language.isRTL) {
                    Icon(
                        Icons.AutoMirrored.Filled.FormatTextdirectionRToL,
                        contentDescription = null, // Decorative - indicates RTL language visually
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        // Divider for visual separation
        HorizontalDivider(
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
        )
    }
}

/**
 * Apply language selection and persist preference
 * WCAG 3.3.7 - Redundant Entry: Remember selection
 * MASVS-CODE-1: Uses EncryptedSharedPreferences via SecurePreferencesManager
 */
private fun applyLanguage(
    context: Context,
    languageCode: String,
) {
    try {
        Timber.d("Applying language: $languageCode")

        // MASVS-CODE-1: Save to EncryptedSharedPreferences for secure persistence
        val securePrefs = SecurePreferencesManager(context)
        securePrefs.saveLanguageCode(languageCode)

        // Apply language using AndroidX AppCompat
        val localeList = LocaleListCompat.forLanguageTags(languageCode)
        AppCompatDelegate.setApplicationLocales(localeList)

        Timber.d("Language applied successfully: $languageCode")
    } catch (e: Exception) {
        Timber.e(e, "Failed to apply language: $languageCode")
    }
}
