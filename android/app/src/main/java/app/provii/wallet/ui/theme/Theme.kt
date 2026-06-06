// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.provii.wallet.ui.accessibility.AccessibilitySettings
import app.provii.wallet.ui.accessibility.AccessibilityUiState
import app.provii.wallet.ui.accessibility.ColorBlindMode
import app.provii.wallet.ui.accessibility.ContrastLevel
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.WalletAccessibilityManager

/**
 * Material3 theme configuration for the Provii Wallet Android application. Resolves
 * colour schemes, typography, and status bar appearance based on the user's accessibility
 * settings. Supports standard, high contrast, and maximum contrast (WCAG AAA 7:1) modes
 * with colour blindness palette overrides for protanopia, deuteranopia, tritanopia, and
 * monochrome vision.
 */

@Composable
fun AccessibleProviiWalletTheme(
    manager: WalletAccessibilityManager,
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val settings by manager.settings.collectAsStateWithLifecycle(initialValue = AccessibilitySettings.Default)
    val talkBackEnabled by manager.isTalkBackEnabled.collectAsStateWithLifecycle(initialValue = false)
    val prefersReducedMotion by manager.prefersReducedMotion.collectAsStateWithLifecycle(initialValue = false)

    val mergedSettings =
        remember(settings, prefersReducedMotion) {
            if (prefersReducedMotion && !settings.reduceMotion) {
                settings.copy(reduceMotion = true)
            } else {
                settings
            }
        }

    val uiState =
        remember(mergedSettings, talkBackEnabled, prefersReducedMotion) {
            AccessibilityUiState(
                settings = mergedSettings,
                isTalkBackEnabled = talkBackEnabled,
                prefersReducedMotion = prefersReducedMotion,
            )
        }

    androidx.compose.runtime.CompositionLocalProvider(
        LocalAccessibilityManager provides manager,
        LocalAccessibilityUiState provides uiState,
    ) {
        ProviiWalletTheme(
            darkTheme = darkTheme,
            uiState = uiState,
            content = content,
        )
    }
}

@Composable
fun ProviiWalletTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    uiState: AccessibilityUiState = LocalAccessibilityUiState.current,
    content: @Composable () -> Unit,
) {
    val colorScheme =
        remember(darkTheme, uiState.settings) {
            accessibleColorScheme(darkTheme, uiState.settings)
        }
    val typography = remember(uiState.settings) { typographyFor(uiState.settings) }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            val insetsController = WindowCompat.getInsetsController(window, view)

            // statusBarColor is deprecated in API 35+ (edge-to-edge is the default)
            // Keep for older devices for consistent appearance
            if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                window.statusBarColor = colorScheme.background.toArgb()
            }
            insetsController.isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = typography,
        content = content,
    )
}

private fun accessibleColorScheme(
    darkTheme: Boolean,
    settings: AccessibilitySettings,
): ColorScheme {
    // WCAG 2.2 AAA: Support three-level contrast system
    return when (settings.contrastLevel) {
        ContrastLevel.MAXIMUM -> maximumContrastColorScheme(darkTheme, settings.colorBlindMode)
        ContrastLevel.HIGH -> highContrastColorScheme(darkTheme)
        ContrastLevel.STANDARD -> standardColorScheme(darkTheme, settings)
    }
}

private fun maximumContrastColorScheme(
    darkTheme: Boolean,
    colorBlindMode: ColorBlindMode,
): ColorScheme {
    // WCAG AAA: 7:1 contrast ratio minimum
    val primary =
        if (darkTheme) {
            PrimaryAAADark
        } else {
            when (colorBlindMode) {
                ColorBlindMode.NONE -> PrimaryAAA
                ColorBlindMode.PROTANOPIA, ColorBlindMode.DEUTERANOPIA -> PrimaryAAA
                ColorBlindMode.TRITANOPIA -> WarningAAA
                ColorBlindMode.MONOCHROME -> TextAAA
            }
        }

    val error = if (darkTheme) ErrorAAADark else ErrorAAA
    val background = if (darkTheme) BackgroundAAADark else BackgroundAAA
    val surface = if (darkTheme) SurfaceAAADark else SurfaceAAA
    val onBackground = if (darkTheme) TextAAADark else TextAAA
    val onSurface = if (darkTheme) TextAAADark else TextAAA

    return if (darkTheme) {
        darkColorScheme(
            primary = primary,
            onPrimary = BackgroundAAADark,
            secondary = SecondaryAAADark,
            onSecondary = BackgroundAAADark,
            error = error,
            onError = BackgroundAAADark,
            background = background,
            onBackground = onBackground,
            surface = surface,
            onSurface = onSurface,
        )
    } else {
        lightColorScheme(
            primary = primary,
            onPrimary = BackgroundAAA,
            secondary = SecondaryAAA,
            onSecondary = BackgroundAAA,
            error = error,
            onError = BackgroundAAA,
            background = background,
            onBackground = onBackground,
            surface = surface,
            onSurface = onSurface,
        )
    }
}

private fun standardColorScheme(
    darkTheme: Boolean,
    settings: AccessibilitySettings,
): ColorScheme {
    val primary =
        when (settings.colorBlindMode) {
            ColorBlindMode.NONE -> if (darkTheme) Color(0xFF42A5F5) else Color(0xFF1976D2)
            ColorBlindMode.PROTANOPIA, ColorBlindMode.DEUTERANOPIA -> if (darkTheme) Color(0xFF5DAEFF) else Color(0xFF0F6DC5)
            ColorBlindMode.TRITANOPIA -> if (darkTheme) Color(0xFFFFA04D) else Color(0xFFCC6600)
            ColorBlindMode.MONOCHROME -> if (darkTheme) Color(0xFFE0E0E0) else Color(0xFF1A1A1A) // WCAG AA: 12:1+ contrast
        }

    val secondary =
        when (settings.colorBlindMode) {
            ColorBlindMode.NONE -> if (darkTheme) Color(0xFF757575) else Color(0xFF424242)
            ColorBlindMode.PROTANOPIA, ColorBlindMode.DEUTERANOPIA -> if (darkTheme) Color(0xFF9AA6FF) else Color(0xFF4154B5)
            ColorBlindMode.TRITANOPIA -> if (darkTheme) Color(0xFFFFB347) else Color(0xFFC57B00)
            ColorBlindMode.MONOCHROME -> if (darkTheme) Color(0xFFBBBBBB) else Color(0xFF3D3D3D) // WCAG AA: 7:1+ contrast
        }

    val error =
        when (settings.colorBlindMode) {
            ColorBlindMode.NONE -> if (darkTheme) Color(0xFFEF5350) else Color(0xFFD32F2F)
            ColorBlindMode.PROTANOPIA -> if (darkTheme) Color(0xFFFFA24D) else Color(0xFFFF6A1A)
            ColorBlindMode.DEUTERANOPIA -> if (darkTheme) Color(0xFFFFB366) else Color(0xFFFF861F)
            ColorBlindMode.TRITANOPIA -> if (darkTheme) Color(0xFFEA4E4E) else Color(0xFFC62828)
            ColorBlindMode.MONOCHROME -> if (darkTheme) Color(0xFFB3B3B3) else Color(0xFF4D4D4D)
        }

    val background =
        when {
            settings.reduceTransparency && !darkTheme -> Color(0xFFF3F3F3)
            settings.reduceTransparency && darkTheme -> Color(0xFF111111)
            else -> if (darkTheme) Color(0xFF121212) else Color(0xFFFAFAFA)
        }

    val surface =
        when {
            settings.reduceTransparency && !darkTheme -> Color.White
            settings.reduceTransparency && darkTheme -> Color(0xFF1E1E1E)
            else -> if (darkTheme) Color(0xFF1A1C28) else Color.White
        }

    val onSurface = if (darkTheme) Color(0xFFE0E0E0) else Color(0xFF212121)
    val onPrimary = if (darkTheme && settings.colorBlindMode == ColorBlindMode.MONOCHROME) Color.Black else Color.White
    val onSecondary = if (darkTheme && settings.colorBlindMode == ColorBlindMode.MONOCHROME) Color.Black else Color.White

    val primaryContainer = if (darkTheme) darkenColor(primary, 0.6f) else lightenColor(primary, 0.82f)
    val onPrimaryContainer = if (darkTheme) Color.White else primary
    val secondaryContainer = if (darkTheme) darkenColor(secondary, 0.6f) else lightenColor(secondary, 0.82f)
    val onSecondaryContainer = if (darkTheme) Color.White else secondary

    return if (darkTheme) {
        darkColorScheme(
            primary = primary,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = secondary,
            onSecondary = onSecondary,
            secondaryContainer = secondaryContainer,
            onSecondaryContainer = onSecondaryContainer,
            error = error,
            surface = surface,
            onSurface = onSurface,
            background = background,
            onBackground = onSurface,
        )
    } else {
        lightColorScheme(
            primary = primary,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = secondary,
            onSecondary = onSecondary,
            secondaryContainer = secondaryContainer,
            onSecondaryContainer = onSecondaryContainer,
            error = error,
            surface = surface,
            onSurface = onSurface,
            background = background,
            onBackground = onSurface,
        )
    }
}

private fun highContrastColorScheme(darkTheme: Boolean): ColorScheme {
    return if (darkTheme) {
        darkColorScheme(
            primary = Color.White,
            onPrimary = Color.Black,
            secondary = Color.White,
            onSecondary = Color.Black,
            error = Color.White,
            onError = Color.Black,
            background = Color.Black,
            onBackground = Color.White,
            surface = Color.Black,
            onSurface = Color.White,
        )
    } else {
        lightColorScheme(
            primary = Color.Black,
            onPrimary = Color.White,
            secondary = Color.Black,
            onSecondary = Color.White,
            error = Color.Black,
            onError = Color.White,
            background = Color.White,
            onBackground = Color.Black,
            surface = Color.White,
            onSurface = Color.Black,
        )
    }
}

private fun lightenColor(
    color: Color,
    factor: Float,
): Color {
    val clamped = factor.coerceIn(0f, 1f)
    val red = color.red + (1f - color.red) * clamped
    val green = color.green + (1f - color.green) * clamped
    val blue = color.blue + (1f - color.blue) * clamped
    return Color(red = red, green = green, blue = blue, alpha = 1f)
}

private fun darkenColor(
    color: Color,
    factor: Float,
): Color {
    val clamped = factor.coerceIn(0f, 1f)
    val red = (color.red * (1f - clamped)).coerceIn(0f, 1f)
    val green = (color.green * (1f - clamped)).coerceIn(0f, 1f)
    val blue = (color.blue * (1f - clamped)).coerceIn(0f, 1f)
    return Color(red = red, green = green, blue = blue, alpha = 1f)
}
