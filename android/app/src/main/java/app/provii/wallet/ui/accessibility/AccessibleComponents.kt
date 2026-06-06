// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.content.Context
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/**
 * Typography-related accessibility modifiers and composables targeting WCAG 2.2 AAA
 * criterion 1.4.8. Provides a [Modifier.accessibleTypography] extension that applies
 * line spacing, paragraph spacing, letter spacing, and text width constraints from
 * [AccessibilitySettings]. Also includes [AccessibleText], a drop-in replacement for
 * [Text] that automatically applies these settings.
 */

/**
 * WCAG 2.2 AAA: Typography Controls (1.4.8)
 *
 * Modifier that applies all typography accessibility settings:
 * - Line spacing (1.0x - 2.0x, AAA requires 1.5x)
 * - Paragraph spacing (1.0x - 3.0x, AAA requires 2.0x)
 * - Letter spacing (0.0em - 0.2em, AAA requires 0.12em)
 * - Text width limitations (80 chars comfortable, 60 chars narrow)
 */
@Composable
fun Modifier.accessibleTypography(
    settings: AccessibilitySettings = LocalAccessibilityUiState.current.settings,
): Modifier {
    // Apply text width constraints
    val maxWidth =
        when (settings.textWidth) {
            TextWidth.FULL -> Dp.Unspecified
            TextWidth.COMFORTABLE -> 640.dp // ~80 characters at standard size
            TextWidth.NARROW -> 480.dp // ~60 characters at standard size
        }

    var modifier = this

    if (maxWidth != Dp.Unspecified) {
        modifier = modifier.widthIn(max = maxWidth)
    }

    // Paragraph spacing is handled via padding
    if (settings.paragraphSpacingMultiplier > 1.0f) {
        val extraSpacing = ((settings.paragraphSpacingMultiplier - 1.0f) * 8).dp
        modifier = modifier.padding(bottom = extraSpacing)
    }

    return modifier
}

/**
 * Returns the line height multiplier for text based on accessibility settings.
 * WCAG AAA requires 1.5x line spacing.
 */
fun AccessibilitySettings.getLineHeight(baseSize: TextUnit): TextUnit {
    return baseSize * (1.0f + (lineSpacingMultiplier - 1.0f))
}

/**
 * Returns the letter spacing for text based on accessibility settings.
 * WCAG AAA requires 0.12em letter spacing.
 */
fun AccessibilitySettings.getLetterSpacing(): TextUnit {
    return letterSpacingMultiplier.em
}

/**
 * Accessible Text composable that applies all typography settings.
 * Use this instead of regular Text for accessible content.
 */
@Composable
fun AccessibleText(
    text: String,
    modifier: Modifier = Modifier,
    fontSize: TextUnit = 16.sp,
    textAlign: TextAlign? = null,
) {
    val settings = LocalAccessibilityUiState.current.settings

    Text(
        text = text,
        modifier = modifier.accessibleTypography(settings),
        fontSize = if (settings.useExtraLargeText) fontSize * 1.5f else fontSize,
        lineHeight = settings.getLineHeight(fontSize),
        letterSpacing = settings.getLetterSpacing(),
        textAlign = textAlign,
    )
}

/**
 * Returns whether AAA typography requirements are met.
 */
fun AccessibilitySettings.isTypographyAAA(): Boolean {
    return lineSpacingMultiplier >= 1.5f &&
        paragraphSpacingMultiplier >= 2.0f &&
        letterSpacingMultiplier >= 0.12f
}

/**
 * Returns a description of current typography settings for UI display.
 */
fun AccessibilitySettings.typographyDescription(context: Context): String {
    val parts = mutableListOf<String>()

    if (lineSpacingMultiplier != 1.0f) {
        parts.add("Line: ${String.format("%.1f", lineSpacingMultiplier)}x")
    }
    if (paragraphSpacingMultiplier != 1.0f) {
        parts.add("Para: ${String.format("%.1f", paragraphSpacingMultiplier)}x")
    }
    if (letterSpacingMultiplier != 0.0f) {
        parts.add("Letter: ${String.format("%.2f", letterSpacingMultiplier)}em")
    }
    if (textWidth != TextWidth.FULL) {
        parts.add(textWidth.getDisplayName(context))
    }

    return if (parts.isEmpty()) {
        "Default"
    } else {
        parts.joinToString(", ")
    }
}

/**
 * Announce a message to accessibility services (TalkBack).
 * WCAG 4.1.3 (AAA): Status Messages.
 *
 * Consolidates the duplicated `announceForAccessibility` helper that was
 * previously copied into SettingsScreen, AccessibilitySettingsScreen,
 * PrivacySettingsScreen, and SearchScreen.
 */
fun announceForAccessibility(
    context: Context,
    message: String,
) {
    val accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
    if (accessibilityManager.isEnabled) {
        val event =
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                AccessibilityEvent(AccessibilityEvent.TYPE_ANNOUNCEMENT)
            } else {
                AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
            }
        event.text.add(message)
        accessibilityManager.sendAccessibilityEvent(event)
    }
}
