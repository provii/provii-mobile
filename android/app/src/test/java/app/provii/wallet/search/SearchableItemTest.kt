// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.search

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchableItemTest {
    private fun makeItem(
        title: String = "Test Title",
        subtitle: String? = "Test subtitle",
        keywords: List<String> = listOf("key1", "key2"),
    ) = SearchableItem(
        id = "test-id",
        title = title,
        subtitle = subtitle,
        keywords = keywords,
        type = SearchableItemType.SCREEN,
        destination = SearchDestination.Settings,
        icon = Icons.Default.Settings,
        iconColor = Color.Gray,
    )

    @Test
    fun matchesReturnsTrueForTitleMatch() {
        assertTrue(makeItem(title = "Settings").matches("settings"))
    }

    @Test
    fun matchesReturnsTrueForSubtitleMatch() {
        assertTrue(makeItem(subtitle = "App preferences").matches("preferences"))
    }

    @Test
    fun matchesReturnsTrueForKeywordMatch() {
        assertTrue(makeItem(keywords = listOf("config", "option")).matches("config"))
    }

    @Test
    fun matchesReturnsFalseForNoMatch() {
        assertFalse(makeItem().matches("nonexistent"))
    }

    @Test
    fun matchesIsCaseInsensitive() {
        assertTrue(makeItem(title = "Settings").matches("SETTINGS"))
    }

    @Test
    fun matchesHandlesNullSubtitle() {
        assertFalse(makeItem(subtitle = null).matches("missing"))
    }
}

class SearchableItemTypeTest {
    @Test
    fun allTypesExist() {
        val types = SearchableItemType.entries
        assertEquals(4, types.size)
        assertTrue(types.contains(SearchableItemType.SCREEN))
        assertTrue(types.contains(SearchableItemType.SETTING))
        assertTrue(types.contains(SearchableItemType.HELP_TOPIC))
        assertTrue(types.contains(SearchableItemType.FEATURE))
    }
}

class SearchDestinationTest {
    @Test
    fun specificHelpTopicPreservesId() {
        val dest = SearchDestination.SpecificHelpTopic(42)
        assertEquals(42, dest.topicId)
    }

    @Test
    fun sealedClassVariantsExist() {
        val variants = listOf(
            SearchDestination.AccessibilitySettings,
            SearchDestination.Settings,
            SearchDestination.Credentials,
            SearchDestination.Help,
            SearchDestination.WhereToGet,
            SearchDestination.LanguageSelection,
            SearchDestination.SpecificHelpTopic(1),
        )
        assertEquals(7, variants.size)
    }
}
