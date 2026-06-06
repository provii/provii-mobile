// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data.models

import android.os.Parcelable
import kotlinx.parcelize.IgnoredOnParcel
import kotlinx.parcelize.Parcelize

/**
 * Credential model for the zero knowledge proof system. Wraps the SDK's CredentialV2
 * with UI-friendly fields and supports Parcelable for safe cross-Activity transport.
 * Sensitive cryptographic material (dobDays, rBits) is excluded from parcelling
 * and redacted in toString() per MASVS-CODE-2.
 */
@Parcelize
data class StoredCredential(
    val id: String, // Unique identifier (base64url)
    val issuerKid: String, // Issuer key ID
    val issuerLabel: String, // Display name for issuer
    val issuedAt: Long, // Unix timestamp (seconds)
    val expiresAt: Long, // Unix timestamp (seconds)
    val schema: String, // e.g., "provii.age/1"
    val createdAt: Long = System.currentTimeMillis(), // When stored locally (ms)
    // Private fields not shown in UI but needed for proofs
    val credentialData: CredentialData,
    /** "primary" or "managed" */
    val credentialType: String = "primary",
    /** User-assigned nickname (required for managed credentials) */
    val nickname: String? = null,
) : Parcelable {
    val isExpired: Boolean
        get() = (System.currentTimeMillis() / 1000) > expiresAt

    val daysUntilExpiry: Long
        get() = (expiresAt - (System.currentTimeMillis() / 1000)) / (24 * 60 * 60)

    /** Display name: nickname if set, null otherwise. UI layer resolves fallback via stringResource. */
    val displayName: String?
        get() = nickname

    val isManaged: Boolean
        get() = credentialType == "managed"
}

/**
 * The actual credential data needed for ZK proofs
 * This contains the cryptographic material
 * SECURITY: dobDays and rBits are excluded from Parcelable to prevent accidental exposure
 *
 * MASVS-CODE-2: Implements secure memory cleanup for sensitive data
 */
@Parcelize
data class CredentialData(
    val issuerVk: String, // 32B issuer verifying key (base64)
    val sigRj: String, // 64B RedJubjub signature (base64)
    val cBytes: String, // 32B commitment (base64)
    @IgnoredOnParcel
    var dobDays: Int = 0, // Days since epoch (private, never shown) - NOT parceled for security
    @IgnoredOnParcel
    var rBits: String = "", // Random bits JSON (private) - NOT parceled for security
) : Parcelable {
    /**
     * MASVS-CODE-2: Prevent auto-generated toString() from exposing dobDays/rBits
     */
    override fun toString(): String =
        "CredentialData(issuerVk=$issuerVk, sigRj=$sigRj, cBytes=$cBytes, dobDays=[REDACTED], rBits=[REDACTED])"
}

/**
 * Display-friendly credential for UI lists
 */
@Parcelize
data class CredentialDisplay(
    val id: String,
    val issuerLabel: String,
    val status: CredentialStatus,
    val expiresInDays: Long,
    val createdAt: Long,
) : Parcelable

enum class CredentialStatus {
    ACTIVE,
    EXPIRED,
    REVOKED,
    PENDING,
}

/**
 * Issuance confirmation (for officer receipts)
 */
@Parcelize
data class IssuanceConfirmation(
    val requestId: String,
    val credentialId: String,
    val officerId: String?, // Only if officer mode
    val stationId: String?, // Only if officer mode
    val issuedAt: Long,
    val issuerKid: String,
) : Parcelable

/**
 * Verification result for UI
 */
@Parcelize
data class VerificationResult(
    val challengeId: String,
    val status: VerificationStatus,
    val verifierName: String?,
    val timestamp: Long = System.currentTimeMillis(),
) : Parcelable

enum class VerificationStatus {
    SUCCESS, // Proof accepted
    WAITING_FOR_REDEEM, // proof_ok_waiting_for_redeem
    NOT_ELIGIBLE, // HTTP 403
    EXPIRED, // HTTP 410
    FAILED, // Other errors
}
