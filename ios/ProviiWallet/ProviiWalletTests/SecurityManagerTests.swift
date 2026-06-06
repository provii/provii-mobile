// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Unit tests for SecurityManager orchestration logic: threat response routing,
/// DEBUG gate behaviour, isDeviceCompromised property, and shouldAllowOperation.

import XCTest
@testable import ProviiWallet

final class SecurityManagerTests: XCTestCase {

    private var manager: SecurityManager!

    override func setUp() {
        super.setUp()
        manager = SecurityManager.shared
    }

    // MARK: - responseFor(_:) routing

    func testResponseForJailbreakReturnsRestrict() {
        let response = manager.responseFor(.jailbreak)
        XCTAssertEqual(response, .restrict)
    }

    func testResponseForDebuggerReturnsTerminate() {
        let response = manager.responseFor(.debugger)
        XCTAssertEqual(response, .terminate)
    }

    func testResponseForFridaReturnsTerminate() {
        let response = manager.responseFor(.fridaDetected)
        XCTAssertEqual(response, .terminate)
    }

    func testResponseForIntegrityViolationReturnsTerminate() {
        let response = manager.responseFor(.integrityViolation)
        XCTAssertEqual(response, .terminate)
    }

    // MARK: - DEBUG gate behaviour

    /// In DEBUG builds, performSecurityChecks skips all detection checks due
    /// to the #if !DEBUG guard. This means detectedThreats is always empty and
    /// the method returns true (no threats).
    func testPerformSecurityChecksReturnsNoThreatsInDebug() {
        #if DEBUG
        let result = manager.performSecurityChecks(enforceTermination: false)
        XCTAssertTrue(result, "DEBUG builds should report no threats")
        XCTAssertTrue(manager.detectedThreats.isEmpty)
        #else
        // In release builds this test is not meaningful; skip assertion
        #endif
    }

    // MARK: - isDeviceCompromised property

    /// After a clean check in DEBUG mode, the device should not be considered compromised.
    func testIsDeviceCompromisedReturnsFalseAfterCleanCheck() {
        #if DEBUG
        _ = manager.performSecurityChecks(enforceTermination: false)
        XCTAssertFalse(manager.isDeviceCompromised)
        #else
        // Release builds may detect actual threats on the CI machine; skip
        #endif
    }

    // MARK: - shouldAllowOperation

    /// In DEBUG builds, shouldAllowOperation should return true since all
    /// checks are gated behind #if !DEBUG.
    func testShouldAllowOperationReturnsTrueInDebug() {
        #if DEBUG
        let allowed = manager.shouldAllowOperation()
        XCTAssertTrue(allowed)
        #else
        // Release builds may terminate; skip
        #endif
    }
}
