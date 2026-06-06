// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.theme

import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState

/**
 * Compose [Modifier] extensions that draw visible focus indicators around interactive
 * elements during keyboard and accessibility navigation. Satisfies WCAG 2.2 criterion
 * 2.4.13 (Focus Appearance) with a configurable border width, shape, and colour that
 * adapts to the user's high-contrast preference.
 */

/**
 * Adds a visible focus indicator to interactive elements for keyboard and accessibility navigation.
 *
 * This modifier ensures WCAG 2.2 compliance for Focus Appearance (2.4.13) by:
 * - Providing a 2-3dp outline when focused
 * - Using FocusDarkBlue colour with 4.5:1+ contrast ratio (AA) or 7:1+ (AAA)
 * - Supporting both keyboard focus and accessibility focus
 * - Respecting the app's accessibility settings
 *
 * @param borderWidth The width of the focus indicator border (default: 3.dp for AAA compliance)
 * @param shape The shape of the focus indicator (default: rounded corners)
 * @param focusColor The colour of the focus indicator (default: FocusDarkBlue/FocusDarkBlueDark)
 */
fun Modifier.focusIndicator(
    borderWidth: Dp = 3.dp,
    shape: Shape = RoundedCornerShape(8.dp),
    focusColor: Color? = null,
): Modifier =
    composed {
        val uiState = LocalAccessibilityUiState.current
        val isHighContrast = uiState.settings.useHighContrast
        val isDarkTheme = isSystemInDarkTheme()

        // Use custom colour or default based on theme. FocusDarkBlue (0xFF0D47A1) is
        // nearly invisible on dark backgrounds, so switch to FocusDarkBlueDark
        // (0xFF90CAF9) whenever dark theme is active, not only when the user has
        // explicitly enabled high contrast.
        val effectiveFocusColor =
            focusColor ?: if (isHighContrast || isDarkTheme) {
                FocusDarkBlueDark // Lighter colour visible on dark backgrounds
            } else {
                FocusDarkBlue // Standard focus colour for light backgrounds
            }

        var isFocused by remember { mutableStateOf(false) }

        this
            .onFocusChanged { focusState ->
                isFocused = focusState.isFocused || focusState.hasFocus
            }
            .focusable()
            .border(
                width = if (isFocused) borderWidth else 0.dp,
                color = if (isFocused) effectiveFocusColor else Color.Transparent,
                shape = shape,
            )
    }

/**
 * Adds a visible focus indicator specifically for card-like elements.
 * Uses the accessibility settings to determine the corner radius.
 */
fun Modifier.cardFocusIndicator(
    borderWidth: Dp = 3.dp,
    focusColor: Color? = null,
): Modifier =
    composed {
        val uiState = LocalAccessibilityUiState.current
        val shape = RoundedCornerShape(uiState.cardCornerRadius)
        focusIndicator(borderWidth = borderWidth, shape = shape, focusColor = focusColor)
    }

/**
 * Adds a visible focus indicator for button elements.
 * Uses a consistent border width and respects high contrast settings.
 */
fun Modifier.buttonFocusIndicator(
    borderWidth: Dp = 3.dp,
    focusColor: Color? = null,
): Modifier =
    composed {
        val uiState = LocalAccessibilityUiState.current
        val shape = RoundedCornerShape(uiState.cardCornerRadius)
        focusIndicator(borderWidth = borderWidth, shape = shape, focusColor = focusColor)
    }

/**
 * Adds a visible focus indicator for circular elements like icon buttons.
 */
fun Modifier.circularFocusIndicator(
    borderWidth: Dp = 3.dp,
    focusColor: Color? = null,
): Modifier =
    composed {
        focusIndicator(
            borderWidth = borderWidth,
            shape = androidx.compose.foundation.shape.CircleShape,
            focusColor = focusColor,
        )
    }
