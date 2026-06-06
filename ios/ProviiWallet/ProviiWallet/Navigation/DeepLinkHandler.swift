// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import SwiftUI
import UIKit
import Combine
import CryptoKit
import os.log

/// Handles deep links for Provii Wallet verification and blind attestation flows.
///
/// Supported URL formats:
///   - `provii://verify?d={base64url}` and `provii://attest?d={base64url}` (legacy custom scheme)
///   - `https://provii.app/verify?d={base64url}` and `https://provii.app/attest?d={base64url}` (Universal Links)
///
/// Includes rate limiting, nonce replay prevention with Keychain persistence, payload
/// size caps, URL injection detection, and biometric gating for verification challenges.
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    // MARK: - Rate Limiting
    private let rateLimitWindowMs: Int64 = 60 * 1000    // 1 minute window
    private let maxDeepLinksPerWindow = 10                // Max 10 per minute
    private var rateLimitCounter = 0
    private var rateLimitWindowStart: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    private let rateLimitQueue = DispatchQueue(label: "app.provii.wallet.deeplink.ratelimit")

    // MARK: - Nonce Replay Prevention
    private var processedNonces: [String: Int64] = [:]   // nonce -> timestamp ms
    private let nonceMaxAgeMs: Int64 = 5 * 60 * 1000     // 5 minutes
    private let maxNonceEntries = 1000
    private let nonceQueue = DispatchQueue(label: "app.provii.wallet.deeplink.nonce")

    // MARK: - Payload Size Limits
    private let maxAttestPayloadChars = 1000
    private let maxVerifyPayloadChars = 10000

    // MARK: - Constants
    enum Constants {
        static let schemeProviiWallet = "provii"
        static let schemeHttps = "https"
        static let hostProviiwalletApp = "provii.app"
        static let hostVerify = "verify"
        static let hostAttest = "attest"
        static let pathVerify = "/verify"
        static let pathAttest = "/attest"
        static let paramData = "d"

        /// Get default verify URL from EnvironmentManager
        static var defaultVerifyURL: String {
            EnvironmentManager.shared.verifierVerifyUrl
        }

        /// Get trusted verifier domains based on environment
        static var trustedVerifierDomains: Set<String> {
            var domains = Set([
                "verify.provii.app",
                "invokeprovii.com"  // Demo domain
            ])

            // Add sandbox domains if in sandbox mode
            if EnvironmentManager.shared.isSandboxEnabled {
                domains.insert("sandbox-verify.provii.app")
                domains.insert("sandbox.invokeprovii.com")
            }

            // Add staging/dev domains based on environment
            switch EnvironmentManager.shared.getCurrentEnvironment {
            case "staging":
                domains.insert("staging-verify.provii.app")
            case "development":
                domains.insert("dev-verify.provii.app")
            default:
                break
            }

            return domains
        }
    }

    // MARK: - Published Properties
    @Published var pendingDeepLink: DeepLink?

    /// Sandbox-mode confirmation prompt triggered when an incoming deep-link
    /// carries `?env=sandbox` while the wallet is currently running in
    /// production. Observed by NavigationCoordinator which presents an alert
    /// and calls back into `confirmSandboxPrompt` or `dismissSandboxPrompt`.
    @Published var pendingSandboxPrompt: SandboxPrompt?

    // MARK: - Types
    enum DeepLink: Equatable {
        case verification(challengeData: String)
        case attest(attestData: String)
    }

    /// Source that triggered the sandbox confirmation prompt. The UI copy
    /// differs between the two paths, so the navigation layer needs to know
    /// which one fired.
    ///
    /// - url: query-parameter advisory (`?env=sandbox`). The URL
    ///   itself hints at sandbox but the wallet has not yet attempted to
    ///   decode the challenge.
    /// - challenge: required `environment` field inside the decoded
    ///   challenge payload. The gateway explicitly marked this challenge as
    ///   sandbox-only, so the copy is sterner ("Sandbox challenge received").
    enum SandboxPromptSource: Equatable {
        case url
        case challenge
    }

    /// Payload shown to the user when a sandbox deep-link arrives while the
    /// wallet is in production mode. Holds the original URL so the handler
    /// can resume processing if the user accepts.
    struct SandboxPrompt: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let source: SandboxPromptSource
    }

    struct ChallengePayload {
        let challengeId: String
        let rpChallenge: String
        let cutoffDays: Int
        let verifyingKeyId: Int
        let submitSecret: String
        /// required `"environment"` field. Must be `"sandbox"` or
        /// `"production"`. A missing or unrecognised value is treated as a
        /// malformed payload, not a legacy-compat defensive default. The
        /// gateway always emits this field, so
        /// absence is a protocol violation.
        let environment: String
        let verifyUrl: String?
        let expiresAt: Int64?
        let proofDirection: String?

        var json: [String: Any] {
            var dict: [String: Any] = [
                "challenge_id": challengeId,
                "rp_challenge": rpChallenge,
                "cutoff_days": cutoffDays,
                "verifying_key_id": verifyingKeyId,
                "submit_secret": submitSecret,
                "environment": environment
            ]
            if let verifyUrl = verifyUrl {
                dict["verify_url"] = verifyUrl
            }
            if let expiresAt = expiresAt {
                dict["expires_at"] = expiresAt
            }
            if let proofDirection = proofDirection {
                dict["proof_direction"] = proofDirection
            }
            return dict
        }
    }

    private let logger = Logger(subsystem: "app.provii.wallet", category: "DeepLinkHandler")

    // MARK: - Keychain Persistence Keys

    /// Base Keychain key for the production nonce bucket.
    private static let nonceKeychainKeyProduction = "deeplink_processed_nonces"

    /// Base Keychain key for the sandbox nonce bucket (). Nonce state
    /// is tracked per environment so a replay in sandbox cannot block a
    /// production link (and vice versa).
    private static let nonceKeychainKeySandbox = "deeplink_processed_nonces_sandbox"

    /// Returns the Keychain key for the currently-active environment.
    /// Derived at read time so a runtime toggle of the sandbox flag routes
    /// subsequent reads and writes to the correct bucket.
    private var nonceKeychainKey: String {
        Self.currentNonceKeychainKey()
    }

    /// Resolve the Keychain key for the currently-active environment. Exposed
    /// at module-internal visibility so unit tests (`@testable import`) can
    /// pin the env-namespacing contract without reaching into private state.
    static func currentNonceKeychainKey() -> String {
        EnvironmentManager.shared.isSandboxEnabled
            ? nonceKeychainKeySandbox
            : nonceKeychainKeyProduction
    }

    /// Environment-change observer. Releases the previous environment's
    /// in-memory nonce cache so we do not cross-contaminate buckets.
    private var environmentObserver: NSObjectProtocol?

    private init() {
        loadPersistedNonces()

        // Re-load persisted nonces from the (possibly new) Keychain bucket
        // whenever the environment toggles at runtime. The Keychain-backed
        // store remains the source of truth; the in-memory cache is rebuilt
        // from the correct bucket.
        environmentObserver = NotificationCenter.default.addObserver(
            forName: .proviiEnvironmentChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshNonceStoreForEnvironment()
        }
    }

    deinit {
        if let environmentObserver = environmentObserver {
            NotificationCenter.default.removeObserver(environmentObserver)
        }
    }

    /// Clear the in-memory nonce cache and reload from the Keychain bucket
    /// associated with the currently-active environment. Called in response
    /// to `proviiEnvironmentChanged`.
    private func refreshNonceStoreForEnvironment() {
        nonceQueue.sync {
            processedNonces.removeAll()
        }
        loadPersistedNonces()
        logger.info("Nonce store refreshed for environment: \(EnvironmentManager.shared.getCurrentEnvironment)")
    }

    // MARK: - Nonce Persistence

    /// Load persisted nonces from Keychain on init so replay protection survives app restart.
    private func loadPersistedNonces() {
        nonceQueue.sync {
            guard let data = KeychainBridge.shared.retrieveSecure(
                key: nonceKeychainKey,
                requireBiometrics: false
            ) else {
                return
            }

            guard let decoded = try? JSONDecoder().decode([String: Int64].self, from: data) else {
                return
            }

            // Only load entries that have not expired
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let cutoff = now - nonceMaxAgeMs
            processedNonces = decoded.filter { $0.value >= cutoff }
        }
    }

    /// Persist current nonces to Keychain (call within nonceQueue).
    private func persistNonces() {
        guard let data = try? JSONEncoder().encode(processedNonces) else {
            return
        }

        _ = KeychainBridge.shared.storeSecure(
            key: nonceKeychainKey,
            data: data,
            useSecureEnclave: false,
            requireBiometrics: false
        )
    }

    // MARK: - Rate Limiting

    /// Check if deep link processing should be blocked due to rate limiting.
    /// Thread-safe via dedicated queue.
    private func isRateLimited() -> Bool {
        rateLimitQueue.sync {
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            if now - rateLimitWindowStart > rateLimitWindowMs {
                rateLimitWindowStart = now
                rateLimitCounter = 1
                return false
            }

            rateLimitCounter += 1
            if rateLimitCounter > maxDeepLinksPerWindow {
                logger.warning("Deep link rate limited: \(self.rateLimitCounter) requests in window")
                logSecurityEvent("deeplink_rate_limited", details: [
                    "count": rateLimitCounter,
                    "max": maxDeepLinksPerWindow
                ])
                return true
            }

            return false
        }
    }

    // MARK: - Nonce Replay Prevention

    /// Check if a nonce/challenge_id has been processed before (replay attack).
    /// Records the nonce if not previously seen.
    private func isReplayAttack(nonce: String) -> Bool {
        nonceQueue.sync {
            cleanupExpiredNonces()

            let now = Int64(Date().timeIntervalSince1970 * 1000)

            if let previousTimestamp = processedNonces[nonce] {
                let ageMs = now - previousTimestamp
                logger.warning("Replay attack detected: nonce processed \(ageMs)ms ago")
                logSecurityEvent("replay_attack_blocked", details: [
                    "nonce_prefix": String(nonce.prefix(16)) + "...",
                    "age_ms": ageMs
                ])
                return true
            }

            processedNonces[nonce] = now
            persistNonces()
            return false
        }
    }

    /// Clean up expired nonce entries. Called within nonceQueue.
    private func cleanupExpiredNonces() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let cutoff = now - nonceMaxAgeMs

        let beforeCount = processedNonces.count
        processedNonces = processedNonces.filter { $0.value >= cutoff }

        if processedNonces.count > maxNonceEntries {
            let sorted = processedNonces.sorted { $0.value < $1.value }
            let toRemove = sorted.prefix(sorted.count / 2)
            for entry in toRemove {
                processedNonces.removeValue(forKey: entry.key)
            }
        }

        // Persist if any entries were evicted
        if processedNonces.count != beforeCount {
            persistNonces()
        }
    }

    /// Clear nonce tracking (for testing).
    func clearNonceTracking() {
        nonceQueue.sync {
            processedNonces.removeAll()
            _ = KeychainBridge.shared.deleteSecure(key: nonceKeychainKey)
        }
    }

    /// Reset the deep-link rate-limit window (for testing). A unit-test suite
    /// issues many deep links in quick succession, which would otherwise trip
    /// the production 10-per-minute limit and block later cases.
    func resetRateLimit() {
        rateLimitQueue.sync {
            rateLimitWindowStart = Int64(Date().timeIntervalSince1970 * 1000)
            rateLimitCounter = 0
        }
    }

    /// Read-only probe for whether a nonce has been recorded. Used by the
    /// tests to pin that the sandbox-on-production rejection path
    /// does not consume the challenge_id, so a subsequent accept (after the
    /// user confirms the prompt) can route normally.
    func hasProcessedNonce(_ nonce: String) -> Bool {
        return nonceQueue.sync { processedNonces[nonce] != nil }
    }

    /// Get security stats for debugging.
    func getSecurityStats() -> [String: Any] {
        var stats: [String: Any] = [:]
        nonceQueue.sync {
            stats["tracked_nonces"] = processedNonces.count
        }
        rateLimitQueue.sync {
            stats["rate_limit_count"] = rateLimitCounter
            let remaining = max(0, rateLimitWindowMs - (Int64(Date().timeIntervalSince1970 * 1000) - rateLimitWindowStart))
            stats["rate_limit_window_remaining_ms"] = remaining
        }
        return stats
    }

    // MARK: - URL Structure Validation

    /// Validate URL structure to prevent injection attacks.
    private func isValidUrlStructure(_ urlString: String) -> Bool {
        if urlString.isEmpty || urlString.count > 2048 {
            logger.warning("URL validation failed: invalid length \(urlString.count)")
            return false
        }

        let suspiciousPatterns = [
            "javascript:", "data:", "vbscript:",
            "<script", "%3cscript",
            "\\x", "\\u",
            "\n", "\r", "%0a", "%0d"
        ]

        let urlLower = urlString.lowercased()
        for pattern in suspiciousPatterns {
            if urlLower.contains(pattern) {
                logger.warning("URL validation failed: suspicious pattern detected")
                logSecurityEvent("url_injection_blocked", details: [
                    "pattern": pattern
                ])
                return false
            }
        }

        return true
    }

    // MARK: - Public Methods

    /// Handle deep links from SwiftUI's onOpenURL. Returns true if the deep link was
    /// handled successfully. Supports both legacy custom scheme and HTTPS Universal Links.
    ///
    /// MASVS PLATFORM-1: Validates all incoming URLs before processing.
    func handleURL(_ url: URL) -> Bool {
        // SECURITY: Rate limiting and structure validation
        guard passesPreValidation(url) else { return false }

        // MASVS PLATFORM-1: Validate deep link before processing
        guard passesDeepLinkValidation(url) else { return false }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("Failed to parse URL components")
            return false
        }

        // Check sandbox environment mismatch
        if shouldDeferForSandboxPrompt(url: url, components: components) {
            return false
        }

        return routeDeepLink(components: components)
    }

    private func passesPreValidation(_ url: URL) -> Bool {
        if isRateLimited() {
            logger.warning("Deep link rejected: rate limit exceeded")
            return false
        }
        if !isValidUrlStructure(url.absoluteString) {
            logger.warning("Deep link rejected: invalid URL structure")
            return false
        }
        let redactedUrl = "\(url.scheme ?? "")://\(url.host ?? "")\(url.path)"
        logger.info("Handling URL: \(redactedUrl) (payload size: \(url.query?.count ?? 0) chars, environment: \(EnvironmentManager.shared.getCurrentEnvironment))")
        return true
    }

    private func passesDeepLinkValidation(_ url: URL) -> Bool {
        let validationResult = DeepLinkValidator.shared.validate(url)
        switch validationResult {
        case .rejected(let reason):
            logger.warning("Deep link rejected by validator: \(reason)")
            logSecurityEvent("deeplink_validation_failed", details: [
                "reason": reason,
                "scheme": url.scheme ?? "nil",
                "host": url.host ?? "nil",
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        case .accepted:
            logger.info("Deep link validated successfully")
            return true
        }
    }

    private func shouldDeferForSandboxPrompt(url: URL, components: URLComponents) -> Bool {
        let envValue = components.queryItems?
            .first(where: { $0.name.lowercased() == "env" })?
            .value?
            .lowercased()

        guard envValue == "sandbox", !EnvironmentManager.shared.isSandboxEnabled else {
            return false
        }

        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        logger.info("Deep link carries env=sandbox but wallet is production; prompting user")
        logSecurityEvent("deeplink_sandbox_prompt_presented", details: [
            "scheme": scheme ?? "nil",
            "host": host ?? "nil"
        ])

        DispatchQueue.main.async { [weak self] in
            self?.pendingSandboxPrompt = SandboxPrompt(url: url, source: .url)
            UIAccessibility.post(
                notification: .announcement,
                argument: LocalizedString.deeplinkSandboxPromptAnnouncement.localized
            )
        }
        return true
    }

    private func routeDeepLink(components: URLComponents) -> Bool {
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let path = components.path.lowercased()

        switch scheme {
        case Constants.schemeProviiWallet:
            switch host {
            case Constants.hostVerify:
                return handleVerifyDeepLink(components)
            case Constants.hostAttest:
                return handleAttestDeepLink(components)
            default:
                logger.warning("Unknown deep link host: \(host ?? "nil")")
                return false
            }

        case Constants.schemeHttps:
            guard host == Constants.hostProviiwalletApp else {
                logger.warning("Unknown Universal Link host: \(host ?? "nil")")
                return false
            }
            switch path {
            case Constants.pathVerify:
                return handleVerifyDeepLink(components)
            case Constants.pathAttest:
                return handleAttestDeepLink(components)
            default:
                logger.warning("Unknown Universal Link path: \(path)")
                return false
            }

        default:
            logger.warning("Unsupported URL scheme: \(scheme ?? "nil")")
            return false
        }
    }

    /// Clear any pending deep link.
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    /// Confirm the sandbox prompt, enable sandbox mode, and re-dispatch the
    /// originally-received deep link so the handler can route it. Called by
    /// the UI layer after the user taps the primary action on the sandbox
    /// confirmation sheet.
    ///
    /// SECURITY: Enabling sandbox switches all API endpoints to the sandbox
    /// environment. The user's explicit confirmation is the consent gate.
    func confirmSandboxPrompt() {
        guard let prompt = pendingSandboxPrompt else { return }
        pendingSandboxPrompt = nil

        logSecurityEvent("deeplink_sandbox_prompt_confirmed", details: [:])
        EnvironmentManager.shared.enableSandbox(true)

        // Re-enter the handler. The env check at the top will now pass
        // because sandbox is enabled, so the URL routes normally.
        _ = handleURL(prompt.url)
    }

    /// Dismiss the sandbox prompt and drop the pending deep link. Called by
    /// the UI layer when the user taps the secondary action on the sandbox
    /// confirmation sheet.
    func dismissSandboxPrompt() {
        guard pendingSandboxPrompt != nil else { return }
        pendingSandboxPrompt = nil
        logSecurityEvent("deeplink_sandbox_prompt_cancelled", details: [:])
    }

    // MARK: - Private Methods

    /// Handle verification challenge deep link.
    /// `provii://verify?d=<base64url_encoded_json>`
    ///
    /// SECURITY: Biometric consent is enforced downstream in
    /// WalletRepository.createAgeProof() before any proof is generated.
    private func handleVerifyDeepLink(_ components: URLComponents) -> Bool {
        let queryItems = components.queryItems ?? []
        guard let encodedData = queryItems.first(where: { $0.name == Constants.paramData })?.value,
              !encodedData.isEmpty else {
            logger.error("Verify deep link missing 'd' parameter")
            logSecurityEvent("verification_challenge_invalid", details: [
                "reason": "missing_d_parameter",
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        }

        // SECURITY: Payload size limit
        if encodedData.count > maxVerifyPayloadChars {
            logger.error("Verify payload too large: \(encodedData.count) chars")
            logSecurityEvent("verify_payload_size_exceeded", details: [
                "encoded_length": encodedData.count,
                "max_allowed": maxVerifyPayloadChars
            ])
            return false
        }

        do {
            // Decode base64url to JSON string
            let json = try decodeBase64Url(encodedData)

            // SECURITY: Cap decoded JSON size to prevent memory exhaustion from
            // crafted deep links. The encoded size is already limited, but base64
            // decoding can produce up to 3/4 of the encoded length. A 16KB cap on
            // decoded JSON is well above any legitimate challenge payload.
            let maxDecodedJsonBytes = 16_384
            if json.utf8.count > maxDecodedJsonBytes {
                logger.error("Decoded verify JSON too large: \(json.utf8.count) bytes (max \(maxDecodedJsonBytes))")
                logSecurityEvent("verify_decoded_size_exceeded", details: [
                    "decoded_length": json.utf8.count,
                    "max_allowed": maxDecodedJsonBytes
                ])
                return false
            }

            logger.info("Deep link (verify) received, payload size: \(json.count) bytes")

            // Parse and validate the challenge payload
            guard let challengePayload = parseAndValidateChallengePayload(json) else {
                logger.error("Failed to parse or validate challenge payload")
                return false
            }

            // sandbox-marked challenge received while the wallet is
            // running in production. Raise the sandbox confirmation prompt
            // (with the challenge-specific copy) and defer routing. If the
            // user accepts, `confirmSandboxPrompt` enables sandbox and
            // re-dispatches the URL; the second pass will find
            // `isSandboxEnabled == true` and skip this branch.
            //
            // The prompt runs BEFORE the replay check so the challenge_id
            // does not get consumed by a rejected attempt.
            if challengePayload.environment == "sandbox",
               !EnvironmentManager.shared.isSandboxEnabled,
               let sourceUrl = components.url {
                logger.info("Challenge payload is sandbox-marked but wallet is production; prompting user")
                logSecurityEvent("challenge_sandbox_prompt_presented", details: [
                    "challenge_id": challengePayload.challengeId,
                    "environment": EnvironmentManager.shared.getCurrentEnvironment
                ])

                DispatchQueue.main.async { [weak self] in
                    self?.pendingSandboxPrompt = SandboxPrompt(url: sourceUrl, source: .challenge)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: LocalizedString.challengeSandboxPromptAnnouncement.localized
                    )
                }
                return false
            }

            // SECURITY: Nonce replay check using challenge_id
            if isReplayAttack(nonce: challengePayload.challengeId) {
                logger.error("Verification replay attack detected for challenge")
                logSecurityEvent("verify_replay_blocked", details: [
                    "challenge_id": challengePayload.challengeId,
                    "environment": EnvironmentManager.shared.getCurrentEnvironment
                ])
                return false
            }

            // Route directly to the verification screen. The biometric gate
            // in WalletRepository.createAgeProof() is the single point of consent
            // before any proof is generated. No additional prompt needed here.
            DispatchQueue.main.async { [weak self] in
                self?.pendingDeepLink = .verification(challengeData: json)
            }

            // `wallet_env` reports which env the wallet processed
            // THIS challenge under. For a sandbox-marked challenge that
            // reached this branch, the user already confirmed the sandbox
            // prompt and the wallet is now in sandbox; for a production
            // challenge, the wallet is in production. Named distinctly from
            // the surrounding `environment` field so upstream consumers can
            // differentiate "wallet's current env" from "env used for this
            // challenge" without relying on temporal correlation.
            logSecurityEvent("verification_challenge_accepted", details: [
                "challenge_id": challengePayload.challengeId,
                "verifier": URL(string: challengePayload.verifyUrl ?? Constants.defaultVerifyURL)?.host ?? "unknown",
                "environment": EnvironmentManager.shared.getCurrentEnvironment,
                "wallet_env": EnvironmentManager.shared.getCurrentEnvironment,
                "challenge_env": challengePayload.environment
            ])

            return true

        } catch {
            logger.error("Failed to handle verification deep link: \(error)")
            logSecurityEvent("verification_challenge_failed", details: [
                "error": error.localizedDescription,
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        }
    }

    /// Handle blind attestation deep link.
    /// `provii://attest?d=<base64_attestation>`
    ///
    /// The attestation contains a signed DOB from a trusted issuer (officer/sandbox).
    /// The wallet will generate r_bits locally and call /v1/issuance/blind.
    private func handleAttestDeepLink(_ components: URLComponents) -> Bool {
        let queryItems = components.queryItems ?? []

        guard let encodedData = queryItems.first(where: { $0.name == Constants.paramData })?.value,
              !encodedData.isEmpty else {
            logger.error("Attest deep link missing 'd' parameter")
            logSecurityEvent("attestation_invalid", details: [
                "reason": "missing_d_parameter",
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        }

        // SECURITY: Payload size limit
        if encodedData.count > maxAttestPayloadChars {
            logger.warning("Attest payload too large: \(encodedData.count) chars")
            logSecurityEvent("attest_payload_size_exceeded", details: [
                "data_length": encodedData.count,
                "max_allowed": maxAttestPayloadChars
            ])
            return false
        }

        // SECURITY: Validate base64url format
        if !isValidBase64Url(encodedData) {
            logger.warning("Attest data is not valid base64url")
            logSecurityEvent("attestation_invalid", details: [
                "reason": "invalid_base64url",
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        }

        // SECURITY: Replay check using deterministic SHA-256 hash (not Swift's hashValue which is randomised per process)
        let attestHash = SHA256.hash(data: Data(encodedData.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        if isReplayAttack(nonce: "attest:\(attestHash)") {
            logger.warning("Attestation replay attack detected")
            logSecurityEvent("attest_replay_blocked", details: [
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        }

        do {
            // Decode base64url to get attestation data
            let attestationData = try decodeBase64Url(encodedData)
            logger.info("Deep link (attest) received, payload size: \(attestationData.count) bytes")

            // Store the deep link for navigation
            DispatchQueue.main.async { [weak self] in
                self?.pendingDeepLink = .attest(attestData: attestationData)
            }

            logSecurityEvent("attestation_accepted", details: [
                "payload_size": attestationData.count,
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])

            return true

        } catch {
            logger.error("Failed to handle attestation deep link: \(error)")
            logSecurityEvent("attestation_failed", details: [
                "error": error.localizedDescription,
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return false
        }
    }

    /// Parse and validate challenge payload from JSON.
    private func parseAndValidateChallengePayload(_ json: String) -> ChallengePayload? {
        guard let data = json.data(using: .utf8) else {
            logger.error("Failed to convert JSON string to data")
            return nil
        }

        do {
            guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.error("Failed to parse JSON as dictionary")
                return nil
            }

            // Check required fields
            guard let challengeId = payload["challenge_id"] as? String, !challengeId.isEmpty else {
                logger.error("Invalid or missing challenge_id")
                return nil
            }

            guard let rpChallenge = payload["rp_challenge"] as? String, rpChallenge.count == 43 else {
                logger.error("Invalid rp_challenge length")
                return nil
            }

            guard let submitSecret = payload["submit_secret"] as? String, submitSecret.count == 43 else {
                logger.error("Invalid submit_secret length")
                return nil
            }

            guard let cutoffDays = payload["cutoff_days"] as? Int,
                  let verifyingKeyId = payload["verifying_key_id"] as? Int else {
                logger.error("Missing required numeric fields")
                return nil
            }

            guard let environment = validateEnvironmentField(payload) else {
                return nil
            }

            // Validate verify_url if provided
            let verifyUrl = payload["verify_url"] as? String
            if let verifyUrl = verifyUrl, !verifyUrl.isEmpty, !isValidVerifyUrl(verifyUrl) {
                logger.error("Untrusted verify URL: \(verifyUrl)")
                return nil
            }

            // Check expiration if provided
            let expiresAt = payload["expires_at"] as? Int64
            guard !isChallengeExpired(expiresAt) else {
                return nil
            }

            let proofDirection = payload["proof_direction"] as? String

            return ChallengePayload(
                challengeId: challengeId,
                rpChallenge: rpChallenge,
                cutoffDays: cutoffDays,
                verifyingKeyId: verifyingKeyId,
                submitSecret: submitSecret,
                environment: environment,
                verifyUrl: verifyUrl,
                expiresAt: expiresAt,
                proofDirection: proofDirection
            )

        } catch {
            logger.error("Failed to parse challenge payload: \(error)")
            return nil
        }
    }

    /// Check if a challenge has expired based on its `expires_at` timestamp.
    private func isChallengeExpired(_ expiresAt: Int64?) -> Bool {
        guard let expiresAt = expiresAt, expiresAt > 0 else { return false }
        let now = Int64(Date().timeIntervalSince1970)
        if expiresAt < now {
            logger.error("Challenge has expired")
            return true
        }
        return false
    }

    /// Validate the `environment` field from a challenge payload dictionary.
    /// Returns the validated lowercase environment string, or nil if invalid.
    private func validateEnvironmentField(_ payload: [String: Any]) -> String? {
        guard let environmentRaw = payload["environment"] as? String else {
            logger.error("Missing required environment field in challenge payload")
            logSecurityEvent("verification_challenge_invalid", details: [
                "reason": "missing_environment_field",
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return nil
        }
        let environment = environmentRaw.lowercased()
        guard environment == "sandbox" || environment == "production" else {
            logger.error("Invalid environment value in challenge payload")
            logSecurityEvent("verification_challenge_invalid", details: [
                "reason": "invalid_environment_value",
                "environment": EnvironmentManager.shared.getCurrentEnvironment
            ])
            return nil
        }
        return environment
    }

    /// Decode base64url string to UTF-8 string.
    private func decodeBase64Url(_ encoded: String) throws -> String {
        // Convert base64url to base64
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64) else {
            throw DeepLinkError.invalidBase64
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw DeepLinkError.invalidUTF8
        }

        return string
    }

    /// Encode string to base64url.
    private func encodeBase64Url(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }

        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Validate that the verify URL is from a trusted domain.
    private func isValidVerifyUrl(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            logger.warning("Invalid URL format: \(urlString)")
            return false
        }

        // Must be HTTPS (allow HTTP for localhost/testing)
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()

        if scheme != "https" {
            #if DEBUG
            // Allow HTTP for localhost testing only in debug builds
            if scheme == "http" && (host == "localhost" || host == "127.0.0.1") {
                return true
            }
            #endif
            logger.warning("Verify URL not HTTPS: \(urlString)")
            return false
        }

        guard let host = host else {
            logger.warning("Verify URL has no host: \(urlString)")
            return false
        }

        #if DEBUG
        // Allow localhost for testing only in debug builds
        if host == "localhost" || host == "127.0.0.1" {
            return true
        }
        #endif

        // Check if host is in trusted list
        let isValid = Constants.trustedVerifierDomains.contains { trustedDomain in
            host == trustedDomain || host.hasSuffix(".\(trustedDomain)")
        }

        if !isValid {
            logger.warning("Verify URL host not trusted: \(host) (environment: \(EnvironmentManager.shared.getCurrentEnvironment))")
        }

        return isValid
    }

    /// Validate that a string is valid base64url encoding.
    /// Base64url uses: A-Z, a-z, 0-9, -, _ (no padding).
    private func isValidBase64Url(_ encoded: String) -> Bool {
        // Should not be empty
        guard !encoded.isEmpty else {
            return false
        }

        // Base64url character set: A-Z, a-z, 0-9, -, _
        let base64UrlCharacterSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

        // Should only contain valid base64url characters
        guard encoded.rangeOfCharacter(from: base64UrlCharacterSet.inverted) == nil else {
            logger.warning("HMAC contains invalid base64url characters")
            return false
        }

        // Should not have padding (base64url does not use padding)
        if encoded.contains("=") {
            logger.warning("HMAC contains padding, not valid base64url")
            return false
        }

        // HMAC-SHA256 produces 32 bytes = 43 base64url chars (without padding)
        // Allow some flexibility for different hash algorithms but warn if unusual
        if encoded.count < 20 || encoded.count > 100 {
            logger.warning("HMAC length unusual: \(encoded.count) chars (expected ~43 for SHA256)")
        }

        return true
    }

    // MARK: - Public Creation Methods

    /// Create a verification deep link (for testing/sharing).
    func createVerificationDeepLink(
        challengeId: String,
        rpChallenge: String,
        cutoffDays: Int,
        verifyingKeyId: Int,
        submitSecret: String,
        environment: String? = nil,
        verifyUrl: String? = nil,
        expiresAt: Int64? = nil,
        proofDirection: String? = nil
    ) -> String {
        let payload = ChallengePayload(
            challengeId: challengeId,
            rpChallenge: rpChallenge,
            cutoffDays: cutoffDays,
            verifyingKeyId: verifyingKeyId,
            submitSecret: submitSecret,
            environment: environment ?? EnvironmentManager.shared.getCurrentEnvironment,
            verifyUrl: verifyUrl ?? Constants.defaultVerifyURL,
            expiresAt: expiresAt,
            proofDirection: proofDirection
        )

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload.json)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return ""
            }

            let encoded = encodeBase64Url(jsonString)
            return "provii://verify?d=\(encoded)"

        } catch {
            logger.error("Failed to create verification deep link: \(error)")
            return ""
        }
    }

    // MARK: - Security Logging

    /// Security audit logging.
    private func logSecurityEvent(_ event: String, details: [String: Any]) {
        let detailsString = details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        logger.info("SECURITY_EVENT: \(event) - \(detailsString)")

        // In production, send to security monitoring service
        // SecurityMonitor.shared.logEvent(event, details: details)
    }
}

// MARK: - Error Types

enum DeepLinkError: LocalizedError {
    case invalidBase64
    case invalidUTF8
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return LocalizedString.errorInvalidBase64.localized
        case .invalidUTF8:
            return LocalizedString.errorInvalidUtf8.localized
        case .invalidPayload:
            return LocalizedString.errorInvalidPayload.localized
        }
    }
}
