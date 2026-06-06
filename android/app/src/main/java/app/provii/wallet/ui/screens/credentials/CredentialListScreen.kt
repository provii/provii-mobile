// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.credentials

import androidx.compose.animation.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CollectionInfo
import androidx.compose.ui.semantics.CollectionItemInfo
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.collectionInfo
import androidx.compose.ui.semantics.collectionItemInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.R
import app.provii.wallet.navigation.Screen
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessibleCard
import app.provii.wallet.ui.theme.buttonFocusIndicator
import app.provii.wallet.ui.theme.circularFocusIndicator
import kotlinx.coroutines.launch

/**
 * Primary credential list screen shown after onboarding. Renders an empty-state welcome
 * view when no credentials exist, or a LazyColumn list of primary and managed credential
 * rows with a pinned age verification bottom bar. Animated transitions between states
 * respect the user's reduce-motion preference per WCAG 2.3.3.
 */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CredentialListScreen(navController: NavController) {
    val walletRepository = LocalWalletRepository.current
    val credentialState by walletRepository.credentialState.collectAsStateWithLifecycle()
    val isProcessing by walletRepository.isProcessing.collectAsStateWithLifecycle()

    // WCAG 2.3.3: Respect reduce motion setting
    val accessibilityUiState = LocalAccessibilityUiState.current
    val reduceMotion = accessibilityUiState.settings.reduceMotion || accessibilityUiState.prefersReducedMotion

    val deleteErrorText = stringResource(R.string.credential_detail_delete_error)
    val nicknameErrorText = stringResource(R.string.credential_detail_nickname_error)

    // Delete state management
    var credentialToDelete by remember { mutableStateOf<WalletRepository.StoredCredentialInfo?>(null) }
    var isDeleting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    // Edit nickname state management
    var credentialToEdit by remember { mutableStateOf<WalletRepository.StoredCredentialInfo?>(null) }
    var editedNickname by remember { mutableStateOf("") }
    var isSavingNickname by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(R.string.title_provii_wallet),
                        fontWeight = FontWeight.SemiBold,
                    )
                },
                actions = {
                    IconButton(
                        onClick = { navController.navigate(Screen.Settings.route) },
                        modifier = Modifier.circularFocusIndicator(),
                    ) {
                        Icon(
                            Icons.Outlined.Settings,
                            contentDescription = stringResource(R.string.accessibility_credentials_settings_description),
                        )
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            // Only show the bottom bar when the user has credentials
            if (credentialState is WalletRepository.CredentialState.HasCredentials) {
                VerifyAgeBottomBar(
                    reduceMotion = reduceMotion,
                    onVerifyAge = {
                        navController.navigate(Screen.VerificationChallenge.route)
                    },
                )
            }
        },
    ) { paddingValues ->
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            contentAlignment = Alignment.Center,
        ) {
            Crossfade(
                targetState = credentialState,
                animationSpec =
                    if (reduceMotion) {
                        androidx.compose.animation.core.snap()
                    } else {
                        androidx.compose.animation.core.tween()
                    },
                label = "credential_state_crossfade",
            ) { state ->
                when (state) {
                    is WalletRepository.CredentialState.None -> {
                        EmptyCredentialView(
                            onScanQR = {
                                navController.navigate(Screen.AttestationScanner.route)
                            },
                            onFindApps = {
                                navController.navigate(Screen.WhereToGetCredentials.createRoute("apps"))
                            },
                            onFindLocations = {
                                navController.navigate(Screen.WhereToGetCredentials.createRoute("locations"))
                            },
                            onManagedExplainer = {
                                navController.navigate(Screen.ManagedCredentialExplainer.route)
                            },
                        )
                    }

                    is WalletRepository.CredentialState.HasCredentials -> {
                        HasCredentialsView(
                            state = state,
                            reduceMotion = reduceMotion,
                            onDeleteCredential = { credential ->
                                credentialToDelete = credential
                            },
                            onEditNickname = { credential ->
                                editedNickname = credential.nickname ?: ""
                                credentialToEdit = credential
                            },
                            onGetCredential = {
                                navController.navigate(Screen.AttestationScanner.route)
                            },
                            onAddManaged = {
                                navController.navigate(Screen.AttestationScanner.route)
                            },
                        )
                    }
                }
            }

            // Loading overlay - WCAG 2.4.11: Uses subtle background to maintain visibility.
            // Placed in outer Box so it covers both content and bottom bar.
            AnimatedVisibility(
                visible = isProcessing,
                enter = if (reduceMotion) EnterTransition.None else fadeIn(),
                exit = if (reduceMotion) ExitTransition.None else fadeOut(),
            ) {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.95f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Card(
                        modifier = Modifier.padding(48.dp),
                        shape = RoundedCornerShape(16.dp),
                        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            // A11Y-009a: Announce loading state to TalkBack
                            val loadingDescription = stringResource(R.string.accessibility_loading)
                            CircularProgressIndicator(
                                modifier =
                                    Modifier.semantics {
                                        contentDescription = loadingDescription
                                        liveRegion = LiveRegionMode.Polite
                                    },
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                stringResource(R.string.credential_list_processing),
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                            )
                        }
                    }
                }
            }
        }

        // Delete confirmation dialog
        if (credentialToDelete != null) {
            AlertDialog(
                onDismissRequest = {
                    if (!isDeleting) credentialToDelete = null
                },
                title = { Text(stringResource(R.string.credential_detail_delete_title)) },
                text = { Text(stringResource(R.string.credential_detail_delete_message)) },
                confirmButton = {
                    TextButton(
                        onClick = {
                            isDeleting = true
                            scope.launch {
                                val result = walletRepository.deleteCredential(credentialToDelete!!.id)
                                isDeleting = false
                                if (result.isSuccess) {
                                    credentialToDelete = null
                                } else {
                                    credentialToDelete = null
                                    snackbarHostState.showSnackbar(
                                        deleteErrorText,
                                    )
                                }
                            }
                        },
                        enabled = !isDeleting,
                        colors =
                            ButtonDefaults.textButtonColors(
                                contentColor = MaterialTheme.colorScheme.error,
                            ),
                    ) {
                        if (isDeleting) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                            )
                        } else {
                            Text(stringResource(R.string.action_delete))
                        }
                    }
                },
                dismissButton = {
                    TextButton(
                        onClick = { credentialToDelete = null },
                        enabled = !isDeleting,
                    ) {
                        Text(stringResource(R.string.action_cancel))
                    }
                },
            )
        }

        // Edit nickname dialog
        if (credentialToEdit != null) {
            AlertDialog(
                onDismissRequest = {
                    if (!isSavingNickname) credentialToEdit = null
                },
                title = { Text(stringResource(R.string.credential_detail_nickname)) },
                text = {
                    OutlinedTextField(
                        value = editedNickname,
                        onValueChange = { if (it.length <= 30) editedNickname = it },
                        singleLine = true,
                        enabled = !isSavingNickname,
                        label = { Text(stringResource(R.string.sandbox_nickname_label)) },
                        supportingText = { Text("${editedNickname.length}/30") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                },
                confirmButton = {
                    TextButton(
                        onClick = {
                            isSavingNickname = true
                            scope.launch {
                                val result =
                                    walletRepository.updateCredentialNickname(
                                        credentialToEdit!!.id,
                                        editedNickname.trim().ifBlank { null },
                                    )
                                isSavingNickname = false
                                if (result.isSuccess) {
                                    credentialToEdit = null
                                } else {
                                    credentialToEdit = null
                                    snackbarHostState.showSnackbar(
                                        nicknameErrorText,
                                    )
                                }
                            }
                        },
                        enabled = !isSavingNickname && editedNickname.isNotBlank(),
                    ) {
                        if (isSavingNickname) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                            )
                        } else {
                            Text(stringResource(R.string.action_save))
                        }
                    }
                },
                dismissButton = {
                    TextButton(
                        onClick = { credentialToEdit = null },
                        enabled = !isSavingNickname,
                    ) {
                        Text(stringResource(R.string.action_cancel))
                    }
                },
            )
        }
    }
}

@Composable
private fun EmptyCredentialView(
    onScanQR: () -> Unit,
    onFindApps: () -> Unit,
    onFindLocations: () -> Unit,
    onManagedExplainer: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier =
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
    ) {
        // Hero icon with gradient background
        Box(
            modifier =
                Modifier
                    .size(120.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors =
                                listOf(
                                    MaterialTheme.colorScheme.primaryContainer,
                                    MaterialTheme.colorScheme.secondaryContainer,
                                ),
                        ),
                    ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.Badge,
                contentDescription = null, // Decorative: described by adjacent heading
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = stringResource(R.string.empty_credential_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = stringResource(R.string.empty_credential_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp),
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Option 1: I have a QR code to scan (primary, highlighted)
        AccessibleCard(
            onClick = onScanQR,
            modifier = Modifier.fillMaxWidth(),
            contentDescription = stringResource(R.string.empty_credential_option_scan_a11y),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                ),
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.primary),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Default.QrCodeScanner,
                        contentDescription = null, // Decorative: card has contentDescription
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.size(28.dp),
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.empty_credential_option_scan_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text(
                        text = stringResource(R.string.empty_credential_option_scan_desc),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null, // Decorative: part of clickable card
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Option 2: Find a participating app
        AccessibleCard(
            onClick = onFindApps,
            modifier = Modifier.fillMaxWidth(),
            contentDescription = stringResource(R.string.empty_credential_option_find_apps_a11y),
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.secondaryContainer),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Default.PhoneAndroid,
                        contentDescription = null, // Decorative: card has contentDescription
                        modifier = Modifier.size(28.dp),
                        tint = MaterialTheme.colorScheme.onSecondaryContainer,
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.empty_credential_option_find_apps_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text(
                        text = stringResource(R.string.empty_credential_option_find_apps_desc),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null, // Decorative: part of clickable card
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Option 3: Find a location near you
        AccessibleCard(
            onClick = onFindLocations,
            modifier = Modifier.fillMaxWidth(),
            contentDescription = stringResource(R.string.empty_credential_option_find_locations_a11y),
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Default.LocationOn,
                        contentDescription = null, // Decorative: card has contentDescription
                        modifier = Modifier.size(28.dp),
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.empty_credential_option_find_locations_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text(
                        text = stringResource(R.string.empty_credential_option_find_locations_desc),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null, // Decorative: part of clickable card
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Option 4: I care for someone who needs a credential
        AccessibleCard(
            onClick = onManagedExplainer,
            modifier = Modifier.fillMaxWidth(),
            contentDescription = stringResource(R.string.empty_credential_option_managed_a11y),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                ),
        ) {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.tertiaryContainer),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Default.FamilyRestroom,
                        contentDescription = null, // Decorative: card has contentDescription
                        modifier = Modifier.size(28.dp),
                        tint = MaterialTheme.colorScheme.onTertiaryContainer,
                    )
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.empty_credential_option_managed_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text(
                        text = stringResource(R.string.empty_credential_option_managed_desc),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null, // Decorative: part of clickable card
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/**
 * Verify Age bottom bar pinned in the outer Scaffold. Surface with tonal elevation and
 * an 8dp gradient scrim above (suppressed when reduceMotion is true). Accounts for
 * system navigation bar insets.
 */
@Composable
private fun VerifyAgeBottomBar(
    reduceMotion: Boolean,
    onVerifyAge: () -> Unit,
) {
    Column {
        // Gradient scrim above the bar: surface colour fading to transparent
        if (!reduceMotion) {
            Box(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .background(
                            Brush.verticalGradient(
                                colors =
                                    listOf(
                                        Color.Transparent,
                                        MaterialTheme.colorScheme.surface,
                                    ),
                            ),
                        ),
            )
        }

        Surface(
            tonalElevation = 3.dp,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier =
                    Modifier
                        .padding(horizontal = 24.dp)
                        .padding(top = 12.dp, bottom = 16.dp)
                        .navigationBarsPadding(),
            ) {
                Button(
                    onClick = onVerifyAge,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(80.dp)
                            .buttonFocusIndicator(),
                    shape = RoundedCornerShape(16.dp),
                    colors =
                        ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                        ),
                ) {
                    Icon(
                        Icons.Default.QrCodeScanner,
                        contentDescription = null, // Decorative: described by adjacent text
                        modifier = Modifier.size(32.dp),
                    )
                    Spacer(modifier = Modifier.width(16.dp))
                    Text(
                        text = stringResource(R.string.credential_list_verify_age_button),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

/**
 * Managed section header with ChildCare icon, heading text, and a count pill badge
 * showing the current count against the 15-credential limit.
 */
@Composable
private fun ManagedSectionHeader(
    managedCount: Int,
) {
    val headerDescription =
        stringResource(
            R.string.credential_section_managed,
        ) + ", " + stringResource(R.string.credential_list_managed_count, managedCount, 15)

    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .semantics { contentDescription = headerDescription },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Outlined.ChildCare,
            contentDescription = null, // Decorative: row has contentDescription
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.secondary,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = stringResource(R.string.credential_section_managed),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier =
                Modifier
                    .weight(1f)
                    .semantics { heading() },
        )
        if (managedCount > 0) {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.secondaryContainer,
            ) {
                Text(
                    text = stringResource(R.string.credential_list_managed_count, managedCount, 15),
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
        }
    }
}

/**
 * Compact row for managed credentials. Uses a plain Row with a bottom HorizontalDivider
 * instead of a Card to reduce per-item height. Single three-dot overflow menu provides
 * edit nickname and delete actions.
 */

private const val CREDENTIALS_PER_PAGE = 5

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ManagedCredentialPager(
    managed: List<WalletRepository.StoredCredentialInfo>,
    onDeleteCredential: (WalletRepository.StoredCredentialInfo) -> Unit,
    onEditNickname: (WalletRepository.StoredCredentialInfo) -> Unit,
    reduceMotion: Boolean,
) {
    val pages = managed.chunked(CREDENTIALS_PER_PAGE)
    val pageCount = pages.size
    val pagerState = rememberPagerState(pageCount = { pageCount })

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxWidth(),
            pageSpacing = 16.dp,
            beyondViewportPageCount = 0,
        ) { pageIndex ->
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                pages[pageIndex].forEach { credential ->
                    CompactCredentialRow(
                        credential = credential,
                        onDelete = { onDeleteCredential(credential) },
                        onEditNickname = { onEditNickname(credential) },
                    )
                }
                // Pad incomplete pages with empty slots so every page is the same height
                val emptySlots = CREDENTIALS_PER_PAGE - pages[pageIndex].size
                repeat(emptySlots) {
                    Column {
                        Spacer(modifier = Modifier.height(56.dp))
                        HorizontalDivider(color = Color.Transparent)
                    }
                }
            }
        }

        // Page dots (only when more than 1 page)
        if (pageCount > 1) {
            Spacer(modifier = Modifier.height(12.dp))
            val pageIndicatorDesc = stringResource(R.string.page_indicator_description, pagerState.currentPage + 1, pageCount)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier =
                    Modifier.semantics {
                        contentDescription = pageIndicatorDesc
                    },
            ) {
                repeat(pageCount) { index ->
                    val isSelected = pagerState.currentPage == index
                    Box(
                        modifier =
                            Modifier
                                .size(if (isSelected) 8.dp else 6.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isSelected) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        MaterialTheme.colorScheme.outlineVariant
                                    },
                                ),
                    )
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
        }
    }
}

@Composable
private fun CompactCredentialRow(
    credential: WalletRepository.StoredCredentialInfo,
    onDelete: () -> Unit,
    onEditNickname: () -> Unit,
) {
    // Privacy: TalkBack uses generic label for managed credentials (child name protection)
    val talkBackLabel = stringResource(R.string.accessibility_managed_credential)

    val editDescription = stringResource(R.string.a11y_edit_nickname_for, talkBackLabel)
    val deleteDescription = stringResource(R.string.a11y_delete_credential_for, talkBackLabel)
    val overflowDescription = stringResource(R.string.credential_row_overflow_menu)

    var menuExpanded by remember { mutableStateOf(false) }

    Column {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(start = 24.dp, end = 8.dp)
                    .semantics(mergeDescendants = true) {
                        contentDescription = talkBackLabel
                    },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // 36dp icon badge with 10dp corner radius
            Box(
                modifier =
                    Modifier
                        .size(36.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(MaterialTheme.colorScheme.secondaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Outlined.ChildCare,
                    contentDescription = null, // Decorative: row has contentDescription
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onSecondaryContainer,
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = credential.displayName ?: stringResource(R.string.accessibility_managed_credential),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.clearAndSetSemantics {},
                )
                if (credential.isExpired) {
                    Text(
                        text = stringResource(R.string.credential_picker_expired_label),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            // Three-dot overflow menu (48dp touch target)
            Box {
                IconButton(
                    onClick = { menuExpanded = true },
                    modifier =
                        Modifier
                            .minimumInteractiveComponentSize()
                            .circularFocusIndicator(),
                ) {
                    Icon(
                        Icons.Outlined.MoreVert,
                        contentDescription = overflowDescription,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                DropdownMenu(
                    expanded = menuExpanded,
                    onDismissRequest = { menuExpanded = false },
                ) {
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.credential_row_action_edit)) },
                        onClick = {
                            menuExpanded = false
                            onEditNickname()
                        },
                        modifier =
                            Modifier.semantics {
                                contentDescription = editDescription
                            },
                    )
                    DropdownMenuItem(
                        text = {
                            Text(
                                stringResource(R.string.credential_row_action_delete),
                                color = MaterialTheme.colorScheme.error,
                            )
                        },
                        onClick = {
                            menuExpanded = false
                            onDelete()
                        },
                        modifier =
                            Modifier.semantics {
                                contentDescription = deleteDescription
                            },
                    )
                }
            }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
private fun HasCredentialsView(
    state: WalletRepository.CredentialState.HasCredentials,
    reduceMotion: Boolean,
    onDeleteCredential: (WalletRepository.StoredCredentialInfo) -> Unit,
    onEditNickname: (WalletRepository.StoredCredentialInfo) -> Unit,
    onGetCredential: () -> Unit,
    onAddManaged: () -> Unit,
) {
    // Total item count for list semantics: primary section (1) + managed items + optional add button
    val totalItemCount = 1 + state.managed.size + if (state.managed.size < 15) 1 else 0

    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .widthIn(max = 600.dp)
                .semantics {
                    collectionInfo =
                        CollectionInfo(
                            rowCount = totalItemCount,
                            columnCount = 1,
                        )
                },
        contentPadding = PaddingValues(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // -- My Credential section header --
        item(key = "primary_header") {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            ) {
                Icon(
                    Icons.Outlined.Badge,
                    contentDescription = null, // Decorative: heading text provides context
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.credential_section_my_credential),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.semantics { heading() },
                )
            }
        }

        // -- Primary credential card or Get button --
        item(key = "primary_credential") {
            Box(
                modifier =
                    Modifier
                        .padding(horizontal = 24.dp)
                        .semantics {
                            collectionItemInfo =
                                CollectionItemInfo(
                                    rowIndex = 0,
                                    rowSpan = 1,
                                    columnIndex = 0,
                                    columnSpan = 1,
                                )
                        },
            ) {
                if (state.primary != null) {
                    CredentialNicknameCard(
                        credential = state.primary,
                        onDelete = { onDeleteCredential(state.primary) },
                    )
                } else {
                    OutlinedButton(
                        onClick = onGetCredential,
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .heightIn(min = 48.dp)
                                .buttonFocusIndicator(),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = null, // Decorative: described by adjacent text
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            stringResource(R.string.credential_list_get_credential_button),
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }

        // -- Section divider --
        item(key = "divider") {
            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
            )
        }

        // -- Managed section header --
        item(key = "managed_header") {
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp)) {
                ManagedSectionHeader(managedCount = state.managed.size)
            }
        }

        // -- Managed credentials pager or empty state --
        if (state.managed.isEmpty()) {
            item(key = "managed_empty") {
                Text(
                    text = stringResource(R.string.credential_section_managed_empty),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 40.dp, vertical = 8.dp),
                )
            }
        } else {
            item(key = "managed_pager") {
                ManagedCredentialPager(
                    managed = state.managed,
                    onDeleteCredential = onDeleteCredential,
                    onEditNickname = onEditNickname,
                    reduceMotion = reduceMotion,
                )
            }
        }

        // -- Add managed button --
        if (state.managed.size < 15) {
            item(key = "add_managed") {
                OutlinedButton(
                    onClick = onAddManaged,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 24.dp, vertical = 8.dp)
                            .heightIn(min = 48.dp)
                            .buttonFocusIndicator(),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        stringResource(R.string.credential_list_add_managed_button),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }

        // -- Bottom spacer for bar clearance --
        item(key = "bottom_spacer") {
            Spacer(modifier = Modifier.height(96.dp))
        }
    }
}

@Composable
private fun CredentialNicknameCard(
    credential: WalletRepository.StoredCredentialInfo,
    onDelete: () -> Unit,
    onEditNickname: (() -> Unit)? = null,
) {
    // Privacy: TalkBack uses generic label for managed credentials (child name protection)
    val talkBackLabel =
        if (credential.isManaged) {
            stringResource(R.string.accessibility_managed_credential)
        } else {
            credential.displayName ?: stringResource(R.string.credential_section_my_credential)
        }

    val editDescription = stringResource(R.string.a11y_edit_nickname_for, talkBackLabel)
    val deleteDescription = stringResource(R.string.a11y_delete_credential_for, talkBackLabel)

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(start = 20.dp, top = 20.dp, bottom = 20.dp, end = 8.dp)
                    .semantics(mergeDescendants = true) {
                        contentDescription = talkBackLabel
                    },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (credential.isManaged) {
                                MaterialTheme.colorScheme.secondaryContainer
                            } else {
                                MaterialTheme.colorScheme.primaryContainer
                            },
                        ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (credential.isManaged) Icons.Outlined.ChildCare else Icons.Outlined.Badge,
                    contentDescription = null, // Decorative: row has its own contentDescription
                    modifier = Modifier.size(28.dp),
                    tint =
                        if (credential.isManaged) {
                            MaterialTheme.colorScheme.onSecondaryContainer
                        } else {
                            MaterialTheme.colorScheme.onPrimaryContainer
                        },
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = credential.displayName ?: stringResource(R.string.credential_section_my_credential),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clearAndSetSemantics {},
                )
                if (credential.isManaged) {
                    Text(
                        text = stringResource(R.string.credential_managed_label),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (onEditNickname != null) {
                IconButton(
                    onClick = onEditNickname,
                    modifier =
                        Modifier
                            .minimumInteractiveComponentSize()
                            .circularFocusIndicator(),
                ) {
                    Icon(
                        Icons.Outlined.Edit,
                        contentDescription = editDescription,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            IconButton(
                onClick = onDelete,
                modifier =
                    Modifier
                        .minimumInteractiveComponentSize()
                        .circularFocusIndicator(),
            ) {
                Icon(
                    Icons.Outlined.Delete,
                    contentDescription = deleteDescription,
                    tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f),
                )
            }
        }
    }
}
