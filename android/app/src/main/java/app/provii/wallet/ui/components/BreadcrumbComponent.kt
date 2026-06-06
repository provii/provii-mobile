// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState

/**
 * Breadcrumb navigation component providing location context within the app hierarchy.
 * Satisfies WCAG 2.4.8 (AAA) for location awareness and WCAG 1.4.10 (AA) for reflow
 * by using [FlowRow] to prevent horizontal scrolling. Auto-mirrored separator icons
 * support RTL layouts.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun Breadcrumb(
    items: List<BreadcrumbItem>,
    onNavigate: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current
    val locationDesc = stringResource(R.string.accessibility_breadcrumb_location_description, items.joinToString(" > ") { it.title })
    FlowRow(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .semantics {
                    contentDescription = locationDesc
                },
        horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.Start),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        maxItemsInEachRow = Int.MAX_VALUE,
    ) {
        items.forEachIndexed { index, item ->
            if (index > 0) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = stringResource(R.string.accessibility_breadcrumb_separator_description),
                    modifier =
                        Modifier
                            .size(16.dp)
                            .align(Alignment.CenterVertically),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (index < items.lastIndex) {
                // Clickable breadcrumb items
                TextButton(
                    onClick = { onNavigate(index) },
                    modifier =
                        Modifier
                            .align(Alignment.CenterVertically)
                            .heightIn(min = accessibilityUiState.minTouchTarget),
                ) {
                    Text(
                        text = item.title,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            } else {
                // Current page (non-clickable)
                val currentPageDesc = stringResource(R.string.accessibility_breadcrumb_current_page_description, item.title)
                Text(
                    text = item.title,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier =
                        Modifier
                            .padding(horizontal = 12.dp)
                            .align(Alignment.CenterVertically)
                            .semantics {
                                contentDescription = currentPageDesc
                            },
                )
            }
        }
    }
}

data class BreadcrumbItem(val title: String)
