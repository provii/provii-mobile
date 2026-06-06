// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LanguageConfigTest2 {
    @Test
    fun `SUPPORTED_LANGUAGES is non-empty`() {
        assertTrue(LanguageConfig.SUPPORTED_LANGUAGES.isNotEmpty())
    }

    @Test
    fun `SUPPORTED_LANGUAGES includes English`() {
        val en = LanguageConfig.SUPPORTED_LANGUAGES.find { it.code == "en" }
        assertNotNull(en)
        assertEquals("English", en!!.englishName)
    }

    @Test
    fun `RTL languages are flagged correctly`() {
        val rtlCodes = setOf("ar", "fa", "fa-AF", "haz", "he", "ps", "ur")
        LanguageConfig.SUPPORTED_LANGUAGES.forEach { lang ->
            if (lang.code in rtlCodes) {
                assertTrue("${lang.code} should be RTL", lang.isRTL)
            } else {
                assertFalse("${lang.code} should not be RTL", lang.isRTL)
            }
        }
    }

    @Test
    fun `getLanguageByCode returns correct language`() {
        val ar = LanguageConfig.getLanguageByCode("ar")
        assertNotNull(ar)
        assertEquals("Arabic", ar!!.englishName)
        assertTrue(ar.isRTL)
    }

    @Test
    fun `getLanguageByCode is case insensitive`() {
        val en = LanguageConfig.getLanguageByCode("EN")
        assertNotNull(en)
        assertEquals("English", en!!.englishName)
    }

    @Test
    fun `getLanguageByCode returns null for unknown code`() {
        assertNull(LanguageConfig.getLanguageByCode("xx"))
    }

    @Test
    fun `isRTL returns true for Arabic`() {
        assertTrue(LanguageConfig.isRTL("ar"))
    }

    @Test
    fun `isRTL returns false for English`() {
        assertFalse(LanguageConfig.isRTL("en"))
    }

    @Test
    fun `isRTL returns false for unknown code`() {
        assertFalse(LanguageConfig.isRTL("xx"))
    }

    @Test
    fun `hasMultipleLanguages is true when ENABLED_LANGUAGE_CODES has more than one`() {
        assertTrue(LanguageConfig.hasMultipleLanguages)
    }

    @Test
    fun `ENABLED_LANGUAGES is subset of SUPPORTED_LANGUAGES`() {
        val supportedCodes = LanguageConfig.SUPPORTED_LANGUAGES.map { it.code }.toSet()
        LanguageConfig.ENABLED_LANGUAGES.forEach { lang ->
            assertTrue("${lang.code} should be in SUPPORTED_LANGUAGES", lang.code in supportedCodes)
        }
    }

    @Test
    fun `getSystemLanguageMatch returns exact match`() {
        val match = LanguageConfig.getSystemLanguageMatch("ar")
        assertNotNull(match)
        assertEquals("ar", match!!.code)
    }

    @Test
    fun `getSystemLanguageMatch returns prefix match`() {
        val match = LanguageConfig.getSystemLanguageMatch("en-US")
        assertNotNull(match)
        assertEquals("en", match!!.code)
    }

    @Test
    fun `getSystemLanguageMatch returns null for unmatched locale`() {
        assertNull(LanguageConfig.getSystemLanguageMatch("xx-YY"))
    }

    @Test
    fun `getSystemLanguageMatch handles three-part locale`() {
        val match = LanguageConfig.getSystemLanguageMatch("zh-Hant-HK")
        // Should try "zh-Hant" then "zh"
        assertNotNull(match)
    }
}

class AustralianLanguageOrderTest {
    @Test
    fun `getLanguagesSortedByAustralianPopulation puts English first`() {
        val sorted = AustralianLanguageOrder.getLanguagesSortedByAustralianPopulation()
        assertTrue(sorted.isNotEmpty())
        assertEquals("en", sorted[0].code)
    }

    @Test
    fun `getPopulationRank returns 1 for English`() {
        assertEquals(1, AustralianLanguageOrder.getPopulationRank("en"))
    }

    @Test
    fun `getPopulationRank returns null for unknown language`() {
        assertNull(AustralianLanguageOrder.getPopulationRank("xx"))
    }

    @Test
    fun `ROTATION_LANGUAGES contains correct RTL flags`() {
        val expectedRtl = setOf("ar", "fa", "fa-AF", "haz", "he", "ps", "ur")
        AustralianLanguageOrder.ROTATION_LANGUAGES.forEach { lang ->
            if (lang.code in expectedRtl) {
                assertTrue("${lang.code} should be RTL in rotation", lang.isRtl)
            }
        }
    }

    @Test
    fun `ROTATION_LANGUAGES has non-empty native text for all entries`() {
        AustralianLanguageOrder.ROTATION_LANGUAGES.forEach { lang ->
            assertTrue("${lang.code} nativeText should not be blank", lang.nativeText.isNotBlank())
        }
    }
}

class RtlLanguageTest {
    @Test
    fun `isRtlLocale returns true for Arabic locale`() {
        assertTrue(RtlLanguage.isRtlLocale(java.util.Locale("ar")))
    }

    @Test
    fun `isRtlLocale returns false for English locale`() {
        assertFalse(RtlLanguage.isRtlLocale(java.util.Locale.ENGLISH))
    }

    @Test
    fun `fromLocale returns correct RtlLanguage`() {
        val rtl = RtlLanguage.fromLocale(java.util.Locale("he"))
        assertNotNull(rtl)
        assertEquals(RtlLanguage.HEBREW, rtl)
    }

    @Test
    fun `fromLocale returns null for non-RTL locale`() {
        assertNull(RtlLanguage.fromLocale(java.util.Locale.FRENCH))
    }

    @Test
    fun `getLayoutDirection returns Rtl for Arabic`() {
        val dir = getLayoutDirection(java.util.Locale("ar"))
        assertEquals(androidx.compose.ui.unit.LayoutDirection.Rtl, dir)
    }

    @Test
    fun `getLayoutDirection returns Ltr for English`() {
        val dir = getLayoutDirection(java.util.Locale.ENGLISH)
        assertEquals(androidx.compose.ui.unit.LayoutDirection.Ltr, dir)
    }

    @Test
    fun `LayoutDirection opposite works correctly`() {
        assertEquals(
            androidx.compose.ui.unit.LayoutDirection.Rtl,
            androidx.compose.ui.unit.LayoutDirection.Ltr.opposite(),
        )
        assertEquals(
            androidx.compose.ui.unit.LayoutDirection.Ltr,
            androidx.compose.ui.unit.LayoutDirection.Rtl.opposite(),
        )
    }

    @Test
    fun `RtlTestingUtils getAllRtlLocales returns all RTL locales`() {
        val locales = RtlTestingUtils.getAllRtlLocales()
        assertEquals(RtlLanguage.values().size, locales.size)
    }

    @Test
    fun `RtlTestingUtils testCases is non-empty`() {
        assertTrue(RtlTestingUtils.testCases.isNotEmpty())
    }
}
