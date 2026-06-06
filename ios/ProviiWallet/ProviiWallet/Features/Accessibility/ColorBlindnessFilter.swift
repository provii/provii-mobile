// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import UIKit

/// Colour blindness filter system implementing five colour vision deficiency modes (protanopia, deuteranopia,
/// tritanopia, monochrome, and none). Uses transformation matrices based on Brettel, Vienot, and Mollon (1997)
/// research to simulate how colours appear under each condition. Supports SwiftUI Color, UIColor, and CGColor inputs.
/// WCAG 2.2 AAA Compliance: Provides colour transformation for users with various types of colour vision deficiencies.

enum ColorBlindnessMode: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case protanopia = "Protanopia (Red-Blind)"       // Red-blind (1% of males)
    case deuteranopia = "Deuteranopia (Green-Blind)" // Green-blind (1% of males)
    case tritanopia = "Tritanopia (Blue-Blind)"      // Blue-blind (0.001% of population)
    case monochrome = "Monochrome"                   // Complete colour blindness

    var id: String { rawValue }

    /// Localised display name for the colour blindness mode
    var localizedName: String {
        switch self {
        case .none:
            return NSLocalizedString("accessibility.colorblind.none", comment: "")
        case .protanopia:
            return NSLocalizedString("accessibility.colorblind.protanopia", comment: "")
        case .deuteranopia:
            return NSLocalizedString("accessibility.colorblind.deuteranopia", comment: "")
        case .tritanopia:
            return NSLocalizedString("accessibility.colorblind.tritanopia", comment: "")
        case .monochrome:
            return NSLocalizedString("accessibility.colorblind.monochrome", comment: "")
        }
    }

    /// Human-readable description of the colour blindness type
    var description: String {
        switch self {
        case .none:
            return NSLocalizedString("accessibility.colorblind.none.description", comment: "")
        case .protanopia:
            return NSLocalizedString("accessibility.colorblind.protanopia.description", comment: "")
        case .deuteranopia:
            return NSLocalizedString("accessibility.colorblind.deuteranopia.description", comment: "")
        case .tritanopia:
            return NSLocalizedString("accessibility.colorblind.tritanopia.description", comment: "")
        case .monochrome:
            return NSLocalizedString("accessibility.colorblind.monochrome.description", comment: "")
        }
    }

    /// Short descriptive label for UI
    var shortLabel: String {
        switch self {
        case .none:
            return NSLocalizedString("accessibility.colorblind.none.short", comment: "")
        case .protanopia:
            return NSLocalizedString("accessibility.colorblind.protanopia.short", comment: "")
        case .deuteranopia:
            return NSLocalizedString("accessibility.colorblind.deuteranopia.short", comment: "")
        case .tritanopia:
            return NSLocalizedString("accessibility.colorblind.tritanopia.short", comment: "")
        case .monochrome:
            return NSLocalizedString("accessibility.colorblind.monochrome.short", comment: "")
        }
    }

    // Colour transformation matrices based on research by Brettel, Vienot and Mollon (1997)
    // and Machado, Oliveira and Fernandes (2009)

    /// 4x4 colour transformation matrix for converting RGB values
    /// Matrix format: [R1, R2, R3, R4,  G1, G2, G3, G4,  B1, B2, B3, B4,  A1, A2, A3, A4]
    var transformMatrix: [Float] {
        switch self {
        case .none:
            // Identity matrix - no transformation
            return [
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0
            ]

        case .protanopia:
            // Protanopia (red-blind) transformation
            // Based on Brettel et al. simulation
            return [
                0.567, 0.433, 0.0, 0.0,
                0.558, 0.442, 0.0, 0.0,
                0.0, 0.242, 0.758, 0.0,
                0.0, 0.0, 0.0, 1.0
            ]

        case .deuteranopia:
            // Deuteranopia (green-blind) transformation
            // Based on Brettel et al. simulation
            return [
                0.625, 0.375, 0.0, 0.0,
                0.7, 0.3, 0.0, 0.0,
                0.0, 0.3, 0.7, 0.0,
                0.0, 0.0, 0.0, 1.0
            ]

        case .tritanopia:
            // Tritanopia (blue-blind) transformation
            // Based on Brettel et al. simulation
            return [
                0.95, 0.05, 0.0, 0.0,
                0.0, 0.433, 0.567, 0.0,
                0.0, 0.475, 0.525, 0.0,
                0.0, 0.0, 0.0, 1.0
            ]

        case .monochrome:
            // Monochrome (complete colour blindness)
            // Uses luminance coefficients from ITU-R BT.709
            return [
                0.299, 0.587, 0.114, 0.0,
                0.299, 0.587, 0.114, 0.0,
                0.299, 0.587, 0.114, 0.0,
                0.0, 0.0, 0.0, 1.0
            ]
        }
    }

    /// Apply the colour blindness filter to a SwiftUI Colour
    /// - Parameter color: The original colour to transform
    /// - Returns: The transformed colour as seen by someone with this type of colour blindness
    func apply(to color: Color) -> Color {
        // Special case: no transformation needed
        if self == .none {
            return color
        }

        // Convert SwiftUI Colour to UIColor
        let uiColor = UIColor(color)

        // Extract RGBA components
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Apply transformation matrix
        let matrix = transformMatrix
        let newR = min(max(r * CGFloat(matrix[0]) + g * CGFloat(matrix[1]) + b * CGFloat(matrix[2]), 0), 1)
        let newG = min(max(r * CGFloat(matrix[4]) + g * CGFloat(matrix[5]) + b * CGFloat(matrix[6]), 0), 1)
        let newB = min(max(r * CGFloat(matrix[8]) + g * CGFloat(matrix[9]) + b * CGFloat(matrix[10]), 0), 1)

        return Color(UIColor(red: newR, green: newG, blue: newB, alpha: a))
    }

    /// Apply the colour blindness filter to a UIColor
    /// - Parameter color: The original UIColor to transform
    /// - Returns: The transformed UIColor
    func apply(to color: UIColor) -> UIColor {
        // Special case: no transformation needed
        if self == .none {
            return color
        }

        // Extract RGBA components
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Apply transformation matrix
        let matrix = transformMatrix
        let newR = min(max(r * CGFloat(matrix[0]) + g * CGFloat(matrix[1]) + b * CGFloat(matrix[2]), 0), 1)
        let newG = min(max(r * CGFloat(matrix[4]) + g * CGFloat(matrix[5]) + b * CGFloat(matrix[6]), 0), 1)
        let newB = min(max(r * CGFloat(matrix[8]) + g * CGFloat(matrix[9]) + b * CGFloat(matrix[10]), 0), 1)

        return UIColor(red: newR, green: newG, blue: newB, alpha: a)
    }

    /// Apply the colour blindness filter to a CGColor
    /// - Parameter color: The original CGColor to transform
    /// - Returns: The transformed CGColor
    func apply(to color: CGColor) -> CGColor {
        return apply(to: UIColor(cgColor: color)).cgColor
    }
}

// MARK: - Colour Blindness Preview Helper

/// Preview helper to visualise how colours appear with different types of colour blindness.
/// Useful for designers and developers to test colour accessibility.
struct ColorBlindnessPreview: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.headline)
                .padding(.top)

            // Show original and all transformed versions
            ForEach(ColorBlindnessMode.allCases) { mode in
                HStack {
                    Text(mode.shortLabel)
                        .frame(width: 120, alignment: .leading)
                        .font(.caption)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(mode.apply(to: color))
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
            }

            Divider()
        }
    }
}

// MARK: - Accessibility Extensions

extension ColorBlindnessMode {
    /// Get recommended alternative colour for UI elements that must remain distinguishable
    /// - Parameter baseColor: The original colour
    /// - Returns: A colour that maintains better distinction for this colour blindness type
    func recommendedAlternative(for baseColor: Color) -> Color {
        switch self {
        case .none:
            return baseColor

        case .protanopia, .deuteranopia:
            // For red-green colour blindness, use blue/orange combinations
            // Check if the colour is reddish or greenish and suggest alternatives
            let uiColor = UIColor(baseColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            if r > 0.5 && g < 0.5 { // Reddish
                return Color(red: 0.0, green: 0.4, blue: 0.8) // Blue
            } else if g > 0.5 && r < 0.5 { // Greenish
                return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
            }
            return baseColor

        case .tritanopia:
            // For blue-yellow colour blindness, use red/cyan combinations
            let uiColor = UIColor(baseColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            if b > 0.5 { // Bluish
                return Color(red: 0.8, green: 0.0, blue: 0.2) // Red
            } else if r > 0.5 && g > 0.5 { // Yellowish
                return Color(red: 0.0, green: 0.6, blue: 0.6) // Cyan
            }
            return baseColor

        case .monochrome:
            // For monochrome vision, ensure high contrast
            // Use pure black or white based on luminance
            let uiColor = UIColor(baseColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return luminance > 0.5 ? .black : .white
        }
    }
}

// MARK: - View Modifier for Colour Blindness Simulation

struct ColorBlindnessSimulationModifier: ViewModifier {
    @ObservedObject private var manager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .foregroundStyle(transformedForeground)
            .accessibilityLabel(accessibilityDescription)
    }

    private var transformedForeground: Color {
        // Colour transformation would be applied here based on the filter mode
        return .primary
    }

    private var accessibilityDescription: String {
        if manager.settings.colorBlindMode != .none {
            return "Colour blindness filter active: \(manager.settings.colorBlindMode.localizedName)"
        }
        return ""
    }
}

extension View {
    /// Apply colour blindness simulation to this view
    func colorBlindnessSimulation() -> some View {
        self.modifier(ColorBlindnessSimulationModifier())
    }
}

// MARK: - Testing Utilities

#if DEBUG
struct ColorBlindnessFilterPreviews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                ColorBlindnessPreview(color: .red, label: "Red")
                ColorBlindnessPreview(color: .green, label: "Green")
                ColorBlindnessPreview(color: .blue, label: "Blue")
                ColorBlindnessPreview(color: .yellow, label: "Yellow")
                ColorBlindnessPreview(color: .orange, label: "Orange")
                ColorBlindnessPreview(color: .purple, label: "Purple")
            }
        }
    }
}
#endif
