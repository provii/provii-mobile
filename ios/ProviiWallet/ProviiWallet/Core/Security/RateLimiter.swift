// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Rate limiter with lockout for authentication attempts.
/// Prevents brute-force attacks on PIN verification.
///
/// SECURITY: State is persisted to Keychain so that lockouts survive app force-quit.
/// In-memory dictionaries act as a write through cache for performance. Keychain is
/// the source of truth and is loaded on init, then written after every state change.
final class RateLimiter {
    static let shared = RateLimiter()

    private var attempts: [String: [TimeInterval]] = [:]
    private let maxAttempts: Int
    private let windowSeconds: TimeInterval
    private let lockoutSeconds: TimeInterval
    private var lockouts: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "app.provii.wallet.ratelimiter")

    /// Monotonic clock source. Uses ProcessInfo.systemUptime which is not
    /// affected by wall-clock adjustments (NTP, user changes, DST).
    private func monotonicNow() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Keychain Persistence

    private let attemptsKeychainKey = "ratelimiter_attempts"
    private let lockoutsKeychainKey = "ratelimiter_lockouts"

    /// Codable wrapper for persisting attempt timestamps per identifier
    private struct PersistedAttempts: Codable {
        /// Map of identifier to array of Unix timestamps (seconds since epoch)
        var entries: [String: [TimeInterval]]
    }

    /// Codable wrapper for persisting lockout start times per identifier
    private struct PersistedLockouts: Codable {
        /// Map of identifier to lockout start Unix timestamp (seconds since epoch)
        var entries: [String: TimeInterval]
    }

    init(maxAttempts: Int = 5, windowSeconds: TimeInterval = 300, lockoutSeconds: TimeInterval = 900) {
        self.maxAttempts = maxAttempts
        self.windowSeconds = windowSeconds
        self.lockoutSeconds = lockoutSeconds
        loadPersistedState()
    }

    // MARK: - Persistence Helpers

    /// Load persisted state from Keychain on init.
    ///
    /// Persisted timestamps are wall-clock (Unix epoch) because monotonic time
    /// resets on reboot. On load we convert them to monotonic offsets relative to
    /// the current boot by computing how far in the past each event was and
    /// subtracting that from the current monotonic time.
    private func loadPersistedState() {
        let wallNow = Date().timeIntervalSince1970
        let mono = monotonicNow()

        // Load attempts
        if let data = KeychainBridge.shared.retrieveSecure(
            key: attemptsKeychainKey,
            requireBiometrics: false
        ),
           let persisted = try? JSONDecoder().decode(PersistedAttempts.self, from: data) {
            let cutoffAge = windowSeconds

            for (identifier, timestamps) in persisted.entries {
                let monotonicTimestamps = timestamps.compactMap { wallTs -> TimeInterval? in
                    let age = wallNow - wallTs
                    guard age >= 0, age < cutoffAge else { return nil }
                    return mono - age
                }
                if !monotonicTimestamps.isEmpty {
                    attempts[identifier] = monotonicTimestamps
                }
            }
        }

        // Load lockouts
        if let data = KeychainBridge.shared.retrieveSecure(
            key: lockoutsKeychainKey,
            requireBiometrics: false
        ),
           let persisted = try? JSONDecoder().decode(PersistedLockouts.self, from: data) {
            for (identifier, wallTs) in persisted.entries {
                let age = wallNow - wallTs
                // Only restore lockouts that have not yet expired
                if age >= 0, age < lockoutSeconds {
                    lockouts[identifier] = mono - age
                }
            }
        }
    }

    /// Persist current attempts to Keychain. Must be called within queue.
    /// Converts monotonic timestamps to wall-clock (Unix epoch) for storage.
    private func persistAttempts() {
        let mono = monotonicNow()
        let wallNow = Date().timeIntervalSince1970

        var entries: [String: [TimeInterval]] = [:]
        for (identifier, monoTimestamps) in attempts {
            entries[identifier] = monoTimestamps.map { wallNow - (mono - $0) }
        }
        let persisted = PersistedAttempts(entries: entries)
        if let data = try? JSONEncoder().encode(persisted) {
            _ = KeychainBridge.shared.storeSecure(
                key: attemptsKeychainKey,
                data: data,
                useSecureEnclave: false,
                requireBiometrics: false
            )
        }
    }

    /// Persist current lockouts to Keychain. Must be called within queue.
    /// Converts monotonic timestamps to wall-clock (Unix epoch) for storage.
    private func persistLockouts() {
        let mono = monotonicNow()
        let wallNow = Date().timeIntervalSince1970

        var entries: [String: TimeInterval] = [:]
        for (identifier, monoTs) in lockouts {
            entries[identifier] = wallNow - (mono - monoTs)
        }
        let persisted = PersistedLockouts(entries: entries)
        if let data = try? JSONEncoder().encode(persisted) {
            _ = KeychainBridge.shared.storeSecure(
                key: lockoutsKeychainKey,
                data: data,
                useSecureEnclave: false,
                requireBiometrics: false
            )
        }
    }

    // MARK: - Public Interface

    /// Check if identifier is allowed to make an attempt
    func isAllowed(identifier: String) -> Bool {
        queue.sync {
            let now = monotonicNow()

            // Check if locked out
            if let lockoutTime = lockouts[identifier] {
                if (now - lockoutTime) < lockoutSeconds {
                    return false
                } else {
                    lockouts.removeValue(forKey: identifier)
                    persistLockouts()
                }
            }

            // Clean old attempts
            let cutoff = now - windowSeconds
            let before = attempts[identifier]?.count ?? 0
            attempts[identifier] = (attempts[identifier] ?? []).filter { $0 > cutoff }

            if (attempts[identifier]?.count ?? 0) != before {
                persistAttempts()
            }

            return (attempts[identifier]?.count ?? 0) < maxAttempts
        }
    }

    /// Record an authentication attempt
    func recordAttempt(identifier: String, success: Bool) {
        queue.sync {
            if !success {
                let now = monotonicNow()

                // Prune expired attempts before appending and counting.
                // Without this, stale entries from a previous window inflate the
                // count and can trigger a premature lockout.
                let cutoff = now - windowSeconds
                var currentAttempts = (attempts[identifier] ?? []).filter { $0 > cutoff }
                currentAttempts.append(now)
                attempts[identifier] = currentAttempts
                persistAttempts()

                if currentAttempts.count >= maxAttempts {
                    lockouts[identifier] = now
                    persistLockouts()
                }
            } else {
                // Clear on success
                attempts.removeValue(forKey: identifier)
                persistAttempts()
            }
        }
    }

    /// Get remaining attempts before lockout.
    /// Prunes expired attempts before counting so stale entries from a previous
    /// window do not inflate the reported count.
    func remainingAttempts(identifier: String) -> Int {
        queue.sync {
            let cutoff = monotonicNow() - windowSeconds
            let current = (attempts[identifier] ?? []).filter { $0 > cutoff }
            if current.count != (attempts[identifier]?.count ?? 0) {
                attempts[identifier] = current
                persistAttempts()
            }
            return max(0, maxAttempts - current.count)
        }
    }

    /// Get time remaining in lockout (nil if not locked out)
    func lockoutTimeRemaining(identifier: String) -> TimeInterval? {
        queue.sync {
            guard let lockoutTime = lockouts[identifier] else { return nil }
            let remaining = lockoutSeconds - (monotonicNow() - lockoutTime)
            return remaining > 0 ? remaining : nil
        }
    }

    /// Reset rate limiting for an identifier (use with caution)
    func reset(identifier: String) {
        queue.sync {
            attempts.removeValue(forKey: identifier)
            lockouts.removeValue(forKey: identifier)
            persistAttempts()
            persistLockouts()
        }
    }
}

/// Error types for rate limiting
enum RateLimitError: LocalizedError {
    case rateLimited(remainingSeconds: TimeInterval)
    case locked(remainingSeconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .rateLimited(let seconds):
            let minutes = Int(ceil(seconds / 60))
            return "Too many attempts. Please wait \(minutes) minute(s)."
        case .locked(let seconds):
            let minutes = Int(ceil(seconds / 60))
            return "Account locked. Please wait \(minutes) minute(s)."
        }
    }
}
