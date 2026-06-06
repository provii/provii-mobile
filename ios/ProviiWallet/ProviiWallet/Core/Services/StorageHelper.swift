// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Platform storage utilities for iOS, matching Android's `StorageHelper.kt`.
///
/// Queries filesystem capacity via `URL.resourceValues`, provides directory
/// path accessors, and wraps the Rust SDK's proving key storage check with
/// real iOS volume statistics.

import Foundation
class StorageHelper {

    // MARK: - Singleton
    static let shared = StorageHelper()

    private init() {}

    // MARK: - Storage Information

    /**
     * Get available storage bytes for a given path
     * Matches Android's StatFs functionality
     */
    func getAvailableStorageBytes(path: String) -> UInt64 {
        do {
            let url = URL(fileURLWithPath: path)
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])

            if let capacity = values.volumeAvailableCapacity {
                return UInt64(capacity)
            }

            // Fallback: try the optimistic capacity (includes purgeable space)
            let optimisticValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = optimisticValues.volumeAvailableCapacityForImportantUsage {
                return UInt64(capacity)
            }

            #if DEBUG
            SecureLogger.shared.warning("Failed to get storage stats, returning 0", redact: false)
            #endif
            return 0

        } catch {
            SecureLogger.shared.error("Error getting storage stats: \(error.localizedDescription)")
            return 0
        }
    }

    /**
     * Get total storage capacity
     */
    func getTotalStorageBytes(path: String) -> UInt64 {
        do {
            let url = URL(fileURLWithPath: path)
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey])

            if let capacity = values.volumeTotalCapacity {
                return UInt64(capacity)
            }

            return 0

        } catch {
            SecureLogger.shared.error("Error getting total storage: \(error.localizedDescription)")
            return 0
        }
    }

    /**
     * Get used storage bytes
     */
    func getUsedStorageBytes(path: String) -> UInt64 {
        let total = getTotalStorageBytes(path: path)
        let available = getAvailableStorageBytes(path: path)
        return total > available ? total - available : 0
    }

    /**
     * Check storage with actual iOS filesystem information
     * Matches Android's checkStorageWithAndroidInfo
     */
    func checkStorageWithiOSInfo(filesDir: String) -> StorageCheckResult {
        let availableBytes = getAvailableStorageBytes(path: filesDir)

        // Use the Rust function that accepts bytes from platform
        return provingKeyCheckStorageWithBytes(
            appFilesDir: filesDir,
            availableBytes: availableBytes
        )
    }

    // MARK: - Directory Information

    /**
     * Get documents directory path
     */
    func getDocumentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].path
    }

    /**
     * Get caches directory path
     */
    func getCachesDirectory() -> String {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].path
    }

    /**
     * Get temporary directory path
     */
    func getTemporaryDirectory() -> String {
        return NSTemporaryDirectory()
    }

    /**
     * Get application support directory path
     */
    func getApplicationSupportDirectory() -> String {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].path
    }

    // MARK: - File Operations

    /**
     * Check if file exists
     */
    func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /**
     * Get file size in bytes
     */
    func getFileSize(path: String) -> UInt64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? UInt64 {
                return fileSize
            }
            return 0
        } catch {
            SecureLogger.shared.error("Error getting file size: \(error.localizedDescription)")
            return 0
        }
    }

    /**
     * Get directory size (recursive)
     */
    func getDirectorySize(path: String) -> UInt64 {
        var totalSize: UInt64 = 0

        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return 0
        }

        for case let file as String in enumerator {
            let filePath = (path as NSString).appendingPathComponent(file)
            totalSize += getFileSize(path: filePath)
        }

        return totalSize
    }

    /**
     * Create directory if it doesn't exist
     */
    func createDirectory(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /**
     * Delete file or directory
     */
    func delete(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Storage Information Formatting

    /**
     * Format bytes to human-readable string
     */
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        // Clamp to Int64.max to prevent UInt64 -> Int64 overflow
        let clamped = bytes <= UInt64(Int64.max) ? Int64(bytes) : Int64.max
        return formatter.string(fromByteCount: clamped)
    }

    /**
     * Get storage information summary
     */
    func getStorageInfo(path: String) -> StorageInfo {
        let total = getTotalStorageBytes(path: path)
        let available = getAvailableStorageBytes(path: path)
        let used = total - available
        let usedPercentage = total > 0 ? Double(used) / Double(total) * 100.0 : 0.0

        return StorageInfo(
            totalBytes: total,
            availableBytes: available,
            usedBytes: used,
            usedPercentage: usedPercentage,
            totalFormatted: formatBytes(total),
            availableFormatted: formatBytes(available),
            usedFormatted: formatBytes(used)
        )
    }

    // MARK: - Proving Key Storage Check

    /**
     * Check if there's enough storage for proving key download
     * Convenience method that wraps the SDK function
     */
    func canDownloadProvingKey() -> (canDownload: Bool, reason: String?) {
        let documentsPath = getDocumentsDirectory()
        let result = checkStorageWithiOSInfo(filesDir: documentsPath)

        switch result {
        case .ready:
            return (true, nil)

        case .insufficientSpace(let availableMb, let requiredMb, let message):
            return (false, "Insufficient storage: \(message) (Available: \(availableMb)MB, Required: \(requiredMb)MB)")

        case .error(let message):
            return (false, "Storage check error: \(message)")
        }
    }

    // MARK: - App Storage Usage

    /**
     * Get total app storage usage
     */
    func getAppStorageUsage() -> UInt64 {
        var totalSize: UInt64 = 0

        // Documents
        totalSize += getDirectorySize(path: getDocumentsDirectory())

        // Caches
        totalSize += getDirectorySize(path: getCachesDirectory())

        // Application Support
        totalSize += getDirectorySize(path: getApplicationSupportDirectory())

        // Temp
        totalSize += getDirectorySize(path: getTemporaryDirectory())

        return totalSize
    }

    /**
     * Clear caches
     */
    func clearCaches() throws {
        let cachesPath = getCachesDirectory()
        let contents = try FileManager.default.contentsOfDirectory(atPath: cachesPath)

        for item in contents {
            let itemPath = (cachesPath as NSString).appendingPathComponent(item)
            try FileManager.default.removeItem(atPath: itemPath)
        }
    }

    /**
     * Clear temporary files
     */
    func clearTemporaryFiles() throws {
        let tempPath = getTemporaryDirectory()
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempPath)

        for item in contents {
            let itemPath = (tempPath as NSString).appendingPathComponent(item)
            try FileManager.default.removeItem(atPath: itemPath)
        }
    }
}

// MARK: - StorageInfo

struct StorageInfo {
    let totalBytes: UInt64
    let availableBytes: UInt64
    let usedBytes: UInt64
    let usedPercentage: Double
    let totalFormatted: String
    let availableFormatted: String
    let usedFormatted: String

    var isLowStorage: Bool {
        // Consider low storage when less than 500MB available
        return availableBytes < 500_000_000
    }

    var isCriticalStorage: Bool {
        // Critical when less than 65MB available
        return availableBytes < 65_000_000
    }
}

// MARK: - WalletRepository Extension

extension WalletRepository {
    /**
     * Check storage before proving key download
     * Matches Android extension method
     */
    func checkStorageBeforeDownload(filesDir: String) -> StorageCheckResult {
        return StorageHelper.shared.checkStorageWithiOSInfo(filesDir: filesDir)
    }

    /**
     * Check if enough storage for proving key
     */
    func hasEnoughStorageForProvingKey() async -> Bool {
        let (canDownload, _) = StorageHelper.shared.canDownloadProvingKey()
        return canDownload
    }
}
