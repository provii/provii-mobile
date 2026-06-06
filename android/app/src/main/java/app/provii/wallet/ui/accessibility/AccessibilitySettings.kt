// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.content.Context
import androidx.compose.runtime.Immutable

/**
 * Data model for all user-configurable accessibility preferences on Android. Covers vision,
 * typography, motor interaction, cognitive support, sound feedback, and alternative input
 * settings. Each field corresponds to a WCAG 2.2 criterion where applicable. Supporting
 * enums for colour blind modes, contrast levels, text width, timeout behaviour, and
 * reading level are also declared here.
 */

/**
 * Mirrors the rich accessibility configuration provided by the iOS app.
 * Settings are persisted and surfaced through [WalletAccessibilityManager].
 */
@Immutable
data class AccessibilitySettings(
    // Vision
    val contrastLevel: ContrastLevel = ContrastLevel.STANDARD,
    val useHighContrast: Boolean = false, // Legacy - migrated to contrastLevel
    val useExtraLargeText: Boolean = false,
    val reduceTransparency: Boolean = false,
    val colorBlindMode: ColorBlindMode = ColorBlindMode.NONE,
    // WCAG 2.2 AAA: Advanced Typography (1.4.8)
    val lineSpacingMultiplier: Float = 1.0f, // Range: 1.0 - 2.0 (AAA requires 1.5x)
    val paragraphSpacingMultiplier: Float = 1.0f, // Range: 1.0 - 3.0 (AAA requires 2x)
    val letterSpacingMultiplier: Float = 0.0f, // Range: 0.0 - 0.2 (AAA requires 0.12em)
    val textWidth: TextWidth = TextWidth.FULL,
    // Motor & interaction
    val increaseTouchTargets: Boolean = false,
    val reduceMotion: Boolean = false,
    // WCAG 2.2 AAA: 2.2.3 No Timing (default to NONE for AAA compliance, matching iOS)
    val timeoutBehavior: TimeoutBehavior = TimeoutBehavior.NONE,
    val simplifiedGestures: Boolean = false,
    val hapticFeedback: Boolean = true,
    // Sound Feedback
    val soundEnabled: Boolean = true,
    val soundPreset: String = "provii", // Store as String for DataStore
    val soundVolume: Int = 100, // 0-100
    // Cognitive support
    val simplifiedUI: Boolean = false,
    val showStepNumbers: Boolean = true,
    val verboseDescriptions: Boolean = false,
    val confirmBeforeActions: Boolean = false,
    // WCAG 2.2 AAA: 3.2.5 Change on Request
    val disableAutoContextChanges: Boolean = false,
    // WCAG 2.2 AAA: 3.1.5 Reading Level
    val readingLevel: ReadingLevel = ReadingLevel.STANDARD,
    // WCAG 2.2 AAA: Dyslexia friendly typography (matching iOS useDyslexiaFont).
    // Applied via typographyFor() in ui/theme/Type.kt using res/font/opendyslexic_*.ttf.
    val useDyslexiaFont: Boolean = false,
    // Alternative input
    val enableManualCodeEntry: Boolean = false,
    val enableVoiceInput: Boolean = false,
    // Onboarding flags
    val hasCompletedAccessibilityOnboarding: Boolean = false,
    val hasAcknowledgedTalkBack: Boolean = false,
) {
    /** Helper to get typed SoundPreset from stored string */
    val verificationSoundPreset: app.provii.wallet.audio.SoundPreset
        get() = app.provii.wallet.audio.SoundPreset.fromName(soundPreset)

    companion object {
        val Default = AccessibilitySettings()
    }
}

/**
 * Supported colour blindness profiles. We map these to alternate palette tokens
 * when building the Material colour scheme.
 */
enum class ColorBlindMode {
    NONE,
    PROTANOPIA,
    DEUTERANOPIA,
    TRITANOPIA,
    MONOCHROME,
}

/**
 * Preset accessibility profiles surfaced in the settings screen to match iOS.
 */
enum class AccessibilityProfile {
    VISION_IMPAIRED,
    MOTOR_IMPAIRED,
    COGNITIVE,
    ELDERLY,
    DEFAULT,
}

/**
 * WCAG 2.2 AAA: Contrast levels (1.4.6)
 */
enum class ContrastLevel {
    STANDARD, // Current default
    HIGH, // AA - 4.5:1 contrast
    MAXIMUM, // AAA - 7:1 contrast
    ;

    fun getDisplayName(context: Context): String =
        when (this) {
            STANDARD -> context.getString(app.provii.wallet.R.string.contrast_level_standard)
            HIGH -> context.getString(app.provii.wallet.R.string.contrast_level_high)
            MAXIMUM -> context.getString(app.provii.wallet.R.string.contrast_level_maximum)
        }

    val isAAA: Boolean
        get() = this == MAXIMUM
}

/**
 * WCAG 2.2 AAA: Text width options (1.4.8)
 */
enum class TextWidth {
    FULL,
    COMFORTABLE, // 80 characters
    NARROW, // 60 characters
    ;

    fun getDisplayName(context: Context): String =
        when (this) {
            FULL -> context.getString(app.provii.wallet.R.string.text_width_full)
            COMFORTABLE -> context.getString(app.provii.wallet.R.string.text_width_comfortable)
            NARROW -> context.getString(app.provii.wallet.R.string.text_width_narrow)
        }
}

/**
 * WCAG 2.2 AAA: Timeout behaviour (2.2.3 No Timing)
 */
enum class TimeoutBehavior {
    NONE, // AAA requirement - no timeouts
    STANDARD, // Default 30 seconds
    EXTENDED, // 60 seconds
    ;

    fun getDisplayName(context: Context): String =
        when (this) {
            NONE -> context.getString(app.provii.wallet.R.string.timeout_behavior_none)
            STANDARD -> context.getString(app.provii.wallet.R.string.timeout_behavior_standard)
            EXTENDED -> context.getString(app.provii.wallet.R.string.timeout_behavior_extended)
        }

    val isAAA: Boolean
        get() = this == NONE
}

/**
 * WCAG 2.2 AAA: Reading level (3.1.5)
 */
enum class ReadingLevel {
    STANDARD,
    SIMPLIFIED, // Grade 7-9 level
    ;

    fun getDisplayName(context: Context): String =
        when (this) {
            STANDARD -> context.getString(app.provii.wallet.R.string.reading_level_standard)
            SIMPLIFIED -> context.getString(app.provii.wallet.R.string.reading_level_simplified)
        }

    fun getDescription(context: Context): String =
        when (this) {
            STANDARD -> context.getString(app.provii.wallet.R.string.reading_level_standard_description)
            SIMPLIFIED -> context.getString(app.provii.wallet.R.string.reading_level_simplified_description)
        }

    val isAAA: Boolean
        get() = this == SIMPLIFIED
}
