// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Manages biometric authentication via Face ID and Touch ID.
///
/// Supports two authentication modes: policy-only evaluation for low-risk
/// operations, and Secure Enclave key-bound authentication (MASVS AUTH-2) for
/// high-security flows such as credential access and signing. Key-bound auth
/// generates an EC P-256 key in the Secure Enclave protected by
/// `.biometryCurrentSet`, signs a random nonce, and verifies the signature to
/// cryptographically prove biometric presence.

import LocalAuthentication
import Foundation
import Security

class BiometricService {
    static let shared = BiometricService()

    // MARK: - Security Configuration

    /// Reduced context reuse duration (5 seconds instead of default)
    /// MASVS AUTH-2: Limit biometric auth reuse window
    private let contextReuseDuration: TimeInterval = 5.0

    /// Key tag prefix for Secure Enclave keys
    private let seKeyPrefix = "app.provii.wallet.se."

    /// Current authentication context (invalidated on logout)
    private var currentContext: LAContext?

    /// Audit logger for security events
    private let auditLogger = AuditLogger.shared

    /// Last successful authentication time
    private var lastAuthTime: Date?

    private init() {}

    // MARK: - Authentication

    func authenticate(reason: String) async -> Bool {
        // Create fresh context with reduced reuse window
        let context = createSecureContext()

        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "cannot_evaluate_policy",
                "error": error?.localizedDescription ?? "unknown"
            ])
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                currentContext = context
                lastAuthTime = Date()
                auditLogger.logSecurityEvent(.biometricAuthSuccess, details: [
                    "biometric_type": biometricTypeName
                ])
            } else {
                auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                    "reason": "evaluation_returned_false"
                ])
            }

            return success
        } catch {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "evaluation_error",
                "error": error.localizedDescription
            ])
            return false
        }
    }

    /// Authenticate with Secure Enclave key binding (enhanced security)
    /// MASVS AUTH-2: Bind biometric auth to a real cryptographic operation
    ///
    /// Generates or retrieves an EC P-256 key in the Secure Enclave, protected by
    /// `.biometryCurrentSet`. Signs a random nonce with that key and verifies the
    /// signature. This cryptographically proves that the biometric holder was
    /// present, rather than relying on a policy evaluation alone.
    func authenticateWithKeyBinding(reason: String, keyTag: String) async -> Bool {
        let context = createSecureContext()

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "cannot_evaluate_policy",
                "error": policyError?.localizedDescription ?? "unknown"
            ])
            return false
        }

        let fullTag = "\(seKeyPrefix)\(keyTag)"

        // Retrieve existing key or generate a new one in the Secure Enclave
        guard let privateKey = retrieveOrGenerateSEKey(tag: fullTag, context: context, reason: reason) else {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "secure_enclave_key_unavailable",
                "key_tag": keyTag
            ])
            return false
        }

        // Generate a random nonce to sign (32 bytes)
        var nonce = Data(count: 32)
        let nonceStatus = nonce.withUnsafeMutableBytes { bufferPointer in
            guard let base = bufferPointer.baseAddress else {
                return errSecAllocate
            }
            return SecRandomCopyBytes(kSecRandomDefault, 32, base)
        }
        guard nonceStatus == errSecSuccess else {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "nonce_generation_failed",
                "key_tag": keyTag
            ])
            return false
        }
        defer {
            SensitiveDataHolder.zeroise(&nonce)
        }

        // Sign the nonce. The Secure Enclave key has biometric protection, so
        // this operation triggers the biometric prompt. If the user cancels or
        // fails authentication, SecKeyCreateSignature returns nil.
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            nonce as CFData,
            &signError
        ) else {
            if let cfError = signError?.takeRetainedValue() {
                auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                    "reason": "sign_failed",
                    "error": (cfError as Error).localizedDescription,
                    "key_tag": keyTag
                ])
            }
            return false
        }

        // Verify the signature with the corresponding public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "public_key_extraction_failed",
                "key_tag": keyTag
            ])
            return false
        }

        var verifyError: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            nonce as CFData,
            signature,
            &verifyError
        )

        if verified {
            currentContext = context
            lastAuthTime = Date()
            auditLogger.logSecurityEvent(.biometricAuthSuccess, details: [
                "biometric_type": biometricTypeName,
                "key_bound": "true",
                "key_tag": keyTag
            ])
        } else {
            auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                "reason": "signature_verification_failed",
                "key_tag": keyTag
            ])
        }

        return verified
    }

    // MARK: - Secure Enclave Key Management

    /// Retrieve an existing Secure Enclave key or generate a new one.
    /// The key is protected by `.biometryCurrentSet` so the biometric prompt
    /// fires when the key is used for signing, not at retrieval time.
    private func retrieveOrGenerateSEKey(tag: String, context: LAContext, reason: String) -> SecKey? {
        guard let tagData = tag.data(using: .utf8) else { return nil }

        // Try to retrieve an existing key first
        let retrieveQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        var existingKey: CFTypeRef?
        let retrieveStatus = SecItemCopyMatching(retrieveQuery as CFDictionary, &existingKey)

        if retrieveStatus == errSecSuccess, let result = existingKey,
           CFGetTypeID(result) == SecKeyGetTypeID() {
            // SecKey is a CoreFoundation type. Confirm by type ID rather
            // than `as? SecKey` (which the compiler warns is always true)
            // or `as!` (which warns about unconditional CF downcasts).
            return unsafeBitCast(result, to: SecKey.self)
        }

        // Key does not exist yet. Create access control with biometric protection.
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &accessError
        ) else {
            if let cfError = accessError?.takeRetainedValue() {
                auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                    "reason": "access_control_creation_failed",
                    "error": (cfError as Error).localizedDescription
                ])
            }
            return nil
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

        var generateError: Unmanaged<CFError>?
        guard let newKey = SecKeyCreateRandomKey(attributes as CFDictionary, &generateError) else {
            if let cfError = generateError?.takeRetainedValue() {
                auditLogger.logSecurityEvent(.biometricAuthFailure, details: [
                    "reason": "key_generation_failed",
                    "error": (cfError as Error).localizedDescription
                ])
            }
            return nil
        }

        return newKey
    }

    // MARK: - Context Management

    /// Create a secure LAContext with reduced reuse duration
    private func createSecureContext() -> LAContext {
        let context = LAContext()

        // MASVS AUTH-2: Reduce context reuse window to 5 seconds
        context.touchIDAuthenticationAllowableReuseDuration = contextReuseDuration

        // Invalidate previous context
        currentContext?.invalidate()

        return context
    }

    /// Invalidate current context on logout
    /// MASVS AUTH-2: Proper session invalidation
    func invalidateContext() {
        if let context = currentContext {
            context.invalidate()
            auditLogger.logSecurityEvent(.biometricContextInvalidated, details: [:])
        }
        currentContext = nil
        lastAuthTime = nil
    }

    /// Check if biometric auth is still valid within reuse window
    func isAuthenticationValid() -> Bool {
        guard let lastAuth = lastAuthTime else { return false }
        return Date().timeIntervalSince(lastAuth) < contextReuseDuration
    }

    // MARK: - Biometric Information

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Returns the biometric type name with proper pronunciation for screen readers
    var biometricTypeName: String {
        let type = biometricType
        if #available(iOS 17.0, *), type == .opticID {
            return "Optic ID"
        }
        switch type {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "None"
        @unknown default:
            return "Biometric"
        }
    }

    /// Returns accessibility-friendly description with pronunciation guidance
    var accessibleBiometricDescription: String {
        let type = biometricType
        if #available(iOS 17.0, *), type == .opticID {
            return PronunciationGuide.biometricActionLabel(type: "Optic ID", action: "Authentication")
        }
        switch type {
        case .faceID:
            return PronunciationGuide.biometricActionLabel(type: "Face ID", action: "Authentication")
        case .touchID:
            return PronunciationGuide.biometricActionLabel(type: "Touch ID", action: "Authentication")
        case .none:
            return "No biometric authentication available"
        @unknown default:
            return "Biometric authentication"
        }
    }

    /// Check if biometrics are available on this device
    var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
