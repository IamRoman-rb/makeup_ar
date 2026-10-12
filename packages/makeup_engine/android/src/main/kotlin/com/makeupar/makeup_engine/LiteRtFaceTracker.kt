package com.makeupar.makeup_engine

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.util.Log
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.Environment
import com.google.ai.edge.litert.TensorBuffer
import java.io.File

/**
 * Tracker con los modelos de MediaPipe (BlazeFace + FaceMesh-V2) sobre LiteRT.
 *
 * Hilo "makeup-tracker": carga, inferencia y liberación. Cada modelo se carga
 * en GPU con caché de programas en disco (la primera vez tarda ~5 s en el E20;
 * después debería bajar) y, si la GPU falla, en CPU.
 *
 * Por inferencia: el recorte se convierte a float en C++ sobre un FloatArray
 * reutilizado; readFloat() aloca la salida (API de LiteRT, ~6 KB para
 * landmarks): se acepta porque es este hilo, no el de render.
 */
internal class LiteRtFaceTracker(
    private val context: Context,
    private val nativeHandle: Long,
) : FaceTracker {
    private val thread = HandlerThread("makeup-tracker", Process.THREAD_PRIORITY_DEFAULT).apply { start() }
    private val handler = Handler(thread.looper)
    private val mainHandler = Handler(Looper.getMainLooper())
    // Preasignado: onCropReady() corre en el hilo de render y no debe alocar.
    private val processRunnable = Runnable { process() }

    private val config = NativeBridge.nativeGetConfig()
    private val detectorSize = config[NativeBridge.CONFIG_DETECTOR_INPUT_SIZE]
    private val landmarkSize = config[NativeBridge.CONFIG_LANDMARK_INPUT_SIZE]

    // Solo hilo del tracker.
    private val detectorInput = FloatArray(detectorSize * detectorSize * 3)
    private val landmarkInput = FloatArray(landmarkSize * landmarkSize * 3)
    private var environment: Environment? = null
    private var detector: LoadedModel? = null
    private var landmarker: LoadedModel? = null
    private var enabled = false
    private var running = false
    private var consecutiveErrors = 0

    @Volatile private var released = false
    @Volatile override var backend: String? = null
        private set
    @Volatile override var error: String? = null
        private set
    @Volatile override var initMs: Double = Double.NaN
        private set

    private class LoadedModel(
        val model: CompiledModel,
        val inputs: List<TensorBuffer>,
        val outputs: List<TensorBuffer>,
        val backend: String,
    ) {
        fun close() {
            inputs.forEach { it.close() }
            outputs.forEach { it.close() }
            model.close()
        }
    }

    override fun start() {
        handler.post { load() }
    }

    override fun onCropReady() {
        handler.post(processRunnable)
    }

    override fun setEnabled(enabled: Boolean) {
        handler.post {
            this.enabled = enabled
            syncRunning()
        }
    }

    override fun release(onReleased: () -> Unit) {
        released = true
        val posted = handler.post {
            if (running) NativeBridge.nativeTrackerStop(nativeHandle)
            running = false
            detector?.close()
            landmarker?.close()
            detector = null
            landmarker = null
            environment?.close()
            environment = null
            thread.quitSafely()
            mainHandler.post(onReleased)
        }
        if (!posted) mainHandler.post(onReleased)
    }

    /** Hilo del tracker. */
    private fun load() {
        if (released) return
        val start = System.nanoTime()
        try {
            val env = Environment.create(context)
            environment = env
            val cacheDir = File(context.cacheDir, "litert_gpu").apply { mkdirs() }.absolutePath
            detector = loadModel(env, ModelAssets.DETECTOR, cacheDir)
            landmarker = loadModel(env, ModelAssets.LANDMARKS, cacheDir)
            initMs = (System.nanoTime() - start) / 1e6
            backend = "detector=${detector?.backend} landmarks=${landmarker?.backend}"
            Log.i(TAG, "modelos listos en ${"%.0f".format(initMs)} ms: $backend")
            syncRunning()
        } catch (e: Exception) {
            error = "no se pudieron cargar los modelos: ${e.javaClass.simpleName}: ${e.message}"
            Log.e(TAG, error, e)
        }
    }

    /** GPU con caché de programas; si falla, CPU. */
    private fun loadModel(env: Environment, name: String, cacheDir: String): LoadedModel {
        val path = ModelAssets.file(context, name)
        val gpu = CompiledModel.Options(Accelerator.GPU).apply {
            gpuOptions = CompiledModel.GpuOptions(
                serializationDir = cacheDir,
                modelCacheKey = "$name-litert-$LITERT_VERSION",
                serializeProgramCache = true,
            )
        }
        val gpuFailure = try {
            return createLoaded(path, gpu, env, "gpu")
        } catch (e: Exception) {
            e
        }
        Log.w(TAG, "$name en GPU falló, uso CPU: ${gpuFailure.message}")
        val cpu = CompiledModel.Options(Accelerator.CPU).apply {
            cpuOptions = CompiledModel.CpuOptions(numThreads = CPU_THREADS)
        }
        return createLoaded(path, cpu, env, "cpu")
    }

    private fun createLoaded(path: String, options: CompiledModel.Options, env: Environment, label: String): LoadedModel {
        val model = CompiledModel.create(path, options, env)
        try {
            return LoadedModel(model, model.createInputBuffers(), model.createOutputBuffers(), label)
        } catch (e: Exception) {
            model.close()
            throw e
        }
    }

    /** Hilo del tracker. Arranca o frena el pedido de recortes según [enabled]. */
    private fun syncRunning() {
        if (released || detector == null || landmarker == null) return
        if (enabled && !running) {
            NativeBridge.nativeTrackerStart(nativeHandle)
            running = true
        } else if (!enabled && running) {
            NativeBridge.nativeTrackerStop(nativeHandle)
            running = false
        }
    }

    /** Hilo del tracker: un recorte listo -> inferencia -> salidas al núcleo. */
    private fun process() {
        if (released || !running) return
        try {
            when (NativeBridge.nativeTrackerReadyKind(nativeHandle)) {
                NativeBridge.CROP_DETECTOR -> runDetector()
                NativeBridge.CROP_LANDMARKS -> runLandmarks()
            }
            consecutiveErrors = 0
        } catch (e: Exception) {
            // El recorte quedó tomado: reiniciar el ciclo (vuelve a buscar la cara).
            error = "inferencia: ${e.javaClass.simpleName}: ${e.message}"
            Log.e(TAG, error, e)
            NativeBridge.nativeTrackerStop(nativeHandle)
            if (++consecutiveErrors < MAX_CONSECUTIVE_ERRORS) {
                NativeBridge.nativeTrackerStart(nativeHandle)
            } else {
                running = false
            }
        }
    }

    private fun runDetector() {
        val model = detector ?: return
        val start = System.nanoTime()
        // BlazeFace espera la imagen en [-1, 1].
        if (!NativeBridge.nativeTrackerFillInput(nativeHandle, detectorInput, 2f, -1f)) return
        model.inputs[0].writeFloat(detectorInput)
        model.model.run(model.inputs, model.outputs)
        val first = model.outputs[0].readFloat()
        val second = model.outputs[1].readFloat()
        // regressors (896×16) es la salida grande; classificators (896), la chica.
        val regressors = if (first.size >= second.size) first else second
        val scores = if (first.size >= second.size) second else first
        val ms = ((System.nanoTime() - start) / 1e6).toFloat()
        NativeBridge.nativeTrackerSubmitDetections(nativeHandle, regressors, scores, ms)
    }

    private fun runLandmarks() {
        val model = landmarker ?: return
        val start = System.nanoTime()
        // FaceMesh-V2 espera la imagen en [0, 1].
        if (!NativeBridge.nativeTrackerFillInput(nativeHandle, landmarkInput, 1f, 0f)) return
        model.inputs[0].writeFloat(landmarkInput)
        model.model.run(model.inputs, model.outputs)
        var landmarks = EMPTY
        var presenceLogit = Float.NEGATIVE_INFINITY
        for (output in model.outputs) {
            val values = output.readFloat()
            if (values.size > landmarks.size) {
                landmarks = values
            } else if (values.size == 1 && presenceLogit == Float.NEGATIVE_INFINITY) {
                presenceLogit = values[0]
            }
        }
        val ms = ((System.nanoTime() - start) / 1e6).toFloat()
        NativeBridge.nativeTrackerSubmitLandmarks(nativeHandle, landmarks, presenceLogit, ms)
    }

    private companion object {
        const val TAG = "makeup_tracker"
        const val LITERT_VERSION = "2.3.0"
        const val CPU_THREADS = 2
        const val MAX_CONSECUTIVE_ERRORS = 5
        val EMPTY = FloatArray(0)
    }
}
