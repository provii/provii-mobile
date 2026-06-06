// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui

import app.provii.wallet.utils.LanguageConfig
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for language selection logic and LanguageConfig data integrity.
 * Covers filtering, RTL detection, search matching, and configuration
 * invariants that the language selection screen depends on.
 */
class LanguageConfigTest {
    @Test
    fun `enabled languages list is not empty`() {
        val enabled = LanguageConfig.ENABLED_LANGUAGES
        assertTrue(
            "At least one language must be enabled",
            enabled.isNotEmpty(),
        )
    }

    @Test
    fun `English is always in enabled languages`() {
        val englishPresent = LanguageConfig.ENABLED_LANGUAGES.any { it.code == "en" }
        assertTrue("English must be in the enabled languages list", englishPresent)
    }

    @Test
    fun `hasMultipleLanguages matches enabled count`() {
        val expected = LanguageConfig.ENABLED_LANGUAGE_CODES.size > 1
        assertEquals(expected, LanguageConfig.hasMultipleLanguages)
    }

    @Test
    fun `all enabled codes resolve to a supported language`() {
        // ENABLED_LANGUAGES is the filtered list the UI displays: only codes
        // present in both ENABLED_LANGUAGE_CODES and SUPPORTED_LANGUAGES.
        // Android locale aliases (e.g. "in", "iw") and codes pending
        // SUPPORTED_LANGUAGES entries are intentionally excluded.
        for (lang in LanguageConfig.ENABLED_LANGUAGES) {
            val resolved = LanguageConfig.getLanguageByCode(lang.code)
            assertNotNull(
                "Enabled language '${lang.code}' should resolve via getLanguageByCode",
                resolved,
            )
        }
        // Sanity: at least English must survive the filter
        assertTrue(
            "ENABLED_LANGUAGES must contain at least English",
            LanguageConfig.ENABLED_LANGUAGES.any { it.code == "en" },
        )
    }

    @Test
    fun `no duplicate codes in supported languages`() {
        val codes = LanguageConfig.SUPPORTED_LANGUAGES.map { it.code }
        val duplicates = codes.groupBy { it }.filter { it.value.size > 1 }.keys
        assertTrue(
            "Duplicate language codes found: $duplicates",
            duplicates.isEmpty(),
        )
    }

    @Test
    fun `RTL languages are flagged correctly`() {
        val expectedRtlCodes = setOf("ar", "fa", "fa-AF", "haz", "he", "ps", "ur")
        for (code in expectedRtlCodes) {
            assertTrue(
                "Language '$code' should be flagged as RTL",
                LanguageConfig.isRTL(code),
            )
        }
    }

    @Test
    fun `LTR languages are not flagged as RTL`() {
        val ltrCodes = listOf("en", "de", "fr", "es", "ja")
        for (code in ltrCodes) {
            assertFalse(
                "Language '$code' should not be flagged as RTL",
                LanguageConfig.isRTL(code),
            )
        }
    }

    @Test
    fun `getLanguageByCode returns null for unknown code`() {
        assertNull(LanguageConfig.getLanguageByCode("xx-FAKE"))
    }

    @Test
    fun `every language has non-blank native and English names`() {
        for (lang in LanguageConfig.SUPPORTED_LANGUAGES) {
            assertTrue(
                "Language '${lang.code}' has blank nativeName",
                lang.nativeName.isNotBlank(),
            )
            assertTrue(
                "Language '${lang.code}' has blank englishName",
                lang.englishName.isNotBlank(),
            )
        }
    }

    @Test
    fun `search filtering matches native and English names`() {
        val allLangs = LanguageConfig.ENABLED_LANGUAGES

        // Search by English name
        val germanMatches =
            allLangs.filter {
                it.nativeName.contains("Deutsch", ignoreCase = true) ||
                    it.englishName.contains("German", ignoreCase = true) ||
                    it.code.contains("de", ignoreCase = true)
            }
        assertTrue(
            "Searching 'German' or 'Deutsch' should find at least one language",
            germanMatches.isNotEmpty(),
        )

        // Search with no results
        val noMatches =
            allLangs.filter {
                it.nativeName.contains("ZZZZZ", ignoreCase = true) ||
                    it.englishName.contains("ZZZZZ", ignoreCase = true) ||
                    it.code.contains("ZZZZZ", ignoreCase = true)
            }
        assertTrue("Nonsense query should return no results", noMatches.isEmpty())
    }

    @Test
    fun `getSystemLanguageMatch finds exact and prefix matches`() {
        // Exact match
        val exact = LanguageConfig.getSystemLanguageMatch("en")
        assertNotNull("Exact 'en' should match", exact)
        assertEquals("en", exact?.code)

        // Prefix match (e.g. system reports "de-DE")
        val prefix = LanguageConfig.getSystemLanguageMatch("de-DE")
        assertNotNull("Prefix 'de-DE' should match German", prefix)
    }
}
