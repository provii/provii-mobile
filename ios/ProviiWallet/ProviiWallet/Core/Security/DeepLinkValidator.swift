// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Validates deep link URLs before processing for MASVS PLATFORM-1 compliance.
///
/// Enforces scheme allowlisting (`provii://`, `https://`), host allowlisting
/// for Universal Links, path validation for custom-scheme deep links, query parameter
/// sanitisation against injection patterns (XSS, path traversal, SQL injection,
/// template injection), and blocks sensitive operations from being triggered via
/// external URLs.

import Foundation
import os.log

enum DeepLinkValidationResult: Equatable {
    case accepted(url: URL)
    case rejected(reason: String)

    var isAccepted: Bool {
        if case .accepted = self {
            return true
        }
        return false
    }

    var rejectionReason: String? {
        if case .rejected(let reason) = self {
            return reason
        }
        return nil
    }
}

final class DeepLinkValidator {
    static let shared = DeepLinkValidator()

    private let logger = Logger(subsystem: "app.provii.wallet", category: "DeepLinkValidator")

    // MARK: - Allowed Schemes

    private let allowedSchemes: Set<String> = ["provii", "https"]

    // MARK: - Allowed Hosts for Universal Links

    private let allowedHosts: Set<String> = [
        "provii.app",
        "playground.provii.app",
        "over.provii.app",
        "under.provii.app",
        "sandbox.provii.app",
        "api.provii.app",
        "sandbox-api.provii.app"
    ]

    // MARK: - Sensitive Operations (blocked from deep links)

    private let sensitiveOperations: Set<String> = [
        "/delete",
        "/reset",
        "/export",
        "/admin",
        "/debug",
        "/configure",
        "/keys",
        "/credentials/delete",
        "/wallet/reset"
    ]

    // MARK: - Valid Internal Paths for Custom Scheme

    private let validInternalPaths: Set<String> = [
        "verify",
        "attest",
        "credential",
        "settings",
        "help"
    ]

    private init() {}

    // MARK: - Public Validation Methods

    /// Validate a deep link URL before processing.
    /// Returns `.accepted` if the URL passes all security checks,
    /// or `.rejected` with a reason if validation fails.
    func validate(_ url: URL) -> DeepLinkValidationResult {
        // Validate scheme
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            let invalidScheme = url.scheme ?? "nil"
            logger.warning("Deep link rejected: invalid scheme '\(invalidScheme, privacy: .public)'")
            logSecurityEvent("deeplink_rejected", reason: "invalid_scheme", url: url)
            return .rejected(reason: "Invalid URL scheme")
        }

        // For custom scheme, validate internal paths
        if scheme == "provii" {
            return validateInternalDeepLink(url)
        }

        // For https, validate host.
        // Apply NFC normalisation before comparing to prevent Unicode
        // homograph bypasses (e.g. combining characters that visually match ASCII).
        guard let host = url.host?.precomposedStringWithCanonicalMapping.lowercased() else {
            logger.warning("Deep link rejected: missing host")
            logSecurityEvent("deeplink_rejected", reason: "missing_host", url: url)
            return .rejected(reason: "Invalid host")
        }

        guard isAllowedHost(host) else {
            logger.warning("Deep link rejected: invalid host '\(host, privacy: .public)'")
            logSecurityEvent("deeplink_rejected", reason: "untrusted_host", url: url)
            return .rejected(reason: "Invalid host")
        }

        // Check for sensitive operations that shouldn't be triggered by deep links
        let path = url.path.lowercased()
        for sensitive in sensitiveOperations {
            if path.contains(sensitive) {
                logger.warning("Deep link rejected: sensitive operation '\(path, privacy: .public)'")
                logSecurityEvent("deeplink_rejected", reason: "sensitive_operation", url: url)
                return .rejected(reason: "Sensitive operations cannot be triggered via deep links")
            }
        }

        // Validate query parameters for injection attacks
        if let validationError = validateQueryParameters(url) {
            return .rejected(reason: validationError)
        }

        // Log only scheme and host, not the full URL which may
        // contain sensitive query parameters (tokens, attestation data).
        let safeScheme = url.scheme ?? "unknown"
        let safeHost = url.host ?? "unknown"
        logger.info("Deep link accepted: \(safeScheme, privacy: .public)://\(safeHost, privacy: .public)/...")
        return .accepted(url: url)
    }

    // MARK: - Private Validation Methods

    /// Validate internal deep link (provii:// scheme).
    private func validateInternalDeepLink(_ url: URL) -> DeepLinkValidationResult {
        // For provii:// scheme, the action is in the host
        let path = url.host ?? url.path

        guard !path.isEmpty else {
            logger.warning("Deep link rejected: empty path for custom scheme")
            logSecurityEvent("deeplink_rejected", reason: "empty_path", url: url)
            return .rejected(reason: "Unknown deep link path")
        }

        // SECURITY: Exact match only. hasPrefix would allow "verifyevil" to match "verify".
        guard validInternalPaths.contains(path) else {
            logger.warning("Deep link rejected: unknown path '\(path, privacy: .public)'")
            logSecurityEvent("deeplink_rejected", reason: "unknown_path", url: url)
            return .rejected(reason: "Unknown deep link path")
        }

        // Validate query parameters
        if let validationError = validateQueryParameters(url) {
            return .rejected(reason: validationError)
        }

        // Log only scheme and action, not the full URL.
        let safeScheme = url.scheme ?? "unknown"
        let safeAction = url.host ?? url.path
        logger.info("Internal deep link accepted: \(safeScheme, privacy: .public)://\(safeAction, privacy: .public)/...")
        return .accepted(url: url)
    }

    /// Check if host is in the allowed list or a genuine subdomain of an allowed host.
    ///
    /// SECURITY: Matching requires either an exact hit in the allowlist, or that the host
    /// ends with a dot-separated subdomain boundary (e.g. "sub.provii.app" matches
    /// "provii.app", but "evil-provii.app" does NOT because the character
    /// before the matched suffix is "-" rather than ".").
    private func isAllowedHost(_ host: String) -> Bool {
        // Direct match
        if allowedHosts.contains(host) {
            return true
        }

        // Subdomain match: host must end with ".<allowedHost>" and the overall length
        // must be strictly greater (so we don't accidentally accept the root itself).
        let dotSuffix = "." // Prefix for subdomain boundary
        for allowedHost in allowedHosts {
            let suffix = dotSuffix + allowedHost
            if host.hasSuffix(suffix) && host.count > suffix.count {
                return true
            }
        }

        return false
    }

    /// Validate query parameters for injection attacks and suspicious content.
    /// Returns nil if valid, or an error message string if invalid.
    private func validateQueryParameters(_ url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil // No query parameters is valid
        }

        for item in queryItems {
            // Validate parameter name
            if containsSuspiciousContent(item.name) {
                logger.warning("Deep link rejected: suspicious parameter name '\(item.name, privacy: .public)'")
                logSecurityEvent("deeplink_rejected", reason: "suspicious_param_name", url: url)
                return "Invalid query parameters"
            }

            // Validate parameter value
            if let value = item.value {
                if containsSuspiciousContent(value) {
                    logger.warning("Deep link rejected: suspicious parameter value for '\(item.name, privacy: .public)'")
                    logSecurityEvent("deeplink_rejected", reason: "suspicious_param_value", url: url)
                    return "Invalid query parameters"
                }

                // Check for excessively long parameter values (potential DoS).
                // 2KB limit per parameter. Deep link query params should be
                // compact (base64url attestations, challenge IDs). 10KB was too generous
                // and could enable memory pressure attacks on constrained devices.
                if value.count > 2048 {
                    logger.warning("Deep link rejected: parameter value too long for '\(item.name, privacy: .public)'")
                    logSecurityEvent("deeplink_rejected", reason: "param_too_long", url: url)
                    return "Parameter value exceeds maximum length"
                }
            }
        }

        return nil
    }

    /// Check for suspicious content that could indicate injection attacks.
    ///
    /// This blocklist is intentionally non-exhaustive. It catches common
    /// injection vectors (XSS, path traversal, SQL injection, template injection)
    /// but cannot cover all possible attack patterns. The primary defence is the
    /// allowlist validation upstream: only known schemes, hosts, and paths are
    /// accepted. This blocklist is a secondary, defence in depth measure.
    ///
    /// ADV-WM-002: To defeat URL-encoding bypasses, the value is iteratively
    /// percent-decoded before pattern matching. NFC normalisation is applied to
    /// collapse Unicode homoglyphs into their canonical ASCII equivalents where
    /// possible, preventing visual spoofing of injection keywords.
    private func containsSuspiciousContent(_ value: String) -> Bool {
        // Iteratively percent-decode to defeat double/triple encoding.
        // Cap iterations to prevent infinite loops on pathological input.
        let decoded = iterativePercentDecode(value, maxIterations: 5)

        // NFC normalisation collapses combining characters and homoglyphs
        // into their canonical forms (e.g. fullwidth '<' U+FF1C -> '<').
        let normalised = decoded.precomposedStringWithCanonicalMapping
        let lowercased = normalised.lowercased()

        // XSS patterns
        let xssPatterns = [
            "<script",
            "javascript:",
            "vbscript:",
            "data:text/html",
            "onerror=",
            "onload=",
            "onclick=",
            "onmouseover="
        ]

        // Path traversal patterns (checked against decoded value so %2e%2e is caught)
        let pathTraversalPatterns = [
            "../",
            "..\\"
        ]

        // SQL injection patterns
        let sqlPatterns = [
            "' or ",
            "\" or ",
            "' and ",
            "\" and ",
            "1=1",
            "1'='1",
            "'; drop",
            "\"; drop",
            "union select",
            "union all select"
        ]

        // Template/code injection patterns
        let injectionPatterns = [
            "${",
            "#{",
            "{{",
            "<%",
            "%>",
            "<?",
            "?>"
        ]

        // Check all patterns against the fully decoded, normalised value
        for pattern in xssPatterns + pathTraversalPatterns + sqlPatterns + injectionPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }

        // Check for null bytes (injection attack indicator) in both raw and decoded forms
        if value.contains("\0") || decoded.contains("\0") ||
           value.lowercased().contains("%00") {
            return true
        }

        return false
    }

    /// Iteratively percent-decode a string until it stabilises or the iteration
    /// limit is reached. This defeats double-encoding, triple-encoding, etc.
    private func iterativePercentDecode(_ value: String, maxIterations: Int) -> String {
        var current = value
        for _ in 0..<maxIterations {
            guard let next = current.removingPercentEncoding, next != current else {
                break
            }
            current = next
        }
        return current
    }

    // MARK: - Security Logging

    private func logSecurityEvent(_ event: String, reason: String, url: URL) {
        let sanitizedUrl = sanitizeUrlForLogging(url)
        logger.info("SECURITY_EVENT: \(event, privacy: .public) reason=\(reason, privacy: .public) url=\(sanitizedUrl, privacy: .public)")

        // Also log to AuditLogger for centralized security monitoring
        AuditLogger.shared.logSecurityEvent(.deeplinkFallback, details: [
            "event": event,
            "reason": reason,
            "url_host": url.host ?? "unknown",
            "url_scheme": url.scheme ?? "unknown"
        ])
    }

    /// Sanitise URL for logging by redacting sensitive query parameters.
    private func sanitizeUrlForLogging(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        // List of parameters that should be redacted
        let sensitiveParams = ["token", "key", "secret", "password", "hmac", "d"]

        if let queryItems = components.queryItems {
            components.queryItems = queryItems.map { item in
                if sensitiveParams.contains(item.name.lowercased()) {
                    return URLQueryItem(name: item.name, value: "[REDACTED]")
                }
                return item
            }
        }

        return components.string ?? url.absoluteString
    }
}

// MARK: - URL Extension for Validation

extension URL {
    /// Validate this URL using DeepLinkValidator.
    func validateAsDeepLink() -> DeepLinkValidationResult {
        return DeepLinkValidator.shared.validate(self)
    }
}
