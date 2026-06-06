// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import UIKit
import SwiftUI

// MARK: - Screenshot Protection

/// Provides hardware-level screenshot and screen recording protection for sensitive views.
///
/// Uses the `UITextField.isSecureTextEntry` technique, which relies on iOS's internal
/// secure container to prevent the view hierarchy from appearing in screenshots,
/// screen recordings, and AirPlay mirroring.
///
/// Usage:
///   SomeView()
///       .screenshotProtected()
///
/// If the secure container cannot be extracted (future iOS changes), a blank
/// privacy placeholder is shown instead of falling back to an unprotected view.
final class ScreenshotBlocker {
    static let shared = ScreenshotBlocker()

    private init() {}

    /// Check if screen is being actively recorded or mirrored.
    /// Uses the first connected window scene rather than the deprecated UIScreen.main.
    var isScreenBeingRecorded: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return false
        }
        return windowScene.screen.isCaptured
    }
}

// MARK: - SecureContainerView (Primary Protection)

/// UIKit-based secure container that prevents screenshots at the system level.
///
/// Wraps SwiftUI content inside the secure layer extracted from a `UITextField`
/// with `isSecureTextEntry = true`. When extraction fails, a blank privacy
/// placeholder is rendered instead of exposing the underlying content.
struct SecureContainerView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        textField.isUserInteractionEnabled = false

        guard let secureContainer = textField.layer.sublayers?.first?.delegate as? UIView else {
            // CRITICAL: Do NOT fall back to an unprotected view.
            // Return a blank privacy placeholder so content is never exposed.
            let placeholder = PrivacyPlaceholderUIView()
            return placeholder
        }

        secureContainer.subviews.forEach { $0.removeFromSuperview() }

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        secureContainer.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: secureContainer.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: secureContainer.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: secureContainer.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: secureContainer.bottomAnchor)
        ])

        return secureContainer
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Privacy Placeholder (Fallback)

/// A UIKit view shown when the secure container cannot be extracted.
/// Displays a solid background so no sensitive content is ever visible.
private final class PrivacyPlaceholderUIView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        isAccessibilityElement = true
        accessibilityLabel = NSLocalizedString(
            "security.screenshot_protection_active.label",
            comment: "VoiceOver label when screenshot protection placeholder is displayed"
        )
        // A11Y-007: Explicit trait so VoiceOver announces this as static text
        // rather than a generic element. Without this, VoiceOver may omit the
        // element type from its announcement, confusing screen reader users.
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }
}

// MARK: - Screen Recording Overlay

/// Detects screen recording (AirPlay, QuickTime, etc.) and overlays a warning.
/// This is a supplementary layer on top of SecureContainerView.
struct ScreenRecordingOverlayModifier: ViewModifier {
    @State private var isScreenCaptured = false

    /// Resolve the screen from the first connected window scene instead of the
    /// deprecated UIScreen.main.
    private var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isScreenCaptured {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                                Text(NSLocalizedString(
                                    "security.screen_recording_blocked",
                                    comment: "Screen recording is blocked"
                                ))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(NSLocalizedString(
                            "security.screen_recording_blocked",
                            comment: "Screen recording is blocked"
                        ))
                        // A11Y-004: Mark overlay as modal so VoiceOver cannot
                        // navigate to obscured content behind it.
                        .accessibilityAddTraits(.isModal)
                }
            }
            .onAppear {
                isScreenCaptured = currentScreen?.isCaptured ?? false
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                let wasCaptured = isScreenCaptured
                isScreenCaptured = currentScreen?.isCaptured ?? false

                // A11Y-003: Announce state change to VoiceOver users when
                // screen recording starts or stops.
                if isScreenCaptured != wasCaptured {
                    let announcement = isScreenCaptured
                        ? NSLocalizedString(
                            "security.screen_recording_started",
                            comment: "VoiceOver announcement when screen recording is detected"
                        )
                        : NSLocalizedString(
                            "security.screen_recording_stopped",
                            comment: "VoiceOver announcement when screen recording ends"
                        )
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }
            }
    }
}

// MARK: - Combined ViewModifier

/// Combines hardware-level screenshot blocking (SecureContainerView) with
/// a screen recording detection overlay.
struct ScreenshotProtectedModifier: ViewModifier {
    func body(content: Content) -> some View {
        SecureContainerView {
            content
                .modifier(ScreenRecordingOverlayModifier())
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies hardware-level screenshot protection and screen recording detection.
    ///
    /// Uses `UITextField.isSecureTextEntry` internally to block screenshots at the
    /// system level. Also overlays a warning when screen recording is detected.
    /// If the secure container cannot be created, a blank privacy placeholder is
    /// shown instead of the content.
    func screenshotProtected() -> some View {
        self.modifier(ScreenshotProtectedModifier())
    }

    /// Detects screen recording only (does NOT block screenshots).
    /// Prefer `.screenshotProtected()` for sensitive content.
    func screenRecordingOverlay() -> some View {
        self.modifier(ScreenRecordingOverlayModifier())
    }
}
