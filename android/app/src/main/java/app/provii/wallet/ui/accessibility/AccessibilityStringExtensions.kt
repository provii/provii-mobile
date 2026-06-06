// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import app.provii.wallet.R

/**
 * Composable extension functions that map accessibility enum values to localised display
 * strings. Each extension calls [stringResource] so that returned text honours the
 * current device locale. Covers [AccessibilityProfile], [ColorBlindMode],
 * [ContrastLevel], [TextWidth], [TimeoutBehavior], and [ReadingLevel].
 */

@Composable
fun AccessibilityProfile.toDisplayString(): String {
    return when (this) {
        AccessibilityProfile.VISION_IMPAIRED -> stringResource(R.string.accessibility_profile_vision_impaired)
        AccessibilityProfile.MOTOR_IMPAIRED -> stringResource(R.string.accessibility_profile_motor_impaired)
        AccessibilityProfile.COGNITIVE -> stringResource(R.string.accessibility_profile_cognitive_support)
        AccessibilityProfile.ELDERLY -> stringResource(R.string.accessibility_profile_elderly_support)
        AccessibilityProfile.DEFAULT -> stringResource(R.string.accessibility_profile_default)
    }
}

@Composable
fun ColorBlindMode.toDisplayString(): String {
    return when (this) {
        ColorBlindMode.NONE -> stringResource(R.string.color_blind_mode_none)
        ColorBlindMode.PROTANOPIA -> stringResource(R.string.color_blind_mode_protanopia)
        ColorBlindMode.DEUTERANOPIA -> stringResource(R.string.color_blind_mode_deuteranopia)
        ColorBlindMode.TRITANOPIA -> stringResource(R.string.color_blind_mode_tritanopia)
        ColorBlindMode.MONOCHROME -> stringResource(R.string.color_blind_mode_monochrome)
    }
}

@Composable
fun ContrastLevel.toDisplayString(): String {
    return when (this) {
        ContrastLevel.STANDARD -> stringResource(R.string.contrast_level_standard)
        ContrastLevel.HIGH -> stringResource(R.string.contrast_level_high)
        ContrastLevel.MAXIMUM -> stringResource(R.string.contrast_level_maximum)
    }
}

@Composable
fun TextWidth.toDisplayString(): String {
    return when (this) {
        TextWidth.FULL -> stringResource(R.string.text_width_full)
        TextWidth.COMFORTABLE -> stringResource(R.string.text_width_comfortable)
        TextWidth.NARROW -> stringResource(R.string.text_width_narrow)
    }
}

@Composable
fun TimeoutBehavior.toDisplayString(): String {
    return when (this) {
        TimeoutBehavior.NONE -> stringResource(R.string.timeout_behavior_none)
        TimeoutBehavior.STANDARD -> stringResource(R.string.timeout_behavior_standard)
        TimeoutBehavior.EXTENDED -> stringResource(R.string.timeout_behavior_extended)
    }
}

@Composable
fun ReadingLevel.toDisplayString(): String {
    return when (this) {
        ReadingLevel.STANDARD -> stringResource(R.string.reading_level_standard)
        ReadingLevel.SIMPLIFIED -> stringResource(R.string.reading_level_simplified)
    }
}

@Composable
fun ReadingLevel.toDescriptionString(): String {
    return when (this) {
        ReadingLevel.STANDARD -> stringResource(R.string.reading_level_standard_description)
        ReadingLevel.SIMPLIFIED -> stringResource(R.string.reading_level_simplified_description)
    }
}
