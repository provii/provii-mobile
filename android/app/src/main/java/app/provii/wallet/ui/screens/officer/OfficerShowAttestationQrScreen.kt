// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.officer

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.LocalOfficerAuthManager
import app.provii.wallet.R
import app.provii.wallet.data.QrCoder
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import timber.log.Timber

/**
 * Screen to display the attestation QR code for the user to scan.
 *
 * NEW BLIND ATTESTATION FLOW:
 * - Officer creates attestation (signed DOB only)
 * - This screen displays QR with deeplink: provii://attest?d=<base64-attestation>
 * - User scans, generates r_bits locally, calls blind issuance
 * - PRIVACY: Officer never sees commitment C or r_bits
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OfficerShowAttestationQrScreen(
    navController: NavController,
    attestationB64: String,
) {
    val officerAuthManager = LocalOfficerAuthManager.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    var userScanned by remember { mutableStateOf(false) }

    // Build attestation deeplink: provii://attest?d=<base64-attestation>
    val qrData =
        remember(attestationB64) {
            "provii://attest?d=$attestationB64"
        }

    val qrBitmap =
        remember(qrData) {
            try {
                val qrCoder = QrCoder()
                qrCoder.encode(qrData, 512)
            } catch (e: Exception) {
                Timber.e(e, "Failed to generate QR code")
                null
            }
        }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.title_credential_ready)) },
                actions = {
                    if (userScanned) {
                        IconButton(
                            onClick = {
                                officerAuthManager.resetIssuance()
                                navController.navigate("officer_dashboard") {
                                    popUpTo("officer_dashboard") { inclusive = false }
                                }
                            },
                            modifier = Modifier.size(accessibilityUiState.minTouchTarget),
                        ) {
                            Icon(Icons.Default.Check, contentDescription = stringResource(R.string.accessibility_officer_done_description))
                        }
                    }
                },
            )
        },
    ) { paddingValues ->
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
        ) {
            // Breadcrumb Navigation (WCAG 2.4.8 AAA)
            Breadcrumb(
                items =
                    listOf(
                        BreadcrumbItem(stringResource(R.string.breadcrumb_officer_mode)),
                        BreadcrumbItem(stringResource(R.string.officer_issue_credential)),
                        BreadcrumbItem(stringResource(R.string.title_credential_ready)),
                    ),
                onNavigate = { index ->
                    when (index) {
                        0 -> {
                            officerAuthManager.resetIssuance()
                            navController.navigate("officer_dashboard") {
                                popUpTo("officer_dashboard") { inclusive = false }
                            }
                        }
                        1 -> navController.popBackStack()
                    }
                },
            )

            Column(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                if (qrBitmap != null) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null, // Decorative - described by adjacent text
                        modifier = Modifier.size(56.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = stringResource(R.string.officer_attestation_ready_title),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.semantics { heading() },
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = stringResource(R.string.officer_attestation_scan_instruction),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    // WCAG 1.4.10: Use fillMaxWidth with max constraint instead of fixed size
                    Card(
                        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .aspectRatio(1f)
                                .sizeIn(maxWidth = 320.dp, maxHeight = 320.dp),
                    ) {
                        Image(
                            bitmap = qrBitmap.asImageBitmap(),
                            contentDescription = stringResource(R.string.accessibility_officer_attestation_qr_description),
                            modifier =
                                Modifier
                                    .fillMaxSize()
                                    .padding(16.dp),
                        )
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Show deeplink for debugging (truncated)
                    Card(
                        colors =
                            CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                            ),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                text = stringResource(R.string.officer_attestation_deeplink_label),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = qrData.take(50) + if (qrData.length > 50) "..." else "",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    if (!userScanned) {
                        Card(
                            colors =
                                CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.secondaryContainer,
                                ),
                        ) {
                            Row(
                                modifier = Modifier.padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    Icons.Default.Info,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp),
                                    tint = MaterialTheme.colorScheme.onSecondaryContainer,
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = stringResource(R.string.officer_wait_for_attestation_scan),
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Medium,
                                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )
                                    Text(
                                        text = stringResource(R.string.officer_attestation_info),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Button(
                            onClick = { userScanned = true },
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(min = accessibilityUiState.minTouchTarget),
                        ) {
                            Text(stringResource(R.string.officer_user_scanned_successfully))
                        }
                    } else {
                        Card(
                            colors =
                                CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                ),
                        ) {
                            Row(
                                modifier = Modifier.padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = stringResource(R.string.officer_attestation_complete),
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Medium,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )
                                    Text(
                                        text = stringResource(R.string.officer_user_will_complete_credential),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Button(
                            onClick = {
                                officerAuthManager.resetIssuance()
                                navController.navigate("officer_dashboard") {
                                    popUpTo("officer_dashboard") { inclusive = false }
                                }
                            },
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(min = accessibilityUiState.minTouchTarget),
                        ) {
                            Icon(Icons.Default.Done, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(stringResource(R.string.officer_return_to_dashboard))
                        }
                    }
                } else {
                    // Error state
                    Card(
                        colors =
                            CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.errorContainer,
                            ),
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(
                                Icons.Default.Error,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(48.dp),
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = stringResource(R.string.officer_qr_generation_failed),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = {
                                    officerAuthManager.resetIssuance()
                                    navController.popBackStack()
                                },
                                modifier = Modifier.heightIn(min = accessibilityUiState.minTouchTarget),
                            ) {
                                Text(stringResource(R.string.officer_go_back))
                            }
                        }
                    }
                }
            }
        }
    }
}
