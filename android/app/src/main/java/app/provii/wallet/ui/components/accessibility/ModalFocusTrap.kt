// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.popup
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.theme.buttonFocusIndicator

/**
 * Modal focus trap and role-styled button system satisfying WCAG 2.1.2 (No Keyboard
 * Trap). Traps Tab/Shift+Tab within a modal overlay while always allowing Escape to
 * dismiss. Provides [AccessibleModalButton] with four role variants (primary, cancel,
 * destructive, secondary) and pre-built confirmation/destructive dialog content
 * composables. Announces modal state changes to TalkBack. Mirrors iOS
 * ModalKeyboardNavigation.swift.
 */
@Composable
fun ModalFocusTrap(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    onConfirm: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val focusManager = LocalFocusManager.current
    val focusRequester = remember { FocusRequester() }
    val context = LocalContext.current

    // Announce modal opened to TalkBack
    LaunchedEffect(Unit) {
        announceModalState(context, isOpening = true)
        kotlinx.coroutines.delay(100)
        try {
            focusRequester.requestFocus()
        } catch (_: Exception) {
            // Focus request may fail if no focusable content exists
        }
    }

    // Announce modal closed when dismissed by any mechanism
    DisposableEffect(Unit) {
        onDispose {
            announceModalState(context, isOpening = false)
        }
    }

    Box(
        modifier =
            modifier
                .focusRequester(focusRequester)
                .focusable()
                .semantics { popup() }
                .onPreviewKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false

                    when {
                        // Escape to dismiss (WCAG 2.1.2: must always be able to leave)
                        event.key == Key.Escape -> {
                            announceModalState(context, isOpening = false)
                            onDismiss()
                            true
                        }
                        // Enter to confirm/activate primary action
                        event.key == Key.Enter -> {
                            if (onConfirm != null) {
                                onConfirm()
                                true
                            } else {
                                // Let the focused element handle it
                                false
                            }
                        }
                        // Tab to move forward (wrap to start if at end)
                        event.key == Key.Tab && !event.isShiftPressed -> {
                            val moved = focusManager.moveFocus(FocusDirection.Next)
                            if (!moved) {
                                try {
                                    focusRequester.requestFocus()
                                } catch (_: Exception) {
                                }
                            }
                            true
                        }
                        // Shift+Tab to move backward (wrap to start if at beginning)
                        event.key == Key.Tab && event.isShiftPressed -> {
                            val moved = focusManager.moveFocus(FocusDirection.Previous)
                            if (!moved) {
                                try {
                                    focusRequester.requestFocus()
                                } catch (_: Exception) {
                                }
                            }
                            true
                        }
                        // Arrow Down to move forward
                        event.key == Key.DirectionDown -> {
                            focusManager.moveFocus(FocusDirection.Down)
                            true
                        }
                        // Arrow Up to move backward
                        event.key == Key.DirectionUp -> {
                            focusManager.moveFocus(FocusDirection.Up)
                            true
                        }
                        // Space to activate focused element
                        event.key == Key.Spacebar -> {
                            // Let the focused element handle it
                            false
                        }
                        else -> false
                    }
                },
    ) {
        content()
    }
}

/**
 * Modal button roles matching iOS ModalButtonRole for styling and accessibility hints.
 */
enum class ModalButtonRole {
    PRIMARY,
    CANCEL,
    DESTRUCTIVE,
    SECONDARY,
}

/**
 * Accessible button intended for use inside a ModalFocusTrap.
 * Provides role-appropriate styling, colours, and accessibility labels.
 * Matches iOS AccessibleModalButton.
 */
@Composable
fun AccessibleModalButton(
    title: String,
    role: ModalButtonRole,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState = LocalAccessibilityUiState.current
    val settings = uiState.settings

    val a11yLabel =
        when (role) {
            ModalButtonRole.PRIMARY -> stringResource(R.string.modal_button_primary_label, title)
            ModalButtonRole.CANCEL -> stringResource(R.string.modal_button_cancel_label, title)
            ModalButtonRole.DESTRUCTIVE -> stringResource(R.string.modal_button_destructive_label, title)
            ModalButtonRole.SECONDARY -> title
        }

    val a11yHint =
        when (role) {
            ModalButtonRole.PRIMARY -> stringResource(R.string.modal_button_primary_hint)
            ModalButtonRole.CANCEL -> stringResource(R.string.modal_button_cancel_hint)
            ModalButtonRole.DESTRUCTIVE -> stringResource(R.string.modal_button_destructive_hint)
            ModalButtonRole.SECONDARY -> stringResource(R.string.modal_button_secondary_hint)
        }

    when (role) {
        ModalButtonRole.PRIMARY -> {
            Button(
                onClick = onClick,
                modifier =
                    modifier
                        .fillMaxWidth()
                        .heightIn(min = uiState.minTouchTarget)
                        .buttonFocusIndicator()
                        .semantics {
                            contentDescription = "$a11yLabel. $a11yHint"
                        },
                shape = RoundedCornerShape(8.dp),
                colors =
                    if (settings.useHighContrast) {
                        ButtonDefaults.buttonColors(
                            containerColor = Color(0xFFFFEB3B),
                            contentColor = Color.Black,
                        )
                    } else {
                        ButtonDefaults.buttonColors()
                    },
            ) {
                Text(
                    text = title,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }

        ModalButtonRole.DESTRUCTIVE -> {
            Button(
                onClick = onClick,
                modifier =
                    modifier
                        .fillMaxWidth()
                        .heightIn(min = uiState.minTouchTarget)
                        .buttonFocusIndicator()
                        .semantics {
                            contentDescription = "$a11yLabel. $a11yHint"
                        },
                shape = RoundedCornerShape(8.dp),
                colors =
                    ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error.copy(alpha = 0.1f),
                        contentColor = if (settings.useHighContrast) Color.Black else MaterialTheme.colorScheme.error,
                    ),
            ) {
                Text(text = title)
            }
        }

        ModalButtonRole.CANCEL, ModalButtonRole.SECONDARY -> {
            OutlinedButton(
                onClick = onClick,
                modifier =
                    modifier
                        .fillMaxWidth()
                        .heightIn(min = uiState.minTouchTarget)
                        .buttonFocusIndicator()
                        .semantics {
                            contentDescription = "$a11yLabel. $a11yHint"
                        },
                shape = RoundedCornerShape(8.dp),
                colors =
                    if (settings.useHighContrast) {
                        ButtonDefaults.outlinedButtonColors(contentColor = Color.Black)
                    } else {
                        ButtonDefaults.outlinedButtonColors()
                    },
            ) {
                Text(text = title)
            }
        }
    }
}

/**
 * Pre-built confirmation dialog content for use with ModalFocusTrap.
 * Includes a title, optional message, confirm button, and cancel button.
 * Matches iOS AccessibleAlertBuilder.confirmation pattern.
 */
@Composable
fun ConfirmationDialogContent(
    title: String,
    message: String? = null,
    confirmTitle: String = stringResource(R.string.modal_confirm),
    cancelTitle: String = stringResource(R.string.modal_cancel),
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(24.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            modifier =
                Modifier.semantics {
                    contentDescription = title
                    heading()
                },
        )

        if (message != null) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        AccessibleModalButton(
            title = confirmTitle,
            role = ModalButtonRole.PRIMARY,
            onClick = onConfirm,
        )

        AccessibleModalButton(
            title = cancelTitle,
            role = ModalButtonRole.CANCEL,
            onClick = onCancel,
        )
    }
}

/**
 * Pre-built destructive dialog content for use with ModalFocusTrap.
 * Includes a title, optional message, destructive action button, and cancel button.
 * Matches iOS AccessibleAlertBuilder.destructive pattern.
 */
@Composable
fun DestructiveDialogContent(
    title: String,
    message: String? = null,
    destructiveTitle: String = stringResource(R.string.modal_delete),
    cancelTitle: String = stringResource(R.string.modal_cancel),
    onDestructive: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(24.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            modifier =
                Modifier.semantics {
                    contentDescription = title
                    heading()
                },
        )

        if (message != null) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        AccessibleModalButton(
            title = cancelTitle,
            role = ModalButtonRole.CANCEL,
            onClick = onCancel,
        )

        AccessibleModalButton(
            title = destructiveTitle,
            role = ModalButtonRole.DESTRUCTIVE,
            onClick = onDestructive,
        )
    }
}

/**
 * Announces modal open/close state to TalkBack.
 */
private fun announceModalState(
    context: android.content.Context,
    isOpening: Boolean,
) {
    val a11yManager =
        context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE)
            as? AccessibilityManager ?: return

    if (!a11yManager.isTouchExplorationEnabled) return

    val message =
        if (isOpening) {
            context.getString(R.string.modal_opened_announcement)
        } else {
            context.getString(R.string.modal_closed_announcement)
        }

    val event =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            AccessibilityEvent(AccessibilityEvent.TYPE_ANNOUNCEMENT)
        } else {
            AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
        }
    event.text.add(message)
    a11yManager.sendAccessibilityEvent(event)
}
