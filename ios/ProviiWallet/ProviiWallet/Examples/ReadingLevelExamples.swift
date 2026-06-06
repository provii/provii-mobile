// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

// Demonstrates usage of the ReadingLevelText component for providing standard and
// simplified text variants throughout the wallet app. Each example shows a different
// context where reading level awareness applies: buttons, settings rows, alerts,
// status cards, onboarding steps, form fields, error messages, and help text.

// MARK: - Example 1: Simple Button with Reading Level Text

struct SimplifiedButtonExample: View {
    var body: some View {
        Button(action: {
            // Action
        }, label: {
            // Using ReadingLevelText component
            ReadingLevelText(
                "Configure Notification Preferences",
                simplified: "Set Up Alerts"
            )
            .font(.headline)
        })
    }
}

// MARK: - Example 2: Settings Row with Reading Level

struct SettingsRowExample: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title uses reading level
            ReadingLevelText(
                "Delete Credential",
                simplified: "Remove ID Card"
            )
            .font(.headline)

            // Description also uses reading level
            ReadingLevelText(
                "Remove current credential from your wallet",
                simplified: "Delete your ID from the app"
            )
            .font(.caption)
            .foregroundColor(AccessibleColors.secondaryText)
        }
    }
}

// MARK: - Example 3: Alert Message with Reading Level

struct AlertExample: View {
    @State private var showAlert = false
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        Button("Show Alert") {
            showAlert = true
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(
                    accessibilityManager.settings.readingLevel == .simplified
                        ? "Do you want to delete your ID card?"
                        : "Are you sure you want to delete your credential?"
                ),
                message: Text(
                    accessibilityManager.settings.readingLevel == .simplified
                        ? "Your ID will be removed from the app. You'll need to visit a government office to get a new one."
                        : "This will permanently remove your credential. You'll need to get a new one from an issuer to use the app again."
                ),
                primaryButton: .destructive(Text(
                    accessibilityManager.settings.readingLevel == .simplified
                        ? "Delete"
                        : "Delete Credential"
                )),
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Example 4: Status Card with Reading Level

struct StatusCardExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            ReadingLevelText(
                "Credential Active",
                simplified: "ID Card Ready"
            )
            .font(.title2)
            .fontWeight(.bold)

            // Message
            ReadingLevelText(
                "Your credential is ready for age verification",
                simplified: "Your ID card is ready to use"
            )
            .font(.body)
            .foregroundColor(AccessibleColors.secondaryText)

            // Action Button
            Button(action: {}, label: {
                ReadingLevelText(
                    "Verify Your Age",
                    simplified: "Show Your ID"
                )
                .font(.headline)
            })
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Example 5: Onboarding Step with Reading Level

struct OnboardingStepExample: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            // Title
            ReadingLevelText(
                "Privacy Protected",
                simplified: "Your Info is Safe"
            )
            .font(.title)
            .fontWeight(.bold)

            // Description
            ReadingLevelText(
                "Your date of birth is stored securely on your device and never transmitted to verifiers.",
                simplified: "Your birthday stays on your phone. Nobody else can see it."
            )
            .font(.body)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            // Action
            Button(action: {}, label: {
                ReadingLevelText(
                    "Continue",
                    simplified: "Next"
                )
            })
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Example 6: Using String Extension for Inline Text

struct InlineTextExample: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(accessibilityManager.settings.text(
                standard: "Scan QR Code",
                simplified: "Scan Code"
            ))
            .font(.headline)

            Text(accessibilityManager.settings.text(
                standard: "Point your camera at the QR code to begin verification",
                simplified: "Point camera at the square code"
            ))
            .font(.caption)
            .foregroundColor(AccessibleColors.secondaryText)
        }
    }
}

// MARK: - Example 7: Form Field with Reading Level Labels

struct FormFieldExample: View {
    @State private var dateOfBirth = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            ReadingLevelText(
                "Enter Date of Birth",
                simplified: "Enter Birthday"
            )
            .font(.headline)

            DatePicker(
                selection: $dateOfBirth,
                displayedComponents: [.date]
            ) {
                ReadingLevelText(
                    "Date of Birth",
                    simplified: "Birthday"
                )
            }
        }
        .padding()
    }
}

// MARK: - Example 8: Error Message with Reading Level

struct ErrorMessageExample: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                ReadingLevelText(
                    "Verification Failed",
                    simplified: "Check Failed"
                )
                .font(.headline)

                ReadingLevelText(
                    "Unable to complete the verification request. Please try again.",
                    simplified: "Couldn't check your age. Try again."
                )
                .font(.caption)
                .foregroundColor(AccessibleColors.secondaryText)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Example 9: Navigation Title with Reading Level

struct NavigationExample: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        NavigationView {
            List {
                Text("Content here")
            }
            .navigationTitle(
                accessibilityManager.settings.readingLevel == .simplified
                    ? "Easy Access Settings"
                    : "Accessibility Settings"
            )
        }
    }
}

// MARK: - Example 10: Help Text with Reading Level

struct HelpTextExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)

                ReadingLevelText(
                    "What is a Zero Knowledge Proof?",
                    simplified: "What is a Private Age Proof?"
                )
                .font(.headline)
            }

            ReadingLevelText(
                "Zero Knowledge Proofs allow you to prove something is true without revealing the underlying information. For example, you can prove you're over 18 without showing your exact date of birth.",
                simplified: "This lets you prove your age without showing your birthday. The website knows you're old enough, but doesn't see when you were born."
            )
            .font(.body)
            .foregroundColor(AccessibleColors.secondaryText)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Example 11: Using LocalizedContent Dictionary

struct LocalizedContentExample: View {
    var body: some View {
        VStack(spacing: 16) {
            // Example of using localized content
            Text(NSLocalizedString("scan_qr_code", comment: "Scan QR Code"))
                .font(.headline)

            Text(NSLocalizedString("scan_qr_instructions", comment: "QR Scan Instructions"))
                .font(.caption)

            Button(action: {}, label: {
                Text(NSLocalizedString("enter_code_manually", comment: "Enter Code Manually"))
                    .font(.body)
            })
        }
    }
}

// MARK: - Best Practices Documentation

/*
 BEST PRACTICES FOR READING LEVEL IMPLEMENTATION:

 1. Always provide both standard and simplified versions
    - Standard: Technical terms, complete sentences, passive voice OK
    - Simplified: Simple words, active voice, short sentences (Grade 7-9)

 2. Use the ReadingLevelText component for static text
    - Automatically switches based on user preference
    - Works with all SwiftUI text modifiers

 3. Use the String extension for dynamic/computed text
    - accessibilityManager.settings.text(standard:simplified:)
    - Good for conditional logic and string interpolation

 4. Add entries to LocalizedContent.swift for reusable strings
    - Provides centralised management
    - Ensures consistency across app
    - Makes localisation easier

 5. Simplified text guidelines:
    - Replace technical jargon: "credential" → "ID card"
    - Use common words: "authenticate" → "sign in"
    - Active voice: "Your ID is ready" vs "The ID has been prepared"
    - Short sentences: Break complex ideas into multiple sentences
    - Concrete examples: "like a government office" instead of "authorised issuer"

 6. Don't over-simplify:
    - Keep meaning accurate
    - Don't patronize users
    - Maintain professional tone
    - Complex ideas may need simple explanation, not dumbing down

 7. Test with actual users:
    - Grade 7-9 reading level is target
    - Use readability tools to verify
    - Get feedback from users with cognitive disabilities

 8. Accessibility labels should also respect reading level:
    - Screen reader users benefit from simplified language too
    - Use same simplified text for .accessibilityLabel when appropriate

 9. Consider context:
    - Error messages: Always use simple, clear language
    - Technical settings: Can use more technical terms with good descriptions
    - Onboarding: Should lean toward simpler language by default
    - Legal/security: Balance simplicity with accuracy

 10. Localisation considerations:
     - Simplified text may translate differently than standard text
     - Work with translators who understand accessibility
     - Some languages have formal/informal registers that may help
 */
