// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Zeroising string wrapper for sensitive values such as tokens and PINs.
///
/// Stores the UTF-8 bytes in a mutable buffer and overwrites them with zeros
/// on `clear()` and in `deinit`. Provides Data conversion for Keychain operations
/// and constant-time comparison via the top-level `constantTimeCompare` overload.

import Foundation

/// A string wrapper that securely clears memory when deallocated.
/// Prevents sensitive credentials from lingering in memory.
final class SecureString {
    private var buffer: [UInt8]

    init(_ string: String) {
        self.buffer = Array(string.utf8)
    }

    /// DEPRECATED: Creates an unzeroised String copy that lingers in memory.
    /// Use `withValue(_:)` instead to keep the plaintext within a scoped closure.
    @available(*, deprecated, message: "Use withValue(_:) to avoid unzeroised String copies in memory")
    var value: String {
        String(bytes: buffer, encoding: .utf8) ?? ""
    }

    /// Closure-based accessor that provides the plaintext String only
    /// within the scope of `body`. The caller never holds a persistent reference
    /// to the decoded value, reducing the window during which the plaintext
    /// exists as an unzeroised Swift String.
    func withValue<T>(_ body: (String) -> T) -> T {
        let plaintext = String(bytes: buffer, encoding: .utf8) ?? ""
        return body(plaintext)
    }

    /// Securely clear the buffer by overwriting with zeros.
    /// Uses memset_s which is guaranteed not to be optimised away.
    func clear() {
        buffer.withUnsafeMutableBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                _ = memset_s(baseAddress, ptr.count, 0, ptr.count)
            }
        }
        buffer = []
    }

    deinit {
        clear()
    }
}

/// Extension to convert SecureString to Data for keychain operations.
extension SecureString {
    /// Access the raw UTF-8 bytes without creating a copy.
    ///
    /// The closure receives a read-only pointer valid only for its duration.
    /// No Data copy is allocated, so there is nothing extra to zeroise.
    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try buffer.withUnsafeBytes(body)
    }

    /// DEPRECATED: Creates an unzeroised Data copy that lingers in memory.
    /// Use `withUnsafeBytes(_:)` to access the raw bytes within a scoped closure.
    @available(*, deprecated, message: "Use withUnsafeBytes(_:) to avoid unzeroised Data copies in memory")
    var data: Data {
        Data(buffer)
    }
}
