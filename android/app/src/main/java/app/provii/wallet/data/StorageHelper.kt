// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import android.os.StatFs
import app.provii.wallet.sdk.*
import timber.log.Timber

/**
 * Bridges Android filesystem queries with the Rust SDK's storage checks. Reads available
 * block counts via [StatFs] and passes the result to the SDK's proving key storage
 * verification function, since the Rust layer cannot directly query Android storage APIs.
 */
object StorageHelper {
    /**
     * Get available storage bytes for a given path
     */
    fun getAvailableStorageBytes(path: String): Long {
        return try {
            val stat = StatFs(path)
            stat.availableBlocksLong * stat.blockSizeLong
        } catch (e: Exception) {
            Timber.e(e, "Failed to get storage stats")
            // Return a reasonable default that will trigger proper error handling
            0L
        }
    }

    /**
     * Check storage with actual Android filesystem information
     */
    fun checkStorageWithAndroidInfo(filesDir: String): StorageCheckResult {
        val availableBytes = getAvailableStorageBytes(filesDir)
        // Use the Rust function that accepts bytes from platform
        return provingKeyCheckStorageWithBytes(filesDir, availableBytes.toULong())
    }
}

/**
 * Updated WalletRepository extension to use platform storage info
 */
suspend fun WalletRepository.checkStorageBeforeDownload(filesDir: String): StorageCheckResult {
    return StorageHelper.checkStorageWithAndroidInfo(filesDir)
}
