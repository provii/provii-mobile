// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Detects and blocks debugger attachment on iOS.
///
/// Provides two complementary defences: `denyDebuggerAttachment()` uses
/// `PT_DENY_ATTACH` via ptrace to refuse debugger attachment at the kernel
/// level, and `isDebuggerAttached()` checks sysctl for the `P_TRACED` flag
/// as a secondary detection. Both are no-ops in DEBUG builds.

import Foundation
import Darwin

// ptrace is not exposed in Swift's Darwin module headers.
// Declare it directly using @_silgen_name to link against libc's ptrace symbol.
@_silgen_name("ptrace")
private func c_ptrace(_ request: CInt, _ pid: pid_t, _ addr: CInt, _ data: CInt) -> CInt

// PT_DENY_ATTACH constant (not always exposed in Swift headers)
private let PT_DENY_ATTACH: CInt = 31

final class DebuggerDetector {

    /// Unconditionally deny debugger attachment via ptrace.
    /// This MUST be called at startup before any detection checks, so that
    /// even if detection is bypassed the denial has already taken effect.
    static func denyDebuggerAttachment() {
        #if !DEBUG
        // PT_DENY_ATTACH tells the kernel to kill the process if a
        // debugger tries to attach. Once set, it cannot be reversed.
        _ = c_ptrace(PT_DENY_ATTACH, 0, 0, 0)
        #endif
    }

    /// Detect whether a debugger is currently attached.
    /// Called after denyDebuggerAttachment() as a secondary check; if
    /// the denial was somehow bypassed, this still catches active tracing.
    static func isDebuggerAttached() -> Bool {
        #if DEBUG
        return false  // Allow debugging in debug builds
        #else
        return checkSysctl()
        #endif
    }

    private static func checkSysctl() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        // Fail closed. If sysctl fails, assume a debugger is present
        // rather than silently allowing execution to continue unprotected.
        guard result == 0 else { return true }

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
