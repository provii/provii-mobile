// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// High-level coordinator for the Rust provii-mobile-sdk lifecycle.
///
/// Wraps `WalletSDKBridge` with SwiftUI-friendly `@Published` state for
/// SDK initialisation, credential listing, proof generation, and storage
/// operations. Acts as the single entry point for all SDK interactions
/// from the view layer.

import Foundation
import SwiftUI
import Combine

#if canImport(ProviiSDK)
import ProviiSDK
#endif

@MainActor
class WalletSDKManager: ObservableObject {
    static let shared = WalletSDKManager()

    @Published var isInitialized = false
    @Published var credentials: [CredentialInfo] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let bridge = WalletSDKBridge.shared

    private init() {}

    func initialize() async throws {
        guard !isInitialized else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await bridge.initialize()
            isInitialized = true
            await loadCredentials()
        } catch {
            self.error = error
            throw error
        }
    }

    func loadCredentials() async {
        await bridge.loadCredentials()
        credentials = bridge.credentials
    }

    func processQRCode(_ content: String) async throws -> QrAction {
        return try await bridge.processQRCode(content)
    }

    func deleteCredential(_ id: String) async throws {
        try await bridge.deleteCredential(credentialId: id)
        await loadCredentials()
    }
}
