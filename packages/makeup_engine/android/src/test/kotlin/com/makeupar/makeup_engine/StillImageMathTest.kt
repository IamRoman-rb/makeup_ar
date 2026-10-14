package com.makeupar.makeup_engine

import kotlin.test.Test
import kotlin.test.assertEquals

class StillImageMathTest {
    @Test
    fun `submuestreo por potencias de 2 sin bajar del máximo`() {
        assertEquals(1, StillImageMath.sampleSize(1280, 960, 1280))
        assertEquals(1, StillImageMath.sampleSize(2000, 1500, 1280))
        assertEquals(2, StillImageMath.sampleSize(2560, 1920, 1280))
        assertEquals(2, StillImageMath.sampleSize(4000, 3000, 1280))
        assertEquals(4, StillImageMath.sampleSize(3000, 6000, 1280))
        assertEquals(1, StillImageMath.sampleSize(640, 480, 1280))
    }

    @Test
    fun `escala final al lado máximo`() {
        assertEquals(1f, StillImageMath.scale(1280, 720, 1280))
        assertEquals(1f, StillImageMath.scale(640, 480, 1280))
        assertEquals(0.64f, StillImageMath.scale(2000, 1500, 1280))
        assertEquals(0.64f, StillImageMath.scale(1500, 2000, 1280))
    }
}
