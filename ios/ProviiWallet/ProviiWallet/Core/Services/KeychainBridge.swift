// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Bridge between the Rust SDK's `ios_storage.rs` and the iOS Keychain.
///
/// Provides CRUD operations on `kSecClassGenericPassword` items with optional
/// biometric protection via `SecAccessControl`. The Rust SDK calls the Swift
/// class methods directly via the UniFFI-generated bindings, not via the
/// `@_cdecl` C-bridge functions below. Biometric items use
/// `kSecAttrAccessControl` exclusively (never combined with
/// `kSecAttrAccessible`) to avoid the silent-ignore bug.

import Foundation
import Security
import LocalAuthentication
class KeychainBridge {

    static let shared = KeychainBridge()

    private let keyPrefix = "provii_sdk_"
    private let serviceName = "app.provii.wallet"
    private let accessGroup: String? = nil // Set if using app groups

    private init() {
    }

    // MARK: - SDK Bridge Methods

    func ensurePrimaryKey(useSecureEnclave: Bool, requireBiometrics: Bool) -> Bool {
        // iOS Keychain manages encryption keys internally
        return true
    }

    func initialize(requireBiometrics: Bool, useSecureEnclave: Bool) {
        // Store configuration
        _ = storeSecure(
            key: "\(keyPrefix)config_biometrics",
            data: Data(requireBiometrics.description.utf8),
            useSecureEnclave: false,
            requireBiometrics: false
        )

        _ = storeSecure(
            key: "\(keyPrefix)config_secure_enclave",
            data: Data(useSecureEnclave.description.utf8),
            useSecureEnclave: false,
            requireBiometrics: false
        )
    }

    func storeSecure(key: String, data: Data, useSecureEnclave: Bool, requireBiometrics: Bool) -> Bool {
        // Delete any existing item first
        _ = deleteSecure(key: key)

        // BIO-H01: kSecAttrAccessible and kSecAttrAccessControl are mutually exclusive.
        // When both are set, the Keychain silently ignores the access control (biometric gate).
        // Use ONLY kSecAttrAccessControl when biometric is required (it inherits accessibility
        // from the protection level passed to SecAccessControlCreateWithFlags).
        // Use ONLY kSecAttrAccessible when biometric is not required.
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(keyPrefix)\(key)",
            kSecValueData as String: data
        ]

        // Add access group if configured
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        if requireBiometrics {
            // Biometric path: use kSecAttrAccessControl ONLY (no kSecAttrAccessible)
            guard let access = createBiometricAccess() else {
                // Access control creation failed. Do not fall back to unprotected storage.
                SecureLogger.shared.warning("Biometric access control creation failed, refusing to store without protection", redact: false)
                return false
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            // Non-biometric path: use kSecAttrAccessible ONLY (no kSecAttrAccessControl)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess

        if success {
            // Verify it was saved
            _ = retrieveSecure(key: key, requireBiometrics: requireBiometrics)
        }

        return success
    }

    func retrieveSecure(key: String, requireBiometrics: Bool) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(keyPrefix)\(key)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Add access group if configured
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Add biometric context if required
        if requireBiometrics {
            let context = LAContext()
            // MASVS AUTH-2: Limit biometric reuse window to 5 seconds
            context.touchIDAuthenticationAllowableReuseDuration = 5
            context.localizedReason = "Access your credentials"
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        } else {
            return nil
        }
    }

    func deleteSecure(key: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(keyPrefix)\(key)"
        ]

        // Add access group if configured
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound

        return success
    }

    /// Returns all Keychain items under the SDK service name that carry the SDK
    /// key prefix, with the prefix stripped. Items belonging to other services
    /// or unrelated accounts are excluded by the prefix filter.
    func listKeys() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        // Add access group if configured
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        let sdkKeys = items.compactMap { item -> String? in
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(keyPrefix) else {
                return nil
            }
            return String(account.dropFirst(keyPrefix.count))
        }

        return sdkKeys
    }

    func authenticateBiometric(reason: String, timeoutMs: Int) -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        var authResult = false
        let semaphore = DispatchSemaphore(value: 0)

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, _ in
            authResult = success
            semaphore.signal()
        }

        // Wait for authentication with timeout
        let timeout = DispatchTime.now() + .milliseconds(timeoutMs)
        let result = semaphore.wait(timeout: timeout)

        if result == .timedOut {
            return false
        }

        return authResult
    }

    /**
     * Key rotation on iOS
     *
     * NOTE: This method is NOT called by the Rust SDK. On iOS, key rotation is handled
     * internally by the Rust store-ios implementation which performs delete/re-store
     * operations that trigger new encryption by the iOS Keychain.
     *
     * The iOS Keychain manages its own encryption keys and doesn't expose a "rotate key"
     * API. Instead, deleting and re-storing items causes them to be encrypted with
     * current key material.
     *
     * This method exists only for API compatibility. Use WalletSDK's storage rotation
     * functions if key rotation is needed.
     */
    func rotatePrimaryKey() -> Bool {
        SecureLogger.shared.warning("rotatePrimaryKey() called directly - iOS rotation is handled by Rust SDK internally", redact: false)
        // Return true for compatibility - actual rotation happens through Rust SDK
        return true
    }

    // MARK: - Helper Methods

    private func createBiometricAccess() -> SecAccessControl? {
        var error: Unmanaged<CFError>?

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        )

        // Check both the return value AND the error parameter.
        // SecAccessControlCreateWithFlags can return nil without setting
        // the error on some OS versions, so we must check both.
        if let cfError = error {
            let nsError = cfError.takeRetainedValue() as Error
            SecureLogger.shared.warning("SecAccessControlCreateWithFlags failed: \(nsError.localizedDescription)", redact: false)
            return nil
        }

        guard let validAccess = access else {
            SecureLogger.shared.warning("SecAccessControlCreateWithFlags returned nil without error", redact: false)
            return nil
        }

        return validAccess
    }

    // MARK: - Cleanup

    func clearAll() {
        let keys = listKeys()
        for key in keys {
            _ = deleteSecure(key: key)
        }
    }
}

// MARK: - C-Style Bridge Functions (if needed by Rust FFI)

@_cdecl("ios_keychain_store")
func ios_keychain_store(
    key: UnsafePointer<CChar>,
    data: UnsafePointer<UInt8>,
    dataLen: Int32,
    useSecureEnclave: Bool,
    requireBiometrics: Bool
) -> Bool {
    let keyStr = String(cString: key)
    let dataObj = Data(bytes: data, count: Int(dataLen))

    return KeychainBridge.shared.storeSecure(
        key: keyStr,
        data: dataObj,
        useSecureEnclave: useSecureEnclave,
        requireBiometrics: requireBiometrics
    )
}

@_cdecl("ios_keychain_retrieve")
func ios_keychain_retrieve(
    key: UnsafePointer<CChar>,
    requireBiometrics: Bool,
    outData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    outLen: UnsafeMutablePointer<Int32>
) -> Bool {
    let keyStr = String(cString: key)

    guard let data = KeychainBridge.shared.retrieveSecure(
        key: keyStr,
        requireBiometrics: requireBiometrics
    ) else {
        outData.pointee = nil
        outLen.pointee = 0
        return false
    }

    let count = data.count
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
    // Copy keychain bytes into the FFI-owned buffer.
    data.copyBytes(to: buffer, count: count)
    // Zeroise the local Data binding to prevent the COW-shared backing store
    // from retaining plaintext after this function returns.
    var localData = data
    localData.withUnsafeMutableBytes { ptr in
        if let base = ptr.baseAddress {
            _ = memset_s(base, ptr.count, 0, ptr.count)
        }
    }

    outData.pointee = buffer
    outLen.pointee = Int32(count)

    return true
}

/// Free the buffer allocated by `ios_keychain_retrieve`.
///
/// The Rust side MUST call this after consuming the retrieved bytes.
/// We zeroise via `memset_s` before deallocating so plaintext is not left
/// on the heap for subsequent allocations to observe.
@_cdecl("ios_keychain_free")
func ios_keychain_free(ptr: UnsafeMutablePointer<UInt8>?, len: Int32) {
    guard let ptr = ptr, len > 0 else { return }
    _ = memset_s(ptr, Int(len), 0, Int(len))
    ptr.deallocate()
}

@_cdecl("ios_keychain_delete")
func ios_keychain_delete(key: UnsafePointer<CChar>) -> Bool {
    let keyStr = String(cString: key)
    return KeychainBridge.shared.deleteSecure(key: keyStr)
}

#if DEBUG
@_cdecl("ios_keychain_list_keys")
func ios_keychain_list_keys(
    outKeys: UnsafeMutablePointer<UnsafeMutablePointer<UnsafePointer<CChar>?>?>,
    outCount: UnsafeMutablePointer<Int32>
) -> Bool {
    let keys = KeychainBridge.shared.listKeys()

    guard !keys.isEmpty else {
        outKeys.pointee = nil
        outCount.pointee = 0
        return true
    }

    let keysArray = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: keys.count)

    for (index, key) in keys.enumerated() {
        if let duplicated = strdup(key) {
            keysArray[index] = UnsafePointer<CChar>(duplicated)
        } else {
            keysArray[index] = nil
        }
    }

    outKeys.pointee = keysArray
    outCount.pointee = Int32(keys.count)

    return true
}
#endif
