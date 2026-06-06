// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.help

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import app.provii.wallet.ui.accessibility.Glossary
import app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog
import app.provii.wallet.ui.components.accessibility.AccessibleCard

/**
 * Self-contained help screen with an inline list of common topics and a glossary dialog.
 * Contains a local [HelpTopic] data class (distinct from the accessibility package
 * version) to keep this screen independent of the broader help centre navigation.
 * Each topic expands inline with a content description, and the glossary opens as an
 * accessible alert dialog.
 */

data class HelpTopic(
    val id: Int,
    val title: String,
    val summary: String,
    val content: String,
    val icon: ImageVector,
)

@Composable
fun getHelpTopics(): List<HelpTopic> {
    return listOf(
        HelpTopic(
            id = 1,
            title = stringResource(R.string.help_topic_getting_credential_title),
            summary = stringResource(R.string.help_topic_getting_credential_summary),
            icon = Icons.Default.PersonAdd,
            content = stringResource(R.string.help_topic_getting_credential_content),
        ),
        HelpTopic(
            id = 2,
            title = stringResource(R.string.help_topic_verifying_age_title),
            summary = stringResource(R.string.help_topic_verifying_age_summary),
            icon = Icons.Default.VerifiedUser,
            content = stringResource(R.string.help_topic_verifying_age_content),
        ),
        HelpTopic(
            id = 3,
            title = stringResource(R.string.help_topic_accessibility_title),
            summary = stringResource(R.string.help_topic_accessibility_summary),
            icon = Icons.Default.AccessibilityNew,
            content = stringResource(R.string.help_topic_accessibility_content),
        ),
        HelpTopic(
            id = 4,
            title = stringResource(R.string.help_topic_privacy_security_title),
            summary = stringResource(R.string.help_topic_privacy_security_summary),
            icon = Icons.Default.Security,
            content = stringResource(R.string.help_topic_privacy_security_content),
        ),
        HelpTopic(
            id = 5,
            title = stringResource(R.string.help_topic_troubleshooting_title),
            summary = stringResource(R.string.help_topic_troubleshooting_summary),
            icon = Icons.Default.Build,
            content = stringResource(R.string.help_topic_troubleshooting_content),
        ),
    )
}

@Composable
fun HelpScreen(navController: NavController) {
    var showAccessibilitySettings by remember { mutableStateOf(false) }
    var selectedTopic by remember { mutableStateOf<HelpTopic?>(null) }
    val helpTopics = getHelpTopics()

    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.help_title),
                style = MaterialTheme.typography.headlineLarge,
                modifier = Modifier.semantics { heading() },
            )
        }

        // Quick Access Section
        item {
            Text(
                text = stringResource(R.string.help_quick_access),
                style = MaterialTheme.typography.titleLarge,
                modifier =
                    Modifier
                        .padding(top = 8.dp)
                        .semantics { heading() },
            )
        }

        item {
            QuickAccessCard(
                title = stringResource(R.string.title_accessibility),
                subtitle = stringResource(R.string.accessibility_customize_experience),
                icon = Icons.Default.AccessibilityNew,
            ) {
                navController.navigate(Screen.AccessibilitySettings.route)
            }
        }

        // Help Topics Section
        item {
            Text(
                text = stringResource(R.string.help_topics),
                style = MaterialTheme.typography.titleLarge,
                modifier =
                    Modifier
                        .padding(top = 16.dp)
                        .semantics { heading() },
            )
        }

        items(helpTopics) { topic ->
            HelpTopicCard(topic = topic) {
                selectedTopic = topic
            }
        }

        // Glossary Section
        item {
            Text(
                text = stringResource(R.string.help_glossary),
                style = MaterialTheme.typography.titleLarge,
                modifier =
                    Modifier
                        .padding(top = 16.dp)
                        .semantics { heading() },
            )
        }

        items(Glossary.allEntries()) { entry ->
            GlossaryCard(
                term = stringResource(entry.termRes),
                definition = stringResource(entry.shortDefinitionRes),
            )
        }
    }

    // Help Topic Detail Dialog
    selectedTopic?.let { topic ->
        AccessibleAlertDialog(
            onDismissRequest = { selectedTopic = null },
            icon = { Icon(topic.icon, contentDescription = null /* Decorative - dialog title provides context */) },
            title = { Text(topic.title) },
            text = {
                Text(topic.content)
            },
            confirmButton = {
                TextButton(onClick = { selectedTopic = null }) {
                    Text(stringResource(R.string.action_close))
                }
            },
        )
    }
}

@Composable
private fun QuickAccessCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
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
                contentDescription = null, // Decorative - described by adjacent text title
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(40.dp),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(
                modifier =
                    Modifier
                        .weight(1f)
                        .wrapContentHeight(), // WCAG 1.4.12: Allow flexible height for increased text spacing
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(modifier = Modifier.height(4.dp)) // WCAG 1.4.12: Adequate spacing between text elements
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = stringResource(R.string.accessibility_settings_navigate_description),
            )
        }
    }
}

@Composable
private fun HelpTopicCard(
    topic: HelpTopic,
    onClick: () -> Unit,
) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = topic.title,
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = topic.icon,
                contentDescription = null, // Decorative - described by adjacent text title
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(32.dp),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(
                modifier =
                    Modifier
                        .weight(1f)
                        .wrapContentHeight(), // WCAG 1.4.12: Allow flexible height for increased text spacing
            ) {
                Text(
                    text = topic.title,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Spacer(modifier = Modifier.height(4.dp)) // WCAG 1.4.12: Adequate spacing between text elements
                Text(
                    text = topic.summary,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    // WCAG 1.4.12: Removed maxLines constraint to prevent truncation with increased text spacing
                )
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = stringResource(R.string.accessibility_settings_navigate_description),
            )
        }
    }
}

@Composable
private fun GlossaryCard(
    term: String,
    definition: String,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .wrapContentHeight() // WCAG 1.4.12: Allow flexible height for increased text spacing
                    .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp), // WCAG 1.4.12: Adequate spacing between elements
        ) {
            Text(
                text = term,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = definition,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
