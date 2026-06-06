// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

// Animation control system satisfying WCAG 2.2 AA criterion 2.2.2 (Pause, Stop, Hide).
// Provides a global pause/resume mechanism, controlled animation modifiers, auto pause
// for long running animations, and an accessible progress view that respects reduce motion
// and pause state preferences.

// MARK: - Animation State Manager

@MainActor
class AnimationStateManager: ObservableObject {
    static let shared = AnimationStateManager()

    @Published var isPaused: Bool = false
    @Published var activeAnimations: Set<String> = []

    private init() {}

    /// Register an animation
    func registerAnimation(id: String) {
        activeAnimations.insert(id)
    }

    /// Unregister an animation
    func unregisterAnimation(id: String) {
        activeAnimations.remove(id)
    }

    /// Pause all animations
    func pauseAll() {
        isPaused = true
        announceChange(isPaused: true)
    }

    /// Resume all animations
    func resumeAll() {
        isPaused = false
        announceChange(isPaused: false)
    }

    /// Toggle animation state
    func toggle() {
        if isPaused {
            resumeAll()
        } else {
            pauseAll()
        }
    }

    private func announceChange(isPaused: Bool) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let message = isPaused ? NSLocalizedString("accessibility.animation.paused", comment: "Animations paused announcement") : NSLocalizedString("accessibility.animation.resumed", comment: "Animations resumed announcement")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - Animation Pause Button

struct AnimationPauseButton: View {
    @ObservedObject private var animationManager = AnimationStateManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        Button(action: {
            animationManager.toggle()
            HapticFeedback.selection()
        }, label: {
            HStack(spacing: 8) {
                Image(systemName: animationManager.isPaused ? "play.fill" : "pause.fill")
                    .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.callout : AccessibleTypography.subheadline)

                if accessibilityManager.settings.verboseDescriptions {
                    Text(animationManager.isPaused ? NSLocalizedString("accessibility.animation.resume_button.text", comment: "Resume button text") : NSLocalizedString("accessibility.animation.pause_button.text", comment: "Pause button text"))
                        .font(AccessibleTypography.caption)
                }
            }
            .foregroundColor(AccessibleColors.primary)
            .padding(.horizontal, accessibilityManager.settings.increaseTouchTargets ? 16 : 12)
            .padding(.vertical, accessibilityManager.settings.increaseTouchTargets ? 12 : 8)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AccessibleColors.primary.opacity(0.1))
            )
        })
        .accessibilityLabel(animationManager.isPaused ? NSLocalizedString("accessibility.animation.resume_animations.label", comment: "Resume animations button") : NSLocalizedString("accessibility.animation.pause_animations.label", comment: "Pause animations button"))
        .accessibilityHint(NSLocalizedString("accessibility.animation.toggles_animation_playback.hint", comment: "Toggles animation playback hint"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Controlled Animation Modifier

struct ControlledAnimationModifier: ViewModifier {
    @ObservedObject private var animationManager = AnimationStateManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    let id: String
    let animation: Animation?
    let duration: Double

    init(id: String, duration: Double = 0.3) {
        self.id = id
        self.duration = duration
        self.animation = .easeInOut(duration: duration)
    }

    func body(content: Content) -> some View {
        content
            .animation(
                effectiveAnimation,
                value: animationManager.isPaused
            )
            .onAppear {
                animationManager.registerAnimation(id: id)
            }
            .onDisappear {
                animationManager.unregisterAnimation(id: id)
            }
    }

    private var effectiveAnimation: Animation? {
        // WCAG 2.2 AAA: 2.3.3 Animation from Interactions
        // Must completely remove animations, not just reduce duration to 0
        if accessibilityManager.settings.reduceMotion {
            return nil // Complete removal, not duration = 0
        }

        // No animation if paused
        if animationManager.isPaused {
            return nil
        }

        // Extended duration if extended timeouts enabled
        if accessibilityManager.settings.timeoutBehavior == .extended {
            return .easeInOut(duration: duration * 1.5)
        }

        return animation
    }
}

extension View {
    /// Apply controlled animation that respects accessibility settings and pause state
    func controlledAnimation(id: String, duration: Double = 0.3) -> some View {
        self.modifier(ControlledAnimationModifier(id: id, duration: duration))
    }
}

// MARK: - Animation Control Banner

struct AnimationControlBanner: View {
    @ObservedObject private var animationManager = AnimationStateManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        if !animationManager.activeAnimations.isEmpty &&
           !accessibilityManager.settings.reduceMotion {
            HStack(spacing: 12) {
                Image(systemName: "film")
                    .font(AccessibleTypography.subheadline)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)

                Text(String(format: NSLocalizedString("accessibility.animation.active_animations_count", comment: "Active animations count"), animationManager.activeAnimations.count))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)

                Spacer()

                AnimationPauseButton()
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        accessibilityManager.settings.useHighContrast ?
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1) : nil
                    )
            )
            .padding(.horizontal)
            .accessibilityElement(children: .contain)
        }
    }
}

// MARK: - Accessibility-Aware Progress View

struct AccessibleProgressView: View {
    @ObservedObject private var manager = AccessibilityManager.shared
    @ObservedObject private var animationManager = AnimationStateManager.shared

    let message: String
    let progress: Double?

    init(message: String = NSLocalizedString("accessibility.animation.loading.default_message", comment: "Default loading message"), progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    var body: some View {
        VStack(spacing: 20) {
            if manager.settings.reduceMotion || animationManager.isPaused {
                // Static indicator for reduced motion or paused state
                Image(systemName: "hourglass")
                    .font(manager.settings.useExtraLargeText ? AccessibleTypography.title2 : AccessibleTypography.title3)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)
            } else {
                // Animated progress indicator
                ProgressView()
                    .scaleEffect(manager.settings.useExtraLargeText ? 2.0 : 1.5)
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(AccessibleTypography.body)
                .multilineTextAlignment(.center)

            if let progress = progress {
                ProgressView(value: progress)
                    .frame(width: 200)
                    .accessibilityValue(String(format: NSLocalizedString("accessibility.animation.progress.percent_complete", comment: "Progress percent complete"), Int(progress * 100)))
            }

            if manager.settings.verboseDescriptions {
                Text(NSLocalizedString("accessibility.animation.progress.please_wait", comment: "Please wait message"))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Show pause button if animations are playing
            if !manager.settings.reduceMotion && !animationManager.activeAnimations.isEmpty {
                AnimationPauseButton()
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            format: NSLocalizedString("accessibility.animation.progress_status.label", comment: "Progress status with message and percentage"),
            message,
            progress.map {
                String(format: NSLocalizedString("accessibility.animation.percent_complete.label", comment: "Percent complete"), Int($0 * 100))
            } ?? NSLocalizedString("accessibility.animation.loading.label", comment: "Loading indicator")))
        .accessibilityValue(progress.map { String(format: "%d%%", Int($0 * 100)) } ?? NSLocalizedString("accessibility.loading.in_progress", comment: "In progress"))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Auto-Pause for Long Animations

struct AutoPauseModifier: ViewModifier {
    @ObservedObject private var animationManager = AnimationStateManager.shared
    @State private var pauseTask: Task<Void, Never>?

    let duration: TimeInterval
    let id: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                // WCAG 2.2.2: Auto-pause animations > 5 seconds
                if duration > 5.0 {
                    pauseTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
                        await MainActor.run {
                            animationManager.pauseAll()
                            announceAutoPause()
                        }
                    }
                }
            }
            .onDisappear {
                pauseTask?.cancel()
            }
    }

    private func announceAutoPause() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: NSLocalizedString("accessibility.animation.auto_paused", comment: "Animation auto-paused announcement")
        )
    }
}

extension View {
    /// Automatically pause long-running animations after 5 seconds (WCAG 2.2.2)
    func autoPauseAnimation(duration: TimeInterval, id: String) -> some View {
        self.modifier(AutoPauseModifier(duration: duration, id: id))
    }
}
