// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Speech
import AVFoundation

/// Officer credential issuance view for entering a date of birth from government-issued ID.
/// Presents an accessible date picker with manual entry fallback, document verification
/// checklist, and YubiKey touch overlay for final authorisation. Conforms to WCAG 2.2 AA
/// touch target sizing and VoiceOver labelling requirements.
struct OfficerIssueDobView: View {
    @StateObject private var officerAuthManager = OfficerAuthManager.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @State private var selectedDob: Date?
    @State private var documentVerified = false
    @State private var dobMatches = false
    @State private var showDatePicker = false
    @State private var showSessionExpiryWarning = false
    @State private var restoredFromPreservedData = false
    @State private var showPreservationErrorAlert = false

    // Accessibility states
    @State private var voiceControlActive = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showManualDateEntry = false
    @State private var manualYear = ""
    @State private var manualMonth = ""
    @State private var manualDay = ""
    @State private var currentProcessStep = 0
    @State private var lastAnnouncedState: OfficerAuthManager.IssuanceState?

    // Focus management
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case year, month, day
        case changeButton
        case manualEntryButton
        case selectDobButton
        case enterManuallyButton
    }

    // Focus restoration for WCAG 2.4.3
    @State private var savedFocus: Field?

    private var age: Int? {
        guard let dob = selectedDob else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    private var isFormValid: Bool {
        guard let age, age >= 18, documentVerified, dobMatches else { return false }
        switch officerAuthManager.issuanceState {
        case .idle, .error:
            return true
        default:
            return false
        }
    }

    private var isProcessing: Bool {
        switch officerAuthManager.issuanceState {
        case .validatingInput, .creatingSession, .creatingAttestation,
             .waitingForYubikeyTouch:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                // Accessibility status (verbose mode)
                if accessibilityManager.settings.verboseDescriptions {
                    accessibleStatusCard
                }

                accessibleHeaderSection
                accessibleDateSelectionSection

                if let age, age < 18 {
                    accessibleUnder18Warning
                }

                accessibleVerificationChecklistSection
                accessibleStatusView

                // Help section (simplified UI)
                if accessibilityManager.settings.simplifiedUI {
                    accessibleHelpSection
                }

                Spacer().frame(minHeight: 20)
                accessibleIssueButton

                // Voice hints
                if accessibilityManager.settings.enableVoiceInput && voiceControlActive {
                    voiceCommandHints
                }
            }
            .padding(padding)
        }
        .background(AccessibleColors.background)
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of DOB entry during issuance
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(
            accessibilityManager.settings.useExtraLargeText ? .large : .inline
        )
        // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
        .setNavigationPath(["Home", "Officer Mode", "Issue Credential", "Enter Date of Birth"])
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showDatePicker) {
            AccessibleDatePickerSheet(selectedDate: $selectedDob)
                .sheetKeyboardNavigation(isPresented: $showDatePicker)
        }
        .onChange(of: showDatePicker) { _, isShowing in
            if isShowing {
                savedFocus = focusedField
            } else if let saved = savedFocus {
                focusedField = saved
                savedFocus = nil
            }
        }
        .sheet(isPresented: $showManualDateEntry) {
            AccessibleManualDateEntry(
                selectedDate: $selectedDob,
                year: $manualYear,
                month: $manualMonth,
                day: $manualDay
            )
            .sheetKeyboardNavigation(isPresented: $showManualDateEntry)
        }
        .onChange(of: showManualDateEntry) { _, isShowing in
            if isShowing {
                savedFocus = focusedField
            } else if let saved = savedFocus {
                focusedField = saved
                savedFocus = nil
            }
        }
        .overlay {
            if case .waitingForYubikeyTouch(let message, let step, let totalSteps) = officerAuthManager.issuanceState {
                AccessibleYubikeyTouchOverlay(
                    message: message,
                    step: step,
                    totalSteps: totalSteps
                )
            }
        }
        .onReceive(officerAuthManager.$issuanceState) { newState in
            handleStateChange(newState)
        }
        .onReceive(officerAuthManager.$sessionExpiryWarning) { warning in
            showSessionExpiryWarning = warning
        }
        .alert(NSLocalizedString("alert.session.expiring_title", comment: "Session expiring alert title"), isPresented: $showSessionExpiryWarning) {
            Button(NSLocalizedString("alert.session.save_continue", comment: "Save and continue button")) {
                Task {
                    let dobDays: Int32? = selectedDob.map { dob in
                        Int32(dob.timeIntervalSince1970 / 86400)
                    }
                    let preserved = await officerAuthManager.preserveIssuanceData(
                        dobDays: dobDays,
                        documentVerified: documentVerified,
                        dobMatches: dobMatches
                    )
                    if preserved {
                        showSessionExpiryWarning = false
                    } else {
                        // Keep session expiry dialog closed (it cannot be re-presented while
                        // the error alert is showing) and show the preservation failure alert.
                        showSessionExpiryWarning = false
                        showPreservationErrorAlert = true
                    }
                }
            }
            Button(NSLocalizedString("alert.session.continue_without_saving", comment: "Continue without saving button"), role: .destructive) {
                showSessionExpiryWarning = false
            }
        } message: {
            Text(String(format: NSLocalizedString("alert.session.expiring_message", comment: "Session expiring message with time"), officerAuthManager.timeUntilExpiry))
        }
        .alert(NSLocalizedString("alert.preservation_failed.title", comment: "Preservation failed alert title"), isPresented: $showPreservationErrorAlert) {
            Button(NSLocalizedString("alert.preservation_failed.dismiss", comment: "Dismiss preservation failure alert"), role: .cancel) {
                showPreservationErrorAlert = false
            }
        } message: {
            Text(NSLocalizedString("alert.preservation_failed.message", comment: "Preservation failed alert message"))
        }
        .onAppear {
            setupAccessibility()
            restorePreservedData()
        }
        .onDisappear {
            cleanupAccessibility()
        }
    }

    // MARK: - Accessible Components

    private var accessibleStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AccessibleColors.primary)
                Text(NSLocalizedString("officer.issue_dob.credential_issuance", comment: "Credential issuance heading"))
                    .font(AccessibleTypography.headline)
            }

            Text(NSLocalizedString("officer.issue_dob.enter_dob_instructions", comment: "Instructions to enter DOB from government ID"))
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(cardPadding)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
    }

    private var accessibleHeaderSection: some View {
        HStack(spacing: 12) {
            ZStack {
                if accessibilityManager.settings.useHighContrast {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 48, height: 48)
                }
                Image(systemName: "person.badge.shield.checkmark")
                    .font(headerIconSize)
                    .foregroundColor(headerIconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("officer.issue_dob.verify_identity", comment: "Verify user identity heading"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)

                if accessibilityManager.settings.showStepNumbers {
                    Text(NSLocalizedString("officer.issue_dob.step_enter_dob", comment: "Step 2: Enter Date of Birth"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.officer.verify_identity.label", comment: "Verify identity label"))
    }

    @ViewBuilder
    private var accessibleDateSelectionSection: some View {
        VStack(spacing: 16) {
            if let selectedDob {
                VStack(spacing: 12) {
                    Text(NSLocalizedString("officer.issue_dob.dob_label", comment: "DATE OF BIRTH label"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    Text(selectedDob.formatted(date: .long, time: .omitted))
                        .font(AccessibleTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)

                    Text(selectedDob.ISO8601Format().prefix(10))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)

                    if let age {
                        HStack {
                            Image(systemName: age >= 18 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(age >= 18 ? AccessibleColors.success : AccessibleColors.error)
                            Text(String(format: NSLocalizedString("officer.issue_dob.age_years", comment: "Age in years display"), age))
                                .font(AccessibleTypography.headline)
                                .foregroundColor(age >= 18 ? textColor : AccessibleColors.error)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(
                            format: NSLocalizedString("accessibility.officer.age_status.label", comment: "Age status label"),
                            age,
                            age >= 18
                                ? NSLocalizedString("accessibility.officer.age_eligible", comment: "Eligible")
                                : NSLocalizedString("accessibility.officer.age_not_eligible", comment: "Not eligible")))
                    }

                    HStack(spacing: 12) {
                        Button(NSLocalizedString("officer.issue_dob.change_date", comment: "Change date button")) {
                            showDatePicker = true
                            HapticFeedback.selection()
                        }
                        .focused($focusedField, equals: .changeButton)
                        .buttonStyle(AccessibleSecondaryButtonStyle())
                        .accessibilitySortPriority(2)

                        if accessibilityManager.settings.enableManualCodeEntry {
                            Button(NSLocalizedString("officer.issue_dob.manual_entry", comment: "Manual entry button")) {
                                showManualDateEntry = true
                                HapticFeedback.selection()
                            }
                            .focused($focusedField, equals: .manualEntryButton)
                            .buttonStyle(AccessibleSecondaryButtonStyle())
                            .accessibilitySortPriority(1)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        showDatePicker = true
                        HapticFeedback.selection()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .font(AccessibleTypography.body)
                            Text(NSLocalizedString("officer.issue_dob.select_dob", comment: "Select date of birth button"))
                                .font(AccessibleTypography.body)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .focused($focusedField, equals: .selectDobButton)
                    .buttonStyle(AccessiblePrimaryButtonStyle())
                    .accessibilitySortPriority(2)

                    if accessibilityManager.settings.enableManualCodeEntry {
                        Button {
                            showManualDateEntry = true
                            HapticFeedback.selection()
                        } label: {
                            HStack {
                                Image(systemName: "keyboard")
                                Text(NSLocalizedString("officer.issue_dob.enter_manually", comment: "Enter manually button"))
                            }
                            .font(AccessibleTypography.body)
                            .frame(maxWidth: .infinity)
                        }
                        .focused($focusedField, equals: .enterManuallyButton)
                        .buttonStyle(AccessibleSecondaryButtonStyle())
                        .accessibilitySortPriority(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .background(dateSelectionBackground)
        .accessibilityElement(children: .contain)
    }

    private var accessibleUnder18Warning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.headline)
                .foregroundColor(AccessibleColors.error)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("officer.issue_dob.under_18_title", comment: "Under 18 cannot issue title"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.error)

                Text(NSLocalizedString("officer.issue_dob.under_18_message", comment: "Under 18 cannot issue message"))
                    .font(AccessibleTypography.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(warningBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.officer.under_18_warning.label", comment: "Under 18 warning label"))
        .onAppear {
            announceIfVoiceOver(NSLocalizedString("officer.issue_dob.under_18_announce", comment: "Under 18 warning announcement"))
        }
    }

    private var accessibleVerificationChecklistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(NSLocalizedString("officer.issue_dob.verification_checklist", comment: "Verification checklist heading"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)

                if accessibilityManager.settings.showStepNumbers {
                    Spacer()
                    Text(String(format: NSLocalizedString("officer.issue_dob.checklist_progress", comment: "Checklist progress count"), checklistCompleteCount, 2))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: checklistSpacing) {
                AccessibleChecklistItem(
                    isChecked: $documentVerified,
                    title: NSLocalizedString("officer.issue_dob.checklist_document", comment: "Physical document verified checklist item"),
                    subtitle: documentVerificationSubtitle,
                    isEnabled: selectedDob != nil && !isProcessing,
                    number: 1
                )

                AccessibleChecklistItem(
                    isChecked: $dobMatches,
                    title: NSLocalizedString("officer.issue_dob.checklist_dob_matches", comment: "Date of birth matches checklist item"),
                    subtitle: dobMatchSubtitle,
                    isEnabled: selectedDob != nil && !isProcessing,
                    number: 2
                )
            }

            if accessibilityManager.settings.verboseDescriptions {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(AccessibleColors.warning)
                    Text(NSLocalizedString("officer.issue_dob.checklist_warning", comment: "Checklist verification warning"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(checklistBackground)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var accessibleStatusView: some View {
        switch officerAuthManager.issuanceState {
        case .error(let message, let canRetry):
            AccessibleErrorCard(
                message: message,
                canRetry: canRetry,
                onRetry: { officerAuthManager.resetIssuance() }
            )

        case .validatingInput:
            AccessibleStatusCard(icon: "checkmark.circle", text: NSLocalizedString("officer.issue_dob.status_validating", comment: "Validating input status"), step: 1)
        case .creatingSession:
            AccessibleStatusCard(icon: "lock", text: NSLocalizedString("officer.issue_dob.status_creating_session", comment: "Creating secure session status"), step: 2)
        case .creatingAttestation:
            AccessibleStatusCard(icon: "signature", text: NSLocalizedString("officer.issue_dob.status_creating_attestation", comment: "Creating attestation status"), step: 3)
        default:
            EmptyView()
        }
    }

    private var accessibleHelpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(AccessibleColors.primary)
                Text(NSLocalizedString("officer.issue_dob.need_help", comment: "Need help heading"))
                    .font(AccessibleTypography.headline)
            }

            Text(NSLocalizedString("officer.issue_dob.help_message", comment: "Help message for checking ID"))
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.primary.opacity(0.1))
        )
    }

    private var accessibleIssueButton: some View {
        Button {
            issueCredential()
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    if accessibilityManager.settings.reduceMotion {
                        Image(systemName: "hourglass")
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: buttonProgressColor))
                            .scaleEffect(0.9)
                    }
                } else {
                    Image(systemName: "checkmark")
                        .font(AccessibleTypography.callout)
                }

                Text(isProcessing ? NSLocalizedString("officer.issue_dob.issuing_button", comment: "Issuing button text") : NSLocalizedString("officer.issue_dob.issue_credential_button", comment: "Issue credential button"))
                    .font(AccessibleTypography.headline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, buttonPadding)
        }
        .buttonStyle(AccessiblePrimaryButtonStyle())
        .disabled(!isFormValid || isProcessing)
        .accessibilityLabel(buttonAccessibilityLabel)
        .accessibilityHint(buttonAccessibilityHint)
    }

    private var voiceCommandHints: some View {
        Text(NSLocalizedString("officer.issue_dob.voice_hints", comment: "Voice command hints"))
            .font(AccessibleTypography.caption)
            .foregroundColor(.secondary)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                officerAuthManager.resetIssuance()
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    if accessibilityManager.settings.verboseDescriptions {
                        Text(NSLocalizedString("officer.issue_dob.cancel_button", comment: "Cancel button"))
                    }
                }
            }
            .accessibilityLabel(NSLocalizedString("accessibility.officer.cancel_issuance.label", comment: "Cancel issuance label"))
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if accessibilityManager.settings.enableVoiceInput {
                Button(action: toggleVoiceControl) {
                    Image(systemName: voiceControlActive ? "mic.fill" : "mic")
                        .foregroundColor(voiceControlActive ? .red : .primary)
                }
                .accessibilityLabel(voiceControlActive ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
            }
        }
    }

    // MARK: - Helper Properties

    private var spacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var padding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 28 : 24
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var buttonPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 20 : 16
    }

    private var checklistSpacing: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 16 : 12
    }

    private var headerIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title3 : AccessibleTypography.title3
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    private var headerIconColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .accentColor
    }

    private var buttonProgressColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .white
    }

    private var navigationTitle: String {
        accessibilityManager.settings.verboseDescriptions ? NSLocalizedString("officer.issue_dob.nav_title_verbose", comment: "Issue age credential nav title") : NSLocalizedString("officer.issue_dob.nav_title", comment: "Issue credential nav title")
    }

    private var checklistCompleteCount: Int {
        (documentVerified ? 1 : 0) + (dobMatches ? 1 : 0)
    }

    private var documentVerificationSubtitle: String? {
        if accessibilityManager.settings.verboseDescriptions {
            return NSLocalizedString("officer.issue_dob.document_subtitle_verbose", comment: "Document verification subtitle verbose")
        }
        return NSLocalizedString("officer.issue_dob.document_subtitle", comment: "Document verification subtitle")
    }

    private var dobMatchSubtitle: String? {
        guard let dob = selectedDob else { return nil }
        return String(format: NSLocalizedString("officer.issue_dob.dob_match_subtitle", comment: "DOB match subtitle with date"), dob.formatted(date: .long, time: .omitted))
    }

    private var buttonAccessibilityLabel: String {
        if isProcessing {
            return NSLocalizedString("officer.issue_dob.button_issuing_label", comment: "Issuing credential accessibility label")
        }
        if !isFormValid {
            var reasons: [String] = []
            if selectedDob == nil { reasons.append(NSLocalizedString("officer.issue_dob.reason_select_date", comment: "select date reason")) }
            if let age, age < 18 { reasons.append(NSLocalizedString("officer.issue_dob.reason_under_18", comment: "user under 18 reason")) }
            if !documentVerified { reasons.append(NSLocalizedString("officer.issue_dob.reason_verify_doc", comment: "verify document reason")) }
            if !dobMatches { reasons.append(NSLocalizedString("officer.issue_dob.reason_confirm_match", comment: "confirm match reason")) }
            return String(format: NSLocalizedString("officer.issue_dob.cannot_issue_reasons", comment: "Cannot issue with reasons"), reasons.joined(separator: ", "))
        }
        return NSLocalizedString("officer.issue_dob.button_issue_label", comment: "Issue credential button label")
    }

    private var buttonAccessibilityHint: String {
        isFormValid ? NSLocalizedString("officer.issue_dob.button_hint_valid", comment: "Double tap to issue hint") : NSLocalizedString("officer.issue_dob.button_hint_invalid", comment: "Complete requirements hint")
    }

    // Background styles
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AccessibleColors.cardBackground)
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var dateSelectionBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(selectedDob != nil ?
                  AccessibleColors.primary.opacity(0.15) :
                  Color(uiColor: .secondarySystemFill))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var warningBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AccessibleColors.error.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AccessibleColors.error, lineWidth: 2)
            )
    }

    private var checklistBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .systemBackground))
            .overlay(
                accessibilityManager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1) : nil
            )
    }

    // MARK: - Methods

    private func restorePreservedData() {
        guard let preserved = officerAuthManager.restoreIssuanceData() else { return }

        // Only restore if we have an active session
        guard officerAuthManager.currentSession != nil else {
            #if DEBUG
            SecureLogger.shared.debug("Preserved data found but no active session, clearing", redact: false)
            #endif
            officerAuthManager.clearPreservedData()
            return
        }

        // Restore form state: reconstruct Date from dobDays
        if let days = preserved.dobDays {
            selectedDob = Date(timeIntervalSince1970: Double(days) * 86400)
        }
        documentVerified = preserved.documentVerified
        dobMatches = preserved.dobMatches
        restoredFromPreservedData = true

        announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_data_restored", comment: "Form data restored announcement"))
        #if DEBUG
        SecureLogger.shared.debug("Form data restored from preservation", redact: false)
        #endif

        // Clear preserved data after successful restoration
        officerAuthManager.clearPreservedData()
    }

    private func issueCredential() {
        guard let selectedDob else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dobIso = formatter.string(from: selectedDob)

        currentProcessStep = 1
        HapticFeedback.selection()
        announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_starting", comment: "Starting credential issuance announcement"))

        Task {
            // Preserve data before starting issuance (in case of error/timeout).
            // A failure here does not block issuance; the officer loses
            // the ability to restore state on retry but can re-enter details.
            let dobDays = Int32(selectedDob.timeIntervalSince1970 / 86400)
            let preIssuancePreserved = await officerAuthManager.preserveIssuanceData(
                dobDays: dobDays,
                documentVerified: documentVerified,
                dobMatches: dobMatches
            )
            if !preIssuancePreserved {
                SecureLogger.shared.warning("OfficerIssueDobView: pre-issuance preservation failed; proceeding with attestation")
            }

            do {
                _ = try await officerAuthManager.createAttestation(
                    dobIso: dobIso,
                    documentVerified: documentVerified,
                    dobMatches: dobMatches
                )
                // Clear preserved data on success
                officerAuthManager.clearPreservedData()
            } catch {
                SecureLogger.shared.error("Failed to issue credential: \(error.localizedDescription)")
                announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_failed", comment: "Failed to issue credential announcement"))
                // Preserved data remains for retry
            }
        }
    }

    private func handleStateChange(_ newState: OfficerAuthManager.IssuanceState) {
        if case let .complete(attestationData, _) = newState {
            navigationCoordinator.showOfficerAttestationQR(attestationData: attestationData)
        }

        // Announce state changes
        if lastAnnouncedState != newState {
            lastAnnouncedState = newState
            announceStateChange(newState)
        }
    }

    private func announceStateChange(_ state: OfficerAuthManager.IssuanceState) {
        switch state {
        case .validatingInput:
            announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_validating", comment: "Validating input announcement"))
        case .creatingAttestation:
            announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_creating_attestation", comment: "Creating attestation announcement"))
        case .waitingForYubikeyTouch:
            announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_touch_yubikey", comment: "Touch YubiKey announcement"))
        case .complete:
            announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_success", comment: "Attestation created successfully announcement"))
        case .error(let message, _):
            announceIfVoiceOver(String(format: NSLocalizedString("officer.issue_dob.announce_error", comment: "Error announcement with message"), message))
        default:
            break
        }
    }

    // Voice control methods continue...
    private func toggleVoiceControl() {
        if voiceControlActive {
            speechRecognizer.stopListening()
            voiceControlActive = false
        } else {
            speechRecognizer.startListening()
            voiceControlActive = true
            announceIfVoiceOver(NSLocalizedString("officer.issue_dob.announce_voice_active", comment: "Voice control active announcement"))
        }
        HapticFeedback.selection()
    }

    private func setupAccessibility() {
        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }
    }

    private func cleanupAccessibility() {
        if voiceControlActive {
            speechRecognizer.stopListening()
        }
    }

    private func setupVoiceCommands() {
        speechRecognizer.onRecognizedCommand = { command in
            handleVoiceCommand(command)
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let lowercased = command.lowercased()

        if lowercased.contains("issue") && isFormValid {
            issueCredential()
        } else if lowercased.contains("check document") {
            documentVerified = true
        } else if lowercased.contains("check match") {
            dobMatches = true
        } else if lowercased.contains("cancel") {
            dismiss()
        }
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// Supporting components
struct AccessibleChecklistItem: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Binding var isChecked: Bool
    let title: String
    let subtitle: String?
    let isEnabled: Bool
    let number: Int

    var body: some View {
        Button(action: {
            if isEnabled {
                isChecked.toggle()
                provideHapticFeedback()
            }
        }, label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(manager.settings.useExtraLargeText ? AccessibleTypography.title3 : AccessibleTypography.headline)
                    .foregroundColor(isChecked ? AccessibleColors.success : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(number). \(title)")
                        .font(AccessibleTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(manager.settings.useHighContrast ? .black : .primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(AccessibleTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        })
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString("accessibility.officer.checklist_item.label", comment: "Checklist item label"),
            number,
            title,
            isChecked
                ? NSLocalizedString("accessibility.officer.checklist_item.checked", comment: "Checked")
                : NSLocalizedString("accessibility.officer.checklist_item.not_checked", comment: "Not checked")))
        .accessibilityHint(isEnabled ? NSLocalizedString("accessibility.officer.checklist_item.enabled_hint", comment: "Enabled hint") : NSLocalizedString("accessibility.officer.checklist_item.disabled_hint", comment: "Disabled hint"))
    }

    private func provideHapticFeedback() {
        guard manager.settings.hapticFeedback else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

struct AccessibleStatusCard: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let icon: String
    let text: String
    let step: Int

    var body: some View {
        HStack(spacing: 12) {
            if manager.settings.reduceMotion {
                Image(systemName: "hourglass")
                    .font(AccessibleTypography.headline)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Image(systemName: icon)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.primary)

            VStack(alignment: .leading) {
                Text(text)
                    .font(AccessibleTypography.body)
                if manager.settings.showStepNumbers {
                    Text(String(format: NSLocalizedString("officer.issue_dob.status_step", comment: "Step X of 3"), step))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.officer.status_card.label", comment: "Status card label"), text, step))
    }
}

struct AccessibleErrorCard: View {
    let message: String
    let canRetry: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(AccessibleColors.error)
                Text(NSLocalizedString("officer.issue_dob.error_title", comment: "Error title"))
                    .font(AccessibleTypography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AccessibleColors.error)
            }

            Text(message)
                .font(AccessibleTypography.body)
                .foregroundColor(.secondary)

            if canRetry {
                Button(NSLocalizedString("officer.issue_dob.try_again", comment: "Try again button"), action: onRetry)
                    .buttonStyle(AccessibleSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.error.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AccessibleColors.error, lineWidth: 2)
                )
        )
    }
}

// MARK: - AccessibleDatePickerSheet

struct AccessibleDatePickerSheet: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    @State private var tempDate: Date

    init(selectedDate: Binding<Date?>) {
        _selectedDate = selectedDate
        let eighteenYearsAgo = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        _tempDate = State(initialValue: selectedDate.wrappedValue ?? eighteenYearsAgo)
    }

    var body: some View {
        NavigationStack {
            VStack {
                if manager.settings.verboseDescriptions {
                    Text(NSLocalizedString("officer.datepicker.instructions", comment: "Date picker instructions"))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.secondary)
                        .padding()
                }

                DatePicker(
                    NSLocalizedString("officer.datepicker.date_of_birth", comment: "Date of Birth label"),
                    selection: $tempDate,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .accessibilityLabel(NSLocalizedString("accessibility.officer.date_of_birth_selector.label", comment: "Accessibility label for date of birth picker"))

                Spacer()
            }
            .navigationTitle(NSLocalizedString("officer.datepicker.select_dob_title", comment: "Select Date of Birth navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("officer.datepicker.cancel_button", comment: "Cancel button")) {
                        dismiss()
                    }
                    .font(manager.settings.useExtraLargeText ? AccessibleTypography.body : .body)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("officer.datepicker.done_button", comment: "Done button")) {
                        selectedDate = tempDate
                        dismiss()
                    }
                    .font(manager.settings.useExtraLargeText ? AccessibleTypography.body : .body)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var dateRange: ClosedRange<Date> {
        let now = Date()
        let minDate = Calendar.current.date(byAdding: .year, value: -120, to: now) ?? now
        return minDate...now
    }
}

// MARK: - AccessibleManualDateEntry

struct AccessibleManualDateEntry: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    @Binding var year: String
    @Binding var month: String
    @Binding var day: String

    // Focus management for keyboard navigation
    @FocusState private var focusedField: DateField?

    enum DateField {
        case year, month, day
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(NSLocalizedString("officer.manual_entry.title", comment: "Enter Date of Birth title"))
                    .font(AccessibleTypography.headline)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 16) {
                    VStack {
                        Text(NSLocalizedString("officer.manual_entry.year_label", comment: "Year label"))
                            .font(AccessibleTypography.caption)
                        TextField(NSLocalizedString("officer.manual_entry.year_placeholder", comment: "YYYY placeholder"), text: $year)
                            .textContentType(.dateTime)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(AccessibleTypography.title3)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .year)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .month
                            }
                            .accessibilityLabel(NSLocalizedString("accessibility.officer.year_of_birth.label", comment: "Year of birth"))
                            .accessibilityHint(NSLocalizedString("accessibility.officer.year_of_birth.hint", comment: "Enter 4 digit year"))
                            .accessibilitySortPriority(3)
                    }

                    VStack {
                        Text(NSLocalizedString("officer.manual_entry.month_label", comment: "Month label"))
                            .font(AccessibleTypography.caption)
                        TextField(NSLocalizedString("officer.manual_entry.month_placeholder", comment: "MM placeholder"), text: $month)
                            .textContentType(.dateTime)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(AccessibleTypography.title3)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .month)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .day
                            }
                            .accessibilityLabel(NSLocalizedString("accessibility.officer.month_of_birth.label", comment: "Month of birth"))
                            .accessibilityHint(NSLocalizedString("accessibility.officer.month_of_birth.hint", comment: "Enter 2 digit month"))
                            .accessibilitySortPriority(2)
                    }

                    VStack {
                        Text(NSLocalizedString("officer.manual_entry.day_label", comment: "Day label"))
                            .font(AccessibleTypography.caption)
                        TextField(NSLocalizedString("officer.manual_entry.day_placeholder", comment: "DD placeholder"), text: $day)
                            .textContentType(.dateTime)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(AccessibleTypography.title3)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .day)
                            .submitLabel(.done)
                            .onSubmit {
                                if let date = createDate() {
                                    selectedDate = date
                                    dismiss()
                                }
                            }
                            .accessibilityLabel(NSLocalizedString("accessibility.officer.day_of_birth.label", comment: "Day of birth"))
                            .accessibilityHint(NSLocalizedString("accessibility.officer.day_of_birth.hint", comment: "Enter 2 digit day"))
                            .accessibilitySortPriority(1)
                    }
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("officer.manual_entry.nav_title", comment: "Manual Date Entry navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("officer.manual_entry.cancel_button", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("officer.manual_entry.done_button", comment: "Done button")) {
                        if let date = createDate() {
                            selectedDate = date
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                // Auto-focus on year field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .year
                }
            }
        }
    }

    private func createDate() -> Date? {
        guard let yearInt = Int(year),
              let monthInt = Int(month),
              let dayInt = Int(day) else { return nil }

        var components = DateComponents()
        components.year = yearInt
        components.month = monthInt
        components.day = dayInt

        return Calendar.current.date(from: components)
    }
}

// MARK: - AccessibleYubikeyTouchOverlay

struct AccessibleYubikeyTouchOverlay: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let message: String
    let step: Int
    let totalSteps: Int

    @State private var scale: CGFloat = 0.9
    @State private var ledOpacity: Double = 0.2

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AccessibleColors.primary.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(manager.settings.reduceMotion ? 1.0 : scale)

                    Image(systemName: "key.fill")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(AccessibleColors.primary)

                    if !manager.settings.reduceMotion {
                        Circle()
                            .fill(Color.green.opacity(ledOpacity))
                            .frame(width: 12, height: 12)
                            .offset(x: 25, y: -25)
                    }
                }
                .onAppear {
                    if !manager.settings.reduceMotion {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            scale = 1.1
                        }
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            ledOpacity = 1.0
                        }
                    }
                }

                Text(NSLocalizedString("officer.yubikey.auth_title", comment: "YubiKey Authentication title"))
                    .font(AccessibleTypography.title2)
                    .fontWeight(.bold)

                Text(String(format: NSLocalizedString("officer.yubikey.step_of", comment: "Step X of Y"), step, totalSteps))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)

                Text(message)
                    .font(AccessibleTypography.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                ProgressView(value: Double(step), total: Double(totalSteps))
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                    .tint(AccessibleColors.primary)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(AccessibleTypography.subheadline)
                    Text(manager.settings.verboseDescriptions ?
                         NSLocalizedString("officer.yubikey.touch_hint_verbose", comment: "Touch the metal contact or button on your YubiKey when it blinks") :
                         NSLocalizedString("officer.yubikey.touch_hint", comment: "The YubiKey LED should be blinking"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AccessibleColors.primary.opacity(0.15))
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
            )
            .padding(32)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("accessibility.officer.yubikey_authentication.label", comment: "Accessibility label for YubiKey authentication overlay showing step and message"), step, totalSteps, message))
            .accessibilityHint(NSLocalizedString("accessibility.officer.touch_yubikey.hint", comment: "Accessibility hint to touch YubiKey to authenticate"))
        }
        .onAppear {
            announceIfVoiceOver(String(format: NSLocalizedString("officer.yubikey.announce_touch", comment: "Touch YubiKey announcement with message"), message))
        }
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
