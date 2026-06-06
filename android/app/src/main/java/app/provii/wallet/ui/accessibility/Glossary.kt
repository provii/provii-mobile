// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import androidx.annotation.StringRes
import app.provii.wallet.R

/**
 * In-app technical glossary satisfying WCAG 2.2 AAA criterion 3.1.3 (Unusual Words).
 * Contains 16 entries organised into five categories: cryptography, privacy, credentials,
 * verification, and technical. Each entry carries a short definition for tooltips and a
 * full definition for the dedicated glossary screen, plus related-term cross-references.
 *
 * All user-visible strings are held as @StringRes resource IDs. Composables resolve them
 * via stringResource() so translations flow through the standard Android localisation pipeline.
 */

enum class GlossaryCategory {
    CRYPTOGRAPHY,
    PRIVACY,
    CREDENTIALS,
    VERIFICATION,
    TECHNICAL,
}

data class GlossaryEntry(
    @StringRes val termRes: Int,
    val category: GlossaryCategory,
    @StringRes val shortDefinitionRes: Int,
    @StringRes val fullDefinitionRes: Int,
    val relatedTerms: List<String> = emptyList(),
)

object Glossary {
    private val entries =
        listOf(
            GlossaryEntry(
                termRes = R.string.glossary_term_zero_knowledge_proof,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_zero_knowledge_proof,
                fullDefinitionRes = R.string.glossary_full_zero_knowledge_proof,
                relatedTerms = listOf("Pedersen Commitment", "Range Proof", "Verifier", "Privacy Preserving"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_credential,
                category = GlossaryCategory.CREDENTIALS,
                shortDefinitionRes = R.string.glossary_short_credential,
                fullDefinitionRes = R.string.glossary_full_credential,
                relatedTerms = listOf("Issuer", "Digital Signature", "Cryptographic Commitment", "Attestation"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_issuer,
                category = GlossaryCategory.CREDENTIALS,
                shortDefinitionRes = R.string.glossary_short_issuer,
                fullDefinitionRes = R.string.glossary_full_issuer,
                relatedTerms = listOf("Credential", "Digital Signature", "Trusted Authority", "Attestation"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_verifier,
                category = GlossaryCategory.VERIFICATION,
                shortDefinitionRes = R.string.glossary_short_verifier,
                fullDefinitionRes = R.string.glossary_full_verifier,
                relatedTerms = listOf("Zero Knowledge Proof", "Range Proof", "Challenge", "Session"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_qr_code,
                category = GlossaryCategory.TECHNICAL,
                shortDefinitionRes = R.string.glossary_short_qr_code,
                fullDefinitionRes = R.string.glossary_full_qr_code,
                relatedTerms = listOf("Manual Code Entry", "Scanning", "Alternative Input", "Deep Link"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_pedersen_commitment,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_pedersen_commitment,
                fullDefinitionRes = R.string.glossary_full_pedersen_commitment,
                relatedTerms = listOf("Zero Knowledge Proof", "Cryptographic Commitment", "Homomorphic Encryption", "Range Proof"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_range_proof,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_range_proof,
                fullDefinitionRes = R.string.glossary_full_range_proof,
                relatedTerms = listOf("Zero Knowledge Proof", "Pedersen Commitment", "Verification", "Age Threshold"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_challenge,
                category = GlossaryCategory.VERIFICATION,
                shortDefinitionRes = R.string.glossary_short_challenge,
                fullDefinitionRes = R.string.glossary_full_challenge,
                relatedTerms = listOf("Verifier", "Zero Knowledge Proof", "Session", "Nonce"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_cryptographic_commitment,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_cryptographic_commitment,
                fullDefinitionRes = R.string.glossary_full_cryptographic_commitment,
                relatedTerms = listOf("Pedersen Commitment", "Zero Knowledge Proof", "Credential", "Binding Property"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_digital_signature,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_digital_signature,
                fullDefinitionRes = R.string.glossary_full_digital_signature,
                relatedTerms = listOf("Issuer", "Credential", "Public Key Infrastructure", "Ed25519"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_privacy_preserving,
                category = GlossaryCategory.PRIVACY,
                shortDefinitionRes = R.string.glossary_short_privacy_preserving,
                fullDefinitionRes = R.string.glossary_full_privacy_preserving,
                relatedTerms = listOf("Zero Knowledge Proof", "Privacy by Design", "Data Minimisation", "Selective Disclosure"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_proving_key,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_proving_key,
                fullDefinitionRes = R.string.glossary_full_proving_key,
                relatedTerms = listOf("Zero Knowledge Proof", "Verification Key", "Cryptographic Parameters", "Trusted Setup"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_verification_key,
                category = GlossaryCategory.VERIFICATION,
                shortDefinitionRes = R.string.glossary_short_verification_key,
                fullDefinitionRes = R.string.glossary_full_verification_key,
                relatedTerms = listOf("Proving Key", "Verifier", "Zero Knowledge Proof", "Public Parameters"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_session,
                category = GlossaryCategory.VERIFICATION,
                shortDefinitionRes = R.string.glossary_short_session,
                fullDefinitionRes = R.string.glossary_full_session,
                relatedTerms = listOf("Challenge", "Verifier", "Timeout", "Nonce"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_homomorphic_encryption,
                category = GlossaryCategory.CRYPTOGRAPHY,
                shortDefinitionRes = R.string.glossary_short_homomorphic_encryption,
                fullDefinitionRes = R.string.glossary_full_homomorphic_encryption,
                relatedTerms = listOf("Pedersen Commitment", "Zero Knowledge Proof", "Range Proof", "Additive Property"),
            ),
            GlossaryEntry(
                termRes = R.string.glossary_term_trusted_authority,
                category = GlossaryCategory.CREDENTIALS,
                shortDefinitionRes = R.string.glossary_short_trusted_authority,
                fullDefinitionRes = R.string.glossary_full_trusted_authority,
                relatedTerms = listOf("Issuer", "Credential", "Digital Signature", "Certificate Authority"),
            ),
        )

    fun allEntries(): List<GlossaryEntry> = entries

    fun entriesByCategory(category: GlossaryCategory): List<GlossaryEntry> =
        entries.filter { it.category == category }

    fun getAllCategories(): List<GlossaryCategory> = GlossaryCategory.entries.toList()
}
