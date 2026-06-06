// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI
import Combine

// Language selection and management for multi language support including RTL layouts.
// Backed by the unified SettingsRepository for centralised settings persistence.
// Supports 25 languages, handles layout direction switching, and posts notifications
// when the language changes so the UI can reload.

// MARK: - Language Model

struct Language: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let nativeName: String
    let englishName: String
    let isRTL: Bool

    static func == (lhs: Language, rhs: Language) -> Bool {
        return lhs.code == rhs.code
    }

    /// All supported languages in the app, derived from LanguageSettings.LanguageInfo
    /// as a single source of truth. Do not maintain a separate hardcoded list here.
    static let supportedLanguages: [Language] = LanguageSettings.LanguageInfo.supportedLanguages.map { info in
        Language(code: info.code, nativeName: info.nativeName, englishName: info.englishName, isRTL: info.isRTL)
    }
}

// MARK: - Language Manager

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: Language
    @Published var isRTL: Bool = false

    // Use centralised settings repository
    private let settingsRepository = SettingsRepository.shared
    private var settings: LanguageSettings

    // All supported languages - now referenced from LanguageSettings
    let supportedLanguages: [Language] = Language.supportedLanguages

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Load settings from repository
        self.settings = settingsRepository.load(LanguageSettings.self)

        // Initialize current language from settings
        let selectedLanguageCode = settings.selectedLanguage
        if let language = supportedLanguages.first(where: { $0.code == selectedLanguageCode }) {
            self.currentLanguage = language
            self.isRTL = language.isRTL
        } else {
            // Fallback to system language or English
            let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
            if let language = supportedLanguages.first(where: { $0.code == systemLanguageCode }) {
                self.currentLanguage = language
            } else {
                guard let englishLanguage = supportedLanguages.first(where: { $0.code == "en" }) ?? supportedLanguages.first else {
                    // Hardcoded fallback if language list is somehow empty
                    self.currentLanguage = Language(code: "en", nativeName: "English", englishName: "English", isRTL: false)
                    self.isRTL = false
                    return
                }
                self.currentLanguage = englishLanguage
            }
            self.isRTL = currentLanguage.isRTL

            // Save the initialised language
            settings.setLanguage(currentLanguage)
            settingsRepository.save(settings)
        }

        // Listen for settings changes from other sources
        setupSettingsObserver()
    }

    // MARK: - Settings Observer

    private func setupSettingsObserver() {
        settingsRepository.publisher(for: LanguageSettings.self)
            .sink { [weak self] newSettings in
                self?.handleSettingsChange(newSettings)
            }
            .store(in: &cancellables)
    }

    private func handleSettingsChange(_ newSettings: LanguageSettings) {
        // Skip if this change originated from changeLanguage() to avoid
        // redundantly re-applying the same language selection.
        guard !isSelfUpdate else { return }
        guard newSettings != settings else { return }

        settings = newSettings

        if let language = supportedLanguages.first(where: { $0.code == newSettings.selectedLanguage }) {
            currentLanguage = language
            isRTL = language.isRTL
        }
    }

    /// Suppresses the settings observer from re-applying a change that
    /// originated from this manager. Set to true before saving, cleared after.
    private var isSelfUpdate = false

    /// Change the app language
    /// - Parameter language: The language to switch to
    func changeLanguage(to language: Language) {
        currentLanguage = language
        isRTL = language.isRTL

        // Update settings and save to repository. Mark as self-update
        // to prevent the settings observer from re-applying the same change.
        settings.setLanguage(language)
        isSelfUpdate = true
        settingsRepository.save(settings)
        isSelfUpdate = false

        // Set system language override
        UserDefaults.standard.set([language.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // Update layout direction
        if language.isRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }

        // Notify the app that language changed. The root ZStack will be
        // rebuilt via .id(languageManager.currentLanguage.code), applying
        // the new locale immediately without process termination.
        NotificationCenter.default.post(name: .languageDidChange, object: language)
    }

    /// Get language by code. Delegates to LanguageSettings.LanguageInfo.language(forCode:)
    /// to avoid duplicating the regional variant fallback logic.
    func language(for code: String) -> Language? {
        guard let info = LanguageSettings.LanguageInfo.language(forCode: code) else {
            return nil
        }
        return supportedLanguages.first(where: { $0.code == info.code })
    }

    /// Check if a language is currently selected
    func isSelected(_ language: Language) -> Bool {
        return currentLanguage.code == language.code
    }

    /// Get localised language name in current language
    func localizedName(for language: Language) -> String {
        // For now return the native name
        // In a full implementation, this would be localised
        return language.nativeName
    }

    // MARK: - Settings Access

    /// Get the current language settings
    func getSettings() -> LanguageSettings {
        return settings
    }

    /// Whether the user has completed language selection during onboarding
    var hasSelectedLanguage: Bool {
        return settings.hasSelectedLanguage
    }

    /// Mark language selection as completed during onboarding
    func markLanguageSelected() {
        settings.hasSelectedLanguage = true
        settingsRepository.save(settings)
    }

    /// Reset language to system default
    func resetToSystemLanguage() {
        settings.resetToSystemLanguage()
        settingsRepository.save(settings)

        if let language = supportedLanguages.first(where: { $0.code == settings.selectedLanguage }) {
            currentLanguage = language
            isRTL = language.isRTL

            // Update layout direction
            if language.isRTL {
                UIView.appearance().semanticContentAttribute = .forceRightToLeft
            } else {
                UIView.appearance().semanticContentAttribute = .forceLeftToRight
            }

            // Notify the app that language changed
            NotificationCenter.default.post(name: .languageDidChange, object: language)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - View Environment

struct LanguageEnvironmentKey: EnvironmentKey {
    // Use a static fallback rather than accessing the @MainActor-isolated singleton.
    // The live value is injected by RTLAwareModifier via @StateObject observation.
    static let defaultValue: Language = Language(code: "en", nativeName: "English", englishName: "English", isRTL: false)
}

extension EnvironmentValues {
    var currentLanguage: Language {
        get { self[LanguageEnvironmentKey.self] }
        set { self[LanguageEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Modifier for RTL Support

struct RTLAwareModifier: ViewModifier {
    @StateObject private var languageManager = LanguageManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, languageManager.isRTL ? .rightToLeft : .leftToRight)
    }
}

extension View {
    func rtlAware() -> some View {
        modifier(RTLAwareModifier())
    }
}
