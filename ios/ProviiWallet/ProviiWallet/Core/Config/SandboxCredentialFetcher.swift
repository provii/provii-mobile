// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// per-install sandbox credential provisioning.
///
/// Flow:
///   1. GET  /api/mobile/sandbox/challenge           (unauthenticated, returns nonce)
///   2. DCAppAttestService.generateKey(...)          (once per install, keyId cached)
///   3. clientDataHash = SHA256(nonce_bytes)          (BLOCKER-6: matches Apple canonical)
///   4. DCAppAttestService.attestKey(keyId, clientDataHash)
///   5. POST /api/mobile/sandbox/register            body carries attestation + install_uuid
///   6. gateway returns {client_id, hmac_secret, expires_at}
///
/// Subsequent refresh + revoke are signed with the returned `hmac_secret`
/// using the `mwallet-sbx/v1` HMAC envelope format per Sarah's gateway
/// contract (BLOCKER-3). Headers: `X-Mwallet-Auth`, `X-Mwallet-Sig`.
/// CryptoKit `HMAC<SHA256>.authenticationCode(for:using:)` is the signing
/// primitive.
///
/// The install UUID v7 is minted on the first sandbox enable and stored in
/// Keychain under `provii.install_id` with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
///
/// Background refresh runs 24 hours before `expires_at` via `BGTaskScheduler`.
/// Simulators cannot issue real App Attest assertions; `#if
/// targetEnvironment(simulator)` surfaces a clear runtime error so test
/// harnesses know to use a physical device.

import BackgroundTasks
import CryptoKit
import DeviceCheck
import Foundation
import UIKit

// MARK: - Credential model

/// Per-install sandbox credential returned by the gateway `register` and
/// `refresh` responses.
struct SandboxCredential: Codable, Equatable, CustomDebugStringConvertible {
    let clientId: String
    /// base64url secret used for HMAC signing of subsequent requests.
    let hmacSecret: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }

    /// Treat anything within 24 hours of expiry as "refresh now" so the
    /// background task has runway before the credential dies.
    var needsRefresh: Bool {
        Date() >= expiresAt.addingTimeInterval(-24 * 3600)
    }

    var debugDescription: String {
        "SandboxCredential(clientId: \(clientId), hmacSecret: [REDACTED], expiresAt: \(expiresAt))"
    }
}

// MARK: - Errors

enum SandboxCredentialFetcherError: LocalizedError {
    case simulatorUnsupported
    case appAttestUnsupported
    case appAttestKeyGeneration(Error)
    case appAttestAttestation(Error)
    case invalidChallenge
    case challengeExpired
    case invalidResponse
    case missingCredential
    case lifetimeExhausted
    case httpError(Int, String?)
    case keychainFailure(OSStatus)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .simulatorUnsupported:
            return "App Attest requires a physical device with Secure Enclave"
        case .appAttestUnsupported:
            return "App Attest is not supported on this device"
        case .appAttestKeyGeneration(let e):
            return "App Attest key generation failed: \(e.localizedDescription)"
        case .appAttestAttestation(let e):
            return "App Attest attestation failed: \(e.localizedDescription)"
        case .invalidChallenge:
            return "Gateway returned an invalid challenge"
        case .challengeExpired:
            return "Challenge nonce expired before registration completed"
        case .invalidResponse:
            return "Gateway returned an invalid response"
        case .missingCredential:
            return "No sandbox credential registered"
        case .lifetimeExhausted:
            return "Credential absolute lifetime exhausted; must re-register"
        case .httpError(let code, let body):
            return "Gateway HTTP \(code): \(body ?? "")"
        case .keychainFailure(let status):
            return "Keychain failure: \(status)"
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Fetcher

/// Actor that owns the per-install sandbox credential lifecycle.
actor SandboxCredentialFetcher {
    static let shared = SandboxCredentialFetcher()

    // MARK: - Storage keys

    private static let installIdKeychainKey = "provii.install_id"
    private static let credentialKeychainKey = "provii.sandbox.credential"
    private static let appAttestKeyIdKeychainKey = "provii.app_attest_key_id"

    // MARK: - Background task

    static let refreshTaskIdentifier = "app.provii.wallet.sandbox.refresh"

    // MARK: - Configuration

    /// Maximum HTTP body size; gateway rejects anything larger. 16 KiB cap per
    /// Sarah's contract spec.
    private static let maxBodyBytes = 16 * 1024

    /// LOW: Client-side challenge TTL safety margin (seconds). Gateway nonces
    /// expire after 60s; we re-fetch if more than 45s elapsed between
    /// challenge fetch and register POST.
    private static let challengeTtlSafetyMargin: TimeInterval = 45

    // MARK: - Dependencies

    private let session: URLSession
    private let keychain: KeychainService
    private let attestService: AppAttestServicing
    private let baseURLProvider: @Sendable () -> URL?
    private let clockNow: @Sendable () -> Date

    init(
        session: URLSession = .shared,
        keychain: KeychainService = .shared,
        attestService: AppAttestServicing = DCAppAttestService.shared,
        baseURLProvider: @escaping @Sendable () -> URL? = { SandboxCredentialFetcher.defaultBaseURL() },
        clockNow: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.keychain = keychain
        self.attestService = attestService
        self.baseURLProvider = baseURLProvider
        self.clockNow = clockNow
    }

    private static func defaultBaseURL() -> URL? {
        // Base URL resolves via EnvironmentManager so staging and dev builds
        // target the correct gateway host. The sandbox `config` endpoint is
        // `https://playground.provii.app` by default; the mobile sandbox
        // routes live on the same host under `/api/mobile/sandbox/*`.
        let raw = EnvironmentManager.shared.getConfigApi()
        return URL(string: raw)
    }

    // MARK: - Install id

    func installId() throws -> String {
        if let data = try? keychain.getData(key: Self.installIdKeychainKey, requireAuth: false),
           let existing = String(data: data, encoding: .utf8), !existing.isEmpty {
            return existing
        }
        let newId = Self.generateUuidV7()
        try keychain.save(key: Self.installIdKeychainKey, value: newId, requiresBiometric: false)
        return newId
    }

    // MARK: - Public lifecycle

    /// Returns the cached credential, refreshing or bootstrap-registering as
    /// needed. BLOCKER-1: explicit isExpired check BEFORE needsRefresh so an
    /// expired credential never gets returned as a fallback.
    func currentCredential() async throws -> SandboxCredential {
        if let cached = cachedCredential() {
            // Fresh and not in the refresh window: return immediately.
            if !cached.isExpired && !cached.needsRefresh {
                return cached
            }
            // Fully expired: try refresh first, but if that fails fall
            // through to register() instead of returning the dead credential.
            if cached.isExpired {
                if let refreshed = try? await refresh() {
                    return refreshed
                }
                // Fall through to register().
            } else if cached.needsRefresh {
                // Within 24h window but not yet expired: best-effort slide.
                // On failure, log and return cached (still valid).
                do {
                    return try await refresh()
                } catch {
                    SecureLogger.shared.error("Sandbox credential refresh failed (still valid): \(error.localizedDescription)")
                    return cached
                }
            }
        }
        return try await register()
    }

    /// Runs the full attestation handshake and persists the returned credential.
    func register(platform: String = "ios", appVersion: String = SandboxCredentialFetcher.currentAppVersion()) async throws -> SandboxCredential {
        #if targetEnvironment(simulator)
        throw SandboxCredentialFetcherError.simulatorUnsupported
        #else
        guard attestService.isSupported else {
            throw SandboxCredentialFetcherError.appAttestUnsupported
        }

        let challengeStart = clockNow()
        let nonce = try await fetchChallenge()
        let installUuid = try installId()
        let keyId = try await obtainAppAttestKey()
        let timestampMs = Int64(clockNow().timeIntervalSince1970 * 1000)

        // LOW: Client-side TTL check. The gateway challenge has expires_in: 60s.
        // If more than 45s elapsed since we fetched the challenge, re-fetch to
        // avoid submitting a stale nonce.
        let elapsed = clockNow().timeIntervalSince(challengeStart)
        if elapsed > Self.challengeTtlSafetyMargin {
            throw SandboxCredentialFetcherError.challengeExpired
        }

        // BLOCKER-6: clientDataHash = SHA256(nonce_bytes). The gateway's
        // deriveExpectedNonce does SHA256(authData || SHA256(challenge)) where
        // challenge = raw nonce bytes and clientDataHash = SHA256(challenge).
        let clientDataHash = Self.clientDataHash(nonce: nonce)
        let attestationObject: Data = try await withCheckedThrowingContinuation { continuation in
            attestService.attestKey(keyId, clientDataHash: clientDataHash) { data, error in
                if let error = error {
                    continuation.resume(throwing: SandboxCredentialFetcherError.appAttestAttestation(error))
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: SandboxCredentialFetcherError.invalidResponse)
                    return
                }
                continuation.resume(returning: data)
            }
        }

        let body: [String: Any] = [
            "app_attest_token": Self.base64UrlEncode(attestationObject),
            "app_version": appVersion,
            "attestation_nonce": nonce,
            "install_uuid": installUuid,
            "platform": platform,
            "timestamp_ms": timestampMs
        ]

        let credential = try await postForCredential(path: "/api/mobile/sandbox/register", body: body, signingKey: nil)
        try persist(credential)
        scheduleRefresh(at: credential.expiresAt)
        return credential
    #endif
    }

    /// Slides the TTL. Gateway issues a new credential only if we are within
    /// 24 hours of `expires_at`, otherwise the existing credential is echoed
    /// back verbatim.
    ///
    /// HIGH-8: If the gateway returns 409 or 403 indicating absolute lifetime
    /// exhaustion, throws `lifetimeExhausted` so callers can fall through to
    /// `register()`.
    func refresh() async throws -> SandboxCredential {
        guard let current = cachedCredential() else {
            throw SandboxCredentialFetcherError.missingCredential
        }
        // MobileLifecycleRequestSchema only accepts client_id; install_uuid
        // is stripped by the gateway schema.
        let body: [String: Any] = [
            "client_id": current.clientId
        ]
        let credential = try await postForCredential(
            path: "/api/mobile/sandbox/refresh",
            body: body,
            signingKey: current.hmacSecret,
            clientId: current.clientId
        )
        try persist(credential)
        scheduleRefresh(at: credential.expiresAt)
        return credential
    }

    /// Revokes the current credential on the gateway and wipes local state.
    func revoke() async throws {
        guard let current = cachedCredential() else {
            clearCache()
            cancelScheduledRefresh()
            return
        }
        // MobileLifecycleRequestSchema only accepts client_id.
        let body: [String: Any] = [
            "client_id": current.clientId
        ]
        _ = try await postRaw(
            path: "/api/mobile/sandbox/revoke",
            body: body,
            signingKey: current.hmacSecret,
            clientId: current.clientId
        )
        clearCache()
        cancelScheduledRefresh()
    }

    func clearCache() {
        _ = keychain.delete(key: Self.credentialKeychainKey)
    }

    // MARK: - Background refresh

    /// Registers the refresh task handler. Call from `AppDelegate` init.
    nonisolated static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                do {
                    _ = try await SandboxCredentialFetcher.shared.refresh()
                    refreshTask.setTaskCompleted(success: true)
                } catch {
                    refreshTask.setTaskCompleted(success: false)
                }
            }
        }
    }

    nonisolated func scheduleRefresh(at expiresAt: Date) {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = expiresAt.addingTimeInterval(-24 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
    }

    // MARK: - App Attest key caching

    private func obtainAppAttestKey() async throws -> String {
        if let data = try? keychain.getData(key: Self.appAttestKeyIdKeychainKey, requireAuth: false),
           let existing = String(data: data, encoding: .utf8), !existing.isEmpty {
            return existing
        }
        let keyId: String = try await withCheckedThrowingContinuation { continuation in
            attestService.generateKey { keyId, error in
                if let error = error {
                    continuation.resume(throwing: SandboxCredentialFetcherError.appAttestKeyGeneration(error))
                    return
                }
                guard let keyId = keyId, !keyId.isEmpty else {
                    continuation.resume(throwing: SandboxCredentialFetcherError.invalidResponse)
                    return
                }
                continuation.resume(returning: keyId)
            }
        }
        try keychain.save(key: Self.appAttestKeyIdKeychainKey, value: keyId, requiresBiometric: false)
        return keyId
    }

    // MARK: - HTTP

    private func fetchChallenge() async throws -> String {
        guard let base = baseURLProvider() else {
            throw SandboxCredentialFetcherError.invalidResponse
        }
        let url = base.appendingPathComponent("/api/mobile/sandbox/challenge")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await runRequest(request)
        guard (200...299).contains(response.statusCode) else {
            throw SandboxCredentialFetcherError.httpError(response.statusCode, String(data: data, encoding: .utf8))
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let nonce = object["nonce"] as? String,
            !nonce.isEmpty
        else {
            throw SandboxCredentialFetcherError.invalidChallenge
        }
        return nonce
    }

    private func postForCredential(
        path: String,
        body: [String: Any],
        signingKey: String?,
        clientId: String? = nil
    ) async throws -> SandboxCredential {
        let (data, _) = try await postRaw(path: path, body: body, signingKey: signingKey, clientId: clientId)
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let clientId = object["client_id"] as? String,
            let hmacSecret = object["hmac_secret"] as? String,
            let expiresAtIso = object["expires_at"] as? String,
            let expiresAt = ISO8601DateFormatter.iso8601Fractional.date(from: expiresAtIso)
                ?? ISO8601DateFormatter.iso8601Plain.date(from: expiresAtIso)
        else {
            throw SandboxCredentialFetcherError.invalidResponse
        }
        return SandboxCredential(clientId: clientId, hmacSecret: hmacSecret, expiresAt: expiresAt)
    }

    private func postRaw(
        path: String,
        body: [String: Any],
        signingKey: String?,
        clientId: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let base = baseURLProvider() else {
            throw SandboxCredentialFetcherError.invalidResponse
        }
        let canonical = try JsonCanonicaliser.canonicalise(body)
        let canonicalBytes = Data(canonical.utf8)
        guard canonicalBytes.count <= Self.maxBodyBytes else {
            throw SandboxCredentialFetcherError.invalidResponse
        }

        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = canonicalBytes
        request.timeoutInterval = 15

        // BLOCKER-3: Use the mwallet-sbx/v1 HMAC envelope expected by the
        // gateway. Format: "mwallet-sbx/v1\n{method}\n{path}\n{timestamp}\n{nonce}\n{JCS body bytes}"
        // Headers: X-Mwallet-Auth (structured), X-Mwallet-Sig (hex HMAC tag).
        if let signingKey = signingKey, let clientId = clientId {
            let timestampSeconds = Int64(clockNow().timeIntervalSince1970)
            let nonceHex = Self.generateNonceHex()
            let header = "\(Self.hmacEnvelopeVersion)\nPOST\n\(path)\n\(timestampSeconds)\n\(nonceHex)\n"
            var signingBytes = Data(header.utf8)
            signingBytes.append(canonicalBytes)

            // MED-13: wrap the HMAC key in SensitiveDataHolder for zeroisation.
            let keyHolder = SensitiveDataHolder(Data(signingKey.utf8))
            defer { keyHolder.close() }
            let signature = keyHolder.withUnsafeBytes { keyPtr -> String in
                let keyData = Data(keyPtr)
                let key = SymmetricKey(data: keyData)
                let mac = HMAC<SHA256>.authenticationCode(for: signingBytes, using: key)
                return Data(mac).map { String(format: "%02x", $0) }.joined()
            }

            let authValue = "Mwallet-Sandbox client_id=\(clientId),ts=\(timestampSeconds),nonce=\(nonceHex)"
            request.setValue(authValue, forHTTPHeaderField: "X-Mwallet-Auth")
            request.setValue(signature, forHTTPHeaderField: "X-Mwallet-Sig")
        }

        let (data, response) = try await runRequest(request)

        // HIGH-8: 409 or 403 from refresh/revoke may indicate absolute
        // lifetime exhaustion. Surface as a typed error so callers can fall
        // through to register().
        if response.statusCode == 409 || response.statusCode == 403 {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            if bodyStr.contains("lifetime") || bodyStr.contains("exhausted") {
                throw SandboxCredentialFetcherError.lifetimeExhausted
            }
        }

        guard (200...299).contains(response.statusCode) else {
            throw SandboxCredentialFetcherError.httpError(response.statusCode, String(data: data, encoding: .utf8))
        }
        return (data, response)
    }

    private func runRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw SandboxCredentialFetcherError.invalidResponse
            }
            return (data, http)
        } catch let error as SandboxCredentialFetcherError {
            throw error
        } catch {
            throw SandboxCredentialFetcherError.transport(error)
        }
    }

    // MARK: - Persistence

    private func persist(_ credential: SandboxCredential) throws {
        let data = try JSONEncoder.iso8601.encode(credential)
        try keychain.save(key: Self.credentialKeychainKey, data: data, requiresBiometric: false)
    }

    private func cachedCredential() -> SandboxCredential? {
        guard let data = try? keychain.getData(key: Self.credentialKeychainKey, requireAuth: false) else { return nil }
        return try? JSONDecoder.iso8601.decode(SandboxCredential.self, from: data)
    }

    // MARK: - HMAC envelope constants

    /// Canonical HMAC envelope version matching the gateway at
    /// `mobile-sandbox.ts:125`.
    static let hmacEnvelopeVersion = "mwallet-sbx/v1"

    // MARK: - Client data hash + HMAC

    /// BLOCKER-6: Per Apple's server validation docs the gateway computes
    /// `nonce = SHA256(authData || clientDataHash)` where clientDataHash must
    /// equal `SHA256(challenge)`. The challenge is the raw nonce bytes (the
    /// hex string from the gateway). The install_uuid and timestamp travel in
    /// the register body and are verified separately.
    static func clientDataHash(nonce: String) -> Data {
        let nonceBytes = Data(nonce.utf8)
        return Data(SHA256.hash(data: nonceBytes))
    }

    /// HMAC-SHA256 hex, using CryptoKit.
    /// MED-13: Wraps key data in SensitiveDataHolder for zeroisation.
    static func hmacSha256Hex(key: String, message: String) -> String {
        let keyHolder = SensitiveDataHolder(Data(key.utf8))
        defer { keyHolder.close() }
        return keyHolder.withUnsafeBytes { keyPtr -> String in
            let keyData = Data(keyPtr)
            let messageData = Data(message.utf8)
            let mac = HMAC<SHA256>.authenticationCode(for: messageData, using: SymmetricKey(data: keyData))
            return Data(mac).map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Generate a 32-byte hex nonce for HMAC envelope replay prevention.
    static func generateNonceHex() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            // Fallback: UUID without dashes, doubled for 64 hex chars.
            let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            return uuid + uuid
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - UUID v7

    /// RFC 9562 UUID v7 (48-bit unix-ms, version 7, variant 10).
    static func generateUuidV7() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // Fallback: use arc4random for random bytes instead of returning a v4 UUID.
            // This preserves the v7 format (timestamp + version/variant bits) even when
            // SecRandomCopyBytes is unavailable.
            for i in 0..<bytes.count {
                bytes[i] = UInt8.random(in: 0...255)
            }
        }
        let unixMs = UInt64(Date().timeIntervalSince1970 * 1000)
        bytes[0] = UInt8((unixMs >> 40) & 0xff)
        bytes[1] = UInt8((unixMs >> 32) & 0xff)
        bytes[2] = UInt8((unixMs >> 24) & 0xff)
        bytes[3] = UInt8((unixMs >> 16) & 0xff)
        bytes[4] = UInt8((unixMs >> 8) & 0xff)
        bytes[5] = UInt8(unixMs & 0xff)
        bytes[6] = (bytes[6] & 0x0f) | 0x70
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let h8 = hex.index(hex.startIndex, offsetBy: 8)
        let h12 = hex.index(hex.startIndex, offsetBy: 12)
        let h16 = hex.index(hex.startIndex, offsetBy: 16)
        let h20 = hex.index(hex.startIndex, offsetBy: 20)
        return [
            String(hex[hex.startIndex..<h8]),
            String(hex[h8..<h12]),
            String(hex[h12..<h16]),
            String(hex[h16..<h20]),
            String(hex[h20..<hex.endIndex])
        ].joined(separator: "-")
    }

    // MARK: - Base64url

    static func base64UrlEncode(_ data: Data) -> String {
        let b64 = data.base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Metadata

    static func currentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

// MARK: - Protocol for App Attest injection

/// Thin seam over `DCAppAttestService` so unit tests can stub the API without
/// requiring a physical device. `DCAppAttestService.shared` conforms by
/// inheritance.
protocol AppAttestServicing: Sendable {
    var isSupported: Bool { get }
    func generateKey(completionHandler: @escaping @Sendable (String?, Error?) -> Void)
    func attestKey(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void)
}

extension DCAppAttestService: AppAttestServicing {}

// MARK: - Helpers

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.iso8601Fractional.string(from: date))
        }
        return encoder
    }()
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.iso8601Fractional.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter.iso8601Plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601: \(value)")
        }
        return decoder
    }()
}

extension ISO8601DateFormatter {
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601Plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
