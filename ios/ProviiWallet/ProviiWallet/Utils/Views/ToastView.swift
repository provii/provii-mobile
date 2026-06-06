// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine
import UIKit

// Toast notification system providing transient, non blocking messages with VoiceOver
// announcements and haptic feedback. Includes a singleton ToastManager for global toast
// display, success/error/warning convenience methods, and a GlobalToastModifier for
// wiring up at the root view level.

// MARK: - Toast Data Model
struct Toast: Equatable {
    var message: String
    var duration: Double = 2.0
    var icon: String?
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    @State private var workItem: DispatchWorkItem?
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    if let toast = toast {
                        toastView(toast: toast)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint(NSLocalizedString("toast_tap_to_dismiss_hint", comment: "Accessibility hint for dismissing a toast notification"))
                            .onTapGesture {
                                dismissToast()
                            }
                    }
                }
                .animation(accessibilityManager.settings.reduceMotion ? nil : .spring(), value: toast)
                , alignment: .bottom
            )
            .onChange(of: toast) { newValue in
                showToast(newValue)
            }
    }

    @ViewBuilder
    private func toastView(toast: Toast) -> some View {
        HStack(spacing: 12) {
            if let icon = toast.icon {
                Text(icon)
                    .font(AccessibleTypography.body)
            }

            Text(toast.message)
                .font(AccessibleTypography.footnote.weight(.medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelForToast(toast))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func accessibilityLabelForToast(_ toast: Toast) -> String {
        let iconMeaning: String
        if let icon = toast.icon {
            switch icon {
            case "✓":
                iconMeaning = NSLocalizedString("accessibility.toast.success", comment: "Success icon meaning")
            case "✗":
                iconMeaning = NSLocalizedString("accessibility.toast.error", comment: "Error icon meaning")
            case "⚠️":
                iconMeaning = NSLocalizedString("accessibility.toast.warning", comment: "Warning icon meaning")
            default:
                iconMeaning = ""
            }
        } else {
            iconMeaning = ""
        }

        return iconMeaning.isEmpty ? toast.message : "\(iconMeaning). \(toast.message)"
    }

    private func showToast(_ toast: Toast?) {
        guard let toast = toast else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Announce toast to VoiceOver users
        let accessibilityLabel = accessibilityLabelForToast(toast)
        UIAccessibility.post(notification: .announcement, argument: accessibilityLabel)

        if toast.duration > 0 {
            workItem?.cancel()

            let task = DispatchWorkItem {
                dismissToast()
            }

            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
        }
    }

    private func dismissToast() {
        withAnimation {
            self.toast = nil
        }
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - View Extension
extension View {
    func toast(toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Toast Manager (Singleton for Global Toasts)
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var currentToast: Toast?

    private init() {}

    func show(_ message: String, icon: String? = nil, duration: Double = 2.0) {
        // MASVS CODE-1: Use [weak self] for consistency in escaping closures
        DispatchQueue.main.async { [weak self] in
            self?.currentToast = Toast(message: message, duration: duration, icon: icon)
        }
    }

    func showSuccess(_ message: String) {
        show(message, icon: "✓", duration: 2.0)
    }

    func showError(_ message: String) {
        show(message, icon: "✗", duration: 3.0)
    }

    func showWarning(_ message: String) {
        show(message, icon: "⚠️", duration: 2.5)
    }

    func dismiss() {
        // MASVS CODE-1: Use [weak self] for consistency in escaping closures
        DispatchQueue.main.async { [weak self] in
            self?.currentToast = nil
        }
    }
}

// MARK: - Root View Modifier for Global Toasts
struct GlobalToastModifier: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .toast(toast: $toastManager.currentToast)
    }
}

extension View {
    func withGlobalToast() -> some View {
        modifier(GlobalToastModifier())
    }
}
