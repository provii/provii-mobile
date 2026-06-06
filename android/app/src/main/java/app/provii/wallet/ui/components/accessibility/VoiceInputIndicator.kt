// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState

/**
 * Visual feedback indicators for voice input state. The [VoiceInputIndicator] displays a
 * pulsing microphone animation when speech recognition is active, respecting the
 * reduce-motion preference by falling back to a static indicator. Also provides a
 * [VoiceInputError] card for displaying recognition failure messages with assertive
 * live-region announcements.
 */
@Composable
fun VoiceInputIndicator(
    isListening: Boolean,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 48.dp,
) {
    // WCAG 2.3.3: Respect reduce motion setting
    val accessibilityUiState = LocalAccessibilityUiState.current
    val reduceMotion = accessibilityUiState.settings.reduceMotion || accessibilityUiState.prefersReducedMotion

    val infiniteTransition = rememberInfiniteTransition(label = "voicePulse")

    val animatedPulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.3f,
        animationSpec =
            infiniteRepeatable(
                animation =
                    tween(
                        durationMillis = 1000,
                        easing = FastOutSlowInEasing,
                    ),
                repeatMode = RepeatMode.Reverse,
            ),
        label = "pulseScale",
    )
    val pulseScale = if (reduceMotion) 1f else animatedPulseScale

    val animatedPulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.7f,
        animationSpec =
            infiniteRepeatable(
                animation =
                    tween(
                        durationMillis = 1000,
                        easing = FastOutSlowInEasing,
                    ),
                repeatMode = RepeatMode.Reverse,
            ),
        label = "pulseAlpha",
    )
    val pulseAlpha = if (reduceMotion) 0.5f else animatedPulseAlpha

    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center,
    ) {
        if (isListening) {
            // Outer pulsing ring
            Box(
                modifier =
                    Modifier
                        .size(size)
                        .scale(pulseScale)
                        .alpha(pulseAlpha)
                        .background(
                            color = MaterialTheme.colorScheme.error.copy(alpha = 0.6f),
                            shape = CircleShape,
                        ),
            )

            // Inner pulsing ring
            Box(
                modifier =
                    Modifier
                        .size(size * 0.7f)
                        .scale(pulseScale * 0.9f)
                        .alpha(pulseAlpha * 1.2f)
                        .background(
                            color = MaterialTheme.colorScheme.error.copy(alpha = 0.5f),
                            shape = CircleShape,
                        ),
            )
        }

        // Microphone icon - always visible
        Box(
            modifier =
                Modifier
                    .size(size * 0.5f)
                    .background(
                        color =
                            if (isListening) {
                                MaterialTheme.colorScheme.error
                            } else {
                                MaterialTheme.colorScheme.primary
                            },
                        shape = CircleShape,
                    ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Default.Mic,
                contentDescription =
                    stringResource(
                        if (isListening) {
                            R.string.content_desc_voice_input_listening
                        } else {
                            R.string.content_desc_voice_input_available
                        },
                    ),
                tint = Color.White,
                modifier = Modifier.size(size * 0.3f),
            )
        }
    }
}

/**
 * Error state indicator for voice input failures
 */
@Composable
fun VoiceInputError(
    errorMessage: String,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.errorContainer,
            ),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                Icons.Default.Error,
                contentDescription = null, // Decorative
                tint = MaterialTheme.colorScheme.error,
            )
            Text(
                text = errorMessage,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
        }
    }
}
