// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.audio

import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.tanh

/**
 * Low-level tone synthesis engine for generating verification sounds. Produces
 * PCM float buffers from [SoundPreset] configurations using additive sine wave
 * synthesis with configurable harmonics, chorus detuning, and ADSR envelopes.
 * Output is soft-clipped via tanh to prevent harsh distortion on overlapping notes.
 */
class ToneGenerator(private val sampleRate: Int = SAMPLE_RATE) {
    companion object {
        const val SAMPLE_RATE = 44100
    }

    /**
     * Generate complete audio buffer for a preset.
     * @param preset The sound preset to generate
     * @param masterVolume Master volume multiplier (0.0 - 1.0)
     * @return FloatArray of audio samples
     */
    fun generatePresetBuffer(
        preset: SoundPreset,
        masterVolume: Float,
    ): FloatArray {
        if (!preset.hasAudio || preset.notes.isEmpty()) {
            return FloatArray(0)
        }

        // Calculate total samples needed (add 50ms padding for release tail)
        val paddingMs = 50f
        val totalSamples = ((preset.totalDurationMs + paddingMs) / 1000f * sampleRate).toInt()
        val buffer = FloatArray(totalSamples)

        // Generate each note
        for (note in preset.notes) {
            generateNote(
                buffer = buffer,
                note = note,
                envelope = preset.envelope,
                harmonics = preset.harmonics,
                masterVolume = masterVolume,
            )
        }

        return buffer
    }

    private fun generateNote(
        buffer: FloatArray,
        note: SoundPreset.NoteConfig,
        envelope: SoundPreset.EnvelopeConfig,
        harmonics: SoundPreset.HarmonicConfig,
        masterVolume: Float,
    ) {
        val startSample = (note.startMs / 1000f * sampleRate).toInt()
        val durationSamples = (note.durationMs / 1000f * sampleRate).toInt()
        val endSample = minOf(startSample + durationSamples, buffer.size)

        // Calculate harmonic frequencies
        val frequencies = calculateHarmonicFrequencies(note.frequency, harmonics)
        val amplitudes =
            listOf(
                harmonics.fundamental,
                harmonics.chorusPlus,
                harmonics.chorusMinus,
                harmonics.octaveBelow,
                harmonics.octaveAbove,
                harmonics.thirdHarmonic,
            )

        // Phase accumulators for each harmonic
        val phases = FloatArray(frequencies.size)

        // Phase increments per sample
        val phaseIncrements =
            frequencies.map { freq ->
                (2.0 * PI * freq / sampleRate).toFloat()
            }

        // Normalise amplitude by sum of active harmonics
        val ampSum = amplitudes.sum()
        val normFactor = if (ampSum > 0) 1f / ampSum else 1f

        for (i in startSample until endSample) {
            val localSample = i - startSample
            val time = localSample.toFloat() / sampleRate

            // Calculate envelope amplitude
            val envelopeAmp =
                calculateEnvelope(
                    time = time,
                    durationMs = note.durationMs,
                    envelope = envelope,
                )

            var sample = 0f

            // Sum all harmonics
            for ((j, amplitude) in amplitudes.withIndex()) {
                if (amplitude > 0) {
                    sample += sin(phases[j].toDouble()).toFloat() * amplitude
                    phases[j] += phaseIncrements[j]

                    // Wrap phase to prevent overflow
                    if (phases[j] > 2 * PI.toFloat()) {
                        phases[j] -= (2 * PI).toFloat()
                    }
                }
            }

            // Apply normalisation, envelope, volume
            sample *= normFactor * envelopeAmp * note.volume * masterVolume

            // Soft clipping to prevent distortion
            sample = softClip(sample)

            // Add to buffer (accumulate for overlapping notes)
            buffer[i] += sample
        }
    }

    /**
     * Calculate frequencies for all harmonics
     */
    private fun calculateHarmonicFrequencies(
        fundamental: Float,
        harmonics: SoundPreset.HarmonicConfig,
    ): List<Float> {
        val centsRatio = 2f.pow(SoundPreset.HarmonicConfig.CHORUS_DETUNE_CENTS / 1200f)

        return listOf(
            fundamental, // Fundamental
            fundamental * centsRatio, // Chorus + (4 cents sharp)
            fundamental / centsRatio, // Chorus - (4 cents flat)
            fundamental / 2f, // Octave below
            fundamental * 2f, // Octave above
            fundamental * 3f, // Third harmonic
        )
    }

    /**
     * Calculate ADSR envelope amplitude at given time
     */
    private fun calculateEnvelope(
        time: Float,
        durationMs: Float,
        envelope: SoundPreset.EnvelopeConfig,
    ): Float {
        val attackTime = envelope.attackMs / 1000f
        val durationSec = durationMs / 1000f
        val releaseStart = durationSec * (1f - envelope.releaseRatio)
        val releaseTime = durationSec * envelope.releaseRatio

        return when {
            time < attackTime -> {
                // Attack phase: exponential rise
                val progress = time / attackTime
                exponentialRamp(progress)
            }
            time < releaseStart -> {
                // Sustain phase: gradual decay to sustain level
                val sustainProgress = (time - attackTime) / (releaseStart - attackTime)
                1f - (1f - envelope.sustainLevel) * sustainProgress
            }
            else -> {
                // Release phase: exponential decay
                val releaseProgress = minOf((time - releaseStart) / releaseTime, 1f)
                envelope.sustainLevel * (1f - exponentialRamp(releaseProgress))
            }
        }
    }

    /**
     * Exponential ramp function for smooth transitions.
     * Returns 0 at t=0, approaches 1 as t approaches 1.
     */
    private fun exponentialRamp(t: Float): Float {
        return (1f - exp(-4f * t))
    }

    /**
     * Soft clipping using tanh to prevent harsh distortion.
     */
    private fun softClip(sample: Float): Float {
        return (tanh(sample * 1.5) / tanh(1.5)).toFloat()
    }
}
