// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Centralised accessibility primitives for the Provii Wallet iOS app. Provides a
// dynamic typography system (AccessibleTypography), colour palette with colour blind
// and high contrast variants (AccessibleColors), accessible button and toggle styles,
// a manual QR code entry alternative, and view modifiers for WCAG 2.2 AA/AAA compliance.

// MARK: - Accessible Typography

@MainActor
struct AccessibleTypography {
    // AccessibilityManager.shared is accessed directly rather than via @ObservedObject.
    // @ObservedObject on a static property of a non-View struct has no effect because
    // there is no SwiftUI view lifecycle to observe changes. The manager is an
    // ObservableObject that publishes to views that hold it via @ObservedObject or
    // @StateObject at the view level.
    private static var manager: AccessibilityManager { AccessibilityManager.shared }

    // Get the appropriate font name based on dyslexia font setting
    private static func fontName(weight: Font.Weight = .regular) -> String {
        guard manager.settings.useDyslexiaFont else {
            return ".AppleSystemUIFont"
        }

        // OpenDyslexic font names as they appear in the system
        switch weight {
        case .bold:
            return "OpenDyslexic-Bold"
        case .semibold, .medium:
            return "OpenDyslexic-Bold"
        default:
            return "OpenDyslexic-Regular"
        }
    }

    // Dynamic font creation that respects accessibility settings
    static func font(for style: Font.TextStyle) -> Font {
        let baseFont: Font

        if manager.settings.useDyslexiaFont {
            // Use OpenDyslexic font with custom sizes
            if manager.settings.useExtraLargeText {
                return .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 20)).weight(.medium)
            }
            return .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 17))
        } else {
            baseFont = Font.system(style)

            if manager.settings.useExtraLargeText {
                return baseFont.weight(.medium)
            }

            return baseFont
        }
    }

    // Static fonts with accessibility support
    static var largeTitle: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 51)) :
                .system(size: 51, weight: .bold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 34)) :
            .largeTitle
    }

    static var title: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 42)) :
                .system(size: 42, weight: .bold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 28)) :
            .title
    }

    static var title2: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 33)) :
                .system(size: 33, weight: .semibold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 22)) :
            .title2
    }

    static var title3: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 30)) :
                .system(size: 30, weight: .semibold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 20)) :
            .title3
    }

    static var headline: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 26)) :
                .system(size: 26, weight: .semibold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 17)) :
            .headline
    }

    static var headlineLarge: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 30)) :
                .system(size: 30, weight: .semibold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 20)) :
            .system(size: 20, weight: .semibold)
    }

    static var headlineMedium: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 28)) :
                .system(size: 28, weight: .semibold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 18)) :
            .system(size: 18, weight: .semibold)
    }

    static var body: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 26)) :
                .system(size: 26, weight: .regular)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 17)) :
            .body
    }

    static var bodyBold: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 26)) :
                .system(size: 26, weight: .bold)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Bold", size: UIFontMetrics.default.scaledValue(for: 17)) :
            .system(size: 17, weight: .bold)
    }

    static var callout: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 24)) :
                .system(size: 24, weight: .regular)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 16)) :
            .callout
    }

    static var subheadline: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 23)) :
                .system(size: 23, weight: .regular)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 15)) :
            .subheadline
    }

    static var footnote: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 20)) :
                .system(size: 20, weight: .regular)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 13)) :
            .footnote
    }

    static var caption: Font {
        if manager.settings.useExtraLargeText {
            return manager.settings.useDyslexiaFont ?
                .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 18)) :
                .system(size: 18, weight: .regular)
        }
        return manager.settings.useDyslexiaFont ?
            .custom("OpenDyslexic-Regular", size: UIFontMetrics.default.scaledValue(for: 12)) :
            .caption
    }
}

// MARK: - Accessible Toggle Style

struct AccessibleToggleStyle: ToggleStyle {
    @ObservedObject private var manager = AccessibilityManager.shared

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            // WCAG 1.4.11: Non-text contrast requires 3:1 minimum
            // Using Color(white: 0.5) for off-state provides ~4.5:1 contrast on white
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? AccessibleColors.success : Color(white: 0.5))
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(3)
                        .offset(x: configuration.isOn ? 11 : -11)
                        .animation(manager.settings.reduceMotion ? nil : .easeInOut(duration: 0.2), value: configuration.isOn)
                        .overlay(
                            Circle()
                                // WCAG 1.4.11: Border needs 3:1 contrast
                                .stroke(Color.black.opacity(0.4), lineWidth: 1)
                                .padding(3)
                        )
                )
                .overlay(
                    manager.settings.useHighContrast ?
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 3) :
                    RoundedRectangle(cornerRadius: 16)
                        // WCAG 1.4.11: Outer border needs 3:1 contrast
                        .stroke(Color(white: 0.5), lineWidth: 2)
                )
                .accessibilityAddTraits(.isButton)
                .onTapGesture {
                    configuration.isOn.toggle()
                    if manager.settings.hapticFeedback {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                    // WCAG 4.1.2: Announce state change to assistive technologies
                    let announcement = configuration.isOn ?
                        NSLocalizedString("accessibility.toggle.enabled", comment: "Enabled") :
                        NSLocalizedString("accessibility.toggle.disabled", comment: "Disabled")
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }
        }
    }
}

// MARK: - Accessible Button Styles

struct AccessiblePrimaryButtonStyle: ButtonStyle {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(manager.settings.useExtraLargeText ? .title3 : .body)
            .fontWeight(.semibold)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background(background)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(manager.settings.reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }

    private var foregroundColor: Color {
        if manager.settings.useHighContrast {
            return .black
        }
        return .white
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(backgroundColor)
            .overlay(
                manager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black, lineWidth: 3) : nil
            )
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return Color.gray600  // 7.35:1 contrast on white (WCAG AAA compliant)
        }
        if manager.settings.useHighContrast {
            return Color.yellow
        }
        return AccessibleColors.primary
    }

    private var horizontalPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 32 : 24
    }

    private var verticalPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 20 : 14
    }

    private var minHeight: CGFloat {
        manager.minimumTouchTargetSize()
    }

    private var cornerRadius: CGFloat {
        manager.settings.increaseTouchTargets ? 12 : 8
    }
}

struct AccessibleSecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(manager.settings.useExtraLargeText ? .title3 : .body)
            .fontWeight(.medium)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background(background)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(manager.settings.reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return Color.gray600  // 7.35:1 contrast on white (WCAG AAA compliant)
        }
        if manager.settings.useHighContrast {
            return .black
        }
        return AccessibleColors.primary
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(strokeColor, lineWidth: lineWidth)
            .background(
                manager.settings.reduceTransparency ?
                Color.white : Color.clear
            )
    }

    private var strokeColor: Color {
        if !isEnabled {
            return Color.gray600  // 7.35:1 contrast on white (WCAG AAA compliant)
        }
        if manager.settings.useHighContrast {
            return .black
        }
        return AccessibleColors.primary
    }

    private var lineWidth: CGFloat {
        manager.settings.useHighContrast ? 4 : 3
    }

    private var horizontalPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 32 : 24
    }

    private var verticalPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 20 : 14
    }

    private var minHeight: CGFloat {
        manager.minimumTouchTargetSize()
    }

    private var cornerRadius: CGFloat {
        manager.settings.increaseTouchTargets ? 12 : 8
    }
}

// MARK: - Accessible Colours

@MainActor
struct AccessibleColors {
    // Direct access instead of @ObservedObject on a static non-View struct property.
    private static var manager: AccessibilityManager { AccessibilityManager.shared }

    // WCAG 2.2 AAA: 7:1 contrast ratio colours
    struct AAA {
        static let text = Color.black                    // 21:1 on white
        static let textSecondary = Color(hex: 0x383838)  // 10:1 on white
        static let primary = Color(hex: 0x0A3D62)        // 8.5:1 on white
        static let success = Color(hex: 0x006400)        // 7.5:1 on white (dark green)
        static let error = Color(hex: 0x8B0000)          // 8.0:1 on white (dark red)
        static let warning = Color(hex: 0x8B6500)        // 7.0:1 on white (dark yellow)
    }

    static var primary: Color {
        // Check contrast level first (AAA feature)
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.primary
        case .high:
            return manager.settings.useHighContrast ? .black : Color(hex: 0x1565C0)
        case .standard:
            break
        }

        // Legacy useHighContrast support
        if manager.settings.useHighContrast {
            return .black
        }

        switch manager.settings.colorBlindMode {
        case .protanopia, .deuteranopia:
            return Color(hex: 0x0066CC) // Blue instead of green/red
        case .tritanopia:
            return Color(hex: 0xCC6600) // Orange instead of blue
        case .monochrome:
            return .black
        case .none:
            return .proviiPrimary
        }
    }

    static var secondary: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.textSecondary
        case .high, .standard:
            break
        }

        if manager.settings.useHighContrast {
            return Color.gray700  // 11.49:1 contrast on white (WCAG AAA compliant)
        }
        return .proviiSecondary
    }

    static var success: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.success
        case .high, .standard:
            break
        }

        if manager.settings.useHighContrast {
            return .black
        }

        switch manager.settings.colorBlindMode {
        case .protanopia, .deuteranopia:
            return Color(hex: 0x0066CC) // Blue
        case .tritanopia:
            return Color(hex: 0x009900) // Green
        case .monochrome:
            return .black
        case .none:
            return .green
        }
    }

    static var error: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.error
        case .high, .standard:
            break
        }

        if manager.settings.useHighContrast {
            return .black
        }

        switch manager.settings.colorBlindMode {
        case .protanopia:
            return Color(hex: 0xFF6600) // Orange
        case .deuteranopia:
            return Color(hex: 0xFF9900) // Light orange
        case .tritanopia:
            return Color(hex: 0xCC0000) // Dark red
        case .monochrome:
            return .black
        case .none:
            return .red
        }
    }

    static var warning: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.warning
        case .high, .standard:
            break
        }

        if manager.settings.useHighContrast {
            return .black
        }

        switch manager.settings.colorBlindMode {
        case .protanopia, .deuteranopia:
            return Color(hex: 0xFFCC00) // Yellow
        case .tritanopia:
            return Color(hex: 0xFF6600) // Orange
        case .monochrome:
            return .gray
        case .none:
            return .orange
        }
    }

    static var background: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return .white // Pure white for maximum contrast
        case .high, .standard:
            break
        }

        if manager.settings.useHighContrast {
            return .white
        }
        return Color.proviiBackground
    }

    static var cardBackground: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return .white // Pure white for maximum contrast
        case .high, .standard:
            break
        }

        if manager.settings.useHighContrast {
            return .white
        }
        if manager.settings.reduceTransparency {
            return Color.gray.opacity(0.05)
        }
        return Color.proviiSurface
    }

    static var text: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.text
        case .high:
            return manager.settings.useHighContrast ? .black : Color(hex: 0x212121)
        case .standard:
            break
        }

        if manager.settings.useHighContrast {
            return .black
        }

        return Color.proviiOnSurface
    }

    static var secondaryText: Color {
        switch manager.settings.contrastLevel {
        case .maximum:
            return AAA.textSecondary
        case .high:
            return manager.settings.useHighContrast ? Color(hex: 0x383838) : Color(hex: 0x616161)
        case .standard:
            break
        }

        if manager.settings.useHighContrast {
            return Color(hex: 0x424242)
        }

        return Color.gray600  // 7.35:1 contrast on white (WCAG AAA compliant)
    }
}

// MARK: - Accessible QR Scanner Alternative

struct AccessibleQRInputView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @State private var manualCode = ""
    @State private var isListening = false
    let onCodeSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            if manager.settings.enableManualCodeEntry {
                manualEntrySection
            }

            if manager.settings.enableVoiceInput {
                voiceInputSection
            }
        }
        .padding()
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("accessibility.manual_code_entry", comment: "Manual Code Entry"))
                .font(AccessibleTypography.headline)
                .accessibilityAddTraits(.isHeader)

            Text(NSLocalizedString("accessibility.type_code_shown", comment: "Type the code shown on screen"))
                .font(AccessibleTypography.caption)
                .foregroundColor(AccessibleColors.secondaryText)

            HStack {
                TextField(NSLocalizedString("accessibility.enter_code", comment: "Enter code"), text: $manualCode)
                    .font(AccessibleTypography.body)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.oneTimeCode)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.allCharacters)
                    .accessibilityLabel(NSLocalizedString("accessibility.code_entry_field", comment: "Code entry field"))

                Button(NSLocalizedString("accessibility.submit", comment: "Submit")) {
                    if !manualCode.isEmpty {
                        onCodeSubmit(manualCode)
                        provideHapticFeedback()
                    }
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
                .disabled(manualCode.isEmpty)
            }
        }
    }

    private var voiceInputSection: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("accessibility.voice_input", comment: "Voice Input"))
                .font(AccessibleTypography.headline)
                .accessibilityAddTraits(.isHeader)

            Button(action: toggleVoiceInput) {
                HStack {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.title2)
                    Text(isListening ? NSLocalizedString("accessibility.listening", comment: "Listening...") : NSLocalizedString("accessibility.speak_code", comment: "Speak Code"))
                }
            }
            .buttonStyle(AccessibleSecondaryButtonStyle())
            .accessibilityLabel(isListening ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
        }
    }

    private func toggleVoiceInput() {
        isListening.toggle()
        provideHapticFeedback()
        // Voice input implementation would go here
    }

    private func provideHapticFeedback() {
        if manager.settings.hapticFeedback {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
}

// MARK: - Accessible Loading View

struct AccessibleLoadingView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let message: String
    let progress: Double?

    init(message: String, progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    var body: some View {
        VStack(spacing: 20) {
            if manager.settings.reduceMotion {
                // Static loading indicator for reduced motion
                Image(systemName: "clock.fill")
                    .font(.largeTitle)
                    .foregroundColor(AccessibleColors.primary)
            } else {
                ProgressView()
                    .scaleEffect(manager.settings.useExtraLargeText ? 2 : 1.5)
            }

            Text(message)
                .font(AccessibleTypography.body)
                .multilineTextAlignment(.center)

            if let progress = progress {
                ProgressView(value: progress)
                    .frame(width: 200)
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.loading.percent_complete", comment: "%d%% complete"), Int(progress * 100)))
            }

            if manager.settings.verboseDescriptions {
                Text(NSLocalizedString("accessibility.please_wait_process_request", comment: "Please wait while we process your request"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(AccessibleColors.cardBackground)
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). \(progress.map { String(format: NSLocalizedString("accessibility.loading.percent_complete", comment: "%d%% complete"), Int($0 * 100)) } ?? NSLocalizedString("accessibility.loading.generic", comment: "Loading"))")
        .accessibilityValue(progress.map { String(format: "%d%%", Int($0 * 100)) } ?? NSLocalizedString("accessibility.loading.in_progress", comment: "In progress"))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - View Extensions

extension View {
    func accessibleStyle() -> some View {
        self.modifier(AccessibilityModifier())
    }

    func accessibleCard() -> some View {
        self.modifier(AccessibleCardModifier())
    }

    func accessibleAnimation<V: Equatable>(_ value: V) -> some View {
        self.modifier(AccessibleAnimationModifier(value: value))
    }

    // WCAG 2.2 AAA: 1.4.8 Advanced Typography
    func accessibleText(baseSize: CGFloat = 17) -> some View {
        self.modifier(AccessibleTextModifier(baseSize: baseSize))
    }
}

// MARK: - View Modifiers

struct AccessibilityModifier: ViewModifier {
    @ObservedObject private var manager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(
                manager.settings.useExtraLargeText ?
                    .xxxLarge...DynamicTypeSize.accessibility5 :
                    .small...DynamicTypeSize.accessibility5
            )
    }
}

struct AccessibleCardModifier: ViewModifier {
    @ObservedObject private var manager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .padding(manager.settings.increaseTouchTargets ? 20 : 16)
            .background(AccessibleColors.cardBackground)
            .cornerRadius(manager.settings.increaseTouchTargets ? 16 : 12)
            .overlay(
                manager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: manager.settings.increaseTouchTargets ? 16 : 12)
                    .stroke(Color.black, lineWidth: 3) : nil
            )
    }
}

struct AccessibleAnimationModifier<V: Equatable>: ViewModifier {
    @ObservedObject private var manager = AccessibilityManager.shared
    let value: V

    func body(content: Content) -> some View {
        if manager.settings.reduceMotion {
            content
        } else {
            content
                .animation(.easeInOut(duration: manager.animationDuration(0.3)), value: value)
        }
    }
}

// WCAG 2.2 AAA: 1.4.8 Advanced Typography Controls
struct AccessibleTextModifier: ViewModifier {
    @ObservedObject private var manager = AccessibilityManager.shared
    let baseSize: CGFloat

    func body(content: Content) -> some View {
        content
            .lineSpacing(baseSize * manager.settings.lineSpacingMultiplier * 0.5)
            .tracking(baseSize * manager.settings.letterSpacingMultiplier)
            .padding(.bottom, baseSize * manager.settings.paragraphSpacingMultiplier * 0.5)
            .frame(maxWidth: textMaxWidth)
    }

    private var textMaxWidth: CGFloat? {
        switch manager.settings.textWidth {
        case .full:
            return nil
        case .comfortable:
            return 600  // ~80 characters at standard text size
        case .narrow:
            return 450  // ~60 characters at standard text size
        }
    }
}
