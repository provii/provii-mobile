// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

/// Language selection screen supporting over 50 languages with search, section indexing,
/// and right-to-left layout detection. Each language row displays the native script name
/// alongside the English label. Conforms to WCAG 2.2 AA with minimum touch targets,
/// Dynamic Type support, and VoiceOver announcements on selection changes.
struct LanguageSelectionView: View {
    @StateObject private var viewModel = LanguageSelectionViewModel()
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @State private var showingConfirmation = false
    @State private var showingSkipWarning = false
    @State private var searchText = ""
    @State private var scrollTarget: String?
    @FocusState private var searchFieldFocused: Bool

    let onLanguageSelected: () -> Void
    let showBreadcrumbs: Bool
    let isOnboarding: Bool
    let onBack: (() -> Void)?

    init(
        onLanguageSelected: @escaping () -> Void,
        showBreadcrumbs: Bool = false,
        isOnboarding: Bool = false,
        onBack: (() -> Void)? = nil
    ) {
        self.onLanguageSelected = onLanguageSelected
        self.showBreadcrumbs = showBreadcrumbs
        self.isOnboarding = isOnboarding
        self.onBack = onBack
    }

    var body: some View {
        NavigationView {
            ZStack {
                AccessibleColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Back button for onboarding mode
                    if isOnboarding, let onBack = onBack {
                        HStack {
                            Button(action: onBack) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(NSLocalizedString("onboarding_back_button", comment: "Back"))
                                }
                                .font(AccessibleTypography.body)
                                .foregroundColor(AccessibleColors.primary)
                            }
                            .accessibilityLabel(AccessibilityLabels.back)
                            .frame(minWidth: 60, minHeight: 44) // WCAG touch target
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }

                    // Breadcrumb navigation (when shown from Settings)
                    if showBreadcrumbs {
                        BreadcrumbView(path: [
                            NSLocalizedString("breadcrumb.home", comment: "Home"),
                            NSLocalizedString("breadcrumb.settings", comment: "Settings"),
                            NSLocalizedString("breadcrumb.language", comment: "Language")
                        ])
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }

                    // Header
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.top, (showBreadcrumbs || isOnboarding) ? 12 : 20)

                    // Search bar
                    searchSection
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Language list
                    languageListSection
                        .padding(.top, 16)

                    // Bottom actions
                    bottomActionsSection
                        .padding(24)
                }
            }
            .navigationTitle(String(localized: "Language Selection"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .alert(NSLocalizedString("alert.language.confirm_title", comment: "Confirm language selection alert title"), isPresented: $showingConfirmation) {
            Button(NSLocalizedString("alert.common.cancel", comment: "Cancel button"), role: .cancel) { }
            Button(NSLocalizedString("alert.language.confirm_button", comment: "Confirm button")) {
                confirmLanguageSelection()
            }
        } message: {
            if let language = viewModel.selectedLanguage {
                Text(String(format: NSLocalizedString("alert.language.confirm_message", comment: "Set language confirmation message"), language.nativeName))
            }
        }
        .alert(NSLocalizedString("alert.language.skip_title", comment: "Skip language selection alert title"), isPresented: $showingSkipWarning) {
            Button(NSLocalizedString("alert.common.cancel", comment: "Cancel button"), role: .cancel) { }
            Button(NSLocalizedString("alert.language.skip_button", comment: "Skip use English button"), role: .destructive) {
                skipLanguageSelection()
            }
        } message: {
            Text(NSLocalizedString("alert.language.skip_message", comment: "English will be used by default message"))
        }
        .onChange(of: viewModel.selectedLanguage) { newLanguage in
            // WCAG 2.2 AA: Live region announcement for selection changes
            if let language = newLanguage {
                announceSelection(language)
            }
        }
        .onAppear {
            // WCAG 2.2 AA: 3.3.7 Redundant Entry - check if language was previously selected
            viewModel.loadSavedLanguage()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(.largeTitle, design: .default))
                .imageScale(.large)
                .foregroundColor(AccessibleColors.primary)
                .accessibilityHidden(true)

            Text(NSLocalizedString("language_selection.title", comment: "Choose your language title"))
                .font(AccessibleTypography.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(NSLocalizedString("accessibility.language_selection.choose_language", comment: "Choose Your Language"))

            Text(NSLocalizedString("language_selection.subtitle", comment: "Select your preferred language subtitle"))
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibleText()
        }
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            TextField(NSLocalizedString("language_selection.search_placeholder", comment: "Search languages placeholder"), text: $searchText)
                .font(AccessibleTypography.body)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($searchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    // Dismiss keyboard after search
                    searchFieldFocused = false
                }
                .accessibilityLabel(NSLocalizedString("accessibility.language_selection.search_languages", comment: "Search languages"))
                .accessibilityHint(NSLocalizedString("accessibility.language_selection.type_to_filter", comment: "Type to filter the language list"))
                .onChange(of: searchText) { _ in
                    viewModel.filterLanguages(searchText)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.filterLanguages("")
                    provideHapticFeedback()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(NSLocalizedString("accessibility.language_selection.clear_search", comment: "Clear search"))
                .frame(minWidth: 60, minHeight: 60) // WCAG 2.2 AA: 2.5.8 Target Size
            }
        }
        .padding(16)
        .background(AccessibleColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    searchFieldFocused ? AccessibleColors.primary : Color.clear,
                    lineWidth: accessibilityManager.settings.useHighContrast ? 3 : 2
                )
        )
        .frame(minHeight: 60) // WCAG 2.2 AA: 2.5.8 Target Size
    }

    // MARK: - Language List Section

    private var languageListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // System language (if supported)
                    if let systemLanguage = viewModel.systemLanguage {
                        systemLanguageRow(systemLanguage)
                            .id("system")

                        Divider()
                            .padding(.leading, 24)
                    }

                    // All languages
                    ForEach(viewModel.filteredLanguages) { language in
                        languageRow(language)
                            .id(language.code)

                        if language.code != viewModel.filteredLanguages.last?.code {
                            Divider()
                                .padding(.leading, 24)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: scrollTarget) { target in
                if let target = target {
                    // WCAG 2.2 AA: 2.4.11 Focus Not Obscured
                    withAnimation {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("accessibility.language_selection.language_list", comment: "Language list"))
        .accessibilityHint(NSLocalizedString("accessibility.language_selection.swipe_to_browse", comment: "Swipe up or down to browse languages"))
    }

    // MARK: - System Language Row

    private func systemLanguageRow(_ language: SupportedLanguage) -> some View {
        Button {
            selectLanguage(language)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(language.nativeName)
                            .font(AccessibleTypography.headline)
                            .foregroundColor(.primary)
                            .accessibilityLanguage(language.code)

                        Text(NSLocalizedString("language_selection.system_badge", comment: "System language badge"))
                            .font(AccessibleTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AccessibleColors.primary)
                            .cornerRadius(4)
                    }

                    Text(language.englishName)
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.selectedLanguage?.code == language.code {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AccessibleColors.primary)
                        .accessibilityLabel(NSLocalizedString("accessibility.language_selection.selected", comment: "Selected"))
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize()) // WCAG 2.2 AA: 2.5.8 Target Size
            .background(
                viewModel.selectedLanguage?.code == language.code ?
                    AccessibleColors.primary.opacity(0.1) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.language_selection.system_language_item", comment: "%@, %@, System language"), language.nativeName, language.englishName))
        .accessibilityHint(viewModel.selectedLanguage?.code == language.code ? NSLocalizedString("accessibility.language_selection.currently_selected", comment: "Currently selected") : NSLocalizedString("accessibility.language_selection.tap_to_select", comment: "Tap to select"))
        .accessibilityAddTraits(viewModel.selectedLanguage?.code == language.code ? [.isSelected] : [])
    }

    // MARK: - Language Row

    private func languageRow(_ language: SupportedLanguage) -> some View {
        Button {
            selectLanguage(language)
        } label: {
            HStack(spacing: 16) {
                // Flag or language indicator
                Text(language.flag)
                    .font(.title)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(language.nativeName)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)
                        .accessibilityLanguage(language.code)

                    Text(language.englishName)
                        .font(AccessibleTypography.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.selectedLanguage?.code == language.code {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AccessibleColors.primary)
                        .accessibilityLabel(NSLocalizedString("accessibility.language_selection.selected", comment: "Selected"))
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize()) // WCAG 2.2 AA: 2.5.8 Target Size
            .background(
                viewModel.selectedLanguage?.code == language.code ?
                    AccessibleColors.primary.opacity(0.1) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.language_selection.language_item", comment: "%@, %@"), language.nativeName, language.englishName))
        .accessibilityHint(viewModel.selectedLanguage?.code == language.code ? NSLocalizedString("accessibility.language_selection.currently_selected", comment: "Currently selected") : NSLocalizedString("accessibility.language_selection.tap_to_select", comment: "Tap to select"))
        .accessibilityAddTraits(viewModel.selectedLanguage?.code == language.code ? [.isSelected] : [])
        .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight) // RTL support
    }

    // MARK: - Bottom Actions Section

    private var bottomActionsSection: some View {
        VStack(spacing: 12) {
            // Preview text in selected language
            if let selectedLanguage = viewModel.selectedLanguage {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("language_selection.preview_label", comment: "Preview label"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)

                    Text(selectedLanguage.previewText)
                        .font(AccessibleTypography.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AccessibleColors.cardBackground)
                        .cornerRadius(8)
                        .environment(\.layoutDirection, selectedLanguage.isRTL ? .rightToLeft : .leftToRight)
                        .accessibilityLanguage(selectedLanguage.code)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("accessibility.language_selection.preview_in_language", comment: "Preview in %@: %@"), selectedLanguage.nativeName, selectedLanguage.previewText))
            }

            // Confirm button
            Button {
                if viewModel.selectedLanguage != nil {
                    showingConfirmation = true
                    provideHapticFeedback()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text(NSLocalizedString("language_selection.continue_button", comment: "Continue button"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessiblePrimaryButtonStyle())
            .disabled(viewModel.selectedLanguage == nil)
            .accessibilityLabel(NSLocalizedString("accessibility.language_selection.continue_with_selected", comment: "Continue with selected language"))
            .accessibilityHint(viewModel.selectedLanguage == nil ? NSLocalizedString("accessibility.language_selection.select_first", comment: "Select a language first") : NSLocalizedString("accessibility.language_selection.confirm_choice", comment: "Tap to confirm your language choice"))

            // Skip button
            Button {
                showingSkipWarning = true
                provideHapticFeedback()
            } label: {
                HStack {
                    Image(systemName: "arrow.forward")
                    Text(NSLocalizedString("language_selection.skip_button", comment: "Skip use English button"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())
            .accessibilityLabel(NSLocalizedString("accessibility.language_selection.skip_use_english", comment: "Skip language selection and use English"))
            .accessibilityHint(NSLocalizedString("accessibility.language_selection.continue_with_english", comment: "Tap to continue with English as default language"))

            // Help button - WCAG 2.2 AA: 3.2.6 Consistent Help
            Button {
                // Show help
                announceHelp()
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text(NSLocalizedString("language_selection.help_button", comment: "Help button"))
                }
            }
            .font(AccessibleTypography.subheadline)
            .foregroundColor(AccessibleColors.primary)
            .frame(minHeight: 60) // WCAG 2.2 AA: 2.5.8 Target Size
            .accessibilityLabel(NSLocalizedString("accessibility.language_selection.help", comment: "Help"))
            .accessibilityHint(NSLocalizedString("accessibility.language_selection.get_help", comment: "Get help with language selection"))
        }
    }

    // MARK: - Actions

    private func selectLanguage(_ language: SupportedLanguage) {
        viewModel.selectLanguage(language)
        scrollTarget = language.code
        provideHapticFeedback()
    }

    private func confirmLanguageSelection() {
        guard let language = viewModel.selectedLanguage else { return }

        // Mark language as selected via LanguageManager (persists to settings)
        languageManager.markLanguageSelected()

        // Always route through LanguageManager to update published properties,
        // persist settings, set layout direction, and post notifications.
        let lang = languageManager.language(for: language.code)
            ?? Language(code: language.code, nativeName: language.nativeName, englishName: language.englishName, isRTL: language.isRTL)
        languageManager.changeLanguage(to: lang)

        // Announce completion
        announceCompletion(language)

        provideHapticFeedback(style: .success)

        // Continue to next screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onLanguageSelected()
        }
    }

    private func skipLanguageSelection() {
        // Mark language as selected (user chose to skip = use English)
        languageManager.markLanguageSelected()

        // Apply English via LanguageManager
        if let english = languageManager.language(for: "en") {
            languageManager.changeLanguage(to: english)
        }

        provideHapticFeedback()
        onLanguageSelected()
    }

    // MARK: - Accessibility Announcements

    private func announceSelection(_ language: SupportedLanguage) {
        let announcement = String(format: NSLocalizedString("language_selection.announcement.selected", comment: "Selected language announcement"), language.nativeName)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private func announceCompletion(_ language: SupportedLanguage) {
        let announcement = String(format: NSLocalizedString("language_selection.announcement.completed", comment: "Language set announcement"), language.nativeName)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private func announceHelp() {
        let helpText = NSLocalizedString("language_selection.help_text", comment: "Help text for language selection")
        UIAccessibility.post(notification: .announcement, argument: helpText)
    }

    // MARK: - Haptic Feedback

    private func provideHapticFeedback(style: UINotificationFeedbackGenerator.FeedbackType = .success) {
        if accessibilityManager.settings.hapticFeedback {
            if style == .success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }
}

// MARK: - View Model

@MainActor
class LanguageSelectionViewModel: ObservableObject {
    @Published var selectedLanguage: SupportedLanguage?
    @Published var filteredLanguages: [SupportedLanguage]
    @Published var systemLanguage: SupportedLanguage?

    private let allLanguages: [SupportedLanguage]

    init() {
        let enabled = SupportedLanguages.enabled
        self.allLanguages = enabled
        self.filteredLanguages = enabled

        // Detect system language
        if let systemCode = Locale.preferredLanguages.first?.components(separatedBy: "-").first {
            self.systemLanguage = allLanguages.first { $0.code.starts(with: systemCode) }
        }
    }

    func selectLanguage(_ language: SupportedLanguage) {
        selectedLanguage = language
    }

    func filterLanguages(_ searchText: String) {
        if searchText.isEmpty {
            filteredLanguages = allLanguages
        } else {
            let lowercasedSearch = searchText.lowercased()
            filteredLanguages = allLanguages.filter { language in
                language.nativeName.lowercased().contains(lowercasedSearch) ||
                language.englishName.lowercased().contains(lowercasedSearch) ||
                language.code.lowercased().contains(lowercasedSearch)
            }
        }
    }

    func loadSavedLanguage() {
        // WCAG 2.2 AA: 3.3.7 Redundant Entry
        if let savedCode = UserDefaults.standard.string(forKey: "selectedLanguageCode"),
           let language = allLanguages.first(where: { $0.code == savedCode }) {
            selectedLanguage = language
        }
    }
}

// MARK: - Supporting Types

struct SupportedLanguage: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let englishName: String
    let nativeName: String
    let flag: String
    let isRTL: Bool
    let previewText: String

    static func == (lhs: SupportedLanguage, rhs: SupportedLanguage) -> Bool {
        lhs.code == rhs.code
    }
}

struct SupportedLanguages {
    /// Languages currently enabled, filtered by LanguageSettings.LanguageInfo.enabledLanguageCodes
    static var enabled: [SupportedLanguage] {
        all.filter { LanguageSettings.LanguageInfo.enabledLanguageCodes.contains($0.code) }
    }

    static let all: [SupportedLanguage] = [
        // RTL Languages marked with isRTL: true
        SupportedLanguage(code: "ar", englishName: "Arabic", nativeName: "العربية", flag: "🇸🇦", isRTL: true, previewText: "مرحبا بك"),
        SupportedLanguage(code: "fa", englishName: "Persian/Farsi", nativeName: "فارسی", flag: "🇮🇷", isRTL: true, previewText: "خوش آمدید"),
        SupportedLanguage(code: "fa-AF", englishName: "Dari (Afghan Persian)", nativeName: "دری", flag: "🇦🇫", isRTL: true, previewText: "خوش آمدید"),
        SupportedLanguage(code: "haz", englishName: "Hazaragi", nativeName: "هزارگی", flag: "🇦🇫", isRTL: true, previewText: "خوش آمدید"),
        SupportedLanguage(code: "he", englishName: "Hebrew", nativeName: "עברית", flag: "🇮🇱", isRTL: true, previewText: "ברוך הבא"),
        SupportedLanguage(code: "ps", englishName: "Pashto", nativeName: "پښتو", flag: "🇦🇫", isRTL: true, previewText: "ښه راغلاست"),
        SupportedLanguage(code: "ur", englishName: "Urdu", nativeName: "اردو", flag: "🇵🇰", isRTL: true, previewText: "خوش آمدید"),

        // LTR Languages
        SupportedLanguage(code: "am", englishName: "Amharic", nativeName: "አማርኛ", flag: "🇪🇹", isRTL: false, previewText: "እንኳን ደህና መጡ"),
        SupportedLanguage(code: "bg", englishName: "Bulgarian", nativeName: "Български", flag: "🇧🇬", isRTL: false, previewText: "Добре дошли"),
        SupportedLanguage(code: "bn", englishName: "Bengali", nativeName: "বাংলা", flag: "🇧🇩", isRTL: false, previewText: "স্বাগতম"),
        SupportedLanguage(code: "bo", englishName: "Tibetan", nativeName: "བོད་སྐད", flag: "🇨🇳", isRTL: false, previewText: "དགའ་བསུ་ཞུ"),
        SupportedLanguage(code: "bs", englishName: "Bosnian", nativeName: "Bosanski", flag: "🇧🇦", isRTL: false, previewText: "Dobrodošli"),
        SupportedLanguage(code: "cnh", englishName: "Hakha Chin", nativeName: "Laiholh", flag: "🇲🇲", isRTL: false, previewText: "Lawm ṭha seh"),
        SupportedLanguage(code: "de", englishName: "German", nativeName: "Deutsch", flag: "🇩🇪", isRTL: false, previewText: "Willkommen"),
        SupportedLanguage(code: "din", englishName: "Dinka", nativeName: "Thuɔŋjäŋ", flag: "🇸🇸", isRTL: false, previewText: "Kudual"),
        SupportedLanguage(code: "el", englishName: "Greek", nativeName: "Ελληνικά", flag: "🇬🇷", isRTL: false, previewText: "Καλώς ήρθατε"),
        SupportedLanguage(code: "en", englishName: "English", nativeName: "English", flag: "🇬🇧", isRTL: false, previewText: "Welcome"),
        SupportedLanguage(code: "es", englishName: "Spanish", nativeName: "Español", flag: "🇪🇸", isRTL: false, previewText: "Bienvenido"),
        SupportedLanguage(code: "fi", englishName: "Finnish", nativeName: "Suomi", flag: "🇫🇮", isRTL: false, previewText: "Tervetuloa"),
        SupportedLanguage(code: "fr", englishName: "French", nativeName: "Français", flag: "🇫🇷", isRTL: false, previewText: "Bienvenue"),
        SupportedLanguage(code: "gu", englishName: "Gujarati", nativeName: "ગુજરાતી", flag: "🇮🇳", isRTL: false, previewText: "સ્વાગત છે"),
        SupportedLanguage(code: "hi", englishName: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳", isRTL: false, previewText: "स्वागत है"),
        SupportedLanguage(code: "hmn", englishName: "Hmong", nativeName: "Hmoob", flag: "🇱🇦", isRTL: false, previewText: "Txais tos"),
        SupportedLanguage(code: "hr", englishName: "Croatian", nativeName: "Hrvatski", flag: "🇭🇷", isRTL: false, previewText: "Dobrodošli"),
        SupportedLanguage(code: "hy", englishName: "Armenian", nativeName: "Հայերեն", flag: "🇦🇲", isRTL: false, previewText: "Բարի գալուստ"),
        SupportedLanguage(code: "id", englishName: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩", isRTL: false, previewText: "Selamat datang"),
        SupportedLanguage(code: "it", englishName: "Italian", nativeName: "Italiano", flag: "🇮🇹", isRTL: false, previewText: "Benvenuto"),
        SupportedLanguage(code: "ja", englishName: "Japanese", nativeName: "日本語", flag: "🇯🇵", isRTL: false, previewText: "ようこそ"),
        SupportedLanguage(code: "kar", englishName: "Karen", nativeName: "ကညီကျိ", flag: "🇲🇲", isRTL: false, previewText: "တၢ်ညီလၢတဖၣ်"),
        SupportedLanguage(code: "km", englishName: "Khmer", nativeName: "ភាសាខ្មែរ", flag: "🇰🇭", isRTL: false, previewText: "សូមស្វាគមន៍"),
        SupportedLanguage(code: "ko", englishName: "Korean", nativeName: "한국어", flag: "🇰🇷", isRTL: false, previewText: "환영합니다"),
        SupportedLanguage(code: "ku", englishName: "Kurdish", nativeName: "Kurdî", flag: "🇮🇶", isRTL: false, previewText: "Bi xêr hatî"),
        SupportedLanguage(code: "lo", englishName: "Lao", nativeName: "ລາວ", flag: "🇱🇦", isRTL: false, previewText: "ຍິນດີຕ້ອນຮັບ"),
        SupportedLanguage(code: "mk", englishName: "Macedonian", nativeName: "Македонски", flag: "🇲🇰", isRTL: false, previewText: "Добредојдовте"),
        SupportedLanguage(code: "ml", englishName: "Malayalam", nativeName: "മലയാളം", flag: "🇮🇳", isRTL: false, previewText: "സ്വാഗതം"),
        SupportedLanguage(code: "mt", englishName: "Maltese", nativeName: "Malti", flag: "🇲🇹", isRTL: false, previewText: "Merħba"),
        SupportedLanguage(code: "ne", englishName: "Nepali", nativeName: "नेपाली", flag: "🇳🇵", isRTL: false, previewText: "स्वागत छ"),
        SupportedLanguage(code: "nl", englishName: "Dutch", nativeName: "Nederlands", flag: "🇳🇱", isRTL: false, previewText: "Welkom"),
        SupportedLanguage(code: "pa", englishName: "Punjabi", nativeName: "ਪੰਜਾਬੀ", flag: "🇮🇳", isRTL: false, previewText: "ਜੀ ਆਇਆਂ ਨੂੰ"),
        SupportedLanguage(code: "pl", englishName: "Polish", nativeName: "Polski", flag: "🇵🇱", isRTL: false, previewText: "Witamy"),
        SupportedLanguage(code: "pt", englishName: "Portuguese", nativeName: "Português", flag: "🇵🇹", isRTL: false, previewText: "Bem-vindo"),
        SupportedLanguage(code: "rhg", englishName: "Rohingya", nativeName: "Ruáingga", flag: "🇲🇲", isRTL: false, previewText: "Xúc aiyí"),
        SupportedLanguage(code: "rn", englishName: "Kirundi", nativeName: "Ikirundi", flag: "🇧🇮", isRTL: false, previewText: "Murakaza neza"),
        SupportedLanguage(code: "ro", englishName: "Romanian", nativeName: "Română", flag: "🇷🇴", isRTL: false, previewText: "Bun venit"),
        SupportedLanguage(code: "ru", englishName: "Russian", nativeName: "Русский", flag: "🇷🇺", isRTL: false, previewText: "Добро пожаловать"),
        SupportedLanguage(code: "si", englishName: "Sinhala", nativeName: "සිංහල", flag: "🇱🇰", isRTL: false, previewText: "සාදරයෙන් පිළිගනිමු"),
        SupportedLanguage(code: "sk", englishName: "Slovak", nativeName: "Slovenčina", flag: "🇸🇰", isRTL: false, previewText: "Vitajte"),
        SupportedLanguage(code: "sl", englishName: "Slovenian", nativeName: "Slovenščina", flag: "🇸🇮", isRTL: false, previewText: "Dobrodošli"),
        SupportedLanguage(code: "sm", englishName: "Samoan", nativeName: "Gagana Samoa", flag: "🇼🇸", isRTL: false, previewText: "Talofa"),
        SupportedLanguage(code: "so", englishName: "Somali", nativeName: "Soomaali", flag: "🇸🇴", isRTL: false, previewText: "Soo dhawoow"),
        SupportedLanguage(code: "sq", englishName: "Albanian", nativeName: "Shqip", flag: "🇦🇱", isRTL: false, previewText: "Mirë se vini"),
        SupportedLanguage(code: "sr", englishName: "Serbian", nativeName: "Српски", flag: "🇷🇸", isRTL: false, previewText: "Добродошли"),
        SupportedLanguage(code: "sw", englishName: "Swahili", nativeName: "Kiswahili", flag: "🇰🇪", isRTL: false, previewText: "Karibu"),
        SupportedLanguage(code: "ta", englishName: "Tamil", nativeName: "தமிழ்", flag: "🇮🇳", isRTL: false, previewText: "வரவேற்கிறோம்"),
        SupportedLanguage(code: "th", englishName: "Thai", nativeName: "ไทย", flag: "🇹🇭", isRTL: false, previewText: "ยินดีต้อนรับ"),
        SupportedLanguage(code: "ti", englishName: "Tigrinya", nativeName: "ትግርኛ", flag: "🇪🇷", isRTL: false, previewText: "እንቋዕ ብደሓን መጻእኩም"),
        SupportedLanguage(code: "tl", englishName: "Tagalog/Filipino", nativeName: "Tagalog", flag: "🇵🇭", isRTL: false, previewText: "Maligayang pagdating"),
        SupportedLanguage(code: "tr", englishName: "Turkish", nativeName: "Türkçe", flag: "🇹🇷", isRTL: false, previewText: "Hoş geldiniz"),
        SupportedLanguage(code: "vi", englishName: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳", isRTL: false, previewText: "Chào mừng"),
        SupportedLanguage(code: "zh-Hans", englishName: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳", isRTL: false, previewText: "欢迎"),
        SupportedLanguage(code: "zh-Hant", englishName: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇹🇼", isRTL: false, previewText: "歡迎")
    ]
}

// MARK: - Preview

struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LanguageSelectionView(
                onLanguageSelected: { print("Language selected") },
                showBreadcrumbs: false,
                isOnboarding: true,
                onBack: nil
            )
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Onboarding")

            LanguageSelectionView(
                onLanguageSelected: { print("Language selected") },
                showBreadcrumbs: true,
                isOnboarding: false,
                onBack: nil
            )
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("From Settings")
        }
    }
}
