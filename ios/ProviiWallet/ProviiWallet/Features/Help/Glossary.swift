// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Glossary data model and singleton providing searchable, categorised definitions of cryptographic,
/// privacy, credential, verification, and technical terms used throughout Provii Wallet. Includes
/// pronunciation guides for screen reader accessibility and related-term cross-references.

enum GlossaryCategory: String, CaseIterable {
    case cryptography = "Cryptography"
    case privacy = "Privacy"
    case credentials = "Credentials"
    case verification = "Verification"
    case technical = "Technical"
}

struct GlossaryEntry {
    let term: String
    let category: GlossaryCategory
    let definition: String
    let pronunciation: String?
    let relatedTerms: [String]

    init(term: String, category: GlossaryCategory, definition: String, pronunciation: String? = nil, relatedTerms: [String] = []) {
        self.term = term
        self.category = category
        self.definition = definition
        self.pronunciation = pronunciation
        self.relatedTerms = relatedTerms
    }
}

class Glossary {
    static let shared = Glossary()

    private init() {}

    func getAllEntries() -> [GlossaryEntry] {
        return entries
    }

    func entriesByCategory(_ category: GlossaryCategory) -> [GlossaryEntry] {
        return entries.filter { $0.category == category }
    }

    func findEntry(term: String) -> GlossaryEntry? {
        return entries.first { $0.term.caseInsensitiveCompare(term) == .orderedSame }
    }

    func search(query: String) -> [GlossaryEntry] {
        let lowered = query.lowercased()
        return entries.filter {
            $0.term.lowercased().contains(lowered) ||
            $0.definition.lowercased().contains(lowered)
        }
    }

    /// Get pronunciation-friendly term for accessibility
    func getPronunciationFriendlyTerm(_ term: String) -> String {
        if let entry = entries.first(where: { $0.term == term }),
           let pronunciation = entry.pronunciation {
            return pronunciation
        }
        return term
    }

    // MARK: - Entries (matching Android's 16 terms + iOS accessibility extras)

    private var entries: [GlossaryEntry] {
        return [
            // Cryptography
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_zero_knowledge_proof", comment: "Glossary term: Zero Knowledge Proof"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_zero_knowledge_proof", comment: "Glossary definition for Zero Knowledge Proof"),
                relatedTerms: ["Pedersen Commitment", "Range Proof", "Verifier", "Privacy Preserving"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_pedersen_commitment", comment: "Glossary term: Pedersen Commitment"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_pedersen_commitment", comment: "Glossary definition for Pedersen Commitment"),
                relatedTerms: ["Zero Knowledge Proof", "Cryptographic Commitment", "Homomorphic Encryption", "Range Proof"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_range_proof", comment: "Glossary term: Range Proof"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_range_proof", comment: "Glossary definition for Range Proof"),
                relatedTerms: ["Zero Knowledge Proof", "Pedersen Commitment", "Verification", "Data Minimisation"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_cryptographic_commitment", comment: "Glossary term: Cryptographic Commitment"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_cryptographic_commitment", comment: "Glossary definition for Cryptographic Commitment"),
                relatedTerms: ["Pedersen Commitment", "Zero Knowledge Proof", "Credential", "Verifier"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_digital_signature", comment: "Glossary term: Digital Signature"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_digital_signature", comment: "Glossary definition for Digital Signature"),
                relatedTerms: ["Issuer", "Credential", "Public Key Infrastructure", "Trusted Authority"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_proving_key", comment: "Glossary term: Proving Key"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_proving_key", comment: "Glossary definition for Proving Key"),
                relatedTerms: ["Zero Knowledge Proof", "Verification Key", "Cryptographic Parameters", "Digital Signature"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_homomorphic_encryption", comment: "Glossary term: Homomorphic Encryption"),
                category: .cryptography,
                definition: NSLocalizedString("glossary_def_homomorphic_encryption", comment: "Glossary definition for Homomorphic Encryption"),
                relatedTerms: ["Pedersen Commitment", "Zero Knowledge Proof", "Range Proof", "Privacy Preserving"]
            ),

            // Privacy
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_privacy_preserving", comment: "Glossary term: Privacy Preserving"),
                category: .privacy,
                definition: NSLocalizedString("glossary_def_privacy_preserving", comment: "Glossary definition for Privacy Preserving"),
                relatedTerms: ["Zero Knowledge Proof", "Privacy by Design", "Data Minimisation", "Credential"]
            ),

            // Credentials
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_credential", comment: "Glossary term: Credential"),
                category: .credentials,
                definition: NSLocalizedString("glossary_def_credential", comment: "Glossary definition for Credential")
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_issuer", comment: "Glossary term: Issuer"),
                category: .credentials,
                definition: NSLocalizedString("glossary_def_issuer", comment: "Glossary definition for Issuer")
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_trusted_authority", comment: "Glossary term: Trusted Authority"),
                category: .credentials,
                definition: NSLocalizedString("glossary_def_trusted_authority", comment: "Glossary definition for Trusted Authority"),
                relatedTerms: ["Issuer", "Credential", "Digital Signature", "Public Key Infrastructure"]
            ),

            // Verification
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_verifier", comment: "Glossary term: Verifier"),
                category: .verification,
                definition: NSLocalizedString("glossary_def_verifier", comment: "Glossary definition for Verifier")
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_challenge", comment: "Glossary term: Challenge"),
                category: .verification,
                definition: NSLocalizedString("glossary_def_challenge", comment: "Glossary definition for Challenge"),
                relatedTerms: ["Verifier", "Zero Knowledge Proof", "Session", "Proving Key"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_verification_key", comment: "Glossary term: Verification Key"),
                category: .verification,
                definition: NSLocalizedString("glossary_def_verification_key", comment: "Glossary definition for Verification Key"),
                relatedTerms: ["Proving Key", "Verifier", "Zero Knowledge Proof", "Cryptographic Parameters"]
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_session", comment: "Glossary term: Session"),
                category: .verification,
                definition: NSLocalizedString("glossary_def_session", comment: "Glossary definition for Session"),
                relatedTerms: ["Challenge", "Verifier", "Timeout", "Zero Knowledge Proof"]
            ),

            // Technical
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_qr_code", comment: "Glossary term: QR Code"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_qr_code", comment: "Glossary definition for QR Code"),
                pronunciation: "Q R Code"
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_biometric_authentication", comment: "Glossary term: Biometric Authentication"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_biometric_authentication", comment: "Glossary definition for Biometric Authentication")
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_api", comment: "Glossary term: API"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_api", comment: "Glossary definition for API"),
                pronunciation: "A P I"
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_url", comment: "Glossary term: URL"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_url", comment: "Glossary definition for URL"),
                pronunciation: "U R L"
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_id", comment: "Glossary term: ID"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_id", comment: "Glossary definition for ID"),
                pronunciation: "I D"
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_mdl", comment: "Glossary term: mDL"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_mdl", comment: "Glossary definition for mDL"),
                pronunciation: "M D L"
            ),
            GlossaryEntry(
                term: NSLocalizedString("glossary_term_pin", comment: "Glossary term: PIN"),
                category: .technical,
                definition: NSLocalizedString("glossary_def_pin", comment: "Glossary definition for PIN"),
                pronunciation: "P I N"
            ),
            GlossaryEntry(
                term: "Provii",
                category: .technical,
                definition: NSLocalizedString("glossary_def_provii", comment: "Glossary definition for Provii"),
                pronunciation: "par lee"
            )
        ]
    }
}
