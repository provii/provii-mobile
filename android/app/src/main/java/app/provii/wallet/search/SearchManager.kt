// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.search

import android.content.Context
import app.provii.wallet.utils.LanguageConfig
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import app.provii.wallet.R

enum class SearchableItemType {
    SCREEN,
    SETTING,
    HELP_TOPIC,
    FEATURE,
}

data class SearchableItem(
    val id: String,
    val title: String,
    val subtitle: String?,
    val keywords: List<String>,
    val type: SearchableItemType,
    val destination: SearchDestination,
    val icon: ImageVector,
    val iconColor: Color,
) {
    fun matches(query: String): Boolean {
        val lowercasedQuery = query.lowercase()
        return title.lowercase().contains(lowercasedQuery) ||
            (subtitle?.lowercase()?.contains(lowercasedQuery) ?: false) ||
            keywords.any { it.lowercase().contains(lowercasedQuery) }
    }
}

sealed class SearchDestination {
    object AccessibilitySettings : SearchDestination()

    object Settings : SearchDestination()

    object Credentials : SearchDestination()

    object Help : SearchDestination()

    object WhereToGet : SearchDestination()

    object LanguageSelection : SearchDestination()

    data class SpecificHelpTopic(val topicId: Int) : SearchDestination()
}

/**
 * In-app search engine that indexes screens, settings, help topics, and features
 * into a queryable catalogue. Search input is capped at 200 characters to match
 * the iOS implementation. Results are ranked by relevance: exact title match first,
 * then prefix match, then substring match, then alphabetical order.
 */
class SearchManager(context: Context) {
    var searchQuery by mutableStateOf("")
    var searchResults by mutableStateOf<List<SearchableItem>>(emptyList())
    var isSearching by mutableStateOf(false)

    private val allSearchableItems: List<SearchableItem> = createSearchableItems(context)

    fun search(query: String) {
        // Limit search input to 200 characters (matching iOS)
        searchQuery = query.take(200)

        if (searchQuery.isEmpty()) {
            searchResults = emptyList()
            isSearching = false
            return
        }

        isSearching = true

        // Filter items that match the (limited) query
        val matches = allSearchableItems.filter { it.matches(searchQuery) }

        // Sort by relevance
        searchResults =
            matches.sortedWith(
                compareBy(
                    // Exact matches first
                    { !it.title.equals(searchQuery, ignoreCase = true) },
                    // Title starts with query
                    { !it.title.startsWith(searchQuery, ignoreCase = true) },
                    // Title contains query
                    { !it.title.contains(searchQuery, ignoreCase = true) },
                    // Alphabetical
                    { it.title },
                ),
            )
    }

    fun clearSearch() {
        searchQuery = ""
        searchResults = emptyList()
        isSearching = false
    }

    companion object {
        private fun createSearchableItems(context: Context): List<SearchableItem> {
            val items = mutableListOf<SearchableItem>()

            // Accessibility Settings (HIGH PRIORITY)
            items.add(
                SearchableItem(
                    id = "accessibility_settings",
                    title = context.getString(R.string.search_item_accessibility_settings_title),
                    subtitle = context.getString(R.string.search_item_accessibility_settings_subtitle),
                    keywords =
                        listOf(
                            "accessibility", "a11y", "settings", "customize", "screen reader",
                            "voiceover", "talkback", "large text", "high contrast", "voice",
                            "speech", "disabilities", "wcag", "ada",
                        ),
                    type = SearchableItemType.SCREEN,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.AccessibilityNew,
                    iconColor = Color.Blue,
                ),
            )

            // Individual Accessibility Features
            items.add(
                SearchableItem(
                    id = "large_text",
                    title = context.getString(R.string.search_item_large_text_title),
                    subtitle = context.getString(R.string.search_item_large_text_subtitle),
                    keywords = listOf("large", "text", "size", "font", "bigger", "accessibility", "vision", "sight"),
                    type = SearchableItemType.SETTING,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.TextFields,
                    iconColor = Color.Blue,
                ),
            )

            items.add(
                SearchableItem(
                    id = "high_contrast",
                    title = context.getString(R.string.search_item_high_contrast_title),
                    subtitle = context.getString(R.string.search_item_high_contrast_subtitle),
                    keywords = listOf("high", "contrast", "visibility", "vision", "accessibility", "colors", "see better"),
                    type = SearchableItemType.SETTING,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.Contrast,
                    iconColor = Color.Blue,
                ),
            )

            items.add(
                SearchableItem(
                    id = "voice_input",
                    title = context.getString(R.string.search_item_voice_input_title),
                    subtitle = context.getString(R.string.search_item_voice_input_subtitle),
                    keywords = listOf("voice", "speech", "input", "control", "speak", "talk", "accessibility", "hands-free"),
                    type = SearchableItemType.SETTING,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.Mic,
                    iconColor = Color.Blue,
                ),
            )

            items.add(
                SearchableItem(
                    id = "manual_code_entry",
                    title = context.getString(R.string.search_item_manual_code_entry_title),
                    subtitle = context.getString(R.string.search_item_manual_code_entry_subtitle),
                    keywords = listOf("manual", "code", "entry", "type", "keyboard", "accessibility", "qr", "scan"),
                    type = SearchableItemType.SETTING,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.Keyboard,
                    iconColor = Color.Blue,
                ),
            )

            items.add(
                SearchableItem(
                    id = "simplified_ui",
                    title = context.getString(R.string.search_item_simplified_ui_title),
                    subtitle = context.getString(R.string.search_item_simplified_ui_subtitle),
                    keywords = listOf("simplified", "simple", "ui", "interface", "easy", "basic", "accessibility", "cognitive"),
                    type = SearchableItemType.SETTING,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.GridView,
                    iconColor = Color.Blue,
                ),
            )

            items.add(
                SearchableItem(
                    id = "color_blindness",
                    title = context.getString(R.string.search_item_color_blindness_title),
                    subtitle = context.getString(R.string.search_item_color_blindness_subtitle),
                    keywords = listOf("color", "blind", "blindness", "vision", "accessibility", "deuteranopia", "protanopia", "tritanopia"),
                    type = SearchableItemType.SETTING,
                    destination = SearchDestination.AccessibilitySettings,
                    icon = Icons.Default.Palette,
                    iconColor = Color.Blue,
                ),
            )

            // Settings
            items.add(
                SearchableItem(
                    id = "settings",
                    title = context.getString(R.string.search_item_settings_title),
                    subtitle = context.getString(R.string.search_item_settings_subtitle),
                    keywords = listOf("settings", "config", "configuration", "preferences", "options"),
                    type = SearchableItemType.SCREEN,
                    destination = SearchDestination.Settings,
                    icon = Icons.Default.Settings,
                    iconColor = Color.Gray,
                ),
            )

            if (LanguageConfig.hasMultipleLanguages) {
                items.add(
                    SearchableItem(
                        id = "language",
                        title = context.getString(R.string.search_item_language_title),
                        subtitle = context.getString(R.string.search_item_language_subtitle),
                        keywords = listOf("language", "translate", "locale", "español", "français", "deutsch", "italiano", "português"),
                        type = SearchableItemType.SCREEN,
                        destination = SearchDestination.LanguageSelection,
                        icon = Icons.Default.Language,
                        iconColor = Color.Green,
                    ),
                )
            }

            // Credentials
            items.add(
                SearchableItem(
                    id = "credentials",
                    title = context.getString(R.string.search_item_credentials_title),
                    subtitle = context.getString(R.string.search_item_credentials_subtitle),
                    keywords = listOf("credentials", "wallet", "id", "verification", "identity"),
                    type = SearchableItemType.SCREEN,
                    destination = SearchDestination.Credentials,
                    icon = Icons.Default.Wallet,
                    iconColor = Color(0xFF9C27B0), // Purple
                ),
            )

            items.add(
                SearchableItem(
                    id = "get_credential",
                    title = context.getString(R.string.search_item_get_credential_title),
                    subtitle = context.getString(R.string.search_item_get_credential_subtitle),
                    keywords = listOf("get", "obtain", "acquire", "credential", "issuer", "location", "where"),
                    type = SearchableItemType.SCREEN,
                    destination = SearchDestination.WhereToGet,
                    icon = Icons.Default.Add,
                    iconColor = Color.Blue,
                ),
            )

            // Help Topics
            items.add(
                SearchableItem(
                    id = "help",
                    title = context.getString(R.string.search_item_help_title),
                    subtitle = context.getString(R.string.search_item_help_subtitle),
                    keywords = listOf("help", "support", "assistance", "guide", "tutorial", "how to"),
                    type = SearchableItemType.SCREEN,
                    destination = SearchDestination.Help,
                    icon = Icons.AutoMirrored.Filled.Help,
                    iconColor = Color(0xFFFF9800), // Orange
                ),
            )

            // Privacy & Security
            items.add(
                SearchableItem(
                    id = "privacy",
                    title = context.getString(R.string.search_item_privacy_title),
                    subtitle = context.getString(R.string.search_item_privacy_subtitle),
                    keywords = listOf("privacy", "security", "protection", "safe", "secure", "data", "zero knowledge", "zkp"),
                    type = SearchableItemType.HELP_TOPIC,
                    destination = SearchDestination.SpecificHelpTopic(4),
                    icon = Icons.Default.Security,
                    iconColor = Color.Green,
                ),
            )

            // Verification
            items.add(
                SearchableItem(
                    id = "verification",
                    title = context.getString(R.string.search_item_verification_title),
                    subtitle = context.getString(R.string.search_item_verification_subtitle),
                    keywords = listOf("verify", "verification", "age", "proof", "prove", "check"),
                    type = SearchableItemType.HELP_TOPIC,
                    destination = SearchDestination.SpecificHelpTopic(2),
                    icon = Icons.Default.VerifiedUser,
                    iconColor = Color.Blue,
                ),
            )

            return items
        }
    }
}
