// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Detail view for a single stored credential, showing header info, editable nickname (for managed
/// credentials), validity status, and a destructive delete action with confirmation dialog. Applies
/// screenshot protection (MASVS-STORAGE-2) and logs screenshot attempts to the audit trail.

struct CredentialDetailView: View {
    let credential: StoredCredential
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    private let auditLogger = AuditLogger.shared
    @State private var showDeleteConfirmation = false
    @State private var isProcessingAction = false

    // Nickname editing state
    @State private var isEditingNickname = false
    @State private var editedNickname = ""
    @State private var isSavingNickname = false
    @State private var showNicknameError = false

    // Refreshable credential state (Issue 16: avoids stale data after nickname save)
    @State private var currentCredential: StoredCredential?

    // Security states
    @State private var isBlurred = false

    // Screenshot observer token (Issue 15: prevent NotificationCenter leak)
    @State private var screenshotObserver: NSObjectProtocol?

    /// The credential to display, preferring the refreshed copy after nickname edits.
    private var activeCredential: StoredCredential {
        currentCredential ?? credential
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with type badge
                headerCard

                // Nickname section (editable for managed credentials)
                if activeCredential.isManaged {
                    nicknameSection
                }

                // Status
                statusCard

                // Delete button
                deleteButton
            }
            .padding(16)
        }
        .background(AccessibleColors.background)
        .navigationTitle(NSLocalizedString("credentials.detail.title", comment: "Credential details title"))
        .navigationBarTitleDisplayMode(.inline)
        // WCAG 3.3.6: Confirmation dialog for destructive action
        .confirmationDialog(
            NSLocalizedString("credentials.detail.delete_credential", comment: "Delete credential"),
            isPresented: $showDeleteConfirmation
        ) {
            deleteConfirmationButtons
        } message: {
            // Issue 25: Managed credentials show a specific warning about the person being managed
            if activeCredential.isManaged {
                Text(NSLocalizedString("credentials.detail.delete_managed_confirmation", comment: "Delete managed credential confirmation"))
            } else {
                Text(NSLocalizedString("credentials.detail.delete_confirmation_simple", comment: "Simple delete confirmation message"))
            }
        }
        // Issue 9: Alert for nickname save failure
        .alert(
            NSLocalizedString("credentials.detail.nickname_save_failed", comment: "Failed to save nickname"),
            isPresented: $showNicknameError
        ) {
            Button(NSLocalizedString("credentials.detail.ok", comment: "OK"), role: .cancel) { }
        }
        .overlay {
            if isProcessingAction {
                AccessibleLoadingView(message: NSLocalizedString("credentials.detail.processing", comment: "Processing message"))
            }
        }
        .blur(radius: isBlurred ? 20 : 0)
        .screenshotProtected() // MASVS-STORAGE-2: Block screenshots of credential data
        .onAppear {
            setupScreenshotProtection()
            editedNickname = activeCredential.nickname ?? ""
        }
        .onDisappear {
            cleanupScreenshotProtection()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: activeCredential.isManaged ? "person.2.fill" : "person.fill")
                        .font(AccessibleTypography.title3)
                        .foregroundColor(.accentColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activeCredential.displayName)
                        .font(AccessibleTypography.title3)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Text(activeCredential.isManaged
                        ? NSLocalizedString("credentials.detail.type.managed", comment: "Managed credential type label")
                        : NSLocalizedString("credentials.detail.type.primary", comment: "Primary credential type label"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AccessibleColors.cardBackground)
        )
        .accessibilityElement(children: .combine)
        // Issue 10: Hide child name from VoiceOver for managed credentials
        .accessibilityLabel(activeCredential.isManaged
            ? NSLocalizedString("accessibility.credential_detail.managed_credential", comment: "Managed credential")
            : activeCredential.displayName)
    }

    // MARK: - Nickname Section

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("credentials.detail.nickname", comment: "Nickname section label"))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            if isEditingNickname {
                VStack(spacing: 12) {
                    TextField(
                        NSLocalizedString("credentials.detail.nickname", comment: "Nickname"),
                        text: $editedNickname
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(AccessibleTypography.body)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .disabled(isSavingNickname)

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("credentials.detail.cancel", comment: "Cancel")) {
                            isEditingNickname = false
                            editedNickname = activeCredential.nickname ?? ""
                        }
                        .disabled(isSavingNickname)

                        Button(NSLocalizedString("credentials.detail.save", comment: "Save")) {
                            saveNickname()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSavingNickname)
                    }
                }
            } else {
                HStack {
                    Text(activeCredential.nickname ?? NSLocalizedString("credentials.detail.no_nickname", comment: "No nickname set"))
                        .font(AccessibleTypography.body)

                    Spacer()

                    Button {
                        isEditingNickname = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(AccessibleTypography.body)
                            .frame(minWidth: 44, minHeight: 44) // WCAG 2.5.8: Minimum touch target
                    }
                    .accessibilityLabel(NSLocalizedString("credentials.detail.edit_nickname", comment: "Edit nickname"))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AccessibleColors.cardBackground)
        )
    }

    // MARK: - Status Card

    // Issue 11: Status icon + text so colour is not the only indicator (WCAG 1.4.1)
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("credentials.detail.status", comment: "Status label"))
                .font(AccessibleTypography.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                Image(systemName: statusIconName)
                    .font(AccessibleTypography.body)
                    .foregroundColor(statusColour)
                    .accessibilityHidden(true)

                Text(statusText)
                    .font(AccessibleTypography.body)
                    .foregroundColor(statusColour)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AccessibleColors.cardBackground)
        )
    }

    private var statusIconName: String {
        if activeCredential.isExpired {
            return "xmark.circle.fill"
        } else if activeCredential.daysUntilExpiry <= 30 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        if activeCredential.isExpired {
            return NSLocalizedString("credentials.detail.status.expired", comment: "Expired status")
        } else if activeCredential.daysUntilExpiry <= 30 {
            return NSLocalizedString("credentials.detail.status.expiring", comment: "Expiring soon status")
        } else {
            return NSLocalizedString("credentials.detail.status.valid", comment: "Valid status")
        }
    }

    private var statusColour: Color {
        if activeCredential.isExpired {
            return AccessibleColors.error
        } else if activeCredential.daysUntilExpiry <= 30 {
            return AccessibleColors.warning
        } else {
            return AccessibleColors.success
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            // WCAG 3.3.6: Error Prevention - destructive actions require confirmation
            HapticFeedback.notification(.warning)
            showDeleteConfirmation = true
        }, label: {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(AccessibleTypography.body)
                Text(NSLocalizedString("credentials.detail.delete_credential_button", comment: "Delete credential button"))
                    .font(AccessibleTypography.headline)
                Spacer()
            }
            .foregroundColor(AccessibleColors.error)
            .padding(16)
            .frame(minHeight: 44) // Minimum touch target
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AccessibleColors.error.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AccessibleColors.error, lineWidth: 2)
                    )
            )
        })
        .accessibilityLabel(NSLocalizedString("accessibility.credentialdetail.delete_credential.label", comment: "Delete credential"))
        .accessibilityHint(NSLocalizedString("accessibility.credentialdetail.double_tap_to_delete.hint", comment: "Double tap to delete this credential"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Delete Confirmation

    private var deleteConfirmationButtons: some View {
        Group {
            Button(NSLocalizedString("credentials.detail.cancel", comment: "Cancel button"), role: .cancel) {
                // Dismissed
            }
            .accessibilityLabel(NSLocalizedString("accessibility.credentialdetail.cancel_deletion.label", comment: "Cancel deletion"))

            Button(NSLocalizedString("credentials.detail.delete", comment: "Delete button"), role: .destructive) {
                deleteCredential()
            }
            .accessibilityLabel(NSLocalizedString("accessibility.credentialdetail.confirm_deletion.label", comment: "Confirm deletion"))
        }
    }

    // MARK: - Actions

    private func saveNickname() {
        isSavingNickname = true
        let newNickname = editedNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let nicknameToSave: String? = newNickname.isEmpty ? nil : newNickname

        Task {
            do {
                try await WalletRepository.shared.updateCredentialNickname(
                    credentialId: credential.id,
                    nickname: nicknameToSave
                )
                await MainActor.run {
                    // Issue 16: Refresh the local credential state after successful save
                    currentCredential = StoredCredential(
                        id: credential.id,
                        issuerKid: credential.issuerKid,
                        issuerLabel: credential.issuerLabel,
                        issuedAt: credential.issuedAt,
                        expiresAt: credential.expiresAt,
                        schema: credential.schema,
                        credentialData: credential.credentialData,
                        credentialType: credential.credentialType,
                        nickname: nicknameToSave
                    )
                    isSavingNickname = false
                    isEditingNickname = false
                    // Issue 12: VoiceOver announcement for successful save
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: NSLocalizedString("credentials.detail.nickname_saved", comment: "Nickname saved") as NSString
                    )
                }
            } catch {
                await MainActor.run {
                    isSavingNickname = false
                    // Issue 9: Show error alert and announce to VoiceOver
                    showNicknameError = true
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: NSLocalizedString("credentials.detail.nickname_save_failed", comment: "Failed to save nickname") as NSString
                    )
                }
            }
        }
    }

    private func deleteCredential() {
        isProcessingAction = true
        HapticFeedback.notification(.warning)

        Task {
            do {
                try await WalletRepository.shared.deleteCredential(credentialId: credential.id)
                await MainActor.run {
                    HapticFeedback.notification(.success)
                    // Issue 12: VoiceOver announcement before navigating away
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: NSLocalizedString("credentials.detail.credential_deleted", comment: "Credential deleted") as NSString
                    )
                    navigationCoordinator.pop()
                }
            } catch {
                await MainActor.run {
                    isProcessingAction = false
                    HapticFeedback.notification(.error)
                    // Issue 12: VoiceOver announcement for delete failure
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: NSLocalizedString("credentials.detail.delete_failed", comment: "Failed to delete credential") as NSString
                    )
                }
            }
        }
    }

    // MARK: - Screenshot Protection

    // Issue 15: Store observer token to avoid NotificationCenter leak
    private func setupScreenshotProtection() {
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleScreenshotDetected()
        }
    }

    private func cleanupScreenshotProtection() {
        if let observer = screenshotObserver {
            NotificationCenter.default.removeObserver(observer)
            screenshotObserver = nil
        }
    }

    private func handleScreenshotDetected() {
        auditLogger.logSecurityEvent(.screenshotAttempt, details: [
            "view": "credential_detail",
            "credential_id": credential.id
        ])
        HapticFeedback.notification(.warning)
    }
}

#Preview {
    NavigationView {
        CredentialDetailView(
            credential: StoredCredential(
                id: "123456789abcdef",
                issuerKid: "issuer-key",
                issuerLabel: "Example Issuer",
                issuedAt: Int64(Date().timeIntervalSince1970 - 86400),
                expiresAt: Int64(Date().timeIntervalSince1970 + 86400 * 30),
                schema: "age_verification_v1",
                credentialData: CredentialData(issuerVk: "", sigRj: "", cBytes: ""),
                credentialType: "primary",
                nickname: "My ID"
            )
        )
        .environmentObject(NavigationCoordinator())
    }
}
