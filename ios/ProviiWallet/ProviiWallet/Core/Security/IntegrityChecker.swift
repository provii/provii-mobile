// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Verifies app binary and bundle integrity at runtime.
///
/// Checks code signature validity via `SecStaticCodeCheckValidity`, computes
/// SHA-256 hashes of the main executable and Info.plist against build-time
/// expected values, and confirms the provisioning profile is present. Hash
/// placeholders must be replaced during the build process. Fails closed in
/// release builds when placeholders have not been set.

import Foundation
import CryptoKit

final class IntegrityChecker {

    // WARNING: This is a placeholder value. The build script (Run Script phase)
    // MUST replace this string with the actual SHA-256 hash of the main
    // executable after linking. If this placeholder is not replaced, release
    // builds will fail the integrity check and refuse to launch. Debug builds
    // skip the check. See the "Compute Integrity Hashes" build phase.
    //
    // Format: lowercase hex string, 64 characters.
    static let expectedExecutableHash: String = "PLACEHOLDER_SET_DURING_BUILD"

    // WARNING: This is a placeholder value. The build script (Run Script phase)
    // MUST replace this string with the actual SHA-256 hash of Info.plist
    // after the Copy Bundle Resources phase completes. If this placeholder is
    // not replaced, release builds will fail the integrity check and refuse to
    // launch. Debug builds skip the check. See the "Compute Integrity Hashes"
    // build phase.
    //
    // Format: lowercase hex string, 64 characters.
    static let expectedInfoPlistHash: String = "PLACEHOLDER_SET_DURING_BUILD"

    static func verifyAppIntegrity() -> Bool {
        return verifyBundleSignature() &&
               verifyExecutableIntegrity() &&
               verifyResourceIntegrity() &&
               verifyProvisioningProfile()
    }

    /// Verify bundle code signature validity using Security framework.
    /// Uses SecStaticCode / SecCodeCheckValidity to perform actual
    /// cryptographic signature validation rather than merely checking
    /// that the _CodeSignature directory exists.
    ///
    /// SecStaticCode APIs are part of the Security framework but only
    /// available in the macOS SDK, not in iphonesimulator or iphoneos
    /// SDKs at the public-API level. On the simulator we skip signature
    /// verification (acceptable: simulator is a development environment
    /// without a real provisioning chain). On device builds the other
    /// integrity checks (executable hash, Info.plist hash, embedded
    /// provisioning profile presence) still apply, so we degrade
    /// gracefully rather than fail closed.
    private static func verifyBundleSignature() -> Bool {
        #if targetEnvironment(simulator)
        // Simulator: no real code signature to validate. Other integrity
        // checks (hash verification, provisioning profile) still run.
        return true
        #elseif canImport(Security) && os(macOS)
        let bundlePath = Bundle.main.bundlePath
        let bundleURL = URL(fileURLWithPath: bundlePath)

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            bundleURL as CFURL,
            [],
            &staticCode
        )
        guard createStatus == errSecSuccess, let code = staticCode else {
            // Fail closed. If we cannot create a static code reference
            // for cryptographic signature validation, refuse to trust the bundle
            // rather than falling back to a weak directory-existence check.
            return false
        }

        // Validate the signature with no specific requirement (checks that
        // the code signature is internally consistent and valid).
        let validityStatus = SecStaticCodeCheckValidity(code, [], nil)
        return validityStatus == errSecSuccess
        #else
        // iOS device: SecStaticCode public API is unavailable. Rely on the
        // OS loader to enforce the code signature at launch and on the
        // embedded provisioning profile + hash checks below.
        return true
        #endif
    }

    /// Verify executable integrity by computing a SHA-256 hash of the
    /// main executable binary and comparing it against the expected hash
    /// set during the build process.
    private static func verifyExecutableIntegrity() -> Bool {
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }

        guard let executableData = FileManager.default.contents(atPath: executablePath) else {
            return false
        }

        let hash = SHA256.hash(data: executableData)
        let computedHash = hash.compactMap { String(format: "%02x", $0) }.joined()

        // If the placeholder has not been replaced by the build system,
        // fail closed in release builds and pass in debug builds only.
        if expectedExecutableHash == "PLACEHOLDER_SET_DURING_BUILD" {
            #if DEBUG
            return true  // Expected in debug builds
            #else
            SecureLogger.shared.warning(
                "Executable integrity check failed: build-time hash not set",
                redact: false
            )
            return false  // Fail closed in release
            #endif
        }

        // Constant-time comparison is not required here: the executable
        // hash is not secret material (it is embedded in the binary and
        // the attacker already has the binary). A timing side-channel on
        // this comparison reveals nothing useful.
        return computedHash == expectedExecutableHash
    }

    /// Verify that critical bundle resources have not been tampered with.
    /// Checks Info.plist hash against the expected value set at build time.
    private static func verifyResourceIntegrity() -> Bool {
        // Verify Info.plist
        guard let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist") else {
            // Info.plist missing entirely is suspicious
            return false
        }

        guard let plistData = FileManager.default.contents(atPath: infoPlistPath) else {
            return false
        }

        let hash = SHA256.hash(data: plistData)
        let computedHash = hash.compactMap { String(format: "%02x", $0) }.joined()

        if expectedInfoPlistHash == "PLACEHOLDER_SET_DURING_BUILD" {
            #if DEBUG
            return true  // Expected in debug builds
            #else
            SecureLogger.shared.warning(
                "Info.plist integrity check failed: build-time hash not set",
                redact: false
            )
            return false  // Fail closed in release
            #endif
        }

        return computedHash == expectedInfoPlistHash
    }

    private static func verifyProvisioningProfile() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return false
        }
        return FileManager.default.fileExists(atPath: profilePath)
        #endif
    }

    /// Compute the SHA-256 hash of a named bundle resource.
    /// Useful for build scripts or runtime diagnostics.
    static func computeResourceHash(for filename: String) -> String? {
        guard let path = Bundle.main.path(forResource: filename, ofType: nil),
              let data = FileManager.default.contents(atPath: path) else {
            return nil
        }

        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
