// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

/// Centralised manager for accessibility settings across the Provii Wallet iOS app.
/// Monitors system accessibility changes (VoiceOver, Dynamic Type, Reduce Motion, Differentiate Without Colour)
/// and applies user-configured preferences including touch target sizing, haptic feedback, and contrast levels.
/// Persists settings through SettingsRepository and publishes changes for reactive UI updates.

@MainActor
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published var settings: AccessibilitySettings
    @Published var isVoiceOverRunning: Bool = false
    @Published var prefersCrossFadeTransitions: Bool = false
    @Published var systemDifferentiateWithoutColor: Bool = UIAccessibility.shouldDifferentiateWithoutColor

    private var cancellables = Set<AnyCancellable>()
    private let repository: SettingsRepository

    private init(repository: SettingsRepository = .shared) {
        self.repository = repository

        // Load saved settings
        self.settings = repository.load(AccessibilitySettings.self)
        #if DEBUG
        SecureLogger.shared.debug("AccessibilityManager loaded settings", redact: false)
        #endif

        // Monitor system accessibility changes
        setupSystemMonitoring()

        // Apply settings on initialisation
        applySettings()
    }

    // MARK: - System Monitoring

    private func setupSystemMonitoring() {
        // Monitor VoiceOver status
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { _ in
                self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
                self.handleVoiceOverChange()
            }
            .store(in: &cancellables)

        // Monitor Reduce Motion
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { _ in
                self.prefersCrossFadeTransitions = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        // Monitor Dynamic Type changes
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { _ in
                self.handleDynamicTypeChange()
            }
            .store(in: &cancellables)

        // Monitor Increase Contrast
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .sink { _ in
                self.systemAccessibilitySettingsChanged()
            }
            .store(in: &cancellables)

        // Monitor Differentiate Without Colour
        NotificationCenter.default.publisher(for: UIAccessibility.differentiateWithoutColorDidChangeNotification)
            .sink { _ in
                self.differentiateWithoutColorChanged()
            }
            .store(in: &cancellables)

        // Initial values
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        prefersCrossFadeTransitions = UIAccessibility.isReduceMotionEnabled
        systemDifferentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
    }

    // MARK: - Settings Management

    func updateSettings(_ newSettings: AccessibilitySettings) {
        settings = newSettings
        saveSettings()
        applySettings()
    }

    func updateSetting<T>(_ keyPath: WritableKeyPath<AccessibilitySettings, T>, value: T) {
        settings[keyPath: keyPath] = value
        saveSettings()
        applySettings()
    }

    private func saveSettings() {
        repository.save(settings)
        #if DEBUG
        SecureLogger.shared.debug("AccessibilityManager saved settings", redact: false)
        #endif
    }

    func resetToDefaults() {
        settings = AccessibilitySettings()
        saveSettings()
        applySettings()
    }

    /// Mark accessibility onboarding as complete
    func markOnboardingComplete() {
        settings.hasCompletedAccessibilityOnboarding = true
        saveSettings()
    }

    // MARK: - Apply Settings

    func applySettings() {
        // This triggers UI updates through @Published
        objectWillChange.send()

        // Apply haptic settings
        UIImpactFeedbackGenerator.isEnabled = settings.hapticFeedback
        UINotificationFeedbackGenerator.isEnabled = settings.hapticFeedback

        // Notify components that need to update
        NotificationCenter.default.post(name: .accessibilitySettingsChanged, object: nil)
    }

    // MARK: - Quick Setup

    func applyQuickSetup(_ profile: AccessibilityProfile) {
        switch profile {
        case .visionImpaired:
            settings.useExtraLargeText = true
            settings.useHighContrast = true
            settings.reduceTransparency = true
            settings.increaseTouchTargets = true
            settings.verboseDescriptions = true
            settings.hapticFeedback = true

        case .motorImpaired:
            settings.increaseTouchTargets = true
            settings.simplifiedGestures = true
            settings.confirmBeforeActions = true
            settings.extendedTimeouts = true

        case .cognitive:
            settings.simplifiedUI = true
            settings.showStepNumbers = true
            settings.verboseDescriptions = true
            settings.reduceMotion = true
            settings.confirmBeforeActions = true
            settings.extendedTimeouts = true

        case .elderly:
            settings.useExtraLargeText = true
            settings.increaseTouchTargets = true
            settings.simplifiedUI = true
            settings.reduceMotion = true
            settings.extendedTimeouts = true

        case .default:
            settings = AccessibilitySettings()
        }

        saveSettings()
        applySettings()
    }

    // MARK: - Helpers

    private func handleVoiceOverChange() {
        if isVoiceOverRunning && !settings.hasAcknowledgedVoiceOver {
            // First time VoiceOver detected
            settings.hasAcknowledgedVoiceOver = true
            settings.verboseDescriptions = true
            saveSettings()
        }
    }

    private func handleDynamicTypeChange() {
        let currentSize = UIApplication.shared.preferredContentSizeCategory

        // Auto-enable our extra large text setting if system is using accessibility sizes
        if currentSize.isAccessibilityCategory && !settings.useExtraLargeText {
            settings.useExtraLargeText = true
            saveSettings()
        }
    }

    private func systemAccessibilitySettingsChanged() {
        // Auto-enable high contrast when system setting is on
        if UIAccessibility.isDarkerSystemColorsEnabled && settings.contrastLevel == .standard {
            settings.contrastLevel = .high
            saveSettings()
        }
    }

    private func differentiateWithoutColorChanged() {
        systemDifferentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
    }

    // MARK: - Utility Methods

    func minimumTouchTargetSize() -> CGFloat {
        // Enhanced mode: 60pt (AAA+)
        if settings.enhancedTouchTargets {
            return 60
        }
        // Standard increased mode: 52pt (between standard and enhanced)
        if settings.increaseTouchTargets {
            return 52
        }
        // Standard: 44pt (Apple HIG minimum)
        return 44
    }

    func animationDuration(_ base: Double) -> Double {
        if settings.reduceMotion {
            return 0
        }
        return settings.extendedTimeouts ? base * 1.5 : base
    }

    func timeoutDuration(_ base: TimeInterval) -> TimeInterval {
        // AAA mode removes hard time limits; this helper just scales short-lived delays.
        switch settings.timeoutBehavior {
        case .none, .standard:
            return base
        case .extended:
            return base * 2
        }
    }

    func getTimeoutDuration(standard: TimeInterval = 30) -> TimeInterval? {
        // WCAG 2.2 AAA: 2.2.3 No Timing
        switch settings.timeoutBehavior {
        case .none:
            return nil  // No timeout
        case .standard:
            return standard
        case .extended:
            return standard * 2
        }
    }

    func shouldShowStepIndicator() -> Bool {
        return settings.showStepNumbers || settings.simplifiedUI
    }

    func getTextSize(for style: Font.TextStyle) -> CGFloat {
        let baseSize = getBaseSize(for: style)

        if settings.useExtraLargeText {
            return baseSize * 1.5
        } else if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            return baseSize * 1.3
        }

        return baseSize
    }

    private static let baseSizes: [Font.TextStyle: CGFloat] = [
        .largeTitle: 34, .title: 28, .title2: 22, .title3: 20,
        .headline: 17, .body: 17, .callout: 16, .subheadline: 15,
        .footnote: 13, .caption: 12, .caption2: 11
    ]

    private func getBaseSize(for style: Font.TextStyle) -> CGFloat {
        Self.baseSizes[style] ?? 17
    }
}

// MARK: - Supporting Types

struct AccessibilitySettings: SettingsSection {
    static let storageKey = "accessibility_settings"
    static let defaultValue = AccessibilitySettings()
    static let schemaVersion = SettingsVersion(major: 1, minor: 0, patch: 0)
    // WCAG 2.2 AAA: Contrast levels
    enum ContrastLevel: String, Codable, CaseIterable {
        case standard
        case high = "high_aa"
        case maximum = "maximum_aaa"

        var localizedName: String {
            switch self {
            case .standard:
                return NSLocalizedString("contrast_level_standard", comment: "Standard contrast level")
            case .high:
                return NSLocalizedString("contrast_level_high_aa", comment: "High contrast (AA) level")
            case .maximum:
                return NSLocalizedString("contrast_level_maximum_aaa", comment: "Maximum contrast (AAA) level")
            }
        }
    }

    // Vision
    var contrastLevel: ContrastLevel = .standard  // WCAG 2.2 AAA: 1.4.6
    var useHighContrast: Bool = false  // Legacy - migrated to contrastLevel
    var useExtraLargeText: Bool = false
    var reduceTransparency: Bool = false
    var colorBlindMode: ColorBlindMode = .none
    var useDyslexiaFont: Bool = false  // WCAG 2.2 AAA: Dyslexia friendly typography

    // WCAG 2.2 AAA: Advanced Typography (1.4.8)
    var lineSpacingMultiplier: CGFloat = 1.0        // Range: 1.0 - 2.0 (AAA requires 1.5x)
    var paragraphSpacingMultiplier: CGFloat = 1.0   // Range: 1.0 - 3.0 (AAA requires 2x)
    var letterSpacingMultiplier: CGFloat = 0.0      // Range: 0.0 - 0.2 (AAA requires 0.12em)

    enum TextWidth: String, Codable, CaseIterable {
        case full
        case comfortable
        case narrow

        var localizedName: String {
            switch self {
            case .full:
                return NSLocalizedString("text_width_full", comment: "Full width text")
            case .comfortable:
                return NSLocalizedString("text_width_comfortable", comment: "Comfortable width (80 chars)")
            case .narrow:
                return NSLocalizedString("text_width_narrow", comment: "Narrow width (60 chars)")
            }
        }
    }
    var textWidth: TextWidth = .full

    // Motor & Interaction
    var increaseTouchTargets: Bool = false
    var enhancedTouchTargets: Bool = false  // Extra large 60pt touch targets (enhanced mode)
    var reduceMotion: Bool = false

    // WCAG 2.2 AAA: 2.2.3 No Timing
    enum TimeoutBehavior: String, Codable, CaseIterable {
        case none
        case standard
        case extended

        var localizedName: String {
            switch self {
            case .none:
                return NSLocalizedString("timeout_none", comment: "No timeout (AAA)")
            case .standard:
                return NSLocalizedString("timeout_standard", comment: "Standard 30 second timeout")
            case .extended:
                return NSLocalizedString("timeout_extended", comment: "Extended 60 second timeout")
            }
        }
    }
    var timeoutBehavior: TimeoutBehavior = .none
    var extendedTimeouts: Bool = false  // Deprecated - migrated to timeoutBehaviour

    var simplifiedGestures: Bool = false
    var hapticFeedback: Bool = true

    // Sound Feedback
    var soundEnabled: Bool = true
    var soundPreset: SoundPreset = .provii
    var soundVolume: Int = 100  // 0-100

    // Cognitive
    var simplifiedUI: Bool = false
    var showStepNumbers: Bool = true
    var verboseDescriptions: Bool = false
    var confirmBeforeActions: Bool = false

    // WCAG 2.2 AAA: 3.1.5 Reading Level
    enum ReadingLevel: String, Codable, CaseIterable {
        case standard
        case simplified

        var localizedName: String {
            switch self {
            case .standard:
                return NSLocalizedString("reading_level_standard", comment: "Standard reading level")
            case .simplified:
                return NSLocalizedString("reading_level_simplified", comment: "Simplified reading level (Grade 7-9)")
            }
        }
    }
    var readingLevel: ReadingLevel = .standard

    // QR Scanning Alternatives
    var enableManualCodeEntry: Bool = false
    var enableVoiceInput: Bool = false

    // Onboarding
    var hasCompletedAccessibilityOnboarding: Bool = false
    var hasAcknowledgedVoiceOver: Bool = false

    enum ColorBlindMode: String, Codable, CaseIterable {
        case none
        case protanopia
        case deuteranopia
        case tritanopia
        case monochrome

        var localizedName: String {
            switch self {
            case .none:
                return NSLocalizedString("color_blind_mode_none", comment: "No colour blind mode")
            case .protanopia:
                return NSLocalizedString("color_blind_mode_protanopia", comment: "Protanopia (Red-Blind)")
            case .deuteranopia:
                return NSLocalizedString("color_blind_mode_deuteranopia", comment: "Deuteranopia (Green-Blind)")
            case .tritanopia:
                return NSLocalizedString("color_blind_mode_tritanopia", comment: "Tritanopia (Blue-Blind)")
            case .monochrome:
                return NSLocalizedString("color_blind_mode_monochrome", comment: "Monochrome")
            }
        }
    }
}

enum AccessibilityProfile {
    case visionImpaired
    case motorImpaired
    case cognitive
    case elderly
    case `default`

    var localizedName: String {
        switch self {
        case .visionImpaired:
            return NSLocalizedString("accessibility.profile.vision_impaired", comment: "")
        case .motorImpaired:
            return NSLocalizedString("accessibility.profile.motor_impaired", comment: "")
        case .cognitive:
            return NSLocalizedString("accessibility.profile.cognitive_impaired", comment: "")
        case .elderly:
            return NSLocalizedString("accessibility.profile.elderly", comment: "")
        case .default:
            return NSLocalizedString("accessibility.profile.default", comment: "")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let accessibilitySettingsChanged = Notification.Name("accessibilitySettingsChanged")
}

// MARK: - UIKit Extensions for Haptics

@MainActor
extension UIImpactFeedbackGenerator {
    static var isEnabled = true
}

@MainActor
extension UINotificationFeedbackGenerator {
    static var isEnabled = true

    func notificationOccurredIfEnabled(_ notificationType: UINotificationFeedbackGenerator.FeedbackType) {
        if UINotificationFeedbackGenerator.isEnabled {
            self.notificationOccurred(notificationType)
        }
    }
}
