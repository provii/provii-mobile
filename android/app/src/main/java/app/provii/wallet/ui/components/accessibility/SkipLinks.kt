// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState

/**
 * Skip-link navigation for keyboard and TalkBack users, satisfying WCAG 2.4.1 (Bypass
 * Blocks). Provides a [SkipLinksBar] that renders focus-visible buttons allowing users
 * to jump directly to named content sections, plus [SkipLinkAnchor] markers placed at
 * each target location. The bar is only visible when a button has focus or TalkBack is
 * active.
 */

/**
 * Skip link target that can receive focus from a SkipLinksBar.
 * Place this at the beginning of main content sections.
 */
data class SkipLinkTarget(
    val id: String,
    val labelResId: Int,
    val focusRequester: FocusRequester,
)

/**
 * A composable that provides skip links for keyboard navigation.
 * This helps users with screen readers or keyboard-only navigation
 * quickly jump to main content areas without tabbing through every element.
 *
 * WCAG 2.4.1: Bypass Blocks - Provide mechanism to bypass repeated content.
 *
 * The skip links are only visible when focused (keyboard navigation).
 */
@Composable
fun SkipLinksBar(
    targets: List<SkipLinkTarget>,
    modifier: Modifier = Modifier,
) {
    val uiState = LocalAccessibilityUiState.current

    // Skip links must be available for keyboard navigation (WCAG 2.4.1)
    if (targets.isEmpty()) return

    var isAnyButtonFocused by remember { mutableStateOf(false) }

    Box(
        modifier =
            modifier
                .fillMaxWidth()
                .height(if (isAnyButtonFocused || uiState.isTalkBackEnabled) 48.dp else 0.dp)
                .background(
                    if (isAnyButtonFocused || uiState.isTalkBackEnabled) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.background
                    },
                ),
    ) {
        // Render buttons even when height is 0 so they can receive focus
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            targets.forEachIndexed { index, target ->
                SkipLinkButton(
                    labelResId = target.labelResId,
                    onClick = { target.focusRequester.requestFocus() },
                    onFocusChanged = { hasFocus ->
                        isAnyButtonFocused = hasFocus
                    },
                )
                if (index < targets.lastIndex) {
                    Spacer(modifier = Modifier.width(8.dp))
                }
            }
        }
    }
}

@Composable
private fun SkipLinkButton(
    labelResId: Int,
    onClick: () -> Unit,
    onFocusChanged: (Boolean) -> Unit,
) {
    val label = stringResource(labelResId)
    val skipToContentDesc = stringResource(R.string.accessibility_skip_to, label)

    TextButton(
        onClick = onClick,
        modifier =
            Modifier
                .semantics {
                    role = Role.Button
                    contentDescription = skipToContentDesc
                }
                .onFocusChanged { focusState ->
                    onFocusChanged(focusState.hasFocus)
                }
                .background(
                    MaterialTheme.colorScheme.primary,
                    RoundedCornerShape(4.dp),
                ),
    ) {
        Text(
            text = skipToContentDesc,
            color = MaterialTheme.colorScheme.onPrimary,
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

/**
 * Marker composable to place at the beginning of a main content section.
 * This provides a focusable target for skip links.
 */
@Composable
fun SkipLinkAnchor(
    focusRequester: FocusRequester,
    contentDescription: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier =
            modifier
                .focusRequester(focusRequester)
                .focusable()
                .semantics {
                    this.contentDescription = contentDescription
                },
    )
}

/**
 * Creates and remembers a SkipLinkTarget with its FocusRequester.
 */
@Composable
fun rememberSkipLinkTarget(
    id: String,
    labelResId: Int,
): SkipLinkTarget {
    val focusRequester = remember { FocusRequester() }
    return remember(id, labelResId) {
        SkipLinkTarget(id, labelResId, focusRequester)
    }
}
