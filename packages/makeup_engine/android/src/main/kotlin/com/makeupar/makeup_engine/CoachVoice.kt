package com.makeupar.makeup_engine

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * Voz de la guía de maquillaje (docs/ar_engine/COACH.md) con el TextToSpeech
 * que trae Android: sin dependencias ni red propias (el motor de voz del
 * sistema decide si usa sus voces locales).
 *
 * Hilo de plataforma. Cada [speak] corta lo anterior: la guía siempre dice lo
 * más reciente. Mientras el motor de voz arranca, se guarda el último pedido.
 */
internal class CoachVoice(context: Context) : TextToSpeech.OnInitListener {
    private val tts = TextToSpeech(context.applicationContext, this)
    private var ready = false
    private var failed = false
    private var pending: Pair<String, String>? = null
    private var language: String? = null

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        failed = !ready
        val last = pending
        pending = null
        if (ready && last != null) speak(last.first, last.second)
    }

    /**
     * Dice [text] en [locale] (es, en, pt, fr). false si el sistema no tiene
     * voz para ese idioma o el motor de voz no arrancó: queda solo el texto.
     */
    fun speak(text: String, locale: String): Boolean {
        if (failed) return false
        if (!ready) {
            pending = text to locale
            return true
        }
        if (locale != language) {
            val result = tts.setLanguage(Locale.forLanguageTag(locale))
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) return false
            language = locale
        }
        return tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, UTTERANCE_ID) == TextToSpeech.SUCCESS
    }

    fun stop() {
        pending = null
        if (ready) tts.stop()
    }

    fun shutdown() {
        pending = null
        tts.shutdown()
    }

    private companion object {
        const val UTTERANCE_ID = "makeup_coach"
    }
}
