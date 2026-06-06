// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.verification

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import app.provii.wallet.data.AuthenticationRequiredException
import app.provii.wallet.data.WalletRepository
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.SheetValue
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.R
import app.provii.wallet.logging.redactId
import app.provii.wallet.security.SecurePreferencesManager
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.TimeoutBehavior
import app.provii.wallet.ui.components.accessibility.AccessibleModalBottomSheet
import app.provii.wallet.utils.ErrorMapper
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import timber.log.Timber

/**
 * Dedicated screen for handling verification from deep links (app-to-app flow).
 * This screen immediately processes the challenge without showing a QR scanner.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeepLinkVerificationScreen(
    navController: NavController,
    challengeData: String,
) {
    val walletRepository = LocalWalletRepository.current
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val accessibilityUiState = LocalAccessibilityUiState.current

    val resources = context.resources
    val preparingText = stringResource(R.string.deeplink_verification_preparing)
    val errorFailedChallengeText = stringResource(R.string.deeplink_verification_error_failed_challenge)
    val creatingProofText = stringResource(R.string.deeplink_verification_creating_proof)
    val errorNoAuthPromptText = stringResource(R.string.deeplink_verification_error_no_auth_prompt)
    val errorAuthCancelledText = stringResource(R.string.error_authentication_cancelled)
    val submittingProofText = stringResource(R.string.deeplink_verification_submitting_proof)
    val successText = stringResource(R.string.deeplink_verification_success)
    val errorVerificationFailedText = stringResource(R.string.deeplink_verification_error_verification_failed)
    val processingChallengeText = stringResource(R.string.deeplink_verification_processing_challenge)
    val checkingCredentialText = stringResource(R.string.deeplink_verification_checking_credential)
    val errorNoCredentialText = stringResource(R.string.deeplink_verification_error_no_credential)
    val errorNoCredentialSelectedText = stringResource(R.string.deeplink_verification_error_no_credential_selected)

    var verificationState by remember { mutableStateOf(VerificationState.PROCESSING) }
    var progressMessage by remember { mutableStateOf(preparingText) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Challenge state persisted across LaunchedEffects
    var pendingChallengeId by remember { mutableStateOf<String?>(null) }

    // Credential picker state
    var showCredentialPicker by remember { mutableStateOf(false) }
    var provableCredentials by remember { mutableStateOf<List<WalletRepository.CredentialPickerItem>>(emptyList()) }
    var selectedCredentialId by remember { mutableStateOf<String?>(null) }

    // Managed credential confirmation state
    var showManagedConfirmation by remember { mutableStateOf(false) }
    var pendingManagedCredential by remember { mutableStateOf<WalletRepository.CredentialPickerItem?>(null) }
    var managedConfirmed by remember { mutableStateOf(false) }

    // Track selected credential for context-aware messages
    var selectedCredentialName by remember { mutableStateOf<String?>(null) }
    var selectedCredentialIsManaged by remember { mutableStateOf(false) }

    // Parse proof_direction from challenge data for direction-aware UI
    val proofDirection =
        remember(challengeData) {
            try {
                val json = org.json.JSONObject(challengeData)
                json.optString("proof_direction", null)
            } catch (e: Exception) {
                null
            }
        }
    val ageFromChallenge =
        remember(challengeData) {
            try {
                val json = org.json.JSONObject(challengeData)
                val cutoffDays = json.optInt("cutoff_days", Int.MIN_VALUE)
                if (cutoffDays != Int.MIN_VALUE) Math.round(cutoffDays / 365.2425).toInt() else null
            } catch (e: Exception) {
                null
            }
        }

    /**
     * Once a credential is confirmed and a challengeId is known,
     * create the proof, submit it, and handle the result.
     *
     * Defensive: verifies that the wallet FFI layer is ready before
     * attempting proof generation. After process death the Rust SDK
     * may not have re-initialised yet; calling into it would crash.
     */
    fun continueProofWithCredential(
        credentialId: String,
        challengeId: String,
    ) {
        coroutineScope.launch {
            try {
                // Guard: ensure wallet FFI is initialised in the current process
                if (!walletRepository.isReady.value) {
                    Timber.e("continueProofWithCredential: wallet is not ready")
                    errorMessage = errorFailedChallengeText
                    verificationState = VerificationState.ERROR
                    return@launch
                }

                verificationState = VerificationState.PROCESSING
                progressMessage =
                    if (selectedCredentialIsManaged && selectedCredentialName != null) {
                        resources.getString(R.string.verification_creating_proof_for, selectedCredentialName)
                    } else {
                        creatingProofText
                    }
                delay(500)

                val activity = context as? FragmentActivity
                if (activity == null) {
                    Timber.e("Cannot get FragmentActivity for authentication")
                    errorMessage = errorNoAuthPromptText
                    verificationState = VerificationState.ERROR
                    return@launch
                }

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
                    verificationState = VerificationState.ERROR
                    return@launch
                }

                val proofJson = proofResult.getOrThrow()
                Timber.d("Proof created, size: ${proofJson.length}")

                progressMessage = submittingProofText
                delay(300)

                val submitResult = walletRepository.submitProof(proofJson)

                if (submitResult.isSuccess && submitResult.getOrThrow()) {
                    Timber.d("Verification successful!")
                    progressMessage = successText
                    verificationState = VerificationState.SUCCESS

                    if (!accessibilityUiState.settings.disableAutoContextChanges) {
                        val autoReturnDelay = if (accessibilityUiState.settings.timeoutBehavior == TimeoutBehavior.EXTENDED) 3000L else 1500L
                        delay(autoReturnDelay)
                        returnToBrowser(context)
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
                    verificationState = VerificationState.ERROR
                }
            } catch (e: Exception) {
                Timber.e(e, "Unexpected error during proof creation/submission")
                errorMessage = ErrorMapper.mapToUserMessage(e, context)
                verificationState = VerificationState.ERROR
            }
        }
    }

    /**
     * Proceed with a credential after selection, showing confirmation for managed credentials
     * or continuing directly to proof creation.
     */
    fun proceedWithCredential(
        credential: WalletRepository.CredentialPickerItem,
        challengeId: String,
    ) {
        selectedCredentialName = credential.displayName
        selectedCredentialIsManaged = credential.isManaged
        if (credential.isManaged) {
            pendingManagedCredential = credential
            pendingChallengeId = challengeId
            showManagedConfirmation = true
        } else {
            continueProofWithCredential(credential.id, challengeId)
        }
    }

    // Step 1: Process the challenge and resolve credentials
    LaunchedEffect(challengeData) {
        try {
            Timber.d("DeepLinkVerification: Starting verification process")
            Timber.d("Challenge data length: ${challengeData.length}")

            verificationState = VerificationState.PROCESSING
            progressMessage = processingChallengeText
            delay(300)

            val challengeResult = walletRepository.processVerificationChallenge(challengeData)
            if (challengeResult.isFailure) {
                val error = challengeResult.exceptionOrNull()
                Timber.e("Failed to process challenge: ${error?.message}")
                errorMessage =
                    if (error != null) {
                        ErrorMapper.mapToUserMessage(error, context)
                    } else {
                        errorFailedChallengeText
                    }
                verificationState = VerificationState.ERROR
                return@LaunchedEffect
            }

            val challengeId = challengeResult.getOrThrow()
            Timber.d("Challenge processed, ID: ${redactId(challengeId)}")

            progressMessage = checkingCredentialText
            delay(300)

            val credentials = walletRepository.getPickerCredentials()
            Timber.d("Found ${credentials.size} provable credential(s)")

            when {
                credentials.isEmpty() -> {
                    Timber.e("No provable credentials found")
                    errorMessage = errorNoCredentialText
                    verificationState = VerificationState.ERROR
                }
                credentials.size == 1 -> {
                    Timber.d("Single provable credential found: ${redactId(credentials[0].id)}")
                    proceedWithCredential(credentials[0], challengeId)
                }
                else -> {
                    Timber.d("Multiple provable credentials found, showing picker")
                    provableCredentials = credentials
                    pendingChallengeId = challengeId
                    verificationState = VerificationState.SELECTING_CREDENTIAL
                    showCredentialPicker = true
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "Unexpected error during verification")
            errorMessage = ErrorMapper.mapToUserMessage(e, context)
            verificationState = VerificationState.ERROR
        }
    }

    // Step 2: Resume when user selects a credential from the picker
    LaunchedEffect(selectedCredentialId) {
        val chosen = selectedCredentialId ?: return@LaunchedEffect
        val challengeId = pendingChallengeId ?: return@LaunchedEffect
        pendingChallengeId = null
        Timber.d("User selected credential: ${redactId(chosen)}")
        val credential = provableCredentials.firstOrNull { it.id == chosen } ?: return@LaunchedEffect
        proceedWithCredential(credential, challengeId)
    }

    // Step 3: Resume when user confirms managed credential dialog
    LaunchedEffect(managedConfirmed) {
        if (!managedConfirmed) return@LaunchedEffect
        managedConfirmed = false
        val credential = pendingManagedCredential ?: return@LaunchedEffect
        val challengeId = pendingChallengeId ?: return@LaunchedEffect
        pendingManagedCredential = null
        pendingChallengeId = null
        continueProofWithCredential(credential.id, challengeId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        when (verificationState) {
                            VerificationState.PROCESSING -> stringResource(R.string.deeplink_verification_title_verifying)
                            VerificationState.SELECTING_CREDENTIAL -> stringResource(R.string.deeplink_verification_title_verifying)
                            VerificationState.SUCCESS -> stringResource(R.string.deeplink_verification_title_verified)
                            VerificationState.ERROR -> stringResource(R.string.deeplink_verification_title_failed)
                        },
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor =
                            when (verificationState) {
                                VerificationState.SUCCESS -> MaterialTheme.colorScheme.primaryContainer
                                VerificationState.ERROR -> MaterialTheme.colorScheme.errorContainer
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
            when (verificationState) {
                VerificationState.PROCESSING -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp),
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(64.dp),
                            color = MaterialTheme.colorScheme.primary,
                            strokeWidth = 4.dp,
                        )
                        Spacer(modifier = Modifier.height(32.dp))
                        Text(
                            text = progressMessage,
                            style = MaterialTheme.typography.headlineSmall,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = stringResource(R.string.deeplink_verification_please_wait),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                        )
                    }
                }

                VerificationState.SELECTING_CREDENTIAL -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp),
                    ) {
                        Icon(
                            Icons.Default.Badge,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Text(
                            text = stringResource(R.string.deeplink_verification_select_credential_title),
                            style = MaterialTheme.typography.headlineMedium,
                            textAlign = TextAlign.Center,
                            modifier =
                                Modifier.semantics {
                                    heading()
                                    liveRegion = LiveRegionMode.Polite
                                },
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = stringResource(R.string.deeplink_verification_select_credential_subtitle),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                        )
                    }
                }

                VerificationState.SUCCESS -> {
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
                        Text(
                            text =
                                if (selectedCredentialIsManaged && selectedCredentialName != null) {
                                    stringResource(R.string.deeplink_verification_age_verified_for, selectedCredentialName as Any)
                                } else if (proofDirection == "under_age" && ageFromChallenge != null) {
                                    resources.getString(R.string.deeplink_verification_under_age_verified, ageFromChallenge)
                                } else {
                                    stringResource(R.string.deeplink_verification_age_verified)
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

                        // Show appropriate message/button based on auto-context-change preference
                        if (!accessibilityUiState.settings.disableAutoContextChanges) {
                            Text(
                                text = stringResource(R.string.deeplink_verification_returning_browser),
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                            )
                        } else {
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = { returnToBrowser(context) },
                                modifier = Modifier.fillMaxWidth(0.7f),
                            ) {
                                Text(stringResource(R.string.deeplink_verification_return_to_browser))
                            }
                        }
                    }
                }

                VerificationState.ERROR -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp),
                    ) {
                        Icon(
                            Icons.Default.Error,
                            contentDescription = stringResource(R.string.accessibility_verification_error_description),
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Text(
                            text = stringResource(R.string.deeplink_verification_failed_title),
                            style = MaterialTheme.typography.headlineMedium,
                            color = MaterialTheme.colorScheme.error,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = errorMessage ?: stringResource(R.string.deeplink_verification_error_occurred),
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                        )
                        Spacer(modifier = Modifier.height(32.dp))

                        Button(
                            onClick = { returnToBrowser(context) },
                            modifier = Modifier.fillMaxWidth(0.6f),
                        ) {
                            Text(stringResource(R.string.deeplink_verification_return_to_browser))
                        }
                    }
                }
            }
        }
    }

    // Credential picker bottom sheet
    if (showCredentialPicker) {
        val sheetState =
            rememberModalBottomSheetState(
                skipPartiallyExpanded = true,
                confirmValueChange = { it != SheetValue.Hidden },
            )
        AccessibleModalBottomSheet(
            onDismissRequest = {
                showCredentialPicker = false
                if (selectedCredentialId == null) {
                    Timber.d("User dismissed credential picker without selecting")
                    errorMessage = errorNoCredentialSelectedText
                    verificationState = VerificationState.ERROR
                    pendingChallengeId = null
                }
            },
            sheetState = sheetState,
        ) {
            app.provii.wallet.ui.components.CredentialPickerSheet(
                credentials = provableCredentials,
                onCredentialSelected = { credential ->
                    selectedCredentialId = credential.id
                    showCredentialPicker = false
                },
                onDismiss = {
                    showCredentialPicker = false
                    if (selectedCredentialId == null) {
                        Timber.d("User dismissed credential picker without selecting")
                        errorMessage = errorNoCredentialSelectedText
                        verificationState = VerificationState.ERROR
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
                pendingChallengeId = null
                errorMessage = errorNoCredentialSelectedText
                verificationState = VerificationState.ERROR
            },
            title = { Text(stringResource(R.string.managed_confirm_title, managedName)) },
            text = { Text(stringResource(R.string.managed_confirm_message, managedName)) },
            confirmButton = {
                TextButton(onClick = {
                    showManagedConfirmation = false
                    managedConfirmed = true
                }) {
                    Text(stringResource(R.string.managed_confirm_proceed, managedName))
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showManagedConfirmation = false
                    pendingManagedCredential = null
                    pendingChallengeId = null
                    errorMessage = errorNoCredentialSelectedText
                    verificationState = VerificationState.ERROR
                }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

/**
 * Return to the browser by finishing the activity
 * MASVS-CODE-1: Uses EncryptedSharedPreferences via SecurePreferencesManager
 */
private fun returnToBrowser(context: Context) {
    Timber.d("Returning to browser...")

    // MASVS-CODE-1: Mark that we're returning after verification using secure storage
    val securePrefs = SecurePreferencesManager(context)
    securePrefs.setVerificationCompleted(true)

    // Finish the activity to return to browser
    (context as? Activity)?.finish()
}

private enum class VerificationState {
    PROCESSING,
    SELECTING_CREDENTIAL,
    SUCCESS,
    ERROR,
}
