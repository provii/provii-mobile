// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components.accessibility

import android.view.KeyEvent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * External keyboard shortcut handling satisfying WCAG 2.1.3 (Keyboard, No Exception).
 * Provides six Ctrl+key app shortcuts and five standard navigation shortcuts, a
 * composable installer that attaches a key listener to the root View, and a discovery
 * screen listing all available shortcuts. Mirrors iOS KeyboardShortcuts.swift.
 */
@Immutable
data class AppKeyboardShortcut(
    val keyCode: Int,
    val label: String,
    val displayKey: String,
    val description: String,
)

@Immutable
data class NavigationShortcut(
    val displayKey: String,
    val title: String,
    val description: String,
)

object KeyboardShortcutHandler {
    private val _isEnabled = MutableStateFlow(true)
    val isEnabled: StateFlow<Boolean> = _isEnabled.asStateFlow()

    // Callback closures for each shortcut
    var onSettings: (() -> Unit)? = null
    var onAccessibility: (() -> Unit)? = null
    var onHelp: (() -> Unit)? = null
    var onAddCredential: (() -> Unit)? = null
    var onStartVerification: (() -> Unit)? = null
    var onKeyboardShortcuts: (() -> Unit)? = null

    /**
     * Returns localised app shortcuts. Must be called from a @Composable context
     * or via Context.getString(). The displayKey values (Ctrl+S etc.) are
     * conventionally untranslated.
     */
    fun shortcuts(context: android.content.Context) =
        listOf(
            AppKeyboardShortcut(
                KeyEvent.KEYCODE_S,
                context.getString(R.string.keyboard_shortcut_label_settings),
                "Ctrl+S",
                context.getString(R.string.keyboard_shortcut_desc_settings),
            ),
            AppKeyboardShortcut(
                KeyEvent.KEYCODE_A,
                context.getString(R.string.keyboard_shortcut_label_accessibility),
                "Ctrl+A",
                context.getString(R.string.keyboard_shortcut_desc_accessibility),
            ),
            AppKeyboardShortcut(
                KeyEvent.KEYCODE_H,
                context.getString(R.string.keyboard_shortcut_label_help),
                "Ctrl+H",
                context.getString(R.string.keyboard_shortcut_desc_help),
            ),
            AppKeyboardShortcut(
                KeyEvent.KEYCODE_N,
                context.getString(R.string.keyboard_shortcut_label_add_credential),
                "Ctrl+N",
                context.getString(R.string.keyboard_shortcut_desc_add_credential),
            ),
            AppKeyboardShortcut(
                KeyEvent.KEYCODE_V,
                context.getString(R.string.keyboard_shortcut_label_verify),
                "Ctrl+V",
                context.getString(R.string.keyboard_shortcut_desc_verify),
            ),
            AppKeyboardShortcut(
                KeyEvent.KEYCODE_K,
                context.getString(R.string.keyboard_shortcut_label_shortcuts),
                "Ctrl+K",
                context.getString(R.string.keyboard_shortcut_desc_shortcuts),
            ),
        )

    fun navigationShortcuts(context: android.content.Context) =
        listOf(
            NavigationShortcut("ESC", context.getString(R.string.keyboard_shortcut_nav_back), context.getString(R.string.keyboard_shortcut_nav_back_desc)),
            NavigationShortcut("TAB", context.getString(R.string.keyboard_shortcut_nav_next), context.getString(R.string.keyboard_shortcut_nav_next_desc)),
            NavigationShortcut("Shift+TAB", context.getString(R.string.keyboard_shortcut_nav_prev), context.getString(R.string.keyboard_shortcut_nav_prev_desc)),
            NavigationShortcut("ENTER", context.getString(R.string.keyboard_shortcut_nav_submit), context.getString(R.string.keyboard_shortcut_nav_submit_desc)),
            NavigationShortcut("SPACE", context.getString(R.string.keyboard_shortcut_nav_activate), context.getString(R.string.keyboard_shortcut_nav_activate_desc)),
        )

    fun enable() {
        _isEnabled.value = true
    }

    fun disable() {
        _isEnabled.value = false
    }

    /**
     * Handle a key event. Returns true if the event was consumed by a shortcut.
     */
    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!_isEnabled.value) return false
        if (event.action != KeyEvent.ACTION_DOWN) return false
        if (!event.isCtrlPressed) return false

        return when (event.keyCode) {
            KeyEvent.KEYCODE_S -> {
                onSettings?.invoke()
                onSettings != null
            }
            KeyEvent.KEYCODE_A -> {
                onAccessibility?.invoke()
                onAccessibility != null
            }
            KeyEvent.KEYCODE_H -> {
                onHelp?.invoke()
                onHelp != null
            }
            KeyEvent.KEYCODE_N -> {
                onAddCredential?.invoke()
                onAddCredential != null
            }
            KeyEvent.KEYCODE_V -> {
                onStartVerification?.invoke()
                onStartVerification != null
            }
            KeyEvent.KEYCODE_K -> {
                onKeyboardShortcuts?.invoke()
                onKeyboardShortcuts != null
            }
            else -> false
        }
    }
}

/**
 * Composable side-effect that installs a key event listener on the current View.
 * This should be placed near the root of the navigation host so that keyboard
 * shortcuts are available throughout the app.
 *
 * Call this once at the top level and provide callback lambdas for each action.
 */
@Composable
fun InstallKeyboardShortcuts(
    onSettings: () -> Unit = {},
    onAccessibility: () -> Unit = {},
    onHelp: () -> Unit = {},
    onAddCredential: () -> Unit = {},
    onStartVerification: () -> Unit = {},
    onKeyboardShortcuts: () -> Unit = {},
) {
    val view = LocalView.current

    DisposableEffect(view) {
        KeyboardShortcutHandler.onSettings = onSettings
        KeyboardShortcutHandler.onAccessibility = onAccessibility
        KeyboardShortcutHandler.onHelp = onHelp
        KeyboardShortcutHandler.onAddCredential = onAddCredential
        KeyboardShortcutHandler.onStartVerification = onStartVerification
        KeyboardShortcutHandler.onKeyboardShortcuts = onKeyboardShortcuts

        val listener =
            android.view.View.OnKeyListener { _, _, event ->
                KeyboardShortcutHandler.handleKeyEvent(event)
            }
        view.setOnKeyListener(listener)

        onDispose {
            view.setOnKeyListener(null)
            KeyboardShortcutHandler.onSettings = null
            KeyboardShortcutHandler.onAccessibility = null
            KeyboardShortcutHandler.onHelp = null
            KeyboardShortcutHandler.onAddCredential = null
            KeyboardShortcutHandler.onStartVerification = null
            KeyboardShortcutHandler.onKeyboardShortcuts = null
        }
    }
}

/**
 * Display screen showing all available keyboard shortcuts.
 * Matches iOS KeyboardShortcutsView with app shortcuts, navigation shortcuts,
 * and tips sections.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KeyboardShortcutsScreen(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState = LocalAccessibilityUiState.current
    val context = LocalContext.current
    val appShortcuts = remember(context) { KeyboardShortcutHandler.shortcuts(context) }
    val navShortcuts = remember(context) { KeyboardShortcutHandler.navigationShortcuts(context) }
    val dismissDesc = stringResource(R.string.keyboard_shortcuts_dismiss)

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.keyboard_shortcuts_title),
                        modifier = Modifier.semantics { heading() },
                    )
                },
                actions = {
                    TextButton(
                        onClick = onDismiss,
                        modifier =
                            Modifier
                                .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                                .semantics {
                                    contentDescription = dismissDesc
                                },
                    ) {
                        Text(stringResource(R.string.keyboard_shortcuts_done))
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // App Shortcuts section
            item {
                Text(
                    text = stringResource(R.string.keyboard_shortcuts_app_section),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(bottom = 8.dp)
                            .semantics { heading() },
                )
            }

            items(appShortcuts) { shortcut ->
                ShortcutRow(
                    key = shortcut.displayKey,
                    title = shortcut.label,
                    description = if (uiState.settings.verboseDescriptions) shortcut.description else null,
                )
            }

            // Navigation Shortcuts section
            item {
                Text(
                    text = stringResource(R.string.keyboard_shortcuts_navigation_section),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 8.dp, bottom = 8.dp)
                            .semantics { heading() },
                )
            }

            items(navShortcuts) { shortcut ->
                ShortcutRow(
                    key = shortcut.displayKey,
                    title = shortcut.title,
                    description = if (uiState.settings.verboseDescriptions) shortcut.description else null,
                )
            }

            if (uiState.settings.verboseDescriptions) {
                item {
                    Text(
                        text = stringResource(R.string.keyboard_shortcuts_navigation_footer),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }

            // Tips section
            item {
                Text(
                    text = stringResource(R.string.keyboard_shortcuts_tips_section),
                    style = MaterialTheme.typography.titleMedium,
                    modifier =
                        Modifier
                            .padding(top = 8.dp, bottom = 8.dp)
                            .semantics { heading() },
                )
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    TipText(stringResource(R.string.keyboard_shortcuts_tip_external))
                    TipText(stringResource(R.string.keyboard_shortcuts_tip_arrow_keys))
                    TipText(stringResource(R.string.keyboard_shortcuts_tip_hold_ctrl))
                    if (uiState.settings.verboseDescriptions) {
                        TipText(stringResource(R.string.keyboard_shortcuts_tip_a11y))
                    }
                }
            }
        }
    }
}

@Composable
private fun ShortcutRow(
    key: String,
    title: String,
    description: String?,
) {
    val uiState = LocalAccessibilityUiState.current
    val spacing = if (uiState.settings.increaseTouchTargets) 16.dp else 12.dp

    val a11yLabel =
        if (description != null) {
            stringResource(R.string.keyboard_shortcut_description_label, key, title, description)
        } else {
            stringResource(R.string.keyboard_shortcut_description_label, key, title, "")
        }

    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp)
                .semantics(mergeDescendants = true) {
                    contentDescription = a11yLabel
                },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(spacing),
    ) {
        // Key badge
        Card(
            shape = RoundedCornerShape(6.dp),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                ),
        ) {
            Text(
                text = key,
                style =
                    MaterialTheme.typography.bodyMedium.copy(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.SemiBold,
                    ),
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }

        Spacer(Modifier.width(4.dp))

        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            if (description != null) {
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun TipText(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier =
            Modifier.semantics {
                contentDescription = text
            },
    )
}
