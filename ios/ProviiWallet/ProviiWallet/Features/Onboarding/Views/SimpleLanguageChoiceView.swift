// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

/// Onboarding language choice screen with a rotating multilingual button that cycles
/// through greetings in different scripts. Lets the user continue in English or open
/// the full language selection view. Respects the reduce-motion accessibility preference
/// by disabling the rotation animation when active.
struct SimpleLanguageChoiceView: View {
    let onUseEnglish: () -> Void
    let onChangeLanguage: () -> Void

    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var currentLanguageIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Australian languages by population (matching Android)
    private let rotatingLanguages: [(text: String, language: String)] = [
        ("换语言", "Mandarin"),
        ("غيّر اللغة", "Arabic"),
        ("Đổi ngôn ngữ", "Vietnamese"),
        ("ਭਾਸ਼ਾ ਬਦਲੋ", "Punjabi"),
        ("Αλλαγή γλώσσας", "Greek"),
        ("Cambia lingua", "Italian"),
        ("भाषा बदलें", "Hindi"),
        ("Cambiar idioma", "Spanish"),
        ("언어 변경", "Korean"),
        ("மொழியை மாற்று", "Tamil")
    ]

    // Timer for rotation - 2.5 seconds per language (0.4Hz, well under WCAG 3Hz limit)
    private let rotationTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.proviiBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Welcome header
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.proviiPrimary)
                        .accessibilityHidden(true)

                    Text(NSLocalizedString("onboarding_welcome", comment: "Welcome to Provii Wallet"))
                        .font(ProviiTypography.headlineLarge)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(NSLocalizedString("onboarding_language_subtitle", comment: "Choose your language"))
                        .font(ProviiTypography.bodyLarge)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    // Primary: Use English
                    Button(action: onUseEnglish) {
                        Text(NSLocalizedString("onboarding_use_english", comment: "Use English"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProviiPrimaryButtonStyle())
                    .accessibilityHint(NSLocalizedString("onboarding_use_english_hint", comment: "Continue with English language"))

                    if LanguageSettings.LanguageInfo.hasMultipleLanguages {
                        // Secondary: Change Language (static English)
                        Button(action: onChangeLanguage) {
                            Text(NSLocalizedString("onboarding_change_language", comment: "Change Language"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ProviiSecondaryButtonStyle())
                        .accessibilityHint(NSLocalizedString("onboarding_change_language_hint", comment: "Open language selection"))

                        // Rotating multilingual button
                        Button(action: onChangeLanguage) {
                            rotatingButtonContent
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ProviiSecondaryButtonStyle())
                        .accessibilityLabel(currentAccessibilityLabel)
                        .accessibilityHint(NSLocalizedString("onboarding_change_language_hint", comment: "Open language selection"))
                    }
                }
                .padding(.horizontal, 24)

                if LanguageSettings.LanguageInfo.hasMultipleLanguages {
                    // Footer
                    Text(NSLocalizedString("onboarding_change_later", comment: "You can change this later in Settings"))
                        .font(ProviiTypography.bodySmall)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .onReceive(rotationTimer) { _ in
            if !reduceMotion && !accessibilityManager.settings.reduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentLanguageIndex = (currentLanguageIndex + 1) % rotatingLanguages.count
                }
            }
        }
    }

    // MARK: - Rotating Button Content

    @ViewBuilder
    private var rotatingButtonContent: some View {
        let shouldAnimate = !reduceMotion && !accessibilityManager.settings.reduceMotion

        if shouldAnimate {
            // Animated version
            Text(rotatingLanguages[currentLanguageIndex].text)
                .id(currentLanguageIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
        } else {
            // Static version for reduce motion
            Text(NSLocalizedString("onboarding_change_language", comment: "Change Language"))
        }
    }

    // MARK: - Accessibility

    private var currentAccessibilityLabel: String {
        let current = rotatingLanguages[currentLanguageIndex]
        return String(format: NSLocalizedString("onboarding_change_language_rotating_label", comment: "Change Language - showing %@ translation"), current.language)
    }
}

// MARK: - Preview

#Preview {
    SimpleLanguageChoiceView(
        onUseEnglish: { print("Use English") },
        onChangeLanguage: { print("Change Language") }
    )
}
