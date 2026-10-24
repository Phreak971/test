package app.overworld.overworld.car

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.Locale

/**
 * Spoken guidance via the platform [TextToSpeech] engine.
 *
 * - pitch is used as-is (personas use ~0.75..1.35, 1.0 = normal);
 *   rate is the flutter_tts style 0..1 value where 0.5 = normal, so it is
 *   doubled for [TextToSpeech.setSpeechRate].
 * - Each utterance requests transient, duckable audio focus with
 *   navigation-guidance usage and abandons it once the queue drains.
 * - A transient focus loss (e.g. a phone call) stops the current phrase.
 */
class CarVoice(context: Context) : TextToSpeech.OnInitListener {
    private val appContext = context.applicationContext
    private val audio = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val main = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = TextToSpeech(appContext, this)
    private var ready = false
    private var pending: String? = null
    private var settings = CarVoiceSettings()
    private var language = "en"
    private val inFlight = HashSet<String>()
    private var focusRequest: AudioFocusRequest? = null
    private var hasFocus = false
    private var nextId = 0

    var muted = false

    private val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> main.post {
                // Pause on transient loss: drop the current phrase rather than talk over a call.
                tts?.stop()
                inFlight.clear()
                abandonFocus()
            }
            else -> Unit
        }
    }

    override fun onInit(status: Int) {
        main.post {
            if (status != TextToSpeech.SUCCESS) {
                Log.w(TAG, "TTS init failed: $status")
                return@post
            }
            val engine = tts ?: return@post
            ready = true
            engine.setAudioAttributes(attributes)
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}

                override fun onDone(utteranceId: String?) {
                    main.post { finished(utteranceId) }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    main.post { finished(utteranceId) }
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    main.post { finished(utteranceId) }
                }

                override fun onStop(utteranceId: String?, interrupted: Boolean) {
                    main.post { finished(utteranceId) }
                }
            })
            applySettings()
            pending?.let { pending = null; speak(it) }
        }
    }

    /** Applies synced voice/locale settings. */
    fun configure(voice: CarVoiceSettings, locale: String, muted: Boolean) {
        this.muted = muted
        if (voice == settings && locale == language) return
        settings = voice
        language = locale
        if (ready) applySettings()
    }

    private fun applySettings() {
        val engine = tts ?: return
        engine.setPitch(settings.pitch.toFloat().coerceIn(0.5f, 2.0f))
        engine.setSpeechRate((settings.rate * 2.0).toFloat().coerceIn(0.5f, 2.0f))
        val loc = Locale.forLanguageTag(language.take(2).ifEmpty { "en" })
        val r = try {
            engine.setLanguage(loc)
        } catch (t: Throwable) {
            TextToSpeech.LANG_NOT_SUPPORTED
        }
        if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
            Log.w(TAG, "TTS language $loc unavailable ($r); using default")
            runCatching { engine.setLanguage(Locale.getDefault()) }
        }
    }

    /** Queues [text]. Ignored while muted. [force] speaks even when muted (voice test button). */
    fun speak(text: String, force: Boolean = false, flush: Boolean = false) {
        if (text.isBlank() || (muted && !force)) return
        val engine = tts ?: return
        if (!ready) {
            pending = text
            return
        }
        if (!requestFocus()) return
        val id = "ow-${nextId++}"
        if (flush) inFlight.clear()
        inFlight.add(id)
        // Audio attributes (navigation guidance) are set on the engine; no stream override here.
        val r = engine.speak(text, if (flush) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD, Bundle(), id)
        if (r != TextToSpeech.SUCCESS) finished(id)
    }

    fun stop() {
        tts?.stop()
        inFlight.clear()
        abandonFocus()
    }

    private fun finished(id: String?) {
        if (id != null) inFlight.remove(id)
        if (inFlight.isEmpty()) abandonFocus()
    }

    private fun requestFocus(): Boolean {
        if (hasFocus) return true
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener, main)
                .setWillPauseWhenDucked(false)
                .build()
            focusRequest = req
            audio.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        hasFocus = granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasFocus
    }

    private fun abandonFocus() {
        if (!hasFocus) return
        hasFocus = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audio.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audio.abandonAudioFocus(focusListener)
        }
    }

    fun release() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (t: Throwable) {
            Log.w(TAG, "TTS shutdown", t)
        }
        tts = null
        ready = false
        abandonFocus()
        main.removeCallbacksAndMessages(null)
    }

    companion object {
        private const val TAG = "OverworldCar"
    }
}
