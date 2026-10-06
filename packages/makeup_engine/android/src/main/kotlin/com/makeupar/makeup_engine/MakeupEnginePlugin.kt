package com.makeupar.makeup_engine

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Canal `makeup_engine`. Métodos: start, stop, setTint, getStats, resetStats.
 * Una sola sesión a la vez. Ver lib/makeup_engine.dart para el contrato.
 */
class MakeupEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var textures: TextureRegistry? = null
    private var session: EngineSession? = null

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
            "getStats" -> result.success(session?.stats())
            "resetStats" -> {
                session?.resetStats()
                result.success(null)
            }
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

    private companion object {
        const val CHANNEL = "makeup_engine"
    }
}
