// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Language
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton
import app.provii.wallet.utils.AustralianLanguageOrder
import app.provii.wallet.utils.LanguageConfig
import kotlinx.coroutines.delay

/**
 * Simple Language Choice Screen - First screen in onboarding flow.
 *
 * Presents two options:
 * 1. "Use English" - Primary button for English speakers
 * 2. Rotating multilingual button - Shows "Change Language" in English with rotating
 *    translations underneath to help non-English speakers find the option
 *
 * WCAG 2.2 Compliance:
 * - 2.3.2/2.3.3: Animation at 0.4Hz (well under 3Hz limit), respects reduce motion
 * - 2.5.5/2.5.8: 60dp minimum touch targets
 * - 1.4.3: Maintains 4.5:1 contrast ratio via MaterialTheme
 * - 2.4.6: Heading semantics on title
 * - 4.1.2: Content descriptions on all interactive elements
 */
@Composable
fun SimpleLanguageChoiceScreen(
    onUseEnglish: () -> Unit,
    onChangeLanguage: () -> Unit,
) {
    val useEnglishDesc = stringResource(R.string.onboarding_use_english_description)
    val uiState = LocalAccessibilityUiState.current
    val reduceMotion = uiState.settings.reduceMotion || uiState.prefersReducedMotion

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // Language icon
            Icon(
                imageVector = Icons.Default.Language,
                contentDescription = null, // Decorative - title provides context
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colorScheme.primary,
            )

            // Title
            Text(
                text = stringResource(R.string.onboarding_welcome),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )

            // Subtitle
            Text(
                text = stringResource(R.string.onboarding_language_subtitle),
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Button 1: "Use English" - Primary button
            AccessiblePrimaryButton(
                text = stringResource(R.string.onboarding_use_english),
                onClick = onUseEnglish,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 60.dp)
                        .semantics {
                            contentDescription = useEnglishDesc
                        },
            )

            if (LanguageConfig.hasMultipleLanguages) {
                // Button 2: Rotating multilingual button
                RotatingLanguageButton(
                    onClick = onChangeLanguage,
                    reduceMotion = reduceMotion,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .heightIn(min = 72.dp),
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Helper text
                Text(
                    text = stringResource(R.string.onboarding_change_later),
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/**
 * Rotating button that cycles through "Change Language" in different languages.
 * Ordered by Australian population demographics.
 *
 * Animation: 2.5s per language, fade + vertical slide transition
 * WCAG 2.3.2: Animation at 0.4Hz is well under the 3Hz seizure threshold
 */
@Composable
private fun RotatingLanguageButton(
    onClick: () -> Unit,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = context.resources
    val rotationLanguages = remember { AustralianLanguageOrder.ROTATION_LANGUAGES }
    var currentIndex by remember { mutableIntStateOf(0) }

    // Rotate through languages every 2.5 seconds (0.4Hz - safe for WCAG 2.3.2)
    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) {
            while (true) {
                delay(2500)
                currentIndex = (currentIndex + 1) % rotationLanguages.size
            }
        }
    }

    val currentLanguage = rotationLanguages[currentIndex]

    // Determine layout direction for RTL languages
    val layoutDirection = if (currentLanguage.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr

    OutlinedButton(
        onClick = onClick,
        modifier =
            modifier.semantics {
                role = Role.Button
                contentDescription =
                    resources.getString(
                        R.string.onboarding_rotating_button_description,
                        currentLanguage.nativeText,
                    )
                liveRegion = LiveRegionMode.Polite
            },
        colors =
            ButtonDefaults.outlinedButtonColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
        border = ButtonDefaults.outlinedButtonBorder(enabled = true),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(vertical = 8.dp),
        ) {
            // English text (larger, static - not animated)
            Text(
                text = "Change Language",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )

            // Only animate the translation text
            CompositionLocalProvider(LocalLayoutDirection provides layoutDirection) {
                AnimatedContent(
                    targetState = currentLanguage,
                    transitionSpec = {
                        if (reduceMotion) {
                            EnterTransition.None togetherWith ExitTransition.None
                        } else {
                            // Fade + slight vertical slide for smooth transition
                            (
                                fadeIn(animationSpec = tween(300)) +
                                    slideInVertically(
                                        animationSpec = tween(300),
                                        initialOffsetY = { it / 4 },
                                    )
                            ) togetherWith
                                (
                                    fadeOut(animationSpec = tween(300)) +
                                        slideOutVertically(
                                            animationSpec = tween(300),
                                            targetOffsetY = { -it / 4 },
                                        )
                                )
                        }
                    },
                    label = "language_rotation",
                ) { language ->
                    // Native language translation (rotating)
                    Text(
                        text = language.nativeText,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
