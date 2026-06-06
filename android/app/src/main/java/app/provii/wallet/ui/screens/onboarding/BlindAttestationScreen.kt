// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChildCare
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.R
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.navigation.Screen
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessibleErrorBadge
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleSecondaryButton
import app.provii.wallet.privacy.ErrorSanitizer
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import timber.log.Timber

/**
 * Dedicated screen for handling blind attestation credential issuance.
 * This implements the secure blind attestation protocol where:
 * - Issuer (DMV) signs attestation with Ed25519, never sees commitment or r_bits
 * - User generates r_bits locally but cannot lie about DOB
 * - Provii computes commitment server-side using attested DOB
 *
 * MASVS-CRYPTO-2: Ed25519-signed attestation for non-repudiation
 * MASVS-NETWORK-2: TLS 1.3+ required for all API calls
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BlindAttestationScreen(
    navController: NavController,
    attestationData: String,
) {
    val walletRepository = LocalWalletRepository.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val accessibilityManager = LocalAccessibilityManager.current
    val settings = accessibilityUiState.settings
    val coroutineScope = rememberCoroutineScope()

    // String resources
    val decodingMessage = stringResource(R.string.attestation_decoding)
    val generatingMessage = stringResource(R.string.attestation_generating_randomness)
    val sendingMessage = stringResource(R.string.attestation_sending)
    val verifyingMessage = stringResource(R.string.attestation_verifying)
    val storingMessage = stringResource(R.string.attestation_storing)
    val completeMessage = stringResource(R.string.attestation_complete)
    val errorInvalidData = stringResource(R.string.attestation_error_invalid_data)
    val errorExpired = stringResource(R.string.attestation_error_expired)
    val errorNetwork = stringResource(R.string.attestation_error_network)
    val errorUnexpected = stringResource(R.string.attestation_error_unexpected)

    var attestationState by remember { mutableStateOf(AttestationState.TYPE_CHOICE) }
    var currentStep by remember { mutableStateOf(ProcessingStep.DECODING) }
    var progressMessage by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var progress by remember { mutableFloatStateOf(0f) }
    var issuerName by remember { mutableStateOf<String?>(null) }

    // Credential recipient state
    var credentialType by remember { mutableStateOf("primary") }
    var childNickname by remember { mutableStateOf("") }

    // Slot-full guard
    val credentialState by walletRepository.credentialState.collectAsStateWithLifecycle()
    var showSlotFullDialog by remember { mutableStateOf(false) }
    val managedSlotsFull =
        when (val state = credentialState) {
            is WalletRepository.CredentialState.HasCredentials -> state.managed.size >= 15
            else -> false
        }

    // Primary credential replacement guard
    var showReplacePrimaryDialog by remember { mutableStateOf(false) }

    // String resources for recipient flow
    val recipientHeadingDescription = stringResource(R.string.accessibility_attestation_recipient_heading)
    val nicknameHeadingDescription = stringResource(R.string.accessibility_attestation_nickname_heading)

    // Initialise progress message
    LaunchedEffect(Unit) {
        progressMessage = decodingMessage
    }

    // Callback to kick off the processing flow once the recipient is chosen
    fun startProcessing() {
        attestationState = AttestationState.PROCESSING
        coroutineScope.launch {
            try {
                Timber.d("BlindAttestation: Starting attestation process")
                Timber.d("Attestation data length: ${attestationData.length} chars")
                Timber.d("Credential type: $credentialType, nickname: [REDACTED]")

                // Step 1: Decode attestation
                currentStep = ProcessingStep.DECODING
                progressMessage = decodingMessage
                progress = 0.1f
                delay(300) // Brief visual feedback

                // Step 2: Generate randomness
                currentStep = ProcessingStep.GENERATING
                progressMessage = generatingMessage
                progress = 0.3f
                delay(200)

                // Step 3: Send to Provii for signing
                currentStep = ProcessingStep.SENDING
                progressMessage = sendingMessage
                progress = 0.5f

                // Process the blind issuance through the wallet repository
                val nicknameToSend = if (credentialType == "managed") childNickname else null
                val result =
                    walletRepository.processBlindIssuance(
                        attestationData = attestationData,
                        credentialType = credentialType,
                        nickname = nicknameToSend,
                    )

                if (result.isSuccess) {
                    // Step 4: Verify commitment
                    currentStep = ProcessingStep.VERIFYING
                    progressMessage = verifyingMessage
                    progress = 0.7f
                    delay(200)

                    // Step 5: Store credential
                    currentStep = ProcessingStep.STORING
                    progressMessage = storingMessage
                    progress = 0.9f
                    delay(200)

                    // Step 6: Complete
                    currentStep = ProcessingStep.COMPLETE
                    progressMessage = completeMessage
                    progress = 1.0f

                    Timber.d("Blind attestation credential issuance successful!")
                    attestationState = AttestationState.SUCCESS

                    // Wait a moment to show success (WCAG 2.2.1: Respect accessibility timeout)
                    val successDisplayTime = accessibilityManager.getTimeoutDuration(standard = 2000L) ?: 2000L
                    delay(successDisplayTime)

                    // Navigate to success screen
                    navController.navigate(Screen.CredentialSuccess.route) {
                        popUpTo(Screen.CredentialList.route) { inclusive = false }
                    }
                } else {
                    val error = result.exceptionOrNull()
                    Timber.e("Blind attestation failed: ${error?.message}")

                    errorMessage =
                        when {
                            error?.message?.contains("invalid", ignoreCase = true) == true ||
                                error?.message?.contains("decode", ignoreCase = true) == true ->
                                errorInvalidData
                            error?.message?.contains("expired", ignoreCase = true) == true ->
                                errorExpired
                            error?.message?.contains("network", ignoreCase = true) == true ||
                                error?.message?.contains("timeout", ignoreCase = true) == true ->
                                errorNetwork
                            else ->
                                ErrorSanitizer.sanitize(error?.message ?: errorUnexpected)
                        }
                    attestationState = AttestationState.ERROR
                }
            } catch (e: Exception) {
                Timber.e(e, "Unexpected error during blind attestation")
                errorMessage = ErrorSanitizer.sanitize(e.message ?: errorUnexpected)
                attestationState = AttestationState.ERROR
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        when (attestationState) {
                            AttestationState.TYPE_CHOICE -> stringResource(R.string.attestation_recipient_title)
                            AttestationState.NICKNAME_ENTRY -> stringResource(R.string.attestation_nickname_title)
                            AttestationState.PROCESSING -> stringResource(R.string.attestation_title_processing)
                            AttestationState.SUCCESS -> stringResource(R.string.attestation_title_success)
                            AttestationState.ERROR -> stringResource(R.string.attestation_title_failed)
                        },
                    )
                },
                navigationIcon = {
                    if (attestationState == AttestationState.NICKNAME_ENTRY) {
                        IconButton(onClick = { attestationState = AttestationState.TYPE_CHOICE }) {
                            // A11Y-010a: Use AutoMirrored variant so the arrow
                            // flips direction in RTL layouts (Arabic, Hebrew, etc.)
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = stringResource(R.string.attestation_nickname_back),
                            )
                        }
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor =
                            when (attestationState) {
                                AttestationState.SUCCESS -> MaterialTheme.colorScheme.primaryContainer
                                AttestationState.ERROR -> MaterialTheme.colorScheme.errorContainer
                                else -> MaterialTheme.colorScheme.surface
                            },
                    ),
            )
        },
    ) { paddingValues ->
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            contentAlignment = Alignment.Center,
        ) {
            when (attestationState) {
                AttestationState.TYPE_CHOICE -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(24.dp),
                        modifier =
                            Modifier
                                .padding(32.dp)
                                .verticalScroll(rememberScrollState()),
                    ) {
                        // Security badge (same as processing screen)
                        Card(
                            colors =
                                CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                ),
                            modifier = Modifier.padding(bottom = 8.dp),
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                            ) {
                                Icon(
                                    Icons.Default.Shield,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(R.string.attestation_secure_issuance),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }

                        // Heading
                        Text(
                            text = stringResource(R.string.attestation_recipient_prompt),
                            style = MaterialTheme.typography.headlineSmall,
                            textAlign = TextAlign.Center,
                            modifier =
                                Modifier.semantics {
                                    heading()
                                    contentDescription = recipientHeadingDescription
                                },
                        )

                        // "Me" button
                        Column(
                            modifier = Modifier.fillMaxWidth(0.85f),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            AccessiblePrimaryButton(
                                text = stringResource(R.string.attestation_recipient_me),
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    val hasPrimary = (credentialState as? WalletRepository.CredentialState.HasCredentials)?.primary != null
                                    if (hasPrimary) {
                                        showReplacePrimaryDialog = true
                                    } else {
                                        credentialType = "primary"
                                        startProcessing()
                                    }
                                },
                            )

                            // "A Child" button (guarded by slot availability)
                            AccessibleSecondaryButton(
                                text = stringResource(R.string.attestation_recipient_child),
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    if (managedSlotsFull) {
                                        showSlotFullDialog = true
                                    } else {
                                        credentialType = "managed"
                                        attestationState = AttestationState.NICKNAME_ENTRY
                                    }
                                },
                            )
                        }
                    }
                }

                AttestationState.NICKNAME_ENTRY -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(20.dp),
                        modifier =
                            Modifier
                                .padding(32.dp)
                                .verticalScroll(rememberScrollState()),
                    ) {
                        // Child icon
                        Icon(
                            Icons.Default.ChildCare,
                            contentDescription = null, // Decorative -- heading describes the screen
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )

                        // Heading
                        Text(
                            text = stringResource(R.string.attestation_nickname_prompt),
                            style = MaterialTheme.typography.headlineSmall,
                            textAlign = TextAlign.Center,
                            modifier =
                                Modifier.semantics {
                                    heading()
                                    contentDescription = nicknameHeadingDescription
                                },
                        )

                        // Nickname text field (max 30 characters)
                        OutlinedTextField(
                            value = childNickname,
                            onValueChange = { if (it.length <= 30) childNickname = it },
                            label = { Text(stringResource(R.string.attestation_nickname_title)) },
                            placeholder = { Text(stringResource(R.string.attestation_nickname_placeholder)) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            isError = childNickname.isNotEmpty() && childNickname.isBlank(),
                            supportingText = {
                                Text("${childNickname.length}/30")
                            },
                            leadingIcon = {
                                Icon(
                                    Icons.Default.Person,
                                    contentDescription = null, // Decorative -- field has label
                                )
                            },
                        )

                        // Continue / Back buttons
                        Column(
                            modifier = Modifier.fillMaxWidth(0.85f),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            AccessiblePrimaryButton(
                                text = stringResource(R.string.attestation_nickname_continue),
                                modifier = Modifier.fillMaxWidth(),
                                enabled = childNickname.isNotBlank(),
                                onClick = { startProcessing() },
                            )
                            AccessibleSecondaryButton(
                                text = stringResource(R.string.attestation_nickname_back),
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    attestationState = AttestationState.TYPE_CHOICE
                                },
                            )
                        }
                    }
                }

                AttestationState.PROCESSING -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(20.dp),
                        modifier =
                            Modifier
                                .padding(32.dp)
                                .verticalScroll(rememberScrollState())
                                .semantics {
                                    liveRegion = LiveRegionMode.Polite
                                    contentDescription = progressMessage
                                },
                    ) {
                        // Security badge
                        Card(
                            colors =
                                CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                ),
                            modifier = Modifier.padding(bottom = 8.dp),
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                            ) {
                                Icon(
                                    Icons.Default.Shield,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(R.string.attestation_secure_issuance),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }

                        // Progress indicator
                        CircularProgressIndicator(
                            progress = { progress },
                            modifier =
                                Modifier
                                    .size(80.dp)
                                    .semantics {
                                        contentDescription = progressMessage
                                    },
                            color = MaterialTheme.colorScheme.primary,
                            strokeWidth = 6.dp,
                            trackColor = MaterialTheme.colorScheme.surfaceVariant,
                        )

                        // Current step message
                        Text(
                            text = progressMessage,
                            style = MaterialTheme.typography.headlineSmall,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                        )

                        // Progress steps visualization
                        ProcessingStepsIndicator(
                            currentStep = currentStep,
                            modifier = Modifier.fillMaxWidth(),
                        )

                        // Security note
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center,
                        ) {
                            Icon(
                                Icons.Default.Lock,
                                contentDescription = stringResource(R.string.accessibility_attestation_encrypted_description),
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = stringResource(R.string.attestation_privacy_preserving),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }

                        Text(
                            text = stringResource(R.string.attestation_may_take_seconds),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )

                        if (settings.verboseDescriptions) {
                            Text(
                                text = stringResource(R.string.attestation_keep_app_open),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }

                AttestationState.SUCCESS -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier =
                            Modifier
                                .padding(32.dp)
                                .semantics {
                                    liveRegion = LiveRegionMode.Polite
                                },
                    ) {
                        Icon(
                            if (credentialType == "managed") Icons.Default.ChildCare else Icons.Default.CheckCircle,
                            contentDescription = stringResource(R.string.accessibility_attestation_success_description),
                            modifier = Modifier.size(80.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Text(
                            text =
                                if (credentialType == "managed" && childNickname.isNotBlank()) {
                                    stringResource(R.string.attestation_managed_credential_received, childNickname.trim())
                                } else {
                                    stringResource(R.string.attestation_credential_received)
                                },
                            style = MaterialTheme.typography.headlineMedium,
                            color = MaterialTheme.colorScheme.primary,
                            textAlign = TextAlign.Center,
                            modifier =
                                Modifier.semantics {
                                    liveRegion = LiveRegionMode.Assertive
                                    heading()
                                },
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text =
                                if (credentialType == "managed") {
                                    stringResource(R.string.attestation_managed_credential_stored)
                                } else {
                                    stringResource(R.string.attestation_credential_stored_description)
                                },
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )

                        // Security verification badge
                        Spacer(modifier = Modifier.height(16.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center,
                        ) {
                            Icon(
                                Icons.Default.Verified,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = stringResource(R.string.attestation_issuer_verified),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        LinearProgressIndicator(
                            modifier =
                                Modifier
                                    .fillMaxWidth(0.6f)
                                    .height(2.dp),
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
                        )
                    }
                }

                AttestationState.ERROR -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier =
                            Modifier
                                .padding(32.dp)
                                .semantics {
                                    liveRegion = LiveRegionMode.Assertive
                                },
                    ) {
                        Icon(
                            Icons.Default.Error,
                            contentDescription = stringResource(R.string.accessibility_attestation_error_description),
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Text(
                            text = stringResource(R.string.attestation_failed_title),
                            style = MaterialTheme.typography.headlineMedium,
                            color = MaterialTheme.colorScheme.error,
                            textAlign = TextAlign.Center,
                            modifier =
                                Modifier.semantics {
                                    liveRegion = LiveRegionMode.Assertive
                                    heading()
                                },
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        AccessibleErrorBadge(
                            message = errorMessage ?: errorUnexpected,
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .semantics {
                                        liveRegion = LiveRegionMode.Assertive
                                    },
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Column(
                            modifier = Modifier.fillMaxWidth(0.85f),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            AccessiblePrimaryButton(
                                text = stringResource(R.string.attestation_scan_qr_instead),
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    navController.navigate(Screen.WhereToGetCredentials.createRoute()) {
                                        popUpTo(Screen.CredentialList.route) { inclusive = false }
                                    }
                                },
                            )
                            AccessibleSecondaryButton(
                                text = stringResource(R.string.attestation_go_back),
                                modifier = Modifier.fillMaxWidth(),
                                onClick = { navController.popBackStack() },
                            )
                        }
                    }
                }
            }
        }
    }

    // Slot-full dialog
    if (showSlotFullDialog) {
        AlertDialog(
            onDismissRequest = { showSlotFullDialog = false },
            title = { Text(stringResource(R.string.credential_slots_full_title)) },
            text = { Text(stringResource(R.string.credential_slots_full_message)) },
            confirmButton = {
                TextButton(onClick = { showSlotFullDialog = false }) {
                    Text(stringResource(R.string.action_ok))
                }
            },
        )
    }

    // Replace existing primary credential dialog
    if (showReplacePrimaryDialog) {
        AlertDialog(
            onDismissRequest = { showReplacePrimaryDialog = false },
            title = { Text(stringResource(R.string.attestation_replace_primary_title)) },
            text = { Text(stringResource(R.string.attestation_replace_primary_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showReplacePrimaryDialog = false
                    credentialType = "primary"
                    startProcessing()
                }) {
                    Text(stringResource(R.string.attestation_replace_confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = { showReplacePrimaryDialog = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

/**
 * Visual indicator showing the current processing step
 */
@Composable
private fun ProcessingStepsIndicator(
    currentStep: ProcessingStep,
    modifier: Modifier = Modifier,
) {
    val steps =
        listOf(
            ProcessingStep.DECODING to stringResource(R.string.attestation_step_decode),
            ProcessingStep.GENERATING to stringResource(R.string.attestation_step_generate),
            ProcessingStep.SENDING to stringResource(R.string.attestation_step_send),
            ProcessingStep.VERIFYING to stringResource(R.string.attestation_step_verify),
            ProcessingStep.STORING to stringResource(R.string.attestation_step_store),
            ProcessingStep.COMPLETE to stringResource(R.string.attestation_step_complete),
        )

    Column(
        modifier = modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        steps.forEach { (step, label) ->
            val isComplete = step.ordinal < currentStep.ordinal
            val isCurrent = step == currentStep

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
            ) {
                // Step indicator
                Box(
                    modifier = Modifier.size(20.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    when {
                        isComplete -> {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = stringResource(R.string.accessibility_step_complete, label),
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        }
                        isCurrent -> {
                            CircularProgressIndicator(
                                modifier = Modifier.size(14.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        else -> {
                            // Pending indicator - empty circle
                            Box(
                                modifier =
                                    Modifier
                                        .size(12.dp),
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.width(12.dp))

                Text(
                    text = label,
                    style = MaterialTheme.typography.bodySmall,
                    color =
                        when {
                            isComplete -> MaterialTheme.colorScheme.primary
                            isCurrent -> MaterialTheme.colorScheme.onSurface
                            else -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        },
                )
            }
        }
    }
}

private enum class AttestationState {
    TYPE_CHOICE,
    NICKNAME_ENTRY,
    PROCESSING,
    SUCCESS,
    ERROR,
}

private enum class ProcessingStep {
    DECODING,
    GENERATING,
    SENDING,
    VERIFYING,
    STORING,
    COMPLETE,
}
