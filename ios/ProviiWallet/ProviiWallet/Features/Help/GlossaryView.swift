// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// View for displaying glossary terms grouped by category with full-text search, pronunciation guides
/// for screen readers, and accessible typography. Terms are shown in expandable rows with definitions
/// and pronunciation-friendly accessibility labels.

struct GlossaryView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let glossary = Glossary.shared

    var body: some View {
        List {
            if searchText.isEmpty {
                // Grouped by category when not searching
                ForEach(GlossaryCategory.allCases, id: \.rawValue) { category in
                    let categoryEntries = glossary.entriesByCategory(category)
                    if !categoryEntries.isEmpty {
                        Section(header: Text(category.rawValue)) {
                            ForEach(categoryEntries, id: \.term) { entry in
                                GlossaryEntryRow(entry: entry)
                            }
                        }
                    }
                }
            } else {
                // Flat list when searching
                ForEach(filteredEntries, id: \.term) { entry in
                    GlossaryEntryRow(entry: entry)
                }
            }
        }
        .navigationTitle(NSLocalizedString("glossary_title", comment: "Glossary screen navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: NSLocalizedString("glossary_search_prompt", comment: "Glossary search field placeholder"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("common_done", comment: "Done button")) {
                    dismiss()
                }
            }
        }
    }

    private var filteredEntries: [GlossaryEntry] {
        glossary.search(query: searchText)
    }
}

struct GlossaryEntryRow: View {
    let entry: GlossaryEntry
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Term with pronunciation
            HStack {
                Text(entry.term)
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.text)
                    .accessibilityAddTraits(.isHeader)

                if let pronunciation = entry.pronunciation {
                    Text("(\(pronunciation))")
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            .pronunciationFriendly(accessibilityLabel)

            // Definition
            Text(entry.definition)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .pronunciationFriendly(entry.definition)
        }
        .padding(.vertical, 8)
    }

    private var accessibilityLabel: String {
        if let pronunciation = entry.pronunciation {
            return "\(pronunciation). \(entry.definition)"
        }
        return "\(entry.term). \(entry.definition)"
    }
}

struct GlossaryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GlossaryView()
        }
    }
}
