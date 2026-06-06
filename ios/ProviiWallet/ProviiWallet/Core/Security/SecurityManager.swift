// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Orchestrates all runtime security checks for the wallet app.
///
/// Coordinates jailbreak detection, debugger detection, Frida instrumentation
/// scanning, and app integrity verification. Called at startup from
/// `ProviiWalletApp.init` and re-checked before every sensitive operation
/// (credential access, signing, key export) via `shouldAllowOperation()`.

import Foundation

final class SecurityManager {
    static let shared = SecurityManager()

    enum SecurityThreat: Hashable {
        case jailbreak
        case debugger
        case fridaDetected
        case integrityViolation
    }

    /// Response to security threats
    enum ThreatResponse {
        case restrict  // Block sensitive operations (for jailbreak)
        case terminate // Exit app immediately (for debugger, Frida, integrity)
    }

    /// All reads and writes to `detectedThreats` are serialised through
    /// `threatLock` to prevent data races when security checks run on background
    /// threads while the UI reads `isDeviceCompromised` on the main thread.
    private var _detectedThreats: Set<SecurityThreat> = []
    private let threatLock = NSLock()

    private(set) var detectedThreats: Set<SecurityThreat> {
        get {
            threatLock.withLock { _detectedThreats }
        }
        set {
            threatLock.withLock { _detectedThreats = newValue }
        }
    }

    /// Whether startup checks have been executed at least once
    private var _startupChecksCompleted = false
    private(set) var startupChecksCompleted: Bool {
        get { threatLock.withLock { _startupChecksCompleted } }
        set { threatLock.withLock { _startupChecksCompleted = newValue } }
    }

    private init() {}

    // MARK: - Startup

    /// Perform all security checks at app startup and take appropriate action.
    /// This method should be called as early as possible in the app lifecycle
    /// (from ProviiWalletApp.init or similar). It runs the full check suite
    /// and terminates the process for critical threats.
    ///
    /// Call order:
    ///   1. Unconditional ptrace denial (before any detection)
    ///   2. Debugger detection
    ///   3. Frida detection
    ///   4. Jailbreak detection
    ///   5. Integrity verification
    @discardableResult
    func performStartupChecks() -> Bool {
        // Step 1: Unconditional ptrace denial. This must happen first so that
        // even if every detection check is bypassed, debugger attachment has
        // already been refused at the kernel level.
        DebuggerDetector.denyDebuggerAttachment()

        // Step 2: Run the full security check suite
        let result = performSecurityChecks(enforceTermination: true)
        startupChecksCompleted = true
        return result
    }

    // MARK: - Core Checks

    /// Perform security checks and respond to threats.
    /// - Parameter enforceTermination: If true, terminate on critical threats
    /// - Returns: true if no threats detected
    ///
    /// ADV-WM-005: Threats are accumulated into a local set first, then
    /// atomically swapped into `detectedThreats`. This eliminates the TOCTOU
    /// window where `isDeviceCompromised` could briefly return false between
    /// clearing the old set and populating the new one.
    func performSecurityChecks(enforceTermination: Bool = true) -> Bool {
        var newThreats = Set<SecurityThreat>()

        #if !DEBUG
        // Check for debugger (terminate immediately)
        if DebuggerDetector.isDebuggerAttached() {
            newThreats.insert(.debugger)
            logSecurityThreat("debugger")

            if enforceTermination {
                // MASVS-RESILIENCE-1: Terminate on debugger detection
                terminateApp(reason: "Debugger detected")
            }
        }

        // Check for Frida instrumentation (terminate immediately)
        if FridaDetector.isFridaDetected() {
            newThreats.insert(.fridaDetected)
            logSecurityThreat("frida instrumentation")

            if enforceTermination {
                terminateApp(reason: "Frida instrumentation detected")
            }
        }

        // Check for jailbreak (restrict sensitive operations)
        if JailbreakDetector.isJailbroken() {
            newThreats.insert(.jailbreak)
            logSecurityThreat("jailbreak")
            // Jailbreak: restrict credential operations but do not terminate.
            // The isDeviceCompromised property gates sensitive operations.
        }

        // Check integrity (terminate on violation)
        if !IntegrityChecker.verifyAppIntegrity() {
            newThreats.insert(.integrityViolation)
            logSecurityThreat("integrity violation")

            if enforceTermination {
                terminateApp(reason: "Integrity check failed")
            }
        }
        #endif

        // Atomic replacement: readers of detectedThreats never see a stale empty set
        detectedThreats = newThreats
        return newThreats.isEmpty
    }

    // MARK: - Public API for Credential Operations

    /// Whether the device is in a compromised state.
    /// Credential operations, key material access, and other sensitive flows
    /// MUST check this property before proceeding.
    var isDeviceCompromised: Bool {
        // If startup checks have not yet run, run them now (non-terminating
        // so the caller gets a boolean rather than an exit). Critical threats
        // like debugger and Frida will still terminate via performStartupChecks
        // if that was called first.
        if !startupChecksCompleted {
            _ = performSecurityChecks(enforceTermination: false)
        }
        return !detectedThreats.isEmpty
    }

    /// Gate for sensitive operations (credential access, signing, key export).
    /// Re-runs security checks to catch threats that appeared after startup
    /// (e.g. a debugger attached after launch). Returns false if any threat
    /// is detected; callers MUST refuse the operation when this returns false.
    func shouldAllowOperation() -> Bool {
        return performSecurityChecks(enforceTermination: true)
    }

    /// Get the appropriate response for a threat type
    func responseFor(_ threat: SecurityThreat) -> ThreatResponse {
        switch threat {
        case .jailbreak:
            return .restrict  // Block sensitive operations on jailbroken devices
        case .debugger, .fridaDetected, .integrityViolation:
            return .terminate  // Never allow debugging, instrumentation, or tampered apps
        }
    }

    // MARK: - Private

    /// Terminate the app due to security threat.
    ///
    /// Zeroises all in-memory secrets held by the Rust SDK, clears the
    /// clipboard, invalidates any active biometric context, then kills the
    /// process. In release builds `abort()` is used instead of `exit(1)`
    /// because abort generates SIGABRT which cannot be caught by a
    /// signal handler in the same process.
    ///
    /// SECURITY: No crash reporter SDK may install SIGABRT handlers that
    /// could intercept this termination and allow continued execution.
    private func terminateApp(reason: String) {
        // Log the termination reason (this will be captured by crash reporters)
        SecureLogger.shared.warning("App terminating: \(reason)", redact: false)

        // Zeroise all in-memory secret material in the Rust SDK
        WalletSDKBridge.emergencyZeroize()

        // Clear clipboard contents
        ClipboardManager.shared.clear()

        // Invalidate any active biometric authentication context
        BiometricService.shared.invalidateContext()

        // Use fatalError in debug to get stack trace, abort in release
        #if DEBUG
        fatalError("Security violation: \(reason)")
        #else
        // SECURITY: abort() sends SIGABRT which cannot be caught by a signal
        // handler in the same process. Preferred over exit(1) which can be
        // intercepted by atexit handlers or signal catchers.
        abort()
        #endif
    }

    private func logSecurityThreat(_ threat: String) {
        // Log security threats for monitoring.
        // In production, this could send to a secure logging service.
        #if DEBUG
        print("[SecurityManager] CRITICAL: Security threat detected: \(threat)")
        #endif
    }
}
