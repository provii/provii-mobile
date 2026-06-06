// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.navigation

import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory store that holds large or sensitive navigation payloads keyed by UUID.
 * Routes carry only the UUID; the destination retrieves the actual data via [get]
 * and then schedules cleanup via [remove] in a DisposableEffect.
 *
 * A 30-second TTL ensures entries never accumulate if a destination is abandoned
 * before it can call [remove]. [prune] runs automatically on every [put].
 */
@Singleton
class NavigationPayloadStore
    @Inject
    constructor() {
        private data class PayloadEntry(
            val value: String,
            val expiresAt: Long,
        )

        private val store = ConcurrentHashMap<String, PayloadEntry>()

        private val ttlMs = 30_000L

        /**
         * Store [payload] under a freshly-minted UUID key and return that key.
         * Expired entries are pruned before insertion.
         */
        fun put(payload: String): String {
            prune()
            val key = java.util.UUID.randomUUID().toString()
            store[key] =
                PayloadEntry(
                    value = payload,
                    expiresAt = System.currentTimeMillis() + ttlMs,
                )
            return key
        }

        /**
         * Retrieve the payload for [key], or null if the entry does not exist or
         * has expired.
         */
        fun get(key: String): String? {
            val entry = store[key] ?: return null
            if (System.currentTimeMillis() > entry.expiresAt) {
                store.remove(key)
                return null
            }
            return entry.value
        }

        /**
         * Remove the entry for [key]. Called from DisposableEffect.onDispose in
         * destination composables so memory is released when the screen leaves
         * composition. Safe to call with an unknown or already-removed key.
         */
        fun remove(key: String) {
            store.remove(key)
        }

        /**
         * Evict all entries whose TTL has elapsed. Called automatically by [put].
         */
        private fun prune() {
            val now = System.currentTimeMillis()
            store.entries.removeIf { (_, entry) -> now > entry.expiresAt }
        }
    }
