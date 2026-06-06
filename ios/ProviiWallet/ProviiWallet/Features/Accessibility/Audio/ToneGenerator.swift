// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation
import AVFoundation

/// Low-level tone synthesis engine for generating verification sounds.
/// Uses sine wave synthesis with configurable harmonics (fundamental, chorus, octave, third harmonic)
/// and an ADSR envelope with exponential attack/release curves. Supports overlapping multi-tone
/// playback with soft clipping to prevent distortion at the output stage.
final class ToneGenerator {

    // MARK: - Constants

    static let sampleRate: Double = 44100.0

    // MARK: - Types

    /// Parameters for a single tone to be generated
    struct ToneParameters {
        let frequency: Double
        let startSample: Int
        let durationSamples: Int
        let volume: Double
        let envelope: SoundPreset.EnvelopeConfig
        let harmonics: SoundPreset.HarmonicConfig
    }

    // MARK: - Properties

    private var phaseAccumulators: [Double] = []
    private let lock = NSLock()

    // MARK: - Public API

    /// Generate samples for multiple tones into the provided buffer.
    /// - Parameters:
    ///   - tones: Array of tone parameters to generate
    ///   - buffer: Output buffer to fill
    ///   - frameCount: Number of frames to generate
    ///   - startFrame: Starting frame number in the overall sequence
    ///   - mainVolume: Main volume multiplier (0.0 - 1.0)
    func generateSamples(
        tones: [ToneParameters],
        into buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        startFrame: Int,
        mainVolume: Double
    ) {
        // Clear buffer
        memset(buffer, 0, frameCount * MemoryLayout<Float>.size)

        for tone in tones {
            generateTone(
                tone,
                into: buffer,
                frameCount: frameCount,
                startFrame: startFrame,
                mainVolume: mainVolume
            )
        }
    }

    /// Reset all phase accumulators
    func reset() {
        lock.lock()
        phaseAccumulators = []
        lock.unlock()
    }

    // MARK: - Private Methods

    private func generateTone(
        _ tone: ToneParameters,
        into buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        startFrame: Int,
        mainVolume: Double
    ) {
        let sampleRate = Self.sampleRate

        // Calculate all harmonic frequencies
        let frequencies = calculateHarmonicFrequencies(
            fundamental: tone.frequency,
            harmonics: tone.harmonics
        )

        let amplitudes = [
            tone.harmonics.fundamental,
            tone.harmonics.chorusPlus,
            tone.harmonics.chorusMinus,
            tone.harmonics.octaveBelow,
            tone.harmonics.octaveAbove,
            tone.harmonics.thirdHarmonic
        ]

        // Ensure phase accumulators exist for all harmonics
        lock.lock()
        while phaseAccumulators.count < frequencies.count {
            phaseAccumulators.append(0.0)
        }
        lock.unlock()

        // Phase increments per sample
        let phaseIncrements = frequencies.map { freq in
            2.0 * Double.pi * freq / sampleRate
        }

        // Normalise amplitude by sum of active harmonics
        let ampSum = amplitudes.reduce(0, +)
        let normFactor = ampSum > 0 ? 1.0 / ampSum : 1.0

        for frame in 0..<frameCount {
            let globalFrame = startFrame + frame
            let localFrame = globalFrame - tone.startSample

            // Skip if before tone start or after tone end
            guard localFrame >= 0 && localFrame < tone.durationSamples else {
                continue
            }

            let time = Double(localFrame) / sampleRate
            let envelopeAmp = calculateEnvelope(
                time: time,
                durationMs: Double(tone.durationSamples) / sampleRate * 1000.0,
                envelope: tone.envelope
            )

            var sample: Double = 0.0

            // Sum all harmonics
            lock.lock()
            for (i, (_, amplitude)) in zip(frequencies, amplitudes).enumerated() where amplitude > 0 {
                let phase = phaseAccumulators[i]
                sample += sin(phase) * amplitude

                phaseAccumulators[i] += phaseIncrements[i]
                // Wrap phase to prevent overflow
                if phaseAccumulators[i] > 2.0 * Double.pi {
                    phaseAccumulators[i] -= 2.0 * Double.pi
                }
            }
            lock.unlock()

            // Apply normalisation, envelope, volume
            sample *= normFactor * envelopeAmp * tone.volume * mainVolume

            // Soft clipping to prevent distortion
            sample = softClip(sample)

            // Add to buffer (accumulate for overlapping tones)
            buffer[frame] += Float(sample)
        }
    }

    /// Calculate frequencies for all harmonics
    private func calculateHarmonicFrequencies(
        fundamental: Double,
        harmonics: SoundPreset.HarmonicConfig
    ) -> [Double] {
        let centsRatio = pow(2.0, SoundPreset.HarmonicConfig.chorusDetuneCents / 1200.0)

        return [
            fundamental,                   // Fundamental
            fundamental * centsRatio,      // Chorus + (4 cents sharp)
            fundamental / centsRatio,      // Chorus - (4 cents flat)
            fundamental / 2.0,             // Octave below
            fundamental * 2.0,             // Octave above
            fundamental * 3.0              // Third harmonic
        ]
    }

    /// Calculate ADSR envelope amplitude at given time
    private func calculateEnvelope(
        time: Double,
        durationMs: Double,
        envelope: SoundPreset.EnvelopeConfig
    ) -> Double {
        let attackTime = envelope.attackMs / 1000.0
        let durationSec = durationMs / 1000.0
        let releaseStart = durationSec * (1.0 - envelope.releaseRatio)
        let releaseTime = durationSec * envelope.releaseRatio

        if time < attackTime {
            // Attack phase: exponential rise
            let progress = time / attackTime
            return exponentialRamp(progress)
        } else if time < releaseStart {
            // Sustain phase: gradual decay to sustain level
            let sustainProgress = (time - attackTime) / (releaseStart - attackTime)
            return 1.0 - (1.0 - envelope.sustainLevel) * sustainProgress
        } else {
            // Release phase: exponential decay
            let releaseProgress = min((time - releaseStart) / releaseTime, 1.0)
            return envelope.sustainLevel * (1.0 - exponentialRamp(releaseProgress))
        }
    }

    /// Exponential ramp function for smooth transitions
    /// Returns 0 at t=0, approaches 1 as t approaches 1
    private func exponentialRamp(_ t: Double) -> Double {
        return 1.0 - exp(-4.0 * t)
    }

    /// Soft clipping using tanh to prevent harsh distortion
    private func softClip(_ sample: Double) -> Double {
        return tanh(sample * 1.5) / tanh(1.5)
    }
}

// MARK: - Helper Extensions

extension ToneGenerator {
    /// Convert preset notes to tone parameters
    static func toneParameters(
        from preset: SoundPreset,
        sampleRate: Double = ToneGenerator.sampleRate
    ) -> [ToneParameters] {
        return preset.notes.map { note in
            ToneParameters(
                frequency: note.frequency,
                startSample: Int(note.startMs / 1000.0 * sampleRate),
                durationSamples: Int(note.durationMs / 1000.0 * sampleRate),
                volume: note.volume,
                envelope: preset.envelope,
                harmonics: preset.harmonics
            )
        }
    }

    /// Calculate total samples needed for a preset
    static func totalSamples(for preset: SoundPreset, sampleRate: Double = ToneGenerator.sampleRate) -> Int {
        // Add 50ms padding for release tail
        let paddingMs: Double = 50.0
        return Int((preset.totalDurationMs + paddingMs) / 1000.0 * sampleRate)
    }
}
