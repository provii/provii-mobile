// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Accessible error display components that satisfy WCAG 2.2 AA criteria 3.3.1 (Error Identification)
// and 3.3.3 (Error Suggestion). Provides error messages, form field errors, error banners,
// and input validation helpers with full VoiceOver announcement support.

// MARK: - Accessible Error Message

struct AccessibleErrorMessage: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let error: String
    let suggestion: String?
    let icon: String
    let onDismiss: (() -> Void)?

    init(
        error: String,
        suggestion: String? = nil,
        icon: String = "exclamationmark.triangle.fill",
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.suggestion = suggestion
        self.icon = icon
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(alignment: .top, spacing: manager.settings.increaseTouchTargets ? 16 : 12) {
            Image(systemName: icon)
                .font(manager.settings.useExtraLargeText ? AccessibleTypography.headline : AccessibleTypography.body)
                .foregroundColor(AccessibleColors.error)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(error)
                    .font(AccessibleTypography.body)
                    .fontWeight(manager.settings.useHighContrast ? .bold : .semibold)
                    .foregroundColor(manager.settings.useHighContrast ? .black : AccessibleColors.error)
                    .fixedSize(horizontal: false, vertical: true)

                if let suggestion = suggestion {
                    Text(suggestion)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let onDismiss = onDismiss {
                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(NSLocalizedString("accessibility.error.dismiss_button.label", comment: "Dismiss error button label"))
                .accessibilityHint(NSLocalizedString("accessibility.error.dismiss_button.hint", comment: "Dismiss error button hint"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(manager.settings.increaseTouchTargets ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.error.opacity(0.15))
                .overlay(
                    manager.settings.useHighContrast ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AccessibleColors.error, lineWidth: 2) : nil
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(.isStaticText)
    }

    private var accessibilityLabelText: String {
        if let suggestion = suggestion {
            return String(format: NSLocalizedString("accessibility.error.message_with_suggestion.label", comment: "Error with suggestion label"), error, suggestion)
        }
        return String(format: NSLocalizedString("error.template.simple", comment: "Simple error"), error)
    }
}

// MARK: - Form Field Error

struct FormFieldError {
    let field: String
    let error: String
    let suggestion: String?

    var accessibilityLabel: String {
        if let suggestion = suggestion {
            return String(format: NSLocalizedString("accessibility.error.field_with_suggestion.label", comment: "Field error with suggestion"), field, error, suggestion)
        }
        return String(format: NSLocalizedString("accessibility.error.field.label", comment: "Field error"), field, error)
    }
}

// MARK: - Error Container View

struct AccessibleErrorContainer: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let errors: [FormFieldError]
    let onDismiss: ((FormFieldError) -> Void)?

    var body: some View {
        if !errors.isEmpty {
            VStack(spacing: 12) {
                ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                    AccessibleErrorMessage(
                        error: error.error,
                        suggestion: error.suggestion,
                        onDismiss: onDismiss != nil ? { onDismiss?(error) } : nil
                    )
                    .accessibilityLabel(error.accessibilityLabel)
                }
            }
            .padding(.bottom, 8)
            .onAppear {
                announceErrors()
            }
        }
    }

    private func announceErrors() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let errorText = errors.map { $0.accessibilityLabel }.joined(separator: ". ")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .announcement, argument: errorText)
        }

        if manager.settings.hapticFeedback {
            HapticFeedback.notification(.error)
        }
    }
}

// MARK: - Error Banner

struct AccessibleErrorBanner: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?

    init(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        if isPresented {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AccessibleColors.error)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AccessibleTypography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(manager.settings.useHighContrast ? .black : AccessibleColors.error)

                        Text(message)
                            .font(AccessibleTypography.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button(action: { isPresented = false }, label: {
                        Image(systemName: "xmark")
                            .font(AccessibleTypography.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    })
                    .accessibilityLabel(NSLocalizedString("accessibility.error.banner_dismiss.label", comment: "Dismiss banner label"))
                }

                if let action = action, let actionLabel = actionLabel {
                    Button(action: action) {
                        Text(actionLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccessibleSecondaryButtonStyle())
                }
            }
            .padding(manager.settings.increaseTouchTargets ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: manager.settings.reduceTransparency ? .clear : .black.opacity(0.1),
                        radius: 8,
                        y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        manager.settings.useHighContrast ? AccessibleColors.error : Color(.separator),
                        lineWidth: manager.settings.useHighContrast ? 2 : 1
                    )
            )
            .padding(.horizontal)
            .transition(manager.settings.reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("accessibility.error.banner.label", comment: "Error banner label"), title, message))
            .onAppear {
                announceError()
            }
        }
    }

    private func announceError() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let announcement = String(format: NSLocalizedString("accessibility.error.announcement", comment: "Error announcement: %@ %@"), title, message)
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }

        if manager.settings.hapticFeedback {
            HapticFeedback.notification(.error)
        }
    }
}

// MARK: - Input Validation Helper

struct InputValidation {
    static func validateRequired(_ value: String, fieldName: String) -> FormFieldError? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FormFieldError(
                field: fieldName,
                error: String(format: NSLocalizedString("validation.field_required", comment: "%@ is required"), fieldName),
                suggestion: String(format: NSLocalizedString("validation.enter_value_for", comment: "Please enter a value for %@"), fieldName.lowercased())
            )
        }
        return nil
    }

    static func validateLength(
        _ value: String,
        fieldName: String,
        min: Int? = nil,
        max: Int? = nil
    ) -> FormFieldError? {
        let length = value.count

        if let min = min, length < min {
            return FormFieldError(
                field: fieldName,
                error: String(format: NSLocalizedString("validation.field_too_short", comment: "%@ is too short"), fieldName),
                suggestion: String(format: NSLocalizedString("validation.min_characters", comment: "Must be at least %d characters. Current length: %d"), min, length)
            )
        }

        if let max = max, length > max {
            return FormFieldError(
                field: fieldName,
                error: String(format: NSLocalizedString("validation.field_too_long", comment: "%@ is too long"), fieldName),
                suggestion: String(format: NSLocalizedString("validation.max_characters", comment: "Must be no more than %d characters. Current length: %d"), max, length)
            )
        }

        return nil
    }

    static func validateFormat(
        _ value: String,
        fieldName: String,
        pattern: String,
        formatDescription: String
    ) -> FormFieldError? {
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        if !predicate.evaluate(with: value) {
            return FormFieldError(
                field: fieldName,
                error: String(format: NSLocalizedString("validation.invalid_format", comment: "Invalid %@ format"), fieldName.lowercased()),
                suggestion: String(format: NSLocalizedString("validation.expected_format", comment: "Expected format: %@"), formatDescription)
            )
        }
        return nil
    }
}
