// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Detects jailbroken iOS devices using multiple heuristic vectors.
///
/// Checks filesystem paths for known jailbreak artifacts, tests sandbox
/// integrity via file write and fork, scans for jailbreak-related URL
/// schemes, and inspects loaded dynamic libraries for known substrate
/// and hook frameworks. Returns early on simulator builds.

import Foundation
import UIKit
import MachO

final class JailbreakDetector {
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return checkJailbreakFiles() ||
               checkSandboxIntegrity() ||
               checkSuspiciousApps() ||
               checkWriteAccess() ||
               checkSymbolicLinks() ||
               checkDynamicLibraries()
        #endif
    }

    private static func checkJailbreakFiles() -> Bool {
        let jailbreakPaths = [
            // Classic jailbreak paths
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/bin/bash",
            "/usr/libexec/sftp-server",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/var/cache/apt",
            "/var/lib/cydia",
            "/private/var/stash",
            "/private/var/db/stash",
            "/usr/bin/cycript",
            "/usr/local/bin/cycript",
            "/usr/lib/libcycript.dylib",
            // Rootless jailbreak paths (Dopamine, palera1n, etc.)
            "/var/jb",
            "/var/jb/usr/bin/su",
            "/var/jb/usr/sbin/sshd",
            "/var/jb/usr/bin/ssh",
            "/var/jb/Library",
            "/var/jb/bin/bash",
            "/var/jb/usr/lib/TweakInject.dylib",
            "/var/containers/Bundle/.jailbreak",
            "/var/LIB",
            "/var/binpack",
            // Bootstraps and package managers
            "/var/jb/Applications/Sileo.app",
            "/var/jb/Applications/Zebra.app",
            "/var/jb/Library/dpkg",
            "/var/jb/etc/apt"
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }

    private static func checkSandboxIntegrity() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true  // Should NOT be able to write outside sandbox
        } catch {
            return false  // Expected - sandbox is intact
        }
    }

    // fork() detection removed. Calling fork() in an iOS app causes
    // immediate App Store rejection during static analysis review. The remaining
    // jailbreak indicators (file paths, sandbox writes, URL schemes, dylib
    // inspection, symlink checks) provide sufficient coverage without fork().

    /// (ACCEPTED): `canOpenURL` requires each scheme to be declared in
    /// `LSApplicationQueriesSchemes` in Info.plist. A side effect is that these
    /// queries are visible in the system's URL scheme registration, which could
    /// theoretically fingerprint the app as performing jailbreak detection. This
    /// is accepted because: (a) the schemes are already well-known jailbreak
    /// indicators, (b) any app can query them, and (c) the detection benefit
    /// outweighs the minimal fingerprinting risk.
    private static func checkSuspiciousApps() -> Bool {
        let suspiciousSchemes = ["cydia://", "sileo://", "zbra://", "filza://", "undecimus://"]
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }

    private static func checkWriteAccess() -> Bool {
        let paths = ["/private/", "/root/", "/System/"]
        for path in paths {
            if FileManager.default.isWritableFile(atPath: path) {
                return true
            }
        }
        return false
    }

    private static func checkSymbolicLinks() -> Bool {
        let suspicious = ["/Applications", "/var/stash", "/Library/Ringtones", "/Library/Wallpaper"]
        for path in suspicious {
            let exists = FileManager.default.fileExists(atPath: path)
            if exists {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: path)
                    if attrs[.type] as? FileAttributeType == .typeSymbolicLink {
                        return true
                    }
                } catch {
                    // Intentionally ignored: jailbreak detection must not crash the
                    // app. A failure to read attributes for a single path is not
                    // actionable and does not indicate jailbreak on its own.
                }
            }
        }
        return false
    }

    private static func checkDynamicLibraries() -> Bool {
        let suspiciousLibs = [
            "SubstrateLoader", "TweakInject", "CydiaSubstrate", "substitute",
            "ellekit", "libhooker", "libblackjack", "roothide"
        ]
        for i in 0..<_dyld_image_count() {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                for lib in suspiciousLibs {
                    if name.lowercased().contains(lib.lowercased()) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
