// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.TimeoutBehavior
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Global animation pause/resume system satisfying WCAG 2.2 AA criterion 2.2.2 (Pause,
 * Stop, Hide). Includes a singleton [AnimationStateManager], a composable pause button,
 * a control banner showing active animation count, an accessible progress indicator that
 * respects reduced-motion preferences, and auto-pause for animations exceeding five
 * seconds. Mirrors iOS AnimationControls.swift.
 */
object AnimationStateManager {
    private val _isPaused = MutableStateFlow(false)
    val isPaused: StateFlow<Boolean> = _isPaused.asStateFlow()

    private val _activeAnimations = MutableStateFlow<Set<String>>(emptySet())
    val activeAnimations: StateFlow<Set<String>> = _activeAnimations.asStateFlow()

    fun pauseAll() {
        _isPaused.value = true
    }

    fun resumeAll() {
        _isPaused.value = false
    }

    fun toggle() {
        _isPaused.value = !_isPaused.value
    }

    fun registerAnimation(id: String) {
        _activeAnimations.value = _activeAnimations.value + id
    }

    fun unregisterAnimation(id: String) {
        _activeAnimations.value = _activeAnimations.value - id
    }
}

/**
 * Pause/resume button for controlling all animations.
 * Respects 48dp minimum touch target (or 60dp when enlarged targets are enabled).
 * Announces state changes via TalkBack when accessibility services are active.
 */
@Composable
fun AnimationPauseButton(modifier: Modifier = Modifier) {
    val isPaused by AnimationStateManager.isPaused.collectAsState()
    val uiState = LocalAccessibilityUiState.current
    val context = LocalContext.current

    val label =
        if (isPaused) {
            stringResource(R.string.animation_resume_animations)
        } else {
            stringResource(R.string.animation_pause_animations)
        }
    val hint = stringResource(R.string.animation_toggles_playback_hint)

    Button(
        onClick = {
            AnimationStateManager.toggle()
            val newPaused = AnimationStateManager.isPaused.value
            announceAnimationStateChange(context, newPaused)
        },
        modifier =
            modifier
                .defaultMinSize(minWidth = uiState.minTouchTarget, minHeight = uiState.minTouchTarget)
                .semantics {
                    contentDescription = "$label. $hint"
                },
        shape = RoundedCornerShape(8.dp),
        colors =
            ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            ),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = if (isPaused) Icons.Default.PlayArrow else Icons.Default.Pause,
                contentDescription = null,
            )
            Text(
                text =
                    if (isPaused) {
                        stringResource(R.string.animation_resume_button_text)
                    } else {
                        stringResource(R.string.animation_pause_button_text)
                    },
            )
        }
    }
}

/**
 * Banner that shows the count of active animations and provides a pause control.
 * Only visible when animations are running and reduce motion is not enabled.
 * Matches iOS AnimationControlBanner.
 */
@Composable
fun AnimationControlBanner(modifier: Modifier = Modifier) {
    val activeAnimations by AnimationStateManager.activeAnimations.collectAsState()
    val uiState = LocalAccessibilityUiState.current

    if (activeAnimations.isNotEmpty() && !uiState.settings.reduceMotion) {
        val bannerPadding = if (uiState.settings.increaseTouchTargets) 16.dp else 12.dp

        Card(
            modifier =
                modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(8.dp),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                ),
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(bannerPadding),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Movie,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        text =
                            stringResource(
                                R.string.animation_active_count,
                                activeAnimations.size,
                            ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                AnimationPauseButton()
            }
        }
    }
}

/**
 * Progress indicator that respects animation pause state and reduce motion settings.
 * Shows a static hourglass icon when animations are paused or reduced motion is on.
 * Matches iOS AccessibleProgressView.
 */
@Composable
fun AccessibleProgressView(
    modifier: Modifier = Modifier,
    message: String = stringResource(R.string.animation_loading_default),
    progress: Float? = null,
) {
    val isPaused by AnimationStateManager.isPaused.collectAsState()
    val uiState = LocalAccessibilityUiState.current
    val activeAnimations by AnimationStateManager.activeAnimations.collectAsState()

    val progressLabel =
        progress?.let {
            stringResource(R.string.animation_percent_complete, (it * 100).toInt())
        } ?: stringResource(R.string.animation_loading_in_progress)

    Column(
        modifier =
            modifier
                .padding(32.dp)
                .semantics {
                    contentDescription = "$message. $progressLabel"
                    liveRegion = LiveRegionMode.Polite
                },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        if (uiState.settings.reduceMotion || isPaused) {
            // Static indicator for reduced motion or paused state
            Text(
                text = "\u231B", // Hourglass character
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        } else {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )

        if (progress != null) {
            androidx.compose.material3.LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth(0.6f),
                color = MaterialTheme.colorScheme.primary,
            )
        }

        if (uiState.settings.verboseDescriptions) {
            Text(
                text = stringResource(R.string.animation_please_wait),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Show pause button if animations are playing
        if (!uiState.settings.reduceMotion && activeAnimations.isNotEmpty()) {
            AnimationPauseButton(
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

/**
 * Composable side effect that registers an animation on appear and unregisters on dispose.
 * Use this inside any composable that runs an animation to participate in the global
 * pause/resume system.
 */
@Composable
fun RegisterAnimation(id: String) {
    DisposableEffect(id) {
        AnimationStateManager.registerAnimation(id)
        onDispose {
            AnimationStateManager.unregisterAnimation(id)
        }
    }
}

/**
 * Composable side effect that auto-pauses all animations after a specified duration.
 * WCAG 2.2.2 requires animations running longer than 5 seconds to provide a pause mechanism.
 * This automatically pauses after the threshold and announces the change to TalkBack.
 */
@Composable
fun AutoPauseEffect(
    durationSeconds: Double,
    id: String,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    DisposableEffect(id, durationSeconds) {
        var job: Job? = null
        if (durationSeconds > 5.0) {
            job =
                scope.launch {
                    delay((5.0 * 1000).toLong())
                    AnimationStateManager.pauseAll()
                    announceAnimationStateChange(context, true)
                }
        }
        onDispose {
            job?.cancel()
        }
    }
}

/**
 * Determines whether animations should play based on current pause state, reduce motion
 * setting, and system preferences. Returns 0 duration when animations should not play,
 * 1.5x duration when extended timeouts are enabled, or the base duration otherwise.
 *
 * Matches iOS ControlledAnimationModifier logic.
 */
fun effectiveAnimationDuration(
    baseDurationMillis: Int,
    isPaused: Boolean,
    reduceMotion: Boolean,
    prefersReducedMotion: Boolean,
    timeoutBehavior: TimeoutBehavior,
): Int =
    when {
        reduceMotion || prefersReducedMotion -> 0
        isPaused -> 0
        timeoutBehavior == TimeoutBehavior.EXTENDED -> (baseDurationMillis * 1.5).toInt()
        else -> baseDurationMillis
    }

/**
 * Announces animation state change to TalkBack if accessibility services are active.
 */
private fun announceAnimationStateChange(
    context: android.content.Context,
    isPaused: Boolean,
) {
    val a11yManager =
        context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE)
            as? AccessibilityManager ?: return

    if (!a11yManager.isTouchExplorationEnabled) return

    val message =
        if (isPaused) {
            context.getString(R.string.animation_paused_announcement)
        } else {
            context.getString(R.string.animation_resumed_announcement)
        }

    val event =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            AccessibilityEvent(AccessibilityEvent.TYPE_ANNOUNCEMENT)
        } else {
            AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
        }
    event.text.add(message)
    a11yManager.sendAccessibilityEvent(event)
}
