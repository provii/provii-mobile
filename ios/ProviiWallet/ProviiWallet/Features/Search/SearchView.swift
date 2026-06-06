// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Search results screen displaying filtered items from the SearchManager index.
/// Includes a popular searches section, quick-access cards for frequently visited
/// screens, and focus management conforming to WCAG 2.4.3 focus order requirements.
struct SearchView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var searchManager = SearchManager.shared
    @State private var showAccessibilitySettings = false
    @State private var showLanguageSelection = false
    @State private var selectedHelpTopic: HelpTopic?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case searchField
        case clearButton
        case doneButton
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)

                    TextField(LocalizedString.searchPlaceholder.localized, text: $searchManager.searchQuery)
                        .focused($isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .font(AccessibleTypography.body)
                        .submitLabel(.search)
                        .onSubmit {
                            // Dismiss keyboard after search
                            isSearchFieldFocused = false
                        }
                        .accessibilityLabel(NSLocalizedString("accessibility.search.search_field.label", comment: "Search field"))
                        .accessibilityHint(NSLocalizedString("accessibility.search.type_to_search.hint", comment: "Type to search for settings, help topics, and features"))
                        .accessibilityAddTraits(.isSearchField)
                        .onChange(of: searchManager.searchQuery) { newValue in
                            // MASVS CODE-4: Input validation - limit search query length
                            if newValue.count > 200 {
                                searchManager.searchQuery = String(newValue.prefix(200))
                            }
                            searchManager.search(query: searchManager.searchQuery)
                        }
                        .onChange(of: searchManager.searchResults.count) { _, newCount in
                            // WCAG 4.1.2: Announce search results count to assistive technologies
                            guard !searchManager.searchQuery.isEmpty else { return }
                            let announcement: String
                            if newCount == 0 {
                                announcement = NSLocalizedString("accessibility.search.no_results", comment: "No results found")
                            } else if newCount == 1 {
                                announcement = NSLocalizedString("accessibility.search.one_result", comment: "1 result found")
                            } else {
                                announcement = String(format: NSLocalizedString("accessibility.search.results_count", comment: "%d results found"), newCount)
                            }
                            UIAccessibility.post(notification: .announcement, argument: announcement)
                        }

                    if !searchManager.searchQuery.isEmpty {
                        Button {
                            searchManager.clearSearch()
                            isSearchFieldFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AccessibleColors.secondaryText)
                        }
                        .accessibilityLabel(NSLocalizedString("accessibility.search.clear_search.label", comment: "Clear search"))
                        .accessibilityInputLabels(["clear", "delete", "remove", "x"])
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .secondarySystemFill))
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                VStack(spacing: 0) {
                    if searchManager.searchQuery.isEmpty {
                        // Show popular searches/quick access when empty
                        popularSearchesView
                    } else if searchManager.searchResults.isEmpty {
                        // No results
                        noResultsView
                    } else {
                        // Search results
                        searchResultsView
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Main Content")
            }
            .background(AccessibleColors.background)
            .navigationTitle(LocalizedString.search.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedString.done.localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAccessibilitySettings) {
                AccessibilitySettingsView()
                    .sheetKeyboardNavigation(isPresented: $showAccessibilitySettings)
            }
            .onChange(of: showAccessibilitySettings) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .sheet(isPresented: $showLanguageSelection) {
                NavigationStack {
                    LanguageSelectionView {
                        showLanguageSelection = false
                    }
                }
                .sheetKeyboardNavigation(isPresented: $showLanguageSelection)
            }
            .onChange(of: showLanguageSelection) { _, isShowing in
                if isShowing {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .sheet(item: $selectedHelpTopic) { topic in
                NavigationStack {
                    HelpTopicDetailView(topic: topic)
                }
            }
            .onChange(of: selectedHelpTopic) { _, newValue in
                if newValue != nil {
                    savedFocus = focusedElement
                } else if let saved = savedFocus {
                    focusedElement = saved
                    savedFocus = nil
                }
            }
            .onAppear {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Popular Searches

    private var popularSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedString.popularSearches.localized)
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 12) {
                    quickAccessButton(
                        title: LocalizedString.accessibilitySettings.localized,
                        icon: "accessibility",
                        color: .blue
                    ) {
                        showAccessibilitySettings = true
                    }

                    quickAccessButton(
                        title: LocalizedString.language.localized,
                        icon: "globe",
                        color: .green
                    ) {
                        showLanguageSelection = true
                    }

                    quickAccessButton(
                        title: LocalizedString.getCredential.localized,
                        icon: "plus.circle.fill",
                        color: .blue
                    ) {
                        dismiss()
                        navigationCoordinator.navigateToWhereToGet()
                    }

                    quickAccessButton(
                        title: LocalizedString.help.localized,
                        icon: "questionmark.circle.fill",
                        color: .orange
                    ) {
                        // Navigate to help tab
                        dismiss()
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchManager.searchResults) { item in
                    searchResultRow(item: item)
                }
            }
            .padding()
        }
    }

    private func searchResultRow(item: SearchableItem) -> some View {
        Button {
            handleItemSelection(item)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(item.iconColor)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(AccessibleTypography.caption)
                            .foregroundColor(AccessibleColors.secondaryText)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AccessibleColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                accessibilityManager.settings.useHighContrast ? Color.black : Color(uiColor: .separator),
                                lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            handleItemSelection(item)
            return .handled
        }
        .onKeyPress(.space) {
            handleItemSelection(item)
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if let subtitle = item.subtitle {
                return String(format: NSLocalizedString("accessibility.search.item_title_subtitle.label", comment: "%@. %@"), item.title, subtitle)
            }
            return item.title
        }())
        .accessibilityHint(NSLocalizedString("accessibility.search.double_tap_to_open.hint", comment: "Double tap to open"))
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(AccessibleTypography.title2)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(LocalizedString.noResultsFound.localized)
                .font(AccessibleTypography.title2)
                .fontWeight(.bold)

            Text(LocalizedString.searchSuggestions.localized)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helper Views

    private func quickAccessButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color)
                    )
                    .accessibilityHidden(true)

                Text(title)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AccessibleColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                accessibilityManager.settings.useHighContrast ? Color.black : Color(uiColor: .separator),
                                lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .onKeyPress(.return) {
            action()
            return .handled
        }
        .onKeyPress(.space) {
            action()
            return .handled
        }
        .accessibilityLabel(title)
        .accessibilityHint(NSLocalizedString("accessibility.search.double_tap_to_open.hint", comment: "Double tap to open"))
    }

    // MARK: - Navigation Handling

    private func handleItemSelection(_ item: SearchableItem) {
        HapticFeedback.selection()

        switch item.destination {
        case .accessibilitySettings:
            showAccessibilitySettings = true

        case .settings:
            dismiss()
            navigationCoordinator.navigateToSettings()

        case .credentials:
            dismiss()
            navigationCoordinator.navigateToCredentials()

        case .help:
            dismiss()
            // Navigate to help tab

        case .whereToGet:
            dismiss()
            navigationCoordinator.navigateToWhereToGet()

        case .languageSelection:
            showLanguageSelection = true

        case .specificHelpTopic(let topic):
            selectedHelpTopic = topic
        }
    }
}
