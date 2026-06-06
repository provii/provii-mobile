// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SoundPresetTest {
    @Test
    fun `entries contains all seven presets`() {
        assertEquals(7, SoundPreset.entries.size)
    }

    @Test
    fun `audioPresets excludes Silent`() {
        val audio = SoundPreset.audioPresets
        assertEquals(6, audio.size)
        assertFalse(audio.any { it is SoundPreset.Silent })
    }

    @Test
    fun `fromName returns correct preset`() {
        assertEquals(SoundPreset.Provii, SoundPreset.fromName("provii"))
        assertEquals(SoundPreset.Optimal, SoundPreset.fromName("optimal"))
        assertEquals(SoundPreset.Bright, SoundPreset.fromName("bright"))
        assertEquals(SoundPreset.Warm, SoundPreset.fromName("warm"))
        assertEquals(SoundPreset.Quick, SoundPreset.fromName("quick"))
        assertEquals(SoundPreset.Celebration, SoundPreset.fromName("celebration"))
        assertEquals(SoundPreset.Silent, SoundPreset.fromName("silent"))
    }

    @Test
    fun `fromName is case insensitive`() {
        assertEquals(SoundPreset.Provii, SoundPreset.fromName("PROVII"))
        assertEquals(SoundPreset.Bright, SoundPreset.fromName("Bright"))
    }

    @Test
    fun `fromName defaults to Provii for unknown name`() {
        assertEquals(SoundPreset.Provii, SoundPreset.fromName("nonexistent"))
        assertEquals(SoundPreset.Provii, SoundPreset.fromName(""))
    }

    @Test
    fun `silent preset has no audio`() {
        assertFalse(SoundPreset.Silent.hasAudio)
        assertEquals(0f, SoundPreset.Silent.totalDurationMs, 0.001f)
        assertTrue(SoundPreset.Silent.notes.isEmpty())
    }

    @Test
    fun `provii preset has audio and positive duration`() {
        assertTrue(SoundPreset.Provii.hasAudio)
        assertTrue(SoundPreset.Provii.totalDurationMs > 0f)
        assertTrue(SoundPreset.Provii.notes.isNotEmpty())
    }

    @Test
    fun `celebration preset has three notes`() {
        assertEquals(3, SoundPreset.Celebration.notes.size)
    }

    @Test
    fun `totalDurationMs computes from latest note end`() {
        // Celebration: last note starts at 200ms with 350ms duration = 550ms
        assertEquals(550f, SoundPreset.Celebration.totalDurationMs, 0.001f)
    }

    @Test
    fun `all presets have positive frequencies except silent`() {
        SoundPreset.audioPresets.forEach { preset ->
            preset.notes.forEach { note ->
                assertTrue("${preset.name} note frequency must be positive", note.frequency > 0f)
                assertTrue("${preset.name} note volume must be in 0..1", note.volume in 0f..1f)
            }
        }
    }

    @Test
    fun `envelope sustain level is within valid range for all presets`() {
        SoundPreset.entries.forEach { preset ->
            assertTrue(
                "${preset.name} sustain in 0..1",
                preset.envelope.sustainLevel in 0f..1f,
            )
        }
    }
}
