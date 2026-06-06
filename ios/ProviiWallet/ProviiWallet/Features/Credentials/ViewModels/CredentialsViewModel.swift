// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI
import Combine

#if canImport(ProviiSDK)
import ProviiSDK
#endif

/// View model for the credentials list screen, bridging WalletSDKManager operations (load, delete)
/// to published state for SwiftUI consumption. Handles async credential loading and error propagation.

@MainActor
class CredentialsViewModel: ObservableObject {
    @Published var credentials: [CredentialInfo] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let walletManager = WalletSDKManager.shared

    func loadCredentials() async {
        isLoading = true
        defer { isLoading = false }

        await walletManager.loadCredentials()
        credentials = walletManager.credentials
    }

    func deleteCredential(_ id: String) async {
        do {
            try await walletManager.deleteCredential(id)
            await loadCredentials()
        } catch {
            self.error = error
        }
    }
}
