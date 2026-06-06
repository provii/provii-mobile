// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.theme.ProviiWalletTheme
import app.provii.wallet.ui.theme.focusIndicator
import app.provii.wallet.utils.ForceRtlLayout

/**
 * Reference implementations of RTL-aware UI patterns used throughout Provii Wallet.
 * Demonstrates auto-mirrored icons, start/end padding, directional navigation, and
 * proper text alignment for right-to-left locales. Includes paired LTR/RTL preview
 * composables for visual validation during development.
 */

/**
 * Step indicator card with directional arrow (RTL-aware)
 *
 * This component demonstrates:
 * - Using AutoMirrored icons for directional indicators
 * - Proper padding with start/end instead of left/right
 * - RTL-aware text alignment
 *
 * @param stepNumber The current step number
 * @param totalSteps Total number of steps
 * @param title Step title
 * @param description Step description
 * @param isCompleted Whether this step is completed
 * @param onNext Callback for next button
 * @param onBack Callback for back button
 */
@Composable
fun RtlAwareStepCard(
    stepNumber: Int,
    totalSteps: Int,
    title: String,
    description: String,
    isCompleted: Boolean = false,
    onNext: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current

    Card(
        modifier = modifier.fillMaxWidth(),
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant,
            ),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
        ) {
            // Step indicator
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Step $stepNumber of $totalSteps",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
                if (isCompleted) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = "Completed",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.padding(4.dp))

            // Title
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                textAlign = TextAlign.Start, // RTL-aware alignment
            )

            Spacer(modifier = Modifier.padding(4.dp))

            // Description
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Start, // RTL-aware alignment
            )

            Spacer(modifier = Modifier.padding(8.dp))

            // Navigation buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                // Back button (will be on start in LTR, end in RTL)
                if (onBack != null) {
                    TextButton(
                        onClick = onBack,
                        modifier =
                            Modifier
                                .heightIn(min = accessibilityUiState.minTouchTarget)
                                .focusIndicator(),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Back")
                    }
                } else {
                    Spacer(modifier = Modifier) // Maintain layout
                }

                // Next button (will be on end in LTR, start in RTL)
                if (onNext != null) {
                    TextButton(
                        onClick = onNext,
                        modifier =
                            Modifier
                                .heightIn(min = accessibilityUiState.minTouchTarget)
                                .focusIndicator(),
                    ) {
                        Text("Next")
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
    }
}

/**
 * Settings row with chevron indicator (RTL-aware)
 *
 * This component demonstrates:
 * - Using AutoMirrored chevron icons
 * - Proper icon positioning based on layout direction
 * - Start/end padding
 *
 * @param icon Leading icon
 * @param title Setting title
 * @param subtitle Optional subtitle
 * @param onClick Callback when row is clicked
 */
@Composable
fun RtlAwareSettingsRow(
    icon: @Composable () -> Unit,
    title: String,
    subtitle: String? = null,
    onClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    Card(
        onClick = onClick,
        modifier =
            modifier
                .fillMaxWidth()
                .focusIndicator(),
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface,
            ),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Start, // RTL-aware
        ) {
            // Leading icon
            icon()

            Spacer(modifier = Modifier.width(16.dp))

            // Text content
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Start,
                )
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Start,
                    )
                }
            }

            // Trailing chevron (auto-mirrors in RTL)
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "Navigate",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * Breadcrumb navigation (RTL-aware)
 *
 * This component demonstrates:
 * - Using AutoMirrored separator icons
 * - Proper flow direction in RTL
 * - Clickable navigation items
 *
 * @param items List of breadcrumb items
 * @param onNavigate Callback when breadcrumb is clicked
 */
@Composable
fun RtlAwareBreadcrumb(
    items: List<String>,
    onNavigate: (Int) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current

    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEachIndexed { index, item ->
            // Add separator before items except the first
            if (index > 0) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = "Separator",
                    modifier =
                        Modifier
                            .size(16.dp)
                            .padding(horizontal = 4.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Breadcrumb item
            if (index < items.lastIndex) {
                // Clickable items
                TextButton(
                    onClick = { onNavigate(index) },
                    modifier =
                        Modifier
                            .heightIn(min = accessibilityUiState.minTouchTarget)
                            .focusIndicator(),
                ) {
                    Text(
                        text = item,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            } else {
                // Current page (non-clickable)
                Text(
                    text = item,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 12.dp),
                )
            }
        }
    }
}

/**
 * Info banner with icon (RTL-aware)
 *
 * This component demonstrates:
 * - Non-directional icon (doesn't need mirroring)
 * - Proper text alignment
 * - Start/end padding
 */
@Composable
fun RtlAwareInfoBanner(
    message: String,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors =
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer,
            ),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.Start,
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                modifier = Modifier.size(24.dp),
            )

            Spacer(modifier = Modifier.width(12.dp))

            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
                textAlign = TextAlign.Start,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/**
 * Navigation header with back button (RTL-aware)
 *
 * This component demonstrates:
 * - AutoMirrored back arrow
 * - Proper positioning in RTL
 */
@Composable
fun RtlAwareNavigationHeader(
    title: String,
    onBackClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val accessibilityUiState = LocalAccessibilityUiState.current

    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Start,
    ) {
        IconButton(
            onClick = onBackClick,
            modifier =
                Modifier
                    .size(accessibilityUiState.minTouchTarget)
                    .focusIndicator(),
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Start,
        )
    }
}

// ============================================================================
// PREVIEW FUNCTIONS
// ============================================================================

@Preview(name = "Step Card - LTR", showBackground = true)
@Composable
private fun RtlAwareStepCardLtrPreview() {
    ProviiWalletTheme {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            RtlAwareStepCard(
                stepNumber = 2,
                totalSteps = 4,
                title = "Scan QR Code",
                description = "Point your camera at the QR code to get your credential",
                onNext = {},
                onBack = {},
            )
        }
    }
}

@Preview(name = "Step Card - RTL", showBackground = true)
@Composable
private fun RtlAwareStepCardRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                RtlAwareStepCard(
                    stepNumber = 2,
                    totalSteps = 4,
                    title = "امسح رمز الاستجابة السريعة",
                    description = "قم بتوجيه الكاميرا نحو رمز الاستجابة السريعة للحصول على بيانات الاعتماد",
                    onNext = {},
                    onBack = {},
                )
            }
        }
    }
}

@Preview(name = "Settings Row - LTR", showBackground = true)
@Composable
private fun RtlAwareSettingsRowLtrPreview() {
    ProviiWalletTheme {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            RtlAwareSettingsRow(
                icon = {
                    Icon(
                        Icons.Default.Info,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                },
                title = "Language",
                subtitle = "English (United States)",
            )
        }
    }
}

@Preview(name = "Settings Row - RTL", showBackground = true)
@Composable
private fun RtlAwareSettingsRowRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                RtlAwareSettingsRow(
                    icon = {
                        Icon(
                            Icons.Default.Info,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    },
                    title = "اللغة",
                    subtitle = "العربية",
                )
            }
        }
    }
}

@Preview(name = "Breadcrumb - LTR", showBackground = true)
@Composable
private fun RtlAwareBreadcrumbLtrPreview() {
    ProviiWalletTheme {
        RtlAwareBreadcrumb(
            items = listOf("Home", "Settings", "Language"),
        )
    }
}

@Preview(name = "Breadcrumb - RTL", showBackground = true)
@Composable
private fun RtlAwareBreadcrumbRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            RtlAwareBreadcrumb(
                items = listOf("الرئيسية", "الإعدادات", "اللغة"),
            )
        }
    }
}

@Preview(name = "Info Banner - LTR", showBackground = true)
@Composable
private fun RtlAwareInfoBannerLtrPreview() {
    ProviiWalletTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            RtlAwareInfoBanner(
                message = "Your credential is stored securely on your device using zero knowledge proofs.",
            )
        }
    }
}

@Preview(name = "Info Banner - RTL", showBackground = true)
@Composable
private fun RtlAwareInfoBannerRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            Column(modifier = Modifier.padding(16.dp)) {
                RtlAwareInfoBanner(
                    message = "يتم تخزين بيانات الاعتماد الخاصة بك بشكل آمن على جهازك باستخدام إثباتات المعرفة الصفرية.",
                )
            }
        }
    }
}

@Preview(name = "Navigation Header - LTR", showBackground = true)
@Composable
private fun RtlAwareNavigationHeaderLtrPreview() {
    ProviiWalletTheme {
        RtlAwareNavigationHeader(title = "Settings")
    }
}

@Preview(name = "Navigation Header - RTL", showBackground = true)
@Composable
private fun RtlAwareNavigationHeaderRtlPreview() {
    ProviiWalletTheme {
        ForceRtlLayout {
            RtlAwareNavigationHeader(title = "الإعدادات")
        }
    }
}

@Preview(name = "Complete Example - LTR vs RTL", showBackground = true, widthDp = 800)
@Composable
private fun CompleteExamplePreview() {
    ProviiWalletTheme {
        Row(modifier = Modifier.fillMaxWidth()) {
            // LTR
            Column(
                modifier =
                    Modifier
                        .weight(1f)
                        .padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("LTR", style = MaterialTheme.typography.labelSmall)
                RtlAwareNavigationHeader(title = "Settings")
                RtlAwareBreadcrumb(items = listOf("Home", "Settings"))
                RtlAwareStepCard(
                    stepNumber = 1,
                    totalSteps = 3,
                    title = "Welcome",
                    description = "Get started",
                    onNext = {},
                )
            }

            // RTL
            ForceRtlLayout {
                Column(
                    modifier =
                        Modifier
                            .weight(1f)
                            .padding(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text("RTL", style = MaterialTheme.typography.labelSmall)
                    RtlAwareNavigationHeader(title = "الإعدادات")
                    RtlAwareBreadcrumb(items = listOf("الرئيسية", "الإعدادات"))
                    RtlAwareStepCard(
                        stepNumber = 1,
                        totalSteps = 3,
                        title = "مرحبا",
                        description = "البدء",
                        onNext = {},
                    )
                }
            }
        }
    }
}
