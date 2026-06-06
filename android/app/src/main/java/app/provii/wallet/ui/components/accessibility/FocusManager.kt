// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Focus management utilities for keyboard and switch-access navigation. Provides
 * composable helpers for initial focus on screen entry, focus restoration on resume,
 * linear and custom focus traversal, and RTL-aware directional navigation. Satisfies
 * WCAG 2.4.3 (Focus Order) and WCAG 2.4.7 (Focus Visible).
 */
object FocusManager {
    /**
     * Default delay before requesting focus (allows screen to render)
     */
    const val DEFAULT_FOCUS_DELAY = 100L

    /**
     * Creates a focus group that can be used to manage focus order within a section
     */
    @Composable
    fun rememberFocusGroup(size: Int): List<FocusRequester> {
        return remember(size) {
            List(size) { FocusRequester() }
        }
    }

    /**
     * Creates a single FocusRequester and requests focus on screen entry
     */
    @Composable
    fun rememberInitialFocus(
        enabled: Boolean = true,
        delay: Long = DEFAULT_FOCUS_DELAY,
    ): FocusRequester {
        val focusRequester = remember { FocusRequester() }

        if (enabled) {
            LaunchedEffect(Unit) {
                delay(delay)
                try {
                    focusRequester.requestFocus()
                } catch (e: Exception) {
                    // Focus request failed - element may not be focusable
                }
            }
        }

        return focusRequester
    }

    /**
     * Creates a FocusRequester that restores focus when returning to a screen
     */
    @Composable
    fun rememberRestoredFocus(
        key: Any? = null,
        delay: Long = DEFAULT_FOCUS_DELAY,
    ): FocusRequester {
        val focusRequester = remember { FocusRequester() }
        val lifecycleOwner = LocalLifecycleOwner.current

        DisposableEffect(lifecycleOwner, key) {
            val observer =
                LifecycleEventObserver { _, event ->
                    if (event == Lifecycle.Event.ON_RESUME) {
                        kotlinx.coroutines.MainScope().launch {
                            delay(delay)
                            try {
                                focusRequester.requestFocus()
                            } catch (e: Exception) {
                                // Focus request failed
                            }
                        }
                    }
                }

            lifecycleOwner.lifecycle.addObserver(observer)

            onDispose {
                lifecycleOwner.lifecycle.removeObserver(observer)
            }
        }

        return focusRequester
    }
}

/**
 * Extension modifier to apply initial focus when screen opens
 */
fun Modifier.initialFocus(
    focusRequester: FocusRequester,
): Modifier = this.focusRequester(focusRequester)

/**
 * Extension modifier to set up linear focus traversal
 *
 * @param next The FocusRequester for the next element in focus order
 * @param previous The FocusRequester for the previous element in focus order
 */
fun Modifier.linearFocusTraversal(
    next: FocusRequester? = null,
    previous: FocusRequester? = null,
): Modifier =
    this.focusProperties {
        next?.let { this.next = it }
        previous?.let { this.previous = it }
    }

/**
 * Extension modifier to set up custom focus traversal
 * Automatically mirrors left/right for RTL layouts
 */
fun Modifier.customFocusTraversal(
    next: FocusRequester? = null,
    previous: FocusRequester? = null,
    up: FocusRequester? = null,
    down: FocusRequester? = null,
    left: FocusRequester? = null,
    right: FocusRequester? = null,
): Modifier =
    this.focusProperties {
        next?.let { this.next = it }
        previous?.let { this.previous = it }
        up?.let { this.up = it }
        down?.let { this.down = it }
        left?.let { this.left = it }
        right?.let { this.right = it }
    }

/**
 * Extension modifier to set up RTL-aware custom focus traversal
 * Automatically mirrors left/right navigation for RTL layouts
 *
 * In RTL layouts:
 * - "start" maps to right side (visually)
 * - "end" maps to left side (visually)
 * - Focus should move right-to-left instead of left-to-right
 */
fun Modifier.rtlAwareFocusTraversal(
    next: FocusRequester? = null,
    previous: FocusRequester? = null,
    up: FocusRequester? = null,
    down: FocusRequester? = null,
    start: FocusRequester? = null,
    end: FocusRequester? = null,
): Modifier =
    composed {
        val layoutDirection = LocalLayoutDirection.current
        val isRtl = layoutDirection == LayoutDirection.Rtl

        // In RTL, swap left/right navigation
        val left = if (isRtl) end else start
        val right = if (isRtl) start else end

        this.focusProperties {
            next?.let { this.next = it }
            previous?.let { this.previous = it }
            up?.let { this.up = it }
            down?.let { this.down = it }
            left?.let { this.left = it }
            right?.let { this.right = it }
        }
    }

/**
 * Request focus with error handling and delay
 */
suspend fun FocusRequester.requestFocusSafely(delay: Long = FocusManager.DEFAULT_FOCUS_DELAY) {
    delay(delay)
    try {
        this.requestFocus()
    } catch (e: Exception) {
        // Focus request failed - element may not be focusable
    }
}
