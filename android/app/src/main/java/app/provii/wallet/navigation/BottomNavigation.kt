// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.navigation

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Wallet
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavController
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.provii.wallet.R
import app.provii.wallet.ui.components.accessibility.SkipLinkAnchor
import app.provii.wallet.ui.components.accessibility.SkipLinksBar
import app.provii.wallet.ui.components.accessibility.rememberSkipLinkTarget
import app.provii.wallet.ui.screens.credentials.CredentialListScreen
import app.provii.wallet.ui.screens.help.HelpScreen
import app.provii.wallet.ui.screens.settings.SettingsScreen

/**
 * Bottom navigation bar and scaffold for the wallet's main tab structure. Defines
 * three tabs (Credentials, Settings, Help) with skip-link anchors for keyboard
 * navigation per WCAG 2.4.1. Each tab maintains its own back stack state so that
 * re-selecting a tab restores the previous position.
 */

sealed class BottomNavScreen(
    val route: String,
    val titleRes: Int,
    val icon: ImageVector,
    val contentDescriptionRes: Int,
) {
    object Credentials : BottomNavScreen(
        route = "bottom_nav_credentials",
        titleRes = R.string.tab_credentials,
        icon = Icons.Filled.Wallet,
        contentDescriptionRes = R.string.tab_credentials_description,
    )

    object Settings : BottomNavScreen(
        route = "bottom_nav_settings",
        titleRes = R.string.tab_settings,
        icon = Icons.Filled.Settings,
        contentDescriptionRes = R.string.tab_settings_description,
    )

    object Help : BottomNavScreen(
        route = "bottom_nav_help",
        titleRes = R.string.tab_help,
        icon = Icons.AutoMirrored.Filled.Help,
        contentDescriptionRes = R.string.tab_help_description,
    )
}

@Composable
fun BottomNavigationScaffold(
    mainNavController: NavHostController,
    isOfficerMode: Boolean,
    hasCredentials: Boolean,
) {
    val bottomNavController = rememberNavController()

    // WCAG 2.4.1: Skip links for keyboard navigation
    val mainContentTarget =
        rememberSkipLinkTarget(
            id = "main_content",
            labelResId = R.string.accessibility_skip_main_content,
        )

    Scaffold(
        bottomBar = {
            BottomNavigationBar(navController = bottomNavController)
        },
    ) { innerPadding ->
        Column(modifier = Modifier.padding(innerPadding)) {
            // Skip links bar (only visible when focused)
            SkipLinksBar(
                targets = listOf(mainContentTarget),
            )

            // Skip link anchor for main content
            SkipLinkAnchor(
                focusRequester = mainContentTarget.focusRequester,
                contentDescription = stringResource(R.string.accessibility_skip_main_content),
            )

            // Main navigation content
            BottomNavHost(
                navController = bottomNavController,
                mainNavController = mainNavController,
                modifier = Modifier,
                isOfficerMode = isOfficerMode,
                hasCredentials = hasCredentials,
            )
        }
    }
}

@Composable
private fun BottomNavigationBar(navController: NavController) {
    val items =
        listOf(
            BottomNavScreen.Credentials,
            BottomNavScreen.Settings,
            BottomNavScreen.Help,
        )

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    NavigationBar(
        containerColor = MaterialTheme.colorScheme.surface,
        tonalElevation = 3.dp,
    ) {
        items.forEach { screen ->
            val selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true

            NavigationBarItem(
                icon = {
                    Icon(
                        imageVector = screen.icon,
                        contentDescription = stringResource(screen.contentDescriptionRes),
                    )
                },
                label = { Text(stringResource(screen.titleRes)) },
                selected = selected,
                onClick = {
                    navController.navigate(screen.route) {
                        // Pop up to the start destination of the graph to
                        // avoid building up a large stack of destinations
                        popUpTo(navController.graph.findStartDestination().id) {
                            saveState = true
                        }
                        // Avoid multiple copies of the same destination
                        launchSingleTop = true
                        // Restore state when reselecting a previously selected item
                        restoreState = true
                    }
                },
            )
        }
    }
}

@Composable
private fun BottomNavHost(
    navController: NavHostController,
    mainNavController: NavHostController,
    modifier: Modifier = Modifier,
    isOfficerMode: Boolean,
    hasCredentials: Boolean,
) {
    NavHost(
        navController = navController,
        startDestination = BottomNavScreen.Credentials.route,
        modifier = modifier,
    ) {
        composable(BottomNavScreen.Credentials.route) {
            CredentialListScreen(mainNavController)
        }

        composable(BottomNavScreen.Settings.route) {
            SettingsScreen(mainNavController)
        }

        composable(BottomNavScreen.Help.route) {
            HelpScreen(mainNavController)
        }
    }
}
