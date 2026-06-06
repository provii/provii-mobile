// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Combine
import Foundation
import UIKit

#if canImport(YubiKit)
import YubiKit

/**
 * YubiKey manager for iOS
 * Handles HMAC-SHA1 challenge-response authentication using YubiKey 5Ci (Lightning/NFC)
 * 
 * Requirements:
 * - Add YubiKit to your project via CocoaPods: pod 'YubiKit', '~> 4.0'
 * - Add NFCReaderUsageDescription to Info.plist for NFC support
 * - Add com.apple.external-accessory.wireless-configuration entitlement for Lightning
 */
@MainActor
class YubikeyManager: ObservableObject {
    static let shared = YubikeyManager()

    // MARK: - Constants

    private let hmacChallengeSize = 64
    private let challengeResponseSlot = OTPSlot.two

    // MARK: - Published Properties

    @Published private(set) var isYubikeyConnected = false
    @Published private(set) var connectionType: ConnectionType = .none

    // MARK: - Private Properties

    private var currentConnection: YKFConnectionProtocol?

    // MARK: - Types

    enum ConnectionType {
        case none
        case lightning
        case nfc
        case usbC
    }

    enum YubikeyError: LocalizedError {
        case notConnected
        case challengeFailed
        case timeout
        case slotNotConfigured
        case touchTimeout
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return LocalizedString.errorYubikeyNotConnected.localized
            case .challengeFailed:
                return LocalizedString.errorYubikeyChallengeFailed.localized
            case .timeout:
                return LocalizedString.errorYubikeyTimeout.localized
            case .slotNotConfigured:
                return LocalizedString.errorYubikeySlotNotConfigured.localized
            case .touchTimeout:
                return LocalizedString.errorYubikeyTouchTimeout.localized
            case .invalidResponse:
                return LocalizedString.errorYubikeyInvalidResponse.localized
            }
        }
    }

    // MARK: - Initialization

    private init() {
        setupYubiKeyDiscovery()
    }

    // MARK: - Setup

    private func setupYubiKeyDiscovery() {
        // Setup Lightning/USB-C accessory connection
        YubiKitManager.shared.delegate = self
        YubiKitManager.shared.startAccessoryConnection()

        // Setup NFC if available
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            YubiKitManager.shared.startNFCConnection()
        }
    }

    // MARK: - Public Methods

    /**
     * Perform HMAC-SHA1 challenge-response
     * This matches the Android implementation exactly
     */
    func performHmacChallenge(_ challenge: Data) async throws -> Data {
        AuditLogger.shared.logYubiKeyEvent(event: "hmac_challenge_start", details: "challenge_size=\(challenge.count)")

        // Pad challenge to 64 bytes if necessary (matching Android)
        let paddedChallenge: Data
        if challenge.count < hmacChallengeSize {
            var mutableChallenge = challenge
            mutableChallenge.append(Data(repeating: 0, count: hmacChallengeSize - challenge.count))
            paddedChallenge = mutableChallenge
        } else {
            paddedChallenge = challenge.prefix(hmacChallengeSize)
        }

        // Get connection (try accessory first, then NFC)
        guard let connection = try await getConnection() else {
            AuditLogger.shared.logYubiKeyEvent(event: "hmac_challenge_failed", details: "no_connection")
            throw YubikeyError.notConnected
        }

        do {
            let result = try await performChallenge(paddedChallenge, on: connection)
            AuditLogger.shared.logYubiKeyEvent(event: "hmac_challenge_success")
            return result
        } catch {
            AuditLogger.shared.logYubiKeyEvent(event: "hmac_challenge_failed", details: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Private Methods

    private func getConnection() async throws -> YKFConnectionProtocol? {
        // If already connected via accessory, use it
        if let connection = currentConnection {
            return connection
        }

        // Try NFC connection
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            return try await startNFCConnection()
        }

        // Wait briefly for accessory connection
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        if let connection = currentConnection {
            return connection
        }

        throw YubikeyError.notConnected
    }

    private func startNFCConnection() async throws -> YKFNFCConnection {
        return try await withCheckedThrowingContinuation { continuation in
            YubiKitManager.shared.startNFCConnection { connection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let connection = connection {
                    continuation.resume(returning: connection)
                } else {
                    continuation.resume(throwing: YubikeyError.notConnected)
                }
            }
        }
    }

    private func performChallenge(_ challenge: Data, on connection: YKFConnectionProtocol) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            connection.otpSession { session, error in
                guard let session = session else {
                    continuation.resume(throwing: error ?? YubikeyError.challengeFailed)
                    return
                }

                // Calculate HMAC-SHA1 response
                session.calculateHMACSHA1(
                    challenge,
                    slot: self.challengeResponseSlot
                ) { response, error in
                    if let error = error {
                        // Parse specific errors
                        if (error as NSError).code == YKFOTPErrorCode.timeout.rawValue {
                            continuation.resume(throwing: YubikeyError.touchTimeout)
                        } else if error.localizedDescription.contains("not configured") {
                            continuation.resume(throwing: YubikeyError.slotNotConfigured)
                        } else {
                            continuation.resume(throwing: YubikeyError.challengeFailed)
                        }
                    } else if let response = response {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(throwing: YubikeyError.invalidResponse)
                    }
                }
            }
        }
    }

    func cleanup() {
        YubiKitManager.shared.stopAccessoryConnection()
        YubiKitManager.shared.stopNFCConnection()
        currentConnection = nil
        isYubikeyConnected = false
    }
}

// MARK: - YubiKitManager Delegate

extension YubikeyManager: YKFManagerDelegate {
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        Task { @MainActor in
            currentConnection = connection
            isYubikeyConnected = true
            connectionType = .lightning // Assume Lightning for 5Ci
            AuditLogger.shared.logYubiKeyConnection(connected: true, connectionType: "lightning")
        }
    }

    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        Task { @MainActor in
            if currentConnection === connection {
                currentConnection = nil
                isYubikeyConnected = false
                connectionType = .none
                AuditLogger.shared.logYubiKeyConnection(connected: false, connectionType: "lightning")
            }
        }
    }
}

// MARK: - OTP Slot Extension

extension OTPSlot {
    // OTPSlot raw values 1 and 2 are guaranteed valid by the YubiKit SDK.
    // Using guard + preconditionFailure to avoid force unwrap lint violations
    // while keeping the same runtime behaviour if the SDK changes.
    static let one: OTPSlot = {
        guard let slot = OTPSlot(rawValue: 1) else {
            preconditionFailure("OTPSlot(rawValue: 1) returned nil; YubiKit SDK contract broken")
        }
        return slot
    }()
    static let two: OTPSlot = {
        guard let slot = OTPSlot(rawValue: 2) else {
            preconditionFailure("OTPSlot(rawValue: 2) returned nil; YubiKit SDK contract broken")
        }
        return slot
    }()
}

#else

@MainActor
class YubikeyManager: ObservableObject {
    static let shared = YubikeyManager()

    enum ConnectionType {
        case none
        case lightning
        case nfc
        case usbC
    }

    enum YubikeyError: LocalizedError {
        case notSupported

        var errorDescription: String? {
            "YubiKey functionality is unavailable in this build."
        }
    }

    @Published private(set) var isYubikeyConnected = false
    @Published private(set) var connectionType: ConnectionType = .none

    private init() {}

    func performHmacChallenge(_ challenge: Data) async throws -> Data {
        throw YubikeyError.notSupported
    }
}

#endif
