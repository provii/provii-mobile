// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.theme

import androidx.compose.ui.graphics.Color
import app.provii.wallet.ui.accessibility.ColorBlindMode

/**
 * Colour blindness simulation filter using Brettel, Vienot and Mollon (1997) matrices.
 * Matches the iOS ColorBlindnessFilter.swift implementation with identical matrix values.
 *
 * WCAG 2.2 AAA: Provides colour transformation for users with various types of
 * colour vision deficiency. The theme already selects distinct palettes per
 * ColorBlindMode in Theme.kt; this filter supplements that by offering a
 * general-purpose simulation function that can be applied to arbitrary colours
 * outside the Material colour scheme (custom illustrations, dynamic content, etc.).
 *
 * Usage:
 *   val filtered = ColorBlindnessFilter.applyFilter(myColor, mode)
 *
 * To wire into the theme globally, call applyToScheme() on the resolved ColorScheme
 * inside ProviiWalletTheme before passing it to MaterialTheme. The current Theme.kt
 * already handles colour blind mode via hand-picked palette tokens, so this filter
 * is provided as a complementary tool for runtime simulation rather than replacing
 * the curated palettes.
 */
object ColorBlindnessFilter {
    /**
     * Apply a colour vision deficiency simulation to a single [Color].
     *
     * @param color The source colour to transform.
     * @param mode  The colour blindness type to simulate.
     * @return The transformed colour, clamped to valid component ranges.
     */
    fun applyFilter(
        color: Color,
        mode: ColorBlindMode,
    ): Color {
        if (mode == ColorBlindMode.NONE) return color

        val r = color.red
        val g = color.green
        val b = color.blue
        val a = color.alpha

        val (newR, newG, newB) =
            when (mode) {
                ColorBlindMode.PROTANOPIA -> {
                    // Brettel 1997 protanopia simulation matrix
                    Triple(
                        0.56700f * r + 0.43300f * g + 0.00000f * b,
                        0.55833f * r + 0.44167f * g + 0.00000f * b,
                        0.00000f * r + 0.24167f * g + 0.75833f * b,
                    )
                }
                ColorBlindMode.DEUTERANOPIA -> {
                    // Brettel 1997 deuteranopia simulation matrix
                    Triple(
                        0.625f * r + 0.375f * g + 0.000f * b,
                        0.700f * r + 0.300f * g + 0.000f * b,
                        0.000f * r + 0.300f * g + 0.700f * b,
                    )
                }
                ColorBlindMode.TRITANOPIA -> {
                    // Brettel 1997 tritanopia simulation matrix
                    Triple(
                        0.95000f * r + 0.05000f * g + 0.00000f * b,
                        0.00000f * r + 0.43333f * g + 0.56667f * b,
                        0.00000f * r + 0.47500f * g + 0.52500f * b,
                    )
                }
                ColorBlindMode.MONOCHROME -> {
                    // ITU-R BT.709 luminosity coefficients (matches iOS implementation)
                    val lum = 0.2126f * r + 0.7152f * g + 0.0722f * b
                    Triple(lum, lum, lum)
                }
                ColorBlindMode.NONE -> Triple(r, g, b)
            }

        return Color(
            red = newR.coerceIn(0f, 1f),
            green = newG.coerceIn(0f, 1f),
            blue = newB.coerceIn(0f, 1f),
            alpha = a,
        )
    }

    /**
     * Convenience extension for applying the filter inline on a [Color].
     */
    fun Color.filtered(mode: ColorBlindMode): Color = applyFilter(this, mode)
}
