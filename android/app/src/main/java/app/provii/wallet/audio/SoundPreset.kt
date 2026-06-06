// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.audio

/**
 * Sound presets for verification success feedback. Each preset defines musical
 * parameters including note frequencies, ADSR envelope, and harmonic mix ratios
 * for runtime audio synthesis. The [Silent] preset produces no audio and relies
 * on haptic feedback only.
 */
sealed class SoundPreset(
    val name: String,
    val displayName: String,
    val description: String,
    val notes: List<NoteConfig>,
    val envelope: EnvelopeConfig,
    val harmonics: HarmonicConfig,
) {
    /**
     * Configuration for a single synthesized note
     */
    data class NoteConfig(
        val frequency: Float, // Hz
        val startMs: Float, // Start time in milliseconds
        val durationMs: Float, // Duration in milliseconds
        val volume: Float, // Relative volume (0.0 - 1.0)
    )

    /**
     * ADSR envelope configuration
     */
    data class EnvelopeConfig(
        val attackMs: Float, // Time to reach peak
        val sustainLevel: Float, // Sustain level (0.0 - 1.0)
        val releaseRatio: Float, // Release time as ratio of note duration
    )

    /**
     * Harmonic mix ratios for rich tone synthesis
     */
    data class HarmonicConfig(
        val fundamental: Float, // Base tone
        val chorusPlus: Float, // +4 cents detuned
        val chorusMinus: Float, // -4 cents detuned
        val octaveBelow: Float, // f/2
        val octaveAbove: Float, // f*2
        val thirdHarmonic: Float, // f*3
    ) {
        companion object {
            const val CHORUS_DETUNE_CENTS = 4f
        }
    }

    /** Total duration of the sound in milliseconds */
    val totalDurationMs: Float
        get() = notes.maxOfOrNull { it.startMs + it.durationMs } ?: 0f

    /** Whether this preset produces audio (false for silent) */
    val hasAudio: Boolean
        get() = this !is Silent

    // Preset definitions

    object Provii : SoundPreset(
        name = "provii",
        displayName = "Provii",
        description = "The signature Provii chime",
        notes =
            listOf(
                NoteConfig(frequency = 1046.50f, startMs = 0f, durationMs = 60f, volume = 0.65f),
                NoteConfig(frequency = 1318.51f, startMs = 50f, durationMs = 340f, volume = 0.70f),
            ),
        envelope = EnvelopeConfig(attackMs = 4f, sustainLevel = 0.50f, releaseRatio = 0.85f),
        harmonics =
            HarmonicConfig(
                fundamental = 1.0f,
                chorusPlus = 0.15f,
                chorusMinus = 0.15f,
                octaveBelow = 0.25f,
                octaveAbove = 0.0f,
                thirdHarmonic = 0.0f,
            ),
    )

    object Optimal : SoundPreset(
        name = "optimal",
        displayName = "Optimal",
        description = "Balanced, clear confirmation",
        notes =
            listOf(
                NoteConfig(frequency = 523.25f, startMs = 0f, durationMs = 180f, volume = 0.6f),
                NoteConfig(frequency = 783.99f, startMs = 120f, durationMs = 380f, volume = 0.7f),
            ),
        envelope = EnvelopeConfig(attackMs = 8f, sustainLevel = 0.7f, releaseRatio = 0.70f),
        harmonics =
            HarmonicConfig(
                fundamental = 1.0f,
                chorusPlus = 0.40f,
                chorusMinus = 0.40f,
                octaveBelow = 0.50f,
                octaveAbove = 0.15f,
                thirdHarmonic = 0.12f,
            ),
    )

    object Bright : SoundPreset(
        name = "bright",
        displayName = "Bright",
        description = "Higher, more energetic",
        notes =
            listOf(
                NoteConfig(frequency = 659.25f, startMs = 0f, durationMs = 150f, volume = 0.55f),
                NoteConfig(frequency = 987.77f, startMs = 100f, durationMs = 320f, volume = 0.65f),
            ),
        envelope = EnvelopeConfig(attackMs = 8f, sustainLevel = 0.7f, releaseRatio = 0.70f),
        harmonics =
            HarmonicConfig(
                fundamental = 1.0f,
                chorusPlus = 0.40f,
                chorusMinus = 0.40f,
                octaveBelow = 0.35f,
                octaveAbove = 0.15f,
                thirdHarmonic = 0.12f,
            ),
    )

    object Warm : SoundPreset(
        name = "warm",
        displayName = "Warm",
        description = "Lower, more grounded",
        notes =
            listOf(
                NoteConfig(frequency = 392.00f, startMs = 0f, durationMs = 200f, volume = 0.65f),
                NoteConfig(frequency = 587.33f, startMs = 140f, durationMs = 420f, volume = 0.75f),
            ),
        envelope = EnvelopeConfig(attackMs = 12f, sustainLevel = 0.7f, releaseRatio = 0.70f),
        harmonics =
            HarmonicConfig(
                fundamental = 1.0f,
                chorusPlus = 0.40f,
                chorusMinus = 0.40f,
                octaveBelow = 0.60f,
                octaveAbove = 0.15f,
                thirdHarmonic = 0.12f,
            ),
    )

    object Quick : SoundPreset(
        name = "quick",
        displayName = "Quick",
        description = "Short and minimal",
        notes =
            listOf(
                NoteConfig(frequency = 587.33f, startMs = 0f, durationMs = 100f, volume = 0.6f),
                NoteConfig(frequency = 783.99f, startMs = 70f, durationMs = 200f, volume = 0.7f),
            ),
        envelope = EnvelopeConfig(attackMs = 5f, sustainLevel = 0.7f, releaseRatio = 0.70f),
        harmonics =
            HarmonicConfig(
                fundamental = 1.0f,
                chorusPlus = 0.40f,
                chorusMinus = 0.40f,
                octaveBelow = 0.0f,
                octaveAbove = 0.0f,
                thirdHarmonic = 0.0f,
            ),
    )

    object Celebration : SoundPreset(
        name = "celebration",
        displayName = "Celebration",
        description = "Fuller, three-note chime",
        notes =
            listOf(
                NoteConfig(frequency = 523.25f, startMs = 0f, durationMs = 140f, volume = 0.55f),
                NoteConfig(frequency = 659.25f, startMs = 100f, durationMs = 140f, volume = 0.6f),
                NoteConfig(frequency = 783.99f, startMs = 200f, durationMs = 350f, volume = 0.7f),
            ),
        envelope = EnvelopeConfig(attackMs = 8f, sustainLevel = 0.7f, releaseRatio = 0.70f),
        harmonics =
            HarmonicConfig(
                fundamental = 1.0f,
                chorusPlus = 0.40f,
                chorusMinus = 0.40f,
                octaveBelow = 0.50f,
                octaveAbove = 0.15f,
                thirdHarmonic = 0.12f,
            ),
    )

    object Silent : SoundPreset(
        name = "silent",
        displayName = "Silent",
        description = "No sound, haptic only",
        notes = emptyList(),
        envelope = EnvelopeConfig(attackMs = 0f, sustainLevel = 0f, releaseRatio = 0f),
        harmonics =
            HarmonicConfig(
                fundamental = 0f,
                chorusPlus = 0f,
                chorusMinus = 0f,
                octaveBelow = 0f,
                octaveAbove = 0f,
                thirdHarmonic = 0f,
            ),
    )

    companion object {
        /** All available presets */
        val entries: List<SoundPreset> = listOf(Provii, Optimal, Bright, Warm, Quick, Celebration, Silent)

        /** All presets that produce audio (excludes Silent) */
        val audioPresets: List<SoundPreset> = entries.filter { it.hasAudio }

        /** Get preset by name, defaulting to Provii if not found */
        fun fromName(name: String): SoundPreset {
            return entries.find { it.name.equals(name, ignoreCase = true) } ?: Provii
        }
    }
}
