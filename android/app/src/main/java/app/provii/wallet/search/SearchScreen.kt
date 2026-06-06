// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.search

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CollectionInfo
import androidx.compose.ui.semantics.CollectionItemInfo
import androidx.compose.ui.semantics.collectionInfo
import androidx.compose.ui.semantics.collectionItemInfo
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import app.provii.wallet.ui.accessibility.announceForAccessibility
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessibleCard

/**
 * Full-screen search UI with keyboard-focused entry, popular searches, and live
 * result announcements for TalkBack. Conforms to WCAG 1.3.1 (collection semantics),
 * WCAG 2.4.3 (focus management), and WCAG 4.1.3 (status messages via live regions).
 * Search results are debounce-announced to avoid rapid-fire TalkBack interruptions.
 */

// announceForAccessibility is now imported from app.provii.wallet.ui.accessibility.announceForAccessibility

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    navController: NavController,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    val searchManager = remember { SearchManager(context) }
    val accessibilityUiState = LocalAccessibilityUiState.current
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current

    val noResultsText = stringResource(R.string.search_no_results_announcement)
    val singularResultText = stringResource(R.string.search_results_announcement_singular)

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    // Announce search results changes to screen readers (WCAG 4.1.3)
    // Debounced to avoid rapid-fire announcements during typing
    LaunchedEffect(searchManager.searchResults.size, searchManager.searchQuery) {
        if (searchManager.searchQuery.isNotEmpty()) {
            kotlinx.coroutines.delay(400) // Wait for typing pause
            val announcement =
                when (searchManager.searchResults.size) {
                    0 -> noResultsText
                    1 -> singularResultText
                    else -> resources.getString(R.string.search_results_announcement_plural, searchManager.searchResults.size)
                }
            announceForAccessibility(context, announcement)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.search_title)) },
                actions = {
                    TextButton(
                        onClick = onDismiss,
                        modifier = Modifier.heightIn(min = accessibilityUiState.minTouchTarget),
                    ) {
                        Text(stringResource(R.string.action_done))
                    }
                },
            )
        },
    ) { paddingValues ->
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
        ) {
            // Search Field
            OutlinedTextField(
                value = searchManager.searchQuery,
                onValueChange = { searchManager.search(it) },
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .focusRequester(focusRequester),
                label = { Text(stringResource(R.string.search_field_label)) },
                placeholder = { Text(stringResource(R.string.search_placeholder)) },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null, // Decorative - search field has label
                    )
                },
                trailingIcon = {
                    if (searchManager.searchQuery.isNotEmpty()) {
                        IconButton(
                            onClick = { searchManager.clearSearch() },
                            modifier = Modifier.size(accessibilityUiState.minTouchTarget),
                        ) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = stringResource(R.string.search_clear),
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
                            // Clear focus when search action is triggered (WCAG 2.4.3)
                            focusManager.clearFocus()
                        },
                    ),
            )

            // Content
            when {
                searchManager.searchQuery.isEmpty() -> {
                    PopularSearchesContent(navController, onDismiss)
                }
                searchManager.searchResults.isEmpty() -> {
                    NoResultsContent()
                }
                else -> {
                    SearchResultsContent(
                        results = searchManager.searchResults,
                        navController = navController,
                        onDismiss = onDismiss,
                    )
                }
            }
        }
    }
}

@Composable
private fun PopularSearchesContent(
    navController: NavController,
    onDismiss: () -> Unit,
) {
    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(16.dp)
                .semantics {
                    // Mark as a collection/list for screen readers (WCAG 1.3.1)
                    collectionInfo = CollectionInfo(rowCount = 4, columnCount = 1)
                },
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.search_popular),
                style = MaterialTheme.typography.titleLarge,
                modifier =
                    Modifier
                        .padding(bottom = 8.dp)
                        .semantics { heading() }, // Mark as heading for screen readers (WCAG 1.3.1)
            )
        }

        item {
            QuickAccessCard(
                title = stringResource(R.string.title_accessibility),
                icon = Icons.Default.AccessibilityNew,
                itemIndex = 0,
                totalItems = 4,
            ) {
                onDismiss()
                navController.navigate(Screen.AccessibilitySettings.route)
            }
        }

        item {
            QuickAccessCard(
                title = stringResource(R.string.settings_language),
                icon = Icons.Default.Language,
                itemIndex = 1,
                totalItems = 4,
            ) {
                onDismiss()
                navController.navigate(Screen.LanguageSelection.route)
            }
        }

        item {
            QuickAccessCard(
                title = stringResource(R.string.action_get_credential),
                icon = Icons.Default.Add,
                itemIndex = 2,
                totalItems = 4,
            ) {
                onDismiss()
                navController.navigate(Screen.WhereToGetCredentials.createRoute())
            }
        }

        item {
            QuickAccessCard(
                title = stringResource(R.string.help_title),
                icon = Icons.AutoMirrored.Filled.Help,
                itemIndex = 3,
                totalItems = 4,
            ) {
                onDismiss()
                // Navigate to help tab (handled by bottom nav)
            }
        }
    }
}

@Composable
private fun SearchResultsContent(
    results: List<SearchableItem>,
    navController: NavController,
    onDismiss: () -> Unit,
) {
    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(16.dp)
                .semantics {
                    // Mark as a collection/list for screen readers (WCAG 1.3.1)
                    collectionInfo = CollectionInfo(rowCount = results.size, columnCount = 1)
                },
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.search_results_heading),
                style = MaterialTheme.typography.titleLarge,
                modifier =
                    Modifier
                        .padding(bottom = 8.dp)
                        .semantics { heading() }, // Mark as heading for screen readers (WCAG 1.3.1)
            )
            // Live region announcement for TalkBack: result count (WCAG 4.1.3)
            Text(
                text = stringResource(R.string.search_results_announcement_plural, results.size),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier =
                    Modifier.semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
            )
        }

        items(results) { item ->
            val itemIndex = results.indexOf(item)
            SearchResultCard(
                item = item,
                itemIndex = itemIndex,
                totalItems = results.size,
            ) {
                handleItemSelection(item, navController, onDismiss)
            }
        }
    }
}

@Composable
private fun NoResultsContent() {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Default.Search,
            contentDescription = null, // Decorative - no results state described by adjacent text
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = stringResource(R.string.search_no_results),
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.semantics { heading() }, // Mark as heading for screen readers (WCAG 1.3.1)
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = stringResource(R.string.search_try_suggestions),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun QuickAccessCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    itemIndex: Int,
    totalItems: Int,
    onClick: () -> Unit,
) {
    AccessibleCard(
        modifier =
            Modifier
                .fillMaxWidth()
                .semantics {
                    // Mark as collection item for screen readers (WCAG 1.3.1)
                    collectionItemInfo = CollectionItemInfo(rowIndex = itemIndex, rowSpan = 1, columnIndex = 0, columnSpan = 1)
                },
        onClick = onClick,
        contentDescription = title,
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null, // Decorative - category described by adjacent text
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(40.dp),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null, // Decorative - navigation indicated by row semantics
            )
        }
    }
}

@Composable
private fun SearchResultCard(
    item: SearchableItem,
    itemIndex: Int,
    totalItems: Int,
    onClick: () -> Unit,
) {
    AccessibleCard(
        modifier =
            Modifier
                .fillMaxWidth()
                .semantics {
                    // Mark as collection item for screen readers (WCAG 1.3.1)
                    collectionItemInfo = CollectionItemInfo(rowIndex = itemIndex, rowSpan = 1, columnIndex = 0, columnSpan = 1)
                },
        onClick = onClick,
        contentDescription = item.title,
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = item.icon,
                contentDescription = null, // Decorative - search result described by adjacent text
                tint = item.iconColor,
                modifier = Modifier.size(32.dp),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.bodyLarge,
                )
                item.subtitle?.let { subtitle ->
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null, // Decorative - navigation indicated by row semantics
            )
        }
    }
}

private fun handleItemSelection(
    item: SearchableItem,
    navController: NavController,
    onDismiss: () -> Unit,
) {
    onDismiss()

    when (item.destination) {
        SearchDestination.AccessibilitySettings -> {
            navController.navigate(Screen.AccessibilitySettings.route)
        }
        SearchDestination.Settings -> {
            navController.navigate(Screen.Settings.route)
        }
        SearchDestination.Credentials -> {
            navController.navigate(Screen.CredentialList.route)
        }
        SearchDestination.Help -> {
            // Navigate to help tab (handled by bottom nav)
        }
        SearchDestination.WhereToGet -> {
            navController.navigate(Screen.WhereToGetCredentials.createRoute())
        }
        SearchDestination.LanguageSelection -> {
            navController.navigate(Screen.LanguageSelection.route)
        }
        is SearchDestination.SpecificHelpTopic -> {
            // Show help topic detail
            // This would require passing the topic ID to a detail screen
        }
    }
}
