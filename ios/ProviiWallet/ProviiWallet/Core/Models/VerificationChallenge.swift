// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Represents a verification challenge received from a verifier, either via QR scan or deep link.
/// Contains the minimum age threshold the user must prove they meet, along with verifier identity
/// metadata and an optional expiry timestamp after which the challenge can no longer be answered.
struct VerificationChallenge: Codable {
    let id: String
    let minimumAge: Int
    let verifierName: String
    let verifierUrl: String?
    let timestamp: Date
    let expiresAt: Date?
}
