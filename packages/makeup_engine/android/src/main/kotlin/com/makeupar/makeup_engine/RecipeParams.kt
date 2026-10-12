package com.makeupar.makeup_engine

/**
 * Receta `makeup-recipe/2` (ya validada en Dart: RecipeValidator) llegada por
 * el canal como mapa, reducida a los parámetros que el motor dibuja. Por ahora
 * solo labios (P4); el resto de las regiones se ignora hasta P5.
 *
 * Es la segunda línea de defensa: cualquier valor ausente, mal tipado o fuera
 * de rango se recorta o apaga la región, nunca rompe el render.
 */
internal data class RecipeParams(val lips: LipParams) {
    companion object {
        fun fromMap(recipe: Map<*, *>?): RecipeParams =
            RecipeParams(lips = LipParams.fromMap(recipe?.get("lips") as? Map<*, *>))
    }
}

/** Labial resuelto: color sRGB [0,1], acabado NativeBridge.LIP_FINISH_*. */
internal data class LipParams(
    val enabled: Boolean,
    val r: Float,
    val g: Float,
    val b: Float,
    val opacity: Float,
    val finish: Int,
    val gloss: Float,
    val lumaFollow: Float,
) {
    companion object {
        val DISABLED = LipParams(false, 0f, 0f, 0f, 0f, NativeBridge.LIP_FINISH_SATIN, 0f, 0f)

        // Brillo por acabado si la receta no lo trae (docs/ar_engine/LIPS.md).
        private val DEFAULT_GLOSS = mapOf(
            NativeBridge.LIP_FINISH_MATTE to 0f,
            NativeBridge.LIP_FINISH_SATIN to 0.3f,
            NativeBridge.LIP_FINISH_GLOSS to 0.6f,
            NativeBridge.LIP_FINISH_SHIMMER to 0.5f,
        )
        private const val DEFAULT_LUMA_FOLLOW = 0.3f
        private val FINISHES = mapOf(
            "matte" to NativeBridge.LIP_FINISH_MATTE,
            "satin" to NativeBridge.LIP_FINISH_SATIN,
            "gloss" to NativeBridge.LIP_FINISH_GLOSS,
            "shimmer" to NativeBridge.LIP_FINISH_SHIMMER,
        )
        private val HEX = Regex("^#[0-9A-Fa-f]{6}$")

        /** Sin `lips`, sin color válido o sin opacidad: labial apagado. */
        fun fromMap(lips: Map<*, *>?): LipParams {
            if (lips == null) return DISABLED
            val hex = lips["color"] as? String ?: return DISABLED
            if (!HEX.matches(hex)) return DISABLED
            val opacity = unit(lips["opacity"]) ?: return DISABLED
            val rgb = hex.substring(1).toInt(16)
            val finish = FINISHES[lips["finish"] as? String] ?: NativeBridge.LIP_FINISH_SATIN
            return LipParams(
                enabled = opacity > 0f,
                r = ((rgb shr 16) and 0xFF) / 255f,
                g = ((rgb shr 8) and 0xFF) / 255f,
                b = (rgb and 0xFF) / 255f,
                opacity = opacity,
                finish = finish,
                gloss = unit(lips["gloss"]) ?: DEFAULT_GLOSS.getValue(finish),
                lumaFollow = unit(lips["lumaFollow"]) ?: DEFAULT_LUMA_FOLLOW,
            )
        }

        /** Número en [0, 1] (recortado); null si falta, no es número o es NaN. */
        private fun unit(value: Any?): Float? {
            val number = (value as? Number)?.toFloat() ?: return null
            if (number.isNaN()) return null
            return number.coerceIn(0f, 1f)
        }
    }
}
