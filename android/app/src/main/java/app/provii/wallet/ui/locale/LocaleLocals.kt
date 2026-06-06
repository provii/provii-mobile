// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.locale

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import java.util.Locale

/**
 * Composition locals that propagate the current application locale and a locale-change
 * callback through the Compose tree. Used by language selection screens and any
 * composable that needs to observe or trigger runtime locale changes without direct
 * coupling to the Activity or ViewModel layer.
 */

/**
 * CompositionLocal for the current app locale.
 * Allows Compose tree to reactively observe locale changes.
 */
val LocalAppLocale = compositionLocalOf { Locale.getDefault() }

/**
 * CompositionLocal for locale change callback.
 * Use this to trigger language changes from anywhere in the Compose tree.
 */
val LocalOnLocaleChange =
    staticCompositionLocalOf<(String) -> Unit> {
        { _ -> } // No-op default
    }
