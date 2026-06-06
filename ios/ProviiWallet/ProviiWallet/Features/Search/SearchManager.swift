// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

// In-app search manager maintaining an index of searchable screens, settings, help
// topics, and features. Performs case-insensitive filtering across titles, keywords,
// and descriptions with debounced query updates to keep the UI responsive.

// MARK: - Searchable Item

enum SearchableItemType {
    case screen
    case setting
    case helpTopic
    case feature
}

struct SearchableItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let keywords: [String]
    let type: SearchableItemType
    let destination: SearchDestination
    let icon: String
    let iconColor: Color

    func matches(query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return title.lowercased().contains(lowercasedQuery) ||
               (subtitle?.lowercased().contains(lowercasedQuery) ?? false) ||
               keywords.contains { $0.lowercased().contains(lowercasedQuery) }
    }

    static func == (lhs: SearchableItem, rhs: SearchableItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SearchDestination {
    case accessibilitySettings
    case settings
    case credentials
    case help
    case whereToGet
    case languageSelection
    case specificHelpTopic(HelpTopic)
}

// MARK: - Search Manager

@MainActor
class SearchManager: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [SearchableItem] = []
    @Published var isSearching = false

    static let shared = SearchManager()

    private let allSearchableItems: [SearchableItem]

    private init() {
        // Initialize all searchable items
        self.allSearchableItems = SearchManager.createSearchableItems()
    }

    func search(query: String) {
        searchQuery = query

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Filter items that match the query
        let matches = allSearchableItems.filter { $0.matches(query: query) }

        // Sort by relevance (title matches first, then subtitle, then keywords)
        searchResults = matches.sorted { item1, item2 in
            let query = query.lowercased()

            // Exact matches first
            if item1.title.lowercased() == query && item2.title.lowercased() != query {
                return true
            }
            if item2.title.lowercased() == query && item1.title.lowercased() != query {
                return false
            }

            // Title starts with query
            if item1.title.lowercased().hasPrefix(query) && !item2.title.lowercased().hasPrefix(query) {
                return true
            }
            if item2.title.lowercased().hasPrefix(query) && !item1.title.lowercased().hasPrefix(query) {
                return false
            }

            // Title contains query
            if item1.title.lowercased().contains(query) && !item2.title.lowercased().contains(query) {
                return true
            }
            if item2.title.lowercased().contains(query) && !item1.title.lowercased().contains(query) {
                return false
            }

            // Alphabetical order
            return item1.title < item2.title
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    private static func createSearchableItems() -> [SearchableItem] {
        var items: [SearchableItem] = []

        // Accessibility Settings (HIGH PRIORITY)
        items.append(SearchableItem(
            title: LocalizedString.searchAccessibilitySettings.localized,
            subtitle: LocalizedString.searchCustomizeExperience.localized,
            keywords: ["accessibility", "a11y", "settings", "customize", "screen reader", "voiceover", "talkback", "large text", "high contrast", "voice", "speech", "disabilities", "wcag", "ada"],
            type: .screen,
            destination: .accessibilitySettings,
            icon: "accessibility",
            iconColor: .blue
        ))

        // Individual Accessibility Features
        items.append(SearchableItem(
            title: LocalizedString.searchLargeText.localized,
            subtitle: LocalizedString.searchIncreaseTextSize.localized,
            keywords: ["large", "text", "size", "font", "bigger", "accessibility", "vision", "sight"],
            type: .setting,
            destination: .accessibilitySettings,
            icon: "textformat.size",
            iconColor: .blue
        ))

        items.append(SearchableItem(
            title: LocalizedString.searchHighContrast.localized,
            subtitle: LocalizedString.searchEnhanceVisibility.localized,
            keywords: ["high", "contrast", "visibility", "vision", "accessibility", "colors", "see better"],
            type: .setting,
            destination: .accessibilitySettings,
            icon: "circle.lefthalf.filled",
            iconColor: .blue
        ))

        items.append(SearchableItem(
            title: LocalizedString.searchVoiceInput.localized,
            subtitle: LocalizedString.searchControlWithVoice.localized,
            keywords: ["voice", "speech", "input", "control", "speak", "talk", "accessibility", "hands-free"],
            type: .setting,
            destination: .accessibilitySettings,
            icon: "mic.fill",
            iconColor: .blue
        ))

        items.append(SearchableItem(
            title: LocalizedString.searchManualCodeEntry.localized,
            subtitle: LocalizedString.searchTypeCodesInsteadScanning.localized,
            keywords: ["manual", "code", "entry", "type", "keyboard", "accessibility", "qr", "scan"],
            type: .setting,
            destination: .accessibilitySettings,
            icon: "keyboard",
            iconColor: .blue
        ))

        items.append(SearchableItem(
            title: LocalizedString.searchSimplifiedUI.localized,
            subtitle: LocalizedString.searchReduceVisualComplexity.localized,
            keywords: ["simplified", "simple", "ui", "interface", "easy", "basic", "accessibility", "cognitive"],
            type: .setting,
            destination: .accessibilitySettings,
            icon: "square.grid.2x2",
            iconColor: .blue
        ))

        items.append(SearchableItem(
            title: LocalizedString.searchColorBlindnessSupport.localized,
            subtitle: LocalizedString.searchAdjustColorsVisibility.localized,
            keywords: ["color", "blind", "blindness", "vision", "accessibility", "deuteranopia", "protanopia", "tritanopia"],
            type: .setting,
            destination: .accessibilitySettings,
            icon: "eyedropper",
            iconColor: .blue
        ))

        // Settings
        items.append(SearchableItem(
            title: LocalizedString.searchSettings.localized,
            subtitle: LocalizedString.searchAppConfiguration.localized,
            keywords: ["settings", "config", "configuration", "preferences", "options"],
            type: .screen,
            destination: .settings,
            icon: "gearshape.fill",
            iconColor: AccessibleColors.secondaryText
        ))

        if LanguageSettings.LanguageInfo.hasMultipleLanguages {
            items.append(SearchableItem(
                title: LocalizedString.searchLanguage.localized,
                subtitle: LocalizedString.searchChangeAppLanguage.localized,
                keywords: ["language", "translate", "locale", "español", "français", "deutsch", "italiano", "português"],
                type: .screen,
                destination: .languageSelection,
                icon: "globe",
                iconColor: .green
            ))
        }

        // Credentials
        items.append(SearchableItem(
            title: LocalizedString.searchMyCredentials.localized,
            subtitle: LocalizedString.searchViewCredentials.localized,
            keywords: ["credentials", "wallet", "id", "verification", "identity"],
            type: .screen,
            destination: .credentials,
            icon: "wallet.pass.fill",
            iconColor: .purple
        ))

        items.append(SearchableItem(
            title: LocalizedString.searchGetCredential.localized,
            subtitle: LocalizedString.searchFindIssuers.localized,
            keywords: ["get", "obtain", "acquire", "credential", "issuer", "location", "where"],
            type: .screen,
            destination: .whereToGet,
            icon: "plus.circle.fill",
            iconColor: .blue
        ))

        // Help Topics
        items.append(SearchableItem(
            title: LocalizedString.searchHelp.localized,
            subtitle: LocalizedString.searchGetAssistance.localized,
            keywords: ["help", "support", "assistance", "guide", "tutorial", "how to"],
            type: .screen,
            destination: .help,
            icon: "questionmark.circle.fill",
            iconColor: .orange
        ))

        for topic in HelpTopic.allCases {
            items.append(SearchableItem(
                title: topic.title,
                subtitle: String(topic.helpText().prefix(100)),
                keywords: [topic.title.lowercased(), "help", "guide", "tutorial"],
                type: .helpTopic,
                destination: .specificHelpTopic(topic),
                icon: topic.icon,
                iconColor: .orange
            ))
        }

        // Privacy & Security
        items.append(SearchableItem(
            title: LocalizedString.searchPrivacyProtection.localized,
            subtitle: LocalizedString.searchDataProtected.localized,
            keywords: ["privacy", "security", "protection", "safe", "secure", "data", "zero knowledge", "zkp"],
            type: .helpTopic,
            destination: .specificHelpTopic(.zeroKnowledge),
            icon: "lock.shield",
            iconColor: .green
        ))

        // Verification
        items.append(SearchableItem(
            title: LocalizedString.searchAgeVerification.localized,
            subtitle: LocalizedString.searchProveAge.localized,
            keywords: ["verify", "verification", "age", "proof", "prove", "check"],
            type: .helpTopic,
            destination: .specificHelpTopic(.ageVerification),
            icon: "checkmark.shield",
            iconColor: .blue
        ))

        return items
    }
}
