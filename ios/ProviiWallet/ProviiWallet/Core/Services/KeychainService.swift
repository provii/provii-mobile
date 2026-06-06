// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Secure storage manager wrapping the iOS Keychain.
///
/// Provides string and data CRUD, PIN management with PBKDF2 derivation and
/// constant-time verification, officer key storage, biometric setting
/// persistence, and Secure Enclave key generation. Biometric-protected items
/// use `kSecAttrAccessControl` exclusively to avoid the `kSecAttrAccessible`
/// silent-ignore bug.

import Foundation
import Security
import LocalAuthentication
class KeychainService {
    static let shared = KeychainService()

    // MARK: - Constants

    private let serviceName = "app.provii.wallet"
    private let accessGroup: String? = nil // Set if using app groups

    // Key aliases matching Android
    private let pinKeyAlias = "ProviiWalletPINKey"
    private let officerKeyAlias = "officer_key_id"

    private let auditLogger = AuditLogger.shared
    private let rateLimiter = RateLimiter.shared
    private let pinRateLimitIdentifier = "pin_verification"

    private init() {}

    // MARK: - String Storage

    func save(key: String, value: String, requiresBiometric: Bool = true) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        try save(key: key, data: data, requiresBiometric: requiresBiometric)
    }

    func getString(key: String) throws -> String? {
        guard let data = try getData(key: key) else {
            return nil
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return string
    }

    // MARK: - Data Storage

    func save(key: String, data: Data, requiresBiometric: Bool = true) throws {
        // Delete any existing item first
        delete(key: key)

        // BIO-H01: kSecAttrAccessible and kSecAttrAccessControl are mutually exclusive.
        // When both are set, the Keychain silently ignores the access control (biometric gate).
        // Use ONLY kSecAttrAccessControl when biometric is required (it inherits accessibility
        // from the protection level passed to SecAccessControlCreateWithFlags).
        // Use ONLY kSecAttrAccessible when biometric is not required.
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrIsExtractable as String: kCFBooleanFalse as Any
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        if requiresBiometric {
            // Biometric path: use kSecAttrAccessControl ONLY (no kSecAttrAccessible)
            var accessError: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet],
                &accessError
            ) else {
                // Access control creation failed. Do not fall back to unprotected storage.
                auditLogger.logKeychainAccess(operation: "save", key: key, success: false)
                throw KeychainError.saveFailed(-50) // errSecParam
            }

            let context = LAContext()
            // MASVS AUTH-2: Limit biometric reuse window to 5 seconds
            context.touchIDAuthenticationAllowableReuseDuration = 5

            query[kSecAttrAccessControl as String] = access
            query[kSecUseAuthenticationContext as String] = context
        } else {
            // Non-biometric path: use kSecAttrAccessible ONLY (no kSecAttrAccessControl)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            auditLogger.logKeychainAccess(operation: "save", key: key, success: false)
            throw KeychainError.saveFailed(status)
        }

        auditLogger.logKeychainAccess(operation: "save", key: key, success: true)
    }

    func getData(key: String, requireAuth: Bool = true) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Add authentication requirement if requested
        if requireAuth {
            let context = LAContext()
            // MASVS AUTH-2: Limit biometric reuse window to 5 seconds
            context.touchIDAuthenticationAllowableReuseDuration = 5
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            auditLogger.logKeychainAccess(operation: "read", key: key, success: true)
            return result as? Data

        case errSecItemNotFound:
            auditLogger.logKeychainAccess(operation: "read", key: key, success: true)
            return nil

        default:
            auditLogger.logKeychainAccess(operation: "read", key: key, success: false)
            throw KeychainError.readFailed(status)
        }
    }

    // MARK: - Secure Storage Methods (matching Android API)

    func saveSecureString(key: String, value: String) {
        do {
            try save(key: key, value: value)
        } catch {
            auditLogger.logKeychainAccess(operation: "save_string", key: key, success: false)
        }
    }

    func getSecureString(key: String) -> String? {
        do {
            return try getString(key: key)
        } catch {
            auditLogger.logKeychainAccess(operation: "get_string", key: key, success: false)
            return nil
        }
    }

    func saveSecureBytes(key: String, value: Data) {
        do {
            try save(key: key, data: value)
        } catch {
            auditLogger.logKeychainAccess(operation: "save_bytes", key: key, success: false)
        }
    }

    func getSecureBytes(key: String) -> Data? {
        do {
            return try getData(key: key)
        } catch {
            auditLogger.logKeychainAccess(operation: "get_bytes", key: key, success: false)
            return nil
        }
    }

    func removeSecureData(key: String) {
        delete(key: key)
    }

    // MARK: - Deletion

    @discardableResult
    func delete(key: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound

        auditLogger.logKeychainAccess(operation: "delete", key: key, success: success)
        return success
    }

    func deleteAll() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - PIN Management (matching Android functionality)

    func savePIN(_ pin: String) throws {
        // Generate salt for PBKDF2
        let salt = try CryptoUtils.randomKey32()

        // Derive key from PIN
        let derivedKeyHolder = try CryptoUtils.deriveKey(from: pin, salt: salt)
        defer { derivedKeyHolder.close() }

        // Save salt and derived key. Use withUnsafeBytes to avoid an unzeroised Data copy.
        try save(key: "\(pinKeyAlias)_salt", data: salt)
        try derivedKeyHolder.withUnsafeBytes { ptr in
            try save(key: pinKeyAlias, data: Data(ptr), requiresBiometric: true)
        }
    }

    func verifyPIN(_ pin: String) throws -> Bool {
        // Check rate limiting before attempting verification
        guard rateLimiter.isAllowed(identifier: pinRateLimitIdentifier) else {
            if let remaining = rateLimiter.lockoutTimeRemaining(identifier: pinRateLimitIdentifier) {
                auditLogger.logSecurityEvent(.pinVerificationLocked, details: [
                    "lockout_remaining_seconds": "\(Int(remaining))"
                ])
                throw RateLimitError.locked(remainingSeconds: remaining)
            }
            throw RateLimitError.rateLimited(remainingSeconds: 60)
        }

        guard let salt = try getData(key: "\(pinKeyAlias)_salt"),
              var storedKey = try getData(key: pinKeyAlias) else {
            rateLimiter.recordAttempt(identifier: pinRateLimitIdentifier, success: false)
            return false
        }
        defer {
            SensitiveDataHolder.zeroise(&storedKey)
        }

        let derivedKeyHolder = try CryptoUtils.deriveKey(from: pin, salt: salt)
        defer { derivedKeyHolder.close() }

        // Use constant-time comparison to prevent timing attacks.
        // withUnsafeBytes avoids creating an unzeroised Data copy of the derived key.
        let isValid = derivedKeyHolder.withUnsafeBytes { ptr in
            constantTimeCompare(Data(ptr), storedKey)
        }

        // Record the attempt result
        rateLimiter.recordAttempt(identifier: pinRateLimitIdentifier, success: isValid)

        if !isValid {
            let remaining = rateLimiter.remainingAttempts(identifier: pinRateLimitIdentifier)
            auditLogger.logSecurityEvent(.pinVerificationFailed, details: [
                "remaining_attempts": "\(remaining)"
            ])
        }

        return isValid
    }

    /// Get remaining PIN verification attempts before lockout
    func remainingPINAttempts() -> Int {
        rateLimiter.remainingAttempts(identifier: pinRateLimitIdentifier)
    }

    /// Check if PIN verification is currently locked out
    func isPINLocked() -> Bool {
        rateLimiter.lockoutTimeRemaining(identifier: pinRateLimitIdentifier) != nil
    }

    /// Get remaining lockout time for PIN verification
    func pinLockoutTimeRemaining() -> TimeInterval? {
        rateLimiter.lockoutTimeRemaining(identifier: pinRateLimitIdentifier)
    }

    func hasPIN() -> Bool {
        (try? getData(key: pinKeyAlias)) != nil
    }

    // MARK: - Officer Key Management

    func saveOfficerKey(_ keyId: String) {
        saveSecureString(key: officerKeyAlias, value: keyId)
    }

    func getOfficerKey() -> String? {
        getSecureString(key: officerKeyAlias)
    }

    func clearOfficerKey() {
        removeSecureData(key: officerKeyAlias)
    }

    // MARK: - Biometric Settings Storage

    private let biometricEnabledKey = "biometric_enabled"
    private let featureBiometricAuthKey = "feature_biometric_auth"
    private let featureBiometricAuthSetKey = "feature_biometric_auth_set"

    // In-memory cache for biometric flags. These only change on explicit
    // user toggle, so caching avoids redundant Keychain reads on every access.
    // Matches Android's EncryptedSharedPreferences which caches all values after first load.
    private var _cachedBiometricEnabled: Bool?
    private var _cachedFeatureBiometricAuth: Bool??
    private var _cachedFeatureBiometricAuthSet: Bool?

    /// Save biometric enabled state to Keychain
    /// Uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly for secure storage without biometric requirement
    func saveBiometricEnabled(_ enabled: Bool) throws {
        let data = Data([enabled ? 1 : 0])
        try saveWithoutBiometric(key: biometricEnabledKey, data: data)
        _cachedBiometricEnabled = enabled
    }

    /// Get biometric enabled state from Keychain
    /// Returns false if not set
    func getBiometricEnabled() -> Bool {
        if let cached = _cachedBiometricEnabled {
            return cached
        }
        guard let data = try? getDataWithoutAuth(key: biometricEnabledKey),
              let firstByte = data.first else {
            _cachedBiometricEnabled = false
            return false
        }
        let value = firstByte == 1
        _cachedBiometricEnabled = value
        return value
    }

    /// Remove biometric enabled state from Keychain
    func removeBiometricEnabled() {
        delete(key: biometricEnabledKey)
        _cachedBiometricEnabled = nil
    }

    /// Save feature biometric auth state to Keychain
    func saveFeatureBiometricAuth(_ enabled: Bool) throws {
        let data = Data([enabled ? 1 : 0])
        try saveWithoutBiometric(key: featureBiometricAuthKey, data: data)
        _cachedFeatureBiometricAuth = .some(enabled)
    }

    /// Get feature biometric auth state from Keychain
    /// Returns nil if not set (to distinguish from explicit false)
    func getFeatureBiometricAuth() -> Bool? {
        if let cached = _cachedFeatureBiometricAuth {
            return cached
        }
        guard let data = try? getDataWithoutAuth(key: featureBiometricAuthKey),
              let firstByte = data.first else {
            _cachedFeatureBiometricAuth = .some(nil)
            return nil
        }
        let value = firstByte == 1
        _cachedFeatureBiometricAuth = .some(value)
        return value
    }

    /// Save feature biometric auth set flag to Keychain
    func saveFeatureBiometricAuthSet(_ set: Bool) throws {
        let data = Data([set ? 1 : 0])
        try saveWithoutBiometric(key: featureBiometricAuthSetKey, data: data)
        _cachedFeatureBiometricAuthSet = set
    }

    /// Get feature biometric auth set flag from Keychain
    func getFeatureBiometricAuthSet() -> Bool {
        if let cached = _cachedFeatureBiometricAuthSet {
            return cached
        }
        guard let data = try? getDataWithoutAuth(key: featureBiometricAuthSetKey),
              let firstByte = data.first else {
            _cachedFeatureBiometricAuthSet = false
            return false
        }
        let value = firstByte == 1
        _cachedFeatureBiometricAuthSet = value
        return value
    }

    /// Remove all biometric feature flags from Keychain
    func removeFeatureBiometricAuth() {
        delete(key: featureBiometricAuthKey)
        delete(key: featureBiometricAuthSetKey)
        _cachedFeatureBiometricAuth = nil
        _cachedFeatureBiometricAuthSet = nil
    }

    // MARK: - Private Helpers for Non-Biometric Protected Storage

    /// Save data without biometric protection
    /// Uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly for security
    private func saveWithoutBiometric(key: String, data: Data) throws {
        // Delete any existing item first
        delete(key: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrIsExtractable as String: kCFBooleanFalse as Any
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            auditLogger.logKeychainAccess(operation: "save_biometric_setting", key: key, success: false)
            throw KeychainError.saveFailed(status)
        }

        auditLogger.logKeychainAccess(operation: "save_biometric_setting", key: key, success: true)
    }

    /// Get data without authentication requirement
    private func getDataWithoutAuth(key: String) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.readFailed(status)
        }
    }

    // MARK: - List All Keys (for debugging)

    /// Restricted to DEBUG builds. Enumerating all Keychain account
    /// names is useful during development but exposes key aliases in production,
    /// which could aid reverse engineering of the storage layout.
    #if DEBUG
    func listAllKeys() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        let keys = items.compactMap { $0[kSecAttrAccount as String] as? String }

        return keys
    }
    #endif
}

// MARK: - Encrypted Data (matching Android)

struct EncryptedData: Codable, Equatable {
    let ciphertext: Data
    let iv: Data
    let algorithm: String

    init(ciphertext: Data, iv: Data, algorithm: String = "AES/GCM/NoPadding") {
        self.ciphertext = ciphertext
        self.iv = iv
        self.algorithm = algorithm
    }
}

// MARK: - Error Types

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
    case decodingFailed
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return String(format: NSLocalizedString("error.keychain.save_failed", comment: "Failed to save to keychain error"), status)
        case .readFailed(let status):
            return String(format: NSLocalizedString("error.keychain.read_failed", comment: "Failed to read from keychain error"), status)
        case .deleteFailed(let status):
            return String(format: NSLocalizedString("error.keychain.delete_failed", comment: "Failed to delete from keychain error"), status)
        case .encodingFailed:
            return NSLocalizedString("error.keychain.encoding_failed", comment: "Failed to encode data error")
        case .decodingFailed:
            return NSLocalizedString("error.keychain.decoding_failed", comment: "Failed to decode data error")
        case .itemNotFound:
            return NSLocalizedString("error.keychain.item_not_found", comment: "Item not found in keychain error")
        }
    }
}

// MARK: - Secure Enclave Support (Optional)

extension KeychainService {

    /**
     * Generate a key in Secure Enclave (for devices that support it)
     * This provides hardware-backed key generation and storage
     */
    func generateSecureEnclaveKey(tag: String) throws -> SecKey {
        guard SecureEnclave.isAvailable else {
            throw KeychainError.saveFailed(-50) // errSecParam
        }

        // MASVS CODE-4: Safe unwrapping of optional access control
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            throw KeychainError.saveFailed(-50) // errSecParam - access control creation failed
        }

        guard let tagData = tag.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            // MASVS CODE-4: Safe unwrapping of optional error
            if let cfError = error?.takeRetainedValue() {
                throw cfError as Error
            }
            throw KeychainError.saveFailed(-1) // Unknown error
        }

        return privateKey
    }

    /**
     * Check if Secure Enclave is available on this device
     */
    struct SecureEnclave {
        static var isAvailable: Bool {
            return !isSimulator && hasBiometrics
        }

        private static var isSimulator: Bool {
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }

        private static var hasBiometrics: Bool {
            let context = LAContext()
            var error: NSError?
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        }
    }
}
