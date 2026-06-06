// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// String catalog for internationalisation, providing typed access to all
/// localised string keys used across the wallet app.

import Foundation

/// Type-safe localisation keys for all user-facing strings in Provii Wallet.
enum LocalizedString: String, CaseIterable {

    // MARK: - App Info
    case appName = "app_name"
    case appVersion = "app_version"
    case appTagline = "app_tagline"

    // MARK: - Welcome & Onboarding
    case welcomeTitle = "welcome_title"
    case welcomeSubtitle = "welcome_subtitle"
    case welcomeMessage = "welcome_message"
    case getStarted = "get_started"
    case alreadySetUp = "already_setup"
    case alreadySetUpMessage = "already_setup_message"

    // MARK: - Setup Process
    case setupRequired = "setup_required"
    case setupTitle = "setup_title"
    case downloadRequired = "download_required"
    case downloadRequiredMessage = "download_required_message"
    case downloadNow = "download_now"
    case downloadSize = "download_size"
    case wifiRecommended = "wifi_recommended"
    case checkWifiSettings = "check_wifi_settings"
    case checkingSetupStatus = "checking_setup_status"
    case preparingSecureVerification = "preparing_secure_verification"
    case checkingSecurityComponents = "checking_security_components"
    case downloadingSecurityComponents = "downloading_security_components"
    case initializingSecurityComponents = "initializing_security_components"
    case setupComplete = "setup_complete"
    case setupCompleteMessage = "setup_complete_message"
    case setupFailed = "setup_failed"
    case retrySetup = "retry_setup"
    case takingLongerThanExpected = "taking_longer_than_expected"
    case setupMightBeStuck = "setup_might_be_stuck"

    // MARK: - Setup Error Messages
    case errorStorageFull = "error_storage_full"
    case errorConnectionFailed = "error_connection_failed"
    case errorInitializationFailed = "error_initialization_failed"
    case errorAppNeedsRestart = "error_app_needs_restart"
    case manageStorage = "manage_storage"
    case freeUpStorage = "free_up_storage"
    case retryDownload = "retry_download"
    case checkWifiSettingsAction = "check_wifi_settings_action"
    case restartSetup = "restart_setup"

    // MARK: - Privacy Info
    case privacyProtected = "privacy_protected"
    case privacyMessage = "privacy_message"
    case privacyMessageDetailed = "privacy_message_detailed"
    case oneTimeDownload = "one_time_download"
    case oneTimeDownloadMessage = "one_time_download_message"

    // MARK: - Credentials
    case credential = "credential"
    case credentials = "credentials"
    case noCredential = "no_credential"
    case credentialActive = "credential_active"
    case credentialExpired = "credential_expired"
    case credentialRevoked = "credential_revoked"
    case credentialInvalid = "credential_invalid"
    case credentialSuccessfullyCreated = "credential_successfully_created"
    case credentialSuccessMessage = "credential_success_message"

    // MARK: - Credential Status
    case statusReady = "status_ready"
    case statusReadyForVerification = "status_ready_for_verification"
    case statusNeedsRenewal = "status_needs_renewal"
    case statusNoLongerValid = "status_no_longer_valid"
    case statusCannotBeUsed = "status_cannot_be_used"
    case statusValid = "status_valid"
    case statusProtected = "status_protected"

    // MARK: - Credential Actions
    case scanQRCode = "scan_qr_code"
    case scanQRCodeMessage = "scan_qr_code_message"
    case findLocations = "find_locations"
    case findLocationsMessage = "find_locations_message"
    case getCredential = "get_credential"
    case getCredentialMessage = "get_credential_message"
    case replaceCredential = "replace_credential"
    case replaceCredentialNow = "replace_credential_now"
    case deleteCredential = "delete_credential"
    case deleteCredentialMessage = "delete_credential_message"
    case deleteCredentialConfirm = "delete_credential_confirm"
    case deleteCredentialConfirmMessage = "delete_credential_confirm_message"
    case verifyAge = "verify_age"
    case verifyAgeNow = "verify_age_now"

    // MARK: - Credential Details
    case credentialDetails = "credential_details"
    case credentialId = "credential_id"
    case issuer = "issuer"
    case issued = "issued"
    case expires = "expires"
    case schema = "schema"
    case canVerify = "can_verify"
    case yes = "yes"
    case no = "no"
    case privacy = "privacy"
    case status = "status"
    case fullId = "full_id"
    case schemaVersion = "schema_version"
    case privacyLevel = "privacy_level"
    case zeroKnowledgeProof = "zero_knowledge_proof"

    // MARK: - QR Scanning
    case scanAttestationQR = "scan_attestation_qr"
    case scanVerificationQR = "scan_verification_qr"
    case pointCameraAtQR = "point_camera_at_qr"
    case pointCameraAtVerificationQR = "point_camera_at_verification_qr"
    case qrCodeWillScanAutomatically = "qr_code_will_scan_automatically"
    case alignQRCodeInFrame = "align_qr_code_in_frame"
    case cameraUnavailable = "camera_unavailable"
    case cameraAccessRequired = "camera_access_required"
    case cameraAccessRequiredMessage = "camera_access_required_message"
    case grantCameraAccess = "grant_camera_access"

    // MARK: - Manual Code Entry
    case enterCodeManually = "enter_code_manually"
    case manualCodeEntry = "manual_code_entry"
    case enterVerificationCode = "enter_verification_code"
    case enterCodeHere = "enter_code_here"
    case verificationCode = "verification_code"
    case digit12Code = "digit_12_code"
    case codeExample = "code_example"
    case submitCode = "submit_code"
    case useCameraInstead = "use_camera_instead"
    case useCamera = "use_camera"
    case enterCode = "enter_code"
    case pleaseEnterCode = "please_enter_code"

    // MARK: - Verification Process
    case ageVerification = "age_verification"
    case verifying = "verifying"
    case verified = "verified"
    case verificationFailed = "verification_failed"
    case verificationSuccess = "verification_success"
    case verificationSuccessMessage = "verification_success_message"
    case verificationSuccessDetailed = "verification_success_detailed"
    case verificationFailedMessage = "verification_failed_message"
    case verificationFailedDetailed = "verification_failed_detailed"
    case processingVerification = "processing_verification"
    case readingVerificationRequest = "reading_verification_request"
    case processingChallenge = "processing_challenge"
    case creatingAgeProof = "creating_age_proof"
    case submittingProof = "submitting_proof"
    case ageVerified = "age_verified"
    case ageVerifiedPrivately = "age_verified_privately"
    case returningToBrowser = "returning_to_browser"
    case returnNow = "return_now"
    case confirmVerification = "confirm_verification"
    case confirmVerificationMessage = "confirm_verification_message"

    // MARK: - Step Indicators
    case step = "step"
    case stepOf = "step_of"
    case step1Of2 = "step_1_of_2"
    case step2Of3 = "step_2_of_3"
    case step3Of3 = "step_3_of_3"
    case getYourFirstCredential = "get_your_first_credential"
    case scanVerificationQRCode = "scan_verification_qr_code"
    case processingVerificationStep = "processing_verification_step"
    case verificationComplete = "verification_complete"

    // MARK: - Error Messages
    case error = "error"
    case errorOccurred = "error_occurred"
    case somethingWentWrong = "something_went_wrong"
    case tryAgain = "try_again"
    case retry = "retry"
    case cancel = "cancel"
    case close = "close"
    case dismiss = "dismiss"
    case ok = "ok"
    case done = "done"

    // MARK: - Specific Errors
    case errorWalletNotInitialized = "error_wallet_not_initialized"
    case errorCredentialNotFound = "error_credential_not_found"
    case errorCredentialExpired = "error_credential_expired"
    case errorBiometricAuthFailed = "error_biometric_auth_failed"
    case errorProvingKeyNotFound = "error_proving_key_not_found"
    case errorVerificationFailed = "error_verification_failed"
    case errorInvalidQRCode = "error_invalid_qr_code"
    case errorNetworkTimeout = "error_network_timeout"
    case errorStorageError = "error_storage_error"
    case errorInvalidConfiguration = "error_invalid_configuration"
    case errorOperationCancelled = "error_operation_cancelled"
    case errorNoCredentialAvailable = "error_no_credential_available"
    case errorInvalidAttestationData = "error_invalid_attestation_data"
    case errorInvalidQRFormat = "error_invalid_qr_format"
    case errorWrongQRType = "error_wrong_qr_type"
    case errorUnrecognizedQR = "error_unrecognized_qr"

    // MARK: - Network Error Messages
    case errorNoInternet = "error_no_internet"
    case errorConnectionTimeout = "error_connection_timeout"
    case errorUnableToConnect = "error_unable_to_connect"
    case errorSecureConnectionFailed = "error_secure_connection_failed"
    case errorNetworkConnectionLost = "error_network_connection_lost"
    case errorCellularDataDisabled = "error_cellular_data_disabled"
    case errorNetworkGeneric = "error_network_generic"

    // MARK: - FFI/SDK Error Messages
    case errorInvalidDataFormat = "error_invalid_data_format"
    case errorStorageWithMessage = "error_storage_with_message"
    case errorNetworkWithMessage = "error_network_with_message"
    case errorProofGenerationFailed = "error_proof_generation_failed"
    case errorOperationInProgress = "error_operation_in_progress"
    case errorWalletNotReady = "error_wallet_not_ready"

    // MARK: - File System Error Messages
    case errorFileNotFound = "error_file_not_found"
    case errorPermissionDenied = "error_permission_denied"
    case errorNotEnoughStorage = "error_not_enough_storage"
    case errorFileOperationFailed = "error_file_operation_failed"
    case errorLocationServices = "error_location_services"

    // MARK: - HTTP Error Messages
    case errorNotEligible = "error_not_eligible"
    case errorChallengeExpiredOrNotFound = "error_challenge_expired_or_not_found"
    case errorRequestOutOfOrder = "error_request_out_of_order"
    case errorChallengeExpired = "error_challenge_expired"
    case errorTooManyRequests = "error_too_many_requests"
    case errorServerError = "error_server_error"
    case errorRequestFailed = "error_request_failed"

    // MARK: - App Error Messages
    case errorWalletNotReadyWait = "error_wallet_not_ready_wait"
    case errorAddCredentialFirst = "error_add_credential_first"
    case errorCredentialExpiredGetNew = "error_credential_expired_get_new"
    case errorBiometricTryAgain = "error_biometric_try_again"
    case errorRequiredFilesNotFound = "error_required_files_not_found"
    case errorVerificationFailedWithReason = "error_verification_failed_with_reason"
    case errorInvalidQRCodeScanValid = "error_invalid_qr_code_scan_valid"
    case errorRequestTimedOut = "error_request_timed_out"
    case errorUnexpected = "error_unexpected"

    // MARK: - Error Suggestions
    case errorSuggestionCredential = "error_suggestion_credential"
    case errorSuggestionNetwork = "error_suggestion_network"
    case errorSuggestionQRCode = "error_suggestion_qr_code"

    // MARK: - Simplified Error Messages (WCAG 2.2 AAA: 3.1.5 Reading Level)
    // General Errors - Simplified
    case errorSimplified = "error_simplified"
    case errorOccurredSimplified = "error_occurred_simplified"
    case somethingWentWrongSimplified = "something_went_wrong_simplified"

    // Wallet & Credential Errors - Simplified
    case errorWalletNotInitializedSimplified = "error_wallet_not_initialized_simplified"
    case errorCredentialNotFoundSimplified = "error_credential_not_found_simplified"
    case errorCredentialExpiredSimplified = "error_credential_expired_simplified"
    case errorBiometricAuthFailedSimplified = "error_biometric_auth_failed_simplified"
    case errorProvingKeyNotFoundSimplified = "error_proving_key_not_found_simplified"
    case errorVerificationFailedSimplified = "error_verification_failed_simplified"
    case errorInvalidQRCodeSimplified = "error_invalid_qr_code_simplified"
    case errorStorageErrorSimplified = "error_storage_error_simplified"
    case errorInvalidConfigurationSimplified = "error_invalid_configuration_simplified"
    case errorOperationCancelledSimplified = "error_operation_cancelled_simplified"
    case errorNoCredentialAvailableSimplified = "error_no_credential_available_simplified"
    case errorInvalidAttestationDataSimplified = "error_invalid_attestation_data_simplified"
    case errorInvalidQRFormatSimplified = "error_invalid_qr_format_simplified"
    case errorWrongQRTypeSimplified = "error_wrong_qr_type_simplified"
    case errorUnrecognizedQRSimplified = "error_unrecognized_qr_simplified"

    // Error Suggestions - Simplified
    case errorSuggestionCredentialSimplified = "error_suggestion_credential_simplified"
    case errorSuggestionNetworkSimplified = "error_suggestion_network_simplified"
    case errorSuggestionQRCodeSimplified = "error_suggestion_qr_code_simplified"

    // Network Errors - Simplified
    case errorNoInternetSimplified = "error_no_internet_simplified"
    case errorConnectionTimeoutSimplified = "error_connection_timeout_simplified"
    case errorUnableToConnectSimplified = "error_unable_to_connect_simplified"
    case errorSecureConnectionFailedSimplified = "error_secure_connection_failed_simplified"
    case errorNetworkConnectionLostSimplified = "error_network_connection_lost_simplified"
    case errorCellularDataDisabledSimplified = "error_cellular_data_disabled_simplified"
    case errorNetworkGenericSimplified = "error_network_generic_simplified"
    case errorNetworkTimeoutSimplified = "error_network_timeout_simplified"

    // FFI/SDK Errors - Simplified
    case errorInvalidDataFormatSimplified = "error_invalid_data_format_simplified"
    case errorStorageWithMessageSimplified = "error_storage_with_message_simplified"
    case errorNetworkWithMessageSimplified = "error_network_with_message_simplified"
    case errorProofGenerationFailedSimplified = "error_proof_generation_failed_simplified"
    case errorOperationInProgressSimplified = "error_operation_in_progress_simplified"
    case errorWalletNotReadySimplified = "error_wallet_not_ready_simplified"

    // File System Errors - Simplified
    case errorFileNotFoundSimplified = "error_file_not_found_simplified"
    case errorPermissionDeniedSimplified = "error_permission_denied_simplified"
    case errorNotEnoughStorageSimplified = "error_not_enough_storage_simplified"
    case errorFileOperationFailedSimplified = "error_file_operation_failed_simplified"
    case errorLocationServicesSimplified = "error_location_services_simplified"

    // HTTP Errors - Simplified
    case errorNotEligibleSimplified = "error_not_eligible_simplified"
    case errorChallengeExpiredOrNotFoundSimplified = "error_challenge_expired_or_not_found_simplified"
    case errorRequestOutOfOrderSimplified = "error_request_out_of_order_simplified"
    case errorChallengeExpiredSimplified = "error_challenge_expired_simplified"
    case errorTooManyRequestsSimplified = "error_too_many_requests_simplified"
    case errorServerErrorSimplified = "error_server_error_simplified"
    case errorRequestFailedSimplified = "error_request_failed_simplified"

    // App-Specific Errors - Simplified
    case errorWalletNotReadyWaitSimplified = "error_wallet_not_ready_wait_simplified"
    case errorAddCredentialFirstSimplified = "error_add_credential_first_simplified"
    case errorCredentialExpiredGetNewSimplified = "error_credential_expired_get_new_simplified"
    case errorBiometricTryAgainSimplified = "error_biometric_try_again_simplified"
    case errorRequiredFilesNotFoundSimplified = "error_required_files_not_found_simplified"
    case errorVerificationFailedWithReasonSimplified = "error_verification_failed_with_reason_simplified"
    case errorInvalidQRCodeScanValidSimplified = "error_invalid_qr_code_scan_valid_simplified"
    case errorRequestTimedOutSimplified = "error_request_timed_out_simplified"
    case errorUnexpectedSimplified = "error_unexpected_simplified"

    // Setup Errors - Simplified
    case errorStorageFullSimplified = "error_storage_full_simplified"
    case errorConnectionFailedSimplified = "error_connection_failed_simplified"
    case errorInitializationFailedSimplified = "error_initialization_failed_simplified"
    case errorAppNeedsRestartSimplified = "error_app_needs_restart_simplified"

    // Verification Errors - Simplified
    case verificationFailedSimplified = "verification_failed_simplified"
    case verificationFailedMessageSimplified = "verification_failed_message_simplified"
    case verificationFailedDetailedSimplified = "verification_failed_detailed_simplified"

    // Voice Input Errors - Simplified
    case errorVoiceInputNotAvailableSimplified = "error.voice_input.not_available_simplified"
    case errorVoiceInputTemporarilyUnavailableSimplified = "error.voice_input.temporarily_unavailable_simplified"
    case errorVoiceInputAudioRecordingSimplified = "error.voice_input.audio_recording_simplified"
    case errorVoiceInputNetworkSimplified = "error.voice_input.network_simplified"
    case errorVoiceInputNoSpeechSimplified = "error.voice_input.no_speech_simplified"
    case errorVoiceInputBusySimplified = "error.voice_input.busy_simplified"
    case errorVoiceInputServerSimplified = "error.voice_input.server_simplified"
    case errorVoiceInputPermissionDeniedSimplified = "error.voice_input.permission_denied_simplified"
    case errorVoiceInputTimeoutSimplified = "error.voice_input.timeout_simplified"
    case errorVoiceInputGenericSimplified = "error.voice_input.generic_simplified"

    // Issue Error Messages - Simplified
    case issueErrorInvalidLinkSimplified = "issue_error_invalid_link_simplified"
    case issueErrorExpiredLinkSimplified = "issue_error_expired_link_simplified"
    case issueErrorHmacFailedSimplified = "issue_error_hmac_failed_simplified"
    case issueErrorIssuerUnavailableSimplified = "issue_error_issuer_unavailable_simplified"

    // Credential Generation Errors - Simplified
    case credentialGenerationFailedSimplified = "credential_generation_failed_simplified"
    case failedToDeleteCredentialSimplified = "failed_to_delete_credential_simplified"
    case failedToResetProvingKeySimplified = "failed_to_reset_proving_key_simplified"

    // Age Verification - Simplified
    case ageVerificationFailedSimplified = "age_verification_failed_simplified"
    case errorNoCredentialSimplified = "error_no_credential_simplified"
    case errorNetworkFailedSimplified = "error_network_failed_simplified"
    case errorInvalidQRSimplified = "error_invalid_qr_simplified"
    case errorVerificationFailedDetailSimplified = "error_verification_failed_detail_simplified"

    // MARK: - Settings
    case settings = "settings"
    case accessibility = "accessibility"
    case accessibilitySettings = "accessibility_settings"
    case customizeYourExperience = "customize_your_experience"
    case featuresActive = "features_active"
    case proviiWallet = "provii_wallet"
    case version = "version"
    case environment = "environment"
    case environmentConfiguration = "environment_configuration"
    case currentEnvironment = "current_environment"
    case apiEndpoints = "api_endpoints"
    case sandboxMode = "sandbox_mode"
    case sandboxModeActive = "sandbox_mode_active"
    case sandboxModeMessage = "sandbox_mode_message"
    case usingTestEnvironment = "using_test_environment"

    // MARK: - Settings Actions
    case resetProvingKey = "reset_proving_key"
    case resetProvingKeyMessage = "reset_proving_key_message"
    case resetProvingKeyConfirm = "reset_proving_key_confirm"
    case resetProvingKeyConfirmMessage = "reset_proving_key_confirm_message"
    case environmentSettings = "environment_settings"
    case viewCurrentConfiguration = "view_current_configuration"
    case mintTestCredentialAsIssuer = "mint_test_credential_as_issuer"
    case mintTestCredentialSubtitle = "mint_test_credential_subtitle"

    // MARK: - Accessibility Features
    case largeText = "large_text"
    case highContrast = "high_contrast"
    case reduceMotion = "reduce_motion"
    case voiceInput = "voice_input"
    case voiceControl = "voice_control"
    case quickSettings = "quick_settings"
    case openFullSettings = "open_full_settings"
    case increasedTouchTargets = "increased_touch_targets"
    case hapticFeedback = "haptic_feedback"
    case verboseDescriptions = "verbose_descriptions"
    case simplifiedUI = "simplified_ui"
    case largerButtons = "larger_buttons"
    case simplifiedInterface = "simplified_interface"
    case manualEntry = "manual_entry"

    // MARK: - Voice Control
    case voiceControlActive = "voice_control_active"
    case voiceControlStopped = "voice_control_stopped"
    case voiceControlStarted = "voice_control_started"
    case startVoiceControl = "start_voice_control"
    case stopVoiceControl = "stop_voice_control"
    case listening = "listening"
    case speakCode = "speak_code"
    case sayCommand = "say_command"
    case voiceInputStarted = "voice_input_started"
    case voiceInputStopped = "voice_input_stopped"
    case voiceInputNotAvailable = "voice_input_not_available"
    case heardVoice = "heard_voice"

    // MARK: - Voice Announcements
    case announcementStartingIssuance = "announcement_starting_issuance"
    case announcementOpeningLocations = "announcement_opening_locations"
    case announcementStartingReplacement = "announcement_starting_replacement"
    case announcementOpeningVerification = "announcement_opening_verification"
    case announcementReplacingExpired = "announcement_replacing_expired"
    case announcementOpeningSettings = "announcement_opening_settings"
    case announcementProcessingCredential = "announcement_processing_credential"

    // MARK: - Voice Command Hints
    case voiceHintNoCredential = "voice_hint_no_credential"
    case voiceHintActiveCredential = "voice_hint_active_credential"
    case voiceHintExpiredCredential = "voice_hint_expired_credential"

    // MARK: - State Announcements
    case announcementWelcomeNoCredential = "announcement_welcome_no_credential"
    case announcementCredentialActive = "announcement_credential_active"
    case announcementCredentialExpired = "announcement_credential_expired"
    case announcementCredentialRemoved = "announcement_credential_removed"
    case announcementCredentialNowActive = "announcement_credential_now_active"
    case announcementCredentialHasExpired = "announcement_credential_has_expired"

    // MARK: - Officer Mode
    case officerMode = "officer_mode"
    case officerDashboard = "officer_dashboard"
    case officerDashboardVerbose = "officer_dashboard_verbose"
    case officerAuthentication = "officer_authentication"
    case officerAuthenticationTitle = "officer_authentication_title"
    case officerModeActive = "officer_mode_active"
    case officerModeMessage = "officer_mode_message"
    case officerId = "officer_id"
    case station = "station"
    case issuedToday = "issued_today"
    case dailyLimit = "daily_limit"
    case limitApproaching = "limit_approaching"
    case remaining = "remaining"
    case sessionDuration = "session_duration"
    case sessionStarted = "session_started"
    case sessionStatistics = "session_statistics"

    // MARK: - Issuance Process
    case issueAgeCredential = "issue_age_credential"
    case issueCredentialMessage = "issue_credential_message"
    case issueCredentialDetailed = "issue_credential_detailed"
    case startNewIssuance = "start_new_issuance"
    case issuanceProcess = "issuance_process"
    case endOfficerSession = "end_officer_session"
    case endSessionConfirm = "end_session_confirm"
    case endSessionMessage = "end_session_message"
    case endSessionDetailedMessage = "end_session_detailed_message"
    case endSession = "end_session"
    case sessionContinues = "session_continues"

    // MARK: - Officer Voice Commands
    case voiceHintIssuance = "voice_hint_issuance"
    case voiceHintDashboard = "voice_hint_dashboard"
    case startingNewIssuance = "starting_new_issuance"
    case endingOfficerSession = "ending_officer_session"
    case stepsCount = "steps_count"
    case credentialsIssued = "credentials_issued"
    case outOf = "out_of"
    case warningApproachingLimit = "warning_approaching_limit"
    case noticeCredentialsIssued = "notice_credentials_issued"
    case officerDashboardAnnouncement = "officer_dashboard_announcement"

    // MARK: - Issuance Steps
    case issuanceStep1 = "issuance_step_1"
    case issuanceStep1Detail = "issuance_step_1_detail"
    case issuanceStep2 = "issuance_step_2"
    case issuanceStep2Detail = "issuance_step_2_detail"
    case issuanceStep3 = "issuance_step_3"
    case issuanceStep3Detail = "issuance_step_3_detail"
    case issuanceStep4 = "issuance_step_4"
    case issuanceStep4Detail = "issuance_step_4_detail"
    case issuanceStep5 = "issuance_step_5"
    case issuanceStep5Detail = "issuance_step_5_detail"
    case issuanceImportantWarning = "issuance_important_warning"

    // MARK: - Help & Support
    case needHelp = "need_help"
    case howItWorks = "how_it_works"
    case viewTrainingGuide = "view_training_guide"
    case contactSupport = "contact_support"
    case tapSettingsForOptions = "tap_settings_for_options"
    case helpTapSettingsForOptions = "help_tap_settings_for_options"

    // MARK: - Credential List UI
    case replaceWithNewCredential = "replace_with_new_credential"
    case yourPrivacyIsProtected = "your_privacy_is_protected"
    case privacyExplanation = "privacy_explanation"
    case welcomeSubtitleVerbose = "welcome_subtitle_verbose"
    case welcomeSubtitleSimple = "welcome_subtitle_simple"
    case getCredentialSimple = "get_credential_simple"
    case getCredentialFromIssuer = "get_credential_from_issuer"
    case statusReadyVerbose = "status_ready_verbose"
    case statusReadySimple = "status_ready_simple"
    case tipTextVerbose = "tip_text_verbose"
    case tipTextSimple = "tip_text_simple"
    case expiredMessageVerbose = "expired_message_verbose"
    case expiredMessageSimple = "expired_message_simple"
    case visitAuthorizedIssuer = "visit_authorized_issuer"

    // MARK: - Detailed Instructions
    case instructionStep1 = "instruction_step_1"
    case instructionStep2 = "instruction_step_2"
    case instructionStep3 = "instruction_step_3"
    case instructionStep4 = "instruction_step_4"
    case instructionStep5 = "instruction_step_5"

    // MARK: - Instructions
    case instructions = "instructions"
    case quickTip = "quick_tip"
    case tipVerifyAge = "tip_verify_age"
    case tipVerifyAgeDetailed = "tip_verify_age_detailed"

    // MARK: - Action Buttons
    case back = "back"
    case goBack = "go_back"
    case next = "next"
    case submit = "submit"
    case confirm = "confirm"
    case save = "save"
    case delete = "delete"
    case share = "share"
    case copy = "copy"
    case copyId = "copy_id"
    case shareInfo = "share_info"
    case toggleDetails = "toggle_details"
    case showExtendedInfo = "show_extended_info"
    case hideExtendedInfo = "hide_extended_info"
    case showStats = "show_stats"
    case hideStats = "hide_stats"
    case showDetailedInstructions = "show_detailed_instructions"
    case hideDetailedInstructions = "hide_detailed_instructions"
    case moreOptions = "more_options"
    case continueButton = "continue_button"
    case continuing = "continuing"
    case scanQRCodeInstead = "scan_qr_code_instead"
    case getHelp = "get_help"
    case checkNetworkSettings = "check_network_settings"

    // MARK: - Search
    case popularSearches = "popular_searches"
    case noResultsFound = "no_results_found"
    case searchSuggestions = "search_suggestions"
    case search = "search"
    case searchPlaceholder = "search_placeholder"
    case language = "language"
    case help = "help"

    // Search Item Titles
    case searchAccessibilitySettings = "search_accessibility_settings"
    case searchLargeText = "search_large_text"
    case searchHighContrast = "search_high_contrast"
    case searchVoiceInput = "search_voice_input"
    case searchManualCodeEntry = "search_manual_code_entry"
    case searchSimplifiedUI = "search_simplified_ui"
    case searchColorBlindnessSupport = "search_color_blindness_support"
    case searchSettings = "search_settings"
    case searchLanguage = "search_language"
    case searchMyCredentials = "search_my_credentials"
    case searchGetCredential = "search_get_credential"
    case searchHelp = "search_help"
    case searchPrivacyProtection = "search_privacy_protection"
    case searchAgeVerification = "search_age_verification"

    // Search Item Subtitles
    case searchCustomizeExperience = "search_customize_experience"
    case searchIncreaseTextSize = "search_increase_text_size"
    case searchEnhanceVisibility = "search_enhance_visibility"
    case searchControlWithVoice = "search_control_with_voice"
    case searchTypeCodesInsteadScanning = "search_type_codes_instead_scanning"
    case searchReduceVisualComplexity = "search_reduce_visual_complexity"
    case searchAdjustColorsVisibility = "search_adjust_colors_visibility"
    case searchAppConfiguration = "search_app_configuration"
    case searchChangeAppLanguage = "search_change_app_language"
    case searchViewCredentials = "search_view_credentials"
    case searchFindIssuers = "search_find_issuers"
    case searchGetAssistance = "search_get_assistance"
    case searchDataProtected = "search_data_protected"
    case searchProveAge = "search_prove_age"

    // MARK: - Credential Issuance States
    case encryptedTransfer = "encrypted_transfer"
    case credentialTransferSecure = "credential_transfer_secure"
    case credentialReceived = "credential_received"
    case credentialStoredSecurely = "credential_stored_securely"
    case canVerifyAgePrivately = "can_verify_age_privately"

    // MARK: - Credential Issuance Error Messages
    case failedToFetchCredential = "failed_to_fetch_credential"
    case unexpectedError = "unexpected_error"
    case connectionError = "connection_error"
    case connectionErrorMessage = "connection_error_message"
    case expiredLink = "expired_link"
    case expiredLinkMessage = "expired_link_message"
    case decryptionFailed = "decryption_failed"
    case decryptionFailedMessage = "decryption_failed_message"
    case alreadyClaimed = "already_claimed"
    case alreadyClaimedMessage = "already_claimed_message"
    case processingError = "processing_error"
    case whatHappened = "what_happened"
    case checkYourInternetConnection = "check_your_internet_connection"
    case attemptOfMax = "attempt_of_max"
    case retryingAttempt = "retrying_attempt"
    case operationCancelled = "operation_cancelled"
    case openingSupportEmail = "opening_support_email"

    // MARK: - Credential Issuance Verbose Descriptions
    case establishingSecureConnection = "establishing_secure_connection"
    case verifyingAuthorization = "verifying_authorization"
    case downloadingEncryptedData = "downloading_encrypted_data"
    case decryptingCredential = "decrypting_credential"
    case validatingCredentialAuthenticityIntegrity = "validating_credential_authenticity_integrity"
    case storingCredentialSecurely = "storing_credential_securely"
    case processCompleteCredentialReady = "process_complete_credential_ready"
    case successCredentialReceivedStored = "success_credential_received_stored"

    // MARK: - Credential Issuance States
    case retrievingCredential = "retrieving_credential"
    case connectingToIssuer = "connecting_to_issuer"
    case downloadingCredential = "downloading_credential"
    case storingCredential = "storing_credential"
    case validatingRequest = "validating_request"
    case computingCommitment = "computing_commitment"
    case gettingSignature = "getting_signature"
    case finalizingCredential = "finalizing_credential"
    case storingSecurely = "storing_securely"
    case processingCredentialFromIssuer = "processing_credential_from_issuer"
    case issuingCredential = "issuing_credential"
    case success = "success"
    case credentialReadyToUse = "credential_ready_to_use"

    // MARK: - Deep Link Issuance UI Strings
    case gettingCredential = "getting_credential"
    case issuanceSuccess = "issuance_success"
    case issuanceFailed = "issuance_failed"
    case processingYourCredential = "processing_your_credential"
    case yourCredentialIsReady = "your_credential_is_ready"
    case unableToCompleteIssuance = "unable_to_complete_issuance"
    case authenticatingRequest = "authenticating_request"
    case credentialStoredSecurelyCheck = "credential_stored_securely_check"
    case percentComplete = "percent_complete"
    case thisMayTakeMoment = "this_may_take_moment"
    case thisMayTakeFewSeconds = "this_may_take_few_seconds"
    case failedToGetCredential = "failed_to_get_credential"
    case errorOccurredDuringIssuance = "error_occurred_during_issuance"
    case retryCountFormat = "retry_count_format"
    case whatWentWrong = "what_went_wrong"
    case unknownError = "unknown_error"
    case attemptFailedFormat = "attempt_failed_format"
    case decryptionKeySuggestion = "decryption_key_suggestion"
    case checkInternetConnection = "check_internet_connection"
    case linkExpired = "link_expired"
    case attestationLinkExpired = "attestation_link_expired"
    case requestNewCredential = "request_new_credential"
    case credentialNotFoundTitle = "credential_not_found_title"
    case credentialNotFoundOrClaimed = "credential_not_found_or_claimed"
    case attestationLinkOnceOnly = "attestation_link_once_only"
    case retryingAttemptFormat = "retrying_attempt_format"
    case deepLinkAttestationStarting = "deep_link_attestation_starting"
    case credentialReceivedSuccessfully = "credential_received_successfully"
    case tapContinueWhenReady = "tap_continue_when_ready"
    case continuingAutomatically = "continuing_automatically"
    case errorTryAgainOrScan = "error_try_again_or_scan"
    case errorScanOrGoBack = "error_scan_or_go_back"

    // MARK: - Credential Issuance Error Messages
    case networkErrorOccurred = "network_error_occurred"
    case checkInternetConnectionRetry = "check_internet_connection_retry"
    case requestExpired = "request_expired"
    case issuanceRequestExpired = "issuance_request_expired"
    case requestNewCredentialFromIssuer = "request_new_credential_from_issuer"
    case authenticationFailed = "authentication_failed"
    case unableToVerifyIssuanceRequest = "unable_to_verify_issuance_request"
    case requestSignatureMayBeInvalid = "request_signature_may_be_invalid"
    case issuerError = "issuer_error"
    case credentialIssuerEncounteredError = "credential_issuer_encountered_error"
    case contactIssuerForSupport = "contact_issuer_for_support"

    // MARK: - Session Management
    case sessionExpiring = "session_expiring"
    case sessionExpiringSeconds = "session_expiring_seconds"
    case saveProgressPrompt = "save_progress_prompt"
    case discard = "discard"
    case saveAndContinue = "save_and_continue"

    // MARK: - Error Display
    case suggestionLabel = "suggestion_label"

    // MARK: - Clipboard
    case copiedToClipboard = "copied_to_clipboard"
    case copiedMessage = "copied_message"
    case copiedSuccessfully = "copied_successfully"

    // MARK: - Time & Dates
    case today = "today"
    case inDays = "in_days"
    case daysAgo = "days_ago"
    case minutes = "minutes"
    case hours = "hours"
    case secondsRemaining = "seconds_remaining"
    case timeRemaining = "time_remaining"

    // MARK: - Processing States
    case processing = "processing"
    case processingCredential = "processing_credential"
    case processingQRCode = "processing_qr_code"
    case processingVerificationCode = "processing_verification_code"
    case pleaseWait = "please_wait"
    case loading = "loading"
    case codeValidated = "code_validated"
    case loadingCredential = "loading_credential"
    case codeValidatedSuccessfully = "code_validated_successfully"

    // MARK: - Quick Actions
    case quickActions = "quick_actions"
    case openSettings = "open_settings"
    case openAccessibility = "open_accessibility"

    // MARK: - Navigation
    case home = "home"
    case verification = "verification"
    case getYourCredential = "get_your_credential"

    // MARK: - Sandbox/Testing
    case testCredential = "test_credential"
    case sandboxCredential = "sandbox_credential"
    case sandboxCredentialMessage = "sandbox_credential_message"
    case selectAge = "select_age"
    case dateOfBirth = "date_of_birth"
    case dateOfBirthOptional = "date_of_birth_optional"
    case overrideDefaultDOB = "override_default_dob"
    case defaultDOB = "default_dob"
    case generateCredential = "generate_credential"
    case generating = "generating"
    case testCredentialSaved = "test_credential_saved"
    case idPrefix = "id_prefix"
    case credentialGenerationFailed = "credential_generation_failed"
    case yearsOld = "years_old"
    case age = "age"
    case selectSimulatedAge = "select_simulated_age"

    // MARK: - Permission Descriptions (from Info.plist)
    case permissionCamera = "permission_camera"
    case permissionNFC = "permission_nfc"
    case permissionSpeechRecognition = "permission_speech_recognition"
    case permissionMicrophone = "permission_microphone"
    case permissionFaceID = "permission_face_id"
    case permissionLocalNetwork = "permission_local_network"
    case permissionBluetooth = "permission_bluetooth"

    // MARK: - Abbreviations & Technical Terms
    case qr = "qr"
    case qrCode = "qr_code"
    case qrFull = "qr_full"
    case zkp = "zkp"
    case zkpFull = "zkp_full"
    case dob = "dob"
    case dobFull = "dob_full"
    case id = "id"
    case idFull = "id_full"

    // MARK: - Sandbox Credential Errors
    case errorSandboxInvalidUrl = "error_sandbox_invalid_url"
    case errorSandboxInvalidResponse = "error_sandbox_invalid_response"
    case errorSandboxHttpError = "error_sandbox_http_error"
    case errorSandboxInvalidJson = "error_sandbox_invalid_json"
    case errorSandboxInvalidService = "error_sandbox_invalid_service"
    case errorSandboxMissingFields = "error_sandbox_missing_fields"
    case errorSandboxNetworkError = "error_sandbox_network_error"

    // MARK: - Biometric Authentication
    case biometricEnableTitle = "biometric_enable_title"
    case biometricEnableSubtitle = "biometric_enable_subtitle"

    // MARK: - Issuer Registry
    case errorUnableToLoadIssuerInfo = "error_unable_to_load_issuer_info"

    // MARK: - Localized Content (already in system)
    // These reference existing LocalizedContent keys
    case ageVerificationExplanation = "age_verification_explanation"
    case ageVerificationInstructions = "age_verification_instructions"
    case credentialIssuanceTitle = "credential_issuance_title"
    case credentialIssuanceExplanation = "credential_issuance_explanation"
    case credentialIssuanceInstructions = "credential_issuance_instructions"
    case credentialDescription = "credential_description"
    case zeroKnowledgeExplanation = "zero_knowledge_explanation"
    case setupProvingKey = "setup_proving_key"
    case onboardingWelcome = "onboarding_welcome"
    case onboardingPrivacy = "onboarding_privacy"
    case onboardingGetStarted = "onboarding_get_started"

    // MARK: - Officer Mode / Issuance
    case authenticate = "authenticate"
    case creatingProof = "creating_proof"
    case sessionExpiredReauth = "session_expired_reauth"
    case invalidOfficerIdFormat = "invalid_officer_id_format"
    case touchYubikeyToAuth = "touch_yubikey_to_auth"
    case touchYubikeyToIssue = "touch_yubikey_to_issue"
    case verifyDocumentAndDob = "verify_document_and_dob"
    case invalidDateFormatMessage = "invalid_date_format_message"
    case userMustBe18 = "user_must_be_18"

    // MARK: - Wallet Repository Errors
    case errorProvingKeyNotAvailable = "error_proving_key_not_available"
    case errorProverInitFailed = "error_prover_init_failed"
    case errorBiometricNotAvailable = "error_biometric_not_available"
    case errorAuthenticationFailed = "error_authentication_failed"
    case errorFeatureNotImplemented = "error_feature_not_implemented"
    case errorEnableSandboxMode = "error_enable_sandbox_mode"
    case errorSandboxSecretInvalid = "error_sandbox_secret_invalid"
    case errorSandboxGenerationFailed = "error_sandbox_generation_failed"
    case errorSandboxFetchFailed = "error_sandbox_fetch_failed"

    // MARK: - Officer Auth Errors
    case errorInvalidChallenge = "error_invalid_challenge"
    case errorNoActiveSession = "error_no_active_session"
    case errorDocumentVerificationIncomplete = "error_document_verification_incomplete"
    case errorInvalidDateFormat = "error_invalid_date_format"
    case errorOfficerKeyNotFound = "error_officer_key_not_found"
    case errorEmptyAttestationData = "error_empty_attestation_data"

    // MARK: - YubiKey Errors
    case errorYubikeyNotConnected = "error_yubikey_not_connected"
    case errorYubikeyChallengeFailed = "error_yubikey_challenge_failed"
    case errorYubikeyTimeout = "error_yubikey_timeout"
    case errorYubikeySlotNotConfigured = "error_yubikey_slot_not_configured"
    case errorYubikeyTouchTimeout = "error_yubikey_touch_timeout"
    case errorYubikeyInvalidResponse = "error_yubikey_invalid_response"

    // MARK: - Deep Link Errors
    case errorInvalidBase64 = "error_invalid_base64"
    case errorInvalidUtf8 = "error_invalid_utf8"
    case errorInvalidPayload = "error_invalid_payload"

    // MARK: - Deep Link Sandbox Prompt ()
    case deeplinkSandboxPromptTitle = "deeplink_sandbox_prompt_title"
    case deeplinkSandboxPromptBody = "deeplink_sandbox_prompt_body"
    case deeplinkSandboxPromptPrimary = "deeplink_sandbox_prompt_primary"
    case deeplinkSandboxPromptSecondary = "deeplink_sandbox_prompt_secondary"
    case deeplinkSandboxPromptAnnouncement = "deeplink_sandbox_prompt_announcement"

    // MARK: - Challenge Sandbox Prompt ()
    // Raised when the decoded challenge payload carries
    // `environment: "sandbox"` but the wallet is in production. Distinct
    // from the URL-level prompt because the gateway has already
    // committed to sandbox in a signed payload.
    case challengeSandboxPromptTitle = "challenge_sandbox_prompt_title"
    case challengeSandboxPromptBody = "challenge_sandbox_prompt_body"
    case challengeSandboxPromptPrimary = "challenge_sandbox_prompt_primary"
    case challengeSandboxPromptSecondary = "challenge_sandbox_prompt_secondary"
    case challengeSandboxPromptAnnouncement = "challenge_sandbox_prompt_announcement"

    // MARK: - Sandbox Mode Transition Announcement ()
    // Fired via `UIAccessibility.post(.announcement)` on a
    // production -> sandbox transition so VoiceOver users learn about the
    // environment switch even if the sandbox banner is off-screen.
    case sandboxModeEnabledAnnouncement = "sandbox_mode_enabled_announcement"

    // MARK: - Audio/Sound Errors
    case errorAudioFormatFailed = "error_audio_format_failed"
    case errorAudioEngineNotInit = "error_audio_engine_not_init"

    // MARK: - QR Code Errors
    case errorQrDataTooLarge = "error_qr_data_too_large"
    case errorQrGenerationFailed = "error_qr_generation_failed"

    // MARK: - Biometric Types
    case biometricFaceId = "biometric_face_id"
    case biometricTouchId = "biometric_touch_id"
    case biometricOpticId = "biometric_optic_id"
    case biometricNone = "biometric_none"
    case biometricUnknown = "biometric_unknown"

    // MARK: - UI Labels
    case idLabel = "id_label"
    case navigationPathPrefix = "navigation_path_prefix"
    case noAccessibilityFeaturesActive = "no_accessibility_features_active"
    case percent = "percent"

    // MARK: - Help Text Descriptions
    case helpTextExtraLargeText = "help_text_extra_large_text"
    case helpTextContrastLevel = "help_text_contrast_level"
    case helpTextHighContrast = "help_text_high_contrast"
    case helpTextReduceTransparency = "help_text_reduce_transparency"
    case helpTextColorBlindMode = "help_text_color_blind_mode"
    case helpTextLineSpacing = "help_text_line_spacing"
    case helpTextParagraphSpacing = "help_text_paragraph_spacing"
    case helpTextLetterSpacing = "help_text_letter_spacing"
    case helpTextTextWidth = "help_text_text_width"
    case helpTextLargeTouchTargets = "help_text_large_touch_targets"
    case helpTextReduceMotion = "help_text_reduce_motion"
    case helpTextTimeoutBehavior = "help_text_timeout_behavior"
    case helpTextSimplifiedGestures = "help_text_simplified_gestures"
    case helpTextHapticFeedback = "help_text_haptic_feedback"
    case helpTextSimplifiedUI = "help_text_simplified_ui"
    case helpTextStepIndicators = "help_text_step_indicators"
    case helpTextVerboseDescriptions = "help_text_verbose_descriptions"
    case helpTextConfirmActions = "help_text_confirm_actions"
    case helpTextManualCodeEntry = "help_text_manual_code_entry"
    case helpTextVoiceInput = "help_text_voice_input"
    case helpTextQrScanning = "help_text_qr_scanning"
    case helpTextAgeVerification = "help_text_age_verification"
    case helpTextCredentials = "help_text_credentials"
    case helpTextZeroKnowledge = "help_text_zero_knowledge"
    case helpTextCredentialIssuance = "help_text_credential_issuance"
    case helpTextOfficerMode = "help_text_officer_mode"

    // MARK: - Abbreviation Full Forms
    case abbreviationQr = "abbreviation_qr"
    case abbreviationApi = "abbreviation_api"
    case abbreviationUrl = "abbreviation_url"
    case abbreviationPin = "abbreviation_pin"
    case abbreviationIdFull = "abbreviation_id_full"
    case abbreviationUi = "abbreviation_ui"
    case abbreviationUx = "abbreviation_ux"
    case abbreviationFormat = "abbreviation_format"

    // MARK: - Error Messages
    case errorAudioRecordingCheckMicrophone = "error_audio_recording_check_microphone"
    case errorYubikeyNotSupported = "error_yubikey_not_supported"
    case accessibilityColorBlindFilterActive = "accessibility_color_blind_filter_active"

    /// Returns the localized string for this key
    /// - Parameter level: Optional reading level for accessibility
    /// - Returns: Localized string
    @MainActor
    func localized(level: ReadingLevel? = nil) -> String {
        // First check if this is a LocalizedContent key
        if let contentKey = ContentKey(rawValue: self.rawValue) {
            return LocalizedContentManager.shared.text(for: contentKey, level: level)
        }

        // Otherwise use standard localisation
        return NSLocalizedString(self.rawValue, comment: "")
    }

    /// Returns the localized string with format arguments
    /// - Parameters:
    ///   - arguments: Values to substitute into the format string
    /// - Returns: Formatted localized string
    func localized(_ arguments: CVarArg...) -> String {
        // NSLocalizedString keeps this callable from nonisolated contexts such
        // as LocalizedError.errorDescription. Reading-level content adaptation
        // is applied only by localized(level:), which UI calls on the main actor.
        let format = NSLocalizedString(self.rawValue, comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - String Extension for Convenience

extension String {
    /// Localises the string using the LocalizedString enum if possible
    func localized() -> String {
        if let key = LocalizedString(rawValue: self) {
            return key.localized
        }
        return NSLocalizedString(self, comment: "")
    }
}

// MARK: - Context Comments for Translators

/// Context information for translators to understand string usage.
struct TranslationContext {
    let key: LocalizedString
    let context: String
    let maxLength: Int?
    let placeholders: [String]?
    let screenContext: String

    static let contexts: [TranslationContext] = [
        // Setup
        TranslationContext(
            key: .setupRequired,
            context: "Title for one-time setup screen",
            maxLength: 40,
            placeholders: nil,
            screenContext: "SetupView"
        ),
        TranslationContext(
            key: .downloadRequiredMessage,
            context: "Explanation that security components need to be downloaded (87 MB)",
            maxLength: nil,
            placeholders: ["87 MB"],
            screenContext: "SetupView - ConsentView"
        ),

        // Credentials
        TranslationContext(
            key: .credentialActive,
            context: "Status label when credential is valid and ready to use",
            maxLength: 20,
            placeholders: nil,
            screenContext: "CredentialListView"
        ),
        TranslationContext(
            key: .scanQRCodeMessage,
            context: "Instruction to scan QR code from authorised issuer",
            maxLength: 60,
            placeholders: nil,
            screenContext: "CredentialListView - Empty state"
        ),

        // Verification
        TranslationContext(
            key: .ageVerified,
            context: "Success message after age verification completes",
            maxLength: 30,
            placeholders: nil,
            screenContext: "VerificationChallengeView - Success"
        ),
        TranslationContext(
            key: .verificationSuccessDetailed,
            context: "Detailed explanation of successful verification for verbose mode",
            maxLength: nil,
            placeholders: nil,
            screenContext: "VerificationChallengeView - Success (accessibility)"
        ),

        // Officer Mode
        TranslationContext(
            key: .issueAgeCredential,
            context: "Main action button text for officer dashboard",
            maxLength: 30,
            placeholders: nil,
            screenContext: "OfficerDashboardView"
        ),
        TranslationContext(
            key: .issuanceImportantWarning,
            context: "Critical warning about verifying physical ID",
            maxLength: nil,
            placeholders: nil,
            screenContext: "OfficerDashboardView - Verbose mode"
        ),

        // Errors
        TranslationContext(
            key: .errorCredentialNotFound,
            context: "Error when user tries to verify without a credential",
            maxLength: 80,
            placeholders: nil,
            screenContext: "Various - Error state"
        ),
        TranslationContext(
            key: .errorSuggestionQRCode,
            context: "Helpful suggestion when QR code scan fails",
            maxLength: 100,
            placeholders: nil,
            screenContext: "Error suggestion"
        )
    ]
}

// MARK: - LocalizedString Extension
extension LocalizedString {
    /// Returns the localised string for this key.
    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }

    /// Returns the localised string with formatted arguments.
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self.rawValue, comment: ""), arguments: arguments)
    }
}
