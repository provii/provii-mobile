// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.preview

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import app.provii.wallet.ui.components.DirectionalIcon
import app.provii.wallet.ui.theme.ProviiWalletTheme
import app.provii.wallet.ui.theme.focusIndicator
import app.provii.wallet.utils.ForceRtlLayout
import app.provii.wallet.utils.ForceLtrLayout

/**
 * Compose Preview composables that demonstrate right-to-left layout behaviour for
 * directional icons, navigation cards, and text rendering across Arabic, Farsi,
 * Hebrew, and Urdu locales. Each preview renders an LTR and RTL variant side by side
 * to verify that AutoMirrored icons and [DirectionalIcon] adapt correctly.
 */

/**
 * Preview composables demonstrating RTL (Right-to-Left) layout support
 *
 * These previews show how directional icons and layouts adapt to RTL languages
 * like Arabic, Farsi, Hebrew, etc.
 */

/**
 * Example card component demonstrating proper RTL icon usage
 */
@Composable
private fun NavigationCard(
    title: String,
    description: String,
    onClick: () -> Unit = {},
) {
    Card(
        onClick = onClick,
        modifier =
            Modifier
                .fillMaxWidth()
                .focusIndicator(),
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant,
            ),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.Help,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            // This arrow will automatically flip in RTL layouts
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "Navigate",
            )
        }
    }
}

/**
 * Example showing navigation arrows in both directions
 */
@Composable
private fun NavigationArrows() {
    val layoutDirection = LocalLayoutDirection.current
    val directionLabel = if (layoutDirection == LayoutDirection.Rtl) "RTL" else "LTR"

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "Current Layout: $directionLabel",
            style = MaterialTheme.typography.headlineSmall,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(
                onClick = {},
                modifier =
                    Modifier
                        .heightIn(min = 48.dp)
                        .focusIndicator(),
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    modifier = Modifier.size(24.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Back")
            }

            TextButton(
                onClick = {},
                modifier =
                    Modifier
                        .heightIn(min = 48.dp)
                        .focusIndicator(),
            ) {
                Text("Forward")
                Spacer(modifier = Modifier.width(8.dp))
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Forward",
                    modifier = Modifier.size(24.dp),
                )
            }
        }

        Text(
            text = "Note: In RTL mode, 'Back' points right and 'Forward' points left",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/**
 * Example demonstrating DirectionalIcon component
 */
@Composable
private fun DirectionalIconExample() {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "DirectionalIcon Component",
            style = MaterialTheme.typography.titleLarge,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                DirectionalIcon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Custom Forward",
                    modifier = Modifier.size(48.dp),
                )
                Text("AutoMirrored", style = MaterialTheme.typography.bodySmall)
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                DirectionalIcon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Custom Back",
                    modifier = Modifier.size(48.dp),
                )
                Text("AutoMirrored", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

// ============================================================================
// PREVIEW FUNCTIONS - LTR (Left-to-Right)
// ============================================================================

@Preview(
    name = "Navigation Card - LTR",
    showBackground = true,
    locale = "en",
)
@Composable
private fun NavigationCardLtrPreview() {
    ProviiWalletTheme {
        ForceLtrLayout {
            Surface {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    NavigationCard(
                        title = "Settings",
                        description = "Configure app preferences",
                    )
                    NavigationCard(
                        title = "Help & Support",
                        description = "Get assistance and resources",
                    )
                }
            }
        }
    }
}

@Preview(
    name = "Navigation Arrows - LTR",
    showBackground = true,
    locale = "en",
)
@Composable
private fun NavigationArrowsLtrPreview() {
    ProviiWalletTheme {
        ForceLtrLayout {
            Surface {
                NavigationArrows()
            }
        }
    }
}

@Preview(
    name = "DirectionalIcon - LTR",
    showBackground = true,
    locale = "en",
)
@Composable
private fun DirectionalIconLtrPreview() {
    ProviiWalletTheme {
        ForceLtrLayout {
            Surface {
                DirectionalIconExample()
            }
        }
    }
}

// ============================================================================
// PREVIEW FUNCTIONS - RTL (Right-to-Left)
// ============================================================================

@Preview(
    name = "Navigation Card - RTL (Arabic)",
    showBackground = true,
    locale = "ar",
)
@Composable
private fun NavigationCardRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Surface {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    NavigationCard(
                        title = "الإعدادات",
                        description = "تكوين تفضيلات التطبيق",
                    )
                    NavigationCard(
                        title = "المساعدة والدعم",
                        description = "احصل على المساعدة والموارد",
                    )
                }
            }
        }
    }
}

@Preview(
    name = "Navigation Arrows - RTL (Arabic)",
    showBackground = true,
    locale = "ar",
)
@Composable
private fun NavigationArrowsRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Surface {
                NavigationArrows()
            }
        }
    }
}

@Preview(
    name = "DirectionalIcon - RTL (Arabic)",
    showBackground = true,
    locale = "ar",
)
@Composable
private fun DirectionalIconRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Surface {
                DirectionalIconExample()
            }
        }
    }
}

// ============================================================================
// SIDE-BY-SIDE COMPARISON PREVIEWS
// ============================================================================

@Preview(
    name = "LTR vs RTL Comparison",
    showBackground = true,
    widthDp = 800,
)
@Composable
private fun LtrRtlComparisonPreview() {
    ProviiWalletTheme {
        Row(modifier = Modifier.fillMaxWidth()) {
            // LTR side
            ForceLtrLayout {
                Surface(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Text(
                            "LTR (English)",
                            style = MaterialTheme.typography.titleSmall,
                            modifier = Modifier.padding(bottom = 8.dp),
                        )
                        NavigationCard(
                            title = "Settings",
                            description = "Configure preferences",
                        )
                    }
                }
            }

            // RTL side
            ForceRtlLayout {
                Surface(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Text(
                            "RTL (العربية)",
                            style = MaterialTheme.typography.titleSmall,
                            modifier = Modifier.padding(bottom = 8.dp),
                        )
                        NavigationCard(
                            title = "الإعدادات",
                            description = "تكوين التفضيلات",
                        )
                    }
                }
            }
        }
    }
}

/**
 * Additional RTL language previews
 */

@Preview(
    name = "Navigation Card - RTL (Farsi)",
    showBackground = true,
    locale = "fa",
)
@Composable
private fun NavigationCardFarsiPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Surface {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    NavigationCard(
                        title = "تنظیمات",
                        description = "پیکربندی ترجیحات برنامه",
                    )
                }
            }
        }
    }
}

@Preview(
    name = "Navigation Card - RTL (Hebrew)",
    showBackground = true,
    locale = "he",
)
@Composable
private fun NavigationCardHebrewPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Surface {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    NavigationCard(
                        title = "הגדרות",
                        description = "הגדר העדפות אפליקציה",
                    )
                }
            }
        }
    }
}

@Preview(
    name = "Navigation Card - RTL (Urdu)",
    showBackground = true,
    locale = "ur",
)
@Composable
private fun NavigationCardUrduPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Surface {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    NavigationCard(
                        title = "ترتیبات",
                        description = "ایپ کی ترجیحات کو ترتیب دیں",
                    )
                }
            }
        }
    }
}
