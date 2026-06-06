// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight

/**
 * Section header composable that enforces a heading hierarchy for screen reader
 * navigation (WCAG 1.3.1, 2.4.6). Maps level 1/2/3 to headlineLarge, headlineMedium,
 * and headlineSmall respectively, with the semantics [heading] trait applied. Matches
 * the iOS AccessibleSectionHeader for cross-platform consistency.
 *
 * @param text The heading text to display
 * @param level Heading level: 1 (h1), 2 (h2), or 3 (h3). Defaults to 2.
 * @param modifier Optional Modifier for layout customisation
 */
@Composable
fun AccessibleSectionHeader(
    text: String,
    level: Int = 2,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style =
            when (level) {
                1 -> MaterialTheme.typography.headlineLarge
                2 -> MaterialTheme.typography.headlineMedium
                else -> MaterialTheme.typography.headlineSmall
            },
        fontWeight = FontWeight.SemiBold,
        modifier =
            modifier.semantics {
                heading()
                contentDescription = text
            },
    )
}
