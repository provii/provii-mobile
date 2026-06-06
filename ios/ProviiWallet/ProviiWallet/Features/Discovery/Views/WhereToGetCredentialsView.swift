// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Speech
import AVFoundation
import MapKit

/// Discovery screen listing authorised credential issuers with category filtering, search, map view,
/// and expandable detail cards showing instructions, locations, and action buttons. Supports voice
/// control, breadcrumb navigation, and adapts the entire layout to accessibility settings.

struct WhereToGetCredentialsView: View {
    @StateObject private var issuersRepository = IssuersRepository.shared
    @StateObject private var accessibilityManager = AccessibilityManager.shared

    @State private var registry: IssuerRegistry?
    @State private var isLoading = true
    @State private var selectedCategory = "all"
    @State private var expandedIssuerId: String?

    // Accessibility states
    @State private var voiceControlActive = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var searchText = ""
    @State private var showSearchBar = false
    @State private var selectedIssuerIndex: Int = 0
    @State private var showMapView = false
    @State private var announcementTimer: Timer?

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case voiceControlButton
        case mapButton
        case refreshButton
    }

    var body: some View {
        Group {
            if isLoading {
                accessibleLoadingView
            } else if registry == nil || registry?.issuers.isEmpty == true {
                accessibleErrorView
            } else {
                accessibleContentView
            }
        }
        .navigationTitle(NSLocalizedString("wheretogetcredentials.toolbar.title", comment: "Get Credentials"))
        .navigationBarTitleDisplayMode(
            accessibilityManager.settings.useExtraLargeText ? .large : .inline
        )
        .breadcrumb(breadcrumbPath)
        .toolbar {
            toolbarContent
        }
        .task {
            await loadIssuers()
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: NSLocalizedString("wheretogetcredentials.search.prompt", comment: "Search issuers")
        )
        .onAppear {
            setupAccessibility()
        }
        .onDisappear {
            cleanupAccessibility()
        }
        .sheet(isPresented: $showMapView) {
            AccessibleMapView(issuers: filteredIssuers)
                .sheetKeyboardNavigation(isPresented: $showMapView)
        }
        .onChange(of: showMapView) { _, isShowing in
            if isShowing {
                savedFocus = focusedElement
            } else if let saved = savedFocus {
                focusedElement = saved
                savedFocus = nil
            }
        }
    }

    // MARK: - Accessible Loading View

    private var accessibleLoadingView: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 24 : 18) {
            if accessibilityManager.settings.reduceMotion {
                Image(systemName: "hourglass")
                    .font(AccessibleTypography.title2)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .scaleEffect(accessibilityManager.settings.useExtraLargeText ? 2.0 : 1.5)
            }

            Text(NSLocalizedString("wheretogetcredentials.loading.title", comment: "Loading issuers..."))
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)

            if accessibilityManager.settings.verboseDescriptions {
                Text(NSLocalizedString("wheretogetcredentials.loading.description", comment: "Please wait while we fetch the list of authorised credential issuers"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.loading_credential_issuers_ple.label", comment: ""))
        .onAppear {
            announceIfVoiceOver(NSLocalizedString("wheretogetcredentials.loading.voiceover", comment: "Loading list of credential issuers"))
        }
    }

    // MARK: - Accessible Error View

    private var accessibleErrorView: some View {
        VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 20 : 16) {
            Image(systemName: "icloud.slash")
                .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.largeTitle : AccessibleTypography.title)
                .foregroundColor(AccessibleColors.error.opacity(0.6))
                .accessibilityHidden(true)

            Text(NSLocalizedString("wheretogetcredentials.error.title", comment: "Unable to load issuers"))
                .font(AccessibleTypography.headline)
                .fontWeight(.medium)
                .foregroundColor(textColor)

            Text(errorMessage)
                .font(AccessibleTypography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(AccessibleColors.secondaryText)
                .padding(.horizontal, 32)

            if accessibilityManager.settings.verboseDescriptions {
                Text(NSLocalizedString("wheretogetcredentials.error.verbose_description", comment: "This might be due to network issues or server unavailability. Please check your internet connection and try refreshing."))
                    .font(AccessibleTypography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        HapticFeedback.selection()
                        await refreshIssuers()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(AccessibleTypography.callout)
                        Text(NSLocalizedString("wheretogetcredentials.error.try_again", comment: "Try Again"))
                            .font(AccessibleTypography.body)
                    }
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())

                if accessibilityManager.settings.enableManualCodeEntry {
                    Button {
                        // Navigate to manual entry
                        HapticFeedback.selection()
                    } label: {
                        Text(NSLocalizedString("wheretogetcredentials.error.enter_manually", comment: "Enter Issuer Manually"))
                            .font(AccessibleTypography.body)
                    }
                    .buttonStyle(AccessibleSecondaryButtonStyle())
                }
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .onAppear {
            announceIfVoiceOver(NSLocalizedString("wheretogetcredentials.error.voiceover", comment: "Unable to load issuers. Network error."))
        }
    }

    // MARK: - Accessible Content View

    private var accessibleContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Accessibility Summary Card
                    if accessibilityManager.settings.verboseDescriptions {
                        accessibilitySummaryCard
                    }

                    // Header Card
                    if let registry = registry {
                        accessibleHeaderCard(registry: registry)
                    }

                    // Search Bar (for simplified UI)
                    if accessibilityManager.settings.simplifiedUI && !searchText.isEmpty {
                        searchResultsSummary
                    }

                    // Categories Section
                    if let categories = registry?.categories {
                        accessibleCategoriesSection(categories: categories)
                    }

                    // Map View Button
                    if accessibilityManager.settings.increaseTouchTargets {
                        mapViewButton
                    }

                    // Issuers Section
                    accessibleIssuersSection(proxy: proxy)

                    Spacer()
                        .frame(height: 16)
                }
            }
            .background(AccessibleColors.background)
        }
        .onChange(of: selectedIssuerIndex) { index in
            if let issuer = filteredIssuers[safe: index] {
                expandedIssuerId = issuer.id
            }
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(NSLocalizedString("wheretogetcredentials.toolbar.title", comment: "Get Credentials"))
                    .font(AccessibleTypography.headline)
                    .fontWeight(.semibold)

                if !accessibilityManager.settings.simplifiedUI {
                    Text(NSLocalizedString("wheretogetcredentials.toolbar.subtitle", comment: "Trusted issuers in Australia"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.get_credentials_from_trusted.label", comment: ""))
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 16 : 12) {
                // Voice control
                if accessibilityManager.settings.enableVoiceInput {
                    Button(action: toggleVoiceControl) {
                        Image(systemName: voiceControlActive ? "mic.fill" : "mic")
                            .foregroundColor(voiceControlActive ? .red : .primary)
                            .font(toolbarIconSize)
                    }
                    .focused($focusedElement, equals: .voiceControlButton)
                    .accessibilityLabel(voiceControlActive ? AccessibilityLabels.voiceInputStop : AccessibilityLabels.voiceInputStart)
                }

                // Map view toggle
                if !filteredIssuers.isEmpty {
                    Button {
                        showMapView = true
                        HapticFeedback.selection()
                    } label: {
                        Image(systemName: "map")
                            .font(toolbarIconSize)
                    }
                    .focused($focusedElement, equals: .mapButton)
                    .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.show_map_view.label", comment: ""))
                    .accessibilityHint(NSLocalizedString("accessibility.wheretogetcredentials.view_issuer_locations_on.hint", comment: ""))
                }

                // Refresh button
                Button {
                    Task {
                        HapticFeedback.selection()
                        await refreshIssuers()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(toolbarIconSize)
                }
                .focused($focusedElement, equals: .refreshButton)
                .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.refresh_issuers.label", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.wheretogetcredentials.reload_the_list_of.hint", comment: ""))
            }
        }
    }

    // MARK: - Content Components

    private var accessibilitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AccessibleColors.primary)
                Text(NSLocalizedString("wheretogetcredentials.summary.title", comment: "About Credential Issuers"))
                    .font(AccessibleTypography.headline)
            }

            Text(NSLocalizedString("wheretogetcredentials.summary.description", comment: "These organisations can verify your identity and issue digital age credentials. Visit them in person with your government ID to get started."))
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.primary.opacity(0.1))
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    private func accessibleHeaderCard(registry: IssuerRegistry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(iconSize)
                .foregroundColor(AccessibleColors.primary)
                .accessibilityHidden(true)

            Text(registry.description)
                .font(AccessibleTypography.body)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(headerCardBackground)
                .overlay(
                    accessibilityManager.settings.useHighContrast ?
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 2) : nil
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.information_registry_desc.label", comment: "Information about credential registry"), registry.description))
    }

    private var searchResultsSummary: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AccessibleColors.secondaryText)
            Text(String(format: NSLocalizedString("wheretogetcredentials.search.results_count", comment: "%d results for '%@'"), filteredIssuers.count, searchText))
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
            Spacer()
            Button(NSLocalizedString("wheretogetcredentials.search.clear", comment: "Clear")) {
                searchText = ""
            }
            .font(AccessibleTypography.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.search_results_count.label", comment: "Number of search results for query"), filteredIssuers.count, searchText))
    }

    private func accessibleCategoriesSection(categories: [IssuerCategory]) -> some View {
        Section {
            if accessibilityManager.settings.simplifiedUI {
                // Vertical list for simplified UI
                VStack(spacing: 8) {
                    ForEach(categories) { category in
                        AccessibleCategoryButton(
                            category: category,
                            isSelected: selectedCategory == category.id,
                            onTap: {
                                selectCategory(category.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                // Horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories) { category in
                            AccessibleCategoryChip(
                                category: category,
                                isSelected: selectedCategory == category.id,
                                onTap: {
                                    selectCategory(category.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        } header: {
            accessibleSectionHeader(
                title: NSLocalizedString("wheretogetcredentials.section.categories", comment: "CATEGORIES"),
                count: categories.count
            )
        }
    }

    private var mapViewButton: some View {
        Button {
            showMapView = true
            HapticFeedback.selection()
        } label: {
            HStack {
                Image(systemName: "map")
                    .font(AccessibleTypography.body)
                Text(NSLocalizedString("wheretogetcredentials.map.view_on_map", comment: "View on Map"))
                    .font(AccessibleTypography.body)
                Spacer()
                Text(String(format: NSLocalizedString("wheretogetcredentials.map.locations_count", comment: "%d locations"), locationsCount))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AccessibleColors.primary.opacity(0.1))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.view_locations_on_map.label", comment: "View issuer locations on map"), locationsCount))
    }

    private func accessibleIssuersSection(proxy: ScrollViewProxy) -> some View {
        Section {
            ForEach(Array(filteredIssuers.enumerated()), id: \.element.id) { index, issuer in
                AccessibleIssuerCardView(
                    issuer: issuer,
                    isExpanded: expandedIssuerId == issuer.id,
                    index: index + 1,
                    total: filteredIssuers.count,
                    onExpandToggle: {
                        toggleIssuer(issuer.id)
                    },
                    onWebsiteClick: {
                        openWebsite(issuer.website)
                    },
                    onLocationClick: { location in
                        openMaps(location: location)
                    }
                )
                .id(issuer.id)
            }

            if filteredIssuers.isEmpty {
                emptyStateView
            }

            Spacer()
                .frame(height: 16)
        } header: {
            accessibleSectionHeader(
                title: NSLocalizedString("wheretogetcredentials.section.available_issuers", comment: "AVAILABLE ISSUERS"),
                count: filteredIssuers.count
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(AccessibleTypography.title3)
                .foregroundColor(AccessibleColors.secondaryText)

            Text(NSLocalizedString("wheretogetcredentials.empty.title", comment: "No issuers found"))
                .font(AccessibleTypography.headline)

            Text(searchText.isEmpty ? NSLocalizedString("wheretogetcredentials.empty.hint_category", comment: "Try changing the category filter") : NSLocalizedString("wheretogetcredentials.empty.hint_search", comment: "Try a different search term"))
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "accessibility.wheretogetcredentials.no_issuers_found.label",
                comment: "No issuers found message"),
            searchText.isEmpty
                ? NSLocalizedString(
                    "accessibility.wheretogetcredentials.try_changing_category.hint",
                    comment: "Try changing the category filter hint")
                : NSLocalizedString(
                    "accessibility.wheretogetcredentials.try_different_search.hint",
                    comment: "Try a different search term hint")))
    }

    private func accessibleSectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AccessibleTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(AccessibleColors.secondaryText)

            Spacer()

            if count > 0 {
                Text(String(format: NSLocalizedString("wheretogetcredentials.section.count_found", comment: "%d found"), count))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AccessibleColors.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.section_header_count.label", comment: "Section header with count"), title, count))
    }

    // MARK: - Computed Properties

    private var filteredIssuers: [Issuer] {
        guard let issuers = registry?.issuers else { return [] }

        var filtered = issuers

        // Category filter
        if selectedCategory != "all" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    private var locationsCount: Int {
        filteredIssuers.compactMap { $0.locations }.flatMap { $0 }.count
    }

    private var errorMessage: String {
        if accessibilityManager.settings.verboseDescriptions {
            return NSLocalizedString("wheretogetcredentials.error.message_verbose", comment: "Unable to connect to the server. Please check your internet connection and try again. If the problem persists, the service may be temporarily unavailable.")
        }
        return NSLocalizedString("wheretogetcredentials.error.message", comment: "Check your internet connection and try again")
    }

    private var textColor: Color {
        accessibilityManager.settings.useHighContrast ? .black : .primary
    }

    private var iconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title3 : AccessibleTypography.headline
    }

    private var toolbarIconSize: Font {
        accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.subheadline
    }

    private var cardPadding: CGFloat {
        accessibilityManager.settings.increaseTouchTargets ? 24 : 20
    }

    private var headerCardBackground: Color {
        if accessibilityManager.settings.useHighContrast {
            return Color.yellow.opacity(0.2)
        }
        return Color.accentColor.opacity(0.12)
    }

    // MARK: - Methods

    private func loadIssuers() async {
        isLoading = true
        registry = await issuersRepository.loadIssuers()
        isLoading = false

        if let count = registry?.issuers.count {
            announceIfVoiceOver(String(format: NSLocalizedString("wheretogetcredentials.loading.loaded_count", comment: "Loaded %d credential issuers"), count))
        }
    }

    private func refreshIssuers() async {
        announceIfVoiceOver(NSLocalizedString("wheretogetcredentials.refresh.refreshing", comment: "Refreshing issuers list"))
        isLoading = true
        await issuersRepository.refreshIssuers()
        registry = await issuersRepository.loadIssuers()
        isLoading = false

        if let count = registry?.issuers.count {
            announceIfVoiceOver(String(format: NSLocalizedString("wheretogetcredentials.refresh.refreshed_count", comment: "Refreshed. %d issuers available"), count))
        }
    }

    private func selectCategory(_ categoryId: String) {
        withAnimation(accessibilityManager.settings.reduceMotion ? .none : .default) {
            selectedCategory = categoryId
            expandedIssuerId = nil
        }

        HapticFeedback.selection()

        let categoryName = registry?.categories.first { $0.id == categoryId }?.name ?? NSLocalizedString("wheretogetcredentials.category.all", comment: "All")
        announceIfVoiceOver(String(format: NSLocalizedString("wheretogetcredentials.category.selected_count", comment: "Category %@ selected. %d issuers found"), categoryName, filteredIssuers.count))
    }

    private func toggleIssuer(_ issuerId: String) {
        withAnimation(accessibilityManager.settings.reduceMotion ? .none : .easeInOut(duration: 0.3)) {
            expandedIssuerId = expandedIssuerId == issuerId ? nil : issuerId
        }

        HapticFeedback.selection()

        if let issuer = filteredIssuers.first(where: { $0.id == issuerId }) {
            let action = expandedIssuerId == issuerId ? NSLocalizedString("wheretogetcredentials.issuer.expanded", comment: "expanded") : NSLocalizedString("wheretogetcredentials.issuer.collapsed", comment: "collapsed")
            announceIfVoiceOver("\(issuer.name) \(action)")
        }
    }

    private func openWebsite(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        guard url.scheme?.lowercased() == "https" else { return }
        UIApplication.shared.open(url)
        HapticFeedback.notification(.success)
        announceIfVoiceOver(NSLocalizedString("wheretogetcredentials.website.opening", comment: "Opening website"))
    }

    private func openMaps(location: Location) {
        // Open in Maps app
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location.address) { placemarks, _ in
            if let placemark = placemarks?.first,
               let coordinate = placemark.location?.coordinate {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = location.name
                mapItem.openInMaps()
            }
        }
        HapticFeedback.notification(.success)
        announceIfVoiceOver(String(format: NSLocalizedString("wheretogetcredentials.maps.opening_location", comment: "Opening %@ in Maps"), location.name))
    }

    // MARK: - Voice Control

    private func toggleVoiceControl() {
        if voiceControlActive {
            speechRecognizer.stopListening()
            voiceControlActive = false
            announceIfVoiceOver(NSLocalizedString("wheretogetcredentials.voice.stopped", comment: "Voice control stopped"))
        } else {
            speechRecognizer.startListening()
            voiceControlActive = true
            announceIfVoiceOver(NSLocalizedString("wheretogetcredentials.voice.started", comment: "Voice control started. Say category names or issuer names"))
        }
        HapticFeedback.selection()
    }

    private func setupVoiceCommands() {
        speechRecognizer.onRecognizedCommand = { command in
            handleVoiceCommand(command)
        }
    }

    private func handleVoiceCommand(_ command: String) {
        let lowercased = command.lowercased()

        // Category commands
        if let category = registry?.categories.first(where: {
            $0.name.lowercased().contains(lowercased)
        }) {
            selectCategory(category.id)
            return
        }

        // Issuer commands
        if let issuer = filteredIssuers.first(where: {
            $0.name.lowercased().contains(lowercased)
        }) {
            expandedIssuerId = issuer.id
            return
        }

        // Action commands
        if lowercased.contains("map") {
            showMapView = true
        } else if lowercased.contains("refresh") {
            Task { await refreshIssuers() }
        } else if lowercased.contains("all") {
            selectCategory("all")
        }
    }

    // MARK: - Accessibility Setup

    private func setupAccessibility() {
        if accessibilityManager.settings.enableVoiceInput {
            setupVoiceCommands()
        }
    }

    private func cleanupAccessibility() {
        if voiceControlActive {
            speechRecognizer.stopListening()
        }
        announcementTimer?.invalidate()
    }

    private func announceIfVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private var breadcrumbPath: [String] {
        [
            NSLocalizedString("breadcrumb.home", comment: "Home"),
            NSLocalizedString("breadcrumb.credentials", comment: "Credentials"),
            NSLocalizedString("breadcrumb.get_credentials", comment: "Get Credentials")
        ]
    }
}

// MARK: - Accessible Category Components

struct AccessibleCategoryChip: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let category: IssuerCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(AccessibleTypography.footnote)
                        .accessibilityHidden(true)
                }
                Text(category.name)
                    .font(AccessibleTypography.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.category_name.label", comment: "Category name"), category.name))
        .accessibilityHint(
            isSelected
                ? NSLocalizedString("accessibility.wheretogetcredentials.currently_selected.hint", comment: "Currently selected category hint")
                : NSLocalizedString("accessibility.wheretogetcredentials.double_tap_to_filter.hint", comment: "Double tap to filter by this category hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var horizontalPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 20 : 16
    }

    private var verticalPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 12 : 10
    }

    private var background: some View {
        Capsule()
            .fill(backgroundColor)
            .overlay(
                manager.settings.useHighContrast ?
                Capsule().stroke(Color.black, lineWidth: isSelected ? 2 : 1) : nil
            )
    }

    private var backgroundColor: Color {
        if manager.settings.useHighContrast {
            return isSelected ? Color.yellow : Color.white
        }
        return isSelected ? Color.accentColor.opacity(0.2) : Color(uiColor: .secondarySystemFill)
    }

    private var foregroundColor: Color {
        if manager.settings.useHighContrast {
            return .black
        }
        return isSelected ? .accentColor : .primary
    }
}

struct AccessibleCategoryButton: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let category: IssuerCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(category.name)
                    .font(AccessibleTypography.body)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AccessibleColors.primary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AccessibleColors.primary.opacity(0.1) : Color.clear)
            )
        }
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.category_name.label", comment: "Category name"), category.name))
        .accessibilityHint(isSelected ? NSLocalizedString("accessibility.wheretogetcredentials.currently_selected.hint", comment: "Currently selected category hint") : NSLocalizedString("accessibility.wheretogetcredentials.double_tap_to_select.hint", comment: "Double tap to select category hint"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Accessible Issuer Card

struct AccessibleIssuerCardView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let issuer: Issuer
    let isExpanded: Bool
    let index: Int
    let total: Int
    let onExpandToggle: () -> Void
    let onWebsiteClick: () -> Void
    let onLocationClick: (Location) -> Void

    @State private var showAllLocations = false

    var body: some View {
        VStack(spacing: 0) {
            // Main card button
            Button(action: onExpandToggle) {
                mainCardContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(cardAccessibilityLabel)
            .accessibilityHint(
                isExpanded
                    ? NSLocalizedString("accessibility.wheretogetcredentials.double_tap_to_collapse.hint", comment: "Double tap to collapse hint")
                    : NSLocalizedString("accessibility.wheretogetcredentials.double_tap_to_expand.hint", comment: "Double tap to expand for more details hint"))
            .accessibilityAddTraits(.isButton)

            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(
                        manager.settings.reduceMotion ?
                        .opacity :
                        .opacity.combined(with: .move(edge: .top))
                    )
            }
        }
        .background(cardBackground)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var mainCardContent: some View {
        HStack(alignment: .top, spacing: cardSpacing) {
            // Logo/Brand Box
            issuerLogo

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(issuer.name)
                        .font(AccessibleTypography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    Spacer()

                    // Status Indicators
                    statusIndicators
                }

                Text(issuer.description)
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .lineLimit(isExpanded ? nil : (manager.settings.verboseDescriptions ? 3 : 1))

                categoryBadge
            }

            // Expand Icon
            expandIcon
        }
        .padding(cardPadding)
    }

    private var issuerLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(brandColor)
                .frame(width: logoSize, height: logoSize)
                .overlay(
                    manager.settings.useHighContrast ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2) : nil
                )

            Text(String(issuer.name.prefix(2)).uppercased())
                .font(logoTextFont)
                .foregroundColor(logoTextColor)
        }
        .accessibilityHidden(true)
    }

    private var statusIndicators: some View {
        Group {
            if issuer.status == "coming_soon" {
                Text(NSLocalizedString("wheretogetcredentials.issuer.coming_soon", comment: "Coming Soon"))
                    .font(AccessibleTypography.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AccessibleColors.warning.opacity(0.2))
                            .overlay(
                                manager.settings.useHighContrast ?
                                Capsule().stroke(Color.black, lineWidth: 1) : nil
                            )
                    )
                    .foregroundColor(manager.settings.useHighContrast ? .black : AccessibleColors.warning)
            } else if issuer.verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.success)
                    .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.verified_issuer.label", comment: ""))
            }
        }
    }

    private var categoryBadge: some View {
        HStack {
            Text(getCategoryDisplayName(issuer.category))
                .font(AccessibleTypography.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.15))
                        .overlay(
                            manager.settings.useHighContrast ?
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black, lineWidth: 1) : nil
                        )
                )
                .foregroundColor(manager.settings.useHighContrast ? .black : .blue)

            if manager.settings.verboseDescriptions {
                Text(String(format: NSLocalizedString("wheretogetcredentials.issuer.index_of_total", comment: "• %d of %d"), index, total))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private var expandIcon: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(AccessibleTypography.subheadline)
            .foregroundColor(.secondary)
            .padding(.top, 4)
            .accessibilityHidden(true)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 16) {
                // Instructions
                instructionsSection

                // Locations
                if let locations = issuer.locations, !locations.isEmpty {
                    locationsSection(locations: locations)
                }

                // Requirements (if verbose mode)
                if manager.settings.verboseDescriptions {
                    requirementsSection
                }

                // Action Buttons
                actionButtons
            }
            .padding(.horizontal, cardPadding)
            .padding(.bottom, cardPadding)
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard")
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.primary)
                Text(NSLocalizedString("wheretogetcredentials.issuer.how_to_get", comment: "How to get credential"))
                    .font(AccessibleTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
            }

            Text(issuer.instructions)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.secondaryText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(instructionsBackground)
                        .overlay(
                            manager.settings.useHighContrast ?
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1) : nil
                        )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.instructions_label.label", comment: "Instructions with content"), issuer.instructions))
    }

    private func locationsSection(locations: [Location]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "location")
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.primary)
                Text(String(format: NSLocalizedString("wheretogetcredentials.issuer.service_locations", comment: "Service Locations (%d)"), locations.count))
                    .font(AccessibleTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                if locations.count > 2 && !showAllLocations {
                    Button(NSLocalizedString("wheretogetcredentials.issuer.show_all", comment: "Show All")) {
                        withAnimation {
                            showAllLocations = true
                        }
                    }
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.primary)
                }
            }

            let displayLocations = showAllLocations ? locations : Array(locations.prefix(2))

            ForEach(displayLocations, id: \.name) { location in
                AccessibleLocationCard(
                    location: location,
                    onTap: { onLocationClick(location) }
                )
            }

            if locations.count > 2 && !showAllLocations {
                Text(String(format: NSLocalizedString("wheretogetcredentials.issuer.more_locations", comment: "+ %d more locations"), locations.count - 2))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .padding(.leading, 4)
            }
        }
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.primary)
                Text(NSLocalizedString("wheretogetcredentials.issuer.requirements", comment: "Requirements"))
                    .font(AccessibleTypography.subheadline)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label(NSLocalizedString("wheretogetcredentials.issuer.requirement_id", comment: "Government-issued photo ID"), systemImage: "checkmark.circle")
                    .font(AccessibleTypography.caption)
                Label(NSLocalizedString("wheretogetcredentials.issuer.requirement_proof", comment: "Proof of age (passport, driver's licence)"), systemImage: "checkmark.circle")
                    .font(AccessibleTypography.caption)
                Label(NSLocalizedString("wheretogetcredentials.issuer.requirement_visit", comment: "Visit in person"), systemImage: "checkmark.circle")
                    .font(AccessibleTypography.caption)
            }
            .foregroundColor(.secondary)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.requirements_government_id_pro.label", comment: ""))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if issuer.status == "coming_soon" {
                Button(action: onWebsiteClick) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(AccessibleTypography.callout)
                        Text(NSLocalizedString("wheretogetcredentials.issuer.learn_more", comment: "Learn More"))
                            .font(AccessibleTypography.body)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessibleSecondaryButtonStyle())
            } else {
                Button(action: onWebsiteClick) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(AccessibleTypography.callout)
                        Text(NSLocalizedString("wheretogetcredentials.issuer.visit_website", comment: "Visit Website"))
                            .font(AccessibleTypography.body)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccessiblePrimaryButtonStyle())
            }

            if let locations = issuer.locations, !locations.isEmpty {
                Button(action: { onLocationClick(locations[0]) }, label: {
                    Image(systemName: "map")
                        .font(AccessibleTypography.callout)
                })
                .buttonStyle(AccessibleSecondaryButtonStyle())
                .accessibilityLabel(NSLocalizedString("accessibility.wheretogetcredentials.open_in_maps.label", comment: ""))
            }
        }
    }

    // Helper properties and methods
    private var cardAccessibilityLabel: String {
        var label = String(format: NSLocalizedString("wheretogetcredentials.issuer.accessibility_label", comment: "%@. %@. Category: %@. "), issuer.name, issuer.description, getCategoryDisplayName(issuer.category))
        if issuer.verified {
            label += NSLocalizedString("wheretogetcredentials.issuer.verified_label", comment: "Verified issuer. ")
        }
        if issuer.status == "coming_soon" {
            label += NSLocalizedString("wheretogetcredentials.issuer.coming_soon_label", comment: "Coming soon. ")
        }
        if let locations = issuer.locations {
            label += String(format: NSLocalizedString("wheretogetcredentials.issuer.locations_available", comment: "%d locations available. "), locations.count)
        }
        return label
    }

    private var brandColor: Color {
        guard let hex = issuer.brandColor else {
            return AccessibleColors.primary
        }
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        if let value = UInt(sanitized, radix: 16) {
            return Color(hex: value)
        }
        return AccessibleColors.primary
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(cardBackgroundColor)
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: manager.settings.reduceMotion ? 0 : (isExpanded ? 8 : 2),
                y: manager.settings.reduceMotion ? 0 : (isExpanded ? 4 : 1)
            )
            .overlay(
                manager.settings.useHighContrast ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 2) : nil
            )
    }

    private var cardBackgroundColor: Color {
        if issuer.status == "coming_soon" {
            return Color(uiColor: .secondarySystemFill).opacity(0.5)
        }
        return Color(uiColor: .systemBackground)
    }

    private var shadowOpacity: Double {
        manager.settings.reduceTransparency ? 0 : (isExpanded ? 0.1 : 0.05)
    }

    private var textColor: Color {
        manager.settings.useHighContrast ? .black : .primary
    }

    private var logoTextColor: Color {
        manager.settings.useHighContrast ? .black : .white
    }

    private var instructionsBackground: Color {
        Color(uiColor: .secondarySystemFill).opacity(0.5)
    }

    private var cardSpacing: CGFloat {
        manager.settings.increaseTouchTargets ? 20 : 16
    }

    private var cardPadding: CGFloat {
        manager.settings.increaseTouchTargets ? 20 : 16
    }

    private var logoSize: CGFloat {
        manager.settings.useExtraLargeText ? 64 : 56
    }

    private var logoTextFont: Font {
        (manager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.callout).weight(.bold)
    }

    private func getCategoryDisplayName(_ category: String) -> String {
        switch category {
        case "financial": return NSLocalizedString("wheretogetcredentials.category.financial", comment: "Banking")
        case "superannuation": return NSLocalizedString("wheretogetcredentials.category.superannuation", comment: "Super Fund")
        case "government": return NSLocalizedString("wheretogetcredentials.category.government", comment: "Government")
        case "travel": return NSLocalizedString("wheretogetcredentials.category.travel", comment: "Travel")
        case "telecommunications": return NSLocalizedString("wheretogetcredentials.category.telecommunications", comment: "Telco")
        case "insurance": return NSLocalizedString("wheretogetcredentials.category.insurance", comment: "Insurance")
        default: return category.capitalized
        }
    }
}

// MARK: - Accessible Location Card

struct AccessibleLocationCard: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    let location: Location
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(AccessibleTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "mappin")
                        .font(AccessibleTypography.footnote)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                    Text(location.address)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(AccessibleTypography.footnote)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                    Text(location.hours)
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(locationBackground)
                    .overlay(
                        manager.settings.useHighContrast ?
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1) : nil
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.wheretogetcredentials.location_details.label", comment: "Location name, address and hours"), location.name, location.address, location.hours))
        .accessibilityHint(NSLocalizedString("accessibility.wheretogetcredentials.double_tap_to_open_maps.hint", comment: "Double tap to open in Maps hint"))
    }

    private var textColor: Color {
        manager.settings.useHighContrast ? .black : .primary
    }

    private var locationBackground: Color {
        if manager.settings.useHighContrast {
            return Color.yellow.opacity(0.1)
        }
        return Color.blue.opacity(0.1)
    }
}

// MARK: - Accessible Map View

struct AccessibleMapView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    let issuers: [Issuer]

    var body: some View {
        NavigationView {
            VStack {
                if manager.settings.simplifiedUI {
                    // List view for simplified UI
                    List {
                        ForEach(issuers) { issuer in
                            if let locations = issuer.locations {
                                Section(issuer.name) {
                                    ForEach(locations, id: \.name) { location in
                                        Button {
                                            openInMaps(location: location)
                                        } label: {
                                            VStack(alignment: .leading) {
                                                Text(location.name)
                                                    .font(AccessibleTypography.body)
                                                Text(location.address)
                                                    .font(AccessibleTypography.caption)
                                                    .foregroundColor(AccessibleColors.secondaryText)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text(NSLocalizedString("wheretogetcredentials.map.map_view", comment: "Map View"))
                        .font(AccessibleTypography.title)
                    // Actual map implementation would go here
                }
            }
            .navigationTitle(NSLocalizedString("wheretogetcredentials.map.title", comment: "Issuer Locations"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("wheretogetcredentials.map.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func openInMaps(location: Location) {
        // Open in Maps app using geocoding
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location.address) { placemarks, _ in
            if let placemark = placemarks?.first,
               let coordinate = placemark.location?.coordinate {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = location.name
                mapItem.openInMaps()
            } else {
                // Fallback: try opening with direct Maps URL if geocoding fails
                if let encodedAddress = location.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "https://maps.apple.com/?address=\(encodedAddress)") {
                    UIApplication.shared.open(url)
                }
            }
        }
        HapticFeedback.notification(.success)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: String(format: NSLocalizedString("wheretogetcredentials.map.opening_location_voiceover", comment: "Opening %@ in Maps"), location.name))
        }
    }
}

// MARK: - Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

#Preview {
    NavigationStack {
        WhereToGetCredentialsView()
            .environmentObject(NavigationCoordinator())
    }
}
