// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Sound presets for verification success feedback.
/// Each preset defines musical parameters (note frequencies, ADSR envelope, harmonic mix) for synthesised
/// tones played on successful age verification. Includes seven presets from the signature Provii chime to silence.
enum SoundPreset: String, Codable, CaseIterable, Identifiable {
    case provii
    case optimal
    case bright
    case warm
    case quick
    case celebration
    case silent

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .provii:      return NSLocalizedString("sound.preset.provii", comment: "Provii")
        case .optimal:     return NSLocalizedString("sound.preset.optimal", comment: "Optimal")
        case .bright:      return NSLocalizedString("sound.preset.bright", comment: "Bright")
        case .warm:        return NSLocalizedString("sound.preset.warm", comment: "Warm")
        case .quick:       return NSLocalizedString("sound.preset.quick", comment: "Quick")
        case .celebration: return NSLocalizedString("sound.preset.celebration", comment: "Celebration")
        case .silent:      return NSLocalizedString("sound.preset.silent", comment: "Silent")
        }
    }

    var description: String {
        switch self {
        case .provii:      return NSLocalizedString("sound.preset.provii.description", comment: "The signature Provii chime")
        case .optimal:     return NSLocalizedString("sound.preset.optimal.description", comment: "Balanced, clear confirmation")
        case .bright:      return NSLocalizedString("sound.preset.bright.description", comment: "Higher, more energetic")
        case .warm:        return NSLocalizedString("sound.preset.warm.description", comment: "Lower, more grounded")
        case .quick:       return NSLocalizedString("sound.preset.quick.description", comment: "Short and minimal")
        case .celebration: return NSLocalizedString("sound.preset.celebration.description", comment: "Fuller, three-note chime")
        case .silent:      return NSLocalizedString("sound.preset.silent.description", comment: "No sound, haptic only")
        }
    }

    // MARK: - Note Configuration

    /// Configuration for a single synthesised note
    struct NoteConfig {
        let frequency: Double      // Hz
        let startMs: Double        // Start time in milliseconds
        let durationMs: Double     // Duration in milliseconds
        let volume: Double         // Relative volume (0.0 - 1.0)
    }

    /// All notes for this preset
    var notes: [NoteConfig] {
        switch self {
        case .provii:
            return [
                NoteConfig(frequency: 1046.50, startMs: 0, durationMs: 60, volume: 0.22),
                NoteConfig(frequency: 1318.51, startMs: 50, durationMs: 340, volume: 0.24)
            ]
        case .optimal:
            return [
                NoteConfig(frequency: 523.25, startMs: 0, durationMs: 180, volume: 0.18),
                NoteConfig(frequency: 783.99, startMs: 120, durationMs: 380, volume: 0.216)
            ]
        case .bright:
            return [
                NoteConfig(frequency: 659.25, startMs: 0, durationMs: 150, volume: 0.16),
                NoteConfig(frequency: 987.77, startMs: 100, durationMs: 320, volume: 0.192)
            ]
        case .warm:
            return [
                NoteConfig(frequency: 392.00, startMs: 0, durationMs: 200, volume: 0.20),
                NoteConfig(frequency: 587.33, startMs: 140, durationMs: 420, volume: 0.24)
            ]
        case .quick:
            return [
                NoteConfig(frequency: 587.33, startMs: 0, durationMs: 100, volume: 0.18),
                NoteConfig(frequency: 783.99, startMs: 70, durationMs: 200, volume: 0.20)
            ]
        case .celebration:
            return [
                NoteConfig(frequency: 523.25, startMs: 0, durationMs: 140, volume: 0.16),
                NoteConfig(frequency: 659.25, startMs: 100, durationMs: 140, volume: 0.176),
                NoteConfig(frequency: 783.99, startMs: 200, durationMs: 350, volume: 0.20)
            ]
        case .silent:
            return []
        }
    }

    /// Total duration of the sound in milliseconds
    var totalDurationMs: Double {
        guard let lastNote = notes.last else { return 0 }
        return lastNote.startMs + lastNote.durationMs
    }

    // MARK: - Envelope Configuration

    /// ADSR envelope configuration
    struct EnvelopeConfig {
        let attackMs: Double       // Time to reach peak
        let sustainLevel: Double   // Sustain level (0.0 - 1.0)
        let releaseRatio: Double   // Release time as ratio of note duration
    }

    var envelope: EnvelopeConfig {
        switch self {
        case .provii:
            return EnvelopeConfig(attackMs: 4, sustainLevel: 0.20, releaseRatio: 0.85)
        case .optimal:
            return EnvelopeConfig(attackMs: 8, sustainLevel: 0.30, releaseRatio: 0.70)
        case .bright:
            return EnvelopeConfig(attackMs: 8, sustainLevel: 0.30, releaseRatio: 0.70)
        case .warm:
            return EnvelopeConfig(attackMs: 12, sustainLevel: 0.30, releaseRatio: 0.70)
        case .quick:
            return EnvelopeConfig(attackMs: 5, sustainLevel: 0.30, releaseRatio: 0.70)
        case .celebration:
            return EnvelopeConfig(attackMs: 8, sustainLevel: 0.30, releaseRatio: 0.70)
        case .silent:
            return EnvelopeConfig(attackMs: 0, sustainLevel: 0, releaseRatio: 0)
        }
    }

    // MARK: - Harmonic Configuration

    /// Harmonic mix ratios for rich tone synthesis
    /// [fundamental, chorus+, chorus-, octaveBelow, octaveAbove, thirdHarmonic]
    struct HarmonicConfig {
        let fundamental: Double      // Base tone
        let chorusPlus: Double       // +4 cents detuned
        let chorusMinus: Double      // -4 cents detuned
        let octaveBelow: Double      // f/2
        let octaveAbove: Double      // f*2
        let thirdHarmonic: Double    // f*3

        static let chorusDetuneCents: Double = 4.0
    }

    var harmonics: HarmonicConfig {
        switch self {
        case .provii:
            return HarmonicConfig(
                fundamental: 1.0,
                chorusPlus: 0.15,
                chorusMinus: 0.15,
                octaveBelow: 0.25,
                octaveAbove: 0.0,
                thirdHarmonic: 0.0
            )
        case .optimal:
            return HarmonicConfig(
                fundamental: 1.0,
                chorusPlus: 0.40,
                chorusMinus: 0.40,
                octaveBelow: 0.50,
                octaveAbove: 0.15,
                thirdHarmonic: 0.12
            )
        case .bright:
            return HarmonicConfig(
                fundamental: 1.0,
                chorusPlus: 0.40,
                chorusMinus: 0.40,
                octaveBelow: 0.35,
                octaveAbove: 0.15,
                thirdHarmonic: 0.12
            )
        case .warm:
            return HarmonicConfig(
                fundamental: 1.0,
                chorusPlus: 0.40,
                chorusMinus: 0.40,
                octaveBelow: 0.60,
                octaveAbove: 0.15,
                thirdHarmonic: 0.12
            )
        case .quick:
            return HarmonicConfig(
                fundamental: 1.0,
                chorusPlus: 0.40,
                chorusMinus: 0.40,
                octaveBelow: 0.0,
                octaveAbove: 0.0,
                thirdHarmonic: 0.0
            )
        case .celebration:
            return HarmonicConfig(
                fundamental: 1.0,
                chorusPlus: 0.40,
                chorusMinus: 0.40,
                octaveBelow: 0.50,
                octaveAbove: 0.15,
                thirdHarmonic: 0.12
            )
        case .silent:
            return HarmonicConfig(
                fundamental: 0,
                chorusPlus: 0,
                chorusMinus: 0,
                octaveBelow: 0,
                octaveAbove: 0,
                thirdHarmonic: 0
            )
        }
    }

    /// Whether this preset produces audio (false for silent)
    var hasAudio: Bool {
        self != .silent
    }
}
