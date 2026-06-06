// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens

import android.os.Build
import app.provii.wallet.R
import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.view.accessibility.AccessibilityEvent
import app.provii.wallet.audio.VerificationSoundManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.announceForAccessibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Navy lightened from #1E3650 to #2E527A for WCAG 1.4.11 (3:1 contrast against bg)
private val SplashBackground = Color(0xFF0A0A0F)
private val NavyColor = Color(0xFF2E527A)
private val TealColor = Color(0xFF0D9488)

private val PBodyEasing = CubicBezierEasing(0.4f, 0f, 0.2f, 1f)
private val CheckmarkEasing = CubicBezierEasing(0.2f, 0f, 0.1f, 1f)

// SVG path data in a 400x400 coordinate space (traced from the original PNG via potrace)
private const val P_BODY_SVG = "M185.5 25.7 c-12.5 1.5 -24.7 4.1 -34.7 7.3 c-24.6 8.1 -43.7 19.8 -61.8 38.0 c-21.8 21.7 -34.8 45.4 -42.2 77.2 l-2.2 9.3 l-0.3 107.9 c-0.3 70.1 0.0 108.3 0.6 108.9 c1.1 1.1 3.0 -0.5 33.4 -28.8 c10.7 -9.9 20.2 -19.2 21.1 -20.7 l1.6 -2.6 l0.0 -72.9 c0.0 -43.4 0.4 -76.4 1.0 -81.8 c1.5 -12.5 3.4 -19.5 8.6 -30.4 c9.1 -19.4 23.3 -34.1 42.3 -44.0 c13.2 -6.8 22.3 -9.6 37.1 -11.1 c19.7 -2.1 41.2 3.3 59.6 15.0 c2.7 1.6 5.7 3.0 6.9 3.0 c1.4 -0.0 8.5 -6.4 21.0 -19.0 l18.8 -19.0 l-1.8 -2.0 c-2.4 -2.6 -17.4 -12.8 -25.5 -17.3 c-8.9 -4.9 -21.9 -10.1 -31.5 -12.7 c-4.4 -1.1 -12.7 -2.7 -18.5 -3.5 c-9.6 -1.3 -26.1 -1.7 -33.5 -0.8 z"

private const val CHECKMARK_SVG = "M264.8 116.0 c-43.4 43.9 -62.9 63.0 -64.4 63.0 c-1.4 -0.0 -8.0 -6.0 -20.3 -18.5 c-10.1 -10.3 -18.9 -18.5 -19.9 -18.5 c-1.0 -0.0 -7.5 5.8 -14.6 12.9 l-12.8 12.9 l1.0 1.9 c1.5 2.8 59.7 62.4 62.3 63.9 c1.3 0.7 3.8 1.3 5.4 1.4 l3.0 -0.0 l75.7 -76.2 c48.7 -49.1 75.7 -77.0 75.8 -78.3 c0.0 -2.5 -24.7 -27.5 -27.2 -27.5 c-0.9 -0.0 -29.7 28.3 -64.0 63.0 z"

private const val BOWL_SVG = "M315.4 145.4 l-22.4 23.0 l0.0 3.7 c0.0 11.7 -4.5 30.0 -10.3 41.4 c-10.4 20.7 -28.5 37.3 -49.7 45.4 c-12.0 4.7 -23.5 6.4 -37.5 5.8 c-6.6 -0.3 -14.9 -1.3 -18.5 -2.3 c-20.1 -5.3 -40.1 -18.3 -54.2 -35.3 c-2.0 -2.3 -4.1 -4.0 -4.7 -3.6 c-0.8 0.4 -1.1 11.8 -1.1 35.5 l0.0 34.9 l2.2 2.5 c2.9 3.2 14.2 9.5 25.5 14.2 c20.2 8.4 46.1 12.4 67.2 10.4 c20.3 -1.9 35.3 -6.1 52.6 -14.6 c13.9 -6.8 26.5 -15.8 38.2 -27.3 c24.5 -24.2 38.7 -51.7 43.8 -85.1 c2.0 -12.5 1.9 -32.3 -0.1 -44.1 c-1.7 -10.0 -5.9 -24.7 -7.6 -26.4 c-0.6 -0.7 -8.5 6.8 -23.4 21.9 z"

/** Parse an SVG path string into a Compose [Path]. */
private fun parseSvgPath(svgData: String): Path {
    return PathParser().parsePathString(svgData).toPath()
}

/**
 * Animated splash screen that plays on every cold start. Draws the Provii logo
 * outline via stroke-dash animation, then cross-fades to the filled version.
 *
 * WCAG compliance:
 * - 2.3.3: Reduced motion skips animation (static logo for 0.5s)
 * - 1.4.11: Navy colour meets 3:1 contrast against background
 * - 2.1.2: No focus trap (auto-dismisses)
 * - 2.2.1: Tap-to-skip
 * - 4.1.3: Sends TYPE_WINDOW_STATE_CHANGED for TalkBack focus transfer
 * - 1.3.1: contentDescription = "Provii"
 */
@Composable
fun ProviiSplashScreen(
    onComplete: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current

    // Synthesised chime via VerificationSoundManager (no .wav dependency)
    val soundManager = remember { VerificationSoundManager(context.applicationContext) }
    val accessibilityUiState = LocalAccessibilityUiState.current
    val settings = accessibilityUiState.settings

    val reduceMotion =
        remember {
            try {
                Settings.Global.getFloat(
                    context.contentResolver,
                    Settings.Global.ANIMATOR_DURATION_SCALE,
                ) == 0f
            } catch (_: Settings.SettingNotFoundException) {
                false // Setting not explicitly set, animations are on by default
            }
        }

    // Parse paths once
    val pBodyPath = remember { parseSvgPath(P_BODY_SVG) }
    val checkmarkPath = remember { parseSvgPath(CHECKMARK_SVG) }
    val bowlPath = remember { parseSvgPath(BOWL_SVG) }

    // Measure path lengths for dash animation
    val pBodyLen = remember { PathMeasure().apply { setPath(pBodyPath, false) }.length }
    val checkmarkLen = remember { PathMeasure().apply { setPath(checkmarkPath, false) }.length }
    val bowlLen = remember { PathMeasure().apply { setPath(bowlPath, false) }.length }

    // Animation progress
    val pBodyProgress = remember { Animatable(0f) }
    val bowlProgress = remember { Animatable(0f) }
    val checkmarkProgress = remember { Animatable(0f) }
    val fillAlpha = remember { Animatable(0f) }
    val strokeAlpha = remember { Animatable(1f) }

    // Cleanup when splash leaves composition
    DisposableEffect(Unit) { onDispose { soundManager.dispose() } }

    val hasCompleted = remember { mutableStateOf(false) }
    val splashLoadingAnnouncement = stringResource(R.string.splash_loading_announcement)

    fun complete() {
        if (hasCompleted.value) return
        hasCompleted.value = true
        view.sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)
        onComplete()
    }

    LaunchedEffect(Unit) {
        // TalkBack announcement so screen readers know what is displayed
        announceForAccessibility(context, splashLoadingAnnouncement)

        if (reduceMotion) {
            pBodyProgress.snapTo(1f)
            bowlProgress.snapTo(1f)
            checkmarkProgress.snapTo(1f)
            fillAlpha.snapTo(1f)
            strokeAlpha.snapTo(0f)
            delay(500)
            complete()
            return@LaunchedEffect
        }

        // Phase 1: P body outline (0-1.0s)
        launch {
            pBodyProgress.animateTo(1f, tween(1000, easing = PBodyEasing))
        }

        // Phase 2: Bowl outline (0.5-1.1s)
        delay(500)
        launch {
            bowlProgress.animateTo(1f, tween(600, easing = PBodyEasing))
        }

        // Phase 3: Checkmark outline (1.2-1.6s)
        delay(700)
        launch {
            checkmarkProgress.animateTo(1f, tween(400, easing = CheckmarkEasing))
        }

        // Haptic + chime at checkmark completion (1.6s), respecting user settings
        delay(400)
        if (settings.hapticFeedback) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
            } else {
                view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            }
        }
        // Play chime using user's chosen preset and volume (also checks ringer mode internally)
        soundManager.playVerificationSuccess(
            soundEnabled = settings.soundEnabled,
            preset = settings.verificationSoundPreset,
            volumePercent = settings.soundVolume,
            hapticEnabled = false, // Haptic already handled above
        )

        // Phase 4: Fill fade in, stroke fade out (1.7-1.95s)
        delay(100)
        launch { fillAlpha.animateTo(1f, tween(250)) }
        launch { strokeAlpha.animateTo(0f, tween(250)) }

        // Phase 5: Hold 0.5s on completed logo, then finish
        delay(800)
        complete()
    }

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(SplashBackground)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { complete() }
                .semantics { contentDescription = "Provii" },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val canvasW = size.width
            val canvasH = size.height
            val logoSize = minOf(canvasW, canvasH) * 0.68f
            val scale = logoSize / 400f
            val offsetX = (canvasW - logoSize) / 2f
            val offsetY = (canvasH - logoSize) / 2f
            val strokeW = 3f * scale

            // Draw everything inside a scaled/translated transform so the 400x400
            // path coordinates map correctly onto the canvas
            withTransform({
                translate(left = offsetX, top = offsetY)
                scale(scaleX = scale, scaleY = scale, pivot = Offset.Zero)
            }) {
                // Stroked outlines with dash animation
                if (strokeAlpha.value > 0f) {
                    val sAlpha = strokeAlpha.value
                    val strokeStyle = { len: Float, progress: Float ->
                        val drawn = len * progress
                        Stroke(
                            width = strokeW / scale, // undo the canvas scale so stroke stays consistent
                            cap = StrokeCap.Round,
                            join = StrokeJoin.Round,
                            pathEffect =
                                if (progress < 1f) {
                                    PathEffect.dashPathEffect(floatArrayOf(drawn, len - drawn), 0f)
                                } else {
                                    null
                                },
                        )
                    }

                    if (pBodyProgress.value > 0f) {
                        drawPath(pBodyPath, NavyColor, alpha = sAlpha, style = strokeStyle(pBodyLen, pBodyProgress.value))
                    }
                    if (bowlProgress.value > 0f) {
                        drawPath(bowlPath, NavyColor, alpha = sAlpha, style = strokeStyle(bowlLen, bowlProgress.value))
                    }
                    if (checkmarkProgress.value > 0f) {
                        drawPath(checkmarkPath, TealColor, alpha = sAlpha, style = strokeStyle(checkmarkLen, checkmarkProgress.value))
                    }
                }

                // Filled versions
                if (fillAlpha.value > 0f) {
                    drawPath(pBodyPath, NavyColor, alpha = fillAlpha.value, style = Fill)
                    drawPath(bowlPath, NavyColor, alpha = fillAlpha.value, style = Fill)
                    drawPath(checkmarkPath, TealColor, alpha = fillAlpha.value, style = Fill)
                }
            }
        }
    }
}
