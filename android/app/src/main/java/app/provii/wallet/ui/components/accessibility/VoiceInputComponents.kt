// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.VoiceInputController
import app.provii.wallet.ui.theme.focusIndicator

/**
 * Voice input composables for alternative text entry. Provides a standalone
 * [VoiceInputButton], a full [VoiceInputDialog] with confirm/retry/cancel workflow, and
 * a combined [VoiceInputButtonWithDialog] that manages the entire flow. All components
 * honour the enableVoiceInput accessibility setting and announce state changes via
 * live regions for TalkBack users.
 */

/**
 * Voice input button that triggers speech recognition for text entry.
 *
 * Integrates with [VoiceInputController], shows listening state with visual feedback,
 * respects accessibility settings (enableVoiceInput), and provides proper accessibility
 * labels.
 *
 * @param voiceController The voice input controller to use
 * @param enabled Whether the button is enabled
 * @param modifier Optional modifier for the button
 */
@Composable
fun VoiceInputButton(
    voiceController: VoiceInputController,
    enabled: Boolean = true,
    modifier: Modifier = Modifier,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current
    val isListening by voiceController.isListening.collectAsStateWithLifecycle()
    var showPermissionRationale by remember { mutableStateOf(false) }

    // Only show if voice input is enabled in accessibility settings
    if (!accessibilityUiState.settings.enableVoiceInput) {
        return
    }

    val permissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted ->
            if (granted) {
                voiceController.startListening()
            } else {
                showPermissionRationale = true
            }
        }

    val contentDesc =
        stringResource(
            if (isListening) {
                R.string.voice_input_stop_listening
            } else {
                R.string.voice_input_start_listening
            },
        )

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        // Show visual indicator when listening
        if (isListening) {
            VoiceInputIndicator(
                isListening = true,
                size = 48.dp,
            )
        }

        IconButton(
            onClick = {
                if (isListening) {
                    voiceController.stopListening()
                } else if (voiceController.hasRecordAudioPermission()) {
                    voiceController.startListening()
                } else {
                    permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
            },
            enabled = enabled,
            modifier =
                Modifier
                    .size(accessibilityUiState.minTouchTarget)
                    .focusIndicator()
                    .semantics {
                        role = Role.Button
                        this.contentDescription = contentDesc
                    },
        ) {
            Icon(
                Icons.Default.Mic,
                contentDescription = null, // Described by parent
                tint =
                    if (isListening) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    },
            )
        }
    }

    if (showPermissionRationale) {
        AlertDialog(
            onDismissRequest = { showPermissionRationale = false },
            title = { Text(stringResource(R.string.voice_input_permission_title)) },
            text = { Text(stringResource(R.string.voice_input_permission_message)) },
            confirmButton = {
                TextButton(onClick = { showPermissionRationale = false }) {
                    Text(stringResource(android.R.string.ok))
                }
            },
        )
    }
}

/**
 * WCAG 2.2 AAA: Voice Input Dialog
 *
 * A dialog that shows the listening state and transcript for voice input.
 * Allows users to confirm, retry, or cancel voice input.
 *
 * Features:
 * - Live region announcements for accessibility
 * - Clear visual feedback for listening state
 * - Confirmation workflow for transcript
 * - Error handling with retry option
 *
 * @param isListening Whether currently listening for voice input
 * @param transcript The recognized text transcript
 * @param errorMessage Optional error message to display
 * @param onConfirm Callback when user confirms the transcript
 * @param onCancel Callback when user cancels
 * @param onRetry Callback when user wants to retry
 */
@Composable
fun VoiceInputDialog(
    isListening: Boolean,
    transcript: String,
    errorMessage: String? = null,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
    onRetry: () -> Unit,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current

    AlertDialog(
        onDismissRequest = onCancel,
        icon = {
            VoiceInputIndicator(
                isListening = isListening,
                size = 64.dp,
            )
        },
        title = {
            Text(
                text =
                    stringResource(
                        if (isListening) {
                            R.string.voice_input_listening
                        } else if (errorMessage != null) {
                            R.string.voice_input_error
                        } else {
                            R.string.voice_input_recognized
                        },
                    ),
                modifier =
                    Modifier.semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                when {
                    isListening -> {
                        // Listening state
                        Text(
                            text =
                                if (transcript.isEmpty()) {
                                    stringResource(R.string.voice_input_tap_to_speak)
                                } else {
                                    transcript
                                },
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center,
                            modifier =
                                Modifier.semantics {
                                    liveRegion = LiveRegionMode.Polite
                                },
                        )
                    }
                    errorMessage != null -> {
                        // Error state
                        VoiceInputError(errorMessage = errorMessage)
                    }
                    transcript.isNotEmpty() -> {
                        // Confirmation state
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors =
                                CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                ),
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    text = stringResource(R.string.voice_input_did_you_say),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                )
                                Text(
                                    text = "\"$transcript\"",
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier,
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (!isListening && transcript.isNotEmpty() && errorMessage == null) {
                TextButton(
                    onClick = onConfirm,
                    modifier =
                        Modifier
                            .heightIn(min = accessibilityUiState.minTouchTarget)
                            .focusIndicator(),
                ) {
                    Text(stringResource(R.string.voice_input_confirm))
                }
            }
        },
        dismissButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (errorMessage != null) {
                    TextButton(
                        onClick = onRetry,
                        modifier =
                            Modifier
                                .heightIn(min = accessibilityUiState.minTouchTarget)
                                .focusIndicator(),
                    ) {
                        Text(stringResource(R.string.voice_input_retry))
                    }
                }
                TextButton(
                    onClick = onCancel,
                    modifier =
                        Modifier
                            .heightIn(min = accessibilityUiState.minTouchTarget)
                            .focusIndicator(),
                ) {
                    Text(stringResource(R.string.voice_input_cancel))
                }
            }
        },
    )
}

/**
 * Alternative voice input button that opens a dialog workflow
 *
 * This component manages the full voice input flow including:
 * - Opening a dialog when clicked
 * - Showing listening state
 * - Displaying transcript
 * - Confirming or retrying input
 *
 * @param onVoiceInput Callback with the confirmed voice input text
 * @param enabled Whether the button is enabled
 * @param modifier Optional modifier for the button
 */
@Composable
fun VoiceInputButtonWithDialog(
    onVoiceInput: (String) -> Unit,
    enabled: Boolean = true,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val voiceController = remember { VoiceInputController(context) }

    DisposableEffect(voiceController) {
        onDispose { voiceController.destroy() }
    }

    val isListening by voiceController.isListening.collectAsStateWithLifecycle()
    val transcript by voiceController.transcript.collectAsStateWithLifecycle()
    val errorMessage by voiceController.errorMessage.collectAsStateWithLifecycle()

    var showDialog by remember { mutableStateOf(false) }
    var showPermissionRationale by remember { mutableStateOf(false) }

    // Only show if voice input is enabled
    if (!accessibilityUiState.settings.enableVoiceInput) {
        return
    }

    val permissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted ->
            if (granted) {
                showDialog = true
            } else {
                showPermissionRationale = true
            }
        }

    // Auto-start listening when dialog opens
    androidx.compose.runtime.LaunchedEffect(showDialog) {
        if (showDialog && !isListening) {
            voiceController.startListening()
        }
    }

    IconButton(
        onClick = {
            if (voiceController.hasRecordAudioPermission()) {
                showDialog = true
            } else {
                permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        },
        enabled = enabled,
        modifier =
            modifier
                .size(accessibilityUiState.minTouchTarget)
                .focusIndicator()
                .semantics { role = Role.Button },
    ) {
        Icon(
            Icons.Default.Mic,
            contentDescription = stringResource(R.string.voice_input_button),
        )
    }

    if (showDialog) {
        VoiceInputDialog(
            isListening = isListening,
            transcript = transcript,
            errorMessage = errorMessage,
            onConfirm = {
                onVoiceInput(transcript)
                showDialog = false
                voiceController.clearTranscript()
                voiceController.stopListening()
            },
            onCancel = {
                showDialog = false
                voiceController.stopListening()
            },
            onRetry = {
                voiceController.clearError()
                voiceController.startListening()
            },
        )
    }

    if (showPermissionRationale) {
        AlertDialog(
            onDismissRequest = { showPermissionRationale = false },
            title = { Text(stringResource(R.string.voice_input_permission_title)) },
            text = { Text(stringResource(R.string.voice_input_permission_message)) },
            confirmButton = {
                TextButton(onClick = { showPermissionRationale = false }) {
                    Text(stringResource(android.R.string.ok))
                }
            },
        )
    }
}
