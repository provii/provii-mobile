// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import UIKit

/// Manages clipboard operations with automatic expiration for security.
///
/// Uses two complementary expiration mechanisms:
/// 1. **Primary**: `UIPasteboard.setItems(_:options:)` with `.expirationDate`.
///    This is enforced by the OS and survives process termination.
/// 2. **Secondary**: In-process `Timer` that clears the pasteboard if it has
///    not been modified by another app. This provides a shorter window when
///    the app is still alive but does not survive a process kill.
final class ClipboardManager {
    static let shared = ClipboardManager()

    /// Default clipboard expiration time in seconds.
    /// Sensitive data (credential IDs, proof URLs) uses `sensitiveExpirationSeconds` instead.
    private let expirationSeconds: TimeInterval = 60

    /// Expiration for sensitive data, enforced at the OS level.
    private let sensitiveExpirationSeconds: TimeInterval = 30

    /// Timer for secondary in-process clearing
    private var clearTimer: Timer?

    /// The change count when we last wrote to clipboard
    private var lastChangeCount: Int = 0

    private init() {}

    /// Copy text to clipboard with automatic expiration.
    /// - Parameters:
    ///   - text: The text to copy.
    ///   - expireAfter: Optional custom expiration time (defaults to 60 seconds).
    ///   - sensitive: When true, uses OS-level expiration (30 seconds) that
    ///     survives process kill. Defaults to false for backward compatibility.
    func copy(_ text: String, expireAfter: TimeInterval? = nil, sensitive: Bool = false) {
        // Cancel any existing timer
        clearTimer?.invalidate()

        let expiration: TimeInterval
        if sensitive {
            // For sensitive data, always use the shorter sensitive window
            expiration = sensitiveExpirationSeconds
        } else {
            expiration = expireAfter ?? expirationSeconds
        }

        // Primary mechanism: OS-level expiration via setItems options.
        // The system will automatically remove the item after the expiration
        // date, even if the app has been terminated.
        let expirationDate = Date().addingTimeInterval(expiration)
        let items: [[String: Any]] = [[UIPasteboard.typeAutomatic: text]]
        UIPasteboard.general.setItems(items, options: [
            .expirationDate: expirationDate,
            .localOnly: true
        ])
        lastChangeCount = UIPasteboard.general.changeCount

        // Secondary mechanism: in-process timer as a belt and braces fallback.
        // This clears earlier if the app is still running and the user has not
        // modified the clipboard from elsewhere.
        clearTimer = Timer.scheduledTimer(withTimeInterval: expiration, repeats: false) { [weak self] _ in
            self?.clearIfUnchanged()
        }

        #if DEBUG
        SecureLogger.shared.debug(
            "Clipboard set with \(Int(expiration))s expiration (OS-level, sensitive=\(sensitive))",
            redact: false
        )
        #endif
    }

    /// Clear clipboard if it hasn't been modified since we wrote to it
    private func clearIfUnchanged() {
        // Only clear if the clipboard hasn't been modified by another app
        if UIPasteboard.general.changeCount == lastChangeCount {
            // Use items = [] instead of string = "" for thorough clearing.
            // Setting string = "" leaves a single empty-string item on the pasteboard,
            // which can still be detected by other apps. Clearing items removes all
            // pasteboard content including non-string representations.
            UIPasteboard.general.items = []
            #if DEBUG
            SecureLogger.shared.debug("Clipboard cleared after expiration", redact: false)
            #endif
        }
        clearTimer = nil
    }

    /// Immediately clear the clipboard
    func clear() {
        clearTimer?.invalidate()
        clearTimer = nil
        // Clear all items, not just the string representation
        UIPasteboard.general.items = []
    }
}
