// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// PII-safe logging facade wrapping Apple's unified logging system.
///
/// MASVS STORAGE-2 compliant: debug messages are compiled out in release
/// builds via `#if DEBUG`. Sensitive values logged with `redact: true` use
/// `os.log` privacy specifier `.private` so they appear only in live
/// console output, never in sysdiagnose or device logs.

import Foundation
import os.log
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

final class SecureLogger {
    static let shared = SecureLogger()

    private let logger: Logger
    private let sensitiveLogger: Logger

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "app.provii.wallet"
        logger = Logger(subsystem: subsystem, category: "app")
        sensitiveLogger = Logger(subsystem: subsystem, category: "sensitive")
    }

    // MARK: - Main Logging Method

    /**
     * Log a message with automatic privacy handling
     *
     * - Parameters:
     *   - message: The message to log
     *   - level: Log severity level
     *   - redact: If true, treats message as sensitive data (default: true for safety)
     *   - file: Source file (auto-populated)
     *   - function: Source function (auto-populated)
     *   - line: Source line number (auto-populated)
     */
    func log(
        _ message: String,
        level: LogLevel = .info,
        redact: Bool = true,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let context = "[\(fileName):\(line)] \(function)"
        logDebugBuild(message: message, level: level, redact: redact, context: context)
        #else
        logReleaseBuild(message: message, level: level)
        #endif
    }

    // MARK: - Internal Log Dispatch

    private func logDebugBuild(message: String, level: LogLevel, redact: Bool, context: String) {
        switch level {
        case .debug:
            if redact {
                logger.debug("\(context, privacy: .public): \(message, privacy: .private)")
            } else {
                logger.debug("\(context, privacy: .public): \(message, privacy: .public)")
            }
        case .info:
            if redact {
                logger.info("\(context, privacy: .public): \(message, privacy: .private)")
            } else {
                logger.info("\(context, privacy: .public): \(message, privacy: .public)")
            }
        case .warning:
            if redact {
                logger.warning("\(context, privacy: .public): \(message, privacy: .private)")
            } else {
                logger.warning("\(context, privacy: .public): \(message, privacy: .public)")
            }
        case .error:
            if redact {
                logger.error("\(context, privacy: .public): \(message, privacy: .private)")
            } else {
                logger.error("\(context, privacy: .public): \(message, privacy: .public)")
            }
        case .critical:
            if redact {
                logger.critical("\(context, privacy: .public): \(message, privacy: .private)")
            } else {
                logger.critical("\(context, privacy: .public): \(message, privacy: .public)")
            }
        }
    }

    private func logReleaseBuild(message: String, level: LogLevel) {
        switch level {
        case .error:
            logger.error("\(message, privacy: .private)")
        case .critical:
            logger.critical("\(message, privacy: .private)")
        case .debug, .info, .warning:
            break
        }
    }

    // MARK: - Convenience Methods

    /// Log debug message (only in DEBUG builds)
    func debug(_ message: String, redact: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, redact: redact, file: file, function: function, line: line)
    }

    /// Log info message
    func info(_ message: String, redact: Bool = false, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, redact: redact, file: file, function: function, line: line)
    }

    /// Log warning message
    func warning(_ message: String, redact: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, redact: redact, file: file, function: function, line: line)
    }

    /// Log error message
    func error(_ message: String, redact: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, redact: redact, file: file, function: function, line: line)
    }

    /// Log critical message
    func critical(_ message: String, redact: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, redact: redact, file: file, function: function, line: line)
    }

    // MARK: - Sensitive Data Handling

    /**
     * Redact sensitive data for display/logging
     * Shows only first 2 and last 2 characters for strings > 4 chars
     *
     * - Parameter value: The sensitive string to redact
     * - Returns: Redacted string (e.g., "ab***xy")
     */
    func redact(_ value: String) -> String {
        guard value.count > 4 else { return "***" }
        return String(value.prefix(2)) + "***" + String(value.suffix(2))
    }

    /**
     * Redact an identifier (UUID, token, etc.)
     * Shows only first 4 characters
     */
    func redactId(_ value: String) -> String {
        guard value.count > 4 else { return "***" }
        return String(value.prefix(4)) + "..."
    }

    /**
     * Completely mask a value (for highly sensitive data like passwords)
     */
    func mask(_ value: String) -> String {
        return "[REDACTED]"
    }

    // MARK: - Structured Logging

    /**
     * Log with key-value metadata
     * Automatically redacts values unless explicitly marked safe
     */
    func logWithMetadata(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String],
        safeKeys: Set<String> = [],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let formattedMetadata = metadata.map { key, value in
            let displayValue = safeKeys.contains(key) ? value : redact(value)
            return "\(key)=\(displayValue)"
        }.joined(separator: ", ")

        log("\(message) [\(formattedMetadata)]", level: level, redact: false, file: file, function: function, line: line)
    }
}

// MARK: - Global Convenience Functions

/// Quick debug log (DEBUG builds only)
func secureDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    SecureLogger.shared.debug(message, file: file, function: function, line: line)
}

/// Quick info log
func secureInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    SecureLogger.shared.info(message, file: file, function: function, line: line)
}

/// Quick error log
func secureError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    SecureLogger.shared.error(message, file: file, function: function, line: line)
}
