// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.verification

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.SheetValue
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.R
import app.provii.wallet.audio.VerificationSoundManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.ManagedQrScannerComponent
import app.provii.wallet.ui.components.accessibility.AccessibleErrorBadge
import app.provii.wallet.ui.components.accessibility.AccessibleModalBottomSheet
import app.provii.wallet.ui.components.accessibility.AccessiblePrimaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleSecondaryButton
import app.provii.wallet.ui.components.accessibility.AccessibleStepBadge
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.fragment.app.FragmentActivity
import app.provii.wallet.data.AuthenticationRequiredException
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.logging.redactId
import app.provii.wallet.navigation.Screen
import app.provii.wallet.utils.ErrorMapper
import timber.log.Timber

/**
 * QR scanner screen for verification challenges.
 * This is used when the user manually scans a QR code from another screen.
 * For app-to-app deep link flow, use DeepLinkVerificationScreen instead.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VerificationChallengeScreen(
    navController: NavController,
) {
    val walletRepository = LocalWalletRepository.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val settings = accessibilityUiState.settings
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val soundManager = remember { VerificationSoundManager(context.applicationContext) }
    DisposableEffect(soundManager) {
        onDispose { soundManager.dispose() }
    }

    val resources = context.resources
    val statusCreatingProofText = stringResource(R.string.verification_status_creating_proof)
    val errorNoAuthPromptText = stringResource(R.string.verification_error_no_auth_prompt)
    val errorAuthCancelledText = stringResource(R.string.error_authentication_cancelled)
    val statusSubmittingProofText = stringResource(R.string.verification_status_submitting_proof)
    val statusVerifiedText = stringResource(R.string.verification_status_verified)
    val errorVerificationFailedText = stringResource(R.string.verification_error_verification_failed)
    val errorNoCredentialText = stringResource(R.string.error_no_credential)
    val statusReadingRequestText = stringResource(R.string.verification_status_reading_request)
    val statusProcessingChallengeText = stringResource(R.string.verification_status_processing_challenge)
    val errorFailedProcessChallengeText = stringResource(R.string.verification_error_failed_to_process_challenge)
    val pleaseEnterCodeText = stringResource(R.string.verification_please_enter_code)
    val errorFailedProcessCodeText = stringResource(R.string.verification_error_failed_to_process_code)

    var scanMode by remember { mutableStateOf(ScanMode.SCANNING) }
    var progressMessage by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showManualEntry by remember { mutableStateOf(false) }
    var manualCode by remember { mutableStateOf("") }
    var manualCodeError by remember { mutableStateOf<String?>(null) }
    val errorFocusRequester = remember { FocusRequester() }

    // Credential picker state
    var showCredentialPicker by remember { mutableStateOf(false) }
    var provableCredentials by remember { mutableStateOf<List<WalletRepository.CredentialPickerItem>>(emptyList()) }
    var pendingChallengeId by remember { mutableStateOf<String?>(null) }
    var pendingIsManualEntry by remember { mutableStateOf(false) }

    // Managed credential confirmation state
    var showManagedConfirmation by remember { mutableStateOf(false) }
    var pendingManagedCredential by remember { mutableStateOf<WalletRepository.CredentialPickerItem?>(null) }

    // Attestation QR redirect state
    var showAttestationRedirectDialog by remember { mutableStateOf(false) }
    var pendingAttestationQrContent by remember { mutableStateOf<String?>(null) }

    // Track which credential was selected for context-aware messages
    var selectedCredentialName by remember { mutableStateOf<String?>(null) }
    var selectedCredentialIsManaged by remember { mutableStateOf(false) }

    /**
     * Shared helper: once a credential is selected and a challengeId is known,
     * create the proof, submit it, and handle the result.
     * Called either directly (single credential) or after picker selection (multiple).
     */
    fun continueProofWithCredential(
        credentialId: String,
        challengeId: String,
    ) {
        coroutineScope.launch {
            try {
                progressMessage =
                    if (selectedCredentialIsManaged && selectedCredentialName != null) {
                        resources.getString(R.string.verification_creating_proof_for, selectedCredentialName)
                    } else {
                        statusCreatingProofText
                    }
                delay(500)

                // Get Activity for biometric authentication
                val activity = context as? FragmentActivity
                if (activity == null) {
                    Timber.e("Cannot get FragmentActivity for authentication")
                    errorMessage = errorNoAuthPromptText
                    scanMode = ScanMode.ERROR
                    return@launch
                }

                // Create the age proof (requires biometric authentication)
                val proofResult =
                    walletRepository.createAgeProof(
                        credentialId = credentialId,
                        challengeId = challengeId,
                        activity = activity,
                    )

                if (proofResult.isFailure) {
                    val error = proofResult.exceptionOrNull()
                    Timber.e("Failed to create proof: ${error?.message}")
                    errorMessage =
                        when (error) {
                            is AuthenticationRequiredException -> errorAuthCancelledText
                            else -> ErrorMapper.mapToUserMessage(error ?: Exception(), context)
                        }
                    scanMode = ScanMode.ERROR
                    return@launch
                }

                val proofJson = proofResult.getOrThrow()
                Timber.d("Proof created successfully, size: ${proofJson.length}")

                progressMessage = statusSubmittingProofText
                delay(500)

                // Submit the proof to the verifier
                val submitResult = walletRepository.submitProof(proofJson)

                if (submitResult.isSuccess && submitResult.getOrThrow()) {
                    progressMessage = statusVerifiedText

                    // Play verification success sound and haptic feedback
                    soundManager.playVerificationSuccess(
                        soundEnabled = settings.soundEnabled,
                        preset = settings.verificationSoundPreset,
                        volumePercent = settings.soundVolume,
                        hapticEnabled = settings.hapticFeedback,
                    )

                    scanMode = ScanMode.SUCCESS
                    Timber.d("Verification successful")

                    if (!settings.disableAutoContextChanges) {
                        // Wait for sound to play before navigating away
                        delay(800)
                        navController.popBackStack()
                    }
                } else {
                    val submitError = submitResult.exceptionOrNull()
                    Timber.e("Verification failed: ${submitError?.message}")
                    errorMessage =
                        if (submitError != null) {
                            ErrorMapper.mapToUserMessage(submitError, context)
                        } else {
                            errorVerificationFailedText
                        }
                    scanMode = ScanMode.ERROR
                }
            } catch (e: Exception) {
                Timber.e(e, "Error during proof creation/submission")
                errorMessage = ErrorMapper.mapToUserMessage(e, context)
                scanMode = ScanMode.ERROR
            }
        }
    }

    /**
     * Proceed with a credential after selection, showing confirmation for managed credentials.
     */
    fun proceedWithCredential(
        credential: WalletRepository.CredentialPickerItem,
        challengeId: String,
    ) {
        selectedCredentialName = credential.displayName
        selectedCredentialIsManaged = credential.isManaged
        if (credential.isManaged) {
            // Show confirmation dialog for managed credentials
            pendingManagedCredential = credential
            pendingChallengeId = challengeId
            showManagedConfirmation = true
        } else {
            continueProofWithCredential(credential.id, challengeId)
        }
    }

    suspend fun resolveCredentialAndContinue(
        challengeId: String,
        isManualEntry: Boolean,
    ) {
        val credentials = walletRepository.getPickerCredentials()
        when {
            credentials.isEmpty() -> {
                Timber.e("No provable credentials found")
                errorMessage = errorNoCredentialText
                scanMode = ScanMode.ERROR
            }
            credentials.size == 1 -> {
                // Single credential - proceed (with confirmation if managed)
                val credential = credentials.first()
                Timber.d("Single provable credential found: ${redactId(credential.id)}")
                proceedWithCredential(credential, challengeId)
            }
            else -> {
                // Multiple credentials - show picker and pause the flow
                Timber.d("Multiple provable credentials found (${credentials.size}), showing picker")
                provableCredentials = credentials
                pendingChallengeId = challengeId
                pendingIsManualEntry = isManualEntry
                showCredentialPicker = true
                // Flow resumes when user picks a credential (see CredentialPickerSheet)
            }
        }
    }

    fun processChallenge(qrContent: String) {
        // Check if this is actually an attestation QR, not a verification challenge
        val isAttestationQr =
            qrContent.startsWith("provii://attest") ||
                qrContent.startsWith("https://provii.app/attest")

        if (isAttestationQr) {
            showAttestationRedirectDialog = true
            pendingAttestationQrContent = qrContent
            return
        }

        coroutineScope.launch {
            scanMode = ScanMode.PROCESSING
            errorMessage = null

            try {
                Timber.d("Processing challenge, content length: ${qrContent.length}")
                progressMessage = statusReadingRequestText
                delay(500)

                progressMessage = statusProcessingChallengeText

                // Process the verification challenge
                // The SDK expects the full QR content (either raw JSON or provii:// URL)
                val challengeResult = walletRepository.processVerificationChallenge(qrContent)
                if (challengeResult.isFailure) {
                    val error = challengeResult.exceptionOrNull()
                    Timber.e("Failed to process challenge: ${error?.message}")
                    errorMessage =
                        if (error != null) {
                            ErrorMapper.mapToUserMessage(error, context)
                        } else {
                            errorFailedProcessChallengeText
                        }
                    scanMode = ScanMode.ERROR
                    return@launch
                }

                val challengeId = challengeResult.getOrThrow()
                Timber.d("Challenge processed successfully, ID: ${redactId(challengeId)}")

                // Resolve credential (auto-select single or show picker for multiple)
                resolveCredentialAndContinue(challengeId, isManualEntry = false)
            } catch (e: Exception) {
                Timber.e(e, "Error during verification")
                errorMessage = ErrorMapper.mapToUserMessage(e, context)
                scanMode = ScanMode.ERROR
            }
        }
    }

    fun submitManualCode() {
        val code = manualCode.trim()
        if (code.length != 12 || !code.all { it.isDigit() }) {
            manualCodeError = pleaseEnterCodeText
            return
        }
        manualCodeError = null
        showManualEntry = false
        manualCode = ""

        // Process 12-digit short code via manual entry
        coroutineScope.launch {
            scanMode = ScanMode.PROCESSING
            errorMessage = null

            try {
                Timber.d("Processing manual entry, input length: ${code.length}")
                progressMessage = statusReadingRequestText
                delay(500)

                progressMessage = statusProcessingChallengeText

                // Process 12-digit short code
                val entryResult = walletRepository.processManualEntry(code)
                if (entryResult.isFailure) {
                    val error = entryResult.exceptionOrNull()
                    Timber.e("Failed to process manual entry: ${error?.message}")
                    errorMessage =
                        if (error != null) {
                            ErrorMapper.mapToUserMessage(error, context)
                        } else {
                            errorFailedProcessCodeText
                        }
                    scanMode = ScanMode.ERROR
                    return@launch
                }

                val challengeId = entryResult.getOrThrow()
                Timber.d("Manual entry processed successfully, challenge ID: ${redactId(challengeId)}")

                // Resolve credential (auto-select single or show picker for multiple)
                resolveCredentialAndContinue(challengeId, isManualEntry = true)
            } catch (e: Exception) {
                Timber.e(e, "Error during manual entry verification")
                errorMessage = ErrorMapper.mapToUserMessage(e, context)
                scanMode = ScanMode.ERROR
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text =
                            when (scanMode) {
                                ScanMode.SCANNING -> stringResource(R.string.verification_scan_title)
                                ScanMode.PROCESSING -> stringResource(R.string.verification_verifying_title)
                                ScanMode.SUCCESS -> stringResource(R.string.verification_success_title)
                                ScanMode.ERROR -> stringResource(R.string.verification_failed_title)
                            },
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    if (scanMode == ScanMode.SCANNING || scanMode == ScanMode.ERROR) {
                        IconButton(onClick = { navController.popBackStack() }) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.accessibility_verification_back_description))
                        }
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor =
                            when (scanMode) {
                                ScanMode.SUCCESS -> MaterialTheme.colorScheme.primaryContainer
                                ScanMode.ERROR -> MaterialTheme.colorScheme.errorContainer
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
        ) {
            when (scanMode) {
                ScanMode.SCANNING -> {
                    ManagedQrScannerComponent(
                        onQrScanned = { qrContent ->
                            Timber.d("QR scanned, processing challenge")
                            processChallenge(qrContent)
                        },
                        onError = {
                            errorMessage = it
                            scanMode = ScanMode.ERROR
                        },
                        modifier = Modifier.fillMaxSize(),
                    )

                    Column(
                        modifier =
                            Modifier
                                .align(Alignment.TopCenter)
                                .padding(horizontal = 32.dp, vertical = 24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        AccessibleStepBadge(text = stringResource(R.string.verification_step_1_of_2))
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
                                    contentDescription = null, // Decorative - described by adjacent text "Point camera at verification QR"
                                    modifier = Modifier.size(32.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = stringResource(R.string.verification_point_camera),
                                    style = MaterialTheme.typography.bodyMedium,
                                    textAlign = TextAlign.Center,
                                )
                                if (settings.verboseDescriptions) {
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = stringResource(R.string.verification_hold_steady),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center,
                                    )
                                }
                            }
                        }
                    }

                    AccessibleSecondaryButton(
                        text = stringResource(R.string.manual_entry_enter_code_manually),
                        modifier =
                            Modifier
                                .fillMaxWidth(0.9f)
                                .align(Alignment.BottomCenter)
                                .padding(bottom = 32.dp),
                        onClick = { showManualEntry = true },
                    )
                }

                ScanMode.PROCESSING -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                            modifier = Modifier.padding(32.dp),
                        ) {
                            AccessibleStepBadge(text = stringResource(R.string.verification_step_2_of_2))
                            CircularProgressIndicator(
                                modifier = Modifier.size(64.dp),
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Text(
                                text = progressMessage.ifEmpty { stringResource(R.string.status_processing) },
                                style = MaterialTheme.typography.headlineSmall,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                            )
                            Text(
                                text = stringResource(R.string.verification_processing_wait),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                            )
                            if (settings.verboseDescriptions) {
                                Text(
                                    text = stringResource(R.string.verification_preparing_proof),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        }
                    }
                }

                ScanMode.SUCCESS -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(32.dp),
                        ) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = stringResource(R.string.accessibility_verification_success_description),
                                modifier = Modifier.size(80.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(modifier = Modifier.height(24.dp))
                            // A11Y-012a: Mark success heading so TalkBack users can
                            // navigate to it via heading gestures.
                            Text(
                                text =
                                    if (selectedCredentialIsManaged && selectedCredentialName != null) {
                                        stringResource(R.string.verification_age_verified_for, selectedCredentialName as Any)
                                    } else {
                                        stringResource(R.string.verification_age_verified)
                                    },
                                style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.primary,
                                textAlign = TextAlign.Center,
                                modifier =
                                    Modifier.semantics {
                                        heading()
                                        liveRegion = LiveRegionMode.Polite
                                    },
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = stringResource(R.string.verification_success_message),
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                            )
                            if (settings.verboseDescriptions) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = stringResource(R.string.verification_return_to_site),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center,
                                )
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                            if (settings.disableAutoContextChanges) {
                                AccessiblePrimaryButton(
                                    text = stringResource(R.string.action_done),
                                    onClick = { navController.popBackStack() },
                                    modifier = Modifier.fillMaxWidth(0.6f),
                                )
                            } else {
                                Text(
                                    text = stringResource(R.string.verification_returning_browser),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        }
                    }
                }

                ScanMode.ERROR -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(20.dp),
                            modifier = Modifier.padding(32.dp),
                        ) {
                            Icon(
                                Icons.Default.Error,
                                contentDescription = stringResource(R.string.accessibility_verification_error_description),
                                modifier = Modifier.size(64.dp),
                                tint = MaterialTheme.colorScheme.error,
                            )
                            // A11Y-012a: Mark error heading so TalkBack users can
                            // navigate to it via heading gestures.
                            Text(
                                text = stringResource(R.string.verification_failed),
                                style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.error,
                                textAlign = TextAlign.Center,
                                modifier =
                                    Modifier
                                        .focusRequester(errorFocusRequester)
                                        .semantics {
                                            heading()
                                            liveRegion = LiveRegionMode.Assertive
                                        },
                            )
                            LaunchedEffect(Unit) {
                                delay(100)
                                try {
                                    errorFocusRequester.requestFocus()
                                } catch (_: Exception) {
                                }
                            }
                            AccessibleErrorBadge(
                                message = errorMessage ?: stringResource(R.string.verification_error_occurred),
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                AccessibleSecondaryButton(
                                    text = stringResource(R.string.action_cancel),
                                    modifier = Modifier.fillMaxWidth(),
                                    onClick = { navController.popBackStack() },
                                )
                                AccessiblePrimaryButton(
                                    text = stringResource(R.string.action_try_again),
                                    modifier = Modifier.fillMaxWidth(),
                                    onClick = {
                                        scanMode = ScanMode.SCANNING
                                        errorMessage = null
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (showManualEntry) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        AccessibleModalBottomSheet(
            onDismissRequest = { showManualEntry = false },
            sheetState = sheetState,
        ) {
            ManualEntrySheet(
                manualCode = manualCode,
                onManualCodeChange = { newValue ->
                    manualCode = newValue.filter { it.isDigit() }.take(12)
                    manualCodeError = null
                },
                onSubmit = { submitManualCode() },
                onDismiss = { showManualEntry = false },
                inputError = manualCodeError,
            )
        }
    }

    if (showCredentialPicker) {
        val pickerSheetState =
            rememberModalBottomSheetState(
                skipPartiallyExpanded = true,
                confirmValueChange = { it != SheetValue.Hidden },
            )
        AccessibleModalBottomSheet(
            onDismissRequest = {
                showCredentialPicker = false
                // If the user dismisses the picker without choosing, return to scanning
                if (pendingChallengeId != null) {
                    scanMode = ScanMode.SCANNING
                    pendingChallengeId = null
                }
            },
            sheetState = pickerSheetState,
        ) {
            app.provii.wallet.ui.components.CredentialPickerSheet(
                credentials = provableCredentials,
                onCredentialSelected = { selectedCredential ->
                    showCredentialPicker = false
                    val challengeId = pendingChallengeId
                    pendingChallengeId = null
                    if (challengeId != null) {
                        Timber.d("Credential selected: ${redactId(selectedCredential.id)}, resuming proof for challenge: ${redactId(challengeId)}")
                        proceedWithCredential(selectedCredential, challengeId)
                    }
                },
                onDismiss = {
                    showCredentialPicker = false
                    // Return to scanning if dismissed without selection
                    if (pendingChallengeId != null) {
                        scanMode = ScanMode.SCANNING
                        pendingChallengeId = null
                    }
                },
            )
        }
    }

    // Managed credential confirmation dialog
    if (showManagedConfirmation) {
        val managedName = pendingManagedCredential?.displayName ?: stringResource(R.string.credential_section_my_credential)
        AlertDialog(
            onDismissRequest = {
                showManagedConfirmation = false
                pendingManagedCredential = null
                // Return to scanning
                scanMode = ScanMode.SCANNING
                pendingChallengeId = null
            },
            title = { Text(stringResource(R.string.managed_confirm_title, managedName)) },
            text = { Text(stringResource(R.string.managed_confirm_message, managedName)) },
            confirmButton = {
                TextButton(onClick = {
                    showManagedConfirmation = false
                    val credential = pendingManagedCredential
                    val challengeId = pendingChallengeId
                    pendingManagedCredential = null
                    pendingChallengeId = null
                    if (credential != null && challengeId != null) {
                        continueProofWithCredential(credential.id, challengeId)
                    }
                }) {
                    Text(stringResource(R.string.managed_confirm_proceed, managedName))
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showManagedConfirmation = false
                    pendingManagedCredential = null
                    // Return to scanning
                    scanMode = ScanMode.SCANNING
                    pendingChallengeId = null
                }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }

    // Attestation QR redirect dialog
    if (showAttestationRedirectDialog) {
        AlertDialog(
            onDismissRequest = {
                showAttestationRedirectDialog = false
                pendingAttestationQrContent = null
            },
            title = { Text(stringResource(R.string.verification_wrong_qr_type_title)) },
            text = { Text(stringResource(R.string.verification_wrong_qr_type_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showAttestationRedirectDialog = false
                    pendingAttestationQrContent = null
                    navController.navigate(Screen.AttestationScanner.route) {
                        popUpTo(Screen.CredentialList.route) { inclusive = false }
                    }
                }) {
                    Text(stringResource(R.string.verification_go_to_attestation))
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showAttestationRedirectDialog = false
                    pendingAttestationQrContent = null
                }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

@Composable
private fun ManualEntrySheet(
    manualCode: String,
    onManualCodeChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit,
    inputError: String? = null,
) {
    val focusManager = LocalFocusManager.current
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .imePadding()
                .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            stringResource(R.string.manual_entry_title),
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Start,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            stringResource(R.string.manual_entry_verification_description),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        OutlinedTextField(
            value = manualCode,
            onValueChange = onManualCodeChange,
            label = { Text(stringResource(R.string.manual_entry_verification_code)) },
            singleLine = true,
            isError = inputError != null,
            supportingText =
                if (inputError != null) {
                    {
                        Text(
                            inputError,
                            modifier =
                                Modifier.semantics {
                                    liveRegion = LiveRegionMode.Assertive
                                },
                        )
                    }
                } else {
                    null
                },
            keyboardOptions =
                KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Done,
                    autoCorrect = false,
                ),
            keyboardActions =
                KeyboardActions(
                    onDone = {
                        focusManager.clearFocus()
                        if (manualCode.isNotBlank()) {
                            onSubmit()
                        }
                    },
                ),
            modifier = Modifier.fillMaxWidth(),
        )

        AccessiblePrimaryButton(
            text = stringResource(R.string.manual_entry_submit),
            onClick = onSubmit,
            modifier = Modifier.fillMaxWidth(),
            enabled = manualCode.isNotBlank(),
        )

        AccessibleSecondaryButton(
            text = stringResource(R.string.action_cancel),
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

private enum class ScanMode {
    SCANNING,
    PROCESSING,
    SUCCESS,
    ERROR,
}
