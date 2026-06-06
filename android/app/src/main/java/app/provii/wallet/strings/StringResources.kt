// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.strings

import android.content.Context
import androidx.annotation.StringRes
import app.provii.wallet.R

/**
 * Type-safe access to string resources for the Provii Wallet app. Provides
 * centralised, compile-time-checked access to all string resource IDs, grouped
 * by feature area. Simplifies refactoring and maintains internationalisation
 * consistency across the codebase.
 */
object StringResources {
    /**
     * Get a string resource by ID
     */
    fun get(
        context: Context,
        @StringRes resId: Int,
    ): String {
        return context.getString(resId)
    }

    /**
     * Get a formatted string resource with arguments
     */
    fun format(
        context: Context,
        @StringRes resId: Int,
        vararg formatArgs: Any,
    ): String {
        return context.getString(resId, *formatArgs)
    }

    // ==================== APP INFO ====================

    object App {
        @StringRes val NAME = R.string.app_name

        @StringRes val NAME_DEBUG = R.string.app_name_debug

        @StringRes val NAME_STAGING = R.string.app_name_staging
    }

    // ==================== TITLES ====================

    object Title {
        @StringRes val SETTINGS = R.string.title_settings

        @StringRes val ACCESSIBILITY = R.string.title_accessibility

        @StringRes val PROVII_WALLET = R.string.title_provii_wallet

        @StringRes val GET_CREDENTIALS = R.string.title_get_credentials

        @StringRes val SCAN_VERIFICATION_QR = R.string.title_scan_verification_qr

        @StringRes val VERIFYING_AGE = R.string.title_verifying_age

        @StringRes val AGE_VERIFIED = R.string.title_age_verified

        @StringRes val VERIFICATION_FAILED = R.string.title_verification_failed

        @StringRes val OFFICER_MODE = R.string.title_officer_mode

        @StringRes val OFFICER_DASHBOARD = R.string.title_officer_dashboard

        @StringRes val ISSUE_CREDENTIAL = R.string.title_issue_credential

        @StringRes val CREDENTIAL_READY = R.string.title_credential_ready

        @StringRes val GET_YOUR_CREDENTIAL = R.string.title_get_your_credential
    }

    // ==================== WELCOME & ONBOARDING ====================

    object Welcome {
        @StringRes val TITLE = R.string.welcome_title

        @StringRes val SUBTITLE = R.string.welcome_subtitle

        @StringRes val FIRST_CREDENTIAL = R.string.welcome_first_credential

        @StringRes val DESCRIPTION = R.string.welcome_description
    }

    object Setup {
        @StringRes val ONE_TIME_REQUIRED = R.string.setup_one_time_required

        @StringRes val DOWNLOAD_REQUIRED = R.string.setup_download_required

        @StringRes val DOWNLOAD_DESCRIPTION = R.string.setup_download_description

        @StringRes val WIFI_RECOMMENDED = R.string.setup_wifi_recommended

        @StringRes val CHECKING_STATUS = R.string.setup_checking_status

        @StringRes val ALREADY_SETUP = R.string.setup_already_setup

        @StringRes val READY_MESSAGE = R.string.setup_ready_message

        @StringRes val PREPARING = R.string.setup_preparing

        @StringRes val CHECKING_COMPONENTS = R.string.setup_checking_components

        @StringRes val DOWNLOADING = R.string.setup_downloading

        @StringRes val INITIALIZING = R.string.setup_initializing

        @StringRes val COMPLETE = R.string.setup_complete

        @StringRes val DOWNLOAD_INFO = R.string.setup_download_info

        @StringRes val ONE_TIME_DOWNLOAD = R.string.setup_one_time_download

        @StringRes val STUCK_MESSAGE = R.string.setup_stuck_message

        @StringRes val STUCK_DESCRIPTION = R.string.setup_stuck_description

        @StringRes val RESTART_MESSAGE = R.string.setup_restart_message

        @StringRes val STORAGE_FULL = R.string.setup_storage_full

        @StringRes val CONNECTION_ERROR = R.string.setup_connection_error

        @StringRes val FAILED = R.string.setup_failed

        @StringRes val INITIALIZATION_ERROR = R.string.setup_initialization_error

        @StringRes val FREE_STORAGE_MESSAGE = R.string.setup_free_storage_message

        @StringRes val PROGRESS_FORMAT = R.string.setup_progress_format

        @StringRes val PRIVACY_PROTECTED = R.string.setup_privacy_protected

        @StringRes val PRIVACY_DESCRIPTION = R.string.setup_privacy_description
    }

    // ==================== CREDENTIALS ====================

    object Credentials {
        @StringRes val TITLE = R.string.credentials_title

        @StringRes val EMPTY = R.string.credentials_empty

        @StringRes val ACTIVE = R.string.credential_active

        @StringRes val EXPIRED = R.string.credential_expired

        @StringRes val READY_FOR_VERIFICATION = R.string.credential_ready_for_verification

        @StringRes val EXPIRED_MESSAGE = R.string.credential_expired_message

        @StringRes val STORED_SUCCESSFULLY = R.string.credential_stored_successfully

        @StringRes val STORED_DESCRIPTION = R.string.credential_stored_description

        @StringRes val CAN_PROVE_AGE = R.string.credential_can_prove_age

        @StringRes val RETURNING = R.string.credential_returning

        object Actions {
            @StringRes val SCAN_QR_CODE = R.string.action_scan_qr_code

            @StringRes val FIND_LOCATIONS = R.string.action_find_locations

            @StringRes val GET_CREDENTIAL = R.string.action_get_credential

            @StringRes val REPLACE_CREDENTIAL = R.string.action_replace_credential

            @StringRes val REPLACE_CREDENTIAL_NOW = R.string.action_replace_credential_now

            @StringRes val DELETE_CREDENTIAL = R.string.action_delete_credential

            @StringRes val SCAN_DESCRIPTION = R.string.credential_action_scan_description

            @StringRes val FIND_DESCRIPTION = R.string.credential_action_find_description

            @StringRes val REMOVE_DESCRIPTION = R.string.credential_remove_description
        }

        object Info {
            @StringRes val PRIVACY = R.string.credential_info_privacy

            @StringRes val PRIVACY_VALUE = R.string.credential_info_privacy_value

            @StringRes val STATUS = R.string.credential_info_status

            @StringRes val STATUS_VALUE = R.string.credential_info_status_value

            @StringRes val TIP_TITLE = R.string.credential_tip_title

            @StringRes val TIP_MESSAGE = R.string.credential_tip_message
        }
    }

    // ==================== VERIFICATION ====================

    object Verification {
        @StringRes val SCAN_QR = R.string.verification_scan_qr

        @StringRes val VERIFY_AGE = R.string.verification_verify_age

        @StringRes val GENERATING_PROOF = R.string.verification_generating_proof

        @StringRes val SUCCESS = R.string.verification_success

        @StringRes val FAILED = R.string.verification_failed

        @StringRes val AGE_VERIFIED = R.string.verification_age_verified

        @StringRes val AGE_VERIFIED_MESSAGE = R.string.verification_age_verified_message

        @StringRes val CAN_RETURN = R.string.verification_can_return

        @StringRes val RETURNING_BROWSER = R.string.verification_returning_browser

        @StringRes val STEP_1_OF_2 = R.string.verification_step_1_of_2

        @StringRes val STEP_2_OF_2 = R.string.verification_step_2_of_2

        @StringRes val POINT_CAMERA = R.string.verification_point_camera

        @StringRes val HOLD_STEADY = R.string.verification_hold_steady

        @StringRes val READING_REQUEST = R.string.verification_reading_request

        @StringRes val PROCESSING_CHALLENGE = R.string.verification_processing_challenge

        @StringRes val CREATING_PROOF = R.string.verification_creating_proof

        @StringRes val SUBMITTING_PROOF = R.string.verification_submitting_proof

        @StringRes val PROCESSING_MESSAGE = R.string.verification_processing_message

        @StringRes val PREPARING_PROOF = R.string.verification_preparing_proof
    }

    // ==================== ISSUERS ====================

    object Issuers {
        @StringRes val TRUSTED_IN_AUSTRALIA = R.string.issuers_trusted_in_australia

        @StringRes val LOADING = R.string.issuers_loading

        @StringRes val UNABLE_TO_LOAD = R.string.issuers_unable_to_load

        @StringRes val CHECK_CONNECTION = R.string.issuers_check_connection

        @StringRes val CATEGORIES_HEADER = R.string.issuers_categories_header

        @StringRes val AVAILABLE_HEADER = R.string.issuers_available_header

        @StringRes val FOUND_COUNT = R.string.issuers_found_count

        @StringRes val STATUS_COMING_SOON = R.string.issuer_status_coming_soon

        @StringRes val STATUS_VERIFIED = R.string.issuer_status_verified

        @StringRes val HOW_TO_GET = R.string.issuer_how_to_get

        @StringRes val SERVICE_LOCATIONS = R.string.issuer_service_locations

        @StringRes val VISIT_WEBSITE = R.string.issuer_visit_website

        @StringRes val LEARN_MORE = R.string.issuer_learn_more

        object Categories {
            @StringRes val BANKING = R.string.category_banking

            @StringRes val SUPER_FUND = R.string.category_super_fund

            @StringRes val GOVERNMENT = R.string.category_government

            @StringRes val TRAVEL = R.string.category_travel

            @StringRes val TELCO = R.string.category_telco

            @StringRes val INSURANCE = R.string.category_insurance
        }
    }

    // ==================== SETTINGS ====================

    object Settings {
        @StringRes val TITLE = R.string.settings_title

        @StringRes val SECURITY = R.string.settings_security

        @StringRes val BIOMETRIC = R.string.settings_biometric

        @StringRes val ENVIRONMENT = R.string.settings_environment

        @StringRes val ENVIRONMENT_DESCRIPTION = R.string.settings_environment_description

        @StringRes val RESET_PROVING_KEY = R.string.settings_reset_proving_key

        @StringRes val RESET_PROVING_KEY_DESCRIPTION = R.string.settings_reset_proving_key_description

        @StringRes val MINT_TEST_CREDENTIAL_AS_ISSUER = R.string.settings_mint_test_credential_as_issuer

        @StringRes val MINT_TEST_CREDENTIAL_SUBTITLE = R.string.settings_mint_test_credential_subtitle

        @StringRes val VERSION = R.string.settings_version

        @StringRes val TAP_5X_TOGGLE = R.string.settings_tap_5x_toggle

        object Sandbox {
            @StringRes val MODE_BADGE = R.string.sandbox_mode_badge

            @StringRes val MODE_ACTIVE = R.string.sandbox_mode_active

            @StringRes val MODE_DESCRIPTION = R.string.sandbox_mode_description

            @StringRes val CREDENTIAL_TITLE = R.string.sandbox_credential_title

            @StringRes val CREDENTIAL_DESCRIPTION = R.string.sandbox_credential_description

            @StringRes val SELECT_AGE = R.string.sandbox_select_age

            @StringRes val AGE_FORMAT = R.string.sandbox_age_format

            @StringRes val DEFAULT_DOB = R.string.sandbox_default_dob

            @StringRes val OVERRIDE_DOB = R.string.sandbox_override_dob

            @StringRes val OVERRIDE_DESCRIPTION = R.string.sandbox_override_description

            @StringRes val DATE_OF_BIRTH = R.string.sandbox_date_of_birth

            @StringRes val GENERATE_CREDENTIAL = R.string.sandbox_generate_credential

            @StringRes val GENERATING = R.string.sandbox_generating

            @StringRes val TEST_CREDENTIAL_SAVED = R.string.sandbox_test_credential_saved

            @StringRes val ID_PREFIX = R.string.sandbox_id_prefix

            @StringRes val UNABLE_TO_GENERATE = R.string.sandbox_unable_to_generate
        }

        object Environment {
            @StringRes val CONFIGURATION = R.string.environment_configuration

            @StringRes val CURRENT = R.string.environment_current

            @StringRes val ISSUER_API = R.string.environment_issuer_api

            @StringRes val VERIFIER_API = R.string.environment_verifier_api
        }

        object Dialogs {
            @StringRes val DELETE_CREDENTIAL_TITLE = R.string.dialog_delete_credential_title

            @StringRes val DELETE_CREDENTIAL_MESSAGE = R.string.dialog_delete_credential_message

            @StringRes val RESET_PROVING_KEY_TITLE = R.string.dialog_reset_proving_key_title

            @StringRes val RESET_PROVING_KEY_MESSAGE = R.string.dialog_reset_proving_key_message
        }
    }

    // ==================== ACCESSIBILITY ====================

    object Accessibility {
        @StringRes val TITLE = R.string.accessibility_title

        @StringRes val SERVICE_LABEL = R.string.accessibility_service_label

        @StringRes val SERVICE_DESCRIPTION = R.string.accessibility_service_description

        @StringRes val PERSONALIZE = R.string.accessibility_personalize

        @StringRes val CUSTOMIZE_FEATURES = R.string.accessibility_customize_features

        @StringRes val QUICK_SETUP = R.string.accessibility_quick_setup

        @StringRes val FEATURES_ACTIVE = R.string.accessibility_features_active

        @StringRes val CUSTOMIZE_EXPERIENCE = R.string.accessibility_customize_experience

        @StringRes val RESET_TITLE = R.string.accessibility_reset_title

        @StringRes val RESET_MESSAGE = R.string.accessibility_reset_message

        @StringRes val RESET = R.string.accessibility_reset

        object Categories {
            @StringRes val VISION = R.string.accessibility_category_vision

            @StringRes val INTERACTION = R.string.accessibility_category_interaction

            @StringRes val COGNITIVE = R.string.accessibility_category_cognitive

            @StringRes val ALTERNATIVE_INPUT = R.string.accessibility_category_alternative_input
        }

        object Vision {
            @StringRes val EXTRA_LARGE_TEXT = R.string.accessibility_extra_large_text

            @StringRes val EXTRA_LARGE_TEXT_DESCRIPTION = R.string.accessibility_extra_large_text_description

            @StringRes val HIGH_CONTRAST = R.string.accessibility_high_contrast

            @StringRes val HIGH_CONTRAST_DESCRIPTION = R.string.accessibility_high_contrast_description

            @StringRes val REDUCE_TRANSPARENCY = R.string.accessibility_reduce_transparency

            @StringRes val REDUCE_TRANSPARENCY_DESCRIPTION = R.string.accessibility_reduce_transparency_description

            @StringRes val COLOR_BLIND_MODE = R.string.accessibility_color_blind_mode

            @StringRes val COLOR_BLIND_OPTIMIZED = R.string.accessibility_color_blind_optimized
        }

        object ColorBlind {
            @StringRes val NONE = R.string.color_blind_none

            @StringRes val PROTANOPIA = R.string.color_blind_protanopia

            @StringRes val DEUTERANOPIA = R.string.color_blind_deuteranopia

            @StringRes val TRITANOPIA = R.string.color_blind_tritanopia

            @StringRes val MONOCHROME = R.string.color_blind_monochrome
        }

        object Interaction {
            @StringRes val LARGER_TOUCH_TARGETS = R.string.accessibility_larger_touch_targets

            @StringRes val LARGER_TOUCH_TARGETS_DESCRIPTION = R.string.accessibility_larger_touch_targets_description

            @StringRes val REDUCE_MOTION = R.string.accessibility_reduce_motion

            @StringRes val REDUCE_MOTION_DESCRIPTION = R.string.accessibility_reduce_motion_description

            @StringRes val EXTENDED_TIMEOUTS = R.string.accessibility_extended_timeouts

            @StringRes val EXTENDED_TIMEOUTS_DESCRIPTION = R.string.accessibility_extended_timeouts_description

            @StringRes val SIMPLIFIED_GESTURES = R.string.accessibility_simplified_gestures

            @StringRes val SIMPLIFIED_GESTURES_DESCRIPTION = R.string.accessibility_simplified_gestures_description

            @StringRes val HAPTIC_FEEDBACK = R.string.accessibility_haptic_feedback

            @StringRes val HAPTIC_FEEDBACK_DESCRIPTION = R.string.accessibility_haptic_feedback_description
        }

        object Cognitive {
            @StringRes val SIMPLIFIED_INTERFACE = R.string.accessibility_simplified_interface

            @StringRes val SIMPLIFIED_INTERFACE_DESCRIPTION = R.string.accessibility_simplified_interface_description

            @StringRes val SHOW_STEP_NUMBERS = R.string.accessibility_show_step_numbers

            @StringRes val SHOW_STEP_NUMBERS_DESCRIPTION = R.string.accessibility_show_step_numbers_description

            @StringRes val DETAILED_DESCRIPTIONS = R.string.accessibility_detailed_descriptions

            @StringRes val DETAILED_DESCRIPTIONS_DESCRIPTION = R.string.accessibility_detailed_descriptions_description

            @StringRes val CONFIRM_ACTIONS = R.string.accessibility_confirm_actions

            @StringRes val CONFIRM_ACTIONS_DESCRIPTION = R.string.accessibility_confirm_actions_description
        }

        object AlternativeInput {
            @StringRes val MANUAL_CODE_ENTRY = R.string.accessibility_manual_code_entry

            @StringRes val MANUAL_CODE_ENTRY_DESCRIPTION = R.string.accessibility_manual_code_entry_description

            @StringRes val VOICE_INPUT = R.string.accessibility_voice_input

            @StringRes val VOICE_INPUT_DESCRIPTION = R.string.accessibility_voice_input_description
        }

        object Profiles {
            @StringRes val VISION = R.string.accessibility_profile_vision

            @StringRes val MOTOR = R.string.accessibility_profile_motor

            @StringRes val COGNITIVE = R.string.accessibility_profile_cognitive

            @StringRes val SENIOR = R.string.accessibility_profile_senior
        }
    }

    // ==================== OFFICER MODE ====================

    object Officer {
        @StringRes val MODE = R.string.officer_mode

        @StringRes val ID = R.string.officer_id

        @StringRes val ID_PLACEHOLDER = R.string.officer_id_placeholder

        @StringRes val ID_HINT = R.string.officer_id_hint

        @StringRes val YUBIKEY_CONNECTED = R.string.officer_yubikey_connected

        @StringRes val CONNECT_YUBIKEY = R.string.officer_connect_yubikey

        @StringRes val TOUCH_YUBIKEY = R.string.officer_touch_yubikey

        @StringRes val AUTHENTICATE_HMAC = R.string.officer_authenticate_hmac

        @StringRes val AUTHENTICATION_PROCESS = R.string.officer_authentication_process

        @StringRes val AUTH_STEPS = R.string.officer_auth_steps

        @StringRes val AUTH_FAILED = R.string.officer_auth_failed

        @StringRes val SESSION_INFO = R.string.officer_session_info

        @StringRes val STATION_INFO = R.string.officer_station_info

        @StringRes val ISSUED_TODAY = R.string.officer_issued_today

        @StringRes val ISSUE_AGE_CREDENTIAL = R.string.officer_issue_age_credential

        @StringRes val ISSUE_DESCRIPTION = R.string.officer_issue_description

        @StringRes val START_ISSUANCE = R.string.officer_start_issuance

        @StringRes val ISSUANCE_PROCESS = R.string.officer_issuance_process

        @StringRes val ISSUANCE_STEPS = R.string.officer_issuance_steps

        @StringRes val VERIFY_IDENTITY = R.string.officer_verify_identity

        @StringRes val SELECT_DOB = R.string.officer_select_dob

        @StringRes val CHANGE_DATE = R.string.officer_change_date

        @StringRes val AGE_YEARS = R.string.officer_age_years

        @StringRes val UNDER_18_WARNING = R.string.officer_under_18_warning

        @StringRes val VERIFICATION_CHECKLIST = R.string.officer_verification_checklist

        @StringRes val DOCUMENT_VERIFIED = R.string.officer_document_verified

        @StringRes val DOCUMENT_VERIFIED_DESCRIPTION = R.string.officer_document_verified_description

        @StringRes val DOB_MATCHES = R.string.officer_dob_matches

        @StringRes val DOB_MATCHES_DESCRIPTION = R.string.officer_dob_matches_description

        @StringRes val ISSUE_CREDENTIAL = R.string.officer_issue_credential

        @StringRes val USER_SCANNED_SUCCESSFULLY = R.string.officer_user_scanned_successfully

        @StringRes val RETURN_TO_DASHBOARD = R.string.officer_return_to_dashboard

        @StringRes val GO_BACK = R.string.officer_go_back

        object Yubikey {
            @StringRes val AUTHENTICATION = R.string.yubikey_authentication

            @StringRes val STEP_FORMAT = R.string.yubikey_step_format

            @StringRes val LED_SHOULD_BLINK = R.string.yubikey_led_should_blink
        }

        object States {
            @StringRes val VALIDATING = R.string.officer_state_validating

            @StringRes val COMPUTING_COMMITMENT = R.string.officer_state_computing_commitment

            @StringRes val CREATING_SESSION = R.string.officer_state_creating_session

            @StringRes val SIGNING = R.string.officer_state_signing

            @StringRes val FINALIZING = R.string.officer_state_finalizing

            @StringRes val STORING_ATTESTATION = R.string.officer_state_storing_attestation
        }
    }

    // ==================== ISSUANCE / ONBOARDING ====================

    object Issuance {
        @StringRes val SCAN_QR = R.string.issuance_scan_qr

        @StringRes val DOWNLOADS_CREDENTIAL = R.string.issuance_downloads_credential

        @StringRes val CENTER_QR = R.string.issuance_center_qr

        @StringRes val ENTER_CODE_MANUALLY = R.string.issuance_enter_code_manually

        @StringRes val PROCESSING_QR = R.string.issuance_processing_qr

        @StringRes val INVALID_DATA = R.string.issuance_invalid_data

        @StringRes val VERIFICATION_QR_ERROR = R.string.issuance_verification_qr_error

        @StringRes val INVALID_QR_FORMAT = R.string.issuance_invalid_qr_format

        @StringRes val FAILED_TO_PROCESS = R.string.issuance_failed_to_process

        @StringRes val CODE = R.string.issuance_code
    }

    // ==================== MANUAL ENTRY ====================

    object ManualEntry {
        @StringRes val TITLE = R.string.manual_entry_title

        @StringRes val VERIFICATION_DESCRIPTION = R.string.manual_entry_verification_description

        @StringRes val ISSUANCE_DESCRIPTION = R.string.manual_entry_issuance_description

        @StringRes val VERIFICATION_CODE = R.string.manual_entry_verification_code

        @StringRes val SUBMIT = R.string.manual_entry_submit

        @StringRes val PLEASE_ENTER = R.string.manual_entry_please_enter

        @StringRes val PLEASE_ENTER_VERIFICATION = R.string.manual_entry_please_enter_verification
    }

    object VoiceInput {
        @StringRes val START_LISTENING = R.string.voice_input_start_listening

        @StringRes val STOP_LISTENING = R.string.voice_input_stop_listening

        @StringRes val RECOGNIZED = R.string.voice_input_recognized

        @StringRes val PERMISSION_TITLE = R.string.voice_input_permission_title

        @StringRes val PERMISSION_MESSAGE = R.string.voice_input_permission_message
    }

    // ==================== COMMON ACTIONS ====================

    object Action {
        @StringRes val BACK = R.string.action_back

        @StringRes val CLOSE = R.string.action_close

        @StringRes val CANCEL = R.string.action_cancel

        @StringRes val OK = R.string.action_ok

        @StringRes val SET = R.string.action_set

        @StringRes val CHANGE = R.string.action_change

        @StringRes val DELETE = R.string.action_delete

        @StringRes val RESET = R.string.action_reset

        @StringRes val RETRY = R.string.action_retry

        @StringRes val TRY_AGAIN = R.string.action_try_again

        @StringRes val REFRESH = R.string.action_refresh

        @StringRes val DOWNLOAD_NOW = R.string.action_download_now

        @StringRes val RETRY_SETUP = R.string.action_retry_setup

        @StringRes val RETRY_DOWNLOAD = R.string.action_retry_download

        @StringRes val RESTART_SETUP = R.string.action_restart_setup

        @StringRes val MANAGE_STORAGE = R.string.action_manage_storage

        @StringRes val CHECK_WIFI_SETTINGS = R.string.action_check_wifi_settings

        @StringRes val CHECK_WIFI_SETTINGS_SHORT = R.string.action_check_wifi_settings_short

        @StringRes val GRANT_PERMISSION = R.string.action_grant_permission

        @StringRes val GRANT_CAMERA_ACCESS = R.string.action_grant_camera_access

        @StringRes val RETURN_TO_BROWSER = R.string.action_return_to_browser

        @StringRes val SHOW_DEBUG_INFO = R.string.action_show_debug_info

        @StringRes val RESET_REDOWNLOAD = R.string.action_reset_redownload

        @StringRes val END_SESSION = R.string.action_end_session

        @StringRes val EXPAND = R.string.action_expand

        @StringRes val COLLAPSE = R.string.action_collapse
    }

    // ==================== ERRORS ====================

    object Error {
        @StringRes val GENERIC = R.string.error_generic

        @StringRes val CAMERA_PERMISSION = R.string.error_camera_permission

        @StringRes val CAMERA_ACCESS_NEEDED = R.string.error_camera_access_needed

        @StringRes val CAMERA_PERMISSION_DESCRIPTION = R.string.error_camera_permission_description

        @StringRes val BIOMETRIC_NOT_AVAILABLE = R.string.error_biometric_not_available

        @StringRes val NETWORK = R.string.error_network

        @StringRes val NO_CREDENTIAL = R.string.error_no_credential

        @StringRes val FAILED_TO_PROCESS_CHALLENGE = R.string.error_failed_to_process_challenge

        @StringRes val FAILED_TO_CREATE_PROOF = R.string.error_failed_to_create_proof

        @StringRes val VERIFICATION_FAILED = R.string.error_verification_failed

        @StringRes val OCCURRED_DURING_VERIFICATION = R.string.error_occurred_during_verification

        @StringRes val CONNECTION_TIMEOUT = R.string.error_connection_timeout

        @StringRes val UNABLE_TO_CONNECT = R.string.error_unable_to_connect

        @StringRes val SECURE_CONNECTION_FAILED = R.string.error_secure_connection_failed

        @StringRes val SECURITY_VERIFICATION_FAILED = R.string.error_security_verification_failed

        @StringRes val INVALID_INPUT = R.string.error_invalid_input

        @StringRes val OPERATION_IN_PROGRESS = R.string.error_operation_in_progress

        @StringRes val OPERATION_CANCELLED = R.string.error_operation_cancelled

        @StringRes val WALLET_NOT_INITIALIZED = R.string.error_wallet_not_initialized

        @StringRes val SECURITY = R.string.error_security

        @StringRes val CONNECTION_TIMEOUT_SHORT = R.string.error_connection_timeout_short

        @StringRes val INVALID_INPUT_PROVIDED = R.string.error_invalid_input_provided

        @StringRes val INVALID_DATA_FORMAT = R.string.error_invalid_data_format

        @StringRes val STORAGE = R.string.error_storage

        @StringRes val NETWORK_SHORT = R.string.error_network_short

        @StringRes val LABEL = R.string.error_label

        @StringRes val DISMISS = R.string.error_dismiss
    }

    // ==================== STATUS ====================

    object Status {
        @StringRes val PROCESSING = R.string.status_processing

        @StringRes val INITIALIZING_WALLET = R.string.status_initializing_wallet

        @StringRes val LOADING = R.string.status_loading
    }

    // ==================== PRIVACY & SECURITY ====================

    object Privacy {
        @StringRes val PROTECTED = R.string.privacy_protected

        @StringRes val ZK_DESCRIPTION = R.string.privacy_zk_description
    }

    // ==================== CONTENT DESCRIPTIONS ====================

    object ContentDescription {
        @StringRes val BACK = R.string.content_desc_back

        @StringRes val SETTINGS = R.string.content_desc_settings

        @StringRes val REFRESH = R.string.content_desc_refresh

        @StringRes val VERIFIED = R.string.content_desc_verified

        @StringRes val EXPAND = R.string.content_desc_expand

        @StringRes val COLLAPSE = R.string.content_desc_collapse
    }

    // ==================== DATE & TIME ====================

    object Date {
        @StringRes val LABEL = R.string.date_label

        @StringRes val OF_BIRTH = R.string.date_of_birth
    }

    // ==================== FORMATS ====================

    object Format {
        @StringRes val AGE_YEARS = R.string.format_age_years

        @StringRes val STEP_INDICATOR = R.string.format_step_indicator

        @StringRes val MB_DOWNLOADED = R.string.format_mb_downloaded

        @StringRes val PERCENTAGE = R.string.format_percentage
    }
}
