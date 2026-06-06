// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.navigation

import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument

/**
 * Navigation graph and screen route definitions for the Provii Wallet. All deep link
 * routes are handled programmatically in [MainActivity] rather than via Compose deep
 * link declarations, ensuring security validation occurs before navigation. The officer
 * flow, verification flow, settings, and help sections each have distinct route namespaces.
 */

sealed class Screen(val route: String) {
    // Main flow
    object CredentialList : Screen("credential_list")

    object WhereToGetCredentials : Screen("where_to_get_credentials?filter={filter}") {
        fun createRoute(filter: String? = null): String {
            return if (filter != null) {
                "where_to_get_credentials?filter=$filter"
            } else {
                "where_to_get_credentials"
            }
        }
    }

    object ManagedCredentialExplainer : Screen("managed_credential_explainer")

    // Credential detail
    object CredentialDetail : Screen("credential_detail/{credentialId}") {
        fun createRoute(credentialId: String) = "credential_detail/${java.net.URLEncoder.encode(credentialId, "UTF-8")}"
    }

    // User onboarding
    object CredentialSuccess : Screen("credential_success")

    object AttestationScanner : Screen("attestation_scanner")

    // Deep link screens (app-to-app flows). Route segment is a UUID key into NavigationPayloadStore
    object DeepLinkVerification : Screen("deeplink_verification/{payloadKey}") // Direct verification

    object DeepLinkAttestation : Screen("deeplink_attest/{payloadKey}") // Blind attestation issuance

    // Verification - manual QR scanning
    object VerificationChallenge : Screen("verification_challenge")

    // Officer mode
    object OfficerEntry : Screen("officer_entry")

    object OfficerDashboard : Screen("officer_dashboard")

    object OfficerIssueDob : Screen("officer_issue_dob")

    object OfficerShowAttestation : Screen("officer_show_attestation/{payloadKey}")

    // Settings
    object Settings : Screen("settings")

    object AccessibilitySettings : Screen("accessibility_settings")

    object LanguageSelection : Screen("language_selection")

    object Licenses : Screen("licenses")

    object PrivacySettings : Screen("privacy_settings")

    // Help
    object HelpCenter : Screen("help_center")

    object HelpTopic : Screen("help_topic/{topicId}") {
        fun createRoute(topicId: String) = "help_topic/$topicId"
    }
}

@Composable
fun NavGraph(
    navController: NavHostController,
    navigationPayloadStore: NavigationPayloadStore,
    isOfficerMode: Boolean = false,
    hasCredentials: Boolean = false,
    deepLinkIntent: Intent? = null, // Kept for compatibility but not used
) {
    val startDestination =
        when {
            isOfficerMode -> Screen.OfficerEntry.route
            else -> Screen.CredentialList.route
        }

    NavHost(
        navController = navController,
        startDestination = startDestination,
    ) {
        // Main/Credentials flow
        composable(Screen.CredentialList.route) {
            app.provii.wallet.ui.screens.credentials.CredentialListScreen(navController)
        }

        // Credential detail
        composable(
            route = Screen.CredentialDetail.route,
            arguments =
                listOf(
                    navArgument("credentialId") { type = NavType.StringType },
                ),
        ) { backStackEntry ->
            val credentialId =
                java.net.URLDecoder.decode(
                    backStackEntry.arguments?.getString("credentialId") ?: "",
                    "UTF-8",
                )
            app.provii.wallet.ui.screens.credentials.CredentialDetailScreen(
                navController = navController,
                credentialId = credentialId,
            )
        }

        composable(
            route = Screen.WhereToGetCredentials.route,
            arguments =
                listOf(
                    navArgument("filter") {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
        ) { backStackEntry ->
            val filter = backStackEntry.arguments?.getString("filter")
            app.provii.wallet.ui.screens.discovery.WhereToGetCredentialsScreen(
                navController = navController,
                filterMode = filter,
            )
        }

        composable(Screen.ManagedCredentialExplainer.route) {
            app.provii.wallet.ui.screens.discovery.ManagedCredentialExplainerScreen(navController)
        }

        composable(Screen.CredentialSuccess.route) {
            app.provii.wallet.ui.screens.onboarding.CredentialSuccessScreen(navController)
        }

        composable(Screen.AttestationScanner.route) {
            app.provii.wallet.ui.screens.credentials.AttestationScannerScreen(navController)
        }

        // Verification flow - QR scanner screen (for scanning external QR codes)
        composable(
            route = Screen.VerificationChallenge.route,
        ) {
            app.provii.wallet.ui.screens.verification.VerificationChallengeScreen(
                navController = navController,
            )
        }

        // Deep link verification - direct processing (for app-to-app flow)
        // No deepLinks declaration here - handled programmatically in MainActivity
        composable(
            route = Screen.DeepLinkVerification.route,
            arguments =
                listOf(
                    navArgument("payloadKey") { type = NavType.StringType },
                ),
        ) { backStackEntry ->
            val payloadKey = backStackEntry.arguments?.getString("payloadKey") ?: ""
            val challengeData = navigationPayloadStore.get(payloadKey) ?: ""
            DisposableEffect(payloadKey) {
                onDispose { navigationPayloadStore.remove(payloadKey) }
            }
            app.provii.wallet.ui.screens.verification.DeepLinkVerificationScreen(
                navController = navController,
                challengeData = challengeData,
            )
        }

        // Deep link attestation - blind issuance (for app-to-app flow from officer QR)
        // No deepLinks declaration here - handled programmatically in MainActivity
        composable(
            route = Screen.DeepLinkAttestation.route,
            arguments =
                listOf(
                    navArgument("payloadKey") { type = NavType.StringType },
                ),
        ) { backStackEntry ->
            val payloadKey = backStackEntry.arguments?.getString("payloadKey") ?: ""
            val attestationData = navigationPayloadStore.get(payloadKey) ?: ""
            DisposableEffect(payloadKey) {
                onDispose { navigationPayloadStore.remove(payloadKey) }
            }
            app.provii.wallet.ui.screens.onboarding.BlindAttestationScreen(
                navController = navController,
                attestationData = attestationData,
            )
        }

        // Officer flow
        composable(Screen.OfficerEntry.route) {
            app.provii.wallet.ui.screens.officer.OfficerEntryScreen(navController)
        }

        composable(Screen.OfficerDashboard.route) {
            app.provii.wallet.ui.screens.officer.OfficerDashboardScreen(navController)
        }

        composable(Screen.OfficerIssueDob.route) {
            app.provii.wallet.ui.screens.officer.OfficerIssueDobScreen(navController)
        }

        composable(
            route = Screen.OfficerShowAttestation.route,
            arguments = listOf(navArgument("payloadKey") { type = NavType.StringType }),
        ) { backStackEntry ->
            val payloadKey = backStackEntry.arguments?.getString("payloadKey") ?: ""
            val attestation = navigationPayloadStore.get(payloadKey) ?: ""
            DisposableEffect(payloadKey) {
                onDispose { navigationPayloadStore.remove(payloadKey) }
            }
            app.provii.wallet.ui.screens.officer.OfficerShowAttestationQrScreen(
                navController = navController,
                attestationB64 = attestation,
            )
        }

        // Settings
        composable(Screen.Settings.route) {
            app.provii.wallet.ui.screens.settings.SettingsScreen(navController)
        }

        composable(Screen.AccessibilitySettings.route) {
            app.provii.wallet.ui.screens.settings.AccessibilitySettingsScreen(navController)
        }

        composable(Screen.LanguageSelection.route) {
            app.provii.wallet.ui.screens.settings.LanguageSelectionScreen(navController)
        }

        composable(Screen.Licenses.route) {
            app.provii.wallet.ui.screens.settings.LicensesScreen(navController)
        }

        composable(Screen.PrivacySettings.route) {
            app.provii.wallet.ui.screens.settings.PrivacySettingsScreen(navController)
        }

        // Help
        composable(Screen.HelpCenter.route) {
            app.provii.wallet.ui.screens.help.HelpCenterScreen(navController)
        }

        composable(
            route = Screen.HelpTopic.route,
            arguments = listOf(navArgument("topicId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val topicId = backStackEntry.arguments?.getString("topicId") ?: ""
            app.provii.wallet.ui.screens.help.HelpTopicScreen(
                navController = navController,
                topicId = topicId,
            )
        }
    }
}
