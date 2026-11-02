package com.makeupar.makeup_engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * Voz de la guía de maquillaje (docs/ar_engine/COACH.md) con el TextToSpeech
 * que trae Android: sin dependencias ni red propias (el motor de voz del
 * sistema decide si usa sus voces locales).
 *
 * Hilo de plataforma. Cada [speak] corta lo anterior: la guía siempre dice lo
 * más reciente. Mientras el motor de voz arranca se guarda solo el último
 * pedido, y su respuesta espera a saber si hay voz para el idioma: así el
 * aviso de "sin voz" sale con la primera indicación y no con la siguiente.
 */
internal class CoachVoice(context: Context) : TextToSpeech.OnInitListener {
    private class Pending(val text: String, val locale: String, val onResult: (Boolean) -> Unit)

    private val main = Handler(Looper.getMainLooper())
    private val tts = TextToSpeech(context.applicationContext, this)
    private var ready = false
    private var failed = false
    private var released = false
    private var pending: Pending? = null
    private var language: String? = null

    override fun onInit(status: Int) {
        // El sistema avisa desde el hilo principal; se pasa a él igual para
        // que todo el estado viva en un solo hilo.
        main.post {
            if (released) return@post
            ready = status == TextToSpeech.SUCCESS
            failed = !ready
            val last = pending ?: return@post
            pending = null
            last.onResult(ready && speakNow(last.text, last.locale))
        }
    }

    /**
     * Dice [text] en [locale] (es, en, pt, fr) y responde por [onResult]:
     * false si el sistema no tiene voz para ese idioma o el motor de voz no
     * arrancó (queda solo el texto). Un pedido reemplazado por otro mientras
     * el motor arranca, o cortado con [stop], responde true: no es una falla.
     */
    fun speak(text: String, locale: String, onResult: (Boolean) -> Unit) {
        when {
            failed || released -> onResult(false)
            !ready -> {
                pending?.onResult?.invoke(true)
                pending = Pending(text, locale, onResult)
            }
            else -> onResult(speakNow(text, locale))
        }
    }

    private fun speakNow(text: String, locale: String): Boolean {
        if (locale != language) {
            // Negativo = LANG_MISSING_DATA o LANG_NOT_SUPPORTED.
            if (tts.setLanguage(Locale.forLanguageTag(locale)) < TextToSpeech.LANG_AVAILABLE) return false
            language = locale
        }
        return tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, UTTERANCE_ID) == TextToSpeech.SUCCESS
    }

    fun stop() {
        answerPending()
        if (ready) tts.stop()
    }

    fun shutdown() {
        released = true
        answerPending()
        main.removeCallbacksAndMessages(null)
        tts.shutdown()
    }

    private fun answerPending() {
        val last = pending ?: return
        pending = null
        last.onResult(true)
    }

    private companion object {
        const val UTTERANCE_ID = "makeup_coach"
    }
}
