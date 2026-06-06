// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.settings

// AccessibilityEvent and AccessibilityManager no longer needed here;
// announceForAccessibility is imported from ui.accessibility package
import app.provii.wallet.utils.LanguageConfig
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Badge
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CollectionInfo
import androidx.compose.ui.semantics.collectionInfo
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import androidx.navigation.NavController
import app.provii.wallet.LocalWalletRepository
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.navigation.Screen
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.ui.accessibility.announceForAccessibility
import app.provii.wallet.ui.accessibility.AccessibilitySettings
import app.provii.wallet.ui.accessibility.ColorBlindMode
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.TimeoutBehavior
import app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog
import app.provii.wallet.ui.components.accessibility.AccessibleCard
import app.provii.wallet.ui.components.accessibility.AccessibleModalBottomSheet
import app.provii.wallet.ui.components.accessibility.AdvancedFeature
import app.provii.wallet.ui.settings.SandboxToggleHandler
import app.provii.wallet.ui.preview.LocalePreviews
import app.provii.wallet.ui.theme.ProviiWalletTheme
import app.provii.wallet.ui.theme.circularFocusIndicator
import androidx.compose.material3.Surface
import kotlinx.coroutines.launch

/**
 * Main settings screen for the Provii Wallet application. Organises preferences into
 * general, credential management, privacy, accessibility, and advanced sections with
 * a hidden seven-tap sandbox toggle. All interactive elements meet 48dp minimum touch
 * targets and support TalkBack navigation with collection semantics for grouped items.
 */

// announceForAccessibility is now imported from app.provii.wallet.ui.accessibility.announceForAccessibility

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SettingsScreen(navController: NavController) {
    val walletRepository = LocalWalletRepository.current
    val accessibilityUiState = LocalAccessibilityUiState.current
    val accessibilitySettings = accessibilityUiState.settings
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    val sandboxToggleHandler = remember { SandboxToggleHandler() }
    var showSandboxGenerator by remember { mutableStateOf(false) }

    var showClearProvingKeyDialog by remember { mutableStateOf(false) }
    var showDeleteCredentialDialog by remember { mutableStateOf(false) }
    var showSandboxModeInfo by remember { mutableStateOf(false) }

    val isSandboxMode by remember { mutableStateOf(EnvironmentManager.isSandboxEnabled()) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            stringResource(R.string.title_settings),
                            modifier = Modifier.semantics { heading() },
                        )
                        if (isSandboxMode) {
                            Spacer(modifier = Modifier.width(8.dp))
                            Badge(
                                containerColor = MaterialTheme.colorScheme.error,
                            ) {
                                Text(stringResource(R.string.sandbox_mode_badge), style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = { navController.popBackStack() },
                        modifier = Modifier.circularFocusIndicator(),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.content_desc_back))
                    }
                },
            )
        },
    ) { paddingValues ->
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .semantics {
                        // Mark as a collection for screen readers (WCAG 1.3.1)
                        collectionInfo = CollectionInfo(rowCount = -1, columnCount = 1)
                    },
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(16.dp),
        ) {
            if (isSandboxMode) {
                item {
                    Text(
                        text = stringResource(R.string.settings_section_sandbox),
                        style = MaterialTheme.typography.titleMedium,
                        modifier =
                            Modifier
                                .padding(bottom = 4.dp)
                                .semantics { heading() }, // Section heading (WCAG 1.3.1)
                    )
                }
                item { AdvancedFeature { SandboxInfoCard() } }
                item { AdvancedFeature { SandboxGeneratorCard(onClick = { showSandboxGenerator = true }) } }
            }

            item {
                Text(
                    text = stringResource(R.string.settings_section_general),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = if (isSandboxMode) 8.dp else 0.dp, bottom = 4.dp)
                            .semantics { heading() }, // Section heading (WCAG 1.3.1)
                )
            }

            item {
                AppInfoCard(onTap = {
                    sandboxToggleHandler.onSettingsTap(
                        context = context,
                        scope = coroutineScope,
                        onSandboxDisabled = { walletRepository.deleteSandboxCredentials() },
                    )
                })
            }

            item {
                AccessibilityNavigationCard(
                    activeFeatures = countActiveAccessibilityFeatures(accessibilitySettings),
                    onClick = { navController.navigate(Screen.AccessibilitySettings.route) },
                )
            }

            // Language card hidden when only one language is enabled
            if (LanguageConfig.hasMultipleLanguages) {
                item {
                    LanguageNavigationCard(
                        onClick = { navController.navigate(Screen.LanguageSelection.route) },
                    )
                }
            }

            item {
                LicensesNavigationCard(
                    onClick = { navController.navigate(Screen.Licenses.route) },
                )
            }

            item {
                HelpSupportCard(
                    onClick = { navController.navigate(Screen.HelpCenter.route) },
                )
            }

            item {
                Text(
                    text = stringResource(R.string.settings_section_credentials),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 8.dp, bottom = 4.dp)
                            .semantics { heading() }, // Section heading (WCAG 1.3.1)
                )
            }

            item {
                GetCredentialCard(onClick = { navController.navigate(Screen.WhereToGetCredentials.createRoute()) })
            }

            item {
                Text(
                    text = stringResource(R.string.settings_section_advanced),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 8.dp, bottom = 4.dp)
                            .semantics { heading() }, // Section heading (WCAG 1.3.1)
                )
            }

            item {
                DeleteCredentialCard(onClick = {
                    // WCAG 3.3.6: Always confirm destructive actions (AAA)
                    showDeleteCredentialDialog = true
                })
            }

            item {
                ResetProvingKeyCard(onClick = {
                    // WCAG 3.3.6: Always confirm destructive actions (AAA)
                    showClearProvingKeyDialog = true
                })
            }

            if (EnvironmentManager.getCurrentEnvironment() != "production") {
                item {
                    AdvancedFeature {
                        EnvironmentInfoCard(onClick = { showSandboxModeInfo = true })
                    }
                }
            }

            item {
                Text(
                    text = stringResource(R.string.settings_section_privacy),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 8.dp, bottom = 4.dp)
                            .semantics { heading() }, // Section heading (WCAG 1.3.1)
                )
            }

            item {
                PrivacySettingsNavigationCard(
                    onClick = { navController.navigate(Screen.PrivacySettings.route) },
                )
            }

            item { PrivacyCard() }
        }
    }

    if (showSandboxGenerator) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        AccessibleModalBottomSheet(
            onDismissRequest = { showSandboxGenerator = false },
            sheetState = sheetState,
        ) {
            SandboxCredentialSheetContent(
                walletRepository = walletRepository,
                onDismiss = { showSandboxGenerator = false },
            )
        }
    }

    if (showDeleteCredentialDialog) {
        // Announce dialog opening to screen readers
        Text(
            text = stringResource(R.string.dialog_delete_credential_announcement),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
        )

        AccessibleAlertDialog(
            onDismissRequest = { showDeleteCredentialDialog = false },
            icon = { Icon(Icons.Default.Warning, contentDescription = stringResource(R.string.content_desc_warning)) },
            title = { Text(stringResource(R.string.dialog_delete_all_credentials_title)) },
            text = { Text(stringResource(R.string.dialog_delete_all_credentials_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteCredentialDialog = false
                    coroutineScope.launch { walletRepository.deleteAllCredentials() }
                }) {
                    Text(stringResource(R.string.action_delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteCredentialDialog = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }

    if (showClearProvingKeyDialog) {
        // Announce dialog opening to screen readers
        Text(
            text = stringResource(R.string.dialog_reset_proving_key_announcement),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
        )

        AccessibleAlertDialog(
            onDismissRequest = { showClearProvingKeyDialog = false },
            icon = { Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.content_desc_refresh)) },
            title = { Text(stringResource(R.string.dialog_reset_proving_key_title)) },
            text = { Text(stringResource(R.string.dialog_reset_proving_key_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showClearProvingKeyDialog = false
                    coroutineScope.launch { walletRepository.clearProvingKey() }
                }) {
                    Text(stringResource(R.string.action_reset))
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearProvingKeyDialog = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }

    if (showSandboxModeInfo) {
        // Announce dialog opening to screen readers
        Text(
            text = stringResource(R.string.dialog_environment_info_announcement),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
        )

        AccessibleAlertDialog(
            onDismissRequest = { showSandboxModeInfo = false },
            icon = { Icon(Icons.Default.Info, contentDescription = stringResource(R.string.content_desc_information)) },
            title = { Text(stringResource(R.string.environment_configuration)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.environment_current, EnvironmentManager.getCurrentEnvironment()))
                    Text(stringResource(R.string.environment_issuer_api, EnvironmentManager.getIssuerApi()))
                    Text(stringResource(R.string.environment_verifier_api, EnvironmentManager.getVerifierApi()))
                }
            },
            confirmButton = {
                TextButton(onClick = { showSandboxModeInfo = false }) { Text(stringResource(R.string.action_ok)) }
            },
        )
    }
}

// MARK: - Helper Functions

private fun countActiveAccessibilityFeatures(settings: AccessibilitySettings): Int {
    var count = 0
    if (settings.useExtraLargeText) count++
    if (settings.useHighContrast) count++
    if (settings.reduceTransparency) count++
    if (settings.colorBlindMode != ColorBlindMode.NONE) count++
    if (settings.increaseTouchTargets) count++
    if (settings.reduceMotion) count++
    if (settings.timeoutBehavior != TimeoutBehavior.NONE) count++
    if (settings.simplifiedGestures) count++
    if (settings.hapticFeedback) count++
    if (settings.simplifiedUI) count++
    if (settings.showStepNumbers) count++
    if (settings.verboseDescriptions) count++
    if (settings.confirmBeforeActions) count++
    if (settings.enableManualCodeEntry) count++
    if (settings.enableVoiceInput) count++
    return count
}

@Composable
private fun SandboxInfoCard() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Warning, contentDescription = stringResource(R.string.content_desc_sandbox_warning), tint = MaterialTheme.colorScheme.onErrorContainer)
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.sandbox_mode_active), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.sandbox_mode_description), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun AppInfoCard(onTap: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onTap,
        contentDescription = stringResource(R.string.content_desc_app_info),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(stringResource(R.string.title_provii_wallet), style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(stringResource(R.string.settings_version, app.provii.wallet.BuildConfig.VERSION_NAME), style = MaterialTheme.typography.bodyMedium)
            Text(stringResource(R.string.welcome_description), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            AdvancedFeature {
                if (EnvironmentManager.getCurrentEnvironment() != "production") {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(stringResource(R.string.environment_current, EnvironmentManager.getCurrentEnvironment()), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}

@Composable
private fun AccessibilityNavigationCard(
    activeFeatures: Int,
    onClick: () -> Unit,
) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_accessibility_settings),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.AccessibilityNew,
                contentDescription = null, // Decorative - parent Card has onClick
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.title_accessibility), style = MaterialTheme.typography.bodyLarge)
                Text(
                    if (activeFeatures > 0) stringResource(R.string.accessibility_features_active, activeFeatures) else stringResource(R.string.accessibility_customize_experience),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@Composable
private fun LanguageNavigationCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_language_settings),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Language,
                contentDescription = null, // Decorative - parent Card has onClick with description
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.settings_language), style = MaterialTheme.typography.bodyLarge)
                Text(
                    stringResource(R.string.settings_language_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@Composable
private fun LicensesNavigationCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_licenses),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Description,
                contentDescription = null, // Decorative - parent Card has onClick
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.settings_licenses), style = MaterialTheme.typography.bodyLarge)
                Text(
                    stringResource(R.string.settings_licenses_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun SandboxCredentialSheetContent(
    walletRepository: WalletRepository,
    onDismiss: () -> Unit,
) {
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val ageOptions = listOf(5, 10, 13, 16, 18, 21, 25)
    val today = remember { LocalDate.now(ZoneOffset.UTC) }

    fun suggestedDob(age: Int): LocalDate = today.minusYears(age.toLong())

    var credentialType by remember { mutableStateOf("primary") }
    var nickname by remember { mutableStateOf("") }
    var selectedAge by remember { mutableStateOf(18) }
    var useCustomDob by remember { mutableStateOf(false) }
    var customDob by remember { mutableStateOf(suggestedDob(18)) }
    var isGenerating by remember { mutableStateOf(false) }
    var successMessage by remember { mutableStateOf<String?>(null) }
    var credentialId by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }

    val defaultDob = remember(selectedAge) { suggestedDob(selectedAge) }

    LaunchedEffect(selectedAge, useCustomDob) {
        if (!useCustomDob) {
            customDob = defaultDob
        }
    }
    LaunchedEffect(useCustomDob) {
        if (useCustomDob) {
            customDob = defaultDob
        }
    }

    val minDate = remember { today.minusYears(120) }
    val minMillis = remember { minDate.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }
    val maxMillis = remember { today.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }
    val formatter = remember { DateTimeFormatter.ISO_DATE }
    val selectableDates =
        remember {
            object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                    return utcTimeMillis in minMillis..maxMillis
                }

                override fun isSelectableYear(year: Int): Boolean {
                    return year in (today.year - 120)..today.year
                }
            }
        }

    if (showDatePicker) {
        val datePickerState =
            rememberDatePickerState(
                initialSelectedDateMillis = customDob.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
                selectableDates = selectableDates,
            )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        val selected = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                        customDob = selected
                    }
                    showDatePicker = false
                }) { Text(stringResource(R.string.action_set)) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        ) {
            DatePicker(
                state = datePickerState,
            )
        }
    }

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = stringResource(R.string.sandbox_credential_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.semantics { heading() }, // Mark as heading (WCAG 1.3.1)
        )
        Text(
            stringResource(R.string.sandbox_credential_description),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        // Credential type selector
        Text(
            text = stringResource(R.string.sandbox_credential_type),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val typeOptions =
                listOf(
                    "primary" to R.string.sandbox_type_your_credential,
                    "managed" to R.string.sandbox_type_managed_credential,
                )
            val selectedLabel = stringResource(R.string.accessibility_state_selected)
            val notSelectedLabel = stringResource(R.string.accessibility_state_not_selected)
            typeOptions.forEach { (type, labelRes) ->
                val isSelected = credentialType == type
                val chipStateDesc = if (isSelected) selectedLabel else notSelectedLabel
                val chipLabel = stringResource(labelRes)
                AssistChip(
                    onClick = {
                        credentialType = type
                        announceForAccessibility(
                            context,
                            "$chipLabel, $selectedLabel",
                        )
                    },
                    label = { Text(stringResource(labelRes)) },
                    modifier =
                        Modifier.semantics {
                            role = Role.RadioButton
                            selected = isSelected
                            stateDescription = chipStateDesc
                        },
                    colors =
                        AssistChipDefaults.assistChipColors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
                            labelColor = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                        ),
                )
            }
        }

        // Nickname field for managed credentials
        if (credentialType == "managed") {
            val nicknameError = credentialType == "managed" && nickname.isBlank()
            OutlinedTextField(
                value = nickname,
                onValueChange = { if (it.length <= 30) nickname = it },
                label = { Text(stringResource(R.string.sandbox_nickname_label)) },
                placeholder = { Text(stringResource(R.string.sandbox_nickname_placeholder)) },
                supportingText = {
                    if (nicknameError) {
                        Text(
                            stringResource(R.string.sandbox_nickname_required),
                            color = MaterialTheme.colorScheme.error,
                        )
                    } else {
                        Text(stringResource(R.string.sandbox_nickname_helper))
                    }
                },
                isError = nicknameError,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Text(
            text = stringResource(R.string.sandbox_select_age),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() }, // Mark as subheading (WCAG 1.3.1)
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ageOptions.forEach { age ->
                val selected = age == selectedAge
                AssistChip(
                    onClick = { selectedAge = age },
                    label = { Text(stringResource(R.string.sandbox_age_format, age)) },
                    colors =
                        AssistChipDefaults.assistChipColors(
                            containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
                            labelColor = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                        ),
                )
            }
        }

        if (!useCustomDob) {
            Text(
                stringResource(R.string.sandbox_default_dob, formatter.format(defaultDob)),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        val overrideDobLabel = stringResource(R.string.sandbox_override_dob)
        val toggleEnabledAnnouncement = stringResource(R.string.accessibility_toggle_enabled, overrideDobLabel)
        val toggleDisabledAnnouncement = stringResource(R.string.accessibility_toggle_disabled, overrideDobLabel)
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.sandbox_override_dob), style = MaterialTheme.typography.bodyLarge)
                Text(
                    stringResource(R.string.sandbox_override_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = useCustomDob,
                onCheckedChange = { checked ->
                    useCustomDob = checked
                    val announcement = if (checked) toggleEnabledAnnouncement else toggleDisabledAnnouncement
                    announceForAccessibility(context, announcement)
                },
                modifier = Modifier.semantics { role = Role.Switch },
            )
        }

        if (useCustomDob) {
            AccessibleCard(
                modifier = Modifier.fillMaxWidth(),
                onClick = { showDatePicker = true },
                contentDescription = stringResource(R.string.content_desc_select_dob),
            ) {
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Event, contentDescription = null, tint = MaterialTheme.colorScheme.primary) // Decorative - parent Card has onClick
                    Spacer(modifier = Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(stringResource(R.string.sandbox_date_of_birth), style = MaterialTheme.typography.bodyLarge)
                        Text(
                            formatter.format(customDob),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = { showDatePicker = true }) {
                        Text(stringResource(R.string.action_change))
                    }
                }
            }
        }

        val canGenerate = !isGenerating && !(credentialType == "managed" && nickname.isBlank())

        val dobFormatCustom = stringResource(R.string.settings_sandbox_dob_format, formatter.format(customDob))
        val dobFormatAge = stringResource(R.string.settings_sandbox_age_dob_format, selectedAge, formatter.format(defaultDob))
        val managedSavedMsg = stringResource(R.string.sandbox_managed_credential_saved, nickname.trim())
        val unableToGenerateMsg = stringResource(R.string.sandbox_unable_to_generate)
        Button(
            onClick = {
                isGenerating = true
                successMessage = null
                credentialId = null
                errorMessage = null
                val capturedDobSummary = if (useCustomDob) dobFormatCustom else dobFormatAge
                val capturedManagedSavedMsg = managedSavedMsg
                coroutineScope.launch {
                    val result =
                        walletRepository.generateSandboxCredential(
                            ageYears = selectedAge,
                            dateOfBirth = if (useCustomDob) customDob else null,
                            credentialType = credentialType,
                            nickname = if (credentialType == "managed") nickname.trim() else null,
                        )
                    isGenerating = false
                    result.onSuccess { id ->
                        credentialId = id
                        successMessage =
                            if (credentialType == "managed") {
                                "$capturedManagedSavedMsg\n$capturedDobSummary"
                            } else {
                                capturedDobSummary
                            }
                    }.onFailure { throwable ->
                        errorMessage = throwable.message ?: unableToGenerateMsg
                    }
                }
            },
            enabled = canGenerate,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (isGenerating) {
                CircularProgressIndicator(
                    modifier =
                        Modifier
                            .size(18.dp),
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(stringResource(R.string.sandbox_generating))
            } else {
                Text(stringResource(R.string.sandbox_generate_credential))
            }
        }

        val currentSuccessMessage = successMessage
        val currentCredentialId = credentialId
        if (currentSuccessMessage != null && currentCredentialId != null) {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                modifier =
                    Modifier.semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
            ) {
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = stringResource(R.string.content_desc_success), tint = MaterialTheme.colorScheme.onTertiaryContainer)
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(stringResource(R.string.sandbox_test_credential_saved), style = MaterialTheme.typography.bodyLarge)
                        Text(
                            currentSuccessMessage,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onTertiaryContainer,
                        )
                        Text(
                            stringResource(R.string.sandbox_id_prefix, currentCredentialId.take(8)),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onTertiaryContainer,
                        )
                    }
                }
            }
        }

        val currentErrorMessage = errorMessage
        if (currentErrorMessage != null) {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                modifier =
                    Modifier.semantics {
                        liveRegion = LiveRegionMode.Assertive
                    },
            ) {
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Error, contentDescription = stringResource(R.string.content_desc_error), tint = MaterialTheme.colorScheme.error)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        currentErrorMessage,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                    )
                }
            }
        }

        OutlinedButton(
            onClick = onDismiss,
            modifier = Modifier.align(Alignment.End),
        ) {
            Text(stringResource(R.string.action_close))
        }
    }
}

@Composable
private fun SandboxGeneratorCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_mint_test_credential_as_issuer),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Science, contentDescription = null, tint = MaterialTheme.colorScheme.primary) // Decorative - parent Card has onClick
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.settings_mint_test_credential_as_issuer), style = MaterialTheme.typography.bodyLarge)
                Text(
                    stringResource(R.string.settings_mint_test_credential_subtitle),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@Composable
private fun GetCredentialCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_get_credential),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Add, contentDescription = null, tint = MaterialTheme.colorScheme.primary) // Decorative - parent Card has onClick
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.action_get_credential), style = MaterialTheme.typography.bodyLarge)
                Text(stringResource(R.string.settings_find_trusted_issuers), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@Composable
private fun DeleteCredentialCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_delete_credential),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error) // Decorative - parent Card has onClick
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.action_delete_credential), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.error)
                Text(stringResource(R.string.credential_remove_description), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun ResetProvingKeyCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_reset_proving_key),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Refresh, contentDescription = null) // Decorative - parent Card has onClick
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.settings_reset_proving_key), style = MaterialTheme.typography.bodyLarge)
                Text(stringResource(R.string.settings_reset_proving_key_description), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun EnvironmentInfoCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_environment_info),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary) // Decorative - parent Card has onClick
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.settings_environment), style = MaterialTheme.typography.bodyLarge)
                Text(stringResource(R.string.settings_environment_description), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun HelpSupportCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_help_support),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.AutoMirrored.Filled.Help,
                contentDescription = null, // Decorative - parent Card has onClick
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.help_and_support), style = MaterialTheme.typography.bodyLarge)
                Text(
                    stringResource(R.string.help_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@Composable
private fun PrivacySettingsNavigationCard(onClick: () -> Unit) {
    AccessibleCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        contentDescription = stringResource(R.string.content_desc_privacy_settings),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Security,
                contentDescription = null, // Decorative - parent Card has onClick
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(stringResource(R.string.privacy_settings_title), style = MaterialTheme.typography.bodyLarge)
                Text(
                    stringResource(R.string.privacy_settings_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.accessibility_settings_navigate_description))
        }
    }
}

@Composable
private fun PrivacyCard() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Lock, contentDescription = stringResource(R.string.content_desc_privacy_protected), modifier = Modifier.size(20.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text(stringResource(R.string.privacy_protected), style = MaterialTheme.typography.labelLarge)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(stringResource(R.string.privacy_zk_description), style = MaterialTheme.typography.bodySmall)
        }
    }
}

// MARK: - Previews

@LocalePreviews
@Composable
private fun SettingsScreenPreview() {
    ProviiWalletTheme {
        Surface {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(stringResource(R.string.preview_settings_title), style = MaterialTheme.typography.headlineMedium)
                LanguageNavigationCard(onClick = {})
                AccessibilityNavigationCard(activeFeatures = 3, onClick = {})
                PrivacyCard()
            }
        }
    }
}
