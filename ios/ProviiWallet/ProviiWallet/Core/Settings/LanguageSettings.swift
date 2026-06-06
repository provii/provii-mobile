// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Centralised language and localisation settings. Tracks the user's selected language code,
/// native and English names, RTL flag, and locale formatting preferences (date, time, number
/// formats). Conforms to `SettingsSection` for unified persistence. The static
/// `LanguageInfo.supportedLanguages` list enumerates all 60+ languages the app can display.
struct LanguageSettings: SettingsSection {
    static let storageKey = "language"
    static let defaultValue = LanguageSettings()
    static let schemaVersion = SettingsVersion.v2_0_0

    // MARK: - Onboarding State

    /// Whether the user has completed language selection during onboarding
    var hasSelectedLanguage: Bool = false

    // MARK: - Language Configuration

    /// Selected language code (e.g., "en", "ar", "es")
    var languageCode: String = "en"

    /// Language native name (e.g., "English", "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}")
    var nativeName: String = "English"

    /// Language English name
    var englishName: String = "English"

    /// Whether the selected language is right-to-left
    var isRTL: Bool = false

    // MARK: - Locale Preferences

    /// Preferred date format style
    var dateFormatStyle: DateFormatStyle = .medium

    /// Preferred time format (12h vs 24h)
    var timeFormat: TimeFormat = .system

    /// Preferred number format
    var numberFormat: NumberFormat = .system

    /// Use metric system for measurements
    var useMetricSystem: Bool = true

    // MARK: - Localisation Preferences

    /// Show translations for technical terms
    var showTranslations: Bool = false

    /// Preferred translation quality level
    var translationQuality: TranslationQuality = .standard

    /// Enable automatic language detection
    var autoDetectLanguage: Bool = true

    // MARK: - Computed Properties

    /// Whether RTL layout should be forced
    var shouldForceRTL: Bool {
        return isRTL
    }

    /// The locale identifier for the current settings
    var localeIdentifier: String {
        return languageCode
    }

    // MARK: - Supporting Types

    enum DateFormatStyle: String, Codable, CaseIterable {
        case short
        case medium
        case long
        case full

        var displayName: String {
            switch self {
            case .short: return "Short (12/31/24)"
            case .medium: return "Medium (Dec 31, 2024)"
            case .long: return "Long (December 31, 2024)"
            case .full: return "Full (Tuesday, December 31, 2024)"
            }
        }
    }

    enum TimeFormat: String, Codable, CaseIterable {
        case system
        case twelveHour = "12h"
        case twentyFourHour = "24h"

        var displayName: String {
            switch self {
            case .system: return "System Default"
            case .twelveHour: return "12-Hour (3:30 PM)"
            case .twentyFourHour: return "24-Hour (15:30)"
            }
        }
    }

    enum NumberFormat: String, Codable, CaseIterable {
        case system
        case western     // 1,234.56
        case european   // 1.234,56
        case indian       // 1,23,456.78

        var displayName: String {
            switch self {
            case .system: return "System Default"
            case .western: return "Western (1,234.56)"
            case .european: return "European (1.234,56)"
            case .indian: return "Indian (1,23,456.78)"
            }
        }
    }

    enum TranslationQuality: String, Codable, CaseIterable {
        case basic
        case standard
        case premium

        var displayName: String {
            switch self {
            case .basic: return "Basic"
            case .standard: return "Standard"
            case .premium: return "Premium"
            }
        }
    }
}

// MARK: - Language Information

extension LanguageSettings {
    struct LanguageInfo: Codable, Equatable {
        let code: String
        let nativeName: String
        let englishName: String
        let isRTL: Bool

        static let supportedLanguages: [LanguageInfo] = [
            LanguageInfo(code: "am", nativeName: "\u{12A0}\u{121B}\u{122D}\u{129B}", englishName: "Amharic", isRTL: false),
            LanguageInfo(code: "ar", nativeName: "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}", englishName: "Arabic", isRTL: true),
            LanguageInfo(code: "bg", nativeName: "\u{0411}\u{044A}\u{043B}\u{0433}\u{0430}\u{0440}\u{0441}\u{043A}\u{0438}", englishName: "Bulgarian", isRTL: false),
            LanguageInfo(code: "bn", nativeName: "\u{09AC}\u{09BE}\u{0982}\u{09B2}\u{09BE}", englishName: "Bengali", isRTL: false),
            LanguageInfo(code: "bo", nativeName: "\u{0F56}\u{0F7C}\u{0F51}\u{0F0B}\u{0F61}\u{0F72}\u{0F42}", englishName: "Tibetan", isRTL: false),
            LanguageInfo(code: "bs", nativeName: "Bosanski", englishName: "Bosnian", isRTL: false),
            LanguageInfo(code: "cnh", nativeName: "Lai", englishName: "Hakha Chin", isRTL: false),
            LanguageInfo(code: "de", nativeName: "Deutsch", englishName: "German", isRTL: false),
            LanguageInfo(code: "din", nativeName: "Thu\u{0254}\u{014B}j\u{00E4}\u{014B}", englishName: "Dinka", isRTL: false),
            LanguageInfo(code: "el", nativeName: "\u{0395}\u{03BB}\u{03BB}\u{03B7}\u{03BD}\u{03B9}\u{03BA}\u{03AC}", englishName: "Greek", isRTL: false),
            LanguageInfo(code: "en", nativeName: "English", englishName: "English", isRTL: false),
            LanguageInfo(code: "es", nativeName: "Espa\u{00F1}ol", englishName: "Spanish", isRTL: false),
            LanguageInfo(code: "fa", nativeName: "\u{0641}\u{0627}\u{0631}\u{0633}\u{06CC}", englishName: "Persian", isRTL: true),
            LanguageInfo(code: "fa-AF", nativeName: "\u{062F}\u{0631}\u{06CC}", englishName: "Dari", isRTL: true),
            LanguageInfo(code: "fi", nativeName: "Suomi", englishName: "Finnish", isRTL: false),
            LanguageInfo(code: "fr", nativeName: "Fran\u{00E7}ais", englishName: "French", isRTL: false),
            // Gujarati dropped due to persistent translation corruption
            LanguageInfo(code: "haz", nativeName: "\u{0647}\u{0632}\u{0627}\u{0631}\u{06AF}\u{06CC}", englishName: "Hazaragi", isRTL: true),
            LanguageInfo(code: "he", nativeName: "\u{05E2}\u{05D1}\u{05E8}\u{05D9}\u{05EA}", englishName: "Hebrew", isRTL: true),
            LanguageInfo(code: "hi", nativeName: "\u{0939}\u{093F}\u{0928}\u{094D}\u{0926}\u{0940}", englishName: "Hindi", isRTL: false),
            LanguageInfo(code: "hmn", nativeName: "Hmoob", englishName: "Hmong", isRTL: false),
            LanguageInfo(code: "hr", nativeName: "Hrvatski", englishName: "Croatian", isRTL: false),
            LanguageInfo(code: "hy", nativeName: "\u{0540}\u{0561}\u{0575}\u{0565}\u{0580}\u{0565}\u{0576}", englishName: "Armenian", isRTL: false),
            LanguageInfo(code: "id", nativeName: "Bahasa Indonesia", englishName: "Indonesian", isRTL: false),
            LanguageInfo(code: "it", nativeName: "Italiano", englishName: "Italian", isRTL: false),
            LanguageInfo(code: "ja", nativeName: "\u{65E5}\u{672C}\u{8A9E}", englishName: "Japanese", isRTL: false),
            LanguageInfo(code: "kar", nativeName: "\u{1000}\u{100A}\u{102E}\u{1000}\u{103B}\u{102C}\u{103A}", englishName: "Karen", isRTL: false),
            LanguageInfo(code: "km", nativeName: "\u{1781}\u{17D2}\u{1798}\u{17C2}\u{179A}", englishName: "Khmer", isRTL: false),
            LanguageInfo(code: "ko", nativeName: "\u{D55C}\u{AD6D}\u{C5B4}", englishName: "Korean", isRTL: false),
            LanguageInfo(code: "ku", nativeName: "\u{06A9}\u{0648}\u{0631}\u{062F}\u{06CC}", englishName: "Kurdish", isRTL: true),
            LanguageInfo(code: "lo", nativeName: "\u{0EA5}\u{0EB2}\u{0EA7}", englishName: "Lao", isRTL: false),
            LanguageInfo(code: "mk", nativeName: "\u{041C}\u{0430}\u{043A}\u{0435}\u{0434}\u{043E}\u{043D}\u{0441}\u{043A}\u{0438}", englishName: "Macedonian", isRTL: false),
            LanguageInfo(code: "ml", nativeName: "\u{0D2E}\u{0D32}\u{0D2F}\u{0D3E}\u{0D33}\u{0D02}", englishName: "Malayalam", isRTL: false),
            LanguageInfo(code: "mt", nativeName: "Malti", englishName: "Maltese", isRTL: false),
            // Burmese dropped due to translation agent failures
            LanguageInfo(code: "ne", nativeName: "\u{0928}\u{0947}\u{092A}\u{093E}\u{0932}\u{0940}", englishName: "Nepali", isRTL: false),
            LanguageInfo(code: "nl", nativeName: "Nederlands", englishName: "Dutch", isRTL: false),
            LanguageInfo(code: "pa", nativeName: "\u{0A2A}\u{0A70}\u{0A1C}\u{0A3E}\u{0A2C}\u{0A40}", englishName: "Punjabi", isRTL: false),
            LanguageInfo(code: "pl", nativeName: "Polski", englishName: "Polish", isRTL: false),
            LanguageInfo(code: "ps", nativeName: "\u{067E}\u{069A}\u{062A}\u{0648}", englishName: "Pashto", isRTL: true),
            LanguageInfo(code: "pt", nativeName: "Portugu\u{00EA}s", englishName: "Portuguese", isRTL: false),
            LanguageInfo(code: "rhg", nativeName: "Ru\u{00E1}ingga", englishName: "Rohingya", isRTL: false),
            LanguageInfo(code: "rn", nativeName: "Ikirundi", englishName: "Kirundi", isRTL: false),
            LanguageInfo(code: "ro", nativeName: "Rom\u{00E2}n\u{0103}", englishName: "Romanian", isRTL: false),
            LanguageInfo(code: "ru", nativeName: "\u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439}", englishName: "Russian", isRTL: false),
            LanguageInfo(code: "si", nativeName: "\u{0DC3}\u{0DD2}\u{0D82}\u{0DC4}\u{0DBD}", englishName: "Sinhala", isRTL: false),
            LanguageInfo(code: "sk", nativeName: "Sloven\u{010D}ina", englishName: "Slovak", isRTL: false),
            LanguageInfo(code: "sl", nativeName: "Sloven\u{0161}\u{010D}ina", englishName: "Slovenian", isRTL: false),
            LanguageInfo(code: "sm", nativeName: "Gagana Samoa", englishName: "Samoan", isRTL: false),
            LanguageInfo(code: "so", nativeName: "Soomaali", englishName: "Somali", isRTL: false),
            LanguageInfo(code: "sq", nativeName: "Shqip", englishName: "Albanian", isRTL: false),
            LanguageInfo(code: "sr", nativeName: "\u{0421}\u{0440}\u{043F}\u{0441}\u{043A}\u{0438}", englishName: "Serbian", isRTL: false),
            LanguageInfo(code: "sw", nativeName: "Kiswahili", englishName: "Swahili", isRTL: false),
            LanguageInfo(code: "ta", nativeName: "\u{0BA4}\u{0BAE}\u{0BBF}\u{0BB4}\u{0BCD}", englishName: "Tamil", isRTL: false),
            LanguageInfo(code: "th", nativeName: "\u{0E44}\u{0E17}\u{0E22}", englishName: "Thai", isRTL: false),
            LanguageInfo(code: "ti", nativeName: "\u{1275}\u{130D}\u{122D}\u{129B}", englishName: "Tigrinya", isRTL: false),
            LanguageInfo(code: "tl", nativeName: "Tagalog", englishName: "Tagalog", isRTL: false),
            LanguageInfo(code: "tr", nativeName: "T\u{00FC}rk\u{00E7}e", englishName: "Turkish", isRTL: false),
            LanguageInfo(code: "ur", nativeName: "\u{0627}\u{0631}\u{062F}\u{0648}", englishName: "Urdu", isRTL: true),
            LanguageInfo(code: "vi", nativeName: "Ti\u{1EBF}ng Vi\u{1EC7}t", englishName: "Vietnamese", isRTL: false),
            LanguageInfo(code: "zh-Hans", nativeName: "\u{7B80}\u{4F53}\u{4E2D}\u{6587}", englishName: "Simplified Chinese", isRTL: false),
            LanguageInfo(code: "zh-Hant", nativeName: "\u{7E41}\u{9AD4}\u{4E2D}\u{6587}", englishName: "Traditional Chinese", isRTL: false)
        ]

        /// Language codes currently enabled in the app. Add codes here to enable more languages.
        /// NOTE: iOS uses BCP 47 codes (id, he, zh-Hans, zh-Hant, fil).
        /// Android uses legacy Java codes (in, iw, zh-CN, zh-HK, tl).
        /// Both platforms must enable the same set of languages. When adding
        /// a code here, also update LanguageConfig.kt ENABLED_LANGUAGE_CODES.
        static let enabledLanguageCodes: Set<String> = [
            "en",
            "af", "am", "ar", "az",
            "bn", "bs", "bg",
            "ca", "cs",
            "da", "de",
            "el", "es",
            "fa", "fi", "fil", "fr",
            "he", "hi", "hr", "hu",
            "id", "it",
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
            "zh-Hans", "zh-Hant"
        ]

        /// Whether multiple languages are currently available to users
        static var hasMultipleLanguages: Bool {
            enabledLanguageCodes.count > 1
        }

        static func language(forCode code: String) -> LanguageInfo? {
            // Try exact match first
            if let exact = supportedLanguages.first(where: { $0.code == code }) {
                return exact
            }
            // Fall back to base language code (e.g. "pt-BR" -> "pt", "zh-Hant-HK" -> "zh-Hant")
            let components = code.split(separator: "-")
            if components.count > 1 {
                let baseCode = String(components[0])
                if let base = supportedLanguages.first(where: { $0.code == baseCode }) {
                    return base
                }
                // Try two-part prefix (e.g. "zh-Hant" from "zh-Hant-HK")
                if components.count > 2 {
                    let twoPartCode = components.prefix(2).joined(separator: "-")
                    if let twoPartMatch = supportedLanguages.first(where: { $0.code == twoPartCode }) {
                        return twoPartMatch
                    }
                }
            }
            return nil
        }
    }

    /// Get language info for current language
    var languageInfo: LanguageInfo? {
        return LanguageInfo.language(forCode: languageCode)
    }
}

// MARK: - LanguageManager Compatibility

extension LanguageSettings {
    /// Alias for languageCode for LanguageManager compatibility
    var selectedLanguage: String {
        return languageCode
    }

    /// Set language from a Language model
    mutating func setLanguage(_ language: Language) {
        languageCode = language.code
        nativeName = language.nativeName
        englishName = language.englishName
        isRTL = language.isRTL
    }

    /// Reset to system default language
    mutating func resetToSystemLanguage() {
        let systemCode = Locale.current.language.languageCode?.identifier ?? "en"
        if let langInfo = LanguageInfo.language(forCode: systemCode) {
            languageCode = langInfo.code
            nativeName = langInfo.nativeName
            englishName = langInfo.englishName
            isRTL = langInfo.isRTL
        } else {
            languageCode = "en"
            nativeName = "English"
            englishName = "English"
            isRTL = false
        }
    }
}
