// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.credentials

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.R
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.ui.theme.buttonFocusIndicator
import app.provii.wallet.ui.theme.circularFocusIndicator
import kotlinx.coroutines.launch

/**
 * Displays the detail view for a single stored credential, showing its nickname, type
 * indicator, and management controls. Supports inline nickname editing with confirmation
 * and credential deletion with an accessible confirmation dialog. TalkBack announces
 * managed credentials with a generic label to protect child name privacy.
 */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CredentialDetailScreen(
    navController: NavController,
    credentialId: String,
) {
    val walletRepository = LocalWalletRepository.current
    val credentialState by walletRepository.credentialState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    val saveErrorText = stringResource(R.string.credential_detail_save_error)
    val savingText = stringResource(R.string.accessibility_saving)
    val deletingText = stringResource(R.string.accessibility_deleting)
    val deleteErrorText = stringResource(R.string.credential_detail_delete_error)

    // Find the credential in state
    val credential =
        remember(credentialState, credentialId) {
            when (val state = credentialState) {
                is WalletRepository.CredentialState.HasCredentials -> {
                    if (state.primary?.id == credentialId) {
                        state.primary
                    } else {
                        state.managed.find { it.id == credentialId }
                    }
                }
                else -> null
            }
        }

    // Nickname editing state
    var isEditingNickname by remember { mutableStateOf(false) }
    var editedNickname by remember(credential) { mutableStateOf(credential?.nickname ?: "") }
    var isSaving by remember { mutableStateOf(false) }

    // Delete confirmation state
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    var isDeleting by remember { mutableStateOf(false) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(stringResource(R.string.credential_detail_title))
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                },
            )
        },
    ) { paddingValues ->
        if (credential == null) {
            // Credential not found (might have been deleted)
            Box(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(R.string.credential_detail_not_found))
            }
            return@Scaffold
        }

        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .verticalScroll(rememberScrollState())
                    .padding(24.dp),
        ) {
            // Credential type badge
            val typeLabel =
                if (credential.isManaged) {
                    stringResource(R.string.credential_type_managed)
                } else {
                    stringResource(R.string.credential_type_primary)
                }

            // Issue 19: Differentiate managed icon background colour
            val containerColor = if (credential.isManaged) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.primaryContainer
            val contentColor = if (credential.isManaged) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onPrimaryContainer

            Row(
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(56.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(containerColor),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (credential.isManaged) Icons.Outlined.ChildCare else Icons.Outlined.Badge,
                        contentDescription = null,
                        modifier = Modifier.size(32.dp),
                        tint = contentColor,
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column {
                    // Issue 5: Use generic heading for managed credentials to protect child name
                    val headingLabel = if (credential.isManaged) stringResource(R.string.credential_type_managed) else (credential.displayName ?: stringResource(R.string.credential_section_my_credential))
                    Text(
                        text = headingLabel,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.semantics { heading() },
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    // Issue 20: Non-interactive label instead of SuggestionChip with empty onClick
                    Text(
                        text = typeLabel,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier =
                            Modifier
                                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp))
                                .padding(horizontal = 12.dp, vertical = 4.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Nickname section (editable for managed credentials)
            if (credential.isManaged) {
                // A11Y-004a: Subsection label needs heading semantics so TalkBack
                // users can navigate between sections using heading gestures.
                Text(
                    text = stringResource(R.string.credential_detail_nickname),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.semantics { heading() },
                )
                Spacer(modifier = Modifier.height(8.dp))

                if (isEditingNickname) {
                    OutlinedTextField(
                        value = editedNickname,
                        onValueChange = { if (it.length <= 30) editedNickname = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        enabled = !isSaving,
                        label = { Text(stringResource(R.string.credential_detail_nickname)) },
                        supportingText = { Text("${editedNickname.length}/30") },
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                    ) {
                        TextButton(
                            onClick = {
                                isEditingNickname = false
                                editedNickname = credential.nickname ?: ""
                            },
                            enabled = !isSaving,
                        ) {
                            Text(stringResource(R.string.action_cancel))
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        // A11Y-007a: Focus indicator for keyboard/switch navigation
                        Button(
                            onClick = {
                                isSaving = true
                                scope.launch {
                                    val newNickname = editedNickname.trim().ifEmpty { null }
                                    val result =
                                        walletRepository.updateCredentialNickname(
                                            credentialId,
                                            newNickname,
                                        )
                                    isSaving = false
                                    if (result.isSuccess) {
                                        isEditingNickname = false
                                    } else {
                                        snackbarHostState.showSnackbar(
                                            saveErrorText,
                                        )
                                    }
                                }
                            },
                            enabled = !isSaving,
                            modifier = Modifier.buttonFocusIndicator(),
                        ) {
                            if (isSaving) {
                                // A11Y-002a: Announce spinner to TalkBack via liveRegion
                                CircularProgressIndicator(
                                    modifier =
                                        Modifier.size(16.dp).semantics {
                                            contentDescription = savingText
                                            liveRegion = LiveRegionMode.Polite
                                        },
                                    strokeWidth = 2.dp,
                                )
                            } else {
                                Text(stringResource(R.string.action_save))
                            }
                        }
                    }
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = credential.nickname ?: stringResource(R.string.credential_detail_no_nickname),
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(
                            onClick = { isEditingNickname = true },
                            modifier = Modifier.circularFocusIndicator(),
                        ) {
                            Icon(
                                Icons.Default.Edit,
                                contentDescription = stringResource(R.string.credential_detail_edit_nickname),
                            )
                        }
                    }
                }

                HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))
            }

            // Status
            DetailRow(
                label = stringResource(R.string.credential_detail_status),
                value =
                    if (credential.canProve) {
                        stringResource(R.string.credential_status_valid)
                    } else if (credential.isExpired) {
                        stringResource(R.string.credential_status_expired)
                    } else {
                        stringResource(R.string.credential_status_invalid)
                    },
            )

            Spacer(modifier = Modifier.height(48.dp))

            // Delete button
            // A11Y-008a: Focus indicator for keyboard/switch navigation
            OutlinedButton(
                onClick = { showDeleteConfirmation = true },
                modifier = Modifier.fillMaxWidth().buttonFocusIndicator(),
                colors =
                    ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                enabled = !isDeleting,
            ) {
                if (isDeleting) {
                    // A11Y-003a: Announce spinner to TalkBack via liveRegion
                    CircularProgressIndicator(
                        modifier =
                            Modifier.size(16.dp).semantics {
                                contentDescription = deletingText
                                liveRegion = LiveRegionMode.Polite
                            },
                        strokeWidth = 2.dp,
                    )
                } else {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        stringResource(R.string.credential_detail_delete),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }

        // Delete confirmation dialog
        if (showDeleteConfirmation) {
            // Issue 5: Always use generic delete strings to avoid exposing child name to TalkBack
            val deleteTitle = stringResource(R.string.credential_detail_delete_title)
            val deleteMessage = stringResource(R.string.credential_detail_delete_message)
            AlertDialog(
                onDismissRequest = { showDeleteConfirmation = false },
                title = { Text(deleteTitle) },
                text = { Text(deleteMessage) },
                confirmButton = {
                    TextButton(
                        onClick = {
                            showDeleteConfirmation = false
                            isDeleting = true
                            scope.launch {
                                val result = walletRepository.deleteCredential(credentialId)
                                isDeleting = false
                                if (result.isSuccess) {
                                    navController.popBackStack()
                                } else {
                                    snackbarHostState.showSnackbar(
                                        deleteErrorText,
                                    )
                                }
                            }
                        },
                        colors =
                            ButtonDefaults.textButtonColors(
                                contentColor = MaterialTheme.colorScheme.error,
                            ),
                    ) {
                        Text(stringResource(R.string.action_delete))
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteConfirmation = false }) {
                        Text(stringResource(R.string.action_cancel))
                    }
                },
            )
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        // A11Y-004a: Mark subsection labels as headings for TalkBack navigation
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}
