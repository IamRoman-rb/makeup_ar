package com.makeupar.makeup_engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.util.Log
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.Environment
import com.google.ai.edge.litert.TensorBuffer
import java.io.ByteArrayInputStream

/**
 * Studio (F4): analiza una foto en el teléfono. Nada sale del dispositivo y
 * la foto no se guarda: se decodifica, se mide y se descarta; a Dart solo
 * vuelven números (docs/ar_engine/F4_PLAN.md).
 *
 * Bloqueante: el plugin lo corre en su propio hilo (prioridad de fondo),
 * nunca en el de UI ni en el de render. Los modelos (los mismos del tracker)
 * se cargan en CPU para no competir con la sesión de cámara por la GPU, y se
 * liberan al terminar. Con [cameraActive], un solo hilo de inferencia para
 * dejarle núcleos al tracker en vivo.
 */
internal class StillImageAnalyzer(private val context: Context, private val cameraActive: Boolean) {
    private val config = NativeBridge.nativeGetConfig()
    private val maxSide = config[NativeBridge.CONFIG_STILL_MAX_SIDE]
    private val detectorSize = config[NativeBridge.CONFIG_DETECTOR_INPUT_SIZE]
    private val landmarkSize = config[NativeBridge.CONFIG_LANDMARK_INPUT_SIZE]

    /** Medidas del look (CONFIG_LOOK_VALUE_COUNT floats), o null si la foto no se pudo leer. */
    fun analyzeFace(bytes: ByteArray): FloatArray? {
        val handle = decode(bytes, maxSide)?.let { NativeBridge.nativeStillCreate(it.argb, it.width, it.height) }
            ?: return null
        // Desde acá todo se libera en el finally, aunque falle la carga (también un Error).
        var environment: Environment? = null
        var detector: LoadedModel? = null
        var landmarker: LoadedModel? = null
        try {
            val env = Environment.create(context).also { environment = it }
            while (true) {
                when (NativeBridge.nativeStillStep(handle)) {
                    NativeBridge.STILL_DETECTOR -> {
                        val model = detector ?: load(env, ModelAssets.DETECTOR).also { detector = it }
                        runDetector(handle, model)
                    }
                    NativeBridge.STILL_LANDMARKS -> {
                        val model = landmarker ?: load(env, ModelAssets.LANDMARKS).also { landmarker = it }
                        runLandmarks(handle, model)
                    }
                    else -> break
                }
            }
            return NativeBridge.nativeStillAnalyze(handle)
        } finally {
            closeQuietly { detector?.close() }
            closeQuietly { landmarker?.close() }
            closeQuietly { environment?.close() }
            NativeBridge.nativeStillDestroy(handle)
        }
    }

    /** Paleta (r, g, b, fracción por swatch), o null si la foto no se pudo leer. */
    fun palette(bytes: ByteArray): FloatArray? {
        // La miniatura es de kPaletteMaxSide (96 px): no hace falta la foto a 1280.
        val pixels = decode(bytes, PALETTE_DECODE_SIDE) ?: return null
        return NativeBridge.nativeStillPalette(pixels.argb, pixels.width, pixels.height)
    }

    private class Pixels(val argb: IntArray, val width: Int, val height: Int)

    private class LoadedModel(
        val model: CompiledModel,
        val inputs: List<TensorBuffer>,
        val outputs: List<TensorBuffer>,
    ) {
        fun close() {
            inputs.forEach { closeQuietly { it.close() } }
            outputs.forEach { closeQuietly { it.close() } }
            closeQuietly { model.close() }
        }
    }

    private fun load(environment: Environment, name: String): LoadedModel {
        val options = CompiledModel.Options(Accelerator.CPU).apply {
            cpuOptions = CompiledModel.CpuOptions(numThreads = if (cameraActive) 1 else 2)
        }
        val model = CompiledModel.create(ModelAssets.file(context, name), options, environment)
        var inputs: List<TensorBuffer>? = null
        try {
            inputs = model.createInputBuffers()
            return LoadedModel(model, inputs, model.createOutputBuffers())
        } catch (e: Throwable) {
            inputs?.forEach { closeQuietly { it.close() } }
            closeQuietly { model.close() }
            throw e
        }
    }

    private fun runDetector(handle: Long, model: LoadedModel) {
        val input = FloatArray(detectorSize * detectorSize * 3)
        // BlazeFace espera la imagen en [-1, 1] (igual que LiteRtFaceTracker).
        if (!NativeBridge.nativeStillFillInput(handle, input, 2f, -1f)) {
            NativeBridge.nativeStillFail(handle, NativeBridge.STILL_STATUS_BAD_IMAGE)
            return
        }
        model.inputs[0].writeFloat(input)
        model.model.run(model.inputs, model.outputs)
        val first = model.outputs[0].readFloat()
        val second = model.outputs[1].readFloat()
        val regressors = if (first.size >= second.size) first else second
        val scores = if (first.size >= second.size) second else first
        NativeBridge.nativeStillSubmitDetections(handle, regressors, scores)
    }

    private fun runLandmarks(handle: Long, model: LoadedModel) {
        val input = FloatArray(landmarkSize * landmarkSize * 3)
        // FaceMesh-V2 espera la imagen en [0, 1].
        if (!NativeBridge.nativeStillFillInput(handle, input, 1f, 0f)) {
            NativeBridge.nativeStillFail(handle, NativeBridge.STILL_STATUS_BAD_IMAGE)
            return
        }
        model.inputs[0].writeFloat(input)
        model.model.run(model.inputs, model.outputs)
        var landmarks = FloatArray(0)
        var presenceLogit = Float.NEGATIVE_INFINITY
        for (output in model.outputs) {
            val values = output.readFloat()
            if (values.size > landmarks.size) {
                landmarks = values
            } else if (values.size == 1 && presenceLogit == Float.NEGATIVE_INFINITY) {
                presenceLogit = values[0]
            }
        }
        NativeBridge.nativeStillSubmitLandmarks(handle, landmarks, presenceLogit)
    }

    /**
     * JPEG/PNG/HEIF -> ARGB derecho (orientación EXIF aplicada) con el lado
     * mayor <= [side]. null si no se puede decodificar. Los bitmaps
     * intermedios se reciclan aunque algo falle.
     */
    private fun decode(bytes: ByteArray, side: Int): Pixels? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = StillImageMath.sampleSize(bounds.outWidth, bounds.outHeight, side)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
        var upright: Bitmap = decoded
        try {
            val scale = StillImageMath.scale(decoded.width, decoded.height, side)
            val matrix = orientationMatrix(exifOrientation(bytes)).apply { postScale(scale, scale) }
            if (!matrix.isIdentity) {
                upright = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                if (upright !== decoded) decoded.recycle()
            }
            val argb = IntArray(upright.width * upright.height)
            upright.getPixels(argb, 0, upright.width, 0, 0, upright.width, upright.height)
            return Pixels(argb, upright.width, upright.height)
        } finally {
            if (!decoded.isRecycled) decoded.recycle()
            if (!upright.isRecycled) upright.recycle()
        }
    }

    private fun exifOrientation(bytes: ByteArray): Int = try {
        ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
    } catch (e: Exception) {
        Log.w(TAG, "EXIF ilegible: ${e.message}")
        ExifInterface.ORIENTATION_NORMAL
    }

    private fun orientationMatrix(orientation: Int): Matrix = Matrix().apply {
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                postRotate(90f)
                postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                postRotate(-90f)
                postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(-90f)
        }
    }

    private companion object {
        const val TAG = "makeup_still"
        // Lado de la foto para la paleta: 4× la miniatura (kPaletteMaxSide = 96).
        const val PALETTE_DECODE_SIDE = 384

        /** Un cierre que falla no impide los siguientes (se registra y sigue). */
        inline fun closeQuietly(close: () -> Unit) {
            try {
                close()
            } catch (e: Throwable) {
                Log.w(TAG, "cierre fallido: ${e.message}")
            }
        }
    }
}

/** Cuentas de tamaño de la foto (sin Android: se prueban en la JVM). */
internal object StillImageMath {
    /** Mayor potencia de 2 que deja el lado mayor >= maxSide (BitmapFactory.inSampleSize). */
    fun sampleSize(width: Int, height: Int, maxSide: Int): Int {
        var sample = 1
        val longSide = maxOf(width, height)
        while (longSide / (sample * 2) >= maxSide) sample *= 2
        return sample
    }

    /** Escala final para que el lado mayor no pase de maxSide (1 si ya entra). */
    fun scale(width: Int, height: Int, maxSide: Int): Float {
        val longSide = maxOf(width, height)
        return if (longSide <= maxSide) 1f else maxSide.toFloat() / longSide
    }
}
