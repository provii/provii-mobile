// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

// Modal keyboard navigation implementing WCAG 2.2 AA 2.1.2 (No Keyboard Trap) and
// AAA 2.1.3 (Keyboard, No Exception). Manages focus trapping within modals, tab/shift-tab
// cycling through focusable elements, escape to dismiss, and focus restoration on close.
// Covers modals, dialogs, alerts, action sheets, and bottom sheets.

// MARK: - Modal Keyboard Events

enum ModalKeyboardEvent {
    case escape
    case enter
    case tab
    case shiftTab
    case arrowUp
    case arrowDown
    case space
}

// MARK: - Modal Focus Trap Manager

/// Manages focus trapping within modals to prevent keyboard trap violations
@MainActor
class ModalFocusTrapManager: ObservableObject {
    static let shared = ModalFocusTrapManager()

    @Published var activeModalId: UUID?
    @Published var focusableElements: [UUID] = []
    @Published var currentFocusIndex: Int = 0
    @Published var previousFocusElement: UUID?

    private var dismissHandlers: [UUID: () -> Void] = [:]
    private var confirmHandlers: [UUID: () -> Void] = [:]

    private init() {}

    // MARK: - Modal Lifecycle

    /// Register a modal and store the element that should receive focus when dismissed
    func registerModal(
        id: UUID,
        focusableElements: [UUID],
        previousFocus: UUID?,
        onDismiss: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil
    ) {
        self.activeModalId = id
        self.focusableElements = focusableElements
        self.previousFocusElement = previousFocus
        self.currentFocusIndex = 0
        self.dismissHandlers[id] = onDismiss
        if let confirm = onConfirm {
            self.confirmHandlers[id] = confirm
        }

        // Focus first element after a brief delay to ensure modal is presented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.focusFirstElement()
        }
    }

    /// Unregister a modal and restore previous focus
    func unregisterModal(id: UUID) {
        guard activeModalId == id else { return }

        dismissHandlers.removeValue(forKey: id)
        confirmHandlers.removeValue(forKey: id)
        activeModalId = nil
        focusableElements = []
        currentFocusIndex = 0

        // Restore focus to previous element
        if let previous = previousFocusElement {
            restoreFocus(to: previous)
        }
        previousFocusElement = nil
    }

    // MARK: - Focus Management

    /// Move focus to the first focusable element in the modal
    func focusFirstElement() {
        guard !focusableElements.isEmpty else { return }
        currentFocusIndex = 0
        announceCurrentFocus()
    }

    /// Move focus to the last focusable element in the modal
    func focusLastElement() {
        guard !focusableElements.isEmpty else { return }
        currentFocusIndex = focusableElements.count - 1
        announceCurrentFocus()
    }

    /// Move focus to the next element (Tab key)
    func focusNext() {
        guard !focusableElements.isEmpty else { return }

        currentFocusIndex += 1

        // Wrap around to first element (focus trap)
        if currentFocusIndex >= focusableElements.count {
            currentFocusIndex = 0
        }

        announceCurrentFocus()
        provideHapticFeedback()
    }

    /// Move focus to the previous element (Shift+Tab key)
    func focusPrevious() {
        guard !focusableElements.isEmpty else { return }

        currentFocusIndex -= 1

        // Wrap around to last element (focus trap)
        if currentFocusIndex < 0 {
            currentFocusIndex = focusableElements.count - 1
        }

        announceCurrentFocus()
        provideHapticFeedback()
    }

    /// Get the currently focused element ID
    func getCurrentFocusId() -> UUID? {
        guard currentFocusIndex >= 0 && currentFocusIndex < focusableElements.count else {
            return nil
        }
        return focusableElements[currentFocusIndex]
    }

    // MARK: - Keyboard Event Handling

    /// Handle keyboard events for the active modal
    func handleKeyboardEvent(_ event: ModalKeyboardEvent) {
        guard let modalId = activeModalId else { return }

        switch event {
        case .escape:
            // ESC key dismisses modal
            dismissHandlers[modalId]?()

        case .enter, .space:
            // Enter/Space confirms primary action
            if let confirm = confirmHandlers[modalId] {
                confirm()
            } else {
                // If no confirm handler, just dismiss
                dismissHandlers[modalId]?()
            }

        case .tab:
            focusNext()

        case .shiftTab:
            focusPrevious()

        case .arrowDown:
            focusNext()

        case .arrowUp:
            focusPrevious()
        }
    }

    // MARK: - Private Helpers

    private func announceCurrentFocus() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let elementNumber = currentFocusIndex + 1
        let totalElements = focusableElements.count

        let announcement = String(
            format: NSLocalizedString(
                "accessibility.modal.focus.element_of_total",
                comment: "Focused element %d of %d"
            ),
            elementNumber,
            totalElements
        )

        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private func restoreFocus(to elementId: UUID) {
        // Post notification for the view to restore focus
        NotificationCenter.default.post(
            name: .restoreFocusNotification,
            object: nil,
            userInfo: ["elementId": elementId]
        )
    }

    private func provideHapticFeedback() {
        HapticFeedback.selection()
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let restoreFocusNotification = Notification.Name("app.provii.wallet.restoreFocus")
}

// MARK: - Modal Button Role

enum ModalButtonRole {
    case primary      // Confirm/OK action
    case cancel       // Cancel/dismiss action
    case destructive  // Delete/remove action
    case secondary    // Additional action
}

// MARK: - Accessible Modal Button

struct AccessibleModalButton: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @ObservedObject private var focusManager = ModalFocusTrapManager.shared

    let id: UUID
    let title: String
    let role: ModalButtonRole
    let action: () -> Void

    @State private var isFocused = false

    var body: some View {
        Button(action: handleAction) {
            Text(title)
                .font(AccessibleTypography.body)
                .fontWeight(role == .primary ? .semibold : .regular)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, manager.settings.increaseTouchTargets ? 14 : 12)
                .background(backgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibleFocus(isActive: isFocused)
        .onReceive(focusManager.$currentFocusIndex) { _ in
            updateFocusState()
        }
        .onAppear {
            updateFocusState()
        }
    }

    private func handleAction() {
        HapticFeedback.selection()
        action()
    }

    private func updateFocusState() {
        isFocused = focusManager.getCurrentFocusId() == id
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return .white
        case .destructive:
            return manager.settings.useHighContrast ? .black : AccessibleColors.error
        case .cancel, .secondary:
            return manager.settings.useHighContrast ? .black : AccessibleColors.primary
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .primary:
            return manager.settings.useHighContrast ? Color.yellow : AccessibleColors.primary
        case .destructive:
            return manager.settings.useHighContrast ?
                AccessibleColors.error.opacity(0.2) :
                AccessibleColors.error.opacity(0.1)
        case .cancel, .secondary:
            return Color.clear
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return manager.settings.useHighContrast ? Color.black : Color.clear
        case .destructive:
            return AccessibleColors.error
        case .cancel, .secondary:
            return manager.settings.useHighContrast ?
                Color.black :
                Color.gray.opacity(0.6)
        }
    }

    private var borderWidth: CGFloat {
        manager.settings.useHighContrast ? 2 : 1
    }

    private var accessibilityLabel: String {
        switch role {
        case .primary:
            return String(
                format: NSLocalizedString(
                    "accessibility.modal.button.primary",
                    comment: "%@ (primary action)"
                ),
                title
            )
        case .cancel:
            return String(
                format: NSLocalizedString(
                    "accessibility.modal.button.cancel",
                    comment: "%@ (cancel)"
                ),
                title
            )
        case .destructive:
            return String(
                format: NSLocalizedString(
                    "accessibility.modal.button.destructive",
                    comment: "%@ (destructive action)"
                ),
                title
            )
        case .secondary:
            return title
        }
    }

    private var accessibilityHint: String {
        switch role {
        case .primary:
            return NSLocalizedString(
                "accessibility.modal.button.primary.hint",
                comment: "Double tap to confirm, or press Enter"
            )
        case .cancel:
            return NSLocalizedString(
                "accessibility.modal.button.cancel.hint",
                comment: "Double tap to cancel, or press Escape"
            )
        case .destructive:
            return NSLocalizedString(
                "accessibility.modal.button.destructive.hint",
                comment: "Double tap to perform destructive action"
            )
        case .secondary:
            return NSLocalizedString(
                "accessibility.modal.button.secondary.hint",
                comment: "Double tap to perform action"
            )
        }
    }
}

// MARK: - Modal Keyboard Handler View Modifier

struct ModalKeyboardHandlerModifier: ViewModifier {
    let modalId: UUID
    let buttonIds: [UUID]
    let onDismiss: () -> Void
    let onConfirm: (() -> Void)?

    @ObservedObject private var focusManager = ModalFocusTrapManager.shared
    @State private var previousFocusId: UUID?

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Register modal with focus manager
                focusManager.registerModal(
                    id: modalId,
                    focusableElements: buttonIds,
                    previousFocus: previousFocusId,
                    onDismiss: onDismiss,
                    onConfirm: onConfirm
                )

                // Announce modal opened for VoiceOver users
                announceModalOpened()
            }
            .onDisappear {
                // Unregister modal and restore focus
                focusManager.unregisterModal(id: modalId)

                // Announce modal closed for VoiceOver users
                announceModalClosed()
            }
            .onKeyPress(.escape) {
                focusManager.handleKeyboardEvent(.escape)
                return .handled
            }
            .onKeyPress(.return) {
                focusManager.handleKeyboardEvent(.enter)
                return .handled
            }
            .onKeyPress(.space) {
                focusManager.handleKeyboardEvent(.space)
                return .handled
            }
            .onKeyPress(.tab) {
                // Note: Cannot detect shift modifier in basic onKeyPress
                focusManager.handleKeyboardEvent(.tab)
                return .handled
            }
            .onKeyPress(.upArrow) {
                focusManager.handleKeyboardEvent(.arrowUp)
                return .handled
            }
            .onKeyPress(.downArrow) {
                focusManager.handleKeyboardEvent(.arrowDown)
                return .handled
            }
    }

    private func announceModalOpened() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let announcement = NSLocalizedString(
                "accessibility.modal.opened",
                comment: "Dialog opened. Press Escape to dismiss, Enter to confirm."
            )
            UIAccessibility.post(notification: .screenChanged, argument: announcement)
        }
    }

    private func announceModalClosed() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let announcement = NSLocalizedString(
            "accessibility.modal.closed",
            comment: "Dialog closed"
        )
        UIAccessibility.post(notification: .screenChanged, argument: announcement)
    }
}

extension View {
    /// Add keyboard navigation support to modals, alerts, and action sheets
    /// - Parameters:
    ///   - modalId: Unique identifier for this modal
    ///   - buttonIds: Array of button IDs in tab order
    ///   - onDismiss: Callback when modal is dismissed (ESC key)
    ///   - onConfirm: Optional callback for primary action (Enter key)
    func modalKeyboardNavigation(
        modalId: UUID = UUID(),
        buttonIds: [UUID],
        onDismiss: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil
    ) -> some View {
        self.modifier(ModalKeyboardHandlerModifier(
            modalId: modalId,
            buttonIds: buttonIds,
            onDismiss: onDismiss,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Sheet Keyboard Navigation

struct SheetKeyboardNavigationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?

    @ObservedObject private var focusManager = ModalFocusTrapManager.shared
    @State private var sheetId = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                // When sheet appears, set up keyboard handling
                setupSheetKeyboardHandling()
            }
            .onDisappear {
                focusManager.unregisterModal(id: sheetId)
            }
            .onKeyPress(.escape) {
                dismissSheet()
                return .handled
            }
    }

    private func setupSheetKeyboardHandling() {
        // Register the sheet for keyboard navigation
        // Sheets don't have predefined buttons, so we leave elements empty
        focusManager.registerModal(
            id: sheetId,
            focusableElements: [],
            previousFocus: nil,
            onDismiss: dismissSheet,
            onConfirm: nil
        )
    }

    private func dismissSheet() {
        isPresented = false
        onDismiss?()
    }
}

extension View {
    /// Add keyboard navigation to sheet presentations
    /// Enables ESC key to dismiss the sheet
    func sheetKeyboardNavigation(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.modifier(SheetKeyboardNavigationModifier(
            isPresented: isPresented,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Accessible Alert Builder

/// Helper to create accessible alerts with keyboard navigation
struct AccessibleAlertBuilder {
    let title: String
    let message: String?
    let buttons: [AlertButton]

    struct AlertButton: Identifiable {
        let id = UUID()
        let title: String
        let role: ModalButtonRole
        let action: () -> Void
    }

    static func confirmation(
        title: String,
        message: String? = nil,
        confirmTitle: String = NSLocalizedString("alert.confirm", comment: "Confirm"),
        cancelTitle: String = NSLocalizedString("alert.cancel", comment: "Cancel"),
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> AccessibleAlertBuilder {
        AccessibleAlertBuilder(
            title: title,
            message: message,
            buttons: [
                AlertButton(title: cancelTitle, role: .cancel, action: onCancel ?? {}),
                AlertButton(title: confirmTitle, role: .primary, action: onConfirm)
            ]
        )
    }

    static func destructive(
        title: String,
        message: String? = nil,
        destructiveTitle: String = NSLocalizedString("alert.delete", comment: "Delete"),
        cancelTitle: String = NSLocalizedString("alert.cancel", comment: "Cancel"),
        onDestructive: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> AccessibleAlertBuilder {
        AccessibleAlertBuilder(
            title: title,
            message: message,
            buttons: [
                AlertButton(title: cancelTitle, role: .cancel, action: onCancel ?? {}),
                AlertButton(title: destructiveTitle, role: .destructive, action: onDestructive)
            ]
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        AccessibleModalButton(
            id: UUID(),
            title: "Confirm",
            role: .primary,
            action: {}
        )

        AccessibleModalButton(
            id: UUID(),
            title: "Cancel",
            role: .cancel,
            action: {}
        )

        AccessibleModalButton(
            id: UUID(),
            title: "Delete",
            role: .destructive,
            action: {}
        )
    }
    .padding()
}
