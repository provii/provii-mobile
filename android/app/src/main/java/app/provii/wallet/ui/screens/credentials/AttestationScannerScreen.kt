// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.credentials

import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.LocalNavigationPayloadStore
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import app.provii.wallet.ui.components.ManagedQrScannerComponent
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleSecondaryButton
import timber.log.Timber

/**
 * Camera-based QR scanner screen for attestation QR codes. Reuses [ManagedQrScannerComponent]
 * to scan QR codes from an officer, then navigates to [BlindAttestationScreen] with the
 * decoded attestation data. Detects verification QR codes and shows a toast directing the
 * user to use the verification scanner instead.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttestationScannerScreen(navController: NavController) {
    val context = LocalContext.current
    val navigationPayloadStore = LocalNavigationPayloadStore.current
    val errorEmptyText = stringResource(R.string.attestation_scan_error_empty)
    val wrongTypeText = stringResource(R.string.attestation_scan_wrong_type_toast)
    val invalidQrText = stringResource(R.string.attestation_scan_invalid_qr)
    var scannerError by remember { mutableStateOf<String?>(null) }
    var showInvalidQr by remember { mutableStateOf(false) }

    // Base64url character set regex (letters, digits, hyphen, underscore, dot, tilde, plus, slash, equals)
    val base64urlPattern = remember { Regex("^[A-Za-z0-9_\\-+/=.]+$") }

    fun isVerificationQr(content: String): Boolean {
        // Verification challenges are JSON with challenge_id/verifier_id fields, or verification deep links
        return content.startsWith("provii://verify") ||
            content.startsWith("https://provii.app/verify") ||
            (
                content.trimStart().startsWith("{") && (
                    content.contains("\"challenge_id\"") ||
                        content.contains("\"verifier_id\"")
                )
            )
    }

    fun extractAttestationData(content: String): String? {
        // Check for attestation deep link URLs first
        if (content.startsWith("provii://attest?d=") ||
            content.startsWith("https://provii.app/attest?d=")
        ) {
            val uri = Uri.parse(content)
            return uri.getQueryParameter("d")
        }

        // Raw base64url attestation blob (officer QR codes contain just the blob)
        if (!content.startsWith("http") &&
            !content.trimStart().startsWith("{") &&
            content.isNotEmpty() &&
            content.length < 10_000 &&
            base64urlPattern.matches(content)
        ) {
            return content
        }

        return null
    }

    fun handleQrScanned(qrContent: String) {
        if (qrContent.isBlank()) {
            scannerError = errorEmptyText
            showInvalidQr = true
            return
        }

        // Check if this is a verification QR code
        if (isVerificationQr(qrContent)) {
            Toast.makeText(
                context,
                wrongTypeText,
                Toast.LENGTH_LONG,
            ).show()
            // Reset scanner to let the user try again -- do not navigate away
            scannerError = null
            showInvalidQr = false
            return
        }

        // Try to extract attestation data
        val attestationData = extractAttestationData(qrContent)
        if (attestationData != null && attestationData.isNotEmpty()) {
            Timber.d("Attestation QR scanned, data length: ${attestationData.length}")
            // Store attestation in the payload store so the route string never
            // carries raw attestation data.
            val payloadKey = navigationPayloadStore.put(attestationData)
            navController.navigate("deeplink_attest/$payloadKey") {
                popUpTo(Screen.CredentialList.route) { inclusive = false }
            }
        } else {
            Timber.w("Invalid QR content for attestation, length: ${qrContent.length}")
            scannerError = invalidQrText
            showInvalidQr = true
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.attestation_scan_title),
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.accessibility_attestation_scan_back),
                        )
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )
        },
    ) { paddingValues ->
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
        ) {
            if (showInvalidQr) {
                // Error state -- invalid QR was scanned
                Column(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(
                        Icons.Default.QrCodeScanner,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.error,
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    Text(
                        text = scannerError ?: stringResource(R.string.attestation_scan_invalid_qr),
                        style = MaterialTheme.typography.headlineSmall,
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.error,
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    AccessiblePrimaryButton(
                        text = stringResource(R.string.action_try_again),
                        modifier = Modifier.fillMaxWidth(0.7f),
                        onClick = {
                            showInvalidQr = false
                            scannerError = null
                        },
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    AccessibleSecondaryButton(
                        text = stringResource(R.string.action_cancel),
                        modifier = Modifier.fillMaxWidth(0.7f),
                        onClick = { navController.popBackStack() },
                    )
                }
            } else {
                // Camera scanner
                ManagedQrScannerComponent(
                    onQrScanned = { qrContent ->
                        Timber.d("Attestation scanner: QR scanned")
                        handleQrScanned(qrContent)
                    },
                    onError = {
                        scannerError = it
                        showInvalidQr = true
                    },
                    modifier = Modifier.fillMaxSize(),
                )

                // Instruction overlay card
                Column(
                    modifier =
                        Modifier
                            .align(Alignment.TopCenter)
                            .padding(horizontal = 32.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Card(
                        colors =
                            CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
                            ),
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(
                                Icons.Default.QrCodeScanner,
                                contentDescription = null,
                                modifier = Modifier.size(32.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = stringResource(R.string.attestation_scan_instruction),
                                style = MaterialTheme.typography.bodyMedium,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }
            }
        }
    }
}
