// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Gesture guidance system providing accessible alternatives to gesture based interactions.
// Satisfies WCAG 2.2 AAA by ensuring all swipe, long press, double tap, pinch, and rotate
// actions have VoiceOver accessible button alternatives. Includes swipeable cards, an
// accessible pager/carousel, and gesture hint views.

// MARK: - Accessible Gesture Actions

/// Custom accessibility action type
struct AccessibilityActionItem {
    let name: String
    let handler: () -> Void
}

/// Protocol for views that use gestures to define accessible alternatives
protocol AccessibleGestureView {
    /// Provides accessibility actions as alternatives to gestures
    var accessibilityActions: [AccessibilityActionItem] { get }
}

// MARK: - Gesture Type Definitions

enum GestureType {
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case longPress
    case doubleTap
    case pinch
    case rotate

    var accessibilityDescription: String {
        switch self {
        case .swipeLeft:
            return NSLocalizedString("accessibility.gesture.swipe_left", comment: "Gesture description for swipe left")
        case .swipeRight:
            return NSLocalizedString("accessibility.gesture.swipe_right", comment: "Gesture description for swipe right")
        case .swipeUp:
            return NSLocalizedString("accessibility.gesture.swipe_up", comment: "Gesture description for swipe up")
        case .swipeDown:
            return NSLocalizedString("accessibility.gesture.swipe_down", comment: "Gesture description for swipe down")
        case .longPress:
            return NSLocalizedString("accessibility.gesture.long_press", comment: "Gesture description for long press")
        case .doubleTap:
            return NSLocalizedString("accessibility.gesture.double_tap", comment: "Gesture description for double tap")
        case .pinch:
            return NSLocalizedString("accessibility.gesture.pinch_to_zoom", comment: "Gesture description for pinch to zoom")
        case .rotate:
            return NSLocalizedString("accessibility.gesture.rotate", comment: "Gesture description for rotate")
        }
    }

    var alternativeInstruction: String {
        switch self {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            return NSLocalizedString("accessibility.gesture.voiceover_actions", comment: "Alternative instruction for swipe gestures")
        case .longPress:
            return NSLocalizedString("accessibility.gesture.voiceover_menu", comment: "Alternative instruction for long press")
        case .doubleTap:
            return NSLocalizedString("accessibility.gesture.single_tap_voiceover", comment: "Alternative instruction for double tap")
        case .pinch:
            return NSLocalizedString("accessibility.gesture.zoom_controls", comment: "Alternative instruction for pinch gesture")
        case .rotate:
            return NSLocalizedString("accessibility.gesture.rotation_buttons", comment: "Alternative instruction for rotate gesture")
        }
    }
}

// MARK: - Accessible Swipeable Card

/// A card view that supports swipe gestures with full VoiceOver alternatives.
/// Example use case: credential cards that can be swiped to delete or archive.
struct AccessibleSwipeableCard<Content: View>: View {
    let content: Content
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    let swipeLeftLabel: String?
    let swipeRightLabel: String?

    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @State private var offset: CGFloat = 0
    @State private var showingActions = false

    init(
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        swipeLeftLabel: String? = nil,
        swipeRightLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
        self.swipeLeftLabel = swipeLeftLabel
        self.swipeRightLabel = swipeRightLabel
    }

    var body: some View {
        ZStack {
            // Background action buttons (revealed by swipe)
            HStack {
                if let onSwipeRight = onSwipeRight, let label = swipeRightLabel {
                    Button(action: onSwipeRight) {
                        Text(NSLocalizedString(label, comment: "Swipe right action label"))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(width: 80)
                    .background(Color.green)
                }

                Spacer()

                if let onSwipeLeft = onSwipeLeft, let label = swipeLeftLabel {
                    Button(action: onSwipeLeft) {
                        Text(NSLocalizedString(label, comment: "Swipe left action label"))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(width: 80)
                    .background(Color.red)
                }
            }

            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if !accessibilityManager.settings.simplifiedGestures {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            if !accessibilityManager.settings.simplifiedGestures {
                                handleSwipeEnd(translation: gesture.translation.width)
                            }
                        }
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            // Provide button alternatives to swipe gestures
            if let onSwipeLeft = onSwipeLeft, let label = swipeLeftLabel {
                Button(label, action: onSwipeLeft)
            }
            if let onSwipeRight = onSwipeRight, let label = swipeRightLabel {
                Button(label, action: onSwipeRight)
            }
        }
    }

    private func handleSwipeEnd(translation: CGFloat) {
        let threshold: CGFloat = 100

        if translation < -threshold, let action = onSwipeLeft {
            action()

            // Haptic feedback
            if accessibilityManager.settings.hapticFeedback {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        } else if translation > threshold, let action = onSwipeRight {
            action()

            // Haptic feedback
            if accessibilityManager.settings.hapticFeedback {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        }

        // Reset offset with animation
        withAnimation {
            offset = 0
        }
    }
}

// MARK: - Accessible Carousel/Pager

/// A pager/carousel view with VoiceOver friendly navigation.
struct AccessiblePagerView<Content: View>: View {
    let pages: [Content]
    let pageLabels: [String]
    @Binding var currentPage: Int

    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    init(
        currentPage: Binding<Int>,
        pageLabels: [String],
        @ViewBuilder content: () -> [Content]
    ) {
        self._currentPage = currentPage
        self.pageLabels = pageLabels
        self.pages = content()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Current page content
            if pages.indices.contains(currentPage) {
                pages[currentPage]
                    .transition(.slide)
            }

            // Navigation controls (always visible for accessibility)
            if accessibilityManager.settings.simplifiedGestures || UIAccessibility.isVoiceOverRunning {
                HStack(spacing: 20) {
                    Button(action: previousPage) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    .disabled(currentPage == 0)
                    .accessibilityLabel(NSLocalizedString("accessibility.gesture.previous_page.label", comment: "Previous page button"))
                    .accessibilityHint(currentPage > 0 ? String(format: NSLocalizedString("accessibility.gesture.go_to_page.hint", comment: "Go to specific page hint"), pageLabels[currentPage - 1]) : NSLocalizedString("accessibility.gesture.no_previous_page.hint", comment: "No previous page hint"))

                    Text(String(format: NSLocalizedString("accessibility.gesture.page_counter", comment: "Page counter text"), currentPage + 1, pages.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(String(format: NSLocalizedString("accessibility.gesture.page_indicator.label", comment: "Page indicator with current page, total pages and page label"), currentPage + 1, pages.count, pageLabels[currentPage]))

                    Button(action: nextPage) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                    .disabled(currentPage == pages.count - 1)
                    .accessibilityLabel(NSLocalizedString("accessibility.gesture.next_page.label", comment: "Next page button"))
                    .accessibilityHint(
                        currentPage < pages.count - 1
                            ? String(format: NSLocalizedString("accessibility.gesture.go_to_page.hint", comment: "Go to specific page hint"), pageLabels[currentPage + 1])
                            : NSLocalizedString("accessibility.gesture.no_next_page.hint", comment: "No next page hint"))
                }
                .padding()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(pageLabels[currentPage])
        .accessibilityActions {
            if currentPage > 0 {
                Button(String(format: NSLocalizedString("accessibility.gesture.previous_with_label", comment: "Previous page with label"), pageLabels[currentPage - 1]), action: previousPage)
            }
            if currentPage < pages.count - 1 {
                Button(String(format: NSLocalizedString("accessibility.gesture.next_with_label", comment: "Next page with label"), pageLabels[currentPage + 1]), action: nextPage)
            }
        }
    }

    private func previousPage() {
        guard currentPage > 0 else { return }

        withAnimation {
            currentPage -= 1
        }

        // VoiceOver announcement
        UIAccessibility.post(notification: .announcement, argument: pageLabels[currentPage])

        // Haptic feedback
        if accessibilityManager.settings.hapticFeedback {
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        }
    }

    private func nextPage() {
        guard currentPage < pages.count - 1 else { return }

        withAnimation {
            currentPage += 1
        }

        // VoiceOver announcement
        UIAccessibility.post(notification: .announcement, argument: pageLabels[currentPage])

        // Haptic feedback
        if accessibilityManager.settings.hapticFeedback {
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        }
    }
}

// MARK: - Gesture Hint View

/// Displays helpful hints for gesture based interactions.
/// Shows alternatives for VoiceOver users.
struct GestureHintView: View {
    let gesture: GestureType
    let action: String

    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        if accessibilityManager.settings.verboseDescriptions {
            HStack(spacing: 8) {
                Image(systemName: gestureIcon)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(action)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(UIAccessibility.isVoiceOverRunning ?
                         gesture.alternativeInstruction :
                         gesture.accessibilityDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .accessibilityLabel(String(format: NSLocalizedString("accessibility.gesture.gesture_hint.label", comment: "Gesture hint with action and alternative instruction"), action, gesture.alternativeInstruction))
        }
    }

    private var gestureIcon: String {
        switch gesture {
        case .swipeLeft, .swipeRight:
            return "hand.draw"
        case .swipeUp, .swipeDown:
            return "hand.draw.fill"
        case .longPress:
            return "hand.tap.fill"
        case .doubleTap:
            return "hand.tap"
        case .pinch:
            return "hand.pinch"
        case .rotate:
            return "rotate.right"
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Add accessible alternatives to swipe gestures
    func accessibleSwipeActions(
        leading: (() -> Void)? = nil,
        trailing: (() -> Void)? = nil,
        leadingLabel: String? = nil,
        trailingLabel: String? = nil
    ) -> some View {
        self.modifier(AccessibleSwipeModifier(
            leading: leading,
            trailing: trailing,
            leadingLabel: leadingLabel,
            trailingLabel: trailingLabel
        ))
    }

    /// Add gesture hint if verbose descriptions are enabled
    func gestureHint(_ gesture: GestureType, action: String) -> some View {
        VStack(spacing: 8) {
            self
            GestureHintView(gesture: gesture, action: action)
        }
    }
}

// MARK: - Swipe Modifier

private struct AccessibleSwipeModifier: ViewModifier {
    let leading: (() -> Void)?
    let trailing: (() -> Void)?
    let leadingLabel: String?
    let trailingLabel: String?

    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                if let leading = leading, let label = leadingLabel {
                    Button(label, action: leading)
                }
                if let trailing = trailing, let label = trailingLabel {
                    Button(label, action: trailing)
                }
            }
    }
}

// MARK: - Example Usage Documentation

/*
 Example 1: Swipeable Card

 AccessibleSwipeableCard(
     onSwipeLeft: { deleteItem() },
     onSwipeRight: { archiveItem() },
     swipeLeftLabel: "Delete",
     swipeRightLabel: "Archive"
 ) {
     CredentialCard(credential: credential)
 }

 Example 2: Pager/Carousel

 AccessiblePagerView(
     currentPage: $currentPage,
     pageLabels: ["Introduction", "Features", "Setup"]
 ) {
     [
         IntroductionView(),
         FeaturesView(),
         SetupView()
     ]
 }

 Example 3: Gesture Hint

 CardView()
     .gestureHint(.swipeLeft, action: "Swipe left to delete")

 Example 4: Simple Swipe Actions

 CredentialCard(credential: credential)
     .accessibleSwipeActions(
         leading: { archive() },
         trailing: { delete() },
         leadingLabel: "Archive credential",
         trailingLabel: "Delete credential"
     )
 */
