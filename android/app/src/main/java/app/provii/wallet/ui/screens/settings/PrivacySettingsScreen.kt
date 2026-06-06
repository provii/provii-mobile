// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.settings

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Policy
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.LocalPrivacyPreferences
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.R
import app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog
import app.provii.wallet.ui.components.accessibility.AccessibleCard
import app.provii.wallet.ui.theme.circularFocusIndicator
import app.provii.wallet.ui.accessibility.announceForAccessibility
import kotlinx.coroutines.launch

/**
 * Privacy Settings Screen for MASVS-PRIVACY-2 compliance.
 *
 * Provides users with:
 * - Analytics/telemetry opt-in toggle
 * - Crash reporting opt-in toggle
 * - Data deletion capability
 * - Link to privacy policy
 * - Clear explanation of data collection practices
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrivacySettingsScreen(navController: NavController) {
    val context = LocalContext.current
    val privacyPreferences = LocalPrivacyPreferences.current
    val walletRepository = LocalWalletRepository.current
    val coroutineScope = rememberCoroutineScope()

    val analyticsEnabled by privacyPreferences.analyticsEnabled.collectAsState()
    val crashReportingEnabled by privacyPreferences.crashReportingEnabled.collectAsState()

    val analyticsEnabledText = stringResource(R.string.privacy_analytics_enabled)
    val analyticsDisabledText = stringResource(R.string.privacy_analytics_disabled)
    val crashEnabledText = stringResource(R.string.privacy_crash_reporting_enabled)
    val crashDisabledText = stringResource(R.string.privacy_crash_reporting_disabled)

    var showDeleteDataDialog by remember { mutableStateOf(false) }
    var showDataCollectionInfo by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(R.string.privacy_settings_title),
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = { navController.popBackStack() },
                        modifier = Modifier.circularFocusIndicator(),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.content_desc_back),
                        )
                    }
                },
            )
        },
    ) { paddingValues ->
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(16.dp),
        ) {
            // Privacy Protection Info Card
            item {
                PrivacyProtectionCard()
            }

            // Data Collection Section
            item {
                Text(
                    text = stringResource(R.string.privacy_section_data_collection),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 8.dp, bottom = 4.dp)
                            .semantics { heading() },
                )
            }

            // What Data We Collect Info
            item {
                DataCollectionInfoCard(onClick = { showDataCollectionInfo = true })
            }

            // Analytics Toggle
            item {
                PrivacyToggleCard(
                    icon = Icons.Default.Analytics,
                    title = stringResource(R.string.privacy_analytics_title),
                    description = stringResource(R.string.privacy_analytics_description),
                    checked = analyticsEnabled,
                    onCheckedChange = { enabled ->
                        privacyPreferences.setAnalyticsConsent(enabled)
                        val announcement = if (enabled) analyticsEnabledText else analyticsDisabledText
                        announceForAccessibility(context, announcement)
                    },
                )
            }

            // Crash Reporting Toggle
            item {
                PrivacyToggleCard(
                    icon = Icons.Default.BugReport,
                    title = stringResource(R.string.privacy_crash_reporting_title),
                    description = stringResource(R.string.privacy_crash_reporting_description),
                    checked = crashReportingEnabled,
                    onCheckedChange = { enabled ->
                        privacyPreferences.setCrashReportingConsent(enabled)
                        val announcement = if (enabled) crashEnabledText else crashDisabledText
                        announceForAccessibility(context, announcement)
                    },
                )
            }

            // Your Data Section
            item {
                Text(
                    text = stringResource(R.string.privacy_section_your_data),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 16.dp, bottom = 4.dp)
                            .semantics { heading() },
                )
            }

            // Privacy Policy Link
            item {
                PrivacyPolicyCard(context = context)
            }

            // Delete My Data Button
            item {
                DeleteDataCard(onClick = { showDeleteDataDialog = true })
            }

            // Footer note
            item {
                Text(
                    text = stringResource(R.string.privacy_footer_note),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
    }

    // Delete Data Confirmation Dialog
    if (showDeleteDataDialog) {
        Text(
            text = stringResource(R.string.dialog_delete_data_announcement),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
        )

        AccessibleAlertDialog(
            onDismissRequest = { showDeleteDataDialog = false },
            icon = { Icon(Icons.Default.Warning, contentDescription = stringResource(R.string.content_desc_warning)) },
            title = { Text(stringResource(R.string.privacy_delete_data_dialog_title)) },
            text = {
                Column {
                    Text(stringResource(R.string.privacy_delete_data_dialog_message))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        stringResource(R.string.privacy_delete_data_dialog_warning),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDataDialog = false
                        coroutineScope.launch {
                            // Request data deletion
                            privacyPreferences.requestDataDeletion()
                            // Clear wallet data
                            walletRepository.clearAllData()
                            // Clear privacy preferences
                            privacyPreferences.clearAllPrivacyData()
                            // Navigate back to start
                            navController.popBackStack(navController.graph.startDestinationId, false)
                        }
                    },
                ) {
                    Text(
                        stringResource(R.string.privacy_delete_data_confirm),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDataDialog = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }

    // Data Collection Info Dialog
    if (showDataCollectionInfo) {
        Text(
            text = stringResource(R.string.dialog_data_collection_info_announcement),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
        )

        AccessibleAlertDialog(
            onDismissRequest = { showDataCollectionInfo = false },
            icon = { Icon(Icons.Default.Info, contentDescription = stringResource(R.string.content_desc_information)) },
            title = { Text(stringResource(R.string.privacy_data_collection_info_title)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        stringResource(R.string.privacy_data_we_collect_header),
                        fontWeight = FontWeight.Bold,
                    )
                    Text(stringResource(R.string.privacy_data_we_collect_list))

                    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

                    Text(
                        stringResource(R.string.privacy_data_we_dont_collect_header),
                        fontWeight = FontWeight.Bold,
                    )
                    Text(stringResource(R.string.privacy_data_we_dont_collect_list))

                    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

                    Text(
                        stringResource(R.string.privacy_data_never_shared_note),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { showDataCollectionInfo = false }) {
                    Text(stringResource(R.string.action_ok))
                }
            },
        )
    }
}

@Composable
private fun PrivacyProtectionCard() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Lock,
                    contentDescription = stringResource(R.string.content_desc_privacy_protected),
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    stringResource(R.string.privacy_protection_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                stringResource(R.string.privacy_protection_description),
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun DataCollectionInfoCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_data_collection_info),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Info,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.privacy_what_we_collect_title),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    stringResource(R.string.privacy_what_we_collect_subtitle),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = stringResource(R.string.accessibility_settings_navigate_description),
            )
        }
    }
}

@Composable
private fun PrivacyToggleCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.bodyLarge)
                Text(
                    description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
            )
        }
    }
}

@Composable
private fun PrivacyPolicyCard(context: Context) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = {
            // Open privacy policy URL
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://provii.app/privacy"))
            context.startActivity(intent)
        },
        contentDescription = stringResource(R.string.content_desc_privacy_policy),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Policy,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.privacy_policy_title),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    stringResource(R.string.privacy_policy_subtitle),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                Icons.Default.OpenInNew,
                contentDescription = stringResource(R.string.content_desc_opens_external_link),
            )
        }
    }
}

@Composable
private fun DeleteDataCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_delete_my_data),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Delete,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.error,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.privacy_delete_my_data_title),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.error,
                )
                Text(
                    stringResource(R.string.privacy_delete_my_data_subtitle),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
