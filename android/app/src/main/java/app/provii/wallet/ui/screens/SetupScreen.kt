// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens

import android.content.Intent
import android.provider.Settings
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.provii.wallet.R
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.ui.accessibility.LocalAccessibilityManager
import app.provii.wallet.ui.theme.buttonFocusIndicator
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import timber.log.Timber

/**
 * Proving key download and setup flow presented on first launch. Walks the user through
 * consent, download progress with percentage and size indicators, and error recovery.
 * The proving key is required for zero knowledge proof generation during age verification.
 * MASVS-STORAGE-1: Uses Timber for logging (stripped in release builds via ProGuard).
 */

@Composable
fun SetupScreen(
    walletRepository: WalletRepository,
    onSetupComplete: () -> Unit,
) {
    Timber.d("SetupScreen: Composable started")

    val setupState by walletRepository.setupState.collectAsStateWithLifecycle()
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val resources = context.resources
    val accessibilityManager = LocalAccessibilityManager.current

    val checkingStatusText = stringResource(R.string.setup_checking_status)
    val preparingText = stringResource(R.string.setup_preparing)
    val checkingComponentsText = stringResource(R.string.setup_checking_components)
    val initializingText = stringResource(R.string.setup_initializing)

    // Track if user has consented to download
    var hasUserConsented by remember { mutableStateOf(false) }

    // Track if we've checked for existing key
    var hasCheckedForKey by remember { mutableStateOf(false) }
    var keyExists by remember { mutableStateOf(false) }

    // Track stuck checking timeout
    var stuckInCheckingTimeout by remember { mutableStateOf(false) }

    // Check if proving key already exists on first composition
    LaunchedEffect(Unit) {
        Timber.d("SetupScreen: Checking for existing proving key...")

        try {
            // Give UI a moment to settle
            delay(100)

            val hasKey = walletRepository.checkProvingKeyStatus()
            keyExists = hasKey
            hasCheckedForKey = true

            if (hasKey) {
                Timber.d("SetupScreen: Proving key already exists! Completing setup...")
                // Small delay to show success message
                delay(500)
                onSetupComplete()
            } else {
                Timber.d("SetupScreen: Proving key not found, download required")
            }
        } catch (e: Exception) {
            Timber.e("SetupScreen: Error checking for proving key: ${e.message}")
            // If check fails, assume key doesn't exist and proceed with download flow
            hasCheckedForKey = true
            keyExists = false
        }
    }

    // Log state changes
    LaunchedEffect(setupState) {
        Timber.d("SetupScreen: State changed to ${setupState::class.simpleName}")
        when (setupState) {
            is WalletRepository.SetupState.Downloading -> {
                val state = setupState as WalletRepository.SetupState.Downloading
                Timber.d("SetupScreen: Download progress = ${(state.progress * 100).toInt()}% (${state.downloadedMB}MB / ${state.totalMB}MB)")
            }
            is WalletRepository.SetupState.Error -> {
                val state = setupState as WalletRepository.SetupState.Error
                Timber.e("SetupScreen: Error state - message: ${state.message}, canRetry: ${state.canRetry}, action: ${state.requiresAction}")
            }
            else -> {}
        }
    }

    // Auto-start download only after user consent
    LaunchedEffect(hasUserConsented) {
        if (!hasUserConsented) return@LaunchedEffect

        when (setupState) {
            is WalletRepository.SetupState.NotStarted -> {
                Timber.d("SetupScreen: User consented, initiating download after delay")

                // Small delay for UI to settle
                delay(500)

                Timber.d("SetupScreen: Calling walletRepository.downloadProvingKey()")
                val result = walletRepository.downloadProvingKey()
                if (result.isSuccess) {
                    Timber.d("SetupScreen: downloadProvingKey() completed successfully")
                } else {
                    Timber.e("SetupScreen: downloadProvingKey() failed: ${result.exceptionOrNull()?.message}")
                }
            }
            else -> {}
        }
    }

    // Handle other state transitions
    LaunchedEffect(setupState) {
        when (setupState) {
            is WalletRepository.SetupState.Checking -> {
                Timber.d("SetupScreen: Entered Checking state, starting timeout monitor")
                // Start a timeout monitor for stuck checking state
                // WCAG 2.2.1: Respect accessibility timeout settings
                val timeoutDuration = accessibilityManager.getTimeoutDuration(standard = 20_000L) ?: 20_000L
                coroutineScope.launch {
                    delay(timeoutDuration)
                    if (setupState is WalletRepository.SetupState.Checking) {
                        Timber.e("SetupScreen: Still stuck in Checking after ${timeoutDuration / 1000} seconds!")
                        stuckInCheckingTimeout = true
                    }
                }
            }
            is WalletRepository.SetupState.Ready -> {
                Timber.d("SetupScreen: Ready state reached, setup complete!")
                // Small delay to show success (WCAG 2.2.1: Respect accessibility timeout)
                val successDisplayTime = accessibilityManager.getTimeoutDuration(standard = 1000L) ?: 1000L
                delay(successDisplayTime)
                Timber.d("SetupScreen: Calling onSetupComplete()")
                onSetupComplete()
            }
            else -> {}
        }
    }

    Scaffold { paddingValues ->
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(32.dp)
                        .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // App icon or logo
                Icon(
                    Icons.Default.QrCode2,
                    contentDescription = null, // Decorative - described by adjacent text "Welcome to Provii Wallet"
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = stringResource(R.string.welcome_title),
                    style = MaterialTheme.typography.headlineMedium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Show different UI based on whether we've checked for the key
                when {
                    // Still checking for existing key
                    !hasCheckedForKey -> {
                        Timber.d("SetupScreen: Rendering checking for key UI")

                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier =
                                Modifier.semantics {
                                    liveRegion = LiveRegionMode.Polite
                                },
                        ) {
                            Text(
                                text = stringResource(R.string.setup_checking_status),
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                            )

                            Spacer(modifier = Modifier.height(32.dp))

                            CircularProgressIndicator(
                                modifier =
                                    Modifier.semantics {
                                        contentDescription = checkingStatusText
                                    },
                            )
                        }
                    }

                    // Key exists - show success and exit
                    keyExists -> {
                        Timber.d("SetupScreen: Rendering key exists UI")

                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = stringResource(R.string.accessibility_verification_success_description),
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )

                        Spacer(modifier = Modifier.height(16.dp))

                        Text(
                            text = stringResource(R.string.setup_already_setup),
                            style = MaterialTheme.typography.headlineSmall,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.semantics { heading() },
                        )

                        Text(
                            text = stringResource(R.string.setup_ready_message),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )
                    }

                    // Key doesn't exist - show normal setup flow
                    else -> {
                        when (val state = setupState) {
                            is WalletRepository.SetupState.NotStarted -> {
                                if (!hasUserConsented) {
                                    // Show consent screen
                                    Timber.d("SetupScreen: Showing consent screen")

                                    Text(
                                        text = stringResource(R.string.setup_one_time_required),
                                        style = MaterialTheme.typography.titleLarge,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.semantics { heading() },
                                    )

                                    Spacer(modifier = Modifier.height(16.dp))

                                    Card(
                                        colors =
                                            CardDefaults.cardColors(
                                                containerColor = MaterialTheme.colorScheme.primaryContainer,
                                            ),
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Column(
                                            modifier = Modifier.padding(16.dp),
                                        ) {
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                            ) {
                                                Icon(
                                                    Icons.Default.CloudDownload,
                                                    contentDescription = null, // Decorative - described by adjacent text "Download Required"
                                                    modifier = Modifier.size(24.dp),
                                                )
                                                Spacer(modifier = Modifier.width(12.dp))
                                                Text(
                                                    text = stringResource(R.string.setup_download_required),
                                                    style = MaterialTheme.typography.titleMedium,
                                                )
                                            }

                                            Spacer(modifier = Modifier.height(12.dp))

                                            Text(
                                                text = stringResource(R.string.setup_download_description),
                                                style = MaterialTheme.typography.bodyMedium,
                                            )

                                            Spacer(modifier = Modifier.height(8.dp))

                                            Card(
                                                colors =
                                                    CardDefaults.cardColors(
                                                        containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                                                    ),
                                            ) {
                                                Row(
                                                    modifier = Modifier.padding(12.dp),
                                                    verticalAlignment = Alignment.CenterVertically,
                                                ) {
                                                    Icon(
                                                        Icons.Default.Wifi,
                                                        contentDescription = null, // Decorative - described by adjacent text "Wi-Fi recommended"
                                                        modifier = Modifier.size(20.dp),
                                                        tint = MaterialTheme.colorScheme.onTertiaryContainer,
                                                    )
                                                    Spacer(modifier = Modifier.width(8.dp))
                                                    Text(
                                                        text = stringResource(R.string.setup_wifi_recommended),
                                                        style = MaterialTheme.typography.labelLarge,
                                                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                                                    )
                                                }
                                            }
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(24.dp))

                                    Button(
                                        onClick = { hasUserConsented = true },
                                        modifier =
                                            Modifier
                                                .fillMaxWidth()
                                                .buttonFocusIndicator(),
                                    ) {
                                        Icon(Icons.Default.Download, contentDescription = null /* Decorative - described by adjacent text "Download Now" */)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(stringResource(R.string.action_download_now))
                                    }

                                    Spacer(modifier = Modifier.height(8.dp))

                                    FilledTonalButton(
                                        onClick = {
                                            // Open WiFi settings
                                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                                            context.startActivity(intent)
                                        },
                                        modifier =
                                            Modifier
                                                .fillMaxWidth()
                                                .buttonFocusIndicator(),
                                    ) {
                                        Icon(Icons.Default.Settings, contentDescription = null /* Decorative - described by adjacent text "Check Wi-Fi Settings First" */)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(stringResource(R.string.action_check_wifi_settings))
                                    }
                                } else {
                                    // User has consented, show preparing message
                                    Timber.d("SetupScreen: Rendering NotStarted UI after consent")

                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier =
                                            Modifier.semantics {
                                                liveRegion = LiveRegionMode.Polite
                                            },
                                    ) {
                                        Text(
                                            text = stringResource(R.string.setup_preparing),
                                            style = MaterialTheme.typography.bodyLarge,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center,
                                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                        )

                                        Spacer(modifier = Modifier.height(32.dp))

                                        CircularProgressIndicator(
                                            modifier =
                                                Modifier.semantics {
                                                    contentDescription = preparingText
                                                },
                                        )
                                    }
                                }
                            }

                            is WalletRepository.SetupState.Checking -> {
                                Timber.d("SetupScreen: Rendering Checking UI, stuckTimeout=$stuckInCheckingTimeout")

                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier =
                                        Modifier.semantics {
                                            liveRegion = LiveRegionMode.Polite
                                        },
                                ) {
                                    Text(
                                        text = stringResource(R.string.setup_checking_components),
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )

                                    Spacer(modifier = Modifier.height(32.dp))

                                    CircularProgressIndicator(
                                        modifier =
                                            Modifier.semantics {
                                                contentDescription = checkingComponentsText
                                            },
                                    )
                                }

                                // Show retry option if stuck
                                if (stuckInCheckingTimeout) {
                                    Spacer(modifier = Modifier.height(24.dp))

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
                                            Text(
                                                text = stringResource(R.string.setup_stuck_message),
                                                style = MaterialTheme.typography.labelLarge,
                                                color = MaterialTheme.colorScheme.onErrorContainer,
                                            )
                                            Spacer(modifier = Modifier.height(8.dp))
                                            Text(
                                                text = stringResource(R.string.setup_stuck_description),
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onErrorContainer,
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(16.dp))

                                    Button(
                                        onClick = {
                                            Timber.d("SetupScreen: User clicked retry from stuck checking state")
                                            coroutineScope.launch {
                                                try {
                                                    Timber.d("SetupScreen: Calling retryProvingKeyDownload()")
                                                    walletRepository.retryProvingKeyDownload()
                                                    stuckInCheckingTimeout = false
                                                } catch (e: Exception) {
                                                    Timber.e("SetupScreen: Retry failed with exception: ${e.message}")
                                                }
                                            }
                                        },
                                        modifier =
                                            Modifier
                                                .fillMaxWidth()
                                                .buttonFocusIndicator(),
                                    ) {
                                        Icon(Icons.Default.Refresh, contentDescription = null /* Decorative - described by adjacent text "Retry Setup" */)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(stringResource(R.string.action_retry_setup))
                                    }
                                }
                            }

                            is WalletRepository.SetupState.Downloading -> {
                                Timber.d("SetupScreen: Rendering Downloading UI - ${(state.progress * 100).toInt()}%")

                                val progressPercentage = (state.progress * 100).toInt()
                                val progressDescription =
                                    resources.getString(
                                        R.string.setup_download_progress_description,
                                        progressPercentage,
                                        String.format("%.1f", state.downloadedMB),
                                        String.format("%.1f", state.totalMB),
                                    )

                                Column(
                                    modifier =
                                        Modifier
                                            .fillMaxWidth()
                                            .semantics {
                                                liveRegion = LiveRegionMode.Polite
                                                contentDescription = progressDescription
                                            },
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                ) {
                                    Text(
                                        text = stringResource(R.string.setup_downloading),
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )

                                    Spacer(modifier = Modifier.height(24.dp))

                                    // Progress bar
                                    LinearProgressIndicator(
                                        progress = { state.progress },
                                        modifier =
                                            Modifier
                                                .fillMaxWidth()
                                                .height(8.dp)
                                                .semantics {
                                                    contentDescription = progressDescription
                                                },
                                    )

                                    Spacer(modifier = Modifier.height(16.dp))

                                    Text(
                                        text = "$progressPercentage%",
                                        style = MaterialTheme.typography.titleLarge,
                                        modifier =
                                            Modifier.semantics {
                                                liveRegion = LiveRegionMode.Polite
                                            },
                                    )

                                    Spacer(modifier = Modifier.height(8.dp))

                                    Text(
                                        text = "${String.format("%.1f", state.downloadedMB)} MB / ${String.format("%.1f", state.totalMB)} MB",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier =
                                            Modifier.semantics {
                                                liveRegion = LiveRegionMode.Polite
                                            },
                                    )

                                    Spacer(modifier = Modifier.height(24.dp))

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
                                                Icons.Default.Info,
                                                contentDescription = null, // Decorative - described by adjacent text "One-time download"
                                                modifier = Modifier.size(20.dp),
                                            )
                                            Spacer(modifier = Modifier.width(12.dp))
                                            Column {
                                                Text(
                                                    text = stringResource(R.string.setup_one_time_download),
                                                    style = MaterialTheme.typography.labelLarge,
                                                )
                                                Text(
                                                    text = stringResource(R.string.setup_download_info),
                                                    style = MaterialTheme.typography.bodySmall,
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            is WalletRepository.SetupState.Initialising -> {
                                Timber.d("SetupScreen: Rendering Initialising UI")

                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier =
                                        Modifier.semantics {
                                            liveRegion = LiveRegionMode.Polite
                                        },
                                ) {
                                    Text(
                                        text = stringResource(R.string.setup_initializing),
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                                    )

                                    Spacer(modifier = Modifier.height(32.dp))

                                    CircularProgressIndicator(
                                        modifier =
                                            Modifier.semantics {
                                                contentDescription = initializingText
                                            },
                                    )
                                }
                            }

                            is WalletRepository.SetupState.Ready -> {
                                Timber.d("SetupScreen: Rendering Ready UI")

                                Icon(
                                    Icons.Default.CheckCircle,
                                    contentDescription = stringResource(R.string.accessibility_verification_success_description),
                                    modifier = Modifier.size(64.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )

                                Spacer(modifier = Modifier.height(16.dp))

                                Text(
                                    text = stringResource(R.string.setup_complete),
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.semantics { heading() },
                                )

                                Text(
                                    text = stringResource(R.string.setup_ready_message),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center,
                                )
                            }

                            is WalletRepository.SetupState.Error -> {
                                Timber.d("SetupScreen: Rendering Error UI - ${state.message}")

                                // Handle JVM initialisation error specifically
                                val isJvmError = state.message.contains("JVM not initialized", ignoreCase = true)

                                val errorIcon =
                                    when {
                                        isJvmError -> Icons.Default.Warning
                                        state.requiresAction == WalletRepository.SetupAction.FREE_STORAGE -> Icons.Default.Storage
                                        state.requiresAction == WalletRepository.SetupAction.CHECK_NETWORK -> Icons.Default.WifiOff
                                        else -> Icons.Default.Warning
                                    }

                                Icon(
                                    errorIcon,
                                    contentDescription = stringResource(R.string.accessibility_verification_error_description),
                                    modifier = Modifier.size(64.dp),
                                    tint = MaterialTheme.colorScheme.error,
                                )

                                Spacer(modifier = Modifier.height(16.dp))

                                Text(
                                    text =
                                        when {
                                            isJvmError -> stringResource(R.string.setup_initialization_error)
                                            state.requiresAction == WalletRepository.SetupAction.FREE_STORAGE -> stringResource(R.string.setup_storage_full)
                                            state.requiresAction == WalletRepository.SetupAction.CHECK_NETWORK -> stringResource(R.string.setup_connection_error)
                                            else -> stringResource(R.string.setup_failed)
                                        },
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = MaterialTheme.colorScheme.error,
                                )

                                Spacer(modifier = Modifier.height(8.dp))

                                Card(
                                    colors =
                                        CardDefaults.cardColors(
                                            containerColor = MaterialTheme.colorScheme.errorContainer,
                                        ),
                                ) {
                                    Text(
                                        text =
                                            if (isJvmError) {
                                                stringResource(R.string.setup_restart_message)
                                            } else {
                                                state.message
                                            },
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onErrorContainer,
                                        modifier =
                                            Modifier
                                                .padding(16.dp)
                                                .semantics { liveRegion = LiveRegionMode.Assertive },
                                        textAlign = TextAlign.Center,
                                    )
                                }

                                Spacer(modifier = Modifier.height(24.dp))

                                when {
                                    isJvmError -> {
                                        Button(
                                            onClick = {
                                                Timber.d("SetupScreen: User clicked restart for JVM error")
                                                // Try to reinitialize
                                                coroutineScope.launch {
                                                    hasCheckedForKey = false
                                                    keyExists = false
                                                    delay(100)
                                                    val hasKey = walletRepository.checkProvingKeyStatus()
                                                    hasCheckedForKey = true
                                                    keyExists = hasKey

                                                    if (hasKey) {
                                                        onSetupComplete()
                                                    } else {
                                                        hasUserConsented = false
                                                        walletRepository.retryProvingKeyDownload()
                                                    }
                                                }
                                            },
                                            modifier =
                                                Modifier
                                                    .fillMaxWidth()
                                                    .buttonFocusIndicator(),
                                        ) {
                                            Icon(Icons.Default.Refresh, contentDescription = null /* Decorative - described by adjacent text "Restart Setup" */)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(stringResource(R.string.action_restart_setup))
                                        }
                                    }

                                    state.requiresAction == WalletRepository.SetupAction.FREE_STORAGE -> {
                                        FilledTonalButton(
                                            onClick = {
                                                Timber.d("SetupScreen: User clicked Manage Storage")
                                                // Open storage settings
                                                val intent = Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
                                                context.startActivity(intent)
                                            },
                                            modifier =
                                                Modifier
                                                    .fillMaxWidth()
                                                    .buttonFocusIndicator(),
                                        ) {
                                            Icon(Icons.Default.Settings, contentDescription = null /* Decorative - described by adjacent text "Manage Storage" */)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(stringResource(R.string.action_manage_storage))
                                        }

                                        Spacer(modifier = Modifier.height(8.dp))

                                        Text(
                                            text = stringResource(R.string.setup_free_storage_message),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center,
                                        )
                                    }

                                    state.requiresAction == WalletRepository.SetupAction.CHECK_NETWORK -> {
                                        Button(
                                            onClick = {
                                                Timber.d("SetupScreen: User clicked Retry Download")
                                                coroutineScope.launch {
                                                    try {
                                                        Timber.d("SetupScreen: Calling retryProvingKeyDownload()")
                                                        walletRepository.retryProvingKeyDownload()
                                                    } catch (e: Exception) {
                                                        Timber.e("SetupScreen: Retry failed: ${e.message}")
                                                    }
                                                }
                                            },
                                            modifier =
                                                Modifier
                                                    .fillMaxWidth()
                                                    .buttonFocusIndicator(),
                                        ) {
                                            Icon(Icons.Default.Refresh, contentDescription = null /* Decorative - described by adjacent text "Retry Download" */)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(stringResource(R.string.action_retry_download))
                                        }

                                        Spacer(modifier = Modifier.height(8.dp))

                                        FilledTonalButton(
                                            onClick = {
                                                Timber.d("SetupScreen: User clicked Check WiFi Settings")
                                                // Open WiFi settings
                                                val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                                                context.startActivity(intent)
                                            },
                                            modifier =
                                                Modifier
                                                    .fillMaxWidth()
                                                    .buttonFocusIndicator(),
                                        ) {
                                            Icon(Icons.Default.Wifi, contentDescription = null /* Decorative - described by adjacent text "Check WiFi Settings" */)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(stringResource(R.string.action_check_wifi_settings_short))
                                        }
                                    }

                                    else -> {
                                        if (state.canRetry) {
                                            Button(
                                                onClick = {
                                                    Timber.d("SetupScreen: User clicked Try Again")
                                                    hasUserConsented = true // Re-enable consent to trigger download
                                                    coroutineScope.launch {
                                                        try {
                                                            Timber.d("SetupScreen: Calling retryProvingKeyDownload()")
                                                            walletRepository.retryProvingKeyDownload()
                                                        } catch (e: Exception) {
                                                            Timber.e("SetupScreen: Retry failed: ${e.message}")
                                                        }
                                                    }
                                                },
                                                modifier =
                                                    Modifier
                                                        .fillMaxWidth()
                                                        .buttonFocusIndicator(),
                                            ) {
                                                Icon(Icons.Default.Refresh, contentDescription = null /* Decorative - described by adjacent text "Try Again" */)
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Text(stringResource(R.string.action_try_again))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                // Additional info (not shown during initial check, error state, or initial consent)
                if (hasCheckedForKey && !keyExists &&
                    setupState !is WalletRepository.SetupState.Error &&
                    (setupState !is WalletRepository.SetupState.NotStarted || hasUserConsented)
                ) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors =
                            CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                            ),
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    Icons.Default.Security,
                                    contentDescription = null, // Decorative - described by adjacent text "Privacy Protected"
                                    modifier = Modifier.size(20.dp),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(R.string.setup_privacy_protected),
                                    style = MaterialTheme.typography.labelLarge,
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = stringResource(R.string.setup_privacy_description),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
            }
        }
    }

    // Log when composable exits/recomposes
    DisposableEffect(Unit) {
        onDispose {
            Timber.d("SetupScreen: Composable disposed")
        }
    }
}
