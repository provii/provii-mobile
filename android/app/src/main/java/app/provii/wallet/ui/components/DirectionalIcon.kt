// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.draw.scale

/**
 * RTL-aware icon composable and helper utilities for directional mirroring. Automatically
 * flips directional icons (arrows, chevrons, navigation indicators) when the layout
 * direction is right-to-left. Prefer [Icons.AutoMirrored] variants where available;
 * use [DirectionalIcon] for custom vector assets that lack built-in mirroring support.
 */

/**
 * DirectionalIcon - A composable that automatically mirrors icons for RTL layouts.
 *
 * This component handles RTL (Right-to-Left) mirroring for directional icons.
 * It should be used for icons that indicate direction or movement, such as
 * arrows, chevrons, and navigation indicators.
 *
 * Note: For Material Icons, prefer using Icons.AutoMirrored.* variants when available,
 * as they are optimised for RTL support. Use this component for custom icons or when
 * AutoMirrored variants are not available.
 *
 * Supported RTL languages in this app: Arabic (ar), Dari (fa-AF), Farsi/Persian (fa),
 * Hebrew (he), Kurdish (ku), Pashto (ps), Urdu (ur).
 *
 * @param imageVector The icon to display
 * @param contentDescription Accessibility description for the icon
 * @param modifier Modifier for the icon
 * @param tint Colour tint for the icon (defaults to LocalContentColor)
 * @param mirrorInRtl Whether to mirror the icon in RTL layouts (default: true)
 */
@Composable
fun DirectionalIcon(
    imageVector: ImageVector,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = LocalContentColor.current,
    mirrorInRtl: Boolean = true,
) {
    val layoutDirection = LocalLayoutDirection.current
    val shouldMirror = mirrorInRtl && layoutDirection == LayoutDirection.Rtl

    Icon(
        imageVector = imageVector,
        contentDescription = contentDescription,
        modifier =
            modifier.then(
                if (shouldMirror) {
                    Modifier.scale(scaleX = -1f, scaleY = 1f)
                } else {
                    Modifier
                },
            ),
        tint = tint,
    )
}

/**
 * Helper function to check if the current layout direction is RTL
 */
@Composable
fun isRtlLayout(): Boolean {
    return LocalLayoutDirection.current == LayoutDirection.Rtl
}

/**
 * Modifier extension to conditionally apply transformations based on layout direction
 *
 * Example usage:
 * ```
 * Box(
 *     modifier = Modifier
 *         .mirrorInRtl()
 *         .padding(start = 16.dp)
 * )
 * ```
 */
@Composable
fun Modifier.mirrorInRtl(): Modifier {
    val shouldMirror = LocalLayoutDirection.current == LayoutDirection.Rtl
    return if (shouldMirror) {
        this.then(Modifier.scale(scaleX = -1f, scaleY = 1f))
    } else {
        this
    }
}
