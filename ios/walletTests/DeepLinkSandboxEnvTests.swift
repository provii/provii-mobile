// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

/// Unit tests for the `?env=sandbox` advisory query parameter ().
///
/// The validator does not reject a deep-link based on its env value: the
/// allowlist treats env purely as advisory, and the sheet UX surfaced by
/// `pendingSandboxPrompt` is the consent gate. These tests pin that contract
/// so a future change cannot silently start rejecting env values.
final class DeepLinkSandboxEnvTests: XCTestCase {

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()

        // Start every test in production so `?env=sandbox` trips the prompt
        // path rather than being absorbed by an already-sandbox wallet.
        if EnvironmentManager.shared.isSandboxEnabled {
            EnvironmentManager.shared.enableSandbox(false)
        }

        DeepLinkHandler.shared.clearNonceTracking()
        DeepLinkHandler.shared.dismissSandboxPrompt()
        DeepLinkHandler.shared.resetRateLimit()
    }

    override func tearDown() {
        // Leave the singleton state clean so sibling test classes observe
        // production.
        if EnvironmentManager.shared.isSandboxEnabled {
            EnvironmentManager.shared.enableSandbox(false)
        }
        DeepLinkHandler.shared.dismissSandboxPrompt()
        DeepLinkHandler.shared.clearNonceTracking()
        super.tearDown()
    }

    // MARK: - Env parameter behaviour

    func testEnvSandboxTriggersPromptInsteadOfImmediateRouting() {
        let encoded = base64UrlEncode(challengePayload(id: "env-sandbox-1"))
        let url = URL(string: "provii://verify?env=sandbox&d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(handled, "Sandbox env must defer routing behind the prompt")

        // `pendingSandboxPrompt` is published asynchronously on the main queue.
        let promptRaised = expectation(description: "sandbox prompt raised")
        DispatchQueue.main.async {
            XCTAssertNotNil(
                DeepLinkHandler.shared.pendingSandboxPrompt,
                "Sandbox env must raise the prompt state for the UI to observe"
            )
            promptRaised.fulfill()
        }
        wait(for: [promptRaised], timeout: 1.0)
    }

    func testEnvProductionIsToleratedAndRoutesNormally() {
        let encoded = base64UrlEncode(challengePayload(id: "env-production-1"))
        let url = URL(string: "provii://verify?env=production&d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertTrue(handled, "env=production must route without prompting")
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "env=production must not raise the sandbox prompt"
        )
    }

    func testMissingEnvIsToleratedAndRoutesNormally() {
        let encoded = base64UrlEncode(challengePayload(id: "env-missing-1"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertTrue(handled, "Missing env must route without prompting")
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Missing env must not raise the sandbox prompt"
        )
    }

    func testGarbageEnvWithInjectionMetacharsIsRejectedUpstream() {
        // Pinned behaviour: env values containing injection metachars are
        // rejected by the upstream `DeepLinkValidator` (XSS/template-injection
        // filter), not by the env logic. The validator is advisory on env
        // meaning only; it still enforces the global injection blocklist.
        let encoded = base64UrlEncode(challengePayload(id: "env-garbage-1"))
        let url = URL(string: "provii://verify?env=%24%7Bjndi%7D&d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(
            handled,
            "Garbage env containing JNDI-style metachars must be rejected by the upstream injection filter"
        )
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Garbage env must not raise the sandbox prompt"
        )
    }

    func testPlainGarbageEnvValueRoutesNormally() {
        let encoded = base64UrlEncode(challengePayload(id: "env-garbage-2"))
        let url = URL(string: "provii://verify?env=banana&d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertTrue(
            handled,
            "Non-sandbox env values are advisory-only and must route normally"
        )
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Non-sandbox env must not raise the sandbox prompt"
        )
    }

    func testEnvSandboxIsMatchedCaseInsensitively() {
        let encoded = base64UrlEncode(challengePayload(id: "env-sandbox-case-1"))
        let url = URL(string: "provii://verify?env=SANDBOX&d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(handled, "env=SANDBOX must be treated like env=sandbox")

        let promptRaised = expectation(description: "uppercase sandbox prompt raised")
        DispatchQueue.main.async {
            XCTAssertNotNil(
                DeepLinkHandler.shared.pendingSandboxPrompt,
                "Uppercase env=SANDBOX must raise the prompt"
            )
            promptRaised.fulfill()
        }
        wait(for: [promptRaised], timeout: 1.0)
    }

    func testEnvSandboxOnAlreadySandboxWalletDoesNotPrompt() {
        EnvironmentManager.shared.enableSandbox(true)
        defer { EnvironmentManager.shared.enableSandbox(false) }

        let encoded = base64UrlEncode(challengePayload(id: "env-sandbox-already-1"))
        let url = URL(string: "provii://verify?env=sandbox&d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertTrue(
            handled,
            "env=sandbox while already in sandbox must route normally"
        )
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "env=sandbox while already in sandbox must not raise the prompt"
        )
    }

    func testDismissSandboxPromptDropsThePendingState() {
        let encoded = base64UrlEncode(challengePayload(id: "env-dismiss-1"))
        let url = URL(string: "provii://verify?env=sandbox&d=\(encoded)")!

        _ = DeepLinkHandler.shared.handleURL(url)

        let promptRaised = expectation(description: "prompt raised before dismiss")
        DispatchQueue.main.async {
            XCTAssertNotNil(DeepLinkHandler.shared.pendingSandboxPrompt)
            promptRaised.fulfill()
        }
        wait(for: [promptRaised], timeout: 1.0)

        DeepLinkHandler.shared.dismissSandboxPrompt()

        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "dismissSandboxPrompt must clear the prompt state"
        )
    }

    // MARK: - Challenge payload `environment` field (/ )

    func testChallengeEnvironmentMissingIsRejected() {
        // `environment` is a required field. The gateway always
        // emits it, so absence is a protocol
        // violation, not something to paper over with a defensive default.
        let encoded = base64UrlEncode(challengePayloadWithoutEnv(id: "env-field-missing-1"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(handled, "Challenge payload missing environment must be rejected")
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Missing environment must not raise the sandbox prompt"
        )
    }

    func testChallengeEnvironmentInvalidValueIsRejected() {
        // only `sandbox` and `production` are valid. Any other
        // value is a malformed payload. No defensive mapping.
        let encoded = base64UrlEncode(challengePayloadWithEnv(id: "env-field-bad-1", env: "staging"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(handled, "Challenge payload with invalid environment must be rejected")
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Invalid environment must not raise the sandbox prompt"
        )
    }

    func testChallengeEnvironmentProductionRoutesNormally() {
        let encoded = base64UrlEncode(challengePayloadWithEnv(id: "env-field-prod-1", env: "production"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertTrue(handled, "Production-marked challenge on production wallet must route")
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Production-marked challenge must not raise the sandbox prompt"
        )
    }

    func testChallengeEnvironmentSandboxOnProductionWalletRaisesChallengePrompt() {
        // sandbox-marked challenge on a production-toggled wallet
        // must raise the challenge-specific prompt (distinct from the W13
        // URL-level prompt) and defer routing without consuming the nonce.
        let encoded = base64UrlEncode(challengePayloadWithEnv(id: "env-field-sandbox-1", env: "sandbox"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(handled, "Sandbox-marked challenge on production must defer routing")

        let promptRaised = expectation(description: "challenge sandbox prompt raised")
        DispatchQueue.main.async {
            guard let prompt = DeepLinkHandler.shared.pendingSandboxPrompt else {
                XCTFail("Sandbox-marked challenge must raise the prompt")
                promptRaised.fulfill()
                return
            }
            XCTAssertEqual(
                prompt.source,
                .challenge,
                "Sandbox-marked challenge must raise the challenge-specific prompt"
            )
            promptRaised.fulfill()
        }
        wait(for: [promptRaised], timeout: 1.0)
    }

    func testChallengeEnvironmentSandboxDoesNotConsumeNonce() {
        // The challenge-sandbox-on-prod rejection runs BEFORE the replay
        // check, so a subsequent accept (after the user enables sandbox)
        // must not find the challenge_id already marked as processed.
        let challengeId = "env-field-nonce-1"
        let encoded = base64UrlEncode(challengePayloadWithEnv(id: challengeId, env: "sandbox"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        _ = DeepLinkHandler.shared.handleURL(url)

        XCTAssertFalse(
            DeepLinkHandler.shared.hasProcessedNonce(challengeId),
            "Sandbox-on-prod rejection must not consume the challenge_id nonce"
        )
    }

    func testChallengeEnvironmentSandboxOnSandboxWalletRoutes() {
        // Already-sandbox wallet: sandbox-marked challenge routes normally.
        EnvironmentManager.shared.enableSandbox(true)
        defer { EnvironmentManager.shared.enableSandbox(false) }

        let encoded = base64UrlEncode(challengePayloadWithEnv(id: "env-field-sandbox-ok-1", env: "sandbox"))
        let url = URL(string: "provii://verify?d=\(encoded)")!

        let handled = DeepLinkHandler.shared.handleURL(url)

        XCTAssertTrue(handled, "Sandbox-marked challenge on sandbox wallet must route")
        XCTAssertNil(
            DeepLinkHandler.shared.pendingSandboxPrompt,
            "Sandbox-on-sandbox must not raise the prompt"
        )
    }

    // MARK: - Env-namespaced nonce buckets

    func testNonceKeychainKeyReflectsActiveEnvironment() {
        EnvironmentManager.shared.enableSandbox(false)
        XCTAssertEqual(
            DeepLinkHandler.currentNonceKeychainKey(),
            "deeplink_processed_nonces",
            "Production environment must use the production Keychain bucket"
        )

        EnvironmentManager.shared.enableSandbox(true)
        defer { EnvironmentManager.shared.enableSandbox(false) }
        XCTAssertEqual(
            DeepLinkHandler.currentNonceKeychainKey(),
            "deeplink_processed_nonces_sandbox",
            "Sandbox environment must use the sandbox Keychain bucket"
        )
    }

    // MARK: - Helpers

    /// Production-environment challenge payload. required field
    /// `environment` is present; use `challengePayloadWithEnv` or
    /// `challengePayloadWithoutEnv` to cover the other branches.
    private func challengePayload(id: String) -> String {
        return challengePayloadWithEnv(id: id, env: "production")
    }

    /// Challenge payload with a caller-specified `environment` value. Useful
    /// for pinning the sandbox-on-production rejection path and the
    /// environment-field validation rules.
    private func challengePayloadWithEnv(id: String, env: String) -> String {
        let rpChallenge = String(repeating: "a", count: 43)
        let submitSecret = String(repeating: "b", count: 43)
        let expiresAt = Int64(Date().timeIntervalSince1970) + 3600

        return """
        {
            "challenge_id": "\(id)",
            "rp_challenge": "\(rpChallenge)",
            "submit_secret": "\(submitSecret)",
            "cutoff_days": 30,
            "verifying_key_id": 1,
            "environment": "\(env)",
            "verify_url": "https://verify.provii.app/v1/verify",
            "expires_at": \(expiresAt)
        }
        """
    }

    /// Challenge payload missing the required `environment` field. 
    /// treats this as a protocol violation and the decoder returns nil.
    private func challengePayloadWithoutEnv(id: String) -> String {
        let rpChallenge = String(repeating: "a", count: 43)
        let submitSecret = String(repeating: "b", count: 43)
        let expiresAt = Int64(Date().timeIntervalSince1970) + 3600

        return """
        {
            "challenge_id": "\(id)",
            "rp_challenge": "\(rpChallenge)",
            "submit_secret": "\(submitSecret)",
            "cutoff_days": 30,
            "verifying_key_id": 1,
            "verify_url": "https://verify.provii.app/v1/verify",
            "expires_at": \(expiresAt)
        }
        """
    }

    private func base64UrlEncode(_ input: String) -> String {
        let data = Data(input.utf8)
        var encoded = data.base64EncodedString()
        encoded = encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return encoded
    }
}
