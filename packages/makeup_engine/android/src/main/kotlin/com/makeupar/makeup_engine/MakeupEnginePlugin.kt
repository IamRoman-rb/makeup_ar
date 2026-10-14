package com.makeupar.makeup_engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Canal `makeup_engine`. Métodos: start, stop, setTint, setRecipe, setRenderOptions, getStats,
 * resetStats, runBenchmark, analyzeFaceImage y extractPalette (Studio, F4: una foto, sin sesión).
 * Una sola sesión a la vez. Ver lib/makeup_engine.dart para el contrato.
 */
class MakeupEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var textures: TextureRegistry? = null
    private var session: EngineSession? = null
    // Un análisis de foto a la vez, en orden, fuera del hilo de UI (F4).
    private var stillExecutor: ExecutorService? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textures = binding.textureRegistry
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        session?.release()
        session = null
        stillExecutor?.shutdown()
        stillExecutor = null
        context = null
        textures = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> {
                session?.release()
                session = null
                result.success(null)
            }
            "setTint" -> {
                val r = call.argument<Double>("r") ?: 0.0
                val g = call.argument<Double>("g") ?: 0.0
                val b = call.argument<Double>("b") ?: 0.0
                val amount = call.argument<Double>("amount") ?: 0.0
                session?.setTint(r.toFloat(), g.toFloat(), b.toFloat(), amount.toFloat())
                result.success(null)
            }
            "setRecipe" -> {
                session?.setRecipe(call.argument<Map<*, *>>("recipe"))
                result.success(null)
            }
            "setRenderOptions" -> {
                val showLandmarks = call.argument<Boolean>("showLandmarks") ?: false
                val region = call.argument<Int>("region") ?: NativeBridge.REGION_FULL
                val lightAdaptation = call.argument<Boolean>("lightAdaptation") ?: true
                session?.setRenderOptions(showLandmarks, region, lightAdaptation)
                result.success(null)
            }
            "getStats" -> result.success(session?.stats())
            "resetStats" -> {
                session?.resetStats()
                result.success(null)
            }
            "runBenchmark" -> runBenchmark(result)
            "analyzeFaceImage" -> analyzeStill(call, result) { analyzer, bytes -> analyzer.analyzeFace(bytes) }
            "extractPalette" -> analyzeStill(call, result) { analyzer, bytes -> analyzer.palette(bytes) }
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val currentContext = context
        val currentTextures = textures
        if (currentContext == null || currentTextures == null) {
            result.error("not_attached", "El plugin no está adjunto a un FlutterEngine", null)
            return
        }
        if (session != null) {
            result.error("already_started", "Ya hay una sesión activa: llamá a stop() primero", null)
            return
        }
        val newSession = EngineSession(currentContext, currentTextures)
        session = newSession
        try {
            startSession(newSession, call.argument<Int>("rotationDegrees"), result)
        } catch (e: Exception) {
            // CameraAccessException y similares salen de start() de forma síncrona:
            // sin esto la sesión quedaría huérfana y todo start() siguiente fallaría.
            newSession.release()
            if (session === newSession) session = null
            result.error("start_failed", e.message, null)
        }
    }

    private fun startSession(newSession: EngineSession, rotationDegrees: Int?, result: MethodChannel.Result) {
        newSession.start(rotationDegrees) { outcome ->
            outcome.fold(
                onSuccess = { info ->
                    result.success(
                        mapOf(
                            "textureId" to info.textureId,
                            "width" to info.output.width,
                            "height" to info.output.height,
                            "previewWidth" to info.preview.width,
                            "previewHeight" to info.preview.height,
                            "sensorOrientation" to info.sensorOrientation,
                            "rotationDegrees" to info.rotationDegrees,
                            "fpsMin" to info.fpsRange?.first,
                            "fpsMax" to info.fpsRange?.last,
                            "glInfo" to info.glInfo,
                        ),
                    )
                },
                onFailure = { error ->
                    newSession.release()
                    if (session === newSession) session = null
                    val code = (error as? EngineException)?.code ?: "start_failed"
                    result.error(code, error.message, null)
                },
            )
        }
    }

    /** Minutos de trabajo: en un hilo propio, nunca en el de UI. */
    private fun runBenchmark(result: MethodChannel.Result) {
        val currentContext = context
        if (currentContext == null) {
            result.error("not_attached", "El plugin no está adjunto a un FlutterEngine", null)
            return
        }
        val mainHandler = Handler(Looper.getMainLooper())
        Thread({
            val outcome = runCatching { ModelBenchmark.run(currentContext).map { it.toMap() } }
            mainHandler.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("benchmark_failed", it.message, null) },
                )
            }
        }, "makeup-benchmark").start()
    }

    /**
     * Foto (bytes JPEG/PNG) -> números, en el executor del Studio. Responde
     * List<Double>; "bad_image" si no se pudo decodificar.
     */
    private fun analyzeStill(
        call: MethodCall,
        result: MethodChannel.Result,
        work: (StillImageAnalyzer, ByteArray) -> FloatArray?,
    ) {
        val currentContext = context
        val bytes = call.argument<ByteArray>("bytes")
        if (currentContext == null) {
            result.error("not_attached", "El plugin no está adjunto a un FlutterEngine", null)
            return
        }
        if (bytes == null || bytes.isEmpty()) {
            result.error("bad_image", "Faltan los bytes de la foto", null)
            return
        }
        // Prioridad de fondo: la sesión de cámara y el tracker en vivo van primero
        // (el pool de LiteRT se crea desde este hilo).
        val executor = stillExecutor ?: Executors.newSingleThreadExecutor { runnable ->
            Thread({
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
                runnable.run()
            }, "makeup-still")
        }.also { stillExecutor = it }
        val mainHandler = Handler(Looper.getMainLooper())
        val cameraActive = session != null
        executor.execute {
            val outcome = runCatching { work(StillImageAnalyzer(currentContext, cameraActive), bytes) }
            mainHandler.post {
                outcome.fold(
                    onSuccess = { values ->
                        if (values == null) {
                            result.error("bad_image", "No se pudo leer la foto", null)
                        } else {
                            result.success(values.map { it.toDouble() })
                        }
                    },
                    onFailure = { result.error("analysis_failed", it.message, null) },
                )
            }
        }
    }

    private companion object {
        const val CHANNEL = "makeup_engine"
    }
}
