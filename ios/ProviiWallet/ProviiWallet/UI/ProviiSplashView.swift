// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import UIKit

// MARK: - Provii Logo Path Shapes

/// The "P" body shape of the Provii logo, rendered in a 400x400 coordinate space.
struct ProviiPBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 400.0
        let scaleY = rect.height / 400.0

        var path = Path()
        path.move(to: CGPoint(x: 185.5 * scaleX, y: 25.7 * scaleY))
        path.addCurve(
            to: CGPoint(x: 150.8 * scaleX, y: 33.0 * scaleY),
            control1: CGPoint(x: 173.0 * scaleX, y: 27.2 * scaleY),
            control2: CGPoint(x: 160.8 * scaleX, y: 29.8 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 89.0 * scaleX, y: 71.0 * scaleY),
            control1: CGPoint(x: 126.2 * scaleX, y: 41.1 * scaleY),
            control2: CGPoint(x: 107.1 * scaleX, y: 52.8 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 46.8 * scaleX, y: 148.2 * scaleY),
            control1: CGPoint(x: 67.2 * scaleX, y: 92.7 * scaleY),
            control2: CGPoint(x: 54.2 * scaleX, y: 116.4 * scaleY)
        )
        path.addLine(to: CGPoint(x: 44.6 * scaleX, y: 157.5 * scaleY))
        path.addCurve(
            to: CGPoint(x: 44.3 * scaleX, y: 265.4 * scaleY),
            control1: CGPoint(x: 44.3 * scaleX, y: 227.6 * scaleY),
            control2: CGPoint(x: 44.3 * scaleX, y: 227.6 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 44.9 * scaleX, y: 274.3 * scaleY),
            control1: CGPoint(x: 44.6 * scaleX, y: 265.4 * scaleY),
            control2: CGPoint(x: 44.3 * scaleX, y: 273.7 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 78.3 * scaleX, y: 245.5 * scaleY),
            control1: CGPoint(x: 46.0 * scaleX, y: 275.4 * scaleY),
            control2: CGPoint(x: 47.9 * scaleX, y: 273.8 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 99.4 * scaleX, y: 224.8 * scaleY),
            control1: CGPoint(x: 89.0 * scaleX, y: 235.6 * scaleY),
            control2: CGPoint(x: 98.5 * scaleX, y: 226.3 * scaleY)
        )
        path.addLine(to: CGPoint(x: 101.0 * scaleX, y: 222.2 * scaleY))
        path.addCurve(
            to: CGPoint(x: 101.0 * scaleX, y: 149.3 * scaleY),
            control1: CGPoint(x: 101.0 * scaleX, y: 222.2 * scaleY),
            control2: CGPoint(x: 101.0 * scaleX, y: 178.8 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 102.0 * scaleX, y: 67.5 * scaleY),
            control1: CGPoint(x: 101.0 * scaleX, y: 105.9 * scaleY),
            control2: CGPoint(x: 101.4 * scaleX, y: 72.9 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 110.6 * scaleX, y: 37.1 * scaleY),
            control1: CGPoint(x: 103.5 * scaleX, y: 55.0 * scaleY),
            control2: CGPoint(x: 105.4 * scaleX, y: 48.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 152.9 * scaleX, y: -6.9 * scaleY),
            control1: CGPoint(x: 119.7 * scaleX, y: 17.7 * scaleY),
            control2: CGPoint(x: 133.9 * scaleX, y: 3.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 190.0 * scaleX, y: -17.9 * scaleY),
            control1: CGPoint(x: 166.1 * scaleX, y: -13.7 * scaleY),
            control2: CGPoint(x: 175.2 * scaleX, y: -16.5 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 249.6 * scaleX, y: -2.9 * scaleY),
            control1: CGPoint(x: 209.7 * scaleX, y: -20.0 * scaleY),
            control2: CGPoint(x: 231.2 * scaleX, y: -15.4 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 256.5 * scaleX, y: 0.1 * scaleY),
            control1: CGPoint(x: 252.3 * scaleX, y: -1.3 * scaleY),
            control2: CGPoint(x: 255.3 * scaleX, y: -0.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 277.5 * scaleX, y: -18.9 * scaleY),
            control1: CGPoint(x: 257.9 * scaleX, y: 0.1 * scaleY),
            control2: CGPoint(x: 265.0 * scaleX, y: -6.3 * scaleY)
        )
        path.addLine(to: CGPoint(x: 296.3 * scaleX, y: -37.9 * scaleY))
        path.addLine(to: CGPoint(x: 294.5 * scaleX, y: -39.9 * scaleY))
        path.addCurve(
            to: CGPoint(x: 269.0 * scaleX, y: -57.2 * scaleY),
            control1: CGPoint(x: 292.1 * scaleX, y: -42.5 * scaleY),
            control2: CGPoint(x: 277.1 * scaleX, y: -50.7 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 237.5 * scaleX, y: -69.9 * scaleY),
            control1: CGPoint(x: 260.1 * scaleX, y: -62.1 * scaleY),
            control2: CGPoint(x: 247.1 * scaleX, y: -67.3 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 219.0 * scaleX, y: -73.4 * scaleY),
            control1: CGPoint(x: 233.1 * scaleX, y: -71.0 * scaleY),
            control2: CGPoint(x: 224.8 * scaleX, y: -72.6 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 185.5 * scaleX, y: -74.2 * scaleY),
            control1: CGPoint(x: 209.4 * scaleX, y: -74.7 * scaleY),
            control2: CGPoint(x: 192.9 * scaleX, y: -75.1 * scaleY)
        )
        path.closeSubpath()

        // Shift so viewBox origin aligns: the original paths use a 400x400 box
        // with content roughly centred. The coordinates above already map into rect.
        return path
    }
}

/// The checkmark shape of the Provii logo, rendered in a 400x400 coordinate space.
struct ProviiCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 400.0
        let scaleY = rect.height / 400.0

        var path = Path()
        path.move(to: CGPoint(x: 264.8 * scaleX, y: 116.0 * scaleY))
        path.addCurve(
            to: CGPoint(x: 200.4 * scaleX, y: 179.0 * scaleY),
            control1: CGPoint(x: 221.4 * scaleX, y: 159.9 * scaleY),
            control2: CGPoint(x: 201.9 * scaleX, y: 179.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 180.1 * scaleX, y: 160.5 * scaleY),
            control1: CGPoint(x: 199.0 * scaleX, y: 179.0 * scaleY),
            control2: CGPoint(x: 192.4 * scaleX, y: 173.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 160.2 * scaleX, y: 142.0 * scaleY),
            control1: CGPoint(x: 170.0 * scaleX, y: 150.2 * scaleY),
            control2: CGPoint(x: 161.2 * scaleX, y: 142.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 145.6 * scaleX, y: 154.9 * scaleY),
            control1: CGPoint(x: 159.2 * scaleX, y: 142.0 * scaleY),
            control2: CGPoint(x: 152.7 * scaleX, y: 147.8 * scaleY)
        )
        path.addLine(to: CGPoint(x: 132.8 * scaleX, y: 167.8 * scaleY))
        path.addLine(to: CGPoint(x: 133.8 * scaleX, y: 169.7 * scaleY))
        path.addCurve(
            to: CGPoint(x: 196.1 * scaleX, y: 233.6 * scaleY),
            control1: CGPoint(x: 135.3 * scaleX, y: 172.5 * scaleY),
            control2: CGPoint(x: 193.5 * scaleX, y: 232.1 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 201.5 * scaleX, y: 235.0 * scaleY),
            control1: CGPoint(x: 197.4 * scaleX, y: 234.3 * scaleY),
            control2: CGPoint(x: 199.9 * scaleX, y: 234.9 * scaleY)
        )
        path.addLine(to: CGPoint(x: 204.5 * scaleX, y: 235.0 * scaleY))
        path.addLine(to: CGPoint(x: 280.2 * scaleX, y: 158.8 * scaleY))
        path.addCurve(
            to: CGPoint(x: 355.9 * scaleX, y: 80.5 * scaleY),
            control1: CGPoint(x: 328.9 * scaleX, y: 109.7 * scaleY),
            control2: CGPoint(x: 355.9 * scaleX, y: 81.8 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 328.7 * scaleX, y: 53.0 * scaleY),
            control1: CGPoint(x: 355.9 * scaleX, y: 78.0 * scaleY),
            control2: CGPoint(x: 331.2 * scaleX, y: 53.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 264.8 * scaleX, y: 116.0 * scaleY),
            control1: CGPoint(x: 327.8 * scaleX, y: 53.0 * scaleY),
            control2: CGPoint(x: 299.0 * scaleX, y: 81.3 * scaleY)
        )
        path.closeSubpath()
        return path
    }
}

/// The right-side bowl shape of the Provii logo, rendered in a 400x400 coordinate space.
struct ProviiBowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 400.0
        let scaleY = rect.height / 400.0

        var path = Path()
        path.move(to: CGPoint(x: 315.4 * scaleX, y: 145.4 * scaleY))
        path.addLine(to: CGPoint(x: 293.0 * scaleX, y: 168.4 * scaleY))
        path.addLine(to: CGPoint(x: 293.0 * scaleX, y: 172.1 * scaleY))
        path.addCurve(
            to: CGPoint(x: 282.7 * scaleX, y: 213.5 * scaleY),
            control1: CGPoint(x: 293.0 * scaleX, y: 183.8 * scaleY),
            control2: CGPoint(x: 288.5 * scaleX, y: 202.1 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 233.0 * scaleX, y: 258.9 * scaleY),
            control1: CGPoint(x: 272.3 * scaleX, y: 234.2 * scaleY),
            control2: CGPoint(x: 254.2 * scaleX, y: 250.8 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 195.5 * scaleX, y: 264.7 * scaleY),
            control1: CGPoint(x: 221.0 * scaleX, y: 263.6 * scaleY),
            control2: CGPoint(x: 209.5 * scaleX, y: 265.3 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 177.0 * scaleX, y: 262.4 * scaleY),
            control1: CGPoint(x: 188.9 * scaleX, y: 264.4 * scaleY),
            control2: CGPoint(x: 180.6 * scaleX, y: 263.4 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 122.8 * scaleX, y: 227.1 * scaleY),
            control1: CGPoint(x: 156.9 * scaleX, y: 257.1 * scaleY),
            control2: CGPoint(x: 136.9 * scaleX, y: 244.1 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 118.1 * scaleX, y: 223.5 * scaleY),
            control1: CGPoint(x: 120.8 * scaleX, y: 224.8 * scaleY),
            control2: CGPoint(x: 118.7 * scaleX, y: 223.1 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 117.0 * scaleX, y: 259.0 * scaleY),
            control1: CGPoint(x: 117.3 * scaleX, y: 223.9 * scaleY),
            control2: CGPoint(x: 116.9 * scaleX, y: 235.3 * scaleY)
        )
        path.addLine(to: CGPoint(x: 117.0 * scaleX, y: 293.9 * scaleY))
        path.addLine(to: CGPoint(x: 119.2 * scaleX, y: 296.4 * scaleY))
        path.addCurve(
            to: CGPoint(x: 144.7 * scaleX, y: 310.6 * scaleY),
            control1: CGPoint(x: 122.1 * scaleX, y: 299.6 * scaleY),
            control2: CGPoint(x: 133.4 * scaleX, y: 305.9 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 211.9 * scaleX, y: 321.0 * scaleY),
            control1: CGPoint(x: 164.9 * scaleX, y: 319.0 * scaleY),
            control2: CGPoint(x: 190.8 * scaleX, y: 323.0 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 264.5 * scaleX, y: 306.4 * scaleY),
            control1: CGPoint(x: 232.2 * scaleX, y: 319.1 * scaleY),
            control2: CGPoint(x: 247.2 * scaleX, y: 314.9 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 302.7 * scaleX, y: 279.1 * scaleY),
            control1: CGPoint(x: 278.4 * scaleX, y: 299.6 * scaleY),
            control2: CGPoint(x: 291.0 * scaleX, y: 290.6 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 346.5 * scaleX, y: 194.0 * scaleY),
            control1: CGPoint(x: 327.2 * scaleX, y: 254.9 * scaleY),
            control2: CGPoint(x: 341.4 * scaleX, y: 227.4 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 346.4 * scaleX, y: 149.9 * scaleY),
            control1: CGPoint(x: 348.5 * scaleX, y: 181.5 * scaleY),
            control2: CGPoint(x: 348.4 * scaleX, y: 161.7 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 338.8 * scaleX, y: 123.5 * scaleY),
            control1: CGPoint(x: 344.7 * scaleX, y: 139.9 * scaleY),
            control2: CGPoint(x: 340.5 * scaleX, y: 125.2 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 315.4 * scaleX, y: 145.4 * scaleY),
            control1: CGPoint(x: 338.2 * scaleX, y: 122.8 * scaleY),
            control2: CGPoint(x: 330.3 * scaleX, y: 130.3 * scaleY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Animated Trim Modifier

/// A shape that wraps another shape and applies a trim effect for the drawing animation.
struct TrimmedShape<S: Shape>: Shape {
    let shape: S
    var trimEnd: CGFloat

    var animatableData: CGFloat {
        get { trimEnd }
        set { trimEnd = newValue }
    }

    func path(in rect: CGRect) -> Path {
        shape.path(in: rect).trimmedPath(from: 0, to: trimEnd)
    }
}

// MARK: - Provii Splash View

/// Animated splash screen that plays on every cold start. Draws the Provii logo outline
/// via stroke-dasharray animation, then cross-fades to the filled version.
///
/// Accessibility: When Reduce Motion is enabled, shows the static filled logo for 0.5 seconds
/// instead of playing the animation. Posts a screen-changed notification on completion so
/// VoiceOver focus moves to the next screen.
struct ProviiSplashView: View {
    let onComplete: () -> Void

    // Background colour matching the near-black splash
    private let bgColor = Color(red: 10.0/255.0, green: 10.0/255.0, blue: 15.0/255.0)

    // Logo colours (navy lightened from #1E3650 to #2E527A for 3:1 contrast against bg)
    private let navyColor = Color(red: 46.0/255.0, green: 82.0/255.0, blue: 122.0/255.0)
    private let tealColor = Color(red: 13.0/255.0, green: 148.0/255.0, blue: 136.0/255.0)

    // Animation state
    @State private var pBodyTrim: CGFloat = 0
    @State private var bowlTrim: CGFloat = 0
    @State private var checkmarkTrim: CGFloat = 0
    @State private var showFill: Bool = false
    @State private var showStroke: Bool = true
    @State private var hasCompleted: Bool = false

    var body: some View {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        GeometryReader { geometry in
            let logoSize = min(geometry.size.width, geometry.size.height) * 0.68

            ZStack {
                bgColor.ignoresSafeArea()

                ZStack {
                    // Stroke outlines (hidden when fill fades in)
                    if showStroke {
                        TrimmedShape(shape: ProviiPBodyShape(), trimEnd: pBodyTrim)
                            .stroke(navyColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .opacity(showFill ? 0 : 1)

                        TrimmedShape(shape: ProviiBowlShape(), trimEnd: bowlTrim)
                            .stroke(navyColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .opacity(showFill ? 0 : 1)

                        TrimmedShape(shape: ProviiCheckmarkShape(), trimEnd: checkmarkTrim)
                            .stroke(tealColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .opacity(showFill ? 0 : 1)
                    }

                    // Filled versions
                    if showFill {
                        ProviiPBodyShape()
                            .fill(navyColor)
                            .opacity(showFill ? 1 : 0)

                        ProviiBowlShape()
                            .fill(navyColor)
                            .opacity(showFill ? 1 : 0)

                        ProviiCheckmarkShape()
                            .fill(tealColor)
                            .opacity(showFill ? 1 : 0)
                    }
                }
                .frame(width: logoSize, height: logoSize)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .accessibilityLabel("Provii")
        .accessibilityAddTraits(.isImage)
        .onTapGesture {
            completeAnimation()
        }
        .onAppear {
            guard !hasCompleted else { return }

            if reduceMotion {
                // Reduced motion: show filled logo immediately for 0.5s
                showStroke = false
                showFill = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completeAnimation()
                }
            } else {
                runAnimation()
            }
        }
    }

    private func runAnimation() {
        // Phase 1: P body outline draws (0-1.0s)
        withAnimation(
            .timingCurve(0.4, 0, 0.2, 1, duration: 1.0)
        ) {
            pBodyTrim = 1.0
        }

        // Phase 2: Bowl outline draws (0.5-1.1s, overlapping with P body)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(
                .timingCurve(0.4, 0, 0.2, 1, duration: 0.6)
            ) {
                bowlTrim = 1.0
            }
        }

        // Phase 3: Checkmark outline draws (1.2-1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(
                .timingCurve(0.2, 0, 0.1, 1, duration: 0.4)
            ) {
                checkmarkTrim = 1.0
            }
        }

        // Haptic feedback + chime when checkmark completes drawing (respects user settings)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            let settings = AccessibilityManager.shared.settings
            if settings.hapticFeedback {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if settings.soundEnabled, settings.soundPreset.hasAudio, settings.soundVolume > 0 {
                let volume = Double(settings.soundVolume) / 100.0
                VerificationSoundManager.shared.playPreset(settings.soundPreset, volume: volume)
            }
        }

        // Phase 4: Fill fades in, stroke fades out (1.7-1.95s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showFill = true
            }
        }

        // Phase 5: Animation complete at 2.0s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completeAnimation()
        }
    }

    private func completeAnimation() {
        guard !hasCompleted else { return }
        hasCompleted = true

        // Post screen-changed notification so VoiceOver focus moves to the next screen
        UIAccessibility.post(notification: .screenChanged, argument: nil)

        onComplete()
    }
}
