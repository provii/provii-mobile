// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Context-sensitive help system fulfilling WCAG 2.2 AAA criterion 3.3.5. Provides help topics spanning
// vision, typography, interaction, cognitive, alternative input, and feature categories. Each topic
// includes standard and simplified reading-level text, related topic cross-links, and a reusable
// HelpButton component for inline help access throughout the app.

// MARK: - Help Topics

enum HelpTopic: String, CaseIterable, Identifiable {
    // Vision Settings
    case extraLargeText = "extra_large_text"
    case contrastLevel = "contrast_level"
    case highContrast = "high_contrast_mode"
    case reduceTransparency = "reduce_transparency"
    case colorBlindMode = "color_blind_modes"

    // Typography
    case lineSpacing = "line_spacing"
    case paragraphSpacing = "paragraph_spacing"
    case letterSpacing = "letter_spacing"
    case textWidth = "text_width"

    // Interaction
    case largeTouchTargets = "larger_touch_targets"
    case reduceMotion = "reduce_motion"
    case timeoutBehavior = "timeout_behavior"
    case simplifiedGestures = "simplified_gestures"
    case hapticFeedback = "haptic_feedback"

    // Cognitive
    case simplifiedUI = "simplified_interface"
    case stepIndicators = "step_indicators"
    case verboseDescriptions = "detailed_descriptions"
    case confirmActions = "confirm_actions"

    // Alternative Input
    case manualCodeEntry = "manual_code_entry"
    case voiceInput = "voice_input"

    // Features
    case qrScanning = "qr_code_scanning"
    case ageVerification = "age_verification"
    case credentials = "digital_credentials"
    case zeroKnowledge = "zero_knowledge_proofs"
    case credentialIssuance = "credential_issuance"
    case officerMode = "officer_mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .extraLargeText:
            return NSLocalizedString("help_topic_extra_large_text", comment: "Extra Large Text")
        case .contrastLevel:
            return NSLocalizedString("help_topic_contrast_level", comment: "Contrast Level")
        case .highContrast:
            return NSLocalizedString("help_topic_high_contrast", comment: "High Contrast Mode")
        case .reduceTransparency:
            return NSLocalizedString("help_topic_reduce_transparency", comment: "Reduce Transparency")
        case .colorBlindMode:
            return NSLocalizedString("help_topic_color_blind_modes", comment: "Colour Blind Modes")
        case .lineSpacing:
            return NSLocalizedString("help_topic_line_spacing", comment: "Line Spacing")
        case .paragraphSpacing:
            return NSLocalizedString("help_topic_paragraph_spacing", comment: "Paragraph Spacing")
        case .letterSpacing:
            return NSLocalizedString("help_topic_letter_spacing", comment: "Letter Spacing")
        case .textWidth:
            return NSLocalizedString("help_topic_text_width", comment: "Text Width")
        case .largeTouchTargets:
            return NSLocalizedString("help_topic_larger_touch_targets", comment: "Larger Touch Targets")
        case .reduceMotion:
            return NSLocalizedString("help_topic_reduce_motion", comment: "Reduce Motion")
        case .timeoutBehavior:
            return NSLocalizedString("help_topic_timeout_behavior", comment: "Timeout Behaviour")
        case .simplifiedGestures:
            return NSLocalizedString("help_topic_simplified_gestures", comment: "Simplified Gestures")
        case .hapticFeedback:
            return NSLocalizedString("help_topic_haptic_feedback", comment: "Haptic Feedback")
        case .simplifiedUI:
            return NSLocalizedString("help_topic_simplified_interface", comment: "Simplified Interface")
        case .stepIndicators:
            return NSLocalizedString("help_topic_step_indicators", comment: "Step Indicators")
        case .verboseDescriptions:
            return NSLocalizedString("help_topic_detailed_descriptions", comment: "Detailed Descriptions")
        case .confirmActions:
            return NSLocalizedString("help_topic_confirm_actions", comment: "Confirm Actions")
        case .manualCodeEntry:
            return NSLocalizedString("help_topic_manual_code_entry", comment: "Manual Code Entry")
        case .voiceInput:
            return NSLocalizedString("help_topic_voice_input", comment: "Voice Input")
        case .qrScanning:
            return NSLocalizedString("help_topic_qr_code_scanning", comment: "QR Code Scanning")
        case .ageVerification:
            return NSLocalizedString("help_topic_age_verification", comment: "Age Verification")
        case .credentials:
            return NSLocalizedString("help_topic_digital_credentials", comment: "Digital Credentials")
        case .zeroKnowledge:
            return NSLocalizedString("help_topic_zero_knowledge_proofs", comment: "Zero Knowledge Proofs")
        case .credentialIssuance:
            return NSLocalizedString("help_topic_credential_issuance", comment: "Credential Issuance")
        case .officerMode:
            return NSLocalizedString("help_topic_officer_mode", comment: "Officer Mode")
        }
    }

    var icon: String {
        switch self {
        // Vision Settings
        case .extraLargeText:
            return "textformat.size"
        case .contrastLevel:
            return "circle.lefthalf.filled"
        case .highContrast:
            return "circle.lefthalf.filled"
        case .reduceTransparency:
            return "square.stack.3d.down.right"
        case .colorBlindMode:
            return "eyedropper"

        // Typography
        case .lineSpacing:
            return "text.alignleft"
        case .paragraphSpacing:
            return "paragraph"
        case .letterSpacing:
            return "textformat"
        case .textWidth:
            return "text.justify"

        // Interaction
        case .largeTouchTargets:
            return "hand.tap"
        case .reduceMotion:
            return "motion.sensor"
        case .timeoutBehavior:
            return "clock"
        case .simplifiedGestures:
            return "hand.draw"
        case .hapticFeedback:
            return "waveform"

        // Cognitive
        case .simplifiedUI:
            return "square.grid.2x2"
        case .stepIndicators:
            return "list.number"
        case .verboseDescriptions:
            return "text.bubble"
        case .confirmActions:
            return "checkmark.shield"

        // Alternative Input
        case .manualCodeEntry:
            return "keyboard"
        case .voiceInput:
            return "mic.fill"

        // Features
        case .qrScanning:
            return "qrcode.viewfinder"
        case .ageVerification:
            return "checkmark.shield"
        case .credentials:
            return "wallet.pass.fill"
        case .zeroKnowledge:
            return "lock.shield"
        case .credentialIssuance:
            return "plus.circle.fill"
        case .officerMode:
            return "person.badge.key"
        }
    }

    func helpText(readingLevel: AccessibilitySettings.ReadingLevel = .standard) -> String {
        if readingLevel == .simplified {
            return simplifiedHelpText
        }
        return standardHelpText
    }

    private var standardHelpText: String {
        switch self {
        // Vision Settings
        case .extraLargeText:
            return NSLocalizedString("help_text_extra_large_text", comment: "Standard help text for extra large text setting")
        case .contrastLevel:
            return NSLocalizedString("help_text_contrast_level", comment: "Standard help text for contrast level setting")
        case .highContrast:
            return NSLocalizedString("help_text_high_contrast", comment: "Standard help text for high contrast mode setting")
        case .reduceTransparency:
            return NSLocalizedString("help_text_reduce_transparency", comment: "Standard help text for reduce transparency setting")
        case .colorBlindMode:
            return NSLocalizedString("help_text_color_blind_mode", comment: "Standard help text for colour blind mode setting")

        // Typography
        case .lineSpacing:
            return NSLocalizedString("help_text_line_spacing", comment: "Standard help text for line spacing setting")
        case .paragraphSpacing:
            return NSLocalizedString("help_text_paragraph_spacing", comment: "Standard help text for paragraph spacing setting")
        case .letterSpacing:
            return NSLocalizedString("help_text_letter_spacing", comment: "Standard help text for letter spacing setting")
        case .textWidth:
            return NSLocalizedString("help_text_text_width", comment: "Standard help text for text width setting")

        // Interaction
        case .largeTouchTargets:
            return NSLocalizedString("help_text_large_touch_targets", comment: "Standard help text for larger touch targets setting")
        case .reduceMotion:
            return NSLocalizedString("help_text_reduce_motion", comment: "Standard help text for reduce motion setting")
        case .timeoutBehavior:
            return NSLocalizedString("help_text_timeout_behavior", comment: "Standard help text for timeout behaviour setting")
        case .simplifiedGestures:
            return NSLocalizedString("help_text_simplified_gestures", comment: "Standard help text for simplified gestures setting")
        case .hapticFeedback:
            return NSLocalizedString("help_text_haptic_feedback", comment: "Standard help text for haptic feedback setting")

        // Cognitive
        case .simplifiedUI:
            return NSLocalizedString("help_text_simplified_ui", comment: "Standard help text for simplified interface setting")
        case .stepIndicators:
            return NSLocalizedString("help_text_step_indicators", comment: "Standard help text for step indicators setting")
        case .verboseDescriptions:
            return NSLocalizedString("help_text_verbose_descriptions", comment: "Standard help text for detailed descriptions setting")
        case .confirmActions:
            return NSLocalizedString("help_text_confirm_actions", comment: "Standard help text for confirm actions setting")

        // Alternative Input
        case .manualCodeEntry:
            return NSLocalizedString("help_text_manual_code_entry", comment: "Standard help text for manual code entry setting")
        case .voiceInput:
            return NSLocalizedString("help_text_voice_input", comment: "Standard help text for voice input setting")

        // Features
        case .qrScanning:
            return NSLocalizedString("help_text_qr_scanning", comment: "Standard help text for QR code scanning feature")
        case .ageVerification:
            return NSLocalizedString("help_text_age_verification", comment: "Standard help text for age verification feature")
        case .credentials:
            return NSLocalizedString("help_text_credentials", comment: "Standard help text for digital credentials feature")
        case .zeroKnowledge:
            return NSLocalizedString("help_text_zero_knowledge", comment: "Standard help text for zero knowledge proofs feature")
        case .credentialIssuance:
            return NSLocalizedString("help_text_credential_issuance", comment: "Standard help text for credential issuance feature")
        case .officerMode:
            return NSLocalizedString("help_text_officer_mode", comment: "Standard help text for officer mode feature")
        }
    }

    private var simplifiedHelpText: String {
        switch self {
        // Vision Settings
        case .extraLargeText:
            return NSLocalizedString("help_text_extra_large_text_simplified", comment: "")

        case .contrastLevel:
            return NSLocalizedString("help_text_contrast_level_simplified", comment: "")

        case .highContrast:
            return NSLocalizedString("help_text_high_contrast_simplified", comment: "")

        case .reduceTransparency:
            return NSLocalizedString("help_text_reduce_transparency_simplified", comment: "")

        case .colorBlindMode:
            return NSLocalizedString("help_text_color_blind_mode_simplified", comment: "")

        // Typography
        case .lineSpacing:
            return NSLocalizedString("help_text_line_spacing_simplified", comment: "")

        case .paragraphSpacing:
            return NSLocalizedString("help_text_paragraph_spacing_simplified", comment: "")

        case .letterSpacing:
            return NSLocalizedString("help_text_letter_spacing_simplified", comment: "")

        case .textWidth:
            return NSLocalizedString("help_text_text_width_simplified", comment: "")

        // Interaction
        case .largeTouchTargets:
            return NSLocalizedString("help_text_large_touch_targets_simplified", comment: "")

        case .reduceMotion:
            return NSLocalizedString("help_text_reduce_motion_simplified", comment: "")

        case .timeoutBehavior:
            return NSLocalizedString("help_text_timeout_behavior_simplified", comment: "")

        case .simplifiedGestures:
            return NSLocalizedString("help_text_simplified_gestures_simplified", comment: "")

        case .hapticFeedback:
            return NSLocalizedString("help_text_haptic_feedback_simplified", comment: "")

        // Cognitive
        case .simplifiedUI:
            return NSLocalizedString("help_text_simplified_ui_simplified", comment: "")

        case .stepIndicators:
            return NSLocalizedString("help_text_step_indicators_simplified", comment: "")

        case .verboseDescriptions:
            return NSLocalizedString("help_text_verbose_descriptions_simplified", comment: "")

        case .confirmActions:
            return NSLocalizedString("help_text_confirm_actions_simplified", comment: "")

        // Alternative Input
        case .manualCodeEntry:
            return NSLocalizedString("help_text_manual_code_entry_simplified", comment: "")

        case .voiceInput:
            return NSLocalizedString("help_text_voice_input_simplified", comment: "")

        // Features
        case .qrScanning:
            return NSLocalizedString("help_text_qr_scanning_simplified", comment: "")

        case .ageVerification:
            return NSLocalizedString("help_text_age_verification_simplified", comment: "")

        case .credentials:
            return NSLocalizedString("help_text_credentials_simplified", comment: "")

        case .zeroKnowledge:
            return NSLocalizedString("help_text_zero_knowledge_simplified", comment: "")

        case .credentialIssuance:
            return NSLocalizedString("help_text_credential_issuance_simplified", comment: "")

        case .officerMode:
            return NSLocalizedString("help_text_officer_mode_simplified", comment: "")
        }
    }

    var relatedTopics: [HelpTopic] {
        switch self {
        case .extraLargeText:
            return [.lineSpacing, .textWidth, .contrastLevel, .reduceTransparency]
        case .contrastLevel:
            return [.highContrast, .colorBlindMode, .reduceTransparency, .extraLargeText]
        case .highContrast:
            return [.contrastLevel, .colorBlindMode, .extraLargeText, .reduceTransparency]
        case .colorBlindMode:
            return [.highContrast, .contrastLevel]
        case .lineSpacing:
            return [.paragraphSpacing, .letterSpacing, .textWidth, .extraLargeText]
        case .paragraphSpacing:
            return [.lineSpacing, .letterSpacing]
        case .letterSpacing:
            return [.lineSpacing, .paragraphSpacing]
        case .textWidth:
            return [.lineSpacing, .extraLargeText]
        case .reduceMotion:
            return [.simplifiedUI, .reduceTransparency]
        case .timeoutBehavior:
            return [.confirmActions, .stepIndicators]
        case .manualCodeEntry:
            return [.voiceInput, .qrScanning]
        case .voiceInput:
            return [.manualCodeEntry, .qrScanning]
        case .qrScanning:
            return [.manualCodeEntry, .voiceInput]
        case .ageVerification:
            return [.zeroKnowledge, .credentials, .qrScanning, .credentialIssuance]
        case .credentials:
            return [.credentialIssuance, .ageVerification, .zeroKnowledge, .officerMode]
        case .zeroKnowledge:
            return [.ageVerification, .credentials]
        case .credentialIssuance:
            return [.credentials, .qrScanning, .officerMode, .ageVerification]
        case .officerMode:
            return [.credentialIssuance, .credentials]
        default:
            return []
        }
    }

    var category: HelpCategory {
        switch self {
        case .extraLargeText, .contrastLevel, .highContrast, .reduceTransparency, .colorBlindMode:
            return .vision
        case .lineSpacing, .paragraphSpacing, .letterSpacing, .textWidth:
            return .typography
        case .largeTouchTargets, .reduceMotion, .timeoutBehavior, .simplifiedGestures, .hapticFeedback:
            return .interaction
        case .simplifiedUI, .stepIndicators, .verboseDescriptions, .confirmActions:
            return .cognitive
        case .manualCodeEntry, .voiceInput:
            return .alternativeInput
        case .qrScanning, .ageVerification, .credentials, .zeroKnowledge, .credentialIssuance, .officerMode:
            return .features
        }
    }
}

enum HelpCategory: String, CaseIterable {
    case vision = "vision"
    case typography = "typography"
    case interaction = "interaction"
    case cognitive = "cognitive_support"
    case alternativeInput = "alternative_input"
    case features = "features"

    var localizedName: String {
        switch self {
        case .vision:
            return NSLocalizedString("help_category_vision", comment: "Vision")
        case .typography:
            return NSLocalizedString("help_category_typography", comment: "Typography")
        case .interaction:
            return NSLocalizedString("help_category_interaction", comment: "Interaction")
        case .cognitive:
            return NSLocalizedString("help_category_cognitive_support", comment: "Cognitive Support")
        case .alternativeInput:
            return NSLocalizedString("help_category_alternative_input", comment: "Alternative Input")
        case .features:
            return NSLocalizedString("help_category_features", comment: "Features")
        }
    }

    var topics: [HelpTopic] {
        HelpTopic.allCases.filter { $0.category == self }
    }
}

// MARK: - Help Button Component

struct HelpButton: View {
    @ObservedObject private var manager = AccessibilityManager.shared

    let topic: HelpTopic
    @State private var showingHelp = false

    // Focus restoration for WCAG 2.4.3
    @FocusState private var isFocused: Bool
    @State private var wasFocused = false

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            showingHelp = true
        }, label: {
            Image(systemName: "questionmark.circle")
                .foregroundColor(AccessibleColors.primary)
                .font(manager.settings.useExtraLargeText ? AccessibleTypography.body : AccessibleTypography.subheadline)
        })
        .focused($isFocused)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.help.help_topic.label", comment: "Help button for topic"), topic.title))
        .accessibilityHint(String(format: NSLocalizedString("accessibility.help.double_tap_to_learn_more.hint", comment: "Double tap to learn more about topic hint"), topic.title))
        .sheet(isPresented: $showingHelp) {
            HelpDetailView(topic: topic)
                .sheetKeyboardNavigation(isPresented: $showingHelp)
        }
        .onChange(of: showingHelp) { _, isShowing in
            if isShowing {
                wasFocused = isFocused
            } else if wasFocused {
                isFocused = true
                wasFocused = false
            }
        }
    }
}

// MARK: - Help Detail View

struct HelpDetailView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss

    let topic: HelpTopic

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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

                    // Main help text
                    Text(topic.helpText(readingLevel: manager.settings.readingLevel))
                        .font(AccessibleTypography.body)
                        .foregroundColor(.primary)
                        .accessibleText(baseSize: 17)

                    // Related topics
                    if !topic.relatedTopics.isEmpty {
                        Divider()

                        AccessibleSectionHeader.h3(NSLocalizedString("help_related_topics", comment: "Related Topics"), subtitle: nil)

                        ForEach(topic.relatedTopics) { relatedTopic in
                            NavigationLink(destination: HelpDetailView(topic: relatedTopic)) {
                                HStack {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(AccessibleColors.primary)
                                    Text(relatedTopic.title)
                                        .font(AccessibleTypography.body)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                            .accessibilityLabel(String(format: NSLocalizedString("accessibility.help.learn_about_topic.label", comment: "Learn about related topic link"), relatedTopic.title))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common_done", comment: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(AccessibleColors.primary)
                }
            }
        }
    }
}

// MARK: - Help Centre View

struct HelpCenterView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredCategories: [HelpCategory] {
        if searchText.isEmpty {
            return HelpCategory.allCases
        }
        return HelpCategory.allCases.filter { category in
            category.topics.contains { topic in
                topic.title.localizedCaseInsensitiveContains(searchText) ||
                topic.helpText(readingLevel: manager.settings.readingLevel).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Breadcrumb Navigation
                BreadcrumbView(path: [
                    NSLocalizedString("breadcrumb.home", comment: "Home"),
                    NSLocalizedString("breadcrumb.settings", comment: "Settings"),
                    NSLocalizedString("breadcrumb.accessibility", comment: "Accessibility"),
                    NSLocalizedString("breadcrumb.help", comment: "Help Centre")
                ])
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                List {
                    ForEach(filteredCategories, id: \.self) { category in
                    Section {
                        ForEach(category.topics) { topic in
                            if searchText.isEmpty || topic.title.localizedCaseInsensitiveContains(searchText) {
                                NavigationLink(destination: HelpDetailView(topic: topic)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(topic.title)
                                            .font(AccessibleTypography.body)
                                        if manager.settings.verboseDescriptions {
                                            Text(String(topic.helpText(readingLevel: manager.settings.readingLevel).prefix(100)) + "...")
                                                .font(AccessibleTypography.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    } header: {
                        Text(category.localizedName)
                    }
                    }
                }
                .searchable(text: $searchText, prompt: NSLocalizedString("help_search_prompt", comment: "Search help topics"))
            }
            .navigationTitle(NSLocalizedString("help_center_title", comment: "Help Centre"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common_done", comment: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(AccessibleColors.primary)
                }
            }
        }
    }
}

#Preview {
    HelpCenterView()
}
