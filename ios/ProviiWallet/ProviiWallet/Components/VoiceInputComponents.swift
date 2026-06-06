// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

// MARK: - Voice Input Indicator

/// Pulsing microphone indicator that provides clear visual feedback when voice
/// recognition is actively listening. Respects reduced motion preferences and
/// announces state changes to assistive technologies per WCAG 4.1.2.
struct VoiceInputIndicator: View {
    let isListening: Bool
    var size: CGFloat = 48

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        ZStack {
            if isListening {
                // Outer pulsing ring
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)

                // Inner pulsing ring
                Circle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: size * 0.7, height: size * 0.7)
                    .scaleEffect(pulseScale * 0.9)
                    .opacity(pulseOpacity * 1.2)
            }

            // Microphone icon (always visible)
            ZStack {
                Circle()
                    .fill(isListening ? Color.red : Color.blue)
                    .frame(width: size * 0.5, height: size * 0.5)

                Image(systemName: "mic.fill")
                    .font(size > 150 ? AccessibleTypography.title : AccessibleTypography.headline)
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(isListening ? AccessibilityLabels.voiceInputListening : AccessibilityLabels.voiceInputAvailable)
        .onAppear {
            if isListening {
                startPulsing()
            }
        }
        .onChange(of: isListening) { newValue in
            if newValue {
                startPulsing()
                // WCAG 4.1.2: Announce state change to assistive technologies
                UIAccessibility.post(
                    notification: .announcement,
                    argument: NSLocalizedString("accessibility.voice.recording_started", comment: "Voice recording started announcement")
                )
            } else {
                // WCAG 4.1.2: Announce when recording stops
                UIAccessibility.post(
                    notification: .announcement,
                    argument: NSLocalizedString("accessibility.voice.recording_stopped", comment: "Voice recording stopped announcement")
                )
            }
        }
    }

    private func startPulsing() {
        let manager = AccessibilityManager.shared
        if manager.settings.reduceMotion {
            pulseScale = 1.3
            pulseOpacity = 0.7
        } else {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.3
                pulseOpacity = 0.7
            }
        }
    }
}

// MARK: - Voice Input Error

/// Error state indicator for voice input failures. Displays the error message
/// inside a tinted container with an icon for immediate visual recognition.
struct VoiceInputError: View {
    let errorMessage: String
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AccessibleColors.error)
                .font(AccessibleTypography.body)
                .accessibilityHidden(true)

            Text(errorMessage)
                .font(AccessibleTypography.body)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AccessibleColors.error.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AccessibleColors.error, lineWidth: accessibilityManager.settings.useHighContrast ? 2 : 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.voice_input.error.label", comment: "Voice input error label"), errorMessage))
    }
}

// MARK: - Enhanced Speech Recogniser

import Speech
import AVFoundation

/// Speech recogniser with error handling and detailed feedback. Maps common
/// SFSpeechRecognizer error codes to user-friendly localised messages and
/// announces state transitions for assistive technology users.
class EnhancedSpeechRecognizer: ObservableObject {
    @Published var recognizedText = ""
    @Published var isListening = false
    @Published var errorMessage: String?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()

    var onRecognizedCommand: ((String) -> Void)?

    func startListening() {
        clearError()

        guard let recognizer = speechRecognizer else {
            setError(NSLocalizedString("error.voice_input.not_available", comment: "Voice input not available error"))
            return
        }

        guard recognizer.isAvailable else {
            setError(NSLocalizedString("error.voice_input.temporarily_unavailable", comment: "Voice input temporarily unavailable error"))
            return
        }

        do {
            try startRecognition()
            isListening = true
        } catch {
            setError(mapError(error))
        }
    }

    func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        recognizedText = ""
    }

    func clearError() {
        errorMessage = nil
    }

    private func startRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw NSError(domain: "AudioSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio recording error. Check microphone."])
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString

                // Check for commands
                if result.isFinal {
                    self.onRecognizedCommand?(result.bestTranscription.formattedString)
                }
            }

            if let error = error {
                self.setError(self.mapError(error))
                self.stopListening()
            } else if result?.isFinal == true {
                self.stopListening()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func setError(_ message: String) {
        // MASVS CODE-1: Use [weak self] to prevent retain cycles in escaping closures
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.isListening = false
        }
    }

    private static let speechErrorCodes: [Int: String] = [
        1: "error.voice_input.audio_recording",
        2: "error.voice_input.network",
        3: "error.voice_input.no_speech",
        4: "error.voice_input.busy",
        5: "error.voice_input.server",
        203: "error.voice_input.permission_denied",
        216: "error.voice_input.timeout"
    ]

    private func mapError(_ error: Error) -> String {
        let nsError = error as NSError

        if let key = Self.speechErrorCodes[nsError.code] {
            return NSLocalizedString(key, comment: "")
        }
        return mapErrorByDescription(error)
    }

    private func mapErrorByDescription(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()
        if description.contains("audio") || description.contains("microphone") {
            return NSLocalizedString("error.voice_input.audio_recording", comment: "Audio recording error")
        } else if description.contains("network") || description.contains("connection") {
            return NSLocalizedString("error.voice_input.network", comment: "Network error")
        } else if description.contains("permission") {
            return NSLocalizedString("error.voice_input.permission_denied", comment: "Permission denied")
        } else if description.contains("timeout") {
            return NSLocalizedString("error.voice_input.timeout", comment: "Network timeout")
        }
        return NSLocalizedString("error.voice_input.generic", comment: "Generic voice input error")
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
}

#Preview("Voice Input Indicator - Idle") {
    VoiceInputIndicator(isListening: false, size: 56)
        .padding()
}

#Preview("Voice Input Indicator - Listening") {
    VoiceInputIndicator(isListening: true, size: 56)
        .padding()
}

#Preview("Voice Input Error") {
    VoiceInputError(errorMessage: "No speech detected. Please try again.")
        .environmentObject(AccessibilityManager.shared)
        .padding()
}
