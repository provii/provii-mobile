// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Standalone detail view for a single help topic, displaying the topic icon, title, category badge,
/// and reading-level-appropriate help text. Includes breadcrumb navigation and pronunciation-friendly
/// accessibility labels for screen readers.

struct HelpTopicDetailView: View {
    let topic: HelpTopic
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Breadcrumb Navigation
                BreadcrumbView(path: [
                    NSLocalizedString("breadcrumb.home", comment: "Home"),
                    NSLocalizedString("breadcrumb.settings", comment: "Settings"),
                    NSLocalizedString("breadcrumb.accessibility", comment: "Accessibility"),
                    NSLocalizedString("breadcrumb.help", comment: "Help Centre"),
                    topic.title
                ])
                .padding(.horizontal)
                .padding(.top, 8)

                // Header
                HStack(spacing: 16) {
                    Image(systemName: topic.icon)
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(AccessibleTypography.title)
                            .accessibilityAddTraits(.isHeader)

                        Text(topic.category.localizedName)
                            .font(AccessibleTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )

                // Content
                Text(topic.helpText(readingLevel: accessibilityManager.settings.readingLevel))
                    .font(AccessibleTypography.body)
                    .padding(.horizontal)
                    .accessibilityPronunciation(topic.helpText())

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationTitle(LocalizedString.help.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizedString.done.localized) {
                    dismiss()
                }
                .font(AccessibleTypography.body)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityPronunciation(String(format: NSLocalizedString("accessibility.help.help_topic.label", comment: "Help topic: %@"), topic.title))
    }
}

#if DEBUG
struct HelpTopicDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HelpTopicDetailView(topic: HelpTopic.allCases[0])
        }
    }
}
#endif
