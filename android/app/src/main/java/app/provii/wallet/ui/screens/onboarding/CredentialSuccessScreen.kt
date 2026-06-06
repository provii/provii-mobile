// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import app.provii.wallet.R
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.navigation.Screen
import app.provii.wallet.audio.VerificationSoundManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import kotlinx.coroutines.delay

/**
 * Confirmation screen shown after a credential has been successfully issued and stored.
 * Plays a success sound effect and triggers haptic feedback (if enabled) before
 * auto-navigating to the credential list. TalkBack users receive a live-region
 * announcement of the success state.
 */

@Composable
fun CredentialSuccessScreen(navController: NavController) {
    val accessibilityManager = LocalAccessibilityManager.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val context = LocalContext.current
    val soundManager = remember { VerificationSoundManager(context.applicationContext) }
    DisposableEffect(soundManager) {
        onDispose { soundManager.dispose() }
    }

    // Play verification success sound and haptic feedback when screen loads
    LaunchedEffect(Unit) {
        soundManager.playVerificationSuccess(
            soundEnabled = accessibilityUiState.settings.soundEnabled,
            preset = accessibilityUiState.settings.verificationSoundPreset,
            volumePercent = accessibilityUiState.settings.soundVolume,
            hapticEnabled = accessibilityUiState.settings.hapticFeedback,
        )
    }

    LaunchedEffect(Unit) {
        // WCAG 3.2.5: Respect user's timeout preference
        val timeoutDuration = accessibilityManager.getTimeoutDuration(standard = 3000L)
        if (timeoutDuration != null) {
            delay(timeoutDuration)
            navController.navigate(Screen.CredentialList.route) {
                popUpTo(Screen.AttestationScanner.route) { inclusive = true }
            }
        }
        // If null (NONE mode), user stays on success screen until they manually navigate
    }

    Scaffold { paddingValues ->
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(32.dp),
            ) {
                Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = stringResource(R.string.content_desc_success),
                    modifier = Modifier.size(80.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = stringResource(R.string.credential_stored_successfully),
                    style = MaterialTheme.typography.headlineMedium,
                    textAlign = TextAlign.Center,
                    modifier =
                        Modifier.semantics {
                            heading()
                            liveRegion = LiveRegionMode.Polite
                        },
                )

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = stringResource(R.string.credential_stored_description),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                Spacer(modifier = Modifier.height(32.dp))

                Card(
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                        ),
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            text = stringResource(R.string.credential_can_prove_age),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            textAlign = TextAlign.Center,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                // Show progress indicator only if auto-navigation is enabled
                val timeoutDuration = accessibilityManager.getTimeoutDuration(standard = 3000L)
                if (timeoutDuration != null) {
                    LinearProgressIndicator(modifier = Modifier.fillMaxWidth())

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = stringResource(R.string.credential_returning),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier =
                            Modifier.semantics {
                                liveRegion = LiveRegionMode.Polite
                            },
                    )
                } else {
                    // Manual navigation button when auto-navigation is disabled
                    Button(
                        onClick = {
                            navController.navigate(Screen.CredentialList.route) {
                                popUpTo(Screen.AttestationScanner.route) { inclusive = true }
                            }
                        },
                        modifier =
                            Modifier
                                .fillMaxWidth(0.6f)
                                .heightIn(min = accessibilityUiState.minTouchTarget),
                    ) {
                        Text(stringResource(R.string.credential_view_credentials))
                    }
                }
            }
        }
    }
}
