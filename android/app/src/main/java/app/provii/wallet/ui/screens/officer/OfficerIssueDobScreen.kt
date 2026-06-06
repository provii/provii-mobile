// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.officer

import app.provii.wallet.officer.OfficerAuthManager
import android.app.DatePickerDialog
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import app.provii.wallet.LocalNavigationPayloadStore
import app.provii.wallet.LocalOfficerAuthManager
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem
import app.provii.wallet.ui.theme.buttonFocusIndicator
import kotlinx.coroutines.launch
import timber.log.Timber
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter
import java.util.Calendar

/**
 * Officer-facing screen for entering the holder's date of birth, completing a verification
 * checklist, and initiating attestation creation via YubiKey NFC touch. Displays a modal
 * dialog during YubiKey interaction and navigates to the attestation QR screen on success.
 * DOB is used only for the Ed25519-signed attestation and is never stored locally.
 */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OfficerIssueDobScreen(navController: NavController) {
    val context = LocalContext.current
    val officerAuthManager = LocalOfficerAuthManager.current
    val navigationPayloadStore = LocalNavigationPayloadStore.current
    val coroutineScope = rememberCoroutineScope()

    val issuanceState by officerAuthManager.issuanceState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    var selectedDob by remember { mutableStateOf<LocalDate?>(null) }
    var documentVerified by remember { mutableStateOf(false) }
    var dobMatches by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showSessionExpiryDialog by remember { mutableStateOf(false) }
    var restoredFromPreservedData by remember { mutableStateOf(false) }

    val sessionExpiryWarning by officerAuthManager.sessionExpiryWarning.collectAsStateWithLifecycle()
    val timeUntilExpiry by officerAuthManager.timeUntilExpiry.collectAsStateWithLifecycle()

    // Restore preserved data on first composition
    LaunchedEffect(Unit) {
        val preserved = officerAuthManager.restoreIssuanceData()
        if (preserved != null && officerAuthManager.getSessionInfo() != null) {
            // Restore form state: reconstruct LocalDate from dobDays
            preserved.dobDays?.let { days ->
                selectedDob = LocalDate.ofEpochDay(days.toLong())
            }
            documentVerified = preserved.documentVerified
            dobMatches = preserved.dobMatches
            restoredFromPreservedData = true

            // Clear preserved data after successful restoration
            officerAuthManager.clearPreservedData()
        } else if (preserved != null) {
            // Preserved data exists but no active session, clear it
            officerAuthManager.clearPreservedData()
        }
    }

    // Show session expiry warning dialog and announce to screen reader
    LaunchedEffect(sessionExpiryWarning) {
        if (sessionExpiryWarning) {
            showSessionExpiryDialog = true
        }
    }

    // Accessibility: Announce session expiry warning
    if (sessionExpiryWarning && showSessionExpiryDialog) {
        Text(
            text = stringResource(R.string.officer_session_expiring_announcement, timeUntilExpiry ?: 0L),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Assertive
                    },
        )
    }

    fun showDatePicker() {
        val today = Calendar.getInstance()
        val year = today.get(Calendar.YEAR) - 18
        val month = today.get(Calendar.MONTH)
        val day = today.get(Calendar.DAY_OF_MONTH)

        DatePickerDialog(
            context,
            { _, selectedYear, selectedMonth, selectedDay ->
                selectedDob = LocalDate.of(selectedYear, selectedMonth + 1, selectedDay)
                errorMessage = null
            },
            year,
            month,
            day,
        ).apply {
            datePicker.maxDate = System.currentTimeMillis()
            val minDate = Calendar.getInstance()
            minDate.add(Calendar.YEAR, -120)
            datePicker.minDate = minDate.timeInMillis
        }.show()
    }

    val age =
        selectedDob?.let {
            Period.between(it, LocalDate.now()).years
        }

    val formattedDob = selectedDob?.format(DateTimeFormatter.ofPattern("MMMM d, yyyy"))

    // Show session expiry warning dialog
    if (showSessionExpiryDialog) {
        val preservationFailedMessage = stringResource(R.string.officer_preservation_failed)
        AccessibleAlertDialog(
            onDismissRequest = { showSessionExpiryDialog = false }, // WCAG 2.1.2: Allow dismiss
            title = { Text(stringResource(R.string.officer_session_expiring)) },
            text = {
                Text(stringResource(R.string.officer_session_expiring_message, timeUntilExpiry ?: 0L))
            },
            confirmButton = {
                Button(
                    onClick = {
                        coroutineScope.launch {
                            val dobDays = selectedDob?.toEpochDay()?.toInt()
                            val preserved =
                                officerAuthManager.preserveIssuanceData(
                                    dobDays = dobDays,
                                    documentVerified = documentVerified,
                                    dobMatches = dobMatches,
                                )
                            if (preserved) {
                                showSessionExpiryDialog = false
                            } else {
                                snackbarHostState.showSnackbar(
                                    message = preservationFailedMessage,
                                    duration = SnackbarDuration.Long,
                                )
                                // Dialog stays open so the officer can try again or discard
                            }
                        }
                    },
                ) {
                    Text(stringResource(R.string.officer_save_and_continue))
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showSessionExpiryDialog = false },
                ) {
                    Text(stringResource(R.string.officer_continue_without_saving))
                }
            },
        )
    }

    // Show Yubikey touch dialog when needed
    when (val state = issuanceState) {
        is OfficerAuthManager.IssuanceState.WaitingForYubikeyTouch -> {
            YubikeyTouchDialog(
                message = state.message,
                onCancel = { officerAuthManager.resetIssuance() }, // WCAG 2.1.2: Allow escape
            )
        }
        is OfficerAuthManager.IssuanceState.Complete -> {
            LaunchedEffect(state) {
                // Store attestation in the payload store so the route string never
                // carries raw base64 attestation data.
                val payloadKey = navigationPayloadStore.put(state.attestationB64)
                navController.navigate("officer_show_attestation/$payloadKey")
            }
        }
        else -> {}
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.officer_issue_credential)) },
                navigationIcon = {
                    IconButton(onClick = {
                        officerAuthManager.resetIssuance()
                        navController.popBackStack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.accessibility_officer_back_description))
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
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
                    ),
                onNavigate = { index ->
                    when (index) {
                        0 -> {
                            officerAuthManager.resetIssuance()
                            navController.navigate("officer_dashboard") {
                                popUpTo("officer_dashboard") { inclusive = false }
                            }
                        }
                    }
                },
            )

            Column(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(24.dp),
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Default.Badge,
                        contentDescription = null, // Decorative - next to heading text
                        modifier = Modifier.size(32.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = stringResource(R.string.officer_verify_identity),
                        style = MaterialTheme.typography.headlineSmall,
                        modifier = Modifier.semantics { heading() },
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Date selection
                Card(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .semantics {
                                if (selectedDob != null) {
                                    liveRegion = LiveRegionMode.Polite
                                }
                            },
                    colors =
                        CardDefaults.cardColors(
                            containerColor =
                                if (selectedDob != null) {
                                    MaterialTheme.colorScheme.primaryContainer
                                } else {
                                    MaterialTheme.colorScheme.surfaceVariant
                                },
                        ),
                ) {
                    Column(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        if (selectedDob == null) {
                            OutlinedButton(
                                onClick = { showDatePicker() },
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Icon(Icons.Default.CalendarToday, contentDescription = null) // Decorative - button has text label
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(stringResource(R.string.officer_select_dob))
                            }
                        } else {
                            Text(
                                text = stringResource(R.string.officer_dob_label),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant, // WCAG 1.4.3: Full contrast
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = formattedDob ?: "",
                                style = MaterialTheme.typography.headlineMedium,
                                fontWeight = FontWeight.Bold,
                            )
                            Text(
                                text = selectedDob?.format(DateTimeFormatter.ISO_LOCAL_DATE) ?: "",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant, // WCAG 1.4.3: Full contrast
                            )

                            age?.let {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = stringResource(R.string.officer_age_format, it),
                                    style = MaterialTheme.typography.titleMedium,
                                    color =
                                        if (it >= 18) {
                                            MaterialTheme.colorScheme.onPrimaryContainer
                                        } else {
                                            MaterialTheme.colorScheme.error
                                        },
                                    fontWeight = FontWeight.Medium,
                                )
                            }

                            Spacer(modifier = Modifier.height(12.dp))
                            TextButton(onClick = { showDatePicker() }) {
                                Text(stringResource(R.string.officer_change_date))
                            }
                        }
                    }
                }

                if (age != null && age < 18) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Card(
                        colors =
                            CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                            ),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Default.Info,
                                contentDescription = null, // Decorative - info described by adjacent text
                                tint = MaterialTheme.colorScheme.onTertiaryContainer,
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = stringResource(R.string.officer_under_18_full_warning),
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Verification checklist
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = stringResource(R.string.officer_verification_checklist_header),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, // WCAG 1.4.3: Full contrast
                        )

                        Spacer(modifier = Modifier.height(16.dp))

                        Row(
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .semantics(mergeDescendants = true) {},
                            // WCAG: Associate checkbox with label
                            verticalAlignment = Alignment.Top,
                        ) {
                            val checkedLabel = stringResource(R.string.accessibility_state_checked)
                            val uncheckedLabel = stringResource(R.string.accessibility_state_unchecked)
                            val checkboxState = if (documentVerified) checkedLabel else uncheckedLabel
                            Checkbox(
                                checked = documentVerified,
                                onCheckedChange = { documentVerified = it },
                                enabled =
                                    selectedDob != null &&
                                        issuanceState !is OfficerAuthManager.IssuanceState.ValidatingInput &&
                                        issuanceState !is OfficerAuthManager.IssuanceState.CreatingAttestation &&
                                        issuanceState !is OfficerAuthManager.IssuanceState.WaitingForYubikeyTouch,
                                modifier =
                                    Modifier.semantics {
                                        role = Role.Checkbox
                                        stateDescription = checkboxState
                                    },
                            )
                            Column(modifier = Modifier.padding(start = 8.dp)) {
                                Text(
                                    text = stringResource(R.string.officer_physical_document_verified),
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontWeight = FontWeight.Medium,
                                )
                                Text(
                                    text = stringResource(R.string.officer_sighted_valid_id),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .semantics(mergeDescendants = true) {},
                            // WCAG: Associate checkbox with label
                            verticalAlignment = Alignment.Top,
                        ) {
                            val dobCheckedLabel = stringResource(R.string.accessibility_state_checked)
                            val dobUncheckedLabel = stringResource(R.string.accessibility_state_unchecked)
                            val dobCheckboxState = if (dobMatches) dobCheckedLabel else dobUncheckedLabel
                            Checkbox(
                                checked = dobMatches,
                                onCheckedChange = { dobMatches = it },
                                enabled =
                                    selectedDob != null &&
                                        issuanceState !is OfficerAuthManager.IssuanceState.ValidatingInput &&
                                        issuanceState !is OfficerAuthManager.IssuanceState.CreatingAttestation &&
                                        issuanceState !is OfficerAuthManager.IssuanceState.WaitingForYubikeyTouch,
                                modifier =
                                    Modifier.semantics {
                                        role = Role.Checkbox
                                        stateDescription = dobCheckboxState
                                    },
                            )
                            Column(modifier = Modifier.padding(start = 8.dp)) {
                                Text(
                                    text = stringResource(R.string.officer_dob_matches_exactly),
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontWeight = FontWeight.Medium,
                                )
                                if (selectedDob != null) {
                                    Text(
                                        text = stringResource(R.string.officer_dob_on_document, formattedDob ?: ""),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                }
                            }
                        }
                    }
                }

                // State-based overlay dialogs (Error, ValidatingInput, CreatingAttestation)
                // Rendered as overlays rather than inline cards to avoid pushing the issue
                // button off-screen on smaller devices.
                when (val state = issuanceState) {
                    is OfficerAuthManager.IssuanceState.Error -> {
                        Dialog(
                            onDismissRequest = { officerAuthManager.resetIssuance() },
                            properties =
                                DialogProperties(
                                    dismissOnBackPress = true,
                                    dismissOnClickOutside = true,
                                ),
                        ) {
                            Card(
                                modifier =
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                colors =
                                    CardDefaults.cardColors(
                                        containerColor = MaterialTheme.colorScheme.surface,
                                    ),
                                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                            ) {
                                Column(
                                    modifier = Modifier.padding(24.dp),
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Icon(
                                            Icons.Default.Error,
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.error,
                                        )
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            text = stringResource(R.string.officer_error_label),
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onSurface,
                                        )
                                    }
                                    Spacer(modifier = Modifier.height(12.dp))
                                    Text(
                                        text = state.message,
                                        color = MaterialTheme.colorScheme.onSurface,
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                                    )
                                    if (state.canRetry) {
                                        Spacer(modifier = Modifier.height(16.dp))
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.End,
                                        ) {
                                            TextButton(
                                                onClick = { officerAuthManager.resetIssuance() },
                                            ) {
                                                Text(stringResource(R.string.action_try_again))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    is OfficerAuthManager.IssuanceState.ValidatingInput -> {
                        Dialog(
                            onDismissRequest = { /* non-dismissable during validation */ },
                            properties =
                                DialogProperties(
                                    dismissOnBackPress = false,
                                    dismissOnClickOutside = false,
                                ),
                        ) {
                            Card(
                                modifier =
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                colors =
                                    CardDefaults.cardColors(
                                        containerColor = MaterialTheme.colorScheme.surface,
                                    ),
                                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                            ) {
                                Row(
                                    modifier = Modifier.padding(24.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 2.dp,
                                    )
                                    Spacer(modifier = Modifier.width(16.dp))
                                    Text(
                                        text = stringResource(R.string.officer_state_validating),
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )
                                }
                            }
                        }
                    }
                    is OfficerAuthManager.IssuanceState.CreatingAttestation -> {
                        Dialog(
                            onDismissRequest = { /* non-dismissable during creation */ },
                            properties =
                                DialogProperties(
                                    dismissOnBackPress = false,
                                    dismissOnClickOutside = false,
                                ),
                        ) {
                            Card(
                                modifier =
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                colors =
                                    CardDefaults.cardColors(
                                        containerColor = MaterialTheme.colorScheme.surface,
                                    ),
                                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                            ) {
                                Row(
                                    modifier = Modifier.padding(24.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 2.dp,
                                    )
                                    Spacer(modifier = Modifier.width(16.dp))
                                    Text(
                                        text = stringResource(R.string.officer_state_creating_attestation),
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )
                                }
                            }
                        }
                    }
                    else -> {}
                }

                Spacer(modifier = Modifier.weight(1f))

                // Issue button
                Button(
                    onClick = {
                        coroutineScope.launch {
                            selectedDob?.let { dob ->
                                val dobIso = dob.format(DateTimeFormatter.ISO_LOCAL_DATE)
                                val dobDays = dob.toEpochDay().toInt()

                                // Preserve data before starting issuance (in case of error/timeout).
                                // A failure here does not block issuance; the officer loses
                                // the ability to restore state on retry but can re-enter details.
                                val preIssuancePreserved =
                                    officerAuthManager.preserveIssuanceData(
                                        dobDays = dobDays,
                                        documentVerified = documentVerified,
                                        dobMatches = dobMatches,
                                    )
                                if (!preIssuancePreserved) {
                                    Timber.w("OfficerIssueDobScreen: pre-issuance preservation failed; proceeding with attestation")
                                }

                                // Create attestation - officer ID is retrieved from storage
                                // (set during authenticateOfficer in OfficerEntryScreen)
                                val result =
                                    officerAuthManager.createAttestation(
                                        dobIso = dobIso,
                                        documentVerified = documentVerified,
                                        dobMatches = dobMatches,
                                    )

                                // Clear preserved data on success
                                if (result.isSuccess) {
                                    officerAuthManager.clearPreservedData()
                                }
                                // On failure, preserved data remains for retry
                            }
                        }
                    },
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(56.dp),
                    enabled =
                        selectedDob != null &&
                            documentVerified &&
                            dobMatches &&
                            issuanceState !is OfficerAuthManager.IssuanceState.ValidatingInput &&
                            issuanceState !is OfficerAuthManager.IssuanceState.CreatingAttestation &&
                            issuanceState !is OfficerAuthManager.IssuanceState.WaitingForYubikeyTouch &&
                            issuanceState !is OfficerAuthManager.IssuanceState.Complete,
                ) {
                    val issuingCredentialLabel = stringResource(R.string.accessibility_issuing_credential)
                    when (issuanceState) {
                        is OfficerAuthManager.IssuanceState.ValidatingInput,
                        is OfficerAuthManager.IssuanceState.CreatingAttestation,
                        is OfficerAuthManager.IssuanceState.WaitingForYubikeyTouch,
                        -> {
                            // A11Y-009a: Announce spinner state to TalkBack
                            CircularProgressIndicator(
                                modifier =
                                    Modifier.size(20.dp).semantics {
                                        contentDescription = issuingCredentialLabel
                                        liveRegion = LiveRegionMode.Polite
                                    },
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.onPrimary,
                            )
                        }
                        else -> {
                            Icon(Icons.Default.Check, contentDescription = null) // Decorative - button has text label
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(stringResource(R.string.officer_issue_credential))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
) {
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
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
            )
            Spacer(modifier = Modifier.width(12.dp))
            Icon(
                icon,
                contentDescription = null, // Decorative - status described by adjacent text
                modifier = Modifier.size(20.dp),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = text,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
    }
}

@Composable
private fun YubikeyTouchDialog(
    message: String,
    onCancel: () -> Unit, // WCAG 2.1.2: Allow user to escape dialog
) {
    Dialog(
        onDismissRequest = onCancel, // WCAG 2.1.2: Allow dismissal via back button
        properties =
            DialogProperties(
                dismissOnBackPress = true, // WCAG 2.1.2: Allow back button to cancel
                dismissOnClickOutside = false, // Keep this to prevent accidental dismissal
            ),
    ) {
        Card(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        ) {
            Column(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Animated Yubikey icon
                YubikeyIcon()

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = stringResource(R.string.yubikey_authentication),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Indeterminate progress indicator for single-step authentication
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth(),
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.primaryContainer,
                )

                Spacer(modifier = Modifier.height(24.dp))

                Card(
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                        ),
                ) {
                    Row(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        Icon(
                            Icons.Default.Info,
                            contentDescription = null, // Decorative - info described by adjacent text
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.yubikey_led_should_blink),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // WCAG 2.1.2: Provide cancel option to escape modal
                // A11Y-013a: Ensure 48dp minimum touch target
                TextButton(
                    onClick = onCancel,
                    modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .buttonFocusIndicator(),
                ) {
                    Text(stringResource(R.string.action_cancel))
                }
            }
        }
    }
}

@Composable
private fun YubikeyIcon() {
    // WCAG 2.3.2: LED blink at 0.5Hz (<3Hz limit) with reduced alpha range to minimise flash intensity
    // WCAG 2.3.3: All animations disabled when reduce motion is enabled
    // Note: Physical YubiKey LED behaviour is hardware-controlled and cannot be modified by software
    val accessibilityUiState = LocalAccessibilityUiState.current
    val reduceMotion = accessibilityUiState.settings.reduceMotion || accessibilityUiState.prefersReducedMotion

    val infiniteTransition = rememberInfiniteTransition()
    val animatedScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.1f,
        animationSpec =
            infiniteRepeatable(
                animation =
                    tween(
                        durationMillis = 1000,
                        easing = FastOutSlowInEasing,
                    ),
                repeatMode = RepeatMode.Reverse,
            ),
    )
    val scale = if (reduceMotion) 1f else animatedScale

    Box(
        modifier = Modifier.size(80.dp),
        contentAlignment = Alignment.Center,
    ) {
        // Pulsing background
        Box(
            modifier =
                Modifier
                    .size(80.dp)
                    .scale(scale)
                    .background(
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
                        shape = CircleShape,
                    ),
        )

        // Key icon
        Icon(
            Icons.Default.VpnKey,
            contentDescription = null, // Decorative - part of animated Yubikey indicator
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.primary,
        )

        // Blinking dot to simulate LED
        // WCAG 2.3.2: Reduced flash frequency to <3Hz and limited alpha range to reduce intensity
        val animatedAlpha by infiniteTransition.animateFloat(
            initialValue = 0.4f,
            targetValue = 0.8f,
            animationSpec =
                infiniteRepeatable(
                    animation =
                        tween(
                            durationMillis = 1000,
                            easing = LinearEasing,
                        ),
                    repeatMode = RepeatMode.Reverse,
                ),
        )
        val alpha = if (reduceMotion) 0.6f else animatedAlpha

        Box(
            modifier =
                Modifier
                    .align(Alignment.TopEnd)
                    .size(12.dp)
                    .background(
                        color = Color.Green.copy(alpha = alpha),
                        shape = CircleShape,
                    ),
        )
    }
}
