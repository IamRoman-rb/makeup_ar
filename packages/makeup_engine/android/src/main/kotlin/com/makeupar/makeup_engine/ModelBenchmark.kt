package com.makeupar.makeup_engine

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.Environment
import java.io.File

/** Resultado de un modelo con un backend. Tiempos en ms. */
internal data class BenchmarkResult(
    val model: String,
    val backend: String,
    val iterations: Int,
    val initMs: Double,
    val runP50Ms: Double,
    val runP95Ms: Double,
    val totalP50Ms: Double,
    val totalP95Ms: Double,
    val error: String?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "model" to model,
        "backend" to backend,
        "iterations" to iterations,
        "initMs" to initMs,
        "runP50Ms" to runP50Ms,
        "runP95Ms" to runP95Ms,
        "totalP50Ms" to totalP50Ms,
        "totalP95Ms" to totalP95Ms,
        "error" to error,
    )
}

/**
 * Arnés de benchmark del spike P1 (informe §11.6): latencia de los modelos
 * del tracker (BlazeFace + FaceMesh-V2) con LiteRT, GPU vs CPU (XNNPACK).
 *
 * Usa una imagen sintética fija: no abre la cámara ni procesa caras reales.
 * "run" mide solo la inferencia; "total" suma escribir la entrada y leer la
 * salida (lo que de verdad paga el tracker). Bloqueante: llamar desde un hilo
 * de fondo.
 */
internal object ModelBenchmark {
    private const val TAG = "makeup_bench"
    private const val ASSET_DIR = "makeup_engine/models"
    private const val WARMUP = 20
    private const val ITERATIONS = 300
    private const val COOLDOWN_MS = 2000L

    private data class ModelSpec(val file: String, val inputSize: Int)

    private val models = listOf(
        ModelSpec("face_detector.tflite", 128),
        ModelSpec("face_landmarks_detector.tflite", 256),
    )

    private data class Backend(val name: String, val options: () -> CompiledModel.Options)

    private val backends = listOf(
        Backend("gpu") { CompiledModel.Options(Accelerator.GPU) },
        Backend("gpu_opengl") {
            CompiledModel.Options(Accelerator.GPU).apply {
                gpuOptions = CompiledModel.GpuOptions(backend = CompiledModel.GpuOptions.Backend.OPENGL)
            }
        },
        Backend("cpu_1t") {
            CompiledModel.Options(Accelerator.CPU).apply { cpuOptions = CompiledModel.CpuOptions(numThreads = 1) }
        },
        Backend("cpu_2t") {
            CompiledModel.Options(Accelerator.CPU).apply { cpuOptions = CompiledModel.CpuOptions(numThreads = 2) }
        },
        Backend("cpu_4t") {
            CompiledModel.Options(Accelerator.CPU).apply { cpuOptions = CompiledModel.CpuOptions(numThreads = 4) }
        },
    )

    fun run(context: Context): List<BenchmarkResult> {
        Log.i(TAG, "dispositivo=${Build.MANUFACTURER} ${Build.MODEL} abi=${Build.SUPPORTED_ABIS.firstOrNull()} sdk=${Build.VERSION.SDK_INT}")
        val environment = Environment.create(context)
        val results = mutableListOf<BenchmarkResult>()
        try {
            for (model in models) {
                val path = copyAssetToFile(context, model.file)
                val input = syntheticInput(model.inputSize)
                for (backend in backends) {
                    val result = runOne(environment, path, model, backend, input)
                    Log.i(TAG, "resultado " + result.toMap().entries.joinToString(" ") { "${it.key}=${it.value}" })
                    results += result
                    SystemClock.sleep(COOLDOWN_MS)
                }
            }
        } finally {
            environment.close()
        }
        return results
    }

    private fun runOne(
        environment: Environment,
        path: String,
        model: ModelSpec,
        backend: Backend,
        input: FloatArray,
    ): BenchmarkResult {
        var compiled: CompiledModel? = null
        try {
            val initStart = System.nanoTime()
            val created = CompiledModel.create(path, backend.options(), environment)
            compiled = created
            val inputs = created.createInputBuffers()
            val outputs = created.createOutputBuffers()
            val initMs = (System.nanoTime() - initStart) / 1e6

            val runTimes = DoubleArray(ITERATIONS)
            val totalTimes = DoubleArray(ITERATIONS)
            for (i in 0 until WARMUP + ITERATIONS) {
                val t0 = System.nanoTime()
                inputs[0].writeFloat(input)
                val t1 = System.nanoTime()
                created.run(inputs, outputs)
                val t2 = System.nanoTime()
                for (output in outputs) output.readFloat()
                val t3 = System.nanoTime()
                if (i >= WARMUP) {
                    runTimes[i - WARMUP] = (t2 - t1) / 1e6
                    totalTimes[i - WARMUP] = (t3 - t0) / 1e6
                }
            }
            inputs.forEach { it.close() }
            outputs.forEach { it.close() }
            return BenchmarkResult(
                model.file, backend.name, ITERATIONS, initMs,
                percentile(runTimes, 0.50), percentile(runTimes, 0.95),
                percentile(totalTimes, 0.50), percentile(totalTimes, 0.95),
                null,
            )
        } catch (e: Exception) {
            return BenchmarkResult(model.file, backend.name, 0, 0.0, Double.NaN, Double.NaN, Double.NaN, Double.NaN, "${e.javaClass.simpleName}: ${e.message}")
        } finally {
            compiled?.close()
        }
    }

    /** Percentil por rango más cercano (igual que frame_stats.cpp). */
    internal fun percentile(values: DoubleArray, p: Double): Double {
        if (values.isEmpty()) return Double.NaN
        val sorted = values.sortedArray()
        val index = (Math.ceil(p * sorted.size).toInt() - 1).coerceIn(0, sorted.size - 1)
        return sorted[index]
    }

    /** Degradado determinista en [0, 1]: la latencia no depende del contenido. */
    private fun syntheticInput(size: Int): FloatArray {
        val data = FloatArray(size * size * 3)
        var index = 0
        for (y in 0 until size) {
            for (x in 0 until size) {
                data[index++] = x / (size - 1f)
                data[index++] = y / (size - 1f)
                data[index++] = 0.5f
            }
        }
        return data
    }

    /** CompiledModel lee de un archivo: los assets del APK pueden estar comprimidos. */
    private fun copyAssetToFile(context: Context, name: String): String {
        val target = File(context.filesDir, "$ASSET_DIR/$name")
        target.parentFile?.mkdirs()
        context.assets.open("$ASSET_DIR/$name").use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        }
        return target.absolutePath
    }
}
