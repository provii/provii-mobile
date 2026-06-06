// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.content.Context
import androidx.annotation.StringRes
import app.provii.wallet.R

/**
 * Context-sensitive help system satisfying WCAG 2.2 AAA criterion 3.3.5. Enumerates 27
 * help topics across six categories (vision, typography, interaction, cognitive,
 * alternative input, features). Each topic references localised string resources for
 * its title and body text, and declares related topics for cross-navigation.
 */

enum class HelpCategory {
    VISION,
    TYPOGRAPHY,
    INTERACTION,
    COGNITIVE,
    ALTERNATIVE_INPUT,
    FEATURES,
}

enum class HelpTopic(
    @StringRes val titleResId: Int,
    val category: HelpCategory,
    @StringRes val helpTextResId: Int,
) {
    // Vision (7 topics)
    CONTRAST_LEVELS(
        titleResId = R.string.help_topic_contrast_levels_title,
        category = HelpCategory.VISION,
        helpTextResId = R.string.help_topic_contrast_levels_text,
    ),

    EXTRA_LARGE_TEXT(
        titleResId = R.string.help_topic_extra_large_text_title,
        category = HelpCategory.VISION,
        helpTextResId = R.string.help_topic_extra_large_text_text,
    ),

    REDUCE_TRANSPARENCY(
        titleResId = R.string.help_topic_reduce_transparency_title,
        category = HelpCategory.VISION,
        helpTextResId = R.string.help_topic_reduce_transparency_text,
    ),

    COLOR_BLIND_MODES(
        titleResId = R.string.help_topic_color_blind_modes_title,
        category = HelpCategory.VISION,
        helpTextResId = R.string.help_topic_color_blind_modes_text,
    ),

    // Typography (4 topics)
    LINE_SPACING(
        titleResId = R.string.help_topic_line_spacing_title,
        category = HelpCategory.TYPOGRAPHY,
        helpTextResId = R.string.help_topic_line_spacing_text,
    ),

    PARAGRAPH_SPACING(
        titleResId = R.string.help_topic_paragraph_spacing_title,
        category = HelpCategory.TYPOGRAPHY,
        helpTextResId = R.string.help_topic_paragraph_spacing_text,
    ),

    LETTER_SPACING(
        titleResId = R.string.help_topic_letter_spacing_title,
        category = HelpCategory.TYPOGRAPHY,
        helpTextResId = R.string.help_topic_letter_spacing_text,
    ),

    TEXT_WIDTH(
        titleResId = R.string.help_topic_text_width_title,
        category = HelpCategory.TYPOGRAPHY,
        helpTextResId = R.string.help_topic_text_width_text,
    ),

    // Interaction (6 topics)
    TOUCH_TARGETS(
        titleResId = R.string.help_topic_touch_targets_title,
        category = HelpCategory.INTERACTION,
        helpTextResId = R.string.help_topic_touch_targets_text,
    ),

    REDUCE_MOTION(
        titleResId = R.string.help_topic_reduce_motion_title,
        category = HelpCategory.INTERACTION,
        helpTextResId = R.string.help_topic_reduce_motion_text,
    ),

    TIMEOUT_BEHAVIOR(
        titleResId = R.string.help_topic_timeout_behavior_title,
        category = HelpCategory.INTERACTION,
        helpTextResId = R.string.help_topic_timeout_behavior_text,
    ),

    SIMPLIFIED_GESTURES(
        titleResId = R.string.help_topic_simplified_gestures_title,
        category = HelpCategory.INTERACTION,
        helpTextResId = R.string.help_topic_simplified_gestures_text,
    ),

    HAPTIC_FEEDBACK(
        titleResId = R.string.help_topic_haptic_feedback_title,
        category = HelpCategory.INTERACTION,
        helpTextResId = R.string.help_topic_haptic_feedback_text,
    ),

    DATA_PRESERVATION(
        titleResId = R.string.help_topic_data_preservation_title,
        category = HelpCategory.INTERACTION,
        helpTextResId = R.string.help_topic_data_preservation_text,
    ),

    // Cognitive (6 topics)
    SIMPLIFIED_UI(
        titleResId = R.string.help_topic_simplified_ui_title,
        category = HelpCategory.COGNITIVE,
        helpTextResId = R.string.help_topic_simplified_ui_text,
    ),

    STEP_INDICATORS(
        titleResId = R.string.help_topic_step_indicators_title,
        category = HelpCategory.COGNITIVE,
        helpTextResId = R.string.help_topic_step_indicators_text,
    ),

    VERBOSE_DESCRIPTIONS(
        titleResId = R.string.help_topic_verbose_descriptions_title,
        category = HelpCategory.COGNITIVE,
        helpTextResId = R.string.help_topic_verbose_descriptions_text,
    ),

    CONFIRM_ACTIONS(
        titleResId = R.string.help_topic_confirm_actions_title,
        category = HelpCategory.COGNITIVE,
        helpTextResId = R.string.help_topic_confirm_actions_text,
    ),

    READING_LEVEL(
        titleResId = R.string.help_topic_reading_level_title,
        category = HelpCategory.COGNITIVE,
        helpTextResId = R.string.help_topic_reading_level_text,
    ),

    HELP_SYSTEM(
        titleResId = R.string.help_topic_help_system_title,
        category = HelpCategory.COGNITIVE,
        helpTextResId = R.string.help_topic_help_system_text,
    ),

    // Alternative Input (3 topics)
    MANUAL_CODE_ENTRY(
        titleResId = R.string.help_topic_manual_code_entry_title,
        category = HelpCategory.ALTERNATIVE_INPUT,
        helpTextResId = R.string.help_topic_manual_code_entry_text,
    ),

    VOICE_INPUT(
        titleResId = R.string.help_topic_voice_input_title,
        category = HelpCategory.ALTERNATIVE_INPUT,
        helpTextResId = R.string.help_topic_voice_input_text,
    ),

    SCREEN_READER(
        titleResId = R.string.help_topic_screen_reader_title,
        category = HelpCategory.ALTERNATIVE_INPUT,
        helpTextResId = R.string.help_topic_screen_reader_text,
    ),

    // Features (1 topic)
    ACCESSIBILITY_PROFILES(
        titleResId = R.string.help_topic_accessibility_profiles_title,
        category = HelpCategory.FEATURES,
        helpTextResId = R.string.help_topic_accessibility_profiles_text,
    ),
    ;

    /**
     * Get localized title string
     */
    fun getTitle(context: Context): String = context.getString(titleResId)

    /**
     * Get localized help text string
     */
    fun getHelpText(context: Context): String = context.getString(helpTextResId)

    companion object {
        fun allTopics() = values().toList()

        fun topicsByCategory(category: HelpCategory) =
            values().filter { it.category == category }

        fun search(
            query: String,
            context: Context,
        ): List<HelpTopic> {
            val lowercaseQuery = query.lowercase()
            return values().filter {
                it.getTitle(context).lowercase().contains(lowercaseQuery) ||
                    it.getHelpText(context).lowercase().contains(lowercaseQuery)
            }
        }

        // Get related topics for a given topic
        fun getRelatedTopics(topic: HelpTopic): List<HelpTopic> {
            return topicRelationships[topic] ?: emptyList()
        }

        // Map of topic relationships - topics grouped logically
        private val topicRelationships =
            mapOf(
                // Vision topics
                CONTRAST_LEVELS to listOf(COLOR_BLIND_MODES, EXTRA_LARGE_TEXT, REDUCE_TRANSPARENCY, ACCESSIBILITY_PROFILES),
                EXTRA_LARGE_TEXT to listOf(CONTRAST_LEVELS, LINE_SPACING, PARAGRAPH_SPACING, TEXT_WIDTH),
                REDUCE_TRANSPARENCY to listOf(CONTRAST_LEVELS, SIMPLIFIED_UI, REDUCE_MOTION, COLOR_BLIND_MODES),
                COLOR_BLIND_MODES to listOf(CONTRAST_LEVELS, SCREEN_READER),
                // Typography topics
                LINE_SPACING to listOf(PARAGRAPH_SPACING, LETTER_SPACING, TEXT_WIDTH, EXTRA_LARGE_TEXT),
                PARAGRAPH_SPACING to listOf(LINE_SPACING, TEXT_WIDTH, READING_LEVEL, LETTER_SPACING),
                LETTER_SPACING to listOf(LINE_SPACING, TEXT_WIDTH, EXTRA_LARGE_TEXT, PARAGRAPH_SPACING),
                TEXT_WIDTH to listOf(LINE_SPACING, PARAGRAPH_SPACING, READING_LEVEL, EXTRA_LARGE_TEXT),
                // Motor/Interaction topics
                TOUCH_TARGETS to listOf(SIMPLIFIED_GESTURES, HAPTIC_FEEDBACK, CONFIRM_ACTIONS, MANUAL_CODE_ENTRY),
                SIMPLIFIED_GESTURES to listOf(TOUCH_TARGETS, MANUAL_CODE_ENTRY, VOICE_INPUT, REDUCE_MOTION),
                HAPTIC_FEEDBACK to listOf(TOUCH_TARGETS, REDUCE_MOTION, TIMEOUT_BEHAVIOR, SIMPLIFIED_GESTURES),
                REDUCE_MOTION to listOf(REDUCE_TRANSPARENCY, SIMPLIFIED_UI, HAPTIC_FEEDBACK, SIMPLIFIED_GESTURES),
                TIMEOUT_BEHAVIOR to listOf(DATA_PRESERVATION, STEP_INDICATORS, CONFIRM_ACTIONS, HAPTIC_FEEDBACK),
                DATA_PRESERVATION to listOf(TIMEOUT_BEHAVIOR, CONFIRM_ACTIONS, STEP_INDICATORS, SIMPLIFIED_UI),
                // Cognitive topics
                SIMPLIFIED_UI to listOf(REDUCE_TRANSPARENCY, REDUCE_MOTION, STEP_INDICATORS, READING_LEVEL),
                STEP_INDICATORS to listOf(SIMPLIFIED_UI, VERBOSE_DESCRIPTIONS, DATA_PRESERVATION, HELP_SYSTEM),
                VERBOSE_DESCRIPTIONS to listOf(READING_LEVEL, HELP_SYSTEM, STEP_INDICATORS, SCREEN_READER),
                CONFIRM_ACTIONS to listOf(TOUCH_TARGETS, DATA_PRESERVATION, SIMPLIFIED_UI, TIMEOUT_BEHAVIOR),
                READING_LEVEL to listOf(VERBOSE_DESCRIPTIONS, TEXT_WIDTH, SIMPLIFIED_UI, PARAGRAPH_SPACING),
                HELP_SYSTEM to listOf(VERBOSE_DESCRIPTIONS, STEP_INDICATORS, SCREEN_READER, ACCESSIBILITY_PROFILES),
                // Alternative Input topics
                MANUAL_CODE_ENTRY to listOf(VOICE_INPUT, SIMPLIFIED_GESTURES, TOUCH_TARGETS, SCREEN_READER),
                VOICE_INPUT to listOf(MANUAL_CODE_ENTRY, SCREEN_READER),
                SCREEN_READER to listOf(VOICE_INPUT, VERBOSE_DESCRIPTIONS, HELP_SYSTEM, TOUCH_TARGETS),
                // Features
                ACCESSIBILITY_PROFILES to listOf(HELP_SYSTEM, SIMPLIFIED_UI, TOUCH_TARGETS, CONTRAST_LEVELS),
            )
    }
}
