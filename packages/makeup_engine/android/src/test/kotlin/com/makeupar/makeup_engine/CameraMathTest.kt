package com.makeupar.makeup_engine

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class CameraMathTest {
    private fun assertUv(expected: Pair<Float, Float>, actual: Pair<Float, Float>) {
        assertTrue(
            abs(expected.first - actual.first) < 1e-6f && abs(expected.second - actual.second) < 1e-6f,
            "esperado $expected, obtenido $actual",
        )
    }

    @Test
    fun `elige el mayor tamaño que entra en el límite`() {
        val sizes = listOf(PixelSize(2592, 1944), PixelSize(1920, 1080), PixelSize(1280, 720), PixelSize(960, 720), PixelSize(640, 480))
        assertEquals(PixelSize(1280, 720), CameraMath.choosePreviewSize(sizes, 1280, 720))
        assertEquals(PixelSize(640, 480), CameraMath.choosePreviewSize(sizes, 800, 600))
    }

    @Test
    fun `si nada entra elige el menor, nunca el máximo del sensor`() {
        val sizes = listOf(PixelSize(4000, 3000), PixelSize(1920, 1440))
        assertEquals(PixelSize(1920, 1440), CameraMath.choosePreviewSize(sizes, 1280, 720))
        assertEquals(null, CameraMath.choosePreviewSize(emptyList(), 1280, 720))
    }

    @Test
    fun `rango de fps prefiere techo exacto con piso alto`() {
        val ranges = listOf(15..15, 7..30, 15..30, 30..30, 24..24)
        assertEquals(30..30, CameraMath.chooseFpsRange(ranges, 30))
        assertEquals(15..30, CameraMath.chooseFpsRange(listOf(7..30, 15..30), 30))
        assertEquals(10..60, CameraMath.chooseFpsRange(listOf(15..15, 10..60), 30))
        assertEquals(24..24, CameraMath.chooseFpsRange(listOf(15..15, 24..24), 30))
        assertEquals(null, CameraMath.chooseFpsRange(emptyList(), 30))
    }

    @Test
    fun `rotación de imagen según Camera2`() {
        assertEquals(270, CameraMath.imageRotation(270, 0, frontFacing = true))
        assertEquals(0, CameraMath.imageRotation(270, 90, frontFacing = true))
        assertEquals(90, CameraMath.imageRotation(90, 0, frontFacing = false))
        assertEquals(0, CameraMath.imageRotation(90, 90, frontFacing = false))
    }

    @Test
    fun `la salida intercambia lados con 90 y 270 grados`() {
        val preview = PixelSize(1280, 720)
        assertEquals(PixelSize(720, 1280), CameraMath.outputSize(preview, 90))
        assertEquals(PixelSize(720, 1280), CameraMath.outputSize(preview, 270))
        assertEquals(preview, CameraMath.outputSize(preview, 180))
    }

    @Test
    fun `matriz identidad sin rotación ni espejo`() {
        val m = CameraMath.displayMatrix(0, mirror = false)
        assertUv(0f to 0f, CameraMath.apply(m, 0f, 0f))
        assertUv(1f to 1f, CameraMath.apply(m, 1f, 1f))
        assertUv(0.25f to 0.75f, CameraMath.apply(m, 0.25f, 0.75f))
    }

    @Test
    fun `el espejo invierte solo el eje horizontal`() {
        val m = CameraMath.displayMatrix(0, mirror = true)
        assertUv(1f to 0f, CameraMath.apply(m, 0f, 0f))
        assertUv(0.25f to 0.5f, CameraMath.apply(m, 0.75f, 0.5f))
    }

    @Test
    fun `las rotaciones llevan esquinas a esquinas y conservan el centro`() {
        for (degrees in listOf(0, 90, 180, 270)) {
            for (mirror in listOf(false, true)) {
                val m = CameraMath.displayMatrix(degrees, mirror)
                assertUv(0.5f to 0.5f, CameraMath.apply(m, 0.5f, 0.5f))
                val corners = listOf(0f to 0f, 1f to 0f, 0f to 1f, 1f to 1f)
                val mapped = corners.map { (u, v) -> CameraMath.apply(m, u, v) }
                for (point in mapped) {
                    assertTrue(corners.any { abs(it.first - point.first) < 1e-6f && abs(it.second - point.second) < 1e-6f }, "$degrees/$mirror: $point")
                }
                assertEquals(4, mapped.map { "%.3f,%.3f".format(it.first, it.second) }.toSet().size)
            }
        }
    }

    @Test
    fun `90 grados rota en sentido antihorario en espacio UV`() {
        val m = CameraMath.displayMatrix(90, mirror = false)
        // (1, 0.5) -> (0.5, 1): el borde derecho de la salida muestrea el borde superior de la cámara.
        assertUv(0.5f to 1f, CameraMath.apply(m, 1f, 0.5f))
    }

    @Test
    fun `rechaza rotaciones que no son múltiplos de 90`() {
        assertFailsWith<IllegalArgumentException> { CameraMath.displayMatrix(45, mirror = false) }
    }
}
