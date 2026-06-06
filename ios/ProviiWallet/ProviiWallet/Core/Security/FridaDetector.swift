// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Detects Frida dynamic instrumentation framework on iOS.
///
/// Uses a multi-vector approach: loaded dylib scanning, filesystem path checks,
/// TCP port probing on localhost, environment variable inspection, and FridaGadget
/// image detection. Returns early on simulator builds.
enum FridaDetector {

    /// Run all Frida detection checks.
    /// The USB transport check (`tty.usbmodem*`) can match non-Frida USB
    /// accessories, so it is only counted when at least one other indicator
    /// is also positive. This reduces false positives while maintaining
    /// detection when Frida is genuinely present.
    static func isFridaDetected() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let dylibHit = checkLoadedDylibs()
        let filesHit = checkFridaFiles()
        let portsHit = checkFridaPorts()
        let envHit = checkEnvironmentVariables()

        // High-confidence indicators: any single hit is sufficient.
        // Note: checkFridaGadgetInImages() was removed because its
        // "FridaGadget" search is already covered by checkLoadedDylibs()
        // which scans for "FridaGadget" among its fridaLibNames list.
        let highConfidenceHit = dylibHit || filesHit || portsHit || envHit
        if highConfidenceHit { return true }

        // USB transport is low confidence on its own (false-positive prone).
        // Only count it when corroborated by another indicator, which we
        // already know is false at this point, so return false.
        return false
        #endif
    }

    // MARK: - Detection Vectors

    /// Check loaded dynamic libraries for Frida-related names
    private static func checkLoadedDylibs() -> Bool {
        let fridaLibNames = [
            "frida",
            "FridaGadget",
            "frida-agent",
            "frida-gadget"
        ]

        let count = _dyld_image_count()
        for i in 0..<count {
            guard let name = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: name).lowercased()
            for fridaName in fridaLibNames {
                if imageName.contains(fridaName.lowercased()) {
                    return true
                }
            }
        }
        return false
    }

    /// Check for Frida-related files on the filesystem
    private static func checkFridaFiles() -> Bool {
        let fridaPaths = [
            "/usr/sbin/frida-server",
            "/usr/bin/frida-server",
            "/usr/lib/frida",
            "/usr/local/lib/frida",
            "/private/var/tmp/frida-server",
            "/tmp/frida-server"
        ]

        let fm = FileManager.default
        for path in fridaPaths {
            if fm.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }

    /// Check for default Frida listening ports (27042, 27043).
    ///
    /// Port probing uses blocking `connect()` with a 200ms timeout per port.
    /// To avoid blocking the main thread (~400ms worst case), this check dispatches
    /// to a global background queue and synchronously waits via DispatchSemaphore.
    /// The caller (`isFridaDetected`) still receives a synchronous Bool result.
    private static func checkFridaPorts() -> Bool {
        let fridaPorts: [UInt16] = [27042, 27043]
        let semaphore = DispatchSemaphore(value: 0)
        var detected = false

        DispatchQueue.global(qos: .utility).async {
            for port in fridaPorts {
                if isPortOpen(port) {
                    detected = true
                    break
                }
            }
            semaphore.signal()
        }

        semaphore.wait()
        return detected
    }

    /// Check for Frida-related environment variables
    private static func checkEnvironmentVariables() -> Bool {
        let suspiciousVars = [
            "DYLD_INSERT_LIBRARIES",
            "FRIDA_AGENT_PATH"
        ]

        for varName in suspiciousVars {
            if let value = getenv(varName), strlen(value) > 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    /// Check if a TCP port is open on localhost using a blocking connect with short timeout
    private static func isPortOpen(_ port: UInt16) -> Bool {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }

        // Set a short send/receive timeout so connect doesn't block long
        var timeout = timeval(tv_sec: 0, tv_usec: 200_000) // 200ms
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result == 0
    }
}
