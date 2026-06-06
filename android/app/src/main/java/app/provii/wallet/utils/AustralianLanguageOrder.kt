// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

/**
 * Language ordering based on Australian Bureau of Statistics 2021 Census data.
 * Languages are ordered by number of speakers in Australia after English. This
 * ordering is used in the language picker so that the most commonly spoken
 * Australian languages appear first, followed by the remaining languages
 * sorted alphabetically.
 *
 * Source: ABS Census 2021, Languages spoken at home
 * https://www.abs.gov.au/statistics/people/people-and-communities/cultural-diversity-census/2021
 */
object AustralianLanguageOrder {
    /**
     * Data class for rotating button text showing "Change Language" in different languages
     */
    data class RotatingLanguage(
        val code: String,
        val nativeText: String, // "Change Language" in that language
        val isRtl: Boolean = false,
    )

    /**
     * All 62 supported languages for button text rotation.
     * Shows "Change Language" translated into each language.
     * Ordered by Australian population, then alphabetically.
     */
    val ROTATION_LANGUAGES =
        listOf(
            // Top Australian languages by population
            RotatingLanguage("zh-CN", "更改语言"), // Chinese Simplified (DeepL verified)
            RotatingLanguage("ar", "غيّر اللغة", isRtl = true), // Arabic
            RotatingLanguage("vi", "Thay đổi ngôn ngữ"), // Vietnamese
            RotatingLanguage("zh-TW", "變更語言"), // Chinese Traditional (DeepL verified)
            RotatingLanguage("el", "Αλλαγή γλώσσας"), // Greek
            RotatingLanguage("it", "Cambia lingua"), // Italian
            RotatingLanguage("hi", "भाषा बदलें"), // Hindi
            RotatingLanguage("es", "Cambiar idioma"), // Spanish
            RotatingLanguage("pa", "ਭਾਸ਼ਾ ਬਦਲੋ"), // Punjabi
            RotatingLanguage("tl", "Palitan ang wika"), // Tagalog/Filipino
            RotatingLanguage("ko", "언어 변경"), // Korean
            RotatingLanguage("ta", "மொழியை மாற்றவும்"), // Tamil
            RotatingLanguage("ne", "भाषा परिवर्तन गर्नुहोस्"), // Nepali
            RotatingLanguage("ur", "زبان بدلو", isRtl = true), // Urdu
            RotatingLanguage("fa", "تغییر زبان", isRtl = true), // Persian/Farsi
            RotatingLanguage("bn", "ভাষা পরিবর্তন"), // Bengali
            RotatingLanguage("id", "Ubah bahasa"), // Indonesian
            RotatingLanguage("ja", "言語を変更"), // Japanese
            RotatingLanguage("de", "Sprache ändern"), // German
            RotatingLanguage("fr", "Changer de langue"), // French
            RotatingLanguage("th", "เปลี่ยนภาษา"), // Thai
            RotatingLanguage("si", "භාෂාව වෙනස් කරන්න"), // Sinhala
            RotatingLanguage("tr", "Dili değiştir"), // Turkish
            RotatingLanguage("fa-AF", "تغییر زبان", isRtl = true), // Dari
            RotatingLanguage("ps", "ژبه بدله کړئ", isRtl = true), // Pashto
            RotatingLanguage("ml", "ഭാഷ മാറ്റുക"), // Malayalam
            // Gujarati dropped
            RotatingLanguage("pl", "Zmień język"), // Polish
            RotatingLanguage("ru", "Изменить язык"), // Russian
            RotatingLanguage("hr", "Promijeni jezik"), // Croatian
            RotatingLanguage("sr", "Промени језик"), // Serbian
            RotatingLanguage("mk", "Промени јазик"), // Macedonian
            // Remaining languages alphabetically
            RotatingLanguage("am", "ቋንቋ ቀይር"), // Amharic
            RotatingLanguage("bg", "Промяна на езика"), // Bulgarian (DeepL verified)
            RotatingLanguage("bo", "སྐད་ཡིག་བསྒྱུར་བ།"), // Tibetan
            RotatingLanguage("bs", "Promijeni jezik"), // Bosnian
            RotatingLanguage("cnh", "Holh Thleng"), // Hakha Chin
            RotatingLanguage("din", "Gɛɛr thoŋ"), // Dinka
            RotatingLanguage("fi", "Vaihda kieltä"), // Finnish (DeepL verified)
            RotatingLanguage("haz", "تغییر زبان", isRtl = true), // Hazaragi
            RotatingLanguage("he", "שנה שפה", isRtl = true), // Hebrew
            RotatingLanguage("hmn", "Hloov lus"), // Hmong
            RotatingLanguage("hy", "Փոխել լեզուն"), // Armenian
            RotatingLanguage("kar", "ကညီကျိ ဆီလဲ"), // Karen
            RotatingLanguage("km", "ប្តូរភាសា"), // Khmer
            RotatingLanguage("ku", "Zimanî biguherîne"), // Kurdish
            RotatingLanguage("lo", "ປ່ຽນພາສາ"), // Lao
            RotatingLanguage("mt", "Biddel il-lingwa"), // Maltese
            // Burmese dropped
            RotatingLanguage("nl", "Taal wijzigen"), // Dutch
            RotatingLanguage("pt", "Mudar idioma"), // Portuguese
            RotatingLanguage("rhg", "Zuban bodaló"), // Rohingya
            RotatingLanguage("rn", "Hindura ururimi"), // Kirundi
            RotatingLanguage("ro", "Schimbă limba"), // Romanian
            RotatingLanguage("sk", "Zmeniť jazyk"), // Slovak
            RotatingLanguage("sl", "Spremeni jezik"), // Slovenian
            RotatingLanguage("sm", "Sui le gagana"), // Samoan
            RotatingLanguage("so", "Beddel luuqadda"), // Somali
            RotatingLanguage("sq", "Ndrysho gjuhën"), // Albanian
            RotatingLanguage("sw", "Badilisha lugha"), // Swahili
            RotatingLanguage("ti", "ቋንቋ ቀይር"), // Tigrinya
        )

    /**
     * Language codes ordered by Australian population (after English).
     * Used to sort the full language picker.
     */
    private val AUSTRALIAN_POPULATION_ORDER =
        listOf(
            "en", // English (default, always first)
            "zh-CN", // Mandarin
            "ar", // Arabic
            "vi", // Vietnamese
            "zh-TW", // Cantonese/Traditional Chinese
            "el", // Greek
            "it", // Italian
            "hi", // Hindi
            "es", // Spanish
            "pa", // Punjabi
            "tl", // Filipino/Tagalog
            "ko", // Korean
            "ta", // Tamil
            "ne", // Nepali
            "ur", // Urdu
            "fa", // Persian/Farsi
            "bn", // Bengali
            "id", // Indonesian
            "ja", // Japanese
            "de", // German
            "fr", // French
            "th", // Thai
            "si", // Sinhalese
            "tr", // Turkish
            "fa-AF", // Dari
            "ps", // Pashto
            "ml", // Malayalam
            "te", // Telugu
            // Gujarati dropped
            "pl", // Polish
            "ru", // Russian
            "hr", // Croatian
            "sr", // Serbian
            "mk", // Macedonian
            "nl", // Dutch
            "hu", // Hungarian
            "pt", // Portuguese
            "ro", // Romanian
            "sk", // Slovak
            "sl", // Slovenian
            "lt", // Lithuanian
            "bg", // Bulgarian
            "cs", // Czech
            "da", // Danish
            "fi", // Finnish
            "sv", // Swedish
            "am", // Amharic
            "ti", // Tigrinya
            "so", // Somali
            "sw", // Swahili
            // Burmese dropped
            "km", // Khmer
            "lo", // Lao
            "he", // Hebrew
            "ku", // Kurdish
            "mt", // Maltese
            "sm", // Samoan
            "bs", // Bosnian
        )

    /**
     * Returns supported languages sorted by Australian population.
     * English is always first, followed by languages ordered by number of speakers.
     * Languages not in the population list are sorted alphabetically at the end.
     */
    fun getLanguagesSortedByAustralianPopulation(): List<Language> {
        val orderMap =
            AUSTRALIAN_POPULATION_ORDER.withIndex()
                .associate { it.value to it.index }

        return LanguageConfig.SUPPORTED_LANGUAGES.sortedWith(
            compareBy(
                { orderMap[it.code] ?: Int.MAX_VALUE },
                { it.englishName },
            ),
        )
    }

    /**
     * Gets the position of a language in the Australian population ranking.
     * Returns null if the language is not in the top languages list.
     */
    fun getPopulationRank(languageCode: String): Int? {
        val index = AUSTRALIAN_POPULATION_ORDER.indexOf(languageCode)
        return if (index >= 0) index + 1 else null
    }
}
