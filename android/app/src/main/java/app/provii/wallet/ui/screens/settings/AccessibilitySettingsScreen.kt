// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.settings

import android.content.Context.VIBRATOR_MANAGER_SERVICE
import android.content.Context.VIBRATOR_SERVICE
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Accessible
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CollectionInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.collectionInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.audio.SoundPreset
import app.provii.wallet.audio.VerificationSoundManager
import androidx.navigation.NavController
import app.provii.wallet.ui.accessibility.AccessibilityProfile
import app.provii.wallet.ui.accessibility.announceForAccessibility
import app.provii.wallet.ui.accessibility.AccessibilitySettings
import app.provii.wallet.ui.accessibility.ColorBlindMode
import app.provii.wallet.ui.accessibility.ContrastLevel
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.TimeoutBehavior
import app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog
import app.provii.wallet.ui.components.accessibility.AccessibleSecondaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleStepBadge
import app.provii.wallet.ui.components.accessibility.AdvancedFeature
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem
import app.provii.wallet.ui.theme.cardFocusIndicator
import app.provii.wallet.ui.theme.circularFocusIndicator

/**
 * Full accessibility settings screen providing granular control over vision, interaction,
 * cognitive, and typography preferences. Covers WCAG 2.2 AA and AAA criteria including
 * contrast levels, colour blind palettes, reduce-motion, touch target sizing, timeout
 * behaviour, font scaling, and text spacing. All setting changes are announced to
 * TalkBack via live-region announcements per WCAG 4.1.3.
 */

// announceForAccessibility is now imported from app.provii.wallet.ui.accessibility.announceForAccessibility

/**
 * WCAG 2.2 AAA: Dedicated Accessibility Settings Screen
 * Separates accessibility configuration from main settings for better organisation.
 *
 * @param navController Navigation controller (null in onboarding mode)
 * @param isOnboarding Whether this is being shown during onboarding flow
 * @param onComplete Callback when onboarding is complete (used in onboarding mode)
 */
@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun AccessibilitySettingsScreen(
    navController: NavController? = null,
    isOnboarding: Boolean = false,
    onComplete: (() -> Unit)? = null,
) {
    val accessibilityManager = LocalAccessibilityManager.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val accessibilitySettings = accessibilityUiState.settings

    var showResetDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (isOnboarding) {
                            stringResource(R.string.onboarding_accessibility_title)
                        } else {
                            stringResource(R.string.accessibility_title)
                        },
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    // Only show back button when not in onboarding mode
                    if (!isOnboarding && navController != null) {
                        IconButton(
                            onClick = { navController.popBackStack() },
                            modifier = Modifier.circularFocusIndicator(),
                        ) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.accessibility_back))
                        }
                    }
                },
            )
        },
        bottomBar = {
            // Show "Continue to Setup" button in onboarding mode
            if (isOnboarding && onComplete != null) {
                androidx.compose.material3.Surface(
                    shadowElevation = 8.dp,
                    tonalElevation = 2.dp,
                ) {
                    Column(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                    ) {
                        androidx.compose.material3.Button(
                            onClick = onComplete,
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .height(56.dp),
                        ) {
                            Text(
                                text = stringResource(R.string.onboarding_continue_to_setup),
                                style = MaterialTheme.typography.labelLarge,
                            )
                        }
                    }
                }
            }
        },
    ) { paddingValues ->
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(horizontal = 16.dp)
                    .semantics {
                        collectionInfo = CollectionInfo(rowCount = -1, columnCount = 1)
                    },
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            item { Spacer(modifier = Modifier.height(4.dp)) }

            // Breadcrumb Navigation (WCAG 2.4.8 AAA) - only in normal mode
            if (!isOnboarding && navController != null) {
                item {
                    Breadcrumb(
                        items =
                            listOf(
                                BreadcrumbItem(stringResource(R.string.breadcrumb_settings)),
                                BreadcrumbItem(stringResource(R.string.breadcrumb_accessibility)),
                            ),
                        onNavigate = { index ->
                            if (index == 0) {
                                navController.popBackStack()
                            }
                        },
                    )
                }
            }

            // Header
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.AccessibilityNew,
                            contentDescription = null, // Decorative - next to heading text
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(32.dp),
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            stringResource(R.string.accessibility_personalize),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.semantics { heading() },
                        )
                    }
                    AccessibleStepBadge(text = stringResource(R.string.accessibility_customize_features))
                }
            }

            // Quick Setup
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(
                            stringResource(R.string.accessibility_quick_setup),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.semantics { heading() },
                        )
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            quickProfiles.forEach { profile ->
                                AssistChip(
                                    onClick = { accessibilityManager.applyQuickSetup(profile.profile) },
                                    label = { Text(stringResource(profile.titleResId)) },
                                    leadingIcon =
                                        profile.icon?.let { icon ->
                                            {
                                                Icon(
                                                    icon,
                                                    contentDescription = null, // Decorative - parent AssistChip has label
                                                    modifier = Modifier.size(AssistChipDefaults.IconSize),
                                                )
                                            }
                                        },
                                    colors =
                                        AssistChipDefaults.assistChipColors(
                                            containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                                        ),
                                )
                            }
                        }
                    }
                }
            }

            // Vision
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        AccessibilitySectionHeader(stringResource(R.string.accessibility_category_vision))

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_extra_large_text),
                            description = stringResource(R.string.accessibility_extra_large_text_description),
                            checked = accessibilitySettings.useExtraLargeText,
                            icon = Icons.Default.FormatSize,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(useExtraLargeText = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_high_contrast),
                            description = stringResource(R.string.accessibility_high_contrast_description),
                            checked = accessibilitySettings.useHighContrast,
                            icon = Icons.Default.BrightnessHigh,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(useHighContrast = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_reduce_transparency),
                            description = stringResource(R.string.accessibility_reduce_transparency_description),
                            checked = accessibilitySettings.reduceTransparency,
                            icon = Icons.Default.BlurOff,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(reduceTransparency = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_dyslexia_font),
                            description = stringResource(R.string.accessibility_dyslexia_font_description),
                            checked = accessibilitySettings.useDyslexiaFont,
                            icon = Icons.Default.TextFields,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(useDyslexiaFont = enabled) }
                            },
                        )

                        ContrastLevelPicker(
                            current = accessibilitySettings.contrastLevel,
                            onSelected = { level ->
                                accessibilityManager.updateSetting { it.copy(contrastLevel = level) }
                            },
                        )

                        ColorBlindModePicker(
                            current = accessibilitySettings.colorBlindMode,
                            onSelected = { mode ->
                                accessibilityManager.updateSetting { it.copy(colorBlindMode = mode) }
                            },
                        )
                    }
                }
            }

            // Interaction
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        AccessibilitySectionHeader(stringResource(R.string.accessibility_category_interaction))

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_larger_touch_targets),
                            description = stringResource(R.string.accessibility_larger_touch_targets_description),
                            checked = accessibilitySettings.increaseTouchTargets,
                            icon = Icons.Default.TouchApp,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(increaseTouchTargets = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_reduce_motion),
                            description = stringResource(R.string.accessibility_reduce_motion_description),
                            checked = accessibilitySettings.reduceMotion,
                            icon = Icons.Default.Speed,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(reduceMotion = enabled) }
                            },
                        )

                        TimeoutBehaviorPicker(
                            current = accessibilitySettings.timeoutBehavior,
                            onSelected = { behavior ->
                                accessibilityManager.updateSetting { it.copy(timeoutBehavior = behavior) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_simplified_gestures),
                            description = stringResource(R.string.accessibility_simplified_gestures_description),
                            checked = accessibilitySettings.simplifiedGestures,
                            icon = Icons.Default.Gesture,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(simplifiedGestures = enabled) }
                            },
                        )

                        HapticFeedbackToggle(
                            checked = accessibilitySettings.hapticFeedback,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(hapticFeedback = enabled) }
                            },
                        )
                    }
                }
            }

            // Verification Feedback
            item {
                VerificationFeedbackSection(
                    accessibilitySettings = accessibilitySettings,
                    onSoundEnabledChange = { enabled ->
                        accessibilityManager.updateSetting { it.copy(soundEnabled = enabled) }
                    },
                    onSoundPresetChange = { preset ->
                        accessibilityManager.updateSetting { it.copy(soundPreset = preset) }
                    },
                    onSoundVolumeChange = { volume ->
                        accessibilityManager.updateSetting { it.copy(soundVolume = volume) }
                    },
                    onHapticFeedbackChange = { enabled ->
                        accessibilityManager.updateSetting { it.copy(hapticFeedback = enabled) }
                    },
                )
            }

            // Cognitive Support
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        AccessibilitySectionHeader(stringResource(R.string.accessibility_category_cognitive))

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_simplified_interface),
                            description = stringResource(R.string.accessibility_simplified_interface_description),
                            checked = accessibilitySettings.simplifiedUI,
                            icon = Icons.Default.Dashboard,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(simplifiedUI = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_show_step_numbers),
                            description = stringResource(R.string.accessibility_show_step_numbers_description),
                            checked = accessibilitySettings.showStepNumbers,
                            icon = Icons.Default.FormatListNumbered,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(showStepNumbers = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_detailed_descriptions),
                            description = stringResource(R.string.accessibility_detailed_descriptions_description),
                            checked = accessibilitySettings.verboseDescriptions,
                            icon = Icons.Default.Description,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(verboseDescriptions = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_confirm_actions),
                            description = stringResource(R.string.accessibility_confirm_actions_description),
                            checked = accessibilitySettings.confirmBeforeActions,
                            icon = Icons.Default.CheckCircle,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(confirmBeforeActions = enabled) }
                            },
                        )
                    }
                }
            }

            // Typography & Text Spacing (WCAG 1.4.12)
            item {
                AdvancedFeature {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.padding(20.dp),
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            AccessibilitySectionHeader(stringResource(R.string.accessibility_typography_section))

                            // Line Spacing Slider
                            TextSpacingSlider(
                                title = stringResource(R.string.accessibility_line_spacing),
                                description = stringResource(R.string.accessibility_line_spacing_description),
                                value = accessibilitySettings.lineSpacingMultiplier,
                                valueRange = 1.0f..2.0f,
                                steps = 9,
                                aaaThreshold = 1.5f,
                                formatValue = { "${String.format("%.1f", it)}x" },
                                icon = Icons.Default.FormatLineSpacing,
                                onValueChange = { value ->
                                    accessibilityManager.updateSetting { it.copy(lineSpacingMultiplier = value) }
                                },
                            )

                            HorizontalDivider()

                            // Paragraph Spacing Slider
                            TextSpacingSlider(
                                title = stringResource(R.string.accessibility_paragraph_spacing),
                                description = stringResource(R.string.accessibility_paragraph_spacing_description),
                                value = accessibilitySettings.paragraphSpacingMultiplier,
                                valueRange = 1.0f..3.0f,
                                steps = 19,
                                aaaThreshold = 2.0f,
                                formatValue = { "${String.format("%.1f", it)}x" },
                                icon = Icons.Default.FormatAlignJustify,
                                onValueChange = { value ->
                                    accessibilityManager.updateSetting { it.copy(paragraphSpacingMultiplier = value) }
                                },
                            )

                            HorizontalDivider()

                            // Letter Spacing Slider
                            TextSpacingSlider(
                                title = stringResource(R.string.accessibility_letter_spacing),
                                description = stringResource(R.string.accessibility_letter_spacing_description),
                                value = accessibilitySettings.letterSpacingMultiplier,
                                valueRange = 0.0f..0.2f,
                                steps = 19,
                                aaaThreshold = 0.12f,
                                formatValue = { "${String.format("%.2f", it)}em" },
                                icon = Icons.Default.TextFields,
                                onValueChange = { value ->
                                    accessibilityManager.updateSetting { it.copy(letterSpacingMultiplier = value) }
                                },
                            )

                            Text(
                                text = stringResource(R.string.accessibility_typography_aaa_note),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 8.dp),
                            )
                        }
                    }
                }
            }

            // Alternative Input
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        AccessibilitySectionHeader(stringResource(R.string.accessibility_category_alternative_input))

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_manual_code_entry),
                            description = stringResource(R.string.accessibility_manual_code_entry_description),
                            checked = accessibilitySettings.enableManualCodeEntry,
                            icon = Icons.Default.Keyboard,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(enableManualCodeEntry = enabled) }
                            },
                        )

                        AccessibilityToggle(
                            title = stringResource(R.string.accessibility_voice_input),
                            description = stringResource(R.string.accessibility_voice_input_description),
                            checked = accessibilitySettings.enableVoiceInput,
                            icon = Icons.Default.Mic,
                            onCheckedChange = { enabled ->
                                accessibilityManager.updateSetting { it.copy(enableVoiceInput = enabled) }
                            },
                        )
                    }
                }
            }

            // Reset Button
            item {
                AccessibleSecondaryButton(
                    text = stringResource(R.string.accessibility_reset),
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        if (accessibilitySettings.confirmBeforeActions) {
                            showResetDialog = true
                        } else {
                            accessibilityManager.reset()
                        }
                    },
                )
            }

            item { Spacer(modifier = Modifier.height(16.dp)) }
        }
    }

    // Reset Confirmation Dialog
    if (showResetDialog) {
        AccessibleAlertDialog(
            onDismissRequest = { showResetDialog = false },
            icon = { Icon(Icons.Default.SettingsBackupRestore, contentDescription = stringResource(R.string.accessibility_reset_icon_description)) },
            title = { Text(stringResource(R.string.accessibility_reset_title)) },
            text = { Text(stringResource(R.string.accessibility_reset_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showResetDialog = false
                    accessibilityManager.reset()
                }) {
                    Text(stringResource(R.string.action_reset))
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }
}

@Composable
private fun AccessibilitySectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.semantics { heading() },
    )
}

@Composable
private fun AccessibilityToggle(
    title: String,
    description: String,
    checked: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    onCheckedChange: (Boolean) -> Unit,
) {
    val context = LocalContext.current
    val enabledAnnouncement = stringResource(R.string.accessibility_toggle_enabled, title)
    val disabledAnnouncement = stringResource(R.string.accessibility_toggle_disabled, title)

    ListItem(
        headlineContent = {
            Text(title, style = MaterialTheme.typography.titleSmall)
        },
        supportingContent = {
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        leadingContent = {
            icon?.let {
                Box(
                    modifier =
                        Modifier
                            .size(44.dp)
                            .background(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                                shape = MaterialTheme.shapes.small,
                            ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(it, contentDescription = null, tint = MaterialTheme.colorScheme.primary) // Decorative - illustrates setting
                }
            }
        },
        trailingContent = {
            Switch(
                checked = checked,
                onCheckedChange = { enabled ->
                    onCheckedChange(enabled)
                    val announcement = if (enabled) enabledAnnouncement else disabledAnnouncement
                    announceForAccessibility(context, announcement)
                },
                modifier = Modifier.semantics { role = Role.Switch },
            )
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    )
}

@Composable
private fun TimeoutBehaviorPicker(
    current: app.provii.wallet.ui.accessibility.TimeoutBehavior,
    onSelected: (app.provii.wallet.ui.accessibility.TimeoutBehavior) -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    var expanded by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(R.string.accessibility_timeout_behavior),
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Card(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .cardFocusIndicator()
                    .semantics { role = Role.Button }
                    .clickable { expanded = true },
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(current.getDisplayName(context), style = MaterialTheme.typography.bodyLarge)
                    if (current.isAAA) {
                        Text(
                            stringResource(R.string.accessibility_timeout_no_automatic),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        Text(
                            when (current) {
                                app.provii.wallet.ui.accessibility.TimeoutBehavior.STANDARD -> stringResource(R.string.accessibility_timeout_auto_advance_30)
                                app.provii.wallet.ui.accessibility.TimeoutBehavior.EXTENDED -> stringResource(R.string.accessibility_timeout_auto_advance_60)
                                else -> ""
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
            }
        }

        androidx.compose.material3.DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            app.provii.wallet.ui.accessibility.TimeoutBehavior.entries.forEach { behavior ->
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(behavior.getDisplayName(context)) },
                    onClick = {
                        expanded = false
                        onSelected(behavior)
                        announceForAccessibility(
                            context,
                            resources.getString(R.string.accessibility_timeout_set_announcement, behavior.getDisplayName(context)),
                        )
                    },
                )
            }
        }
    }
}

@Composable
private fun ColorBlindModePicker(
    current: ColorBlindMode,
    onSelected: (ColorBlindMode) -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    var expanded by remember { mutableStateOf(false) }
    val currentLabel = stringResource(current.labelResId)

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(R.string.accessibility_color_blind_mode),
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Card(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .cardFocusIndicator()
                    .semantics { role = Role.Button }
                    .clickable { expanded = true },
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(currentLabel, style = MaterialTheme.typography.bodyLarge)
                    if (current != ColorBlindMode.NONE) {
                        Text(
                            stringResource(R.string.accessibility_color_blind_optimized, currentLabel),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Icon(Icons.Default.ArrowDropDown, contentDescription = null) // Decorative - dropdown indicator
            }
        }

        androidx.compose.material3.DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            ColorBlindMode.entries.forEach { mode ->
                val modeLabel = stringResource(mode.labelResId)
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(modeLabel) },
                    onClick = {
                        expanded = false
                        onSelected(mode)
                        announceForAccessibility(
                            context,
                            resources.getString(R.string.accessibility_color_blind_set_announcement, modeLabel),
                        )
                    },
                )
            }
        }
    }
}

@Composable
private fun ContrastLevelPicker(
    current: app.provii.wallet.ui.accessibility.ContrastLevel,
    onSelected: (app.provii.wallet.ui.accessibility.ContrastLevel) -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    var expanded by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(R.string.accessibility_contrast_level),
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Card(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .cardFocusIndicator()
                    .semantics { role = Role.Button }
                    .clickable { expanded = true },
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(current.getDisplayName(context), style = MaterialTheme.typography.bodyLarge)
                    if (current.isAAA) {
                        Text(
                            stringResource(R.string.accessibility_contrast_aaa_ratio),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        Text(
                            when (current) {
                                app.provii.wallet.ui.accessibility.ContrastLevel.STANDARD -> stringResource(R.string.accessibility_contrast_standard)
                                app.provii.wallet.ui.accessibility.ContrastLevel.HIGH -> stringResource(R.string.accessibility_contrast_aa_ratio)
                                else -> ""
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Icon(Icons.Default.ArrowDropDown, contentDescription = null) // Decorative - dropdown indicator
            }
        }

        androidx.compose.material3.DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            app.provii.wallet.ui.accessibility.ContrastLevel.entries.forEach { level ->
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(level.getDisplayName(context)) },
                    onClick = {
                        expanded = false
                        onSelected(level)
                        announceForAccessibility(
                            context,
                            resources.getString(R.string.accessibility_contrast_set_announcement, level.getDisplayName(context)),
                        )
                    },
                )
            }
        }
    }
}

/**
 * Haptic feedback toggle that vibrates when enabled.
 */
@Composable
private fun HapticFeedbackToggle(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val context = LocalContext.current
    val hapticTitle = stringResource(R.string.accessibility_haptic_feedback)
    val hapticEnabledAnnouncement = stringResource(R.string.accessibility_toggle_enabled, hapticTitle)
    val hapticDisabledAnnouncement = stringResource(R.string.accessibility_toggle_disabled, hapticTitle)

    // Get vibrator directly
    val vibrator =
        remember {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(VIBRATOR_SERVICE) as android.os.Vibrator
            }
        }

    ListItem(
        headlineContent = {
            Text(stringResource(R.string.accessibility_haptic_feedback), style = MaterialTheme.typography.titleSmall)
        },
        supportingContent = {
            Text(
                stringResource(R.string.accessibility_haptic_feedback_description),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        leadingContent = {
            Box(
                modifier =
                    Modifier
                        .size(44.dp)
                        .background(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                            shape = MaterialTheme.shapes.small,
                        ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Vibration, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
        },
        trailingContent = {
            Switch(
                checked = checked,
                onCheckedChange = { enabled ->
                    onCheckedChange(enabled)
                    if (enabled) {
                        // Direct vibrator call
                        try {
                            vibrator.vibrate(
                                android.os.VibrationEffect.createOneShot(200, android.os.VibrationEffect.DEFAULT_AMPLITUDE),
                            )
                            timber.log.Timber.d("Vibrator.vibrate() called directly")
                        } catch (e: Exception) {
                            timber.log.Timber.e(e, "Vibration failed: ${e.message}")
                        }
                    }
                    val announcement = if (enabled) hapticEnabledAnnouncement else hapticDisabledAnnouncement
                    announceForAccessibility(context, announcement)
                },
                modifier = Modifier.semantics { role = Role.Switch },
            )
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    )
}

private val ColorBlindMode.labelResId: Int
    get() =
        when (this) {
            ColorBlindMode.NONE -> R.string.color_blind_none
            ColorBlindMode.PROTANOPIA -> R.string.color_blind_protanopia
            ColorBlindMode.DEUTERANOPIA -> R.string.color_blind_deuteranopia
            ColorBlindMode.TRITANOPIA -> R.string.color_blind_tritanopia
            ColorBlindMode.MONOCHROME -> R.string.color_blind_monochrome
        }

private data class QuickProfile(
    val profile: AccessibilityProfile,
    val titleResId: Int,
    val icon: androidx.compose.ui.graphics.vector.ImageVector?,
)

private val quickProfiles =
    listOf(
        QuickProfile(AccessibilityProfile.VISION_IMPAIRED, R.string.accessibility_profile_vision, Icons.Default.VisibilityOff),
        QuickProfile(AccessibilityProfile.MOTOR_IMPAIRED, R.string.accessibility_profile_motor, Icons.AutoMirrored.Filled.Accessible),
        QuickProfile(AccessibilityProfile.COGNITIVE, R.string.accessibility_profile_cognitive, Icons.Default.Lightbulb),
        QuickProfile(AccessibilityProfile.ELDERLY, R.string.accessibility_profile_senior, Icons.Default.Elderly),
    )

/**
 * Text spacing slider component for WCAG 1.4.12 compliance
 * Displays a slider with AAA threshold indicator
 */
@Composable
private fun TextSpacingSlider(
    title: String,
    description: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    aaaThreshold: Float,
    formatValue: (Float) -> String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onValueChange: (Float) -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    val aaaAnnouncementSuffix = stringResource(R.string.accessibility_slider_announcement_aaa)
    val aaaCompliantPart = stringResource(R.string.accessibility_slider_aaa_compliant)

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier =
                        Modifier
                            .size(44.dp)
                            .background(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                                shape = MaterialTheme.shapes.small,
                            ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        icon,
                        contentDescription = null, // Decorative - illustrates setting
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                    )
                    Text(
                        text = stringResource(R.string.accessibility_spacing_current, formatValue(value)),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            if (value >= aaaThreshold) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null, // Decorative - indicates AAA compliance
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        text = stringResource(R.string.accessibility_aaa_badge),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }

        Text(
            text = description,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        val sliderContentDesc =
            resources.getString(
                R.string.accessibility_slider_description,
                title,
                formatValue(value),
                if (value >= aaaThreshold) aaaCompliantPart else "",
                formatValue(valueRange.start),
                formatValue(valueRange.endInclusive),
            )

        Slider(
            value = value,
            onValueChange = { newValue ->
                onValueChange(newValue)
                val suffix = if (newValue >= aaaThreshold) aaaAnnouncementSuffix else ""
                val announcement =
                    resources.getString(
                        R.string.accessibility_slider_announcement,
                        title,
                        formatValue(newValue),
                        suffix,
                    )
                announceForAccessibility(context, announcement)
            },
            valueRange = valueRange,
            steps = steps,
            modifier =
                Modifier
                    .fillMaxWidth()
                    .semantics {
                        this.contentDescription = sliderContentDesc
                    },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = formatValue(valueRange.start),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = stringResource(R.string.accessibility_aaa_threshold, formatValue(aaaThreshold)),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = formatValue(valueRange.endInclusive),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * Verification Feedback settings section.
 * Allows users to configure sound and haptic feedback for successful verifications.
 */
@Composable
private fun VerificationFeedbackSection(
    accessibilitySettings: AccessibilitySettings,
    onSoundEnabledChange: (Boolean) -> Unit,
    onSoundPresetChange: (String) -> Unit,
    onSoundVolumeChange: (Int) -> Unit,
    onHapticFeedbackChange: (Boolean) -> Unit,
) {
    val context = LocalContext.current
    val soundManager = remember { VerificationSoundManager(context.applicationContext) }
    DisposableEffect(soundManager) {
        onDispose { soundManager.dispose() }
    }

    // Trigger haptic preview when setting is enabled
    fun onHapticToggle(enabled: Boolean) {
        timber.log.Timber.d("Haptic toggle changed to: $enabled")
        onHapticFeedbackChange(enabled)
        if (enabled) {
            timber.log.Timber.d("Triggering haptic preview...")
            // Preview the haptic feedback immediately
            soundManager.playVerificationSuccess(
                soundEnabled = false, // Don't play sound
                preset = SoundPreset.Silent,
                volumePercent = 0,
                hapticEnabled = true,
            )
        }
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            AccessibilitySectionHeader(stringResource(R.string.accessibility_verification_feedback_section))

            // Sound enabled toggle
            @Suppress("DEPRECATION")
            AccessibilityToggle(
                title = stringResource(R.string.accessibility_sound_enabled),
                description = stringResource(R.string.accessibility_sound_enabled_description),
                checked = accessibilitySettings.soundEnabled,
                icon = Icons.Default.VolumeUp,
                onCheckedChange = onSoundEnabledChange,
            )

            // Sound preset picker (visible if sound enabled)
            if (accessibilitySettings.soundEnabled) {
                HorizontalDivider()

                SoundPresetPicker(
                    current = accessibilitySettings.verificationSoundPreset,
                    onSelected = { preset -> onSoundPresetChange(preset.name) },
                    onPreview = { preset ->
                        soundManager.previewSound(preset, accessibilitySettings.soundVolume)
                    },
                )

                HorizontalDivider()

                // Volume slider
                VolumeSlider(
                    value = accessibilitySettings.soundVolume,
                    onValueChange = onSoundVolumeChange,
                    onPreview = {
                        soundManager.previewSound(
                            accessibilitySettings.verificationSoundPreset,
                            accessibilitySettings.soundVolume,
                        )
                    },
                )
            }

            HorizontalDivider()

            // Haptic feedback toggle
            AccessibilityToggle(
                title = stringResource(R.string.accessibility_haptic_enabled),
                description = stringResource(R.string.accessibility_haptic_enabled_description),
                checked = accessibilitySettings.hapticFeedback,
                icon = Icons.Default.Vibration,
                onCheckedChange = { enabled -> onHapticToggle(enabled) },
            )

            // Footer note
            Text(
                text = stringResource(R.string.accessibility_sound_footer),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

/**
 * Sound preset picker with preview button.
 */
@Composable
private fun SoundPresetPicker(
    current: SoundPreset,
    onSelected: (SoundPreset) -> Unit,
    onPreview: (SoundPreset) -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    var expanded by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(R.string.accessibility_sound_style),
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Preset dropdown
            Card(
                modifier =
                    Modifier
                        .weight(1f)
                        .cardFocusIndicator()
                        .semantics { role = Role.Button }
                        .clickable { expanded = true },
            ) {
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(current.displayName, style = MaterialTheme.typography.bodyLarge)
                        Text(
                            current.description,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Icon(Icons.Default.ArrowDropDown, contentDescription = null) // Decorative - dropdown behaviour described by parent
                }
            }

            // Preview button
            IconButton(
                onClick = { onPreview(current) },
                modifier =
                    Modifier
                        .size(48.dp)
                        .background(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                            shape = MaterialTheme.shapes.small,
                        ),
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = stringResource(R.string.accessibility_sound_preview),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }

        // Dropdown menu
        androidx.compose.material3.DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            SoundPreset.audioPresets.forEach { preset ->
                androidx.compose.material3.DropdownMenuItem(
                    text = {
                        Column {
                            Text(preset.displayName)
                            Text(
                                preset.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    },
                    onClick = {
                        expanded = false
                        onSelected(preset)
                        announceForAccessibility(context, resources.getString(R.string.accessibility_sound_style_set_announcement, preset.displayName))
                    },
                    trailingIcon = {
                        IconButton(
                            onClick = {
                                onPreview(preset)
                            },
                            modifier = Modifier.defaultMinSize(minWidth = 44.dp, minHeight = 44.dp),
                        ) {
                            Icon(
                                Icons.Default.PlayArrow,
                                contentDescription = stringResource(R.string.accessibility_sound_preview_preset, preset.displayName),
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    },
                )
            }
        }
    }
}

/**
 * Volume slider with preview button.
 */
@Composable
private fun VolumeSlider(
    value: Int,
    onValueChange: (Int) -> Unit,
    onPreview: () -> Unit,
) {
    val context = LocalContext.current
    val resources = context.resources
    val volumeSetText = resources.getString(R.string.accessibility_volume_set_announcement, value)
    val volumeSliderDesc = resources.getString(R.string.accessibility_volume_slider_description, value)

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier =
                        Modifier
                            .size(44.dp)
                            .background(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                                shape = MaterialTheme.shapes.small,
                            ),
                    contentAlignment = Alignment.Center,
                ) {
                    @Suppress("DEPRECATION")
                    Icon(
                        when {
                            value == 0 -> Icons.Default.VolumeOff
                            value < 50 -> Icons.Default.VolumeDown
                            else -> Icons.Default.VolumeUp
                        },
                        contentDescription = null, // Decorative - volume level described by adjacent text
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        text = stringResource(R.string.accessibility_volume),
                        style = MaterialTheme.typography.titleSmall,
                    )
                    Text(
                        text = stringResource(R.string.accessibility_volume_percent, value),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Preview button
            IconButton(
                onClick = onPreview,
                modifier =
                    Modifier
                        .defaultMinSize(minWidth = 44.dp, minHeight = 44.dp)
                        .background(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                            shape = MaterialTheme.shapes.small,
                        ),
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = stringResource(R.string.accessibility_volume_preview),
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        Slider(
            value = value.toFloat(),
            onValueChange = { newValue ->
                val intValue = newValue.toInt()
                onValueChange(intValue)
            },
            onValueChangeFinished = {
                announceForAccessibility(context, volumeSetText)
            },
            valueRange = 0f..100f,
            steps = 9,
            modifier =
                Modifier
                    .fillMaxWidth()
                    .semantics {
                        contentDescription = volumeSliderDesc
                    },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(R.string.accessibility_volume_min),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = stringResource(R.string.accessibility_volume_max),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
