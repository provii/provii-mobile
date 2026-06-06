// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.officer

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import app.provii.wallet.LocalOfficerAuthManager
import app.provii.wallet.LocalYubikeyManager
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import kotlinx.coroutines.launch

/**
 * Entry screen for officer authentication via YubiKey NFC or USB. Prompts the officer
 * for their PIN, validates it against the YubiKey, and transitions to the officer
 * dashboard on success. Provides accessible error feedback via live-region announcements
 * and heading semantics on section titles.
 */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OfficerEntryScreen(navController: NavController) {
    val yubikeyManager = LocalYubikeyManager.current
    val officerAuthManager = LocalOfficerAuthManager.current
    val coroutineScope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    val officerAuthFailedText = stringResource(R.string.officer_auth_failed)

    var officerId by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val isYubikeyConnected by yubikeyManager.isYubikeyConnected.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.title_officer_mode)) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.content_desc_back))
                    }
                },
            )
        },
    ) { paddingValues ->
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Default.Security, contentDescription = null) // Decorative - illustrates officer mode

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = stringResource(R.string.title_officer_mode),
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.semantics { heading() },
            )

            Spacer(modifier = Modifier.height(24.dp))

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors =
                    CardDefaults.cardColors(
                        containerColor =
                            if (isYubikeyConnected) {
                                MaterialTheme.colorScheme.primaryContainer
                            } else {
                                MaterialTheme.colorScheme.errorContainer
                            },
                    ),
            ) {
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.VpnKey, contentDescription = null) // Decorative - Yubikey status described by adjacent text
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = stringResource(if (isYubikeyConnected) R.string.officer_yubikey_connected else R.string.officer_connect_yubikey),
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            OutlinedTextField(
                value = officerId,
                onValueChange = { officerId = it.trim() },
                label = { Text(stringResource(R.string.officer_id)) },
                placeholder = { Text(stringResource(R.string.officer_id_placeholder)) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isLoading,
                leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) }, // Decorative - field has label
                supportingText = {
                    Text(stringResource(R.string.officer_id_hint))
                },
                keyboardOptions =
                    KeyboardOptions(
                        imeAction = ImeAction.Done,
                    ),
                keyboardActions =
                    KeyboardActions(
                        onDone = {
                            // Clear focus when done action is triggered (WCAG 2.1.1)
                            focusManager.clearFocus()
                        },
                    ),
            )

            val currentError = errorMessage
            if (currentError != null) {
                Spacer(modifier = Modifier.height(16.dp))
                Card(
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer,
                        ),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = currentError,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier =
                            Modifier
                                .padding(16.dp)
                                .semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors =
                    CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.secondaryContainer,
                    ),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                ) {
                    Text(
                        text = stringResource(R.string.officer_authentication_process),
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = stringResource(R.string.officer_auth_steps),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            Button(
                onClick = {
                    coroutineScope.launch {
                        isLoading = true
                        errorMessage = null

                        val result = officerAuthManager.authenticateOfficer(officerId)

                        if (result.isSuccess) {
                            navController.navigate(Screen.OfficerDashboard.route)
                        } else {
                            errorMessage = result.exceptionOrNull()?.message
                                ?: officerAuthFailedText
                        }

                        isLoading = false
                    }
                },
                enabled = officerId.isNotBlank() && !isLoading,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(56.dp),
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                } else {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null) // Decorative - button has text label
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.officer_authenticate_hmac))
                }
            }
        }
    }
}
