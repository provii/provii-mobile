// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Privacy settings screen for MASVS-PRIVACY-2 compliance, matching the Android
/// PrivacySettingsScreen.kt feature set. Provides opt-in toggles for analytics and
/// crash reporting, a data deletion action with confirmation, and a link to the full
/// privacy policy. All consent changes take effect immediately and are announced
/// to VoiceOver users.
struct PrivacySettingsView: View {

    @ObservedObject private var privacyPreferences = PrivacyPreferences.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteDataAlert = false
    @State private var showDataCollectionSheet = false

    var body: some View {
        List {
            privacyProtectionSection
            dataCollectionSection
            yourDataSection
            footerSection
        }
        .navigationTitle(NSLocalizedString("privacy.settings.title", comment: "Privacy Settings"))
        .navigationBarTitleDisplayMode(.large)
        .alert(
            NSLocalizedString("privacy.delete.alert.title", comment: "Delete My Data"),
            isPresented: $showDeleteDataAlert
        ) {
            Button(NSLocalizedString("privacy.delete.alert.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("privacy.delete.alert.confirm", comment: "Delete Everything"), role: .destructive) {
                Task {
                    do {
                        try await WalletRepository.shared.clearAllData()
                    } catch {
                        SecureLogger.shared.error("clearAllData failed during Delete My Data: \(error.localizedDescription)")
                    }
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: NSLocalizedString(
                            "privacy.delete.alert.done_announcement",
                            comment: "All data has been deleted"
                        )
                    )
                }
            }
        } message: {
            Text(NSLocalizedString(
                "privacy.delete.alert.message",
                comment: "This will remove all stored consent choices and request deletion of any collected data. This action cannot be undone."
            ))
        }
        .sheet(isPresented: $showDataCollectionSheet) {
            dataCollectionDetailSheet
                .onAppear {
                    UIAccessibility.post(notification: .screenChanged, argument: nil)
                }
        }
    }

    // MARK: - Privacy Protection Info

    private var privacyProtectionSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundColor(AccessibleColors.primary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString(
                        "privacy.protection.title",
                        comment: "Privacy Protection"
                    ))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                    Text(NSLocalizedString(
                        "privacy.protection.description",
                        comment: "Provii Wallet is built with privacy at its core. Your personal information stays on your device. We only collect data you explicitly opt into, and nothing is shared with third parties."
                    ))
                    .font(.subheadline)
                    .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(NSLocalizedString(
                "privacy.protection.accessibility_label",
                comment: "Privacy Protection. Provii Wallet is built with privacy at its core. Your personal information stays on your device."
            ))
        }
    }

    // MARK: - Data Collection

    private var dataCollectionSection: some View {
        Section {
            // "What data we collect" info row
            Button {
                showDataCollectionSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AccessibleColors.primary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString(
                            "privacy.what_we_collect.title",
                            comment: "What data we collect"
                        ))
                        .font(.body)
                        .foregroundColor(.primary)

                        Text(NSLocalizedString(
                            "privacy.what_we_collect.subtitle",
                            comment: "Tap to see full details"
                        ))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(NSLocalizedString(
                "privacy.what_we_collect.accessibility_label",
                comment: "What data we collect. Tap to see full details."
            ))
            .accessibilityAddTraits(.isButton)

            // Analytics toggle
            Toggle(isOn: $privacyPreferences.analyticsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString(
                            "privacy.analytics.title",
                            comment: "Usage Analytics"
                        ))

                        Text(NSLocalizedString(
                            "privacy.analytics.description",
                            comment: "Help us understand how the app is used so we can improve it"
                        ))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .onChange(of: privacyPreferences.analyticsEnabled) { _, newValue in
                privacyPreferences.setAnalyticsConsent(enabled: newValue)
                let message = newValue
                    ? NSLocalizedString("privacy.analytics.enabled", comment: "Analytics enabled")
                    : NSLocalizedString("privacy.analytics.disabled", comment: "Analytics disabled")
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            .accessibilityLabel(NSLocalizedString(
                "privacy.analytics.accessibility_label",
                comment: "Usage analytics toggle"
            ))
            .accessibilityHint(NSLocalizedString(
                "privacy.analytics.accessibility_hint",
                comment: "Double tap to toggle usage analytics collection"
            ))

            // Crash reporting toggle
            Toggle(isOn: $privacyPreferences.crashReportingEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString(
                            "privacy.crash_reporting.title",
                            comment: "Crash Reporting"
                        ))

                        Text(NSLocalizedString(
                            "privacy.crash_reporting.description",
                            comment: "Send anonymous crash logs to help us fix problems faster"
                        ))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    }
                } icon: {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .onChange(of: privacyPreferences.crashReportingEnabled) { _, newValue in
                privacyPreferences.setCrashReportingConsent(enabled: newValue)
                let message = newValue
                    ? NSLocalizedString("privacy.crash_reporting.enabled", comment: "Crash reporting enabled")
                    : NSLocalizedString("privacy.crash_reporting.disabled", comment: "Crash reporting disabled")
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            .accessibilityLabel(NSLocalizedString(
                "privacy.crash_reporting.accessibility_label",
                comment: "Crash reporting toggle"
            ))
            .accessibilityHint(NSLocalizedString(
                "privacy.crash_reporting.accessibility_hint",
                comment: "Double tap to toggle crash reporting"
            ))
        } header: {
            Text(NSLocalizedString("privacy.section.data_collection", comment: "Data Collection"))
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Your Data

    private var yourDataSection: some View {
        Section {
            // Privacy Policy link
            Link(destination: URL(string: "https://provii.app/privacy") ?? URL(fileURLWithPath: "/")) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(AccessibleColors.primary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString(
                            "privacy.policy.title",
                            comment: "Privacy Policy"
                        ))
                        .font(.body)
                        .foregroundColor(.primary)

                        Text(NSLocalizedString(
                            "privacy.policy.subtitle",
                            comment: "Read our full privacy policy"
                        ))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(NSLocalizedString(
                "privacy.policy.accessibility_label",
                comment: "Privacy Policy. Opens in Safari."
            ))
            .accessibilityAddTraits(.isLink)

            // Delete My Data
            Button(role: .destructive) {
                showDeleteDataAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(AccessibleColors.error)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString(
                            "privacy.delete.title",
                            comment: "Delete My Data"
                        ))
                        .font(.body)
                        .foregroundColor(AccessibleColors.error)

                        Text(NSLocalizedString(
                            "privacy.delete.subtitle",
                            comment: "Remove all collected data and consent choices"
                        ))
                        .font(.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                    }

                    Spacer()
                }
            }
            .accessibilityLabel(NSLocalizedString(
                "privacy.delete.accessibility_label",
                comment: "Delete my data"
            ))
            .accessibilityHint(NSLocalizedString(
                "privacy.delete.accessibility_hint",
                comment: "Double tap to show deletion confirmation"
            ))
        } header: {
            Text(NSLocalizedString("privacy.section.your_data", comment: "Your Data"))
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Section {
            Text(NSLocalizedString(
                "privacy.footer.note",
                comment: "Changes take effect immediately. No data is collected without your explicit consent."
            ))
            .font(.footnote)
            .foregroundColor(AccessibleColors.secondaryText)
            .accessibilityLabel(NSLocalizedString(
                "privacy.footer.note",
                comment: "Changes take effect immediately. No data is collected without your explicit consent."
            ))
        }
    }

    // MARK: - Data Collection Detail Sheet

    private var dataCollectionDetailSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text(NSLocalizedString(
                        "privacy.detail.what_we_collect_header",
                        comment: "What we collect (opt-in only)"
                    ))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                    Label(
                        NSLocalizedString("privacy.detail.collect_crash_logs", comment: "App crash logs (opt-in)"),
                        systemImage: "ladybug"
                    )
                    Label(
                        NSLocalizedString("privacy.detail.collect_analytics", comment: "Usage analytics (opt-in)"),
                        systemImage: "chart.bar"
                    )
                    Label(
                        NSLocalizedString("privacy.detail.collect_device", comment: "Device model for compatibility"),
                        systemImage: "iphone"
                    )
                    Label(
                        NSLocalizedString("privacy.detail.collect_os", comment: "OS version for compatibility"),
                        systemImage: "gearshape.2"
                    )
                }

                Section {
                    Text(NSLocalizedString(
                        "privacy.detail.what_we_never_collect_header",
                        comment: "What we never collect"
                    ))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                    Label(
                        NSLocalizedString("privacy.detail.never_dob", comment: "Your date of birth"),
                        systemImage: "xmark.circle"
                    )
                    .foregroundColor(AccessibleColors.error)
                    .accessibilityLabel(NSLocalizedString(
                        "privacy.detail.never_dob_a11y",
                        comment: "Never collected: Your date of birth"
                    ))
                    Label(
                        NSLocalizedString("privacy.detail.never_identity", comment: "Your identity"),
                        systemImage: "xmark.circle"
                    )
                    .foregroundColor(AccessibleColors.error)
                    .accessibilityLabel(NSLocalizedString(
                        "privacy.detail.never_identity_a11y",
                        comment: "Never collected: Your identity"
                    ))
                    Label(
                        NSLocalizedString("privacy.detail.never_verification", comment: "Verification history"),
                        systemImage: "xmark.circle"
                    )
                    .foregroundColor(AccessibleColors.error)
                    .accessibilityLabel(NSLocalizedString(
                        "privacy.detail.never_verification_a11y",
                        comment: "Never collected: Verification history"
                    ))
                    Label(
                        NSLocalizedString("privacy.detail.never_location", comment: "Location data"),
                        systemImage: "xmark.circle"
                    )
                    .foregroundColor(AccessibleColors.error)
                    .accessibilityLabel(NSLocalizedString(
                        "privacy.detail.never_location_a11y",
                        comment: "Never collected: Location data"
                    ))
                    Label(
                        NSLocalizedString("privacy.detail.never_contacts", comment: "Contacts or other personal data"),
                        systemImage: "xmark.circle"
                    )
                    .foregroundColor(AccessibleColors.error)
                    .accessibilityLabel(NSLocalizedString(
                        "privacy.detail.never_contacts_a11y",
                        comment: "Never collected: Contacts or other personal data"
                    ))
                }

                Section {
                    Text(NSLocalizedString(
                        "privacy.detail.never_shared",
                        comment: "Your data is never shared with third parties."
                    ))
                    .font(.subheadline)
                    .foregroundColor(AccessibleColors.primary)
                }
            }
            .navigationTitle(NSLocalizedString(
                "privacy.detail.title",
                comment: "Data Collection Info"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("privacy.detail.done", comment: "Done")) {
                        showDataCollectionSheet = false
                    }
                    .accessibilityLabel(NSLocalizedString(
                        "privacy.detail.done_accessibility",
                        comment: "Close data collection information"
                    ))
                }
            }
        }
    }
}
