package com.makeupar.makeup_engine

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RecipeParamsTest {
    private fun assertNear(expected: Float, actual: Float) {
        assertTrue(abs(expected - actual) < 1e-6f, "esperado $expected, obtenido $actual")
    }

    @Test
    fun `labial completo de un preset`() {
        val recipe = mapOf(
            "schema" to "makeup-recipe/2",
            "name" to "Rojo clásico",
            "lips" to mapOf("color" to "#B3122D", "opacity" to 0.85, "finish" to "gloss", "gloss" to 0.6, "lumaFollow" to 0.35),
            "cheeks" to mapOf("color" to "#E8837A", "opacity" to 0.28),
        )
        val lips = RecipeParams.fromMap(recipe).lips
        assertTrue(lips.enabled)
        assertNear(0xB3 / 255f, lips.r)
        assertNear(0x12 / 255f, lips.g)
        assertNear(0x2D / 255f, lips.b)
        assertNear(0.85f, lips.opacity)
        assertEquals(NativeBridge.LIP_FINISH_GLOSS, lips.finish)
        assertNear(0.6f, lips.gloss)
        assertNear(0.35f, lips.lumaFollow)
    }

    @Test
    fun `valores por defecto según el acabado`() {
        val matte = LipParams.fromMap(mapOf("color" to "#3B0A1E", "opacity" to 0.9, "finish" to "matte"))
        assertEquals(NativeBridge.LIP_FINISH_MATTE, matte.finish)
        assertNear(0f, matte.gloss)
        assertNear(0.8f, matte.lumaFollow)
        val noFinish = LipParams.fromMap(mapOf("color" to "#3B0A1E", "opacity" to 1))
        assertEquals(NativeBridge.LIP_FINISH_SATIN, noFinish.finish)
        assertNear(0.3f, noFinish.gloss)
        val shimmer = LipParams.fromMap(mapOf("color" to "#3B0A1E", "opacity" to 1, "finish" to "shimmer"))
        assertNear(0.5f, shimmer.gloss)
    }

    @Test
    fun `fuera de rango se recorta y lo inválido apaga el labial`() {
        val clamped = LipParams.fromMap(mapOf("color" to "#ffffff", "opacity" to 3.5, "gloss" to -1, "finish" to "neon"))
        assertNear(1f, clamped.opacity)
        assertNear(0f, clamped.gloss)
        assertEquals(NativeBridge.LIP_FINISH_SATIN, clamped.finish)

        assertFalse(LipParams.fromMap(null).enabled)
        assertFalse(LipParams.fromMap(mapOf("color" to "rojo", "opacity" to 0.5)).enabled)
        assertFalse(LipParams.fromMap(mapOf("color" to "#B3122D")).enabled)
        assertFalse(LipParams.fromMap(mapOf("color" to "#B3122D", "opacity" to "0.5")).enabled)
        assertFalse(LipParams.fromMap(mapOf("color" to "#B3122D", "opacity" to Double.NaN)).enabled)
        assertFalse(LipParams.fromMap(mapOf("color" to "#B3122D", "opacity" to 0)).enabled)
        assertFalse(RecipeParams.fromMap(mapOf("name" to "sin labios")).lips.enabled)
        assertFalse(RecipeParams.fromMap(null).lips.enabled)
    }

    @Test
    fun `rubor, piel y ojos de un preset`() {
        val recipe = mapOf(
            "schema" to "makeup-recipe/2",
            "name" to "Glam dorado",
            "cheeks" to mapOf("color" to "#D9826B", "opacity" to 0.3, "spread" to 0.6, "placement" to "high"),
            "skin" to mapOf(
                "foundation" to mapOf("color" to "#D9A98B", "coverage" to 0.35),
                "highlight" to mapOf("color" to "#F6E3C2", "opacity" to 0.35),
            ),
            "eyes" to mapOf(
                "shadow" to listOf(
                    mapOf("color" to "#C9A15A", "opacity" to 0.5, "region" to "lid", "finish" to "shimmer"),
                    mapOf("color" to "#6B4423", "opacity" to 0.45, "region" to "crease"),
                    mapOf("color" to "#F1D9A6", "opacity" to 0.4, "region" to "inner_corner", "finish" to "satin"),
                ),
                "liner" to mapOf("color" to "#2A1A12", "opacity" to 0.85, "thickness" to 0.4, "wing" to 0.3),
            ),
        )
        val params = RecipeParams.fromMap(recipe)
        assertFalse(params.lips.enabled)
        assertTrue(params.cheeks.color.enabled)
        assertNear(0.3f, params.cheeks.color.amount)
        assertNear(0.6f, params.cheeks.spread)
        assertEquals(NativeBridge.CHEEK_HIGH, params.cheeks.placement)
        assertNear(0.35f, params.skin.foundation.amount)
        assertFalse(params.skin.contour.enabled)
        assertTrue(params.skin.highlight.enabled)
        assertEquals(3, params.skin.layers.size)

        val shadows = params.eyes.shadows
        assertEquals(NativeBridge.MAX_EYE_SHADOWS, shadows.size)
        assertEquals(NativeBridge.EYE_REGION_LID, shadows[0].region)
        assertEquals(NativeBridge.SHADOW_FINISH_SHIMMER, shadows[0].finish)
        assertEquals(NativeBridge.EYE_REGION_CREASE, shadows[1].region)
        assertEquals(NativeBridge.SHADOW_FINISH_MATTE, shadows[1].finish)
        assertEquals(NativeBridge.EYE_REGION_INNER_CORNER, shadows[2].region)
        assertFalse(shadows[3].color.enabled)
        assertFalse(params.eyes.lashes.enabled)  // la receta de este test no trae pestañas
        val liner = params.eyes.liner
        assertNear(0x2A / 255f, liner.color.r)
        assertNear(0.4f, liner.thickness)
        assertNear(0.3f, liner.wing)
    }

    @Test
    fun `pestañas con valores por defecto y recorte`() {
        val lashes = LashParams.fromMap(mapOf("opacity" to 0.85, "length" to 0.6, "volume" to 1.7))
        assertTrue(lashes.enabled)
        assertNear(0.85f, lashes.opacity)
        assertNear(0.6f, lashes.length)
        assertNear(1f, lashes.volume)
        val defaults = LashParams.fromMap(mapOf("opacity" to 0.5))
        assertNear(0.5f, defaults.length)
        assertNear(0.5f, defaults.volume)
        assertFalse(LashParams.fromMap(mapOf("opacity" to 0)).enabled)
        assertFalse(LashParams.fromMap(mapOf("length" to 0.5)).enabled)
        assertFalse(LashParams.fromMap(null).enabled)
        val eyes = RecipeParams.fromMap(mapOf("eyes" to mapOf("lashes" to mapOf("opacity" to 0.9, "volume" to 0.8)))).eyes
        assertTrue(eyes.lashes.enabled)
        assertNear(0.8f, eyes.lashes.volume)
    }

    @Test
    fun `regiones inválidas se apagan sin romper el resto`() {
        val params = RecipeParams.fromMap(
            mapOf(
                "cheeks" to mapOf("color" to "#D9826B", "opacity" to 0.3, "placement" to "frente"),
                "skin" to mapOf("foundation" to mapOf("color" to "#D9A98B", "opacity" to 0.5)),  // sin coverage
                "eyes" to mapOf(
                    "shadow" to listOf(
                        mapOf("color" to "#C9A15A", "opacity" to 0.5, "region" to "nariz"),
                        "no es un mapa",
                        mapOf("color" to "#6B4423", "opacity" to 0.45, "region" to "brow_bone", "finish" to "neon"),
                        mapOf("color" to "#6B4423", "opacity" to 0.2, "region" to "outer_v"),
                        mapOf("color" to "#6B4423", "opacity" to 0.2, "region" to "lid"),  // quinta: se ignora
                    ),
                    "liner" to mapOf("color" to "negro", "opacity" to 1),
                ),
            ),
        )
        assertEquals(NativeBridge.CHEEK_APPLE, params.cheeks.placement)
        assertNear(0.5f, params.cheeks.spread)
        assertFalse(params.skin.foundation.enabled)
        val shadows = params.eyes.shadows
        assertEquals(NativeBridge.MAX_EYE_SHADOWS, shadows.size)
        assertFalse(shadows[0].color.enabled)
        assertFalse(shadows[1].color.enabled)
        assertEquals(NativeBridge.EYE_REGION_BROW_BONE, shadows[2].region)
        assertEquals(NativeBridge.SHADOW_FINISH_MATTE, shadows[2].finish)
        assertEquals(NativeBridge.EYE_REGION_OUTER_V, shadows[3].region)
        assertFalse(params.eyes.liner.color.enabled)
    }
}
