// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.material3.Card
import androidx.compose.material3.CardColors
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CardElevation
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState

/**
 * Gesture simplification components for motor accessibility. When the user has enabled
 * simplified gestures, complex swipe interactions are replaced with tap and long-press
 * alternatives. Includes [AccessibleInteractiveCard] and a [gestureDescription] modifier
 * that annotates gesture affordances for TalkBack users.
 */

/**
 * WCAG 2.2 AAA - Gesture Simplification.
 *
 * An accessible Card component that provides simplified gesture alternatives.
 * If simplifiedGestures is enabled, uses long-press for actions (easier for motor impairments).
 * If simplifiedGestures is disabled, supports swipe gestures for power users.
 *
 * Usage:
 * ```
 * AccessibleInteractiveCard(
 *     onClick = { /* View details */ },
 *     onLongClick = { /* Show action menu */ },
 *     onSwipeLeft = { /* Share */ },
 *     onSwipeRight = { /* Delete */ }
 * ) {
 *     // Card content
 * }
 * ```
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AccessibleInteractiveCard(
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    onSwipeLeft: (() -> Unit)? = null,
    onSwipeRight: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    shape: Shape = CardDefaults.shape,
    colors: CardColors = CardDefaults.cardColors(),
    elevation: CardElevation = CardDefaults.cardElevation(),
    content: @Composable () -> Unit,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current
    val simplifyGestures = accessibilityUiState.settings.simplifiedGestures

    var swipeDirection by remember { mutableStateOf<String?>(null) }

    val tapToView = stringResource(R.string.gesture_desc_tap_to_view)
    val longPressOptions = stringResource(R.string.gesture_desc_long_press_options)
    val swipeLeft = stringResource(R.string.gesture_desc_swipe_left)
    val swipeRight = stringResource(R.string.gesture_desc_swipe_right)

    val cardModifier =
        if (simplifyGestures) {
            // Simple version: Click and long-press only
            modifier
                .combinedClickable(
                    onClick = onClick,
                    onLongClick = onLongClick,
                )
                .semantics {
                    val actions =
                        buildString {
                            append(tapToView)
                            if (onLongClick != null) {
                                append(longPressOptions)
                            }
                        }
                    contentDescription = actions
                }
        } else {
            // Complex version: Support swipe gestures
            var dragOffset = 0f
            val swipeThreshold = 100f // pixels

            modifier
                .combinedClickable(
                    onClick = onClick,
                    onLongClick = onLongClick,
                )
                .pointerInput(Unit) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            when {
                                dragOffset < -swipeThreshold && onSwipeLeft != null -> {
                                    onSwipeLeft()
                                    swipeDirection = "left"
                                }
                                dragOffset > swipeThreshold && onSwipeRight != null -> {
                                    onSwipeRight()
                                    swipeDirection = "right"
                                }
                            }
                            dragOffset = 0f
                        },
                        onHorizontalDrag = { _, dragAmount ->
                            dragOffset += dragAmount
                        },
                    )
                }
                .semantics {
                    val actions =
                        buildString {
                            append(tapToView)
                            if (onLongClick != null) {
                                append(longPressOptions)
                            }
                            if (onSwipeLeft != null) {
                                append(swipeLeft)
                            }
                            if (onSwipeRight != null) {
                                append(swipeRight)
                            }
                        }
                    contentDescription = actions
                }
        }

    Card(
        modifier = cardModifier,
        shape = shape,
        colors = colors,
        elevation = elevation,
    ) {
        content()
    }
}

/**
 * Extension function to describe gesture alternatives for TalkBack users
 *
 * Note: Since this is a Modifier extension (not a Composable), it cannot use stringResource().
 * Callers should pass localized strings using stringResource(R.string.gesture_desc_tap_to_activate)
 * and format templates using stringResource(R.string.gesture_desc_long_press_format)
 */
fun Modifier.gestureDescription(
    tapAction: String, // Pass stringResource(R.string.gesture_desc_tap_to_activate)
    longPressAction: String? = null,
    swipeActions: String? = null,
    simplifyGestures: Boolean = false,
    longPressFormat: String = ". Long press: %s", // Pass stringResource(R.string.gesture_desc_long_press_format)
    swipeFormat: String = ". %s", // Pass stringResource(R.string.gesture_desc_swipe_format)
): Modifier {
    return this.semantics {
        val description =
            buildString {
                append(tapAction)
                if (simplifyGestures) {
                    if (longPressAction != null) {
                        append(String.format(longPressFormat, longPressAction))
                    }
                } else {
                    if (longPressAction != null) {
                        append(String.format(longPressFormat, longPressAction))
                    }
                    if (swipeActions != null) {
                        append(String.format(swipeFormat, swipeActions))
                    }
                }
            }
        contentDescription = description
    }
}
