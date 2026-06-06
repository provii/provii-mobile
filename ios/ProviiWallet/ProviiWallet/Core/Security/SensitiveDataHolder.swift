// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// MASVS-CODE-2: Memory Safety - Sensitive Data Holder
///
/// A container for sensitive byte arrays that implements secure cleanup.
/// Uses RAII pattern: data is zeroised on `close()` and in `deinit`.
///
/// Usage:
/// ```swift
/// let holder = SensitiveDataHolder(secretKey)
/// defer { holder.close() }
/// // Use holder.data for cryptographic operations
/// ```
///
/// Or with the `withSensitiveData` helper:
/// ```swift
/// SensitiveDataHolder.withData(secretKey) { data in
///     // Use data safely
/// }
/// ```
final class SensitiveDataHolder {
    private var sensitiveData: [UInt8]
    private var closed = false
    private let lock = NSLock()

    init(_ data: Data) {
        self.sensitiveData = Array(data)
    }

    init(_ bytes: [UInt8]) {
        self.sensitiveData = bytes
    }

    /// Access the sensitive data as a copy.
    ///
    /// WARNING: The returned `Data` is an unzeroised copy. Prefer `withUnsafeBytes(_:)`
    /// to avoid copies. If you must use this property, zeroise the returned value
    /// with `SensitiveDataHolder.zeroise(&copy)` when finished.
    @available(*, deprecated, message: "Use withUnsafeBytes(_:) to avoid unzeroised Data copies in memory")
    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        precondition(!closed, "SensitiveDataHolder has been closed - data has been zeroised")
        return Data(sensitiveData)
    }

    /// Access the sensitive bytes without creating a copy.
    ///
    /// The closure receives a read-only pointer to the underlying buffer.
    /// No copy is made, so there is nothing extra to zeroise afterwards.
    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        precondition(!closed, "SensitiveDataHolder has been closed - data has been zeroised")
        return try sensitiveData.withUnsafeBytes(body)
    }

    var size: Int {
        lock.lock()
        defer { lock.unlock() }
        return sensitiveData.count
    }

    var isValid: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !closed
    }

    /// Securely close and zero out all sensitive data
    func close() {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        zeroiseBuffer(&sensitiveData)
    }

    deinit {
        lock.lock()
        defer { lock.unlock() }
        if !closed {
            closed = true
            zeroiseBuffer(&sensitiveData)
        }
    }

    // MARK: - Static Helpers

    /// Create a holder with data copied from source (leaves source intact)
    static func fromCopy(_ source: Data) -> SensitiveDataHolder {
        return SensitiveDataHolder(source)
    }

    /// Create a holder and immediately zeroise the source.
    ///
    /// The holder is initialised from the source bytes, then the source
    /// buffer is zeroised via `memset_s`. Because Swift Arrays use copy on write,
    /// the intermediate `let copy` formerly shared the same backing store as
    /// `source` until mutation. We now zeroise the source *after* the holder's
    /// init has captured its own independent storage, and we explicitly scrub
    /// the source buffer through its mutable pointer to ensure no COW alias
    /// retains the original plaintext.
    static func takeOwnership(_ source: inout [UInt8]) -> SensitiveDataHolder {
        let holder = SensitiveDataHolder(source)
        // Force COW separation: the init above copies into sensitiveData.
        // Now zeroise the caller's buffer via memset_s so the original
        // backing store is scrubbed even if COW kept a shared reference.
        source.withUnsafeMutableBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                _ = memset_s(baseAddress, ptr.count, 0, ptr.count)
            }
        }
        source = []
        return holder
    }

    /// Execute a closure with zero-copy access to the sensitive bytes, then automatically zeroise.
    ///
    /// The closure receives an `UnsafeRawBufferPointer` valid only for its duration.
    /// No Data copy is allocated so there is nothing extra to zeroise afterwards.
    static func withData<T>(_ data: Data, body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        let holder = SensitiveDataHolder(data)
        defer { holder.close() }
        return try holder.withUnsafeBytes(body)
    }

    /// Securely zero out a byte array
    static func zeroise(_ data: inout [UInt8]) {
        zeroiseBuffer(&data)
    }

    /// Securely zero out Data using memset_s (guaranteed not optimised away)
    static func zeroise(_ data: inout Data) {
        data.withUnsafeMutableBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                _ = memset_s(baseAddress, ptr.count, 0, ptr.count)
            }
        }
        data = Data()
    }
}

// MARK: - Private zeroisation helper

/// Zeroisation using memset_s, which is guaranteed not to be optimised away
/// by the compiler (C11 Annex K / ISO 9899:2011 K.3.7.4.1).
private func zeroiseBuffer(_ buffer: inout [UInt8]) {
    buffer.withUnsafeMutableBytes { ptr in
        if let baseAddress = ptr.baseAddress {
            _ = memset_s(baseAddress, ptr.count, 0, ptr.count)
        }
    }
    buffer = []
}
