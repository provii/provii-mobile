// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import app.provii.wallet.R

/**
 * Abbreviation expansion components satisfying WCAG 2.2 criteria 3.1.2 (Language of
 * Parts) and 3.1.4 (Abbreviations). On first use per session, screen readers announce
 * the full expanded form; subsequent occurrences use the short form only. All display
 * strings are resolved from localised string resources.
 */

/**
 * WCAG 2.2 Level AA: 3.1.2 Language of Parts
 * WCAG 2.2 Level AAA: 3.1.4 Abbreviations
 *
 * Component that expands abbreviations on first use per session.
 * Provides screen reader users with the full expanded form on first encounter.
 * Uses localized string resources to ensure proper language tagging.
 *
 * Example:
 * ```
 * AbbreviationText("QR")
 * // First use: Screen reader announces "Quick Response (QR)" in the device locale
 * // Subsequent uses: Screen reader announces "QR"
 * ```
 */
object AbbreviationManager {
    private val firstUseTracker = mutableStateListOf<String>()

    fun isFirstUse(abbreviation: String): Boolean {
        return !firstUseTracker.contains(abbreviation)
    }

    fun markAsUsed(abbreviation: String) {
        firstUseTracker.add(abbreviation)
    }

    fun reset() {
        firstUseTracker.clear()
    }
}

enum class Abbreviation(val shortResId: Int, val expandedResId: Int) {
    QR(R.string.abbreviation_qr_short, R.string.abbreviation_qr_expanded),
    PIN(R.string.abbreviation_pin_short, R.string.abbreviation_pin_expanded),
    DOB(R.string.abbreviation_dob_short, R.string.abbreviation_dob_expanded),
    ID(R.string.abbreviation_id_short, R.string.abbreviation_id_expanded),
    UI(R.string.abbreviation_ui_short, R.string.abbreviation_ui_expanded),
    URL(R.string.abbreviation_url_short, R.string.abbreviation_url_expanded),
    API(R.string.abbreviation_api_short, R.string.abbreviation_api_expanded),
    ;

    companion object {
        fun fromString(value: String): Abbreviation? {
            return values().find { abbr ->
                // Match against the uppercase version of the abbreviation name
                abbr.name == value.uppercase()
            }
        }
    }
}

/**
 * Composable that renders an abbreviation with automatic expansion on first use.
 * Uses localized string resources for proper language support (WCAG 3.1.2).
 *
 * @param abbreviation The abbreviation text (e.g., "QR", "PIN", "ID")
 * @param modifier Optional modifier for the Text component
 * @param style Optional TextStyle for custom styling
 */
@Composable
fun AbbreviationText(
    abbreviation: String,
    modifier: Modifier = Modifier,
    style: TextStyle = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
) {
    val abbr = remember(abbreviation) { Abbreviation.fromString(abbreviation) }
    val isFirstUse = remember(abbreviation) { AbbreviationManager.isFirstUse(abbreviation) }

    if (isFirstUse && abbr != null) {
        AbbreviationManager.markAsUsed(abbreviation)
    }

    // Get localized strings from resources
    val displayText =
        if (abbr != null) {
            stringResource(abbr.shortResId)
        } else {
            abbreviation
        }

    val accessibilityText =
        if (isFirstUse && abbr != null) {
            stringResource(abbr.expandedResId)
        } else if (abbr != null) {
            stringResource(abbr.shortResId)
        } else {
            abbreviation
        }

    Text(
        text = displayText,
        modifier =
            modifier.semantics {
                contentDescription = accessibilityText
            },
        style = style,
    )
}

/**
 * Alternative version that takes a full text with embedded abbreviation.
 * Use this when the abbreviation is part of a larger text string.
 * Uses localized string resources for proper language support (WCAG 3.1.2).
 *
 * Example:
 * ```
 * AbbreviationTextInline("Scan QR code", "QR")
 * // First use: Screen reader announces "Scan Quick Response (QR) code" in device locale
 * // Subsequent uses: Screen reader announces "Scan QR code"
 * ```
 */
@Composable
fun AbbreviationTextInline(
    text: String,
    abbreviation: String,
    modifier: Modifier = Modifier,
    style: TextStyle = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
) {
    val abbr = remember(abbreviation) { Abbreviation.fromString(abbreviation) }
    val isFirstUse = remember(abbreviation) { AbbreviationManager.isFirstUse(abbreviation) }

    if (isFirstUse && abbr != null) {
        AbbreviationManager.markAsUsed(abbreviation)
    }

    // Get localized strings from resources
    val shortForm = if (abbr != null) stringResource(abbr.shortResId) else abbreviation
    val expandedForm = if (abbr != null) stringResource(abbr.expandedResId) else abbreviation

    val accessibilityText =
        if (isFirstUse && abbr != null) {
            text.replace(shortForm, expandedForm, ignoreCase = true)
        } else {
            text
        }

    Text(
        text = text,
        modifier =
            modifier.semantics {
                contentDescription = accessibilityText
            },
        style = style,
    )
}
