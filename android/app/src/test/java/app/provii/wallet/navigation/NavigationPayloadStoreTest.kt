// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class NavigationPayloadStoreTest {
    @Test
    fun `put returns a UUID key and get retrieves the value`() {
        val store = NavigationPayloadStore()
        val key = store.put("some payload")
        assertNotNull(key)
        assertEquals("some payload", store.get(key))
    }

    @Test
    fun `get returns null for unknown key`() {
        val store = NavigationPayloadStore()
        assertNull(store.get("nonexistent-key"))
    }

    @Test
    fun `remove deletes the entry`() {
        val store = NavigationPayloadStore()
        val key = store.put("data")
        assertEquals("data", store.get(key))
        store.remove(key)
        assertNull(store.get(key))
    }

    @Test
    fun `remove is safe for unknown key`() {
        val store = NavigationPayloadStore()
        store.remove("nonexistent") // should not throw
    }

    @Test
    fun `multiple puts generate unique keys`() {
        val store = NavigationPayloadStore()
        val k1 = store.put("a")
        val k2 = store.put("b")
        assertNotEquals(k1, k2)
        assertEquals("a", store.get(k1))
        assertEquals("b", store.get(k2))
    }
}
