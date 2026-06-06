// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import app.provii.wallet.R

/**
 * Dual-register content system for WCAG 2.2 AAA criterion 3.1.5 (Reading Level). Every
 * user-facing content key maps to both a standard and a simplified (Grade 7-9) string
 * resource. The [LocalizedContentManager] and [localizedText] composable select the
 * appropriate variant based on the current [ReadingLevel] setting.
 */

enum class ContentKey(
    @StringRes val standardResId: Int,
    @StringRes val simplifiedResId: Int,
) {
    // Age Verification
    AGE_VERIFICATION_TITLE(
        R.string.content_age_verification_title,
        R.string.content_age_verification_title_simplified,
    ),
    AGE_VERIFICATION_EXPLANATION(
        R.string.content_age_verification_explanation,
        R.string.content_age_verification_explanation_simplified,
    ),
    AGE_VERIFICATION_INSTRUCTIONS(
        R.string.content_age_verification_instructions,
        R.string.content_age_verification_instructions_simplified,
    ),
    AGE_VERIFICATION_SUCCESS(
        R.string.content_age_verification_success,
        R.string.content_age_verification_success_simplified,
    ),
    AGE_VERIFICATION_FAILED(
        R.string.content_age_verification_failed,
        R.string.content_age_verification_failed_simplified,
    ),

    // Credential Issuance
    CREDENTIAL_ISSUANCE_TITLE(
        R.string.content_credential_issuance_title,
        R.string.content_credential_issuance_title_simplified,
    ),
    CREDENTIAL_ISSUANCE_EXPLANATION(
        R.string.content_credential_issuance_explanation,
        R.string.content_credential_issuance_explanation_simplified,
    ),
    CREDENTIAL_ISSUANCE_INSTRUCTIONS(
        R.string.content_credential_issuance_instructions,
        R.string.content_credential_issuance_instructions_simplified,
    ),
    CREDENTIAL_ISSUANCE_SUCCESS(
        R.string.content_credential_issuance_success,
        R.string.content_credential_issuance_success_simplified,
    ),

    // Technical Terms
    CREDENTIAL_DESCRIPTION(
        R.string.content_credential_description,
        R.string.content_credential_description_simplified,
    ),
    ZERO_KNOWLEDGE_EXPLANATION(
        R.string.content_zero_knowledge_explanation,
        R.string.content_zero_knowledge_explanation_simplified,
    ),
    SETUP_PROVING_KEY(
        R.string.content_setup_proving_key,
        R.string.content_setup_proving_key_simplified,
    ),
    PROCESSING_CHALLENGE(
        R.string.content_processing_challenge,
        R.string.content_processing_challenge_simplified,
    ),
    CREATING_PROOF(
        R.string.content_creating_proof,
        R.string.content_creating_proof_simplified,
    ),
    SUBMITTING_PROOF(
        R.string.content_submitting_proof,
        R.string.content_submitting_proof_simplified,
    ),

    // Errors
    ERROR_NO_CREDENTIAL(
        R.string.content_error_no_credential,
        R.string.content_error_no_credential_simplified,
    ),
    ERROR_NETWORK_FAILED(
        R.string.content_error_network_failed,
        R.string.content_error_network_failed_simplified,
    ),
    ERROR_INVALID_QR(
        R.string.content_error_invalid_qr,
        R.string.content_error_invalid_qr_simplified,
    ),
    ERROR_VERIFICATION_FAILED(
        R.string.content_error_verification_failed,
        R.string.content_error_verification_failed_simplified,
    ),

    // Officer Mode
    OFFICER_AUTHENTICATION_TITLE(
        R.string.content_officer_authentication_title,
        R.string.content_officer_authentication_title_simplified,
    ),
    OFFICER_ISSUANCE_TITLE(
        R.string.content_officer_issuance_title,
        R.string.content_officer_issuance_title_simplified,
    ),
    OFFICER_DOB_PROMPT(
        R.string.content_officer_dob_prompt,
        R.string.content_officer_dob_prompt_simplified,
    ),

    // Onboarding
    ONBOARDING_WELCOME(
        R.string.content_onboarding_welcome,
        R.string.content_onboarding_welcome_simplified,
    ),
    ONBOARDING_PRIVACY(
        R.string.content_onboarding_privacy,
        R.string.content_onboarding_privacy_simplified,
    ),
    ONBOARDING_GET_STARTED(
        R.string.content_onboarding_get_started,
        R.string.content_onboarding_get_started_simplified,
    ),
    ;

    /**
     * Get localized text for the specified reading level
     */
    fun getText(
        context: Context,
        level: ReadingLevel,
    ): String {
        return when (level) {
            ReadingLevel.SIMPLIFIED -> context.getString(simplifiedResId)
            ReadingLevel.STANDARD -> context.getString(standardResId)
        }
    }
}

object LocalizedContentManager {
    @Composable
    fun text(
        key: ContentKey,
        level: ReadingLevel? = null,
    ): String {
        val context = LocalContext.current
        val settings = LocalAccessibilityUiState.current.settings
        val effectiveLevel = level ?: settings.readingLevel

        return remember(key, effectiveLevel) {
            key.getText(context, effectiveLevel)
        }
    }

    fun textNonComposable(
        context: Context,
        key: ContentKey,
        level: ReadingLevel,
    ): String {
        return key.getText(context, level)
    }
}

/**
 * Composable wrapper for localized content that automatically applies
 * the current reading level setting.
 */
@Composable
fun localizedText(
    key: ContentKey,
    level: ReadingLevel? = null,
): String {
    return LocalizedContentManager.text(key, level)
}
