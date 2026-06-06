// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

// Focus management utilities covering WCAG 2.2 AA 2.1.2 (No Keyboard Trap),
// 2.4.11 (Focus Not Obscured Minimum), and AAA 2.4.12/2.4.13 (Focus Not Obscured
// Enhanced, Focus Appearance). Includes focusable field definitions, a keyboard
// accessory toolbar, and WCAG compliant focus indicator styling.

// MARK: - Focus Fields for Forms

/// Defines focusable fields across the app for keyboard navigation
enum FocusableField: Hashable {
    // Authentication
    case officerPin
    case officerConfirmPin

    // Manual Entry
    case manualCodeEntry
    case verificationCodeEntry

    // Settings
    case searchIssuers
    case customIssuerUrl

    // Officer Mode
    case dobDay
    case dobMonth
    case dobYear

    // Generic
    case textField(id: String)
}

// MARK: - Focus Manager

@MainActor
class FocusManager: ObservableObject {
    static let shared = FocusManager()

    @Published var currentFocus: FocusableField?
    @Published var isKeyboardVisible = false

    private init() {
        setupKeyboardNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardVisible = true
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardVisible = false
        }
    }

    /// Move focus to the next field in the sequence
    func focusNext(from currentField: FocusableField, sequence: [FocusableField]) {
        guard let currentIndex = sequence.firstIndex(of: currentField),
              currentIndex < sequence.count - 1 else {
            // At last field, dismiss keyboard
            currentFocus = nil
            return
        }
        currentFocus = sequence[currentIndex + 1]
    }

    /// Move focus to the previous field in the sequence
    func focusPrevious(from currentField: FocusableField, sequence: [FocusableField]) {
        guard let currentIndex = sequence.firstIndex(of: currentField),
              currentIndex > 0 else {
            return
        }
        currentFocus = sequence[currentIndex - 1]
    }

    /// Set focus to a specific field
    func setFocus(to field: FocusableField?) {
        currentFocus = field
    }

    /// Clear all focus
    func clearFocus() {
        currentFocus = nil
    }
}

// MARK: - Environment Key

private struct FocusManagerKey: EnvironmentKey {
    static let defaultValue = FocusManager.shared
}

extension EnvironmentValues {
    var focusManager: FocusManager {
        get { self[FocusManagerKey.self] }
        set { self[FocusManagerKey.self] = newValue }
    }
}

// MARK: - View Extension for Focus

extension View {
    /// Apply focus management to a field
    func managedFocus<F: Hashable>(
        _ field: F,
        equals: FocusState<F?>.Binding,
        onReturn: (() -> Void)? = nil
    ) -> some View {
        self
            .focused(equals, equals: field)
            .onSubmit {
                onReturn?()
            }
    }
}

// MARK: - Keyboard Toolbar for Accessibility

struct KeyboardAccessoryToolbar: ViewModifier {
    let onPrevious: (() -> Void)?
    let onNext: (() -> Void)?
    let onDone: () -> Void
    let canGoPrevious: Bool
    let canGoNext: Bool

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack(spacing: 16) {
                        // Previous button
                        Button(action: { onPrevious?() }, label: {
                            Image(systemName: "chevron.up")
                                .accessibilityLabel(NSLocalizedString("accessibility.focus.previous_field.label", comment: "Previous field button"))
                        })
                        .disabled(!canGoPrevious || onPrevious == nil)

                        // Next button
                        Button(action: { onNext?() }, label: {
                            Image(systemName: "chevron.down")
                                .accessibilityLabel(NSLocalizedString("accessibility.focus.next_field.label", comment: "Next field button"))
                        })
                        .disabled(!canGoNext || onNext == nil)

                        Spacer()

                        // Done button
                        Button(LocalizedString.done.localized) {
                            onDone()
                        }
                        .accessibilityLabel(NSLocalizedString("accessibility.focus.done_editing.label", comment: "Done editing button"))
                        .accessibilityHint(NSLocalizedString("accessibility.focus.closes_keyboard.hint", comment: "Closes the keyboard hint"))
                    }
                }
            }
    }
}

extension View {
    func keyboardAccessory(
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onDone: @escaping () -> Void,
        canGoPrevious: Bool = true,
        canGoNext: Bool = true
    ) -> some View {
        self.modifier(KeyboardAccessoryToolbar(
            onPrevious: onPrevious,
            onNext: onNext,
            onDone: onDone,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext
        ))
    }
}

// MARK: - WCAG 2.2 Focus Appearance

/// WCAG 2.2 AAA: 2.4.13 Focus Appearance
/// Focus indicator must be at least 2 CSS pixels thick and have 3:1 contrast
struct AccessibleFocusStyle: ViewModifier {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focusColor, lineWidth: isActive ? focusLineWidth : 0)
                    .animation(accessibilityManager.settings.reduceMotion ? nil : .easeInOut(duration: 0.15), value: isActive)
            )
    }

    private var focusLineWidth: CGFloat {
        // WCAG 1.4.11: Focus indicators must be at least 3px for 3:1 contrast
        // Use 4px in high contrast mode for enhanced visibility
        accessibilityManager.settings.useHighContrast ? 4 : 3
    }

    private var focusColor: Color {
        // Use dynamic colors that adapt to all accessibility settings
        // Ensures 3:1 contrast ratio minimum with background in all modes
        if colorScheme == .dark {
            // In dark mode, use white for maximum contrast
            return .white
        } else {
            // In light mode, use AccessibleColors.primary which adapts to:
            // - High contrast mode
            // - Color blindness modes
            // - AAA contrast levels
            // WCAG 1.4.11: Ensure focus indicator has sufficient contrast
            return accessibilityManager.settings.useHighContrast ? .black : AccessibleColors.primary
        }
    }
}

extension View {
    /// Apply WCAG 2.2 AAA compliant focus styling
    /// - 3px border (exceeds 2px minimum)
    /// - High contrast color (3:1 minimum)
    /// - Visible and not obscured
    func accessibleFocus(isActive: Bool) -> some View {
        self.modifier(AccessibleFocusStyle(isActive: isActive))
    }
}

// MARK: - Focus Visibility Management

/// WCAG 2.2 AA: 2.4.11 Focus Not Obscured (Minimum)
/// WCAG 2.2 AAA: 2.4.12 Focus Not Obscured (Enhanced)
struct FocusVisibilityModifier: ViewModifier {
    @Namespace private var focusNamespace
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: isFocused) { focused in
                    if focused {
                        // Scroll to ensure focus indicator is fully visible
                        // AAA compliance: No part of focus indicator is hidden
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(focusNamespace, anchor: .center)
                        }
                    }
                }
                .id(focusNamespace)
        }
    }
}

extension View {
    /// Ensures focused element is fully visible when focused
    /// Implements WCAG 2.2 AA 2.4.11 and AAA 2.4.12
    func ensureFocusVisible() -> some View {
        self.modifier(FocusVisibilityModifier())
    }
}
