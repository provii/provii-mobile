// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleSecondaryButton
import kotlinx.coroutines.launch

private const val WALKTHROUGH_PAGE_COUNT = 5

/**
 * Five page swipeable walkthrough shown once after initial setup completes.
 * Explains what credentials are, how to get them, managed credentials for
 * children, how verification works, and presents the user with a "Get Started"
 * call to action.
 *
 * WCAG compliance:
 * - 2.5.1 (Pointer Gestures): Swipe has button alternatives (Next/Back).
 * - 2.5.8 (Target Size): All buttons meet 48dp minimum via accessible components.
 * - 2.4.1 (Bypass Blocks): Skip button always visible, never traps user.
 * - 4.1.3 (Status Messages): Page indicator uses liveRegion for TalkBack.
 * - 2.3.3 (Animation from Interactions): Respects reduceMotion preference.
 * - 1.3.1 (Info and Relationships): Each page heading uses semantics heading().
 * - 1.4.4 (Resize Text): Semantic typography, verticalScroll on pages.
 */
@Composable
fun WalkthroughScreen(
    onComplete: () -> Unit,
) {
    val pagerState = rememberPagerState(pageCount = { WALKTHROUGH_PAGE_COUNT })
    val coroutineScope = rememberCoroutineScope()

    val accessibilityUiState = LocalAccessibilityUiState.current

    // WCAG 2.4.3: Move focus to heading on page change so TalkBack reads the new page
    val headingFocusRequester = remember { FocusRequester() }
    // Use settledPage (not currentPage). settledPage only updates AFTER animation completes,
    // preventing cascading recompositions during animated transitions.
    val settledPage = pagerState.settledPage
    LaunchedEffect(settledPage) {
        kotlinx.coroutines.delay(100)
        try {
            headingFocusRequester.requestFocus()
        } catch (_: Exception) {
        }
    }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .systemBarsPadding(),
    ) {
        // Skip button row - WCAG 2.4.1: Always visible, never traps user
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.End,
        ) {
            TextButton(
                onClick = onComplete,
                modifier = Modifier.heightIn(min = 48.dp),
            ) {
                Text(
                    text = stringResource(R.string.walkthrough_skip),
                    style = MaterialTheme.typography.labelLarge,
                )
            }
        }

        // Pager content. Swipe disabled, navigation via buttons only.
        // Swipe was unreliable (jumping multiple pages despite PagerSnapDistance).
        // Buttons are the primary navigation per WCAG 2.5.1.
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
            userScrollEnabled = false,
        ) { page ->
            WalkthroughPage(
                icon = walkthroughPageIcon(page),
                titleResId = walkthroughHeadingRes(page),
                bodyResId = walkthroughBodyRes(page),
                headingFocusRequester = headingFocusRequester,
            )
        }

        // Page indicators and navigation
        Column(
            modifier = Modifier.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Dot indicators - merged semantics with live region for TalkBack
            // Non-interactive, using size + colour difference for active state
            val pageIndicatorText =
                stringResource(
                    R.string.walkthrough_page_indicator,
                    settledPage + 1,
                    WALKTHROUGH_PAGE_COUNT,
                )
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier =
                    Modifier.semantics(mergeDescendants = true) {
                        contentDescription = pageIndicatorText
                        liveRegion = LiveRegionMode.Polite
                    },
            ) {
                repeat(WALKTHROUGH_PAGE_COUNT) { index ->
                    Box(
                        modifier =
                            Modifier
                                .size(if (index == settledPage) 10.dp else 8.dp)
                                .clip(CircleShape)
                                .background(
                                    if (index == settledPage) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        MaterialTheme.colorScheme.outlineVariant
                                    },
                                ),
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Navigation buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Back button (pages 2-5)
                if (settledPage > 0) {
                    AccessibleSecondaryButton(
                        text = stringResource(R.string.walkthrough_back),
                        modifier = Modifier.weight(1f),
                        onClick = {
                            val targetPage = (settledPage - 1).coerceAtLeast(0)
                            coroutineScope.launch {
                                pagerState.scrollToPage(targetPage)
                            }
                        },
                    )
                }

                // Next / Get Started button
                AccessiblePrimaryButton(
                    text =
                        if (settledPage < WALKTHROUGH_PAGE_COUNT - 1) {
                            stringResource(R.string.walkthrough_next)
                        } else {
                            stringResource(R.string.walkthrough_get_started)
                        },
                    modifier = Modifier.weight(1f),
                    onClick = {
                        val currentPage = settledPage
                        if (currentPage < WALKTHROUGH_PAGE_COUNT - 1) {
                            val targetPage = currentPage + 1
                            coroutineScope.launch {
                                pagerState.scrollToPage(targetPage)
                            }
                        } else {
                            onComplete()
                        }
                    },
                )
            }
        }
    }
}
