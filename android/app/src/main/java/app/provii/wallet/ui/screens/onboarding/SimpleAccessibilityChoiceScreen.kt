// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton

/**
 * Simple Accessibility Choice Screen - Second screen in onboarding flow.
 *
 * Presents two options:
 * 1. "Use Defaults" - Continue with standard accessibility settings
 * 2. "Accessibility Settings" - Open full accessibility settings screen
 *
 * This screen also detects if TalkBack is enabled and acknowledges it.
 *
 * WCAG 2.2 Compliance:
 * - 2.5.5/2.5.8: 60dp minimum touch targets
 * - 1.4.3: Maintains 4.5:1 contrast ratio via MaterialTheme
 * - 2.4.6: Heading semantics on title
 * - 4.1.2: Content descriptions on all interactive elements
 * - 4.1.3: Live regions for status announcements
 */
@Composable
fun SimpleAccessibilityChoiceScreen(
    onUseDefaults: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    val accessibilityManager = LocalAccessibilityManager.current
    val isTalkBackEnabled by accessibilityManager.isTalkBackEnabled.collectAsState()
    val useDefaultsDesc = stringResource(R.string.onboarding_use_defaults_description)
    val openAccessibilityDesc = stringResource(R.string.onboarding_open_accessibility_description)

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Accessibility icon
            Icon(
                imageVector = Icons.Default.Accessibility,
                contentDescription = null, // Decorative - title provides context
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colorScheme.primary,
            )

            // Title
            Text(
                text = stringResource(R.string.onboarding_accessibility_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )

            // Description
            Text(
                text = stringResource(R.string.onboarding_accessibility_desc),
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            // TalkBack detection notice
            if (isTalkBackEnabled) {
                Card(
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                        ),
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .semantics {
                                liveRegion = LiveRegionMode.Polite
                            },
                ) {
                    Row(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Default.Accessibility,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = stringResource(R.string.onboarding_talkback_detected),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                            )
                            Text(
                                text = stringResource(R.string.onboarding_talkback_message),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                            )
                        }
                    }
                }
            }

            // Feature highlights
            Card(
                colors =
                    CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    ),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = stringResource(R.string.onboarding_accessibility_features_title),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                    )
                    FeatureItem(stringResource(R.string.onboarding_feature_text_size))
                    FeatureItem(stringResource(R.string.onboarding_feature_touch_targets))
                    FeatureItem(stringResource(R.string.onboarding_feature_reduce_motion))
                    FeatureItem(stringResource(R.string.onboarding_feature_high_contrast))
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Button 1: "Use Defaults" - Primary button
            AccessiblePrimaryButton(
                text = stringResource(R.string.onboarding_use_defaults),
                onClick = onUseDefaults,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 60.dp)
                        .semantics {
                            contentDescription = useDefaultsDesc
                        },
            )

            // Button 2: "Accessibility Settings" - Secondary button with icon
            OutlinedButton(
                onClick = onOpenSettings,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 60.dp)
                        .semantics {
                            contentDescription = openAccessibilityDesc
                        },
                colors = ButtonDefaults.outlinedButtonColors(),
            ) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.onboarding_open_accessibility),
                    style = MaterialTheme.typography.labelLarge,
                )
            }

            // Helper text
            Text(
                text = stringResource(R.string.onboarding_accessibility_later),
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun FeatureItem(text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(start = 8.dp),
    ) {
        Text(
            text = "\u2022", // Bullet point
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
