// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import AVFoundation
import Combine
import UIKit

/// Manages verification success sound playback using runtime audio synthesis via AVAudioSourceNode.
/// Follows the singleton pattern established by HapticFeedback. Respects the device silent mode by using
/// the ambient audio category, and handles audio session interruptions and route changes gracefully.
@MainActor
final class VerificationSoundManager: ObservableObject {

    // MARK: - Singleton

    static let shared = VerificationSoundManager()

    // MARK: - Published Properties

    @Published private(set) var isPlaying = false

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var mixerNode: AVAudioMixerNode?

    private let toneGenerator = ToneGenerator()
    private var currentFrame: Int = 0
    private var activeTones: [ToneGenerator.ToneParameters] = []
    private var totalFrames: Int = 0
    private var mainVolume: Double = 1.0
    private let lock = NSLock()

    private var cancellables = Set<AnyCancellable>()
    private var stopTask: Task<Void, Never>?

    // MARK: - Initialisation

    private init() {
        setupNotifications()
    }

    // MARK: - Public API

    /// Play verification success sound using current accessibility settings.
    /// Respects sound enabled state, preset, and volume from settings.
    /// Also triggers haptic feedback if enabled.
    func playVerificationSuccess() {
        let settings = AccessibilityManager.shared.settings

        // Always trigger haptic if enabled (even for silent preset)
        if settings.hapticFeedback {
            HapticFeedback.notification(.success)
        }

        // Check if sound should play
        guard settings.soundEnabled else { return }
        guard settings.soundPreset.hasAudio else { return }
        guard settings.soundVolume > 0 else { return }

        let volume = Double(settings.soundVolume) / 100.0
        playPreset(settings.soundPreset, volume: volume)
    }

    /// Play a specific preset at a specific volume (for settings preview).
    /// - Parameters:
    ///   - preset: The sound preset to play
    ///   - volume: Volume level (0.0 - 1.0)
    func playPreset(_ preset: SoundPreset, volume: Double) {
        guard preset.hasAudio else { return }

        Task { @MainActor in
            do {
                // Stop any currently playing sound
                stop()

                try setupAudioEngineIfNeeded()
                try configureAudioSession()

                preparePlayback(preset: preset, volume: volume)

                try startEngine()

                // Schedule automatic stop after playback completes
                scheduleStop(afterMs: preset.totalDurationMs + 100)

            } catch {
                SecureLogger.shared.error("VerificationSoundManager: Failed to play sound - \(error.localizedDescription)")
                cleanup()
            }
        }
    }

    /// Preview a sound preset (convenience method for settings UI).
    /// - Parameters:
    ///   - preset: The preset to preview
    ///   - volume: Volume level (0-100)
    func previewSound(preset: SoundPreset, volume: Int) {
        playPreset(preset, volume: Double(volume) / 100.0)
    }

    /// Stop any currently playing sound.
    func stop() {
        stopTask?.cancel()
        stopTask = nil
        stopEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngineIfNeeded() throws {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()

        engine.attach(mixer)

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: ToneGenerator.sampleRate,
            channels: 1
        ) else {
            throw AudioError.formatCreationFailed
        }

        // Create source node for real-time synthesis
        let source = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            self.lock.lock()
            let tones = self.activeTones
            let startFrame = self.currentFrame
            let volume = self.mainVolume
            let total = self.totalFrames
            self.lock.unlock()

            // Only generate if we have tones and haven't exceeded duration
            if !tones.isEmpty && startFrame < total {
                self.toneGenerator.generateSamples(
                    tones: tones,
                    into: buffer,
                    frameCount: Int(frameCount),
                    startFrame: startFrame,
                    mainVolume: volume
                )
            } else {
                // Fill with silence
                memset(buffer, 0, Int(frameCount) * MemoryLayout<Float>.size)
            }

            self.lock.lock()
            self.currentFrame += Int(frameCount)
            self.lock.unlock()

            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        self.audioEngine = engine
        self.mixerNode = mixer
        self.sourceNode = source
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        do {
            // Use ambient category to respect silent mode and mix with other audio
            try session.setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            throw AudioError.sessionConfigurationFailed(error)
        }
    }

    private func preparePlayback(preset: SoundPreset, volume: Double) {
        lock.lock()
        defer { lock.unlock() }

        currentFrame = 0
        mainVolume = volume
        activeTones = ToneGenerator.toneParameters(from: preset)
        totalFrames = ToneGenerator.totalSamples(for: preset)
        toneGenerator.reset()
    }

    private func startEngine() throws {
        guard let engine = audioEngine else {
            throw AudioError.engineNotInitialized
        }

        guard !engine.isRunning else { return }

        try engine.start()
        isPlaying = true
    }

    private func stopEngine() {
        lock.lock()
        activeTones.removeAll()
        currentFrame = 0
        totalFrames = 0
        lock.unlock()

        audioEngine?.stop()
        toneGenerator.reset()
        isPlaying = false
    }

    private func scheduleStop(afterMs: Double) {
        stopTask?.cancel()
        stopTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(afterMs * 1_000_000))
            guard !Task.isCancelled else { return }
            self.stop()
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            stop()
        case .ended:
            // Engine will restart on next play
            break
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            stop()
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        stop()

        if let source = sourceNode {
            audioEngine?.detach(source)
        }
        if let mixer = mixerNode {
            audioEngine?.detach(mixer)
        }

        sourceNode = nil
        mixerNode = nil
        audioEngine = nil
    }

    // Note: deinit removed as this is a singleton that will never be deallocated.
    // Attempting to call cleanup() from deinit causes MainActor isolation errors.
}

// MARK: - Errors

extension VerificationSoundManager {
    enum AudioError: LocalizedError {
        case formatCreationFailed
        case engineNotInitialized
        case sessionConfigurationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .formatCreationFailed:
                return LocalizedString.errorAudioFormatFailed.localized
            case .engineNotInitialized:
                return LocalizedString.errorAudioEngineNotInit.localized
            case .sessionConfigurationFailed(let error):
                return String(format: NSLocalizedString("error_audio_session_config", comment: "Audio session config error"), error.localizedDescription)
            }
        }
    }
}
