// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

/**
 * Centralised language configuration for the app. Single source of truth for all
 * 62 supported languages, including RTL flags for Arabic, Persian, Dari, Hazaragi,
 * Hebrew, Pashto, and Urdu. Used by the language picker, RTL layout utilities,
 * and the rotating "Change Language" button on the onboarding screen.
 */
data class Language(
    val code: String,
    val englishName: String,
    val nativeName: String,
    val isRTL: Boolean = false,
)

object LanguageConfig {
    /**
     * All 62 supported languages with proper RTL flags.
     * RTL languages: Arabic, Persian/Farsi, Dari, Hazaragi, Hebrew, Pashto, Urdu
     */
    val SUPPORTED_LANGUAGES: List<Language> =
        listOf(
            Language("am", "Amharic", "አማርኛ"),
            Language("ar", "Arabic", "العربية", isRTL = true),
            Language("bg", "Bulgarian", "Български"),
            Language("bn", "Bengali", "বাংলা"),
            Language("bo", "Tibetan", "བོད་སྐད"),
            Language("bs", "Bosnian", "Bosanski"),
            Language("cnh", "Hakha Chin", "Hakha Lai"),
            Language("de", "German", "Deutsch"),
            Language("din", "Dinka", "Thuɔŋjäŋ"),
            Language("el", "Greek", "Ελληνικά"),
            Language("en", "English", "English"),
            Language("es", "Spanish", "Español"),
            Language("fa", "Persian/Farsi", "فارسی", isRTL = true),
            Language("fa-AF", "Dari (Afghan Persian)", "دری", isRTL = true),
            Language("fi", "Finnish", "Suomi"),
            Language("fr", "French", "Français"),
            // Gujarati dropped due to persistent translation corruption
            Language("haz", "Hazaragi", "هزارگی", isRTL = true),
            Language("he", "Hebrew", "עברית", isRTL = true),
            Language("hi", "Hindi", "हिन्दी"),
            Language("hmn", "Hmong", "Hmoob"),
            Language("hr", "Croatian", "Hrvatski"),
            Language("hy", "Armenian", "Հայերեն"),
            Language("id", "Indonesian", "Bahasa Indonesia"),
            Language("it", "Italian", "Italiano"),
            Language("ja", "Japanese", "日本語"),
            Language("kar", "Karen", "ကညီကျိ"),
            Language("km", "Khmer", "ភាសាខ្មែរ"),
            Language("ko", "Korean", "한국어"),
            Language("ku", "Kurdish", "Kurdî"),
            Language("lo", "Lao", "ລາວ"),
            Language("mk", "Macedonian", "Македонски"),
            Language("ml", "Malayalam", "മലയാളം"),
            Language("mt", "Maltese", "Malti"),
            // Burmese dropped due to translation agent failures
            Language("ne", "Nepali", "नेपाली"),
            Language("nl", "Dutch", "Nederlands"),
            Language("pa", "Punjabi", "ਪੰਜਾਬੀ"),
            Language("pl", "Polish", "Polski"),
            Language("ps", "Pashto", "پښتو", isRTL = true),
            Language("pt", "Portuguese", "Português"),
            Language("rhg", "Rohingya", "Ruáingga"),
            Language("rn", "Kirundi", "Ikirundi"),
            Language("ro", "Romanian", "Română"),
            Language("ru", "Russian", "Русский"),
            Language("si", "Sinhala", "සිංහල"),
            Language("sk", "Slovak", "Slovenčina"),
            Language("sl", "Slovenian", "Slovenščina"),
            Language("sm", "Samoan", "Gagana Samoa"),
            Language("so", "Somali", "Soomaali"),
            Language("sq", "Albanian", "Shqip"),
            Language("sr", "Serbian", "Српски"),
            Language("sw", "Swahili", "Kiswahili"),
            Language("ta", "Tamil", "தமிழ்"),
            Language("th", "Thai", "ไทย"),
            Language("ti", "Tigrinya", "ትግርኛ"),
            Language("tl", "Tagalog/Filipino", "Tagalog"),
            Language("tr", "Turkish", "Türkçe"),
            Language("ur", "Urdu", "اردو", isRTL = true),
            Language("vi", "Vietnamese", "Tiếng Việt"),
            Language("zh-CN", "Chinese (Simplified)", "简体中文"),
            Language("zh-HK", "Cantonese (Traditional)", "廣東話"),
            Language("zh-TW", "Chinese (Traditional)", "繁體中文"),
        )

    /**
     * Language codes currently enabled in the app. Add codes here to enable more languages.
     * NOTE: Android uses legacy Java locale codes (in, iw, tl, zh-CN, zh-HK).
     * iOS uses BCP 47 codes (id, he, fil, zh-Hans, zh-Hant).
     * Both platforms must enable the same set of languages. When adding
     * a code here, also update LanguageSettings.swift enabledLanguageCodes.
     */
    val ENABLED_LANGUAGE_CODES: Set<String> =
        setOf(
            "en",
            "af", "am", "ar", "az",
            "bn", "bs", "bg",
            "ca", "cs",
            "da", "de",
            "el", "es",
            "fa", "fi", "fil", "fr",
            "hi", "hr", "hu",
            "in", "it", "iw",
            "ja",
            "ka", "km", "kn", "ko",
            "lo", "lt", "lv",
            "mk", "ml", "mr", "ms",
            "nb", "ne", "nl",
            "pa", "pl", "pt-BR",
            "ro", "ru",
            "si", "sk", "so", "sr", "sv", "sw",
            "ta", "te", "th", "tl", "tr",
            "uk", "ur",
            "vi",
            "zh-CN", "zh-HK",
        )

    /** Languages currently available to users. Subset of SUPPORTED_LANGUAGES filtered by ENABLED_LANGUAGE_CODES. */
    val ENABLED_LANGUAGES: List<Language>
        get() = SUPPORTED_LANGUAGES.filter { it.code in ENABLED_LANGUAGE_CODES }

    /** Whether multiple languages are currently available to users. */
    val hasMultipleLanguages: Boolean
        get() = ENABLED_LANGUAGE_CODES.size > 1

    fun getLanguageByCode(code: String): Language? =
        SUPPORTED_LANGUAGES.find { it.code.equals(code, ignoreCase = true) }

    fun isRTL(code: String): Boolean =
        getLanguageByCode(code)?.isRTL ?: false

    fun getSystemLanguageMatch(systemLocale: String): Language? {
        // Try exact match first
        getLanguageByCode(systemLocale)?.let { return it }

        // Try two-part prefix (e.g. "zh-Hant" from "zh-Hant-HK")
        val parts = systemLocale.split("-", "_")
        if (parts.size > 2) {
            val twoPartCode = parts.take(2).joinToString("-")
            getLanguageByCode(twoPartCode)?.let { return it }
        }

        // Try language-only match (e.g., "en" matches "en-US")
        val languageOnly = parts.firstOrNull() ?: return null
        return SUPPORTED_LANGUAGES.find {
            it.code == languageOnly || it.code.startsWith("$languageOnly-")
        }
    }
}
