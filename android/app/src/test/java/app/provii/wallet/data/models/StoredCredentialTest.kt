// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StoredCredentialTest {
    private fun makeCredential(
        expiresAt: Long = (System.currentTimeMillis() / 1000) + 86400,
        credentialType: String = "primary",
        nickname: String? = null,
    ): StoredCredential {
        return StoredCredential(
            id = "test-id",
            issuerKid = "kid-1",
            issuerLabel = "Test Issuer",
            issuedAt = System.currentTimeMillis() / 1000,
            expiresAt = expiresAt,
            schema = "provii.age/1",
            credentialData = CredentialData(
                issuerVk = "vk-base64",
                sigRj = "sig-base64",
                cBytes = "c-base64",
            ),
            credentialType = credentialType,
            nickname = nickname,
        )
    }

    @Test
    fun `isExpired returns false for future expiry`() {
        val cred = makeCredential(expiresAt = (System.currentTimeMillis() / 1000) + 86400)
        assertFalse(cred.isExpired)
    }

    @Test
    fun `isExpired returns true for past expiry`() {
        val cred = makeCredential(expiresAt = (System.currentTimeMillis() / 1000) - 86400)
        assertTrue(cred.isExpired)
    }

    @Test
    fun `daysUntilExpiry is positive for unexpired credential`() {
        val cred = makeCredential(expiresAt = (System.currentTimeMillis() / 1000) + 86400 * 10)
        assertTrue(cred.daysUntilExpiry > 0)
    }

    @Test
    fun `displayName returns nickname when set`() {
        val cred = makeCredential(nickname = "My Card")
        assertEquals("My Card", cred.displayName)
    }

    @Test
    fun `displayName returns null when nickname not set`() {
        val cred = makeCredential(nickname = null)
        assertNull(cred.displayName)
    }

    @Test
    fun `isManaged returns true for managed type`() {
        val cred = makeCredential(credentialType = "managed")
        assertTrue(cred.isManaged)
    }

    @Test
    fun `isManaged returns false for primary type`() {
        val cred = makeCredential(credentialType = "primary")
        assertFalse(cred.isManaged)
    }
}

class CredentialDataTest {
    @Test
    fun `toString redacts sensitive fields`() {
        val data = CredentialData(
            issuerVk = "vk-value",
            sigRj = "sig-value",
            cBytes = "c-value",
            dobDays = 12345,
            rBits = "secret-r-bits",
        )
        val str = data.toString()
        assertTrue(str.contains("[REDACTED]"))
        assertFalse(str.contains("12345"))
        assertFalse(str.contains("secret-r-bits"))
        assertTrue(str.contains("vk-value"))
    }
}

class OfficerQrModelsTest {
    @Test
    fun `UserIssuanceRequest toString redacts birthDate`() {
        val req = UserIssuanceRequest(
            sessionId = "sess-123",
            commitment = "commit-abc",
            birthDate = "1990-01-15",
        )
        val str = req.toString()
        assertTrue(str.contains("[REDACTED]"))
        assertFalse(str.contains("1990-01-15"))
        assertTrue(str.contains("sess-123"))
    }
}
