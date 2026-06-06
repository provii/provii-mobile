// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.isUnspecified
import androidx.compose.ui.unit.sp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.AccessibilitySettings

/**
 * Typography definitions for the Provii Wallet Android application. Builds on Material3
 * type scale with support for accessibility text scaling (up to 1.45x for extra large text)
 * and WCAG 1.4.12 text spacing adjustments for letter spacing and line height multipliers.
 * The [typographyFor] entry point resolves the final [Typography] from the current
 * [AccessibilitySettings]. When `useDyslexiaFont` is enabled, the OpenDyslexic font family
 * is applied across all styles.
 */

private val OpenDyslexicFontFamily =
    FontFamily(
        Font(R.font.opendyslexic_regular, FontWeight.Normal, FontStyle.Normal),
        Font(R.font.opendyslexic_italic, FontWeight.Normal, FontStyle.Italic),
        Font(R.font.opendyslexic_bold, FontWeight.Bold, FontStyle.Normal),
        Font(R.font.opendyslexic_bolditalic, FontWeight.Bold, FontStyle.Italic),
    )

private fun baseTypography(fontFamily: FontFamily) =
    Typography(
        displayLarge = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.SemiBold, fontSize = 54.sp, lineHeight = 81.sp),
        displayMedium = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.SemiBold, fontSize = 44.sp, lineHeight = 66.sp),
        displaySmall = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.SemiBold, fontSize = 36.sp, lineHeight = 54.sp),
        headlineLarge = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.SemiBold, fontSize = 32.sp, lineHeight = 48.sp),
        headlineMedium = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 28.sp, lineHeight = 42.sp),
        headlineSmall = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 24.sp, lineHeight = 36.sp),
        titleLarge = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 22.sp, lineHeight = 33.sp),
        titleMedium = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 18.sp, lineHeight = 27.sp),
        titleSmall = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 16.sp, lineHeight = 24.sp),
        bodyLarge = TextStyle(fontFamily = fontFamily, fontSize = 16.sp, lineHeight = 24.sp),
        bodyMedium = TextStyle(fontFamily = fontFamily, fontSize = 14.sp, lineHeight = 21.sp),
        bodySmall = TextStyle(fontFamily = fontFamily, fontSize = 12.sp, lineHeight = 18.sp),
        labelLarge = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 21.sp),
        labelMedium = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 18.sp),
        labelSmall = TextStyle(fontFamily = fontFamily, fontWeight = FontWeight.Medium, fontSize = 11.sp, lineHeight = 17.sp),
    )

fun typographyFor(settings: AccessibilitySettings): Typography {
    val scale =
        when {
            settings.useExtraLargeText -> 1.45f
            else -> 1f
        }

    // Apply text spacing settings (WCAG 1.4.12)
    val letterSpacing = settings.letterSpacingMultiplier.em
    val lineHeightMultiplier = settings.lineSpacingMultiplier

    val fontFamily = if (settings.useDyslexiaFont) OpenDyslexicFontFamily else FontFamily.Default
    val base = baseTypography(fontFamily)

    val typography =
        if (scale == 1f) {
            base
        } else {
            base.scale(scale)
        }

    // Apply letter spacing and line height to all text styles
    return typography.applySpacing(letterSpacing, lineHeightMultiplier)
}

private fun Typography.scale(scale: Float): Typography {
    fun TextStyle.scale() =
        copy(
            fontSize = fontSize.scale(scale),
            lineHeight = lineHeight.scale(scale),
        )
    return Typography(
        displayLarge = displayLarge.scale(),
        displayMedium = displayMedium.scale(),
        displaySmall = displaySmall.scale(),
        headlineLarge = headlineLarge.scale(),
        headlineMedium = headlineMedium.scale(),
        headlineSmall = headlineSmall.scale(),
        titleLarge = titleLarge.scale(),
        titleMedium = titleMedium.scale(),
        titleSmall = titleSmall.scale(),
        bodyLarge = bodyLarge.scale(),
        bodyMedium = bodyMedium.scale(),
        bodySmall = bodySmall.scale(),
        labelLarge = labelLarge.scale(),
        labelMedium = labelMedium.scale(),
        labelSmall = labelSmall.scale(),
    )
}

/**
 * Applies WCAG 1.4.12 text spacing settings to all text styles.
 * - Letter spacing (AAA requires 0.12em)
 * - Line height multiplier (AAA requires 1.5x)
 */
private fun Typography.applySpacing(
    letterSpacing: TextUnit,
    lineHeightMultiplier: Float,
): Typography {
    fun TextStyle.applySpacing() =
        copy(
            letterSpacing = letterSpacing,
            lineHeight =
                if (lineHeight.isUnspecified) {
                    lineHeight
                } else {
                    lineHeight.value.sp * lineHeightMultiplier
                },
        )

    return Typography(
        displayLarge = displayLarge.applySpacing(),
        displayMedium = displayMedium.applySpacing(),
        displaySmall = displaySmall.applySpacing(),
        headlineLarge = headlineLarge.applySpacing(),
        headlineMedium = headlineMedium.applySpacing(),
        headlineSmall = headlineSmall.applySpacing(),
        titleLarge = titleLarge.applySpacing(),
        titleMedium = titleMedium.applySpacing(),
        titleSmall = titleSmall.applySpacing(),
        bodyLarge = bodyLarge.applySpacing(),
        bodyMedium = bodyMedium.applySpacing(),
        bodySmall = bodySmall.applySpacing(),
        labelLarge = labelLarge.applySpacing(),
        labelMedium = labelMedium.applySpacing(),
        labelSmall = labelSmall.applySpacing(),
    )
}

private fun TextUnit.scale(factor: Float): TextUnit {
    return if (this.isUnspecified) this else (value * factor).sp
}
