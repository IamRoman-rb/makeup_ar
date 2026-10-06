package com.makeupar.makeup_engine

import kotlin.math.max
import kotlin.math.min

/** Tamaño en píxeles, en la orientación del sensor (ancho = lado largo en general). */
internal data class PixelSize(val width: Int, val height: Int) {
    val area: Long get() = width.toLong() * height
}

/**
 * Decisiones puras (sin APIs de Android) sobre la cámara, para poder testearlas
 * en la JVM.
 */
internal object CameraMath {
    /**
     * Elige el tamaño de mayor área que entre en [maxLongSide] x [maxShortSide].
     * Si ninguno entra, el de menor área (nunca el máximo del sensor).
     */
    fun choosePreviewSize(sizes: List<PixelSize>, maxLongSide: Int, maxShortSide: Int): PixelSize? {
        if (sizes.isEmpty()) return null
        val fitting = sizes.filter {
            max(it.width, it.height) <= maxLongSide && min(it.width, it.height) <= maxShortSide
        }
        return fitting.maxByOrNull { it.area } ?: sizes.minByOrNull { it.area }
    }

    /**
     * Rango de AE para la vista previa. Prefiere un techo igual a [targetFps] con
     * el piso más alto (p. ej. [30, 30]): fps estable para medir. Si no hay techo
     * exacto, el menor techo por encima del objetivo; si tampoco, el mayor techo.
     */
    fun chooseFpsRange(ranges: List<IntRange>, targetFps: Int): IntRange? {
        if (ranges.isEmpty()) return null
        ranges.filter { it.last == targetFps }.maxByOrNull { it.first }?.let { return it }
        ranges.filter { it.last > targetFps }.minByOrNull { it.last }?.let { return it }
        return ranges.maxByOrNull { it.last }
    }

    /**
     * Grados que hay que rotar la imagen del sensor para verla derecha en una
     * pantalla girada [displayRotationDegrees] (0, 90, 180, 270). Fórmula de la
     * documentación de Camera2; la cámara frontal suma porque está espejada.
     */
    fun imageRotation(sensorOrientation: Int, displayRotationDegrees: Int, frontFacing: Boolean): Int =
        if (frontFacing) {
            (sensorOrientation + displayRotationDegrees) % 360
        } else {
            (sensorOrientation - displayRotationDegrees + 360) % 360
        }

    /** Tamaño de la salida: si la imagen se rota 90° o 270°, se intercambian lados. */
    fun outputSize(preview: PixelSize, rotationDegrees: Int): PixelSize =
        if (rotationDegrees % 180 == 0) preview else PixelSize(preview.height, preview.width)

    /**
     * Matriz 4x4 column-major (uDisplayMatrix de camera_quad.vert) que lleva un
     * UV de salida [0,1] al UV de la imagen de cámara: espejo horizontal (cámara
     * frontal, efecto espejo) y luego rotación de [rotationDegrees] alrededor
     * del centro. Solo múltiplos de 90°, con senos y cosenos exactos.
     */
    fun displayMatrix(rotationDegrees: Int, mirror: Boolean): FloatArray {
        val (c, s) = when (((rotationDegrees % 360) + 360) % 360) {
            0 -> 1f to 0f
            90 -> 0f to 1f
            180 -> -1f to 0f
            270 -> 0f to -1f
            else -> throw IllegalArgumentException("rotación no múltiplo de 90: $rotationDegrees")
        }
        val fx = if (mirror) -1f else 1f
        // camUv = R * F * (outUv - 0.5) + 0.5
        val m = FloatArray(16)
        m[0] = c * fx
        m[1] = s * fx
        m[4] = -s
        m[5] = c
        m[10] = 1f
        m[12] = 0.5f - 0.5f * (c * fx - s)
        m[13] = 0.5f - 0.5f * (s * fx + c)
        m[15] = 1f
        return m
    }

    /** Aplica [displayMatrix] a un UV (para tests y depuración). */
    fun apply(matrix: FloatArray, u: Float, v: Float): Pair<Float, Float> =
        Pair(matrix[0] * u + matrix[4] * v + matrix[12], matrix[1] * u + matrix[5] * v + matrix[13])
}
