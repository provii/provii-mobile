// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.compose.setContent
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import androidx.navigation.compose.rememberNavController
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.data.YubikeyManager
import app.provii.wallet.deeplink.DeepLinkHandler
import app.provii.wallet.navigation.NavGraph
import app.provii.wallet.navigation.NavigationPayloadStore
import app.provii.wallet.navigation.Screen
import app.provii.wallet.privacy.PrivacyPreferences
import app.provii.wallet.officer.OfficerAuthManager
import app.provii.wallet.security.SecurePreferencesManager
import app.provii.wallet.security.resilience.ResilienceChecker
import app.provii.wallet.ui.screens.ProviiSplashScreen
import app.provii.wallet.ui.screens.SetupScreen
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.accessibility.WalletAccessibilityManager
import app.provii.wallet.ui.locale.LocalAppLocale
import app.provii.wallet.ui.screens.onboarding.SimpleLanguageChoiceScreen
import app.provii.wallet.ui.screens.onboarding.SimpleAccessibilityChoiceScreen
import app.provii.wallet.ui.screens.onboarding.WalkthroughScreen
import app.provii.wallet.ui.screens.settings.AccessibilitySettingsScreen
import app.provii.wallet.ui.theme.AccessibleProviiWalletTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import timber.log.Timber
import java.util.Locale
import javax.inject.Inject

/**
 * Onboarding state machine for the first-run experience.
 * Flow: Language Choice -> (Full Language Picker) -> Accessibility Choice -> (Full Settings) -> Setup -> Walkthrough -> Main App
 */
enum class OnboardingState {
    CHECKING, // Initial check of onboarding status
    LANGUAGE_CHOICE, // Simple language choice screen (3 buttons)
    FULL_LANGUAGE_PICKER, // Full language selection screen
    ACCESSIBILITY_CHOICE, // Simple accessibility choice screen
    FULL_ACCESSIBILITY_SETTINGS, // Full accessibility settings screen
    BIOMETRIC_REQUIRED, // Device has no screen lock configured
    SETUP, // Proving key download (SetupScreen)
    WALKTHROUGH, // Post-setup walkthrough (shows once)
    MAIN_APP, // Normal app navigation
}

/**
 * Primary Activity for the Provii Wallet. Manages the onboarding state machine,
 * deep link processing with biometric gating, sandbox/production environment
 * overlays, and resilience checks that restrict credential access on compromised
 * devices. Uses Jetpack Compose for all UI rendering.
 */
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    @Inject lateinit var walletRepository: WalletRepository

    @Inject lateinit var yubikeyManager: YubikeyManager

    @Inject lateinit var officerAuthManager: OfficerAuthManager

    @Inject lateinit var deepLinkHandler: DeepLinkHandler

    @Inject lateinit var navigationPayloadStore: NavigationPayloadStore

    @Inject lateinit var accessibilityManager: WalletAccessibilityManager

    @Inject lateinit var securePrefsManager: SecurePreferencesManager

    @Inject lateinit var privacyPreferences: PrivacyPreferences

    @Inject lateinit var issuersRepository: app.provii.wallet.data.IssuersRepository

    // Reactive state for deep links - allows onNewIntent to trigger Compose reprocessing
    private val _pendingDeepLink = mutableStateOf<Uri?>(null)

    // SECURITY: Biometric lock gate. True when the app is locked and awaiting re-auth
    private val _isAppLocked = mutableStateOf(false)

    // SECURITY: True when ResilienceChecker determines credentials should be restricted
    private val _securityRestricted = mutableStateOf(false)

    // Resilience checker, initialised once in onCreate
    private lateinit var resilienceChecker: ResilienceChecker

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Timber.d("=====================================")
        Timber.d("MainActivity onCreate()")
        Timber.d("=====================================")

        // SECURITY: Prevent screenshots and screen recording of sensitive credential data.
        // FLAG_SECURE is ALWAYS enabled regardless of environment (sandbox included).
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        // SECURITY: Initialise and run resilience checks BEFORE loading any credential data.
        // The checker orchestrates anti-debug, root, tamper, and emulator detection.
        // Default policy is RESTRICT_FEATURES. Credential access is gated on the result.
        val isDebugBuild = applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        resilienceChecker =
            ResilienceChecker.Builder(applicationContext)
                .setThreatResponsePolicy(
                    if (isDebugBuild) {
                        ResilienceChecker.ThreatResponsePolicy.LOG_ONLY
                    } else {
                        ResilienceChecker.ThreatResponsePolicy.RESTRICT_FEATURES
                    },
                )
                .build()

        lifecycleScope.launch {
            val result = resilienceChecker.performAllChecks()
            _securityRestricted.value = resilienceChecker.shouldRestrictCredentials()
            if (_securityRestricted.value) {
                Timber.w(
                    "Security checks failed (level=${result.securityLevel}). " +
                        "Credential access restricted.",
                )
            }
        }

        // Start periodic checks so that runtime compromise (e.g. Frida attach) is caught
        resilienceChecker.startPeriodicChecks(lifecycleScope) { result ->
            _securityRestricted.value = resilienceChecker.shouldRestrictCredentials()
            Timber.w("Periodic security check detected threat (level=${result.securityLevel})")
        }

        // INIT-110: Surface SDK init failures that WalletApplication caught during startup.
        // If the Rust SDK, UniFFI, or native logging failed to initialise, show a fatal
        // error immediately instead of letting the app stumble into undefined behaviour.
        val walletApp = application as? WalletApplication
        if (walletApp?.sdkInitFailed == true) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
            setContent {
                AccessibleProviiWalletTheme(accessibilityManager) {
                    ErrorScreen(
                        message =
                            walletApp.sdkInitError
                                ?: getString(R.string.error_storage_init_failed),
                        onRetry = { recreate() },
                        onReset = {
                            lifecycleScope.launch {
                                walletRepository.clearProvingKey()
                                recreate()
                            }
                        },
                        onDebug = {
                            lifecycleScope.launch {
                                val debugInfo = walletRepository.getDebugInfo()
                                Timber.d("Debug Info:\n$debugInfo")
                            }
                        },
                    )
                }
            }
            return
        }

        WindowCompat.setDecorFitsSystemWindows(window, false)

        setContent {
            AccessibleProviiWalletTheme(accessibilityManager) {
                val isOfficerMode by yubikeyManager.isYubikeyConnected.collectAsStateWithLifecycle()
                val setupState by walletRepository.setupState.collectAsStateWithLifecycle()
                val credentialState by walletRepository.credentialState.collectAsStateWithLifecycle()
                val accessibilitySettings by accessibilityManager.settings.collectAsStateWithLifecycle()
                val isWalletInitialized by walletRepository.isReady.collectAsStateWithLifecycle()
                var initError by rememberSaveable { mutableStateOf<String?>(null) }

                // Onboarding state machine
                var onboardingState by rememberSaveable { mutableStateOf(OnboardingState.CHECKING) }

                // Splash screen: plays on every cold start, skipped on config change
                var showSplash by rememberSaveable { mutableStateOf(true) }

                // Get current locale for CompositionLocal
                val currentLocale =
                    remember {
                        val locales = AppCompatDelegate.getApplicationLocales()
                        if (locales.isEmpty) Locale.getDefault() else locales[0] ?: Locale.getDefault()
                    }

                val navController = rememberNavController()
                val coroutineScope = rememberCoroutineScope()

                // Check onboarding status on every activity start
                // This runs once per composition (activity creation/recreation)
                LaunchedEffect(Unit) {
                    val hasLanguage = securePrefsManager.hasSelectedLanguage()
                    val hasAccessibility = accessibilitySettings.hasCompletedAccessibilityOnboarding

                    Timber.d("Onboarding check: hasLanguage=$hasLanguage, hasAccessibility=$hasAccessibility, currentState=$onboardingState")

                    // Check whether device has a screen lock configured
                    val keyguardMgr = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                    val isDeviceSecure = keyguardMgr.isDeviceSecure

                    // Determine correct state based on what's completed
                    val correctState =
                        when {
                            !hasLanguage -> OnboardingState.LANGUAGE_CHOICE
                            !hasAccessibility -> OnboardingState.ACCESSIBILITY_CHOICE
                            !isDeviceSecure -> OnboardingState.BIOMETRIC_REQUIRED
                            else -> OnboardingState.SETUP
                        }

                    // Update state if it needs to advance (e.g., after language selection and recreation)
                    // This handles the case where activity recreates after setApplicationLocales()
                    if (onboardingState == OnboardingState.CHECKING ||
                        onboardingState == OnboardingState.LANGUAGE_CHOICE && hasLanguage ||
                        onboardingState == OnboardingState.FULL_LANGUAGE_PICKER && hasLanguage
                    ) {
                        Timber.d("Advancing onboarding state from $onboardingState to $correctState")
                        onboardingState = correctState
                    }
                }

                // SECURITY: Observe app lock and security restriction states
                val isAppLocked by _isAppLocked
                val isSecurityRestricted by _securityRestricted

                // Observe pending deep links from both onCreate and onNewIntent
                val pendingUri by _pendingDeepLink

                // Handle deep link after navigation is ready - responds to new intents via _pendingDeepLink
                LaunchedEffect(navController, isWalletInitialized, pendingUri) {
                    val uriToProcess = pendingUri
                    if (isWalletInitialized && uriToProcess != null) {
                        Timber.d("Processing pending deep link: $uriToProcess")
                        handleDeepLink(uriToProcess, navController)
                        _pendingDeepLink.value = null // Clear after processing
                    }
                }

                // Also check initial intent on first launch (before any onNewIntent).
                // No delay needed: isWalletInitialized is driven by WalletRepository.isReady
                // which only emits true after FFI init completes in the current process.
                LaunchedEffect(navController, isWalletInitialized) {
                    if (isWalletInitialized && _pendingDeepLink.value == null) {
                        intent?.data?.let { uri ->
                            Timber.d("Processing initial deep link: $uri")
                            handleDeepLink(uri, navController)
                        }
                    }
                }

                // Watch for Yubikey connection changes
                // WCAG 2.2 AAA: 3.2.5 Change on Request - respect user preference for auto-navigation
                LaunchedEffect(isOfficerMode) {
                    if (isOfficerMode && isWalletInitialized && accessibilityManager.shouldAllowAutoContextChanges()) {
                        Timber.d("Yubikey connected, redirecting to officer mode")
                        officerAuthManager.endSession()
                        navController.navigate(Screen.OfficerEntry.route) {
                            popUpTo(Screen.CredentialList.route) {
                                inclusive = false
                            }
                            launchSingleTop = true
                        }
                    } else if (!isOfficerMode && navController.currentDestination?.route?.startsWith("officer") == true && accessibilityManager.shouldAllowAutoContextChanges()) {
                        Timber.d("Yubikey disconnected, returning to main screen")
                        navController.navigate(Screen.CredentialList.route) {
                            popUpTo(Screen.CredentialList.route) {
                                inclusive = true
                            }
                        }
                    } else if (isOfficerMode && isWalletInitialized && !accessibilityManager.shouldAllowAutoContextChanges()) {
                        Timber.d("Yubikey connected, but auto-navigation disabled by accessibility settings")
                    }
                }

                // Check proving key and initialise wallet on launch
                LaunchedEffect(Unit) {
                    Timber.d("MainActivity: Initial setup check...")

                    try {
                        val hasProvingKey = walletRepository.checkProvingKeyStatus()
                        Timber.d("MainActivity: Proving key available: $hasProvingKey")

                        if (hasProvingKey) {
                            Timber.d("MainActivity: Attempting wallet initialization...")

                            val result = walletRepository.initializeWallet()
                            if (result.isSuccess) {
                                Timber.d("MainActivity: Wallet initialized successfully")
                            } else {
                                val exception = result.exceptionOrNull()
                                initError = exception?.message
                                Timber.e("MainActivity: Wallet initialization failed: $initError")

                                if (initError?.contains("JVM not initialized") == true) {
                                    initError = getString(R.string.error_storage_init_failed)
                                }
                            }
                        } else {
                            Timber.d("MainActivity: No proving key found, setup required")
                        }
                    } catch (e: Exception) {
                        Timber.e(e, "MainActivity: Exception during initialization")
                        initError = e.message
                    }
                }

                CompositionLocalProvider(
                    LocalAppLocale provides currentLocale,
                    LocalWalletRepository provides walletRepository,
                    LocalYubikeyManager provides yubikeyManager,
                    LocalOfficerAuthManager provides officerAuthManager,
                    LocalDeepLinkHandler provides deepLinkHandler,
                    LocalNavigationPayloadStore provides navigationPayloadStore,
                    LocalPrivacyPreferences provides privacyPreferences,
                    LocalIssuersRepository provides issuersRepository,
                ) {
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background,
                    ) {
                        if (showSplash) {
                            ProviiSplashScreen(
                                onComplete = { showSplash = false },
                            )
                        } else {
                            Box(modifier = Modifier.fillMaxSize()) {
                                // Background tint for sandbox mode
                                if (EnvironmentManager.isSandboxEnabled()) {
                                    Box(
                                        modifier =
                                            Modifier
                                                .fillMaxSize()
                                                .background(Color(0xFFFF9800).copy(alpha = 0.05f)),
                                    )
                                }

                                // Main content - Onboarding state machine
                                when (onboardingState) {
                                    // Checking onboarding status
                                    OnboardingState.CHECKING -> {
                                        Box(
                                            modifier = Modifier.fillMaxSize(),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            CircularProgressIndicator()
                                        }
                                    }

                                    // Simple language choice screen (first screen after fresh install)
                                    OnboardingState.LANGUAGE_CHOICE -> {
                                        Timber.d("MainActivity: Showing SimpleLanguageChoiceScreen")
                                        SimpleLanguageChoiceScreen(
                                            onUseEnglish = {
                                                Timber.d("MainActivity: User chose English")
                                                // Save language first
                                                securePrefsManager.saveLanguageCode("en")
                                                // Apply locale - this will trigger activity recreation automatically
                                                // Don't call recreate() manually as it races with setApplicationLocales
                                                AppCompatDelegate.setApplicationLocales(
                                                    LocaleListCompat.forLanguageTags("en"),
                                                )
                                            },
                                            onChangeLanguage = {
                                                Timber.d("MainActivity: User wants to change language")
                                                onboardingState = OnboardingState.FULL_LANGUAGE_PICKER
                                            },
                                        )
                                    }

                                    // Full language picker screen
                                    OnboardingState.FULL_LANGUAGE_PICKER -> {
                                        Timber.d("MainActivity: Showing full LanguageSelectionScreen")
                                        OnboardingLanguagePickerWrapper(
                                            onLanguageSelected = { code ->
                                                Timber.d("MainActivity: Language selected: $code")
                                                // Save language first
                                                securePrefsManager.saveLanguageCode(code)
                                                // Apply locale - this will trigger activity recreation automatically
                                                // Don't call recreate() manually as it races with setApplicationLocales
                                                AppCompatDelegate.setApplicationLocales(
                                                    LocaleListCompat.forLanguageTags(code),
                                                )
                                            },
                                            onBack = {
                                                onboardingState = OnboardingState.LANGUAGE_CHOICE
                                            },
                                        )
                                    }

                                    // Simple accessibility choice screen
                                    OnboardingState.ACCESSIBILITY_CHOICE -> {
                                        Timber.d("MainActivity: Showing SimpleAccessibilityChoiceScreen")
                                        SimpleAccessibilityChoiceScreen(
                                            onUseDefaults = {
                                                Timber.d("MainActivity: User chose default accessibility")
                                                accessibilityManager.updateSetting {
                                                    it.copy(hasCompletedAccessibilityOnboarding = true)
                                                }
                                                onboardingState = OnboardingState.SETUP
                                            },
                                            onOpenSettings = {
                                                Timber.d("MainActivity: User wants accessibility settings")
                                                onboardingState = OnboardingState.FULL_ACCESSIBILITY_SETTINGS
                                            },
                                        )
                                    }

                                    // Full accessibility settings screen (onboarding mode)
                                    OnboardingState.FULL_ACCESSIBILITY_SETTINGS -> {
                                        Timber.d("MainActivity: Showing AccessibilitySettingsScreen (onboarding)")
                                        AccessibilitySettingsScreen(
                                            navController = null,
                                            isOnboarding = true,
                                            onComplete = {
                                                Timber.d("MainActivity: Accessibility onboarding complete")
                                                accessibilityManager.updateSetting {
                                                    it.copy(hasCompletedAccessibilityOnboarding = true)
                                                }
                                                onboardingState = OnboardingState.SETUP
                                            },
                                        )
                                    }

                                    // Screen lock required gate
                                    OnboardingState.BIOMETRIC_REQUIRED -> {
                                        Timber.d("MainActivity: Showing BiometricRequired screen")

                                        // Re-check device security on every resume (user may have
                                        // set up a screen lock while in Settings).
                                        val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
                                        DisposableEffect(lifecycleOwner) {
                                            val observer =
                                                androidx.lifecycle.LifecycleEventObserver { _, event ->
                                                    if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
                                                        val kgm = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                                                        if (kgm.isDeviceSecure) {
                                                            Timber.d("Device is now secure, advancing to SETUP")
                                                            onboardingState = OnboardingState.SETUP
                                                        }
                                                    }
                                                }
                                            lifecycleOwner.lifecycle.addObserver(observer)
                                            onDispose {
                                                lifecycleOwner.lifecycle.removeObserver(observer)
                                            }
                                        }

                                        Column(
                                            modifier =
                                                Modifier
                                                    .fillMaxSize()
                                                    .padding(32.dp),
                                            horizontalAlignment = Alignment.CenterHorizontally,
                                            verticalArrangement = Arrangement.Center,
                                        ) {
                                            Icon(
                                                Icons.Default.Fingerprint,
                                                contentDescription = null,
                                                modifier = Modifier.size(72.dp),
                                                tint = MaterialTheme.colorScheme.primary,
                                            )
                                            Spacer(modifier = Modifier.height(24.dp))
                                            Text(
                                                text = stringResource(R.string.biometric_required_title),
                                                style = MaterialTheme.typography.headlineMedium,
                                                textAlign = TextAlign.Center,
                                            )
                                            Spacer(modifier = Modifier.height(16.dp))
                                            Text(
                                                text = stringResource(R.string.biometric_required_message),
                                                style = MaterialTheme.typography.bodyLarge,
                                                textAlign = TextAlign.Center,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                            Spacer(modifier = Modifier.height(32.dp))
                                            Button(
                                                onClick = {
                                                    startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                                                },
                                                modifier =
                                                    Modifier
                                                        .fillMaxWidth()
                                                        .height(56.dp),
                                            ) {
                                                Text(stringResource(R.string.biometric_required_open_settings))
                                            }
                                        }
                                    }

                                    // Setup screen (proving key download) - only show if not initialised
                                    OnboardingState.SETUP -> {
                                        when {
                                            // Check if already initialised (returning user) - transition past walkthrough
                                            isWalletInitialized -> {
                                                onboardingState =
                                                    if (securePrefsManager.hasCompletedWalkthrough()) {
                                                        OnboardingState.MAIN_APP
                                                    } else {
                                                        OnboardingState.WALKTHROUGH
                                                    }
                                            }

                                            // Show setup screen until wallet is initialised
                                            // SetupScreen handles all states internally (NotStarted, Downloading, Ready)
                                            // and calls onSetupComplete when ready
                                            else -> {
                                                Timber.d("MainActivity: Showing SetupScreen (setupState=${setupState::class.simpleName})")

                                                SetupScreen(
                                                    walletRepository = walletRepository,
                                                    onSetupComplete = {
                                                        Timber.d("MainActivity: Setup complete, initializing wallet...")
                                                        coroutineScope.launch {
                                                            try {
                                                                val result = walletRepository.initializeWallet()
                                                                if (result.isSuccess) {
                                                                    initError = null
                                                                    Timber.d("MainActivity: Post-setup initialization successful")
                                                                } else {
                                                                    val error = result.exceptionOrNull()
                                                                    initError = error?.message
                                                                    Timber.e("MainActivity: Post-setup initialization failed: $initError")

                                                                    if (initError?.contains("JVM not initialized") == true) {
                                                                        initError = getString(R.string.error_storage_init_failed)
                                                                    }
                                                                }
                                                            } catch (e: Exception) {
                                                                Timber.e(e, "MainActivity: Exception in onSetupComplete")
                                                                initError = e.message
                                                            }
                                                            onboardingState =
                                                                if (securePrefsManager.hasCompletedWalkthrough()) {
                                                                    OnboardingState.MAIN_APP
                                                                } else {
                                                                    OnboardingState.WALKTHROUGH
                                                                }
                                                        }
                                                    },
                                                )
                                            }
                                        }
                                    }

                                    // Post-setup walkthrough (shows once, skippable)
                                    OnboardingState.WALKTHROUGH -> {
                                        Timber.d("MainActivity: Showing WalkthroughScreen")
                                        WalkthroughScreen(
                                            onComplete = {
                                                Timber.d("MainActivity: Walkthrough complete")
                                                securePrefsManager.setWalkthroughCompleted()
                                                onboardingState = OnboardingState.MAIN_APP
                                            },
                                        )
                                    }

                                    // Main app state (after all onboarding and setup complete)
                                    OnboardingState.MAIN_APP -> {
                                        when {
                                            // Show initialisation error
                                            initError != null -> {
                                                Timber.d("MainActivity: Showing error screen")
                                                val errorMsg = initError ?: return@Surface

                                                ErrorScreen(
                                                    message = errorMsg,
                                                    onRetry = {
                                                        coroutineScope.launch {
                                                            initError = null
                                                            Timber.d("MainActivity: Retrying initialization...")

                                                            val result = walletRepository.initializeWallet()
                                                            if (result.isSuccess) {
                                                                Timber.d("MainActivity: Retry successful")
                                                            } else {
                                                                initError = result.exceptionOrNull()?.message
                                                                Timber.e("MainActivity: Retry failed: $initError")

                                                                if (initError?.contains("JVM not initialized") == true) {
                                                                    initError = getString(R.string.error_storage_init_close_restart)
                                                                }
                                                            }
                                                        }
                                                    },
                                                    onReset = {
                                                        coroutineScope.launch {
                                                            Timber.d("MainActivity: Resetting proving key...")
                                                            walletRepository.clearProvingKey()
                                                            initError = null
                                                            onboardingState = OnboardingState.SETUP
                                                        }
                                                    },
                                                    onDebug = {
                                                        coroutineScope.launch {
                                                            val debugInfo = walletRepository.getDebugInfo()
                                                            Timber.d("Debug Info:\n$debugInfo")
                                                        }
                                                    },
                                                )
                                            }

                                            // Main app navigation
                                            isWalletInitialized -> {
                                                Timber.d("MainActivity: Showing main navigation")

                                                NavGraph(
                                                    navController = navController,
                                                    navigationPayloadStore = navigationPayloadStore,
                                                    isOfficerMode = isOfficerMode,
                                                    hasCredentials = credentialState !is WalletRepository.CredentialState.None,
                                                    deepLinkIntent = null,
                                                )
                                            }

                                            // Loading state
                                            else -> {
                                                Box(
                                                    modifier = Modifier.fillMaxSize(),
                                                    contentAlignment = Alignment.Center,
                                                ) {
                                                    CircularProgressIndicator()
                                                }
                                            }
                                        }
                                    }
                                }

                                // Sandbox banner overlay
                                if (EnvironmentManager.isSandboxEnabled()) {
                                    SandboxBanner(
                                        modifier =
                                            Modifier
                                                .align(Alignment.TopCenter)
                                                .padding(top = 48.dp),
                                    )
                                }

                                // Sandbox deep-link confirmation dialog.
                                // Surfaces when a deep-link carries ?env=sandbox while
                                // the wallet is in production. See DeepLinkHandler.
                                SandboxDeepLinkPromptDialog(
                                    deepLinkHandler = deepLinkHandler,
                                    onConfirmed = { route ->
                                        if (route != null) {
                                            navController.navigate(route) {
                                                launchSingleTop = true
                                                popUpTo(Screen.CredentialList.route) { inclusive = false }
                                            }
                                        }
                                    },
                                )

                                // SECURITY: Biometric lock overlay, covers all content when locked
                                if (isAppLocked && isWalletInitialized) {
                                    LockedScreen(
                                        onUnlock = { requestBiometricUnlock() },
                                    )
                                }

                                // SECURITY: Restriction overlay, shown when device is compromised
                                if (isSecurityRestricted && isWalletInitialized) {
                                    SecurityRestrictedScreen()
                                }
                            }
                        } // end else (splash)
                    }
                }
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        Timber.d("Configuration changed: locale=${newConfig.locales[0]}")
        // Compose will automatically recompose with new configuration
        // Log for debugging purposes
    }

    override fun onResume() {
        super.onResume()
        Timber.d("=====================================")
        Timber.d("MainActivity onResume()")
        Timber.d("  Marking prover as potentially stale")
        Timber.d("=====================================")

        walletRepository.markProverStale()

        // If app is returning to foreground after verification submission,
        // call finish() to return to the browser
        if (shouldReturnToBrowser()) {
            Timber.d("Returning to browser after verification")
            finish()
            return
        }

        // SECURITY: Require biometric authentication when returning to the foreground.
        // This prevents an attacker with physical access from viewing credentials
        // after the app has been backgrounded.
        if (walletRepository.setupState.value is WalletRepository.SetupState.Ready) {
            requestBiometricUnlock()
        } else {
            _isAppLocked.value = false
        }
    }

    override fun onPause() {
        super.onPause()
        Timber.d("MainActivity onPause()")

        // SECURITY: Lock the app when it goes to background so biometric re-auth
        // is required before credentials are visible again.
        if (walletRepository.setupState.value is WalletRepository.SetupState.Ready) {
            _isAppLocked.value = true
        }
    }

    override fun onStop() {
        super.onStop()
        Timber.d("MainActivity onStop()")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Timber.d("MainActivity onNewIntent() - uri: ${intent.data}")
        setIntent(intent)

        // Update pending deep link state - this will trigger the LaunchedEffect in Compose
        intent.data?.let { uri ->
            _pendingDeepLink.value = uri
        }
    }

    /**
     * Handle deep links after navigation is ready.
     * Delegates to DeepLinkHandler for all validation and security checks.
     *
     * SECURITY: Biometric consent is enforced downstream in
     * WalletRepository.createAgeProof() before any proof is generated.
     * The app lock biometric in onResume() covers physical access.
     */
    private suspend fun handleDeepLink(
        uri: Uri,
        navController: androidx.navigation.NavController,
    ) {
        val route = deepLinkHandler.handleUri(uri)
        if (route != null) {
            Timber.d("Navigating to deep link route: $route")
            navController.navigate(route) {
                launchSingleTop = true
                popUpTo(Screen.CredentialList.route) { inclusive = false }
            }
            intent = null
        } else {
            Timber.w("Deep link validation failed for: ${uri.scheme}://${uri.host}")
        }
    }

    /**
     * Check if we should return to the browser after verification
     * MASVS-CODE-1: Uses EncryptedSharedPreferences via SecurePreferencesManager
     */
    private fun shouldReturnToBrowser(): Boolean {
        return securePrefsManager.checkAndConsumeShouldReturnToBrowser()
    }

    /**
     * SECURITY: Show a biometric prompt to unlock the app after it was backgrounded.
     *
     * If biometric hardware is not available or not enrolled, the app unlocks
     * automatically (the user has no biometric protection configured and we
     * cannot force them to set it up here).
     *
     * Uses BIOMETRIC_STRONG only, no PIN/pattern fallback, consistent with
     * the KeystoreBridge biometric policy (MASVS-AUTH-1).
     */
    private fun requestBiometricUnlock() {
        val biometricManager = BiometricManager.from(this)
        val canAuthenticate =
            biometricManager.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG,
            )

        if (canAuthenticate != BiometricManager.BIOMETRIC_SUCCESS) {
            // No biometric hardware or no enrolled biometrics, unlock silently
            _isAppLocked.value = false
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val prompt =
            BiometricPrompt(
                this,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        super.onAuthenticationSucceeded(result)
                        Timber.d("Biometric unlock succeeded")
                        _isAppLocked.value = false
                    }

                    override fun onAuthenticationError(
                        errorCode: Int,
                        errString: CharSequence,
                    ) {
                        super.onAuthenticationError(errorCode, errString)
                        Timber.w("Biometric unlock error ($errorCode): $errString")
                        // Fail CLOSED: keep the app locked.
                        // User can tap the unlock button in the locked screen to retry.
                        _isAppLocked.value = true
                    }

                    override fun onAuthenticationFailed() {
                        super.onAuthenticationFailed()
                        Timber.w("Biometric unlock failed (bad biometric)")
                        // Remain locked. The system will allow the user to retry.
                    }
                },
            )

        val promptInfo =
            BiometricPrompt.PromptInfo.Builder()
                .setTitle(getString(R.string.keystore_biometric_prompt_title))
                .setSubtitle(getString(R.string.keystore_biometric_prompt_subtitle_access_storage))
                .setNegativeButtonText(getString(R.string.keystore_biometric_prompt_cancel))
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .build()

        prompt.authenticate(promptInfo)
    }

    override fun onDestroy() {
        super.onDestroy()
        Timber.d("=====================================")
        Timber.d("MainActivity onDestroy()")
        Timber.d("=====================================")
        resilienceChecker.stopPeriodicChecks()
        walletRepository.cleanup()
        yubikeyManager.cleanup()
    }
}

@Composable
fun ErrorScreen(
    message: String,
    onRetry: () -> Unit,
    onReset: () -> Unit,
    onDebug: () -> Unit = {},
) {
    val accessibilityUiState = LocalAccessibilityUiState.current
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                Icons.Default.Warning,
                contentDescription = stringResource(R.string.content_desc_warning_error),
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.error,
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = stringResource(R.string.setup_initialization_error),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.error,
            )

            Spacer(modifier = Modifier.height(16.dp))

            Card(
                colors =
                    CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                    ),
            ) {
                Text(
                    text = message,
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = onRetry,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = accessibilityUiState.minTouchTarget),
            ) {
                Text(stringResource(R.string.main_activity_retry))
            }

            Spacer(modifier = Modifier.height(8.dp))

            OutlinedButton(
                onClick = onReset,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = accessibilityUiState.minTouchTarget),
                colors =
                    ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
            ) {
                Text(stringResource(R.string.main_activity_reset_redownload))
            }

            Spacer(modifier = Modifier.height(8.dp))

            TextButton(
                onClick = onDebug,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = accessibilityUiState.minTouchTarget),
            ) {
                Text(stringResource(R.string.main_activity_show_debug_info))
            }
        }
    }
}

/**
 * SECURITY: Full-screen lock overlay shown when the app returns from background.
 * The user must authenticate via biometrics to dismiss this screen.
 * Covers all underlying content so credentials are not visible.
 */
@Composable
fun LockedScreen(onUnlock: () -> Unit) {
    val accessibilityUiState = LocalAccessibilityUiState.current
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(32.dp),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Default.Lock,
                    contentDescription = stringResource(R.string.keystore_biometric_prompt_title),
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = stringResource(R.string.keystore_biometric_prompt_title),
                    style = MaterialTheme.typography.headlineMedium,
                    textAlign = TextAlign.Center,
                )

                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    text = stringResource(R.string.keystore_biometric_prompt_subtitle_access_storage),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                Spacer(modifier = Modifier.height(32.dp))

                Button(
                    onClick = onUnlock,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .heightIn(min = accessibilityUiState.minTouchTarget)
                            .semantics { role = Role.Button },
                    contentPadding = PaddingValues(16.dp),
                ) {
                    Text(
                        text = stringResource(R.string.keystore_biometric_prompt_title),
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

/**
 * SECURITY: Full-screen restriction overlay shown when resilience checks
 * detect that the device is compromised (root, Frida, Xposed, tampering).
 * Credential access is blocked entirely. The user must resolve the security
 * issue (e.g. unroot, remove Frida) and restart the app.
 */
@Composable
fun SecurityRestrictedScreen() {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(32.dp),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Default.Warning,
                    contentDescription = stringResource(R.string.content_desc_warning_error),
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.error,
                )

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = stringResource(R.string.setup_initialization_error),
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center,
                )

                Spacer(modifier = Modifier.height(16.dp))

                Card(
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer,
                        ),
                ) {
                    Text(
                        text = stringResource(R.string.security_restricted_body),
                        modifier = Modifier.padding(16.dp),
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

// CompositionLocal providers
val LocalWalletRepository =
    staticCompositionLocalOf<WalletRepository> {
        error("No WalletRepository provided")
    }

val LocalYubikeyManager =
    staticCompositionLocalOf<YubikeyManager> {
        error("No YubikeyManager provided")
    }

val LocalOfficerAuthManager =
    staticCompositionLocalOf<OfficerAuthManager> {
        error("No OfficerAuthManager provided")
    }

val LocalDeepLinkHandler =
    staticCompositionLocalOf<DeepLinkHandler> {
        error("No DeepLinkHandler provided")
    }

val LocalNavigationPayloadStore =
    staticCompositionLocalOf<NavigationPayloadStore> {
        error("No NavigationPayloadStore provided")
    }

val LocalPrivacyPreferences =
    staticCompositionLocalOf<PrivacyPreferences> {
        error("No PrivacyPreferences provided")
    }

val LocalIssuersRepository =
    staticCompositionLocalOf<app.provii.wallet.data.IssuersRepository> {
        error("No IssuersRepository provided")
    }

// Sandbox Mode Banner
@Composable
fun SandboxBanner(modifier: Modifier = Modifier) {
    // WCAG 2.3.2: Pulse animation at 0.33Hz (<3Hz limit) and respects reduce motion
    // WCAG 2.3.3: Animation disabled when reduce motion is enabled
    val accessibilityUiState = LocalAccessibilityUiState.current
    val reduceMotion = accessibilityUiState.settings.reduceMotion || accessibilityUiState.prefersReducedMotion

    // Always create the transition (Compose requirement), but only use animated value when motion enabled
    val infiniteTransition = rememberInfiniteTransition(label = "sandbox_pulse")
    val animatedScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.05f,
        animationSpec =
            infiniteRepeatable(
                animation =
                    tween(
                        durationMillis = 1500,
                        easing = EaseInOut,
                    ),
                repeatMode = RepeatMode.Reverse,
            ),
        label = "sandbox_scale",
    )
    // Use static scale when reduce motion is enabled to respect accessibility preference
    val scale = if (reduceMotion) 1.0f else animatedScale

    // TalkBack announcement text read when the banner enters
    // composition (i.e. the EnvironmentManager flag flipped to sandbox).
    val sandboxAnnouncement = stringResource(R.string.sandbox_mode_enabled_announcement)

    Card(
        // announce the sandbox-mode transition to TalkBack via a
        // polite live region on the banner itself. When the banner enters
        // composition (i.e. the EnvironmentManager flag flipped to sandbox),
        // TalkBack reads the banner's content description. Keeping the live
        // region on the Card rather than on a hidden Text matches the
        // pattern at CredentialDetailScreen.kt:233 and avoids the extra
        // invisible node that some Android versions mis-focus.
        modifier =
            modifier
                .scale(scale)
                .shadow(4.dp, RoundedCornerShape(24.dp))
                .semantics {
                    liveRegion = LiveRegionMode.Polite
                    contentDescription = sandboxAnnouncement
                },
        shape = RoundedCornerShape(24.dp),
        colors =
            CardDefaults.cardColors(
                containerColor = Color(0xFFFF9800), // Orange
            ),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Default.Warning,
                contentDescription = stringResource(R.string.content_desc_sandbox_indicator),
                tint = Color.White,
                modifier = Modifier.size(18.dp),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = stringResource(R.string.sandbox_mode_banner),
                color = Color.White,
                style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Icon(
                imageVector = Icons.Default.Warning,
                contentDescription = stringResource(R.string.content_desc_sandbox_indicator),
                tint = Color.White,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/**
 * Sandbox deep-link confirmation dialog ().
 *
 * Observes the [DeepLinkHandler.pendingSandboxPrompt] flow. When a sandbox
 * deep-link arrives while the wallet is in production mode, this dialog
 * presents the user with an explicit choice: enable sandbox mode and open
 * the link, or cancel silently. TalkBack announces the prompt via a polite
 * live region.
 */
@Composable
fun SandboxDeepLinkPromptDialog(
    deepLinkHandler: DeepLinkHandler,
    onConfirmed: (String?) -> Unit,
) {
    val prompt by deepLinkHandler.pendingSandboxPrompt.collectAsStateWithLifecycle()

    if (prompt != null) {
        // pick the prompt copy based on which signal raised it.
        // URL-level advisory (W13) uses the `deeplink_sandbox_prompt_*`
        // strings; decoded-payload `environment: sandbox` (W14) uses the
        // `challenge_sandbox_prompt_*` strings. Distinct copy because the
        // verifier has already committed to sandbox in a signed payload
        // and the wallet should say so plainly.
        val titleRes: Int
        val bodyRes: Int
        val primaryRes: Int
        val secondaryRes: Int
        val announcementRes: Int
        when (prompt!!.source) {
            DeepLinkHandler.SandboxPromptSource.URL -> {
                titleRes = R.string.deeplink_sandbox_prompt_title
                bodyRes = R.string.deeplink_sandbox_prompt_body
                primaryRes = R.string.deeplink_sandbox_prompt_primary
                secondaryRes = R.string.deeplink_sandbox_prompt_secondary
                announcementRes = R.string.deeplink_sandbox_prompt_announcement
            }
            DeepLinkHandler.SandboxPromptSource.CHALLENGE -> {
                titleRes = R.string.challenge_sandbox_prompt_title
                bodyRes = R.string.challenge_sandbox_prompt_body
                primaryRes = R.string.challenge_sandbox_prompt_primary
                secondaryRes = R.string.challenge_sandbox_prompt_secondary
                announcementRes = R.string.challenge_sandbox_prompt_announcement
            }
        }

        // Live region announces the prompt for TalkBack users.
        Text(
            text = stringResource(announcementRes),
            modifier =
                Modifier
                    .height(0.dp)
                    .semantics {
                        liveRegion = LiveRegionMode.Polite
                    },
        )

        app.provii.wallet.ui.components.accessibility.AccessibleAlertDialog(
            onDismissRequest = { deepLinkHandler.dismissSandboxPrompt() },
            icon = {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = stringResource(R.string.content_desc_sandbox_indicator),
                )
            },
            title = { Text(stringResource(titleRes)) },
            text = { Text(stringResource(bodyRes)) },
            confirmButton = {
                TextButton(onClick = {
                    val route = deepLinkHandler.confirmSandboxPrompt()
                    onConfirmed(route)
                }) {
                    Text(stringResource(primaryRes))
                }
            },
            dismissButton = {
                TextButton(onClick = { deepLinkHandler.dismissSandboxPrompt() }) {
                    Text(stringResource(secondaryRes))
                }
            },
        )
    }
}

/**
 * Wrapper around LanguageSelectionScreen for onboarding flow.
 * Provides callbacks for language selection and back navigation instead of NavController.
 */
@Composable
fun OnboardingLanguagePickerWrapper(
    onLanguageSelected: (String) -> Unit,
    onBack: () -> Unit,
) {
    // Re-use the existing language selection UI with onboarding callbacks
    app.provii.wallet.ui.screens.onboarding.LanguageSelectionScreen(
        navController = null,
        isOnboarding = true,
        onLanguageSelected = onLanguageSelected,
        onBack = onBack,
    )
}
