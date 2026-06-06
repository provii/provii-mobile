// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Defines the tab bar structure and help content for the wallet app.
/// The Tab enum maps each tab to its icon, localised title, and accessibility label.
/// TabBarView renders the tab container with credentials, settings, and help tabs,
/// and configures appearance for high contrast and Dynamic Type modes.

enum Tab: String, CaseIterable {
    case credentials = "Credentials"
    case settings = "Settings"
    case help = "Help"

    var icon: String {
        switch self {
        case .credentials:
            return "wallet.pass.fill"
        case .settings:
            return "gearshape.fill"
        case .help:
            return "questionmark.circle.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .credentials:
            return NSLocalizedString("app.tab.credentials.title", comment: "Credentials tab title")
        case .settings:
            return NSLocalizedString("app.tab.settings.title", comment: "Settings tab title")
        case .help:
            return NSLocalizedString("app.tab.help.title", comment: "Help tab title")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .credentials:
            return NSLocalizedString("tab.credentials.label", comment: "Credentials tab")
        case .settings:
            return NSLocalizedString("tab.settings.label", comment: "Settings tab")
        case .help:
            return NSLocalizedString("tab.help.label", comment: "Help tab")
        }
    }
}

struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedTab: Tab = .credentials

    var body: some View {
        TabView(selection: $selectedTab) {
            // Credentials Tab
            NavigationStack {
                if appState.hasCredentials {
                    CredentialListView()
                } else if appState.isOfficerMode {
                    OfficerEntryView()
                } else {
                    AccessibleEmptyStateView()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
            .tabItem {
                Label(Tab.credentials.localizedTitle, systemImage: Tab.credentials.icon)
            }
            .tag(Tab.credentials)
            .accessibilityLabel(Tab.credentials.accessibilityLabel)

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
            .tabItem {
                Label(Tab.settings.localizedTitle, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
            .accessibilityLabel(Tab.settings.accessibilityLabel)

            // Help Tab
            NavigationStack {
                HelpView()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
            .tabItem {
                Label(Tab.help.localizedTitle, systemImage: Tab.help.icon)
            }
            .tag(Tab.help)
            .accessibilityLabel(Tab.help.accessibilityLabel)
        }
        .accentColor(AccessibleColors.primary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation")
        .onAppear {
            // Customise tab bar appearance for accessibility
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // High contrast mode
        if accessibilityManager.settings.useHighContrast {
            appearance.backgroundColor = .white
            appearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
            appearance.stackedLayoutAppearance.normal.iconColor = .darkGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.darkGray]
        }

        // Larger text for accessibility - using Dynamic Type
        if accessibilityManager.settings.useExtraLargeText {
            let normalFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1)
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium]])
            let selectedFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1)
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
            let normalFont = UIFont(descriptor: normalFontDescriptor, size: 0)
            let selectedFont = UIFont(descriptor: selectedFontDescriptor, size: 0)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.font: normalFont]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.font: selectedFont]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Help View

struct HelpView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @State private var showAccessibilitySettings = false
    @State private var searchText = ""

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case accessibilityButton
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Quick Access to Accessibility Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("app.help.quick_access.header", comment: "Quick Access section header"))
                        .font(AccessibleTypography.title2)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    quickAccessCard(
                        title: NSLocalizedString("app.help.accessibility_settings.title", comment: "Accessibility Settings title"),
                        subtitle: NSLocalizedString("app.help.accessibility_settings.subtitle", comment: "Customise your experience subtitle"),
                        icon: "accessibility",
                        color: AccessibleColors.primary
                    ) {
                        showAccessibilitySettings = true
                    }
                }

                // Help Topics
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("app.help.topics.header", comment: "Help Topics section header"))
                        .font(AccessibleTypography.title2)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(HelpArticle.allTopics, id: \.id) { topic in
                        helpTopicCard(topic: topic)
                    }
                }

                // Glossary
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("app.help.glossary.header", comment: "Glossary section header"))
                        .font(AccessibleTypography.title2)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(Glossary.shared.getAllEntries(), id: \.term) { entry in
                        glossaryCard(entry: entry)
                    }
                }
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main Content")
        }
        .background(AccessibleColors.background)
        .navigationTitle(NSLocalizedString("app.help.navigation_title", comment: "Help navigation title"))
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
    }

    private func quickAccessCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(AccessibleTypography.title3)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color)
                    )
                    .accessibilityHidden(true)
                    .horizontalStackPriority(index: 0, count: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
                .horizontalStackPriority(index: 1, count: 3)

                Spacer()

                Image(systemName: navigationChevron(isForward: true))
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                    .horizontalStackPriority(index: 2, count: 3)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.tabbar.quick_access_card.label", comment: "Quick access card with title and subtitle"), title, subtitle))
        .accessibilityHint(NSLocalizedString("accessibility.tabbar.double_tap_to_open.hint", comment: "Double tap to open hint"))
    }

    private func helpTopicCard(topic: HelpArticle) -> some View {
        NavigationLink {
            HelpArticleDetailView(topic: topic)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: topic.icon)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)
                    .horizontalStackPriority(index: 0, count: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(.primary)
                    Text(topic.summary)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .horizontalStackPriority(index: 1, count: 3)

                Spacer()

                Image(systemName: navigationChevron(isForward: true))
                    .font(AccessibleTypography.footnote)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                    .horizontalStackPriority(index: 2, count: 3)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .accessibleCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func glossaryCard(entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.term)
                .font(AccessibleTypography.headline)
                .foregroundColor(.primary)

            Text(entry.definition)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .accessibleCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.tabbar.glossary_entry.label", comment: "Glossary entry with term and definition"), entry.term, entry.definition))
    }
}

// MARK: - Help Topic Model

struct HelpArticle: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let icon: String
    let content: String

    static let allTopics: [HelpArticle] = [
        HelpArticle(
            title: NSLocalizedString("app.help.getting_credential.title", comment: "Getting a Credential title"),
            summary: NSLocalizedString("app.help.getting_credential.summary", comment: "Learn how to obtain your first age verification credential"),
            icon: "person.badge.plus",
            content: NSLocalizedString("app.help.getting_credential.content", comment: "Getting credential content with steps")
        ),
        HelpArticle(
            title: NSLocalizedString("app.help.verifying_age.title", comment: "Verifying Your Age title"),
            summary: NSLocalizedString("app.help.verifying_age.summary", comment: "How to prove your age without sharing personal information"),
            icon: "checkmark.shield",
            content: NSLocalizedString("app.help.verifying_age.content", comment: "Verifying age content with steps")
        ),
        HelpArticle(
            title: NSLocalizedString("app.help.accessibility_features.title", comment: "Accessibility Features title"),
            summary: NSLocalizedString("app.help.accessibility_features.summary", comment: "Customise the app for your needs"),
            icon: "accessibility",
            content: NSLocalizedString("app.help.accessibility_features.content", comment: "Accessibility features content")
        ),
        HelpArticle(
            title: NSLocalizedString("app.help.privacy_security.title", comment: "Privacy & Security title"),
            summary: NSLocalizedString("app.help.privacy_security.summary", comment: "How your information is protected"),
            icon: "lock.shield",
            content: NSLocalizedString("app.help.privacy_security.content", comment: "Privacy and security content")
        ),
        HelpArticle(
            title: NSLocalizedString("app.help.troubleshooting.title", comment: "Troubleshooting title"),
            summary: NSLocalizedString("app.help.troubleshooting.summary", comment: "Common issues and solutions"),
            icon: "wrench.and.screwdriver",
            content: NSLocalizedString("app.help.troubleshooting.content", comment: "Troubleshooting content with common problems")
        )
    ]
}

// MARK: - Help Topic Detail View

struct HelpArticleDetailView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let topic: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: topic.icon)
                        .font(AccessibleTypography.title3)
                        .foregroundColor(AccessibleColors.primary)
                        .accessibilityHidden(true)

                    Spacer()
                }

                Text(topic.title)
                    .font(AccessibleTypography.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text(topic.content)
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 24 : 20)
        }
        .background(AccessibleColors.background)
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
