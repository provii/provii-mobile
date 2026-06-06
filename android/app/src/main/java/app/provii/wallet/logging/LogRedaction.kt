// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.logging

/**
 * Shared redaction utility for identifiers written to Logcat and audit logs.
 *
 * SECURITY: Credential IDs, challenge IDs, officer IDs, and key IDs are sensitive
 * and must not appear in full in Logcat output. Even debug builds are at risk
 * because Logcat can be read by other apps on rooted devices or via ADB.
 *
 * Returns the first 4 characters followed by "***" so logs remain useful for
 * correlation without exposing the full value. Strings of 4 characters or fewer
 * are replaced entirely with "***" to prevent trivial brute-force.
 */
fun redactId(id: String): String {
    if (id.isBlank()) return "[empty]"
    if (id.length <= 4) return "***"
    return "${id.take(4)}***"
}
