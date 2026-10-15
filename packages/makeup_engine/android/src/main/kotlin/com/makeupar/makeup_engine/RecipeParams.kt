package com.makeupar.makeup_engine

/**
 * Receta `makeup-recipe/2` (ya validada en Dart: RecipeValidator) llegada por
 * el canal como mapa, reducida a los parámetros que el motor dibuja: labios
 * (P4), rubor, piel (base, contorno, iluminador) y ojos (sombras, delineado)
 * (P5), pestañas y efectos procedurales (P6).
 *
 * Es la segunda línea de defensa: cualquier valor ausente, mal tipado o fuera
 * de rango se recorta o apaga la región, nunca rompe el render.
 */
internal data class RecipeParams(
    val lips: LipParams,
    val cheeks: CheekParams = CheekParams.DISABLED,
    val skin: SkinParams = SkinParams.DISABLED,
    val eyes: EyesParams = EyesParams.DISABLED,
    val effects: List<EffectParams> = EffectParams.NONE,
) {
    companion object {
        fun fromMap(recipe: Map<*, *>?): RecipeParams = RecipeParams(
            lips = LipParams.fromMap(recipe?.get("lips") as? Map<*, *>),
            cheeks = CheekParams.fromMap(recipe?.get("cheeks") as? Map<*, *>),
            skin = SkinParams.fromMap(recipe?.get("skin") as? Map<*, *>),
            eyes = EyesParams.fromMap(recipe?.get("eyes") as? Map<*, *>),
            effects = EffectParams.listFromRecipe(recipe?.get("effects") as? List<*>),
        )
    }
}

/**
 * Efecto procedural (P6): tipo NativeBridge.EFFECT_*, región
 * NativeBridge.EFFECT_REGION_*. Sin región, la del tipo: glitter en los ojos,
 * sheen y pecas en mejillas y nariz.
 */
internal data class EffectParams(val enabled: Boolean, val type: Int, val intensity: Float, val region: Int) {
    companion object {
        val DISABLED = EffectParams(false, NativeBridge.EFFECT_GLITTER, 0f, NativeBridge.EFFECT_REGION_EYES)

        /** Siempre NativeBridge.MAX_EFFECTS (los que faltan, apagados), en el orden de la receta. */
        val NONE: List<EffectParams> = List(NativeBridge.MAX_EFFECTS) { DISABLED }

        private val TYPES = mapOf(
            "freckles" to NativeBridge.EFFECT_FRECKLES,
            "glitter" to NativeBridge.EFFECT_GLITTER,
            "sheen" to NativeBridge.EFFECT_SHEEN,
        )
        private val REGIONS = mapOf(
            "cheeks_nose" to NativeBridge.EFFECT_REGION_CHEEKS_NOSE,
            "eyes" to NativeBridge.EFFECT_REGION_EYES,
            "lips" to NativeBridge.EFFECT_REGION_LIPS,
            "full_face" to NativeBridge.EFFECT_REGION_FULL_FACE,
        )

        fun fromMap(effect: Map<*, *>?): EffectParams {
            val type = TYPES[effect?.get("type") as? String] ?: return DISABLED
            val intensity = unit(effect?.get("intensity")) ?: return DISABLED
            if (intensity <= 0f) return DISABLED
            val region = REGIONS[effect?.get("region") as? String] ?: defaultRegion(type)
            return EffectParams(true, type, intensity, region)
        }

        fun listFromRecipe(effects: List<*>?): List<EffectParams> {
            val list = effects.orEmpty()
            return List(NativeBridge.MAX_EFFECTS) { i -> fromMap(list.getOrNull(i) as? Map<*, *>) }
        }

        private fun defaultRegion(type: Int): Int =
            if (type == NativeBridge.EFFECT_GLITTER) NativeBridge.EFFECT_REGION_EYES else NativeBridge.EFFECT_REGION_CHEEKS_NOSE
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
    /** Delineado de labios (`lips.liner`); apagado si falta o es inválido. */
    val liner: ColorParams = ColorParams.DISABLED,
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
        private const val DEFAULT_LUMA_FOLLOW = 0.8f
        private val FINISHES = mapOf(
            "matte" to NativeBridge.LIP_FINISH_MATTE,
            "satin" to NativeBridge.LIP_FINISH_SATIN,
            "gloss" to NativeBridge.LIP_FINISH_GLOSS,
            "shimmer" to NativeBridge.LIP_FINISH_SHIMMER,
        )

        /** Sin `lips`, sin color válido o sin opacidad: labial apagado. */
        fun fromMap(lips: Map<*, *>?): LipParams {
            val color = ColorParams.fromMap(lips, "opacity")
            if (!color.enabled || lips == null) return DISABLED
            val finish = FINISHES[lips["finish"] as? String] ?: NativeBridge.LIP_FINISH_SATIN
            return LipParams(
                enabled = true,
                r = color.r,
                g = color.g,
                b = color.b,
                opacity = color.amount,
                finish = finish,
                gloss = unit(lips["gloss"]) ?: DEFAULT_GLOSS.getValue(finish),
                lumaFollow = unit(lips["lumaFollow"]) ?: DEFAULT_LUMA_FOLLOW,
                liner = ColorParams.fromMap(lips["liner"] as? Map<*, *>, "opacity"),
            )
        }
    }
}

/** Color sRGB [0,1] de una región con su intensidad (opacidad o coverage). */
internal data class ColorParams(
    val enabled: Boolean,
    val r: Float,
    val g: Float,
    val b: Float,
    val amount: Float,
) {
    companion object {
        val DISABLED = ColorParams(false, 0f, 0f, 0f, 0f)
        private val HEX = Regex("^#[0-9A-Fa-f]{6}$")

        /** Apagado si falta el mapa, el color no es HEX o [amountKey] no es un número > 0. */
        fun fromMap(map: Map<*, *>?, amountKey: String): ColorParams {
            if (map == null) return DISABLED
            val hex = map["color"] as? String ?: return DISABLED
            if (!HEX.matches(hex)) return DISABLED
            val amount = unit(map[amountKey]) ?: return DISABLED
            if (amount <= 0f) return DISABLED
            val rgb = hex.substring(1).toInt(16)
            return ColorParams(
                enabled = true,
                r = ((rgb shr 16) and 0xFF) / 255f,
                g = ((rgb shr 8) and 0xFF) / 255f,
                b = (rgb and 0xFF) / 255f,
                amount = amount,
            )
        }
    }
}

/** Rubor: placement NativeBridge.CHEEK_*. */
internal data class CheekParams(val color: ColorParams, val spread: Float, val placement: Int) {
    companion object {
        private const val DEFAULT_SPREAD = 0.5f
        val DISABLED = CheekParams(ColorParams.DISABLED, DEFAULT_SPREAD, NativeBridge.CHEEK_APPLE)
        private val PLACEMENTS = mapOf(
            "apple" to NativeBridge.CHEEK_APPLE,
            "high" to NativeBridge.CHEEK_HIGH,
            "low" to NativeBridge.CHEEK_LOW,
        )

        fun fromMap(cheeks: Map<*, *>?): CheekParams {
            val color = ColorParams.fromMap(cheeks, "opacity")
            if (!color.enabled || cheeks == null) return DISABLED
            return CheekParams(
                color = color,
                spread = unit(cheeks["spread"]) ?: DEFAULT_SPREAD,
                placement = PLACEMENTS[cheeks["placement"] as? String] ?: NativeBridge.CHEEK_APPLE,
            )
        }
    }
}

/** Base (coverage), contorno e iluminador (opacidad). */
internal data class SkinParams(val foundation: ColorParams, val contour: ColorParams, val highlight: ColorParams) {
    /** En el orden de NativeBridge.SKIN_*. */
    val layers: List<ColorParams> get() = listOf(foundation, contour, highlight)

    companion object {
        val DISABLED = SkinParams(ColorParams.DISABLED, ColorParams.DISABLED, ColorParams.DISABLED)

        fun fromMap(skin: Map<*, *>?): SkinParams {
            if (skin == null) return DISABLED
            return SkinParams(
                foundation = ColorParams.fromMap(skin["foundation"] as? Map<*, *>, "coverage"),
                contour = ColorParams.fromMap(skin["contour"] as? Map<*, *>, "opacity"),
                highlight = ColorParams.fromMap(skin["highlight"] as? Map<*, *>, "opacity"),
            )
        }
    }
}

/** Sombra: región NativeBridge.EYE_REGION_*, acabado NativeBridge.SHADOW_FINISH_*. */
internal data class ShadowParams(val color: ColorParams, val region: Int, val finish: Int) {
    companion object {
        val DISABLED = ShadowParams(ColorParams.DISABLED, NativeBridge.EYE_REGION_LID, NativeBridge.SHADOW_FINISH_MATTE)
        private val REGIONS = mapOf(
            "lid" to NativeBridge.EYE_REGION_LID,
            "crease" to NativeBridge.EYE_REGION_CREASE,
            "outer_v" to NativeBridge.EYE_REGION_OUTER_V,
            "inner_corner" to NativeBridge.EYE_REGION_INNER_CORNER,
            "brow_bone" to NativeBridge.EYE_REGION_BROW_BONE,
        )
        private val FINISHES = mapOf(
            "matte" to NativeBridge.SHADOW_FINISH_MATTE,
            "satin" to NativeBridge.SHADOW_FINISH_SATIN,
            "shimmer" to NativeBridge.SHADOW_FINISH_SHIMMER,
        )

        /** La región es obligatoria: sin una válida, la sombra se apaga. */
        fun fromMap(shadow: Map<*, *>?): ShadowParams {
            val color = ColorParams.fromMap(shadow, "opacity")
            val region = REGIONS[shadow?.get("region") as? String]
            if (!color.enabled || region == null || shadow == null) return DISABLED
            val finish = FINISHES[shadow["finish"] as? String] ?: NativeBridge.SHADOW_FINISH_MATTE
            return ShadowParams(color, region, finish)
        }
    }
}

internal data class LinerParams(val color: ColorParams, val thickness: Float, val wing: Float) {
    companion object {
        private const val DEFAULT_THICKNESS = 0.5f
        val DISABLED = LinerParams(ColorParams.DISABLED, DEFAULT_THICKNESS, 0f)

        fun fromMap(liner: Map<*, *>?): LinerParams {
            val color = ColorParams.fromMap(liner, "opacity")
            if (!color.enabled || liner == null) return DISABLED
            return LinerParams(color, unit(liner["thickness"]) ?: DEFAULT_THICKNESS, unit(liner["wing"]) ?: 0f)
        }
    }
}

/** Pestañas (P6): sin color en la receta (el motor usa un negro de máscara). */
internal data class LashParams(val enabled: Boolean, val opacity: Float, val length: Float, val volume: Float) {
    companion object {
        private const val DEFAULT_LENGTH = 0.5f
        private const val DEFAULT_VOLUME = 0.5f
        val DISABLED = LashParams(false, 0f, DEFAULT_LENGTH, DEFAULT_VOLUME)

        /** Sin opacidad numérica > 0: apagadas. */
        fun fromMap(lashes: Map<*, *>?): LashParams {
            val opacity = unit(lashes?.get("opacity")) ?: return DISABLED
            if (opacity <= 0f || lashes == null) return DISABLED
            return LashParams(
                enabled = true,
                opacity = opacity,
                length = unit(lashes["length"]) ?: DEFAULT_LENGTH,
                volume = unit(lashes["volume"]) ?: DEFAULT_VOLUME,
            )
        }
    }
}

/** Siempre NativeBridge.MAX_EYE_SHADOWS sombras (las que faltan, apagadas), en el orden de la receta. */
internal data class EyesParams(
    val shadows: List<ShadowParams>,
    val liner: LinerParams,
    val lashes: LashParams = LashParams.DISABLED,
    val iris: ColorParams = ColorParams.DISABLED,
) {
    companion object {
        val DISABLED = EyesParams(List(NativeBridge.MAX_EYE_SHADOWS) { ShadowParams.DISABLED }, LinerParams.DISABLED)

        fun fromMap(eyes: Map<*, *>?): EyesParams {
            if (eyes == null) return DISABLED
            val list = (eyes["shadow"] as? List<*>).orEmpty()
            val shadows = List(NativeBridge.MAX_EYE_SHADOWS) { i -> ShadowParams.fromMap(list.getOrNull(i) as? Map<*, *>) }
            return EyesParams(
                shadows,
                LinerParams.fromMap(eyes["liner"] as? Map<*, *>),
                LashParams.fromMap(eyes["lashes"] as? Map<*, *>),
                ColorParams.fromMap(eyes["iris"] as? Map<*, *>, "opacity"),
            )
        }
    }
}

/** Número en [0, 1] (recortado); null si falta, no es número o es NaN. */
private fun unit(value: Any?): Float? {
    val number = (value as? Number)?.toFloat() ?: return null
    if (number.isNaN()) return null
    return number.coerceIn(0f, 1f)
}
