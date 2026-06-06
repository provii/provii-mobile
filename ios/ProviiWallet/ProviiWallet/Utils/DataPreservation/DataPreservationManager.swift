// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI
import Combine

/// Data preservation manager satisfying WCAG 2.2 AAA criterion 2.2.6 (Timeouts).
/// Persists and restores form data via Keychain (never UserDefaults) so users do not
/// lose progress when sessions expire. Includes a timeout warning view and a view
/// modifier for automatic preserve/restore on appear/disappear.

@MainActor
class DataPreservationManager: ObservableObject {
    static let shared = DataPreservationManager()

    // SECURITY: Use Keychain instead of UserDefaults.
    // Preserved form data may contain DOB during credential issuance.
    // Matches Android's EncryptedSharedPreferences approach.
    private let keychainKey = "provii_preserved_form_data"

    private init() {}

    // MARK: - Data Preservation

    /// Saves data to Keychain preservation storage with a timestamp.
    /// Returns true on success, false if encoding or Keychain write fails.
    func preserve<T: Codable>(_ data: T, forKey key: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(DataWrapper(key: key, data: data, timestamp: Date()))

            var allPreserved = loadAllPreservedData()
            allPreserved[key] = encoded

            guard let allEncoded = try? JSONEncoder().encode(allPreserved) else {
                SecureLogger.shared.error("DataPreservationManager: failed to encode preservation dictionary for key \(key)")
                return false
            }
            do {
                try KeychainService.shared.save(key: keychainKey, data: allEncoded, requiresBiometric: false)
                return true
            } catch {
                SecureLogger.shared.error("DataPreservationManager: Keychain write failed for key \(key): \(error.localizedDescription)")
                return false
            }
        } catch {
            SecureLogger.shared.error("DataPreservationManager: failed to encode data for key \(key): \(error.localizedDescription)")
            return false
        }
    }

    func restore<T: Codable>(forKey key: String) -> T? {
        let allPreserved = loadAllPreservedData()

        guard let encodedData = allPreserved[key] else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(DataWrapper<T>.self, from: encodedData)

            // Check if data is not too old (24 hours)
            guard Date().timeIntervalSince(wrapper.timestamp) < 86400 else {
                // Data too old, clear it
                clear(forKey: key)
                return nil
            }

            return wrapper.data
        } catch {
            SecureLogger.shared.error("Failed to restore data for key \(key): \(error.localizedDescription)")
            return nil
        }
    }

    func clear(forKey key: String) {
        var allPreserved = loadAllPreservedData()
        allPreserved.removeValue(forKey: key)

        if let allEncoded = try? JSONEncoder().encode(allPreserved) {
            try? KeychainService.shared.save(key: keychainKey, data: allEncoded, requiresBiometric: false)
        }
    }

    func clearAll() {
        _ = KeychainService.shared.delete(key: keychainKey)
    }

    // MARK: - Helper Methods

    private func loadAllPreservedData() -> [String: Data] {
        guard let data = try? KeychainService.shared.getData(key: keychainKey, requireAuth: false),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return [:]
        }
        return decoded
    }

    // MARK: - Data Wrapper

    private struct DataWrapper<T: Codable>: Codable {
        let key: String
        let data: T
        let timestamp: Date
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    /// Automatically preserves and restores form data
    func preserveFormData<T: Codable>(
        _ data: Binding<T>,
        forKey key: String
    ) -> some View {
        self
            .onAppear {
                if let restored: T = DataPreservationManager.shared.restore(forKey: key) {
                    data.wrappedValue = restored
                }
            }
            .onDisappear {
                _ = DataPreservationManager.shared.preserve(data.wrappedValue, forKey: key)
            }
    }
}

// MARK: - Timeout Warning Component

struct TimeoutWarningView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let timeRemaining: Int
    let onSaveAndContinue: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(AccessibleColors.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.sessionExpiring.localized)
                        .font(AccessibleTypography.headline)
                        .foregroundColor(AccessibleColors.warning)

                    Text(LocalizedString.sessionExpiringSeconds.localized(timeRemaining))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                }
            }

            if manager.settings.verboseDescriptions {
                Text(LocalizedString.saveProgressPrompt.localized)
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: manager.settings.increaseTouchTargets ? 16 : 12) {
                Button(LocalizedString.discard.localized) {
                    HapticFeedback.notification(.warning)
                    onDiscard()
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())

                Button(LocalizedString.saveAndContinue.localized) {
                    HapticFeedback.selection()
                    onSaveAndContinue()
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
            }
        }
        .padding(manager.settings.increaseTouchTargets ? 20 : 16)
        .background(AccessibleColors.warning.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AccessibleColors.warning, lineWidth: 2)
        )
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.data_preservation.session_expiring_warning.label", comment: "Warning about session expiring with time remaining"), timeRemaining))
    }
}

// MARK: - Convenience Structures for Common Form Data

struct FormData: Codable {
    var fields: [String: String]

    init() {
        fields = [:]
    }

    subscript(key: String) -> String {
        get { fields[key] ?? "" }
        set { fields[key] = newValue }
    }
}

// MARK: - Timeout Observer Modifier

struct TimeoutObserverModifier: ViewModifier {
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @State private var showTimeoutWarning = false
    @State private var timeRemaining: Int = 0

    let onTimeout: () -> Void
    let onSaveProgress: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showTimeoutWarning {
                    TimeoutWarningView(
                        timeRemaining: timeRemaining,
                        onSaveAndContinue: {
                            showTimeoutWarning = false
                            onSaveProgress()
                        },
                        onDiscard: {
                            showTimeoutWarning = false
                            onTimeout()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                startTimeoutMonitoring()
            }
    }

    private func startTimeoutMonitoring() {
        guard let duration = accessibilityManager.getTimeoutDuration() else {
            // No timeout
            return
        }

        let warningTime = Int(duration) - 10

        Task {
            for i in (0..<Int(duration)).reversed() {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                timeRemaining = i

                if i == warningTime && i > 0 {
                    await MainActor.run {
                        showTimeoutWarning = true
                        UIAccessibility.post(notification: .announcement, argument: String(format: NSLocalizedString("accessibility.data_preservation.session_expiring_seconds", comment: "Session expiring announcement with seconds"), i))
                    }
                }

                if i == 0 {
                    await MainActor.run {
                        onTimeout()
                    }
                }
            }
        }
    }
}

extension View {
    func timeoutWarning(
        onTimeout: @escaping () -> Void,
        onSaveProgress: @escaping () -> Void
    ) -> some View {
        self.modifier(TimeoutObserverModifier(
            onTimeout: onTimeout,
            onSaveProgress: onSaveProgress
        ))
    }
}
