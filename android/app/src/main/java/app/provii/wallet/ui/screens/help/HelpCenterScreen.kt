// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.help

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import app.provii.wallet.ui.accessibility.HelpCategory
import app.provii.wallet.ui.accessibility.HelpTopic
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem
import app.provii.wallet.ui.components.accessibility.AccessibleCard
import app.provii.wallet.ui.theme.circularFocusIndicator

/**
 * WCAG 2.2 AAA: 3.3.5 Context-Sensitive Help
 * Help Centre screen providing access to all help topics organised by category
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpCenterScreen(navController: NavController) {
    val context = LocalContext.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val accessibilitySettings = accessibilityUiState.settings

    var searchQuery by remember { mutableStateOf("") }
    var isSearchActive by remember { mutableStateOf(false) }
    var searchStateAnnouncement by remember { mutableStateOf("") }

    val searchActiveText = stringResource(R.string.help_search_active)
    val searchInactiveText = stringResource(R.string.help_search_inactive)

    // Announce search state changes for accessibility (WCAG 4.1.2)
    LaunchedEffect(isSearchActive) {
        searchStateAnnouncement =
            if (isSearchActive) {
                searchActiveText
            } else {
                searchInactiveText
            }
    }

    val filteredTopics =
        remember(searchQuery) {
            if (searchQuery.isBlank()) {
                emptyList()
            } else {
                HelpTopic.search(searchQuery, context)
            }
        }

    val categories =
        remember {
            HelpCategory.entries.toList()
        }

    // Hidden text for screen reader announcements
    if (searchStateAnnouncement.isNotEmpty()) {
        Text(
            text = searchStateAnnouncement,
            modifier =
                Modifier.semantics {
                    liveRegion = LiveRegionMode.Polite
                },
        )
    }

    Scaffold(
        topBar = {
            if (isSearchActive) {
                SearchBar(
                    inputField = {
                        SearchBarDefaults.InputField(
                            query = searchQuery,
                            onQueryChange = { searchQuery = it },
                            onSearch = { },
                            expanded = true,
                            onExpandedChange = {
                                if (!it) {
                                    isSearchActive = false
                                    searchQuery = ""
                                }
                            },
                            placeholder = { Text(stringResource(R.string.help_search_placeholder)) },
                            leadingIcon = {
                                IconButton(
                                    onClick = {
                                        isSearchActive = false
                                        searchQuery = ""
                                    },
                                    modifier = Modifier.circularFocusIndicator(),
                                ) {
                                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.content_desc_back))
                                }
                            },
                        )
                    },
                    expanded = true,
                    onExpandedChange = {
                        if (!it) {
                            isSearchActive = false
                            searchQuery = ""
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        if (filteredTopics.isEmpty() && searchQuery.isNotBlank()) {
                            item {
                                Text(
                                    stringResource(R.string.help_no_results),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(16.dp),
                                )
                            }
                        } else {
                            items(filteredTopics) { topic ->
                                HelpTopicCard(
                                    topic = topic,
                                    onClick = {
                                        navController.navigate(Screen.HelpTopic.createRoute(topic.name))
                                    },
                                    showDescription = accessibilitySettings.verboseDescriptions,
                                )
                            }
                        }
                    }
                }
            } else {
                TopAppBar(
                    title = {
                        Text(
                            stringResource(R.string.help_center),
                            modifier = Modifier.semantics { heading() },
                        )
                    },
                    navigationIcon = {
                        IconButton(
                            onClick = { navController.popBackStack() },
                            modifier = Modifier.circularFocusIndicator(),
                        ) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.content_desc_back))
                        }
                    },
                    actions = {
                        IconButton(
                            onClick = { isSearchActive = true },
                            modifier = Modifier.circularFocusIndicator(),
                        ) {
                            Icon(Icons.Default.Search, contentDescription = stringResource(R.string.help_search))
                        }
                    },
                )
            }
        },
    ) { paddingValues ->
        if (!isSearchActive) {
            LazyColumn(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Breadcrumb Navigation (WCAG 2.4.8 AAA)
                item {
                    Breadcrumb(
                        items =
                            listOf(
                                BreadcrumbItem(stringResource(R.string.breadcrumb_home)),
                                BreadcrumbItem(stringResource(R.string.breadcrumb_settings)),
                                BreadcrumbItem(stringResource(R.string.breadcrumb_help)),
                            ),
                        onNavigate = { index ->
                            when (index) {
                                0 -> navController.popBackStack(navController.graph.startDestinationId, false)
                                1 -> navController.popBackStack()
                            }
                        },
                    )
                }

                item {
                    Text(
                        stringResource(R.string.help_center_description),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                items(categories) { category ->
                    HelpCategorySection(
                        category = category,
                        onTopicClick = { topic ->
                            navController.navigate(Screen.HelpTopic.createRoute(topic.name))
                        },
                        showDescription = accessibilitySettings.verboseDescriptions,
                    )
                }
            }
        }
    }
}

@Composable
private fun HelpCategorySection(
    category: HelpCategory,
    onTopicClick: (HelpTopic) -> Unit,
    showDescription: Boolean,
) {
    val topics =
        remember(category) {
            HelpTopic.topicsByCategory(category)
        }

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text =
                when (category) {
                    HelpCategory.VISION -> stringResource(R.string.help_category_vision)
                    HelpCategory.TYPOGRAPHY -> stringResource(R.string.help_category_typography)
                    HelpCategory.INTERACTION -> stringResource(R.string.help_category_interaction)
                    HelpCategory.COGNITIVE -> stringResource(R.string.help_category_cognitive)
                    HelpCategory.ALTERNATIVE_INPUT -> stringResource(R.string.help_category_alternative_input)
                    HelpCategory.FEATURES -> stringResource(R.string.help_category_features)
                },
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(vertical = 8.dp),
        )

        topics.forEach { topic ->
            HelpTopicCard(
                topic = topic,
                onClick = { onTopicClick(topic) },
                showDescription = showDescription,
            )
        }
    }
}

@Composable
private fun HelpTopicCard(
    topic: HelpTopic,
    onClick: () -> Unit,
    showDescription: Boolean,
) {
    val context = LocalContext.current
    val topicTitle = topic.getTitle(context)
    val topicHelpText = topic.getHelpText(context)

    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = topicTitle,
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
                    text = topicTitle,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                )
                if (showDescription) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = topicHelpText.take(100) + stringResource(R.string.help_text_ellipsis),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null, // Decorative - navigation indicated by row semantics
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
