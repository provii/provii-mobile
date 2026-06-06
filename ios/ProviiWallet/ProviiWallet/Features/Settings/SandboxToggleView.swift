// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import UIKit
import Combine

/// Hidden sandbox mode toggle activated by tapping the settings header five times
/// within two seconds. Flips the environment between production and sandbox, then
/// forces an app restart so all API clients pick up the new base URL.
class SandboxToggleHandler: ObservableObject {
    @Published var tapCount: Int = 0
    private var resetTimer: Timer?
    private let requiredTaps = 5
    private let resetDelay: TimeInterval = 2.0
    private var toggled = false

    func onSettingsTap() {
        // Ignore taps after toggle has fired (app is restarting)
        guard !toggled else { return }

        // Cancel any existing timer
        resetTimer?.invalidate()

        // Increment tap count
        tapCount += 1

        switch tapCount {
        case requiredTaps:
            // Show developer message
            ToastManager.shared.showWarning(NSLocalizedString("settings.sandbox.developer_mode_unlocked", comment: "⚠️ You are now a developer!"))
            scheduleReset()

        case requiredTaps + 1:
            // Toggle sandbox mode
            toggled = true
            let isSandboxEnabled = EnvironmentManager.shared.isSandboxEnabled
            EnvironmentManager.shared.enableSandbox(!isSandboxEnabled)

            // Show result message
            let message = !isSandboxEnabled
                ? NSLocalizedString("settings.sandbox.mode_enabled", comment: "🔧 Sandbox Mode Enabled\nUsing test environment")
                : NSLocalizedString("settings.sandbox.mode_disabled", comment: "🔒 Production Mode Enabled\nUsing production environment")

            ToastManager.shared.show(message, duration: 3.0)

            // Reset counter
            tapCount = 0

            // Schedule app restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.restartApp()
            }

        case 3...4:
            // Show countdown
            let remaining = requiredTaps - tapCount
            let message = remaining == 1
                ? NSLocalizedString("settings.sandbox.one_step_away", comment: "You are 1 step away from developer mode")
                : String(format: NSLocalizedString("settings.sandbox.steps_away", comment: "You are %d steps away from developer mode"), remaining)

            ToastManager.shared.show(message, duration: 1.5)
            scheduleReset()

        default:
            // Early taps - no message
            scheduleReset()
        }
    }

    private func scheduleReset() {
        resetTimer = Timer.scheduledTimer(withTimeInterval: resetDelay, repeats: false) { [weak self] _ in
            self?.tapCount = 0
        }
    }

    /// MED-17: iOS does not allow programmatic app restart (App Store
    /// guidelines 2.5.1). The user must swipe-kill and relaunch. The alert
    /// copy explains this explicitly so there is no confusion.
    ///
    /// Runbook note: if users report the environment did not change, verify
    /// they fully terminated the app (swipe up from app switcher) rather
    /// than simply backgrounding it. A background-to-foreground transition
    /// does not re-initialise the URLSession base URL cache.
    private func restartApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {

            let alert = UIAlertController(
                title: NSLocalizedString("settings.sandbox.restart_required.title", comment: "Restart Required"),
                message: NSLocalizedString("settings.sandbox.restart_required.message_v2", comment: "The environment has been switched. To apply the change, you must fully close the app (swipe up from the app switcher) and reopen it. iOS does not allow apps to restart themselves."),
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: NSLocalizedString("settings.sandbox.restart_required.ok", comment: "OK"), style: .default) { _ in
                // User must manually restart the app for changes to take effect.
                // iOS prohibits programmatic exit (UIApplicationMain does not
                // expose a public restart API). Per App Store guidelines 2.5.1,
                // calling exit(0) risks rejection.
            })

            rootVC.present(alert, animated: true)
        }
    }
}
