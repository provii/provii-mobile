// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.help

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import app.provii.wallet.ui.accessibility.HelpTopic
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem
import app.provii.wallet.ui.theme.cardFocusIndicator

/**
 * WCAG 2.2 AAA: 3.3.5 Context-Sensitive Help
 * Individual help topic detail screen
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpTopicScreen(
    navController: NavController,
    topicId: String,
) {
    val context = LocalContext.current

    val topic =
        remember(topicId) {
            try {
                HelpTopic.valueOf(topicId)
            } catch (e: IllegalArgumentException) {
                null
            }
        }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        topic?.getTitle(context) ?: stringResource(R.string.help_topic_not_found),
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.content_desc_back))
                    }
                },
            )
        },
    ) { paddingValues ->
        if (topic == null) {
            Box(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.help_topic_not_found),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            Column(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Breadcrumb Navigation (WCAG 2.4.8 AAA)
                Breadcrumb(
                    items =
                        listOf(
                            BreadcrumbItem(stringResource(R.string.breadcrumb_home)),
                            BreadcrumbItem(stringResource(R.string.breadcrumb_settings)),
                            BreadcrumbItem(stringResource(R.string.breadcrumb_help)),
                            BreadcrumbItem(topic.getTitle(context)),
                        ),
                    onNavigate = { index ->
                        when (index) {
                            0 -> navController.popBackStack(navController.graph.startDestinationId, false)
                            1 -> {
                                // Navigate back to Settings
                                navController.popBackStack()
                                navController.popBackStack()
                            }
                            2 -> navController.popBackStack() // Back to Help Centre
                        }
                    },
                )

                // Help text content - grouped as main content region
                Card(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .semantics(mergeDescendants = false) {
                                // Group help content for screen readers
                            },
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.secondaryContainer,
                        ),
                ) {
                    // WCAG 1.4.12: Use wrapContentHeight to allow flexible height for increased text spacing
                    Column(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .wrapContentHeight()
                                .padding(16.dp),
                    ) {
                        // Hidden heading for screen readers to identify content section (WCAG 1.3.1)
                        Text(
                            text = stringResource(R.string.help_content_heading),
                            style = MaterialTheme.typography.titleMedium,
                            modifier =
                                Modifier
                                    .height(0.dp)
                                    .semantics { heading() },
                        )
                        Text(
                            text = topic.getHelpText(context),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }

                // Related topics section
                val relatedTopics =
                    remember(topic) {
                        HelpTopic.getRelatedTopics(topic)
                    }

                if (relatedTopics.isNotEmpty()) {
                    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

                    // Related topics section - semantic grouping for list structure
                    Column(
                        modifier =
                            Modifier.semantics(mergeDescendants = false) {
                                // Group related topics as a semantic list for screen readers
                            },
                    ) {
                        Text(
                            stringResource(R.string.help_related_topics),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            modifier =
                                Modifier
                                    .padding(bottom = 12.dp)
                                    .semantics { heading() },
                        )

                        // Display related topics as clickable cards in a semantic list
                        relatedTopics.forEachIndexed { index, relatedTopic ->
                            RelatedTopicCard(
                                topic = relatedTopic,
                                position = index + 1,
                                total = relatedTopics.size,
                                onClick = {
                                    navController.navigate(Screen.HelpTopic.createRoute(relatedTopic.name))
                                },
                            )
                            if (index < relatedTopics.size - 1) {
                                Spacer(modifier = Modifier.height(8.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Card displaying a related topic with navigation
 * WCAG 1.3.1: Provides position in set for screen reader context
 */
@Composable
private fun RelatedTopicCard(
    topic: HelpTopic,
    position: Int,
    total: Int,
    onClick: () -> Unit,
) {
    val context = LocalContext.current
    val topicPositionDesc =
        stringResource(
            R.string.help_related_topic_position,
            topic.getTitle(context),
            position,
            total,
        )

    Card(
        modifier =
            Modifier
                .fillMaxWidth()
                .cardFocusIndicator()
                .clickable(onClick = onClick)
                .semantics(mergeDescendants = true) {
                    role = Role.Button
                    // Provide list position context for screen readers
                    contentDescription = topicPositionDesc
                },
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant,
            ),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .wrapContentHeight() // WCAG 1.4.12: Allow flexible height for increased text spacing
                    .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier =
                    Modifier
                        .weight(1f)
                        .wrapContentHeight(), // WCAG 1.4.12: Allow flexible height for increased text spacing
            ) {
                Text(
                    text = topic.getTitle(context),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                )
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
