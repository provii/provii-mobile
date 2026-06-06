// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

// ! Constant-time byte comparison for secret material.
// !
// !
// ! Provides timing-safe equality checks for Data, String, and SecureString values.
// ! Used throughout the wallet for HMAC tag verification, token comparison, and any
// ! operation where a timing side-channel could leak information about secret values.

import Foundation
import Darwin

/// Constant-time comparison to prevent timing attacks.
/// Delegates to libc `timingsafe_bcmp` which is guaranteed constant-time
/// by the OS. Returns false for mismatched lengths (length itself is not
/// compared in constant time, but length is never secret in our protocols).
func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else { return false }
    guard a.count > 0 else { return true }
    return a.withUnsafeBytes { aPtr in
        b.withUnsafeBytes { bPtr in
            guard let aBase = aPtr.baseAddress, let bBase = bPtr.baseAddress else {
                return false
            }
            return timingsafe_bcmp(aBase, bBase, a.count) == 0
        }
    }
}

/// Constant-time string comparison wrapper
func constantTimeCompare(_ a: String, _ b: String) -> Bool {
    constantTimeCompare(Data(a.utf8), Data(b.utf8))
}

/// Constant-time comparison for SecureString.
///
/// Uses `withUnsafeBytes` on both operands to avoid creating unzeroised Data copies.
/// The underlying call to `timingsafe_bcmp` is the same constant-time primitive as
/// the Data overload above.
func constantTimeCompare(_ a: SecureString, _ b: SecureString) -> Bool {
    a.withUnsafeBytes { aPtr in
        b.withUnsafeBytes { bPtr in
            guard aPtr.count == bPtr.count else { return false }
            guard aPtr.count > 0 else { return true }
            guard let aBase = aPtr.baseAddress, let bBase = bPtr.baseAddress else {
                return false
            }
            return timingsafe_bcmp(aBase, bBase, aPtr.count) == 0
        }
    }
}
