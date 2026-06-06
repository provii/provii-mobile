// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Composition locals and immutable UI state for the accessibility subsystem. Provides
 * [AccessibilityUiState] that encapsulates touch target sizing, animation scaling, and
 * layout dimensions derived from the current [AccessibilitySettings]. Also exposes
 * [LocalAccessibilityManager] and [LocalAccessibilityUiState] for downstream composables.
 */

/**
 * Snapshot of accessibility state exposed to Compose.
 */
@Immutable
data class AccessibilityUiState(
    val settings: AccessibilitySettings = AccessibilitySettings.Default,
    val isTalkBackEnabled: Boolean = false,
    val prefersReducedMotion: Boolean = false,
) {
    /**
     * Touch target tiers matching iOS: 44pt (standard), 52pt (large), 60pt (AAA).
     * Android maps to: 48dp (platform minimum), 52dp (large), 60dp (AAA).
     */
    val minTouchTarget: Dp =
        when {
            settings.increaseTouchTargets && settings.useExtraLargeText -> 60.dp // AAA tier
            settings.increaseTouchTargets -> 52.dp // Large tier
            else -> 48.dp // Standard tier (Android minimum)
        }
    val cardCornerRadius: Dp = if (settings.increaseTouchTargets) 16.dp else 12.dp
    val buttonHorizontalPadding: Dp = if (settings.increaseTouchTargets) 32.dp else 20.dp
    val buttonVerticalPadding: Dp = if (settings.increaseTouchTargets) 18.dp else 12.dp

    fun animationScale(baseDurationMillis: Int): Int =
        when {
            settings.reduceMotion || prefersReducedMotion -> 0
            settings.timeoutBehavior == TimeoutBehavior.EXTENDED -> (baseDurationMillis * 1.5).toInt()
            else -> baseDurationMillis
        }
}

val LocalAccessibilityManager: ProvidableCompositionLocal<WalletAccessibilityManager> =
    staticCompositionLocalOf { error("WalletAccessibilityManager not provided") }

val LocalAccessibilityUiState = compositionLocalOf { AccessibilityUiState() }
