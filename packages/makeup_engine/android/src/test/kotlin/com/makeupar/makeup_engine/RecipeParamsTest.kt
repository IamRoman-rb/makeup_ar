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
        assertNear(0.3f, matte.lumaFollow)
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
}
