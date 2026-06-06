// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FamilyRestroom
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.RocketLaunch
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.provii.wallet.R

/**
 * Single walkthrough page composable. Renders a decorative icon at the top,
 * a heading marked with semantics heading trait, and body text. Content is
 * wrapped in a verticalScroll so that scaled text at 200% font size remains
 * fully scrollable per WCAG 1.4.4.
 */
@Composable
fun WalkthroughPage(
    icon: ImageVector,
    titleResId: Int,
    bodyResId: Int,
    headingFocusRequester: FocusRequester? = null,
) {
    val scrollState = rememberScrollState()

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(horizontal = 32.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Decorative icon in gradient circle
        Box(
            modifier =
                Modifier
                    .size(100.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors =
                                listOf(
                                    MaterialTheme.colorScheme.primaryContainer,
                                    MaterialTheme.colorScheme.secondaryContainer,
                                ),
                        ),
                    ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null, // Decorative: adjacent heading provides meaning
                modifier = Modifier.size(52.dp),
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Heading with accessibility heading trait (WCAG 1.3.1)
        // WCAG 2.4.3: Focus directed here on page change by WalkthroughScreen
        Text(
            text = stringResource(titleResId),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier =
                Modifier
                    .semantics { heading() }
                    .then(
                        if (headingFocusRequester != null) {
                            Modifier.focusRequester(headingFocusRequester).focusable()
                        } else {
                            Modifier
                        },
                    ),
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Body text
        Text(
            text = stringResource(bodyResId),
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 8.dp),
        )
    }
}

/**
 * Returns the icon for a given walkthrough page index.
 */
internal fun walkthroughPageIcon(pageIndex: Int): ImageVector =
    when (pageIndex) {
        0 -> Icons.Default.Shield
        1 -> Icons.Default.Verified
        2 -> Icons.Default.FamilyRestroom
        3 -> Icons.Default.Lock
        4 -> Icons.Default.RocketLaunch
        else -> Icons.Default.Shield
    }

/**
 * Returns the heading string resource for a given walkthrough page index.
 */
internal fun walkthroughHeadingRes(pageIndex: Int): Int =
    when (pageIndex) {
        0 -> R.string.walkthrough_page1_heading
        1 -> R.string.walkthrough_page2_heading
        2 -> R.string.walkthrough_page3_heading
        3 -> R.string.walkthrough_page4_heading
        4 -> R.string.walkthrough_page5_heading
        else -> R.string.walkthrough_page1_heading
    }

/**
 * Returns the body string resource for a given walkthrough page index.
 */
internal fun walkthroughBodyRes(pageIndex: Int): Int =
    when (pageIndex) {
        0 -> R.string.walkthrough_page1_body
        1 -> R.string.walkthrough_page2_body
        2 -> R.string.walkthrough_page3_body
        3 -> R.string.walkthrough_page4_body
        4 -> R.string.walkthrough_page5_body
        else -> R.string.walkthrough_page1_body
    }
