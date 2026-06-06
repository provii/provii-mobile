// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

// Keyboard shortcut definitions and handler for external keyboard users.
// Satisfies WCAG 2.2 AAA criterion 2.1.3 (Keyboard, No Exception) by providing
// command key shortcuts for settings, accessibility, help, credential management,
// and verification actions, along with a discoverable shortcuts display view.

// MARK: - Keyboard Shortcut Definitions

enum AppKeyboardShortcut: String, CaseIterable, Identifiable {
    case settings = "s"
    case accessibility = "a"
    case help = "h"
    case addCredential = "n"
    case startVerification = "v"
    case keyboardShortcuts = "k"

    var id: String { rawValue }

    var key: String {
        rawValue
    }

    var modifiers: EventModifiers {
        .command
    }

    var title: String {
        switch self {
        case .settings: return NSLocalizedString("accessibility.keyboard.shortcut.settings.title", comment: "Open Settings shortcut title")
        case .accessibility: return NSLocalizedString("accessibility.keyboard.shortcut.accessibility.title", comment: "Accessibility Settings shortcut title")
        case .help: return NSLocalizedString("accessibility.keyboard.shortcut.help.title", comment: "Help shortcut title")
        case .addCredential: return NSLocalizedString("accessibility.keyboard.shortcut.add_credential.title", comment: "Add Credential shortcut title")
        case .startVerification: return NSLocalizedString("accessibility.keyboard.shortcut.start_verification.title", comment: "Start Verification shortcut title")
        case .keyboardShortcuts: return NSLocalizedString("accessibility.keyboard.shortcut.keyboard_shortcuts.title", comment: "Keyboard Shortcuts shortcut title")
        }
    }

    var displayKey: String {
        "⌘\(key.uppercased())"
    }

    var description: String {
        switch self {
        case .settings: return NSLocalizedString("accessibility.keyboard.shortcut.settings.description", comment: "Open Settings shortcut description")
        case .accessibility: return NSLocalizedString("accessibility.keyboard.shortcut.accessibility.description", comment: "Accessibility Settings shortcut description")
        case .help: return NSLocalizedString("accessibility.keyboard.shortcut.help.description", comment: "Help shortcut description")
        case .addCredential: return NSLocalizedString("accessibility.keyboard.shortcut.add_credential.description", comment: "Add Credential shortcut description")
        case .startVerification: return NSLocalizedString("accessibility.keyboard.shortcut.start_verification.description", comment: "Start Verification shortcut description")
        case .keyboardShortcuts: return NSLocalizedString("accessibility.keyboard.shortcut.keyboard_shortcuts.description", comment: "Keyboard Shortcuts shortcut description")
        }
    }
}

// MARK: - Navigation Shortcuts

enum NavigationShortcut: String, CaseIterable {
    case escape = "esc"
    case tab = "tab"
    case shiftTab = "shift+tab"
    case enter = "return"
    case space = "space"

    var displayKey: String {
        switch self {
        case .escape: return NSLocalizedString("accessibility.keyboard.navigation.escape.display_key", comment: "ESC key display")
        case .tab: return NSLocalizedString("accessibility.keyboard.navigation.tab.display_key", comment: "TAB key display")
        case .shiftTab: return NSLocalizedString("accessibility.keyboard.navigation.shift_tab.display_key", comment: "Shift+TAB key display")
        case .enter: return NSLocalizedString("accessibility.keyboard.navigation.enter.display_key", comment: "RETURN key display")
        case .space: return NSLocalizedString("accessibility.keyboard.navigation.space.display_key", comment: "SPACE key display")
        }
    }

    var title: String {
        switch self {
        case .escape: return NSLocalizedString("accessibility.keyboard.navigation.escape.title", comment: "Go Back/Dismiss title")
        case .tab: return NSLocalizedString("accessibility.keyboard.navigation.tab.title", comment: "Next Field title")
        case .shiftTab: return NSLocalizedString("accessibility.keyboard.navigation.shift_tab.title", comment: "Previous Field title")
        case .enter: return NSLocalizedString("accessibility.keyboard.navigation.enter.title", comment: "Submit/Continue title")
        case .space: return NSLocalizedString("accessibility.keyboard.navigation.space.title", comment: "Activate Button title")
        }
    }

    var description: String {
        switch self {
        case .escape: return NSLocalizedString("accessibility.keyboard.navigation.escape.description", comment: "Escape key description")
        case .tab: return NSLocalizedString("accessibility.keyboard.navigation.tab.description", comment: "Tab key description")
        case .shiftTab: return NSLocalizedString("accessibility.keyboard.navigation.shift_tab.description", comment: "Shift+Tab key description")
        case .enter: return NSLocalizedString("accessibility.keyboard.navigation.enter.description", comment: "Enter key description")
        case .space: return NSLocalizedString("accessibility.keyboard.navigation.space.description", comment: "Space key description")
        }
    }
}

// MARK: - Keyboard Shortcut Handler

@MainActor
class KeyboardShortcutHandler: ObservableObject {
    static let shared = KeyboardShortcutHandler()

    @Published var isEnabled = true

    // Callback closures for each shortcut
    var onSettings: (() -> Void)?
    var onAccessibility: (() -> Void)?
    var onHelp: (() -> Void)?
    var onAddCredential: (() -> Void)?
    var onStartVerification: (() -> Void)?
    var onKeyboardShortcuts: (() -> Void)?
    var onDismiss: (() -> Void)?

    private init() {}

    func handle(_ shortcut: AppKeyboardShortcut) {
        guard isEnabled else { return }

        switch shortcut {
        case .settings:
            onSettings?()
        case .accessibility:
            onAccessibility?()
        case .help:
            onHelp?()
        case .addCredential:
            onAddCredential?()
        case .startVerification:
            onStartVerification?()
        case .keyboardShortcuts:
            onKeyboardShortcuts?()
        }
    }
}

// MARK: - View Modifier for Keyboard Shortcuts

struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject private var handler = KeyboardShortcutHandler.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    let onSettings: () -> Void
    let onAccessibility: () -> Void
    let onHelp: () -> Void
    let onAddCredential: () -> Void
    let onStartVerification: () -> Void
    let onKeyboardShortcuts: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                setupHandlers()
            }
    }

    private func setupHandlers() {
        handler.onSettings = onSettings
        handler.onAccessibility = onAccessibility
        handler.onHelp = onHelp
        handler.onAddCredential = onAddCredential
        handler.onStartVerification = onStartVerification
        handler.onKeyboardShortcuts = onKeyboardShortcuts
    }
}

struct KeyboardShortcutActions {
    let onSettings: () -> Void
    let onAccessibility: () -> Void
    let onHelp: () -> Void
    let onAddCredential: () -> Void
    let onStartVerification: () -> Void
    let onKeyboardShortcuts: () -> Void
}

extension View {
    func keyboardShortcuts(actions: KeyboardShortcutActions) -> some View {
        self.modifier(KeyboardShortcutsModifier(
            onSettings: actions.onSettings,
            onAccessibility: actions.onAccessibility,
            onHelp: actions.onHelp,
            onAddCredential: actions.onAddCredential,
            onStartVerification: actions.onStartVerification,
            onKeyboardShortcuts: actions.onKeyboardShortcuts
        ))
    }
}

// MARK: - Keyboard Shortcuts Display View

struct KeyboardShortcutsView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Breadcrumb Navigation
                BreadcrumbView(path: [
                    NSLocalizedString("breadcrumb.home", comment: "Home"),
                    NSLocalizedString("breadcrumb.settings", comment: "Settings"),
                    NSLocalizedString("breadcrumb.accessibility", comment: "Accessibility"),
                    NSLocalizedString("breadcrumb.keyboard_shortcuts", comment: "Keyboard Shortcuts")
                ])
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                List {
                    appShortcutsSection
                    navigationShortcutsSection
                    tipsSection
                }
            }
            .navigationTitle(NSLocalizedString("accessibility.keyboard.shortcuts_view.navigation_title", comment: "Keyboard Shortcuts navigation title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("accessibility.keyboard.shortcuts_view.done_button", comment: "Done button")) {
                        dismiss()
                    }
                    .foregroundColor(AccessibleColors.primary)
                }
            }
        }
    }

    // MARK: - Sections

    private var appShortcutsSection: some View {
        Section {
            ForEach(AppKeyboardShortcut.allCases) { shortcut in
                ShortcutRow(
                    key: shortcut.displayKey,
                    title: shortcut.title,
                    description: manager.settings.verboseDescriptions ? shortcut.description : nil
                )
            }
        } header: {
            Text(NSLocalizedString("accessibility.keyboard.shortcuts_view.app_shortcuts.header", comment: "App Shortcuts section header"))
        }
    }

    private var navigationShortcutsSection: some View {
        Section {
            ForEach(NavigationShortcut.allCases, id: \.self) { shortcut in
                ShortcutRow(
                    key: shortcut.displayKey,
                    title: shortcut.title,
                    description: manager.settings.verboseDescriptions ? shortcut.description : nil
                )
            }
        } header: {
            Text(NSLocalizedString("accessibility.keyboard.shortcuts_view.navigation.header", comment: "Navigation section header"))
        } footer: {
            if manager.settings.verboseDescriptions {
                Text(NSLocalizedString("accessibility.keyboard.shortcuts_view.navigation.footer", comment: "Navigation section footer"))
                    .font(.caption)
            }
        }
    }

    private var tipsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                TipRow(
                    icon: "keyboard",
                    text: NSLocalizedString("accessibility.keyboard.shortcuts_view.tip.external_keyboards", comment: "External keyboards tip")
                )

                TipRow(
                    icon: "arrow.up.arrow.down",
                    text: NSLocalizedString("accessibility.keyboard.shortcuts_view.tip.arrow_keys", comment: "Arrow keys tip")
                )

                TipRow(
                    icon: "command",
                    text: NSLocalizedString("accessibility.keyboard.shortcuts_view.tip.hold_command", comment: "Hold Command tip")
                )

                if manager.settings.verboseDescriptions {
                    TipRow(
                        icon: "info.circle",
                        text: NSLocalizedString("accessibility.keyboard.shortcuts_view.tip.keyboard_accessible", comment: "Keyboard accessible tip")
                    )
                }
            }
        } header: {
            Text(NSLocalizedString("accessibility.keyboard.shortcuts_view.tips.header", comment: "Tips section header"))
        }
    }
}

// MARK: - Supporting Views

private struct ShortcutRow: View {
    @ObservedObject private var manager = AccessibilityManager.shared

    let key: String
    let title: String
    let description: String?

    var body: some View {
        HStack(spacing: manager.settings.increaseTouchTargets ? 16 : 12) {
            // Key display
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(AccessibleColors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(manager.settings.useHighContrast ? Color.black : Color.clear, lineWidth: 1)
                        )
                )
                .frame(minWidth: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AccessibleTypography.body)
                    .foregroundColor(.primary)

                if let description = description {
                    Text(description)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.keyboard.shortcut_description.label", comment: "Keyboard shortcut with key, title and description"), key, title, description ?? ""))
    }
}

private struct TipRow: View {
    @ObservedObject private var manager = AccessibilityManager.shared

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AccessibleColors.primary)
                .frame(width: 24)

            Text(text)
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.keyboard.tip.label", comment: "Keyboard shortcut tip"), text))
    }
}

#Preview {
    KeyboardShortcutsView()
}
