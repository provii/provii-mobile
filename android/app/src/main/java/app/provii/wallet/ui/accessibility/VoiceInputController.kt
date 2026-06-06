// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.accessibility

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import timber.log.Timber
import java.util.Locale

/**
 * Lifecycle-aware wrapper around the Android [SpeechRecognizer] API. Exposes reactive
 * [StateFlow] properties for listening state, transcript text, and error messages so that
 * Compose UI can observe changes directly. Supports locale mapping for the app's
 * supported languages, including RTL locales such as Arabic, Dari, and Pashto.
 */
class VoiceInputController(
    context: Context,
) : RecognitionListener, DefaultLifecycleObserver {
    private val appContext = context.applicationContext

    private val speechRecognizer: SpeechRecognizer? =
        if (SpeechRecognizer.isRecognitionAvailable(appContext)) {
            SpeechRecognizer.createSpeechRecognizer(appContext).apply {
                setRecognitionListener(this@VoiceInputController)
            }
        } else {
            null
        }

    private val _isListening = MutableStateFlow(false)
    val isListening: StateFlow<Boolean> = _isListening

    private val _transcript = MutableStateFlow("")
    val transcript: StateFlow<String> = _transcript

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    var onCommand: ((String) -> Unit)? = null

    fun hasRecordAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun getCurrentAppLanguage(): String {
        val locales = AppCompatDelegate.getApplicationLocales()
        return if (locales.isEmpty) {
            Locale.getDefault().toLanguageTag()
        } else {
            locales[0]?.toLanguageTag() ?: "en-US"
        }
    }

    private fun mapToSpeechRecognitionLocale(appLocale: String): String {
        // Map script subtags to region subtags for speech recognition
        return when {
            appLocale.startsWith("zh-Hans") -> "zh-CN"
            appLocale.startsWith("zh-Hant") -> "zh-TW"
            else -> appLocale
        }
    }

    fun startListening(language: String? = null) {
        if (!hasRecordAudioPermission()) {
            Timber.w("RECORD_AUDIO permission not granted")
            _errorMessage.value = appContext.getString(app.provii.wallet.R.string.voice_input_error_insufficient_permissions)
            return
        }
        if (speechRecognizer == null) {
            Timber.w("Speech recognizer unavailable")
            _errorMessage.value = appContext.getString(app.provii.wallet.R.string.voice_input_error_not_available)
            return
        }
        _errorMessage.value = null

        val effectiveLanguage = language ?: getCurrentAppLanguage()
        val speechLanguage = mapToSpeechRecognitionLocale(effectiveLanguage)

        Timber.d("Starting voice input with language: $speechLanguage (app locale: $effectiveLanguage)")

        val intent =
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, speechLanguage)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, speechLanguage)
                putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, speechLanguage)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
        _transcript.value = ""
        speechRecognizer.startListening(intent)
        _isListening.value = true
    }

    fun stopListening() {
        speechRecognizer?.stopListening()
        _isListening.value = false
        _transcript.value = ""
    }

    fun clearTranscript() {
        _transcript.value = ""
    }

    fun clearError() {
        _errorMessage.value = null
    }

    override fun onReadyForSpeech(params: Bundle?) {
        Timber.d("VoiceInput ready for speech")
    }

    override fun onBeginningOfSpeech() {
        _transcript.value = ""
    }

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() {
        Timber.d("VoiceInput end of speech")
    }

    override fun onError(error: Int) {
        Timber.w("VoiceInput error: $error")
        _isListening.value = false
        _errorMessage.value =
            when (error) {
                android.speech.SpeechRecognizer.ERROR_AUDIO ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_audio)
                android.speech.SpeechRecognizer.ERROR_NETWORK ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_network)
                android.speech.SpeechRecognizer.ERROR_NETWORK_TIMEOUT ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_network_timeout)
                android.speech.SpeechRecognizer.ERROR_NO_MATCH ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_no_match)
                android.speech.SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_recognizer_busy)
                android.speech.SpeechRecognizer.ERROR_SERVER ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_server)
                android.speech.SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_speech_timeout)
                android.speech.SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_insufficient_permissions)
                else ->
                    appContext.getString(app.provii.wallet.R.string.voice_input_error_generic)
            }
    }

    override fun onResults(results: Bundle?) {
        _isListening.value = false
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        matches?.firstOrNull()?.let { text ->
            _transcript.value = text
            onCommand?.invoke(text)
        }
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        matches?.firstOrNull()?.let { text ->
            _transcript.value = text
        }
    }

    override fun onEvent(
        eventType: Int,
        params: Bundle?,
    ) = Unit

    /**
     * Releases the [SpeechRecognizer] IPC binder. Safe to call multiple times because
     * [SpeechRecognizer.destroy] is idempotent. [stopListening] is called first to avoid
     * a crash on certain OEM implementations that reject destroy while a recognition
     * session is still active.
     */
    fun destroy() {
        stopListening()
        speechRecognizer?.destroy()
        _isListening.value = false
    }

    override fun onDestroy(owner: LifecycleOwner) {
        super.onDestroy(owner)
        _transcript.value = ""
        _errorMessage.value = null
        destroy()
    }
}
