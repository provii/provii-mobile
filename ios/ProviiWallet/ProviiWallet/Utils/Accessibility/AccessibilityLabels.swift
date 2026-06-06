// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Centralised accessibility labels for consistent component identification across the app.
/// Satisfies WCAG 3.2.4 Level AA by ensuring components with the same functionality
/// are identified in the same way regardless of where they appear.
enum AccessibilityLabels {

    // MARK: - Navigation

    /// Standard back button label used throughout the app
    static let back = NSLocalizedString("accessibility.navigation.back", comment: "Back button")

    // MARK: - Voice Input

    /// Label for voice input button when not active
    static let voiceInputStart = NSLocalizedString("accessibility.voice_input.start", comment: "Start voice input button")

    /// Label for voice input button when active
    static let voiceInputStop = NSLocalizedString("accessibility.voice_input.stop", comment: "Stop voice input button")

    /// Label when voice input is listening
    static let voiceInputListening = NSLocalizedString("accessibility.voice_input.listening", comment: "Voice input listening state")

    /// Label when voice input is available
    static let voiceInputAvailable = NSLocalizedString("accessibility.voice_input.available", comment: "Voice input available state")
}
