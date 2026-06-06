// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CredentialStatusTest {
    @Test
    fun allStatusValuesExist() {
        val values = CredentialStatus.entries
        assertEquals(4, values.size)
        assertTrue(values.contains(CredentialStatus.ACTIVE))
        assertTrue(values.contains(CredentialStatus.EXPIRED))
        assertTrue(values.contains(CredentialStatus.REVOKED))
        assertTrue(values.contains(CredentialStatus.PENDING))
    }
}

class VerificationStatusTest {
    @Test
    fun allVerificationStatusValuesExist() {
        val values = VerificationStatus.entries
        assertEquals(5, values.size)
        assertTrue(values.contains(VerificationStatus.SUCCESS))
        assertTrue(values.contains(VerificationStatus.WAITING_FOR_REDEEM))
        assertTrue(values.contains(VerificationStatus.NOT_ELIGIBLE))
        assertTrue(values.contains(VerificationStatus.EXPIRED))
        assertTrue(values.contains(VerificationStatus.FAILED))
    }
}

class CredentialDisplayTest {
    @Test
    fun credentialDisplayPreservesFields() {
        val display = CredentialDisplay(
            id = "cred-1",
            issuerLabel = "Test Issuer",
            status = CredentialStatus.ACTIVE,
            expiresInDays = 30,
            createdAt = 1000L,
        )
        assertEquals("cred-1", display.id)
        assertEquals("Test Issuer", display.issuerLabel)
        assertEquals(CredentialStatus.ACTIVE, display.status)
        assertEquals(30L, display.expiresInDays)
    }
}

class VerificationResultTest {
    @Test
    fun verificationResultPreservesFields() {
        val result = VerificationResult(
            challengeId = "challenge-1",
            status = VerificationStatus.SUCCESS,
            verifierName = "Test Verifier",
            timestamp = 12345L,
        )
        assertEquals("challenge-1", result.challengeId)
        assertEquals(VerificationStatus.SUCCESS, result.status)
        assertEquals("Test Verifier", result.verifierName)
        assertEquals(12345L, result.timestamp)
    }
}

class IssuanceConfirmationTest {
    @Test
    fun issuanceConfirmationPreservesFields() {
        val confirm = IssuanceConfirmation(
            requestId = "req-1",
            credentialId = "cred-1",
            officerId = "off-1",
            stationId = "sta-1",
            issuedAt = 1000L,
            issuerKid = "kid-1",
        )
        assertEquals("req-1", confirm.requestId)
        assertEquals("cred-1", confirm.credentialId)
        assertEquals("off-1", confirm.officerId)
        assertEquals("sta-1", confirm.stationId)
    }
}

class PolicyConfigTest {
    @Test
    fun policyConfigPreservesFields() {
        val policy = PolicyConfig(
            schema = "provii.age/1",
            validityDays = 365,
            v = 1,
        )
        assertEquals("provii.age/1", policy.schema)
        assertEquals(365, policy.validityDays)
        assertEquals(1, policy.v)
    }
}

class OfficerStartResponseTest {
    @Test
    fun officerStartResponsePreservesFields() {
        val resp = OfficerStartResponse(
            sessionId = "sess-1",
            issuerId = "issuer-1",
            kid = "kid-1",
            expiresAt = 999L,
            issuerNonce = "nonce-abc",
            policy = PolicyConfig("provii.age/1", 365, 1),
        )
        assertEquals("sess-1", resp.sessionId)
        assertEquals("issuer-1", resp.issuerId)
        assertEquals("kid-1", resp.kid)
        assertEquals(999L, resp.expiresAt)
        assertEquals("nonce-abc", resp.issuerNonce)
    }
}
