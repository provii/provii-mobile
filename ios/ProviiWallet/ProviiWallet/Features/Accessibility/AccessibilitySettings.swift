// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Extensions to AccessibilitySettings providing feature counting, preset generation, context-aware helpers,
// VoiceOver announcement utilities, and haptic feedback wrappers. The main AccessibilitySettings struct
// is defined in AccessibilityManager.swift.

// MARK: - Accessibility Feature Count Extension

extension AccessibilitySettings {
    /// Returns the count of currently active accessibility features
    var activeFeatureCount: Int {
        var count = 0

        // Vision features
        if useHighContrast { count += 1 }
        if useExtraLargeText { count += 1 }
        if reduceTransparency { count += 1 }
        if colorBlindMode != .none { count += 1 }

        // Motor & Interaction features
        if increaseTouchTargets { count += 1 }
        if reduceMotion { count += 1 }
        if timeoutBehavior != .none { count += 1 }
        if simplifiedGestures { count += 1 }

        // Cognitive features
        if simplifiedUI { count += 1 }
        if verboseDescriptions { count += 1 }
        if confirmBeforeActions { count += 1 }

        // Alternative input features
        if enableManualCodeEntry { count += 1 }
        if enableVoiceInput { count += 1 }

        return count
    }

    /// Returns a human-readable summary of active features
    var activeFeaturesSummary: String {
        var features: [String] = []

        if useExtraLargeText { features.append(LocalizedString.largeText.localized) }
        if useHighContrast { features.append(LocalizedString.highContrast.localized) }
        if reduceMotion { features.append(LocalizedString.reduceMotion.localized) }
        if increaseTouchTargets { features.append(LocalizedString.largerButtons.localized) }
        if simplifiedUI { features.append(LocalizedString.simplifiedInterface.localized) }
        if enableVoiceInput { features.append(LocalizedString.voiceControl.localized) }
        if enableManualCodeEntry { features.append(LocalizedString.manualEntry.localized) }

        guard !features.isEmpty else {
            return LocalizedString.noAccessibilityFeaturesActive.localized
        }

        return features.joined(separator: ", ")
    }

    /// Checks if any visual accessibility features are active
    var hasVisualAccessibilityEnabled: Bool {
        useHighContrast || useExtraLargeText || reduceTransparency || colorBlindMode != .none
    }

    /// Checks if any motor accessibility features are active
    var hasMotorAccessibilityEnabled: Bool {
        increaseTouchTargets || timeoutBehavior != .none || simplifiedGestures
    }

    /// Checks if any cognitive accessibility features are active
    var hasCognitiveAccessibilityEnabled: Bool {
        simplifiedUI || verboseDescriptions || confirmBeforeActions || showStepNumbers
    }
}

// MARK: - Accessibility Presets

extension AccessibilitySettings {
    /// Quick setup presets for common accessibility needs
    static func preset(for profile: AccessibilityProfile) -> AccessibilitySettings {
        var settings = AccessibilitySettings()

        switch profile {
        case .visionImpaired:
            settings.useExtraLargeText = true
            settings.useHighContrast = true
            settings.reduceTransparency = true
            settings.increaseTouchTargets = true
            settings.verboseDescriptions = true
            settings.hapticFeedback = true
            settings.enableVoiceInput = true

        case .motorImpaired:
            settings.increaseTouchTargets = true
            settings.simplifiedGestures = true
            settings.confirmBeforeActions = true
            settings.enableManualCodeEntry = true
            settings.timeoutBehavior = .extended

        case .cognitive:
            settings.simplifiedUI = true
            settings.showStepNumbers = true
            settings.verboseDescriptions = true
            settings.reduceMotion = true
            settings.confirmBeforeActions = true
            settings.timeoutBehavior = .extended

        case .elderly:
            settings.useExtraLargeText = true
            settings.increaseTouchTargets = true
            settings.simplifiedUI = true
            settings.reduceMotion = true
            settings.showStepNumbers = true
            settings.timeoutBehavior = .extended

        case .default:
            // Return default settings
            break
        }

        return settings
    }
}

// MARK: - Accessibility Context

/// Provides context-aware accessibility information
struct AccessibilityContext {
    let settings: AccessibilitySettings
    let isVoiceOverRunning: Bool
    let preferredContentSize: UIContentSizeCategory

    init(settings: AccessibilitySettings? = nil,
         isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning,
         preferredContentSize: UIContentSizeCategory = UIApplication.shared.preferredContentSizeCategory) {
        self.settings = settings ?? AccessibilitySettings()
        self.isVoiceOverRunning = isVoiceOverRunning
        self.preferredContentSize = preferredContentSize
    }

    @MainActor
    static func current() -> AccessibilityContext {
        return AccessibilityContext(
            settings: AccessibilityManager.shared.settings,
            isVoiceOverRunning: UIAccessibility.isVoiceOverRunning,
            preferredContentSize: UIApplication.shared.preferredContentSizeCategory
        )
    }

    /// Determines if the app should use the most accessible mode
    var shouldUseMaximumAccessibility: Bool {
        isVoiceOverRunning ||
        preferredContentSize.isAccessibilityCategory ||
        settings.activeFeatureCount >= 5
    }

    /// Gets the appropriate animation duration
    func animationDuration(base: Double = 0.3) -> Double {
        if settings.reduceMotion { return 0 }
        if settings.timeoutBehavior == .extended { return base * 1.5 }
        return base
    }

    /// Gets the appropriate timeout duration
    func timeoutDuration(base: TimeInterval = 30) -> TimeInterval {
        settings.timeoutBehavior == .extended ? base * 2 : base
    }
}

// MARK: - Accessibility Announcement Helper

struct AccessibilityAnnouncement {
    /// Posts an announcement to VoiceOver if running
    static func announce(_ message: String, delay: Double = 0.1) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Posts a screen change notification
    static func announceScreenChange(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .screenChanged, argument: message)
        }
    }

    /// Posts a layout change notification
    static func announceLayoutChange(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        UIAccessibility.post(notification: .layoutChanged, argument: message)
    }
}

// MARK: - Haptic Feedback Helper

struct HapticFeedback {
    /// Provides haptic feedback if enabled in settings
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard AccessibilityManager.shared.settings.hapticFeedback else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Provides notification haptic feedback if enabled
    @MainActor
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AccessibilityManager.shared.settings.hapticFeedback else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Provides selection haptic feedback if enabled
    @MainActor
    static func selection() {
        guard AccessibilityManager.shared.settings.hapticFeedback else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - Accessibility Testing Helpers (Debug Only)

#if DEBUG
extension AccessibilitySettings {
    /// Creates settings for testing specific scenarios
    static var testingHighContrast: AccessibilitySettings {
        var settings = AccessibilitySettings()
        settings.useHighContrast = true
        settings.useExtraLargeText = true
        return settings
    }

    static var testingVoiceOver: AccessibilitySettings {
        var settings = AccessibilitySettings()
        settings.verboseDescriptions = true
        settings.showStepNumbers = true
        settings.enableVoiceInput = true
        return settings
    }

    static var testingSimplified: AccessibilitySettings {
        var settings = AccessibilitySettings()
        settings.simplifiedUI = true
        settings.reduceMotion = true
        settings.increaseTouchTargets = true
        return settings
    }
}
#endif
