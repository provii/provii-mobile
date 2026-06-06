// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

/// Skip link component that appears first in focus order and allows users to jump past
/// repeated navigation elements directly to main content. Only visible when focused by
/// keyboard or when VoiceOver is running. Meets WCAG 2.2 AA: 2.4.1 Bypass Blocks.
struct SkipLink: View {
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState private var isAccessibilityFocused: Bool
    @Binding var skipToContent: Bool
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    let label: String
    let destination: String

    init(
        label: String = NSLocalizedString("skip_link.main_content", comment: "Skip to main content"),
        destination: String = "main-content",
        skipToContent: Binding<Bool>
    ) {
        self.label = label
        self.destination = destination
        self._skipToContent = skipToContent
    }

    var body: some View {
        Button(action: {
            skipToContent = true
            HapticFeedback.selection()
            announceIfVoiceOver(String(format: NSLocalizedString("skip_link.skipped_to", comment: "Skipped to %@"), label))
        }, label: {
            Text(label)
                .font(AccessibleTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 2)
                )
        })
        .focused($isFocused)
        .opacity(shouldBeVisible ? 1 : 0)
        .frame(height: shouldBeVisible ? nil : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityHint(NSLocalizedString("skip_link.hint", comment: "Activate to skip navigation and go directly to main content"))
        .accessibilityAddTraits(.isLink)
        .accessibilityFocused($isAccessibilityFocused)
        .onChange(of: skipToContent) { _, newValue in
            if newValue {
                // Reset after content has been focused
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    skipToContent = false
                }
            }
        }
    }

    // MARK: - Visibility Logic

    /// Skip link is visible when it has keyboard focus or VoiceOver is running.
    private var shouldBeVisible: Bool {
        isFocused || UIAccessibility.isVoiceOverRunning
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        if accessibilityManager.settings.useHighContrast {
            return Color.yellow
        }
        return AccessibleColors.primary
    }

    private var textColor: Color {
        if accessibilityManager.settings.useHighContrast {
            return .black
        }
        return .white
    }

    private var borderColor: Color {
        if accessibilityManager.settings.useHighContrast {
            return .black
        }
        return AccessibleColors.primary
    }

    // MARK: - Helpers

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Skip Link Container

/// Container view that manages skip links and main content focus.
struct SkipLinkContainer<Content: View>: View {
    @FocusState private var mainContentFocused: Bool
    @State private var skipToContent = false

    let skipLinkLabel: String
    let mainContentId: String
    let content: Content

    init(
        skipLinkLabel: String = NSLocalizedString("skip_link.main_content", comment: "Skip to main content"),
        mainContentId: String = "main-content",
        @ViewBuilder content: () -> Content
    ) {
        self.skipLinkLabel = skipLinkLabel
        self.mainContentId = mainContentId
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Skip link (first in focus order)
            SkipLink(
                label: skipLinkLabel,
                destination: mainContentId,
                skipToContent: $skipToContent
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Main content
            content
                .focused($mainContentFocused)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(mainContentId)
                .onChange(of: skipToContent) { _, shouldSkip in
                    if shouldSkip {
                        // Move focus to main content
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            mainContentFocused = true
                        }
                    }
                }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Wraps a view with skip link functionality.
    func withSkipLink(
        skipLinkLabel: String = NSLocalizedString("skip_link.main_content", comment: "Skip to main content"),
        mainContentId: String = "main-content"
    ) -> some View {
        SkipLinkContainer(
            skipLinkLabel: skipLinkLabel,
            mainContentId: mainContentId
        ) {
            self
        }
    }
}

// MARK: - Skip Link Coordinator

/// Manages skip link state across the app.
@MainActor
class SkipLinkCoordinator: ObservableObject {
    static let shared = SkipLinkCoordinator()

    @Published var shouldSkipToContent = false
    @Published var currentMainContentId: String?

    private init() {}

    func skipToContent(id: String) {
        currentMainContentId = id
        shouldSkipToContent = true

        // Reset after a short delay
        // MASVS CODE-1: Use [weak self] to prevent retain cycles in escaping closures
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.shouldSkipToContent = false
        }
    }
}

// MARK: - Accessibility Focus Management for Skip Links

/// Custom focus state for managing skip link behaviour.
struct SkipLinkFocusState {
    var isSkipLinkFocused: Bool = false
    var isMainContentFocused: Bool = false
    var shouldSkipToContent: Bool = false
}

/// View modifier for adding skip link behaviour to any view.
struct WithSkipLinkModifier: ViewModifier {
    @FocusState private var skipLinkFocused: Bool
    @FocusState private var mainContentFocused: Bool
    @State private var skipToContent = false

    let skipLinkLabel: String
    let mainContentId: String

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // Skip link
            SkipLink(
                label: skipLinkLabel,
                destination: mainContentId,
                skipToContent: $skipToContent
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Main content
            content
                .focused($mainContentFocused)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(mainContentId)
                .onChange(of: skipToContent) { _, shouldSkip in
                    if shouldSkip {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            mainContentFocused = true
                        }
                    }
                }
        }
    }
}

extension View {
    /// Alternative method to add skip link using a view modifier.
    func skipLinkModifier(
        label: String = NSLocalizedString("skip_link.main_content", comment: "Skip to main content"),
        mainContentId: String = "main-content"
    ) -> some View {
        self.modifier(WithSkipLinkModifier(
            skipLinkLabel: label,
            mainContentId: mainContentId
        ))
    }
}

// MARK: - Skip Link Presets

/// Common skip link configurations for different views.
enum SkipLinkPreset {
    case mainContent
    case credentials
    case settings
    case help
    case verificationForm
    case customContent(label: String, id: String)

    var label: String {
        switch self {
        case .mainContent:
            return NSLocalizedString("skip_link.main_content", comment: "Skip to main content")
        case .credentials:
            return NSLocalizedString("skip_link.credentials", comment: "Skip to credentials list")
        case .settings:
            return NSLocalizedString("skip_link.settings", comment: "Skip to settings")
        case .help:
            return NSLocalizedString("skip_link.help", comment: "Skip to help content")
        case .verificationForm:
            return NSLocalizedString("skip_link.verification", comment: "Skip to verification form")
        case .customContent(let label, _):
            return label
        }
    }

    var id: String {
        switch self {
        case .mainContent:
            return "main-content"
        case .credentials:
            return "credentials-content"
        case .settings:
            return "settings-content"
        case .help:
            return "help-content"
        case .verificationForm:
            return "verification-form"
        case .customContent(_, let id):
            return id
        }
    }
}

extension View {
    /// Add skip link using a preset configuration.
    func withSkipLink(preset: SkipLinkPreset) -> some View {
        self.withSkipLink(
            skipLinkLabel: preset.label,
            mainContentId: preset.id
        )
    }
}
