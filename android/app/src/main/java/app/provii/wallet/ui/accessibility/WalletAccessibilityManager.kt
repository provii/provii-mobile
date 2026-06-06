// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.content.Context
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.annotation.VisibleForTesting
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber

private const val ACCESSIBILITY_DATASTORE = "accessibility_settings"

private val Context.accessibilityDataStore by preferencesDataStore(name = ACCESSIBILITY_DATASTORE)

/**
 * Singleton source of truth for all accessibility configuration on Android. Persists
 * settings in a Preferences DataStore and observes system-level TalkBack and reduced
 * motion state via [AccessibilityManager] and [ContentObserver]. Mirrors the behaviour
 * of the iOS AccessibilityManager, including quick-setup profiles and WCAG helper methods.
 */
@Singleton
class WalletAccessibilityManager
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
    ) {
        private val job: Job = SupervisorJob()
        private val scope = CoroutineScope(job + Dispatchers.IO)
        private val systemAccessibility: AccessibilityManager =
            context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager

        private val _settings = MutableStateFlow(AccessibilitySettings.Default)
        val settings: StateFlow<AccessibilitySettings> = _settings.asStateFlow()

        private val _isTalkBackEnabled = MutableStateFlow(systemAccessibility.isTouchExplorationEnabled)
        val isTalkBackEnabled: StateFlow<Boolean> = _isTalkBackEnabled.asStateFlow()

        private val _prefersReducedMotion = MutableStateFlow(readSystemReduceMotion())
        val prefersReducedMotion: StateFlow<Boolean> = _prefersReducedMotion.asStateFlow()

        private var animationObserver: ContentObserver? = null

        init {
            observeDataStore()
            observeSystemAccessibility()
        }

        private fun observeDataStore() {
            context.accessibilityDataStore.data
                .catch { throwable ->
                    Timber.w(throwable, "Failed to read accessibility settings; using defaults")
                    emit(emptyPreferences())
                }
                .map { prefs -> prefs.toSettings() }
                .onEach { settings -> _settings.value = settings }
                .launchIn(scope)
        }

        private fun observeSystemAccessibility() {
            val touchExplorationListener =
                AccessibilityManager.TouchExplorationStateChangeListener { enabled ->
                    _isTalkBackEnabled.value = enabled
                    if (enabled && !_settings.value.hasAcknowledgedTalkBack) {
                        updateSettingsInternal { current ->
                            current.copy(
                                hasAcknowledgedTalkBack = true,
                                verboseDescriptions = true,
                            )
                        }
                    }
                }
            systemAccessibility.addTouchExplorationStateChangeListener(touchExplorationListener)

            // Use ContentObserver instead of polling for animation scale changes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                animationObserver =
                    object : ContentObserver(Handler(Looper.getMainLooper())) {
                        override fun onChange(selfChange: Boolean) {
                            _prefersReducedMotion.value = readSystemReduceMotion()
                        }
                    }

                // Observe all animation scale settings
                animationObserver?.let { observer ->
                    context.contentResolver.registerContentObserver(
                        Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
                        false,
                        observer,
                    )
                    context.contentResolver.registerContentObserver(
                        Settings.Global.getUriFor(Settings.Global.TRANSITION_ANIMATION_SCALE),
                        false,
                        observer,
                    )
                    context.contentResolver.registerContentObserver(
                        Settings.Global.getUriFor(Settings.Global.WINDOW_ANIMATION_SCALE),
                        false,
                        observer,
                    )
                }

                // Initial read
                _prefersReducedMotion.value = readSystemReduceMotion()
            }

            job.invokeOnCompletion {
                systemAccessibility.removeTouchExplorationStateChangeListener(touchExplorationListener)
                animationObserver?.let {
                    context.contentResolver.unregisterContentObserver(it)
                }
            }
        }

        private fun readSystemReduceMotion(): Boolean {
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                    val animatorScale =
                        Settings.Global.getFloat(
                            context.contentResolver,
                            Settings.Global.TRANSITION_ANIMATION_SCALE,
                            1f,
                        )
                    animatorScale == 0f
                } else {
                    false
                }
            } catch (t: Throwable) {
                Timber.w(t, "Unable to read transition animation scale")
                false
            }
        }

        fun updateSetting(transform: (AccessibilitySettings) -> AccessibilitySettings) {
            updateSettingsInternal(transform)
        }

        fun setSettings(settings: AccessibilitySettings) {
            updateSettingsInternal { settings }
        }

        fun reset() {
            updateSettingsInternal { AccessibilitySettings.Default }
        }

        fun applyQuickSetup(profile: AccessibilityProfile) {
            val updated =
                when (profile) {
                    AccessibilityProfile.VISION_IMPAIRED ->
                        AccessibilitySettings.Default.copy(
                            useExtraLargeText = true,
                            useHighContrast = true,
                            reduceTransparency = true,
                            increaseTouchTargets = true,
                            verboseDescriptions = true,
                            hapticFeedback = true,
                        )
                    AccessibilityProfile.MOTOR_IMPAIRED ->
                        AccessibilitySettings.Default.copy(
                            increaseTouchTargets = true,
                            timeoutBehavior = TimeoutBehavior.EXTENDED,
                            simplifiedGestures = true,
                            confirmBeforeActions = true,
                        )
                    AccessibilityProfile.COGNITIVE ->
                        AccessibilitySettings.Default.copy(
                            simplifiedUI = true,
                            showStepNumbers = true,
                            verboseDescriptions = true,
                            reduceMotion = true,
                            confirmBeforeActions = true,
                        )
                    AccessibilityProfile.ELDERLY ->
                        AccessibilitySettings.Default.copy(
                            useExtraLargeText = true,
                            increaseTouchTargets = true,
                            timeoutBehavior = TimeoutBehavior.EXTENDED,
                            simplifiedUI = true,
                            reduceMotion = true,
                        )
                    AccessibilityProfile.DEFAULT -> AccessibilitySettings.Default
                }
            setSettings(updated)
        }

        private fun updateSettingsInternal(transform: (AccessibilitySettings) -> AccessibilitySettings) {
            scope.launch {
                context.accessibilityDataStore.edit { prefs ->
                    val current = prefs.toSettings()
                    val updated = transform(current)
                    prefs.updateFromSettings(updated)
                }
            }
        }

        suspend fun awaitSettings(): AccessibilitySettings = withContext(Dispatchers.IO) { settings.value }

        @VisibleForTesting
        internal fun clear() {
            scope.launch { context.accessibilityDataStore.edit { it.clear() } }
        }

        // MARK: - Helper Methods (matching iOS)

        /**
         * Returns the minimum touch target size based on accessibility settings.
         * Three tiers matching iOS: 48dp (standard), 52dp (large), 60dp (AAA).
         * WCAG 2.2 AAA: 2.5.5 Target Size
         */
        fun minimumTouchTargetSize(): Int {
            val s = settings.value
            return when {
                s.increaseTouchTargets && s.useExtraLargeText -> 60 // AAA tier
                s.increaseTouchTargets -> 52 // Large tier
                else -> 48 // Standard tier (Android minimum)
            }
        }

        /**
         * Returns the timeout duration in milliseconds, or null for no timeout.
         * WCAG 2.2 AAA: 2.2.3 No Timing
         */
        fun getTimeoutDuration(standard: Long = 30_000L): Long? {
            return when (settings.value.timeoutBehavior) {
                TimeoutBehavior.NONE -> null // No timeout (AAA)
                TimeoutBehavior.STANDARD -> standard
                TimeoutBehavior.EXTENDED -> standard * 2
            }
        }

        /**
         * Returns whether step indicators should be shown.
         */
        fun shouldShowStepIndicator(): Boolean {
            return settings.value.showStepNumbers || settings.value.simplifiedUI
        }

        /**
         * Returns animation duration, 0 if reduce motion is enabled.
         */
        fun animationDuration(base: Long): Long {
            return if (settings.value.reduceMotion) 0L else base
        }

        /**
         * Returns whether automatic context changes should be allowed.
         * WCAG 2.2 AAA: 3.2.5 Change on Request
         */
        fun shouldAllowAutoContextChanges(): Boolean {
            return !settings.value.disableAutoContextChanges
        }

        fun dispose() {
            scope.cancel()
        }

        private fun Preferences.toSettings(): AccessibilitySettings {
            return AccessibilitySettings(
                // Vision
                contrastLevel =
                    this[KEY_CONTRAST_LEVEL]?.let { runCatching { ContrastLevel.valueOf(it) }.getOrNull() }
                        ?: AccessibilitySettings.Default.contrastLevel,
                useHighContrast = this[KEY_USE_HIGH_CONTRAST] ?: AccessibilitySettings.Default.useHighContrast,
                useExtraLargeText = this[KEY_USE_EXTRA_LARGE_TEXT] ?: AccessibilitySettings.Default.useExtraLargeText,
                reduceTransparency = this[KEY_REDUCE_TRANSPARENCY] ?: AccessibilitySettings.Default.reduceTransparency,
                colorBlindMode =
                    this[KEY_COLOR_BLIND_MODE]?.let { runCatching { ColorBlindMode.valueOf(it) }.getOrNull() }
                        ?: AccessibilitySettings.Default.colorBlindMode,
                // Typography
                lineSpacingMultiplier = this[KEY_LINE_SPACING] ?: AccessibilitySettings.Default.lineSpacingMultiplier,
                paragraphSpacingMultiplier = this[KEY_PARAGRAPH_SPACING] ?: AccessibilitySettings.Default.paragraphSpacingMultiplier,
                letterSpacingMultiplier = this[KEY_LETTER_SPACING] ?: AccessibilitySettings.Default.letterSpacingMultiplier,
                textWidth =
                    this[KEY_TEXT_WIDTH]?.let { runCatching { TextWidth.valueOf(it) }.getOrNull() }
                        ?: AccessibilitySettings.Default.textWidth,
                // Motor & Interaction
                increaseTouchTargets = this[KEY_INCREASE_TOUCH_TARGETS] ?: AccessibilitySettings.Default.increaseTouchTargets,
                reduceMotion = this[KEY_REDUCE_MOTION] ?: AccessibilitySettings.Default.reduceMotion,
                timeoutBehavior =
                    this[KEY_TIMEOUT_BEHAVIOR]?.let { runCatching { TimeoutBehavior.valueOf(it) }.getOrNull() }
                        ?: AccessibilitySettings.Default.timeoutBehavior,
                simplifiedGestures = this[KEY_SIMPLIFIED_GESTURES] ?: AccessibilitySettings.Default.simplifiedGestures,
                hapticFeedback = this[KEY_HAPTIC_FEEDBACK] ?: AccessibilitySettings.Default.hapticFeedback,
                // Sound Feedback
                soundEnabled = this[KEY_SOUND_ENABLED] ?: AccessibilitySettings.Default.soundEnabled,
                soundPreset = this[KEY_SOUND_PRESET] ?: AccessibilitySettings.Default.soundPreset,
                soundVolume = this[KEY_SOUND_VOLUME] ?: AccessibilitySettings.Default.soundVolume,
                // Cognitive
                simplifiedUI = this[KEY_SIMPLIFIED_UI] ?: AccessibilitySettings.Default.simplifiedUI,
                showStepNumbers = this[KEY_SHOW_STEP_NUMBERS] ?: AccessibilitySettings.Default.showStepNumbers,
                verboseDescriptions = this[KEY_VERBOSE_DESCRIPTIONS] ?: AccessibilitySettings.Default.verboseDescriptions,
                confirmBeforeActions = this[KEY_CONFIRM_BEFORE_ACTIONS] ?: AccessibilitySettings.Default.confirmBeforeActions,
                disableAutoContextChanges = this[KEY_DISABLE_AUTO_CONTEXT_CHANGES] ?: AccessibilitySettings.Default.disableAutoContextChanges,
                readingLevel =
                    this[KEY_READING_LEVEL]?.let { runCatching { ReadingLevel.valueOf(it) }.getOrNull() }
                        ?: AccessibilitySettings.Default.readingLevel,
                // Dyslexia Font
                useDyslexiaFont = this[KEY_USE_DYSLEXIA_FONT] ?: AccessibilitySettings.Default.useDyslexiaFont,
                // Alternative Input
                enableManualCodeEntry = this[KEY_ENABLE_MANUAL_CODE_ENTRY] ?: AccessibilitySettings.Default.enableManualCodeEntry,
                enableVoiceInput = this[KEY_ENABLE_VOICE_INPUT] ?: AccessibilitySettings.Default.enableVoiceInput,
                // Onboarding
                hasCompletedAccessibilityOnboarding =
                    this[KEY_HAS_COMPLETED_ONBOARDING]
                        ?: AccessibilitySettings.Default.hasCompletedAccessibilityOnboarding,
                hasAcknowledgedTalkBack =
                    this[KEY_HAS_ACK_TALKBACK]
                        ?: AccessibilitySettings.Default.hasAcknowledgedTalkBack,
            )
        }

        private fun MutablePreferences.updateFromSettings(settings: AccessibilitySettings) {
            // Vision
            this[KEY_CONTRAST_LEVEL] = settings.contrastLevel.name
            this[KEY_USE_HIGH_CONTRAST] = settings.useHighContrast
            this[KEY_USE_EXTRA_LARGE_TEXT] = settings.useExtraLargeText
            this[KEY_REDUCE_TRANSPARENCY] = settings.reduceTransparency
            this[KEY_COLOR_BLIND_MODE] = settings.colorBlindMode.name

            // Typography
            this[KEY_LINE_SPACING] = settings.lineSpacingMultiplier
            this[KEY_PARAGRAPH_SPACING] = settings.paragraphSpacingMultiplier
            this[KEY_LETTER_SPACING] = settings.letterSpacingMultiplier
            this[KEY_TEXT_WIDTH] = settings.textWidth.name

            // Motor & Interaction
            this[KEY_INCREASE_TOUCH_TARGETS] = settings.increaseTouchTargets
            this[KEY_REDUCE_MOTION] = settings.reduceMotion
            this[KEY_TIMEOUT_BEHAVIOR] = settings.timeoutBehavior.name
            this[KEY_SIMPLIFIED_GESTURES] = settings.simplifiedGestures
            this[KEY_HAPTIC_FEEDBACK] = settings.hapticFeedback

            // Sound Feedback
            this[KEY_SOUND_ENABLED] = settings.soundEnabled
            this[KEY_SOUND_PRESET] = settings.soundPreset
            this[KEY_SOUND_VOLUME] = settings.soundVolume

            // Cognitive
            this[KEY_SIMPLIFIED_UI] = settings.simplifiedUI
            this[KEY_SHOW_STEP_NUMBERS] = settings.showStepNumbers
            this[KEY_VERBOSE_DESCRIPTIONS] = settings.verboseDescriptions
            this[KEY_CONFIRM_BEFORE_ACTIONS] = settings.confirmBeforeActions
            this[KEY_DISABLE_AUTO_CONTEXT_CHANGES] = settings.disableAutoContextChanges
            this[KEY_READING_LEVEL] = settings.readingLevel.name

            // Dyslexia Font
            this[KEY_USE_DYSLEXIA_FONT] = settings.useDyslexiaFont

            // Alternative Input
            this[KEY_ENABLE_MANUAL_CODE_ENTRY] = settings.enableManualCodeEntry
            this[KEY_ENABLE_VOICE_INPUT] = settings.enableVoiceInput

            // Onboarding
            this[KEY_HAS_COMPLETED_ONBOARDING] = settings.hasCompletedAccessibilityOnboarding
            this[KEY_HAS_ACK_TALKBACK] = settings.hasAcknowledgedTalkBack
        }

        companion object {
            // Vision
            private val KEY_CONTRAST_LEVEL = stringPreferencesKey("contrast_level")
            private val KEY_USE_HIGH_CONTRAST = booleanPreferencesKey("use_high_contrast")
            private val KEY_USE_EXTRA_LARGE_TEXT = booleanPreferencesKey("use_extra_large_text")
            private val KEY_REDUCE_TRANSPARENCY = booleanPreferencesKey("reduce_transparency")
            private val KEY_COLOR_BLIND_MODE = stringPreferencesKey("color_blind_mode")

            // Typography (WCAG AAA 1.4.8)
            private val KEY_LINE_SPACING = floatPreferencesKey("line_spacing_multiplier")
            private val KEY_PARAGRAPH_SPACING = floatPreferencesKey("paragraph_spacing_multiplier")
            private val KEY_LETTER_SPACING = floatPreferencesKey("letter_spacing_multiplier")
            private val KEY_TEXT_WIDTH = stringPreferencesKey("text_width")

            // Motor & Interaction
            private val KEY_INCREASE_TOUCH_TARGETS = booleanPreferencesKey("increase_touch_targets")
            private val KEY_REDUCE_MOTION = booleanPreferencesKey("reduce_motion")
            private val KEY_TIMEOUT_BEHAVIOR = stringPreferencesKey("timeout_behavior")
            private val KEY_SIMPLIFIED_GESTURES = booleanPreferencesKey("simplified_gestures")
            private val KEY_HAPTIC_FEEDBACK = booleanPreferencesKey("haptic_feedback")

            // Sound Feedback
            private val KEY_SOUND_ENABLED = booleanPreferencesKey("sound_enabled")
            private val KEY_SOUND_PRESET = stringPreferencesKey("sound_preset")
            private val KEY_SOUND_VOLUME = intPreferencesKey("sound_volume")

            // Cognitive
            private val KEY_SIMPLIFIED_UI = booleanPreferencesKey("simplified_ui")
            private val KEY_SHOW_STEP_NUMBERS = booleanPreferencesKey("show_step_numbers")
            private val KEY_VERBOSE_DESCRIPTIONS = booleanPreferencesKey("verbose_descriptions")
            private val KEY_CONFIRM_BEFORE_ACTIONS = booleanPreferencesKey("confirm_before_actions")
            private val KEY_DISABLE_AUTO_CONTEXT_CHANGES = booleanPreferencesKey("disable_auto_context_changes")
            private val KEY_READING_LEVEL = stringPreferencesKey("reading_level")

            // Dyslexia Font
            private val KEY_USE_DYSLEXIA_FONT = booleanPreferencesKey("use_dyslexia_font")

            // Alternative Input
            private val KEY_ENABLE_MANUAL_CODE_ENTRY = booleanPreferencesKey("enable_manual_code_entry")
            private val KEY_ENABLE_VOICE_INPUT = booleanPreferencesKey("enable_voice_input")

            // Onboarding
            private val KEY_HAS_COMPLETED_ONBOARDING = booleanPreferencesKey("has_completed_onboarding")
            private val KEY_HAS_ACK_TALKBACK = booleanPreferencesKey("has_acknowledged_talkback")
        }
    }
