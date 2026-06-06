// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages verification success sound playback using runtime audio synthesis.
 * Respects device ringer mode and provides haptic feedback.
 */
@Singleton
class VerificationSoundManager
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
    ) {
        private val audioManager: AudioManager =
            context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        private val vibrator: Vibrator =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

        private val toneGenerator = ToneGenerator()
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        private val mutex = Mutex()

        // Buffer cache for efficiency
        private val bufferCache = mutableMapOf<Pair<String, Int>, FloatArray>()

        // Current AudioTrack instance
        private var currentTrack: AudioTrack? = null

        /**
         * Play verification success sound and haptic feedback.
         * Uses settings from provided parameters.
         *
         * @param soundEnabled Whether sound is enabled
         * @param preset The sound preset to play
         * @param volumePercent Volume level 0-100
         * @param hapticEnabled Whether haptic feedback is enabled
         */
        fun playVerificationSuccess(
            soundEnabled: Boolean,
            preset: SoundPreset,
            volumePercent: Int,
            hapticEnabled: Boolean,
        ) {
            // Always trigger haptic if enabled (even for silent preset)
            if (hapticEnabled) {
                triggerHapticFeedback()
            }

            // Check if sound should play
            if (!soundEnabled || !preset.hasAudio || volumePercent <= 0) {
                Timber.d("Sound skipped: enabled=$soundEnabled, hasAudio=${preset.hasAudio}, volume=$volumePercent")
                return
            }

            if (!canPlaySound()) {
                Timber.d("Cannot play sound - device in silent/vibrate mode")
                return
            }

            scope.launch {
                try {
                    playSound(preset, volumePercent)
                } catch (e: Exception) {
                    Timber.e(e, "Error playing verification sound")
                }
            }
        }

        /**
         * Play a specific preset at a specific volume (for settings preview).
         */
        fun previewSound(
            preset: SoundPreset,
            volumePercent: Int,
        ) {
            if (!preset.hasAudio || volumePercent <= 0) return

            scope.launch {
                try {
                    playSound(preset, volumePercent)
                } catch (e: Exception) {
                    Timber.e(e, "Error previewing sound")
                }
            }
        }

        /**
         * Check if sound can be played based on ringer mode.
         * Sound is only played in RINGER_MODE_NORMAL.
         */
        private fun canPlaySound(): Boolean {
            val ringerMode = audioManager.ringerMode
            return ringerMode == AudioManager.RINGER_MODE_NORMAL
        }

        /**
         * Trigger haptic feedback for success.
         * Uses simple one-shot vibration for maximum device compatibility.
         */
        private fun triggerHapticFeedback() {
            try {
                if (!vibrator.hasVibrator()) {
                    Timber.d("Device has no vibrator")
                    return
                }

                vibrator.vibrate(
                    VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE),
                )
                Timber.d("Haptic feedback triggered successfully")
            } catch (e: Exception) {
                Timber.w(e, "Failed to trigger haptic feedback: ${e.message}")
            }
        }

        private suspend fun playSound(
            preset: SoundPreset,
            volumePercent: Int,
        ) {
            val volume = (volumePercent.coerceIn(0, 100) / 100f).coerceIn(0f, 1f)
            val buffer = getOrGenerateBuffer(preset, volumePercent)

            if (buffer.isEmpty()) {
                Timber.w("Generated buffer is empty")
                return
            }

            playBuffer(buffer, volume)
        }

        /**
         * Get cached buffer or generate new one.
         */
        private suspend fun getOrGenerateBuffer(
            preset: SoundPreset,
            volumePercent: Int,
        ): FloatArray =
            withContext(Dispatchers.Default) {
                val key = preset.name to volumePercent
                bufferCache.getOrPut(key) {
                    val volume = volumePercent / 100f
                    toneGenerator.generatePresetBuffer(preset, volume)
                }
            }

        /**
         * Play audio buffer using AudioTrack in MODE_STATIC.
         */
        private suspend fun playBuffer(
            buffer: FloatArray,
            volume: Float,
        ) =
            withContext(Dispatchers.IO) {
                mutex.withLock {
                    // Stop and release any existing track
                    currentTrack?.let { track ->
                        try {
                            if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                                track.stop()
                            }
                            track.release()
                        } catch (e: Exception) {
                            Timber.w(e, "Error releasing previous AudioTrack")
                        }
                    }

                    try {
                        val track = createAudioTrack(buffer.size)
                        currentTrack = track

                        // Write buffer to track
                        val written =
                            track.write(
                                buffer,
                                0,
                                buffer.size,
                                AudioTrack.WRITE_BLOCKING,
                            )

                        if (written != buffer.size) {
                            Timber.w("Only wrote $written of ${buffer.size} samples")
                        }

                        // Set volume
                        track.setVolume(volume)

                        // Start playback
                        track.play()

                        Timber.d("Playing verification sound: ${buffer.size} samples")

                        // Schedule cleanup after playback
                        val durationMs = (buffer.size.toLong() * 1000) / ToneGenerator.SAMPLE_RATE + 100
                        scope.launch {
                            delay(durationMs)
                            mutex.withLock {
                                if (currentTrack == track) {
                                    try {
                                        track.stop()
                                        track.release()
                                    } catch (e: Exception) {
                                        Timber.w(e, "Error cleaning up AudioTrack")
                                    }
                                    currentTrack = null
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Timber.e(e, "Error creating/playing AudioTrack")
                        currentTrack = null
                    }
                }
            }

        private fun createAudioTrack(bufferSizeInFrames: Int): AudioTrack {
            val audioAttributes =
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

            val audioFormat =
                AudioFormat.Builder()
                    .setSampleRate(ToneGenerator.SAMPLE_RATE)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()

            return AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(bufferSizeInFrames * 4) // 4 bytes per float
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
        }

        /**
         * Clear buffer cache (call on memory pressure).
         */
        fun clearCache() {
            bufferCache.clear()
        }

        /**
         * Release resources.
         */
        fun dispose() {
            scope.cancel()
            currentTrack?.release()
            currentTrack = null
            bufferCache.clear()
        }
    }
