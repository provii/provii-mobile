// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

/**
 * Data models for officer-mode QR code flows. These represent the JSON structures
 * exchanged between the wallet and provii-issuer during attestation issuance. The
 * [UserIssuanceRequest] redacts sensitive fields in its toString() to prevent
 * accidental exposure of birth date information in logs.
 */

@Serializable
data class OfficerStartResponse(
    @SerialName("session_id")
    val sessionId: String,
    @SerialName("issuer_id")
    val issuerId: String,
    val kid: String,
    @SerialName("expires_at")
    val expiresAt: Long,
    @SerialName("issuer_nonce")
    val issuerNonce: String,
    val policy: PolicyConfig,
)

@Serializable
data class PolicyConfig(
    val schema: String,
    @SerialName("validity_days")
    val validityDays: Int,
    val v: Int,
)

// Sent by the user to the officer to convey their commitment
@Serializable
data class UserIssuanceRequest(
    @SerialName("session_id")
    val sessionId: String,
    val commitment: String,
    @SerialName("birth_date")
    val birthDate: String,
) {
    /**
     * MASVS-CODE-2: Prevent auto-generated toString() from exposing birthDate
     */
    override fun toString(): String =
        "UserIssuanceRequest(sessionId=$sessionId, birthDate=[REDACTED], commitment=$commitment)"
}
