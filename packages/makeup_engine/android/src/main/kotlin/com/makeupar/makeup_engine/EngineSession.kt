package com.makeupar.makeup_engine

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.util.Log
import android.util.Range
import android.view.Surface
import android.view.WindowManager
import io.flutter.view.TextureRegistry
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Lo que recibe Dart al iniciar. */
internal data class StartInfo(
    val textureId: Long,
    val output: PixelSize,
    val preview: PixelSize,
    val sensorOrientation: Int,
    val rotationDegrees: Int,
    val fpsRange: IntRange?,
    val glInfo: String,
)

/**
 * Una sesión cámara -> GLES -> Texture de Flutter.
 *
 * Hilos:
 *  - plataforma (main): start/release/stats, callbacks de SurfaceProducer.
 *  - "makeup-render": dueño del contexto EGL/GL; dibuja cada frame de cámara.
 *  - "makeup-camera": callbacks de Camera2.
 * Dart no cruza por frame: solo inicia, detiene, cambia el tinte y lee stats.
 */
internal class EngineSession(
    private val context: Context,
    private val textures: TextureRegistry,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    // Prioridad de display: en Android Go el hilo de render compite con los de Flutter.
    private val renderThread = HandlerThread("makeup-render", Process.THREAD_PRIORITY_DISPLAY).apply { start() }
    private val renderHandler = Handler(renderThread.looper)
    private val cameraThread = HandlerThread("makeup-camera").apply { start() }
    private val cameraHandler = Handler(cameraThread.looper)

    private val config = NativeBridge.nativeGetConfig()
    private val nativeHandle = NativeBridge.nativeCreate()
    private val egl = EglCore()

    // Solo hilo de render; se reutiliza en cada frame (cero allocations).
    private val texMatrix = FloatArray(16)
    private var surfaceTexture: SurfaceTexture? = null
    private var cameraSurface: Surface? = null
    private var output = PixelSize(0, 0)
    private var lastFrameTimestamp = Long.MIN_VALUE

    // Solo hilo de plataforma.
    private val statsBuffer = FloatArray(NativeBridge.STAT_COUNT)
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var startInfo: StartInfo? = null

    // Solo hilo de cámara.
    private var camera: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    // Objetos de Camera2 que todavía van a mandar callbacks a cameraHandler. El
    // hilo de cámara se termina recién cuando no queda ninguno (ver
    // quitCameraThreadIfIdle): si no, Camera2 postea a un Handler muerto.
    private var cameraOpenPending = false // entre openCamera() y su primer callback
    private var deviceOpen = false        // entre onOpened y onClosed del dispositivo
    private var sessionOpen = false       // entre createCaptureSession y onClosed/onConfigureFailed

    @Volatile private var released = false
    @Volatile private var lastError: String? = null

    /**
     * Abre todo. [onResult] se llama en el hilo de plataforma, una sola vez:
     * con StartInfo cuando GL y la superficie están listos (la cámara abre en
     * segundo plano; sus errores aparecen en stats()["error"]), o con el error.
     */
    fun start(rotationOverride: Int?, onResult: (Result<StartInfo>) -> Unit) {
        val manager = context.getSystemService(CameraManager::class.java)
        val cameraId = manager.cameraIdList.firstOrNull {
            manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_FRONT
        }
        if (cameraId == null) {
            onResult(Result.failure(EngineException("no_front_camera", "No hay cámara frontal")))
            return
        }
        val characteristics = manager.getCameraCharacteristics(cameraId)
        val streamMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val sizes = streamMap?.getOutputSizes(SurfaceTexture::class.java)
            ?.map { PixelSize(it.width, it.height) }
            .orEmpty()
        val preview = CameraMath.choosePreviewSize(
            sizes,
            config[NativeBridge.CONFIG_MAX_PREVIEW_LONG_SIDE],
            config[NativeBridge.CONFIG_MAX_PREVIEW_SHORT_SIDE],
        )
        if (preview == null) {
            onResult(Result.failure(EngineException("camera_unavailable", "La cámara no ofrece tamaños de vista previa")))
            return
        }
        val fpsRange = CameraMath.chooseFpsRange(
            characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                ?.map { it.lower..it.upper }
                .orEmpty(),
            config[NativeBridge.CONFIG_TARGET_FPS],
        )
        val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 270
        val rotation = rotationOverride ?: CameraMath.imageRotation(sensorOrientation, displayRotationDegrees(), true)
        val outputSize = CameraMath.outputSize(preview, rotation)
        val displayMatrix = CameraMath.displayMatrix(rotation, mirror = true)

        val newProducer = textures.createSurfaceProducer()
        producer = newProducer
        newProducer.setSize(outputSize.width, outputSize.height)
        newProducer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                val surface = producer?.surface ?: return
                renderHandler.post { attachWindow(surface) }
            }

            override fun onSurfaceCleanup() {
                // Hay que dejar de usar la Surface antes de volver de este callback.
                // Timeout corto: es el hilo de UI.
                if (!runOnRenderAndWait(SURFACE_CLEANUP_TIMEOUT_MS) { egl.releaseWindow() }) {
                    Log.w(TAG, "onSurfaceCleanup: el hilo de render no solto la ventana a tiempo")
                }
            }
        })
        val initialSurface = newProducer.surface

        renderHandler.post {
            val error = initGl(preview, outputSize, displayMatrix, initialSurface)
            if (error != null) {
                mainHandler.post { onResult(Result.failure(EngineException("gl_init_failed", error))) }
                return@post
            }
            val glInfo = NativeBridge.nativeGetGlInfo(nativeHandle)
            val surface = cameraSurface
            if (surface != null) {
                cameraHandler.post { openCamera(manager, cameraId, surface, fpsRange) }
            }
            mainHandler.post {
                if (released) {
                    // stop() llegó durante start(): se responde igual para no colgar el Future de Dart.
                    onResult(Result.failure(EngineException("cancelled", "La sesión se cerró durante el inicio")))
                    return@post
                }
                val info = StartInfo(newProducer.id(), outputSize, preview, sensorOrientation, rotation, fpsRange, glInfo)
                startInfo = info
                onResult(Result.success(info))
            }
        }
    }

    /** Hilo de render. Devuelve null si salió bien. */
    private fun initGl(preview: PixelSize, outputSize: PixelSize, displayMatrix: FloatArray, window: Surface): String? {
        egl.init()?.let { return it }
        val textureId = NativeBridge.nativeInitGl(nativeHandle)
        if (textureId == 0) return NativeBridge.nativeGetLastError(nativeHandle)
        NativeBridge.nativeSetDisplayMatrix(nativeHandle, displayMatrix)
        output = outputSize
        val texture = SurfaceTexture(textureId).apply {
            setDefaultBufferSize(preview.width, preview.height)
            setOnFrameAvailableListener({ onFrameAvailable() }, renderHandler)
        }
        surfaceTexture = texture
        cameraSurface = Surface(texture)
        return attachWindow(window)
    }

    /** Hilo de render. */
    private fun attachWindow(surface: Surface): String? {
        if (released) return null
        val error = egl.attachWindow(surface)
        if (error != null) lastError = error
        return error
    }

    /** Hilo de render, una vez por frame de cámara. */
    private fun onFrameAvailable() {
        val texture = surfaceTexture ?: return
        if (released) return
        val frameStart = System.nanoTime()
        // Siempre se consume el buffer, aunque no haya ventana: si no, la cámara se traba.
        try {
            texture.updateTexImage()
        } catch (e: RuntimeException) {
            // Contexto perdido o textura liberada: no se mata el proceso por un frame.
            lastError = "updateTexImage: ${e.message}"
            return
        }
        // Si se acumularon callbacks, los que no traen un buffer nuevo no se dibujan.
        val timestamp = texture.timestamp
        if (timestamp == lastFrameTimestamp) return
        lastFrameTimestamp = timestamp
        if (!egl.hasWindow) return
        texture.getTransformMatrix(texMatrix)
        NativeBridge.nativeDrawFrame(nativeHandle, texMatrix, output.width, output.height, frameStart, timestamp)
    }

    @SuppressLint("MissingPermission") // Dart pide el permiso antes de start().
    private fun openCamera(manager: CameraManager, cameraId: String, surface: Surface, fpsRange: IntRange?) {
        if (released) return
        try {
            cameraOpenPending = true
            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraOpenPending = false
                    deviceOpen = true
                    if (released) {
                        device.close()
                        return
                    }
                    camera = device
                    createSession(device, surface, fpsRange)
                }

                override fun onDisconnected(device: CameraDevice) {
                    cameraOpenPending = false
                    lastError = "cámara desconectada (otra app la tomó)"
                    closeCaptureSession()
                    device.close()
                    camera = null
                    quitCameraThreadIfIdle()
                }

                override fun onError(device: CameraDevice, error: Int) {
                    cameraOpenPending = false
                    lastError = "error de cámara $error"
                    closeCaptureSession()
                    device.close()
                    camera = null
                    quitCameraThreadIfIdle()
                }

                override fun onClosed(device: CameraDevice) {
                    deviceOpen = false
                    quitCameraThreadIfIdle()
                }
            }, cameraHandler)
        } catch (e: SecurityException) {
            cameraOpenPending = false
            lastError = "sin permiso de cámara"
            quitCameraThreadIfIdle()
        } catch (e: Exception) {
            cameraOpenPending = false
            lastError = "no se pudo abrir la cámara: ${e.message}"
            quitCameraThreadIfIdle()
        }
    }

    // createCaptureSession(List, ...) está deprecado en API 30, pero es el único
    // disponible desde minSdk 24 sin ramas por versión.
    @Suppress("DEPRECATION")
    private fun createSession(device: CameraDevice, surface: Surface, fpsRange: IntRange?) {
        try {
            sessionOpen = true
            device.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (released) {
                        // Se cierra explícitamente: si no, la cierra el finalizer del GC más
                        // tarde y postea a un hilo ya terminado. sessionOpen mantiene vivo
                        // el hilo hasta su onClosed.
                        session.close()
                        return
                    }
                    captureSession = session
                    val request = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                        addTarget(surface)
                        if (fpsRange != null) {
                            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(fpsRange.first, fpsRange.last))
                        }
                    }
                    session.setRepeatingRequest(request.build(), null, cameraHandler)
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    lastError = "no se pudo configurar la sesión de cámara"
                    sessionOpen = false
                    quitCameraThreadIfIdle()
                }

                override fun onClosed(session: CameraCaptureSession) {
                    sessionOpen = false
                    quitCameraThreadIfIdle()
                }
            }, cameraHandler)
        } catch (e: Exception) {
            sessionOpen = false
            lastError = "createCaptureSession: ${e.message}"
        }
    }

    /** Hilo de cámara. Cerrar explícitamente evita que lo haga el finalizer de la sesión. */
    private fun closeCaptureSession() {
        captureSession?.close()
        captureSession = null
    }

    /** Hilo de cámara. Termina el hilo si la sesión se cerró y Camera2 ya no va a llamar. */
    private fun quitCameraThreadIfIdle(): Boolean {
        if (!released || cameraOpenPending || deviceOpen || sessionOpen) return false
        cameraThread.quitSafely()
        return true
    }

    fun setTint(r: Float, g: Float, b: Float, amount: Float) {
        if (!released) NativeBridge.nativeSetTint(nativeHandle, r, g, b, amount)
    }

    fun resetStats() {
        if (!released) NativeBridge.nativeResetStats(nativeHandle)
    }

    /** Hilo de plataforma. Las claves coinciden con EngineStats.fromMap en Dart. */
    fun stats(): Map<String, Any?> {
        if (released) return mapOf("error" to "sesión cerrada")
        NativeBridge.nativeGetStats(nativeHandle, statsBuffer)
        val info = startInfo
        return mapOf(
            "frames" to statsBuffer[NativeBridge.STAT_FRAMES].toDouble(),
            "intervalP50Ms" to statsBuffer[NativeBridge.STAT_INTERVAL_P50_MS].toDouble(),
            "intervalP95Ms" to statsBuffer[NativeBridge.STAT_INTERVAL_P95_MS].toDouble(),
            "cpuP50Ms" to statsBuffer[NativeBridge.STAT_CPU_P50_MS].toDouble(),
            "cpuP95Ms" to statsBuffer[NativeBridge.STAT_CPU_P95_MS].toDouble(),
            "cameraIntervalP50Ms" to statsBuffer[NativeBridge.STAT_CAMERA_INTERVAL_P50_MS].toDouble(),
            "cameraIntervalP95Ms" to statsBuffer[NativeBridge.STAT_CAMERA_INTERVAL_P95_MS].toDouble(),
            "previewWidth" to info?.preview?.width,
            "previewHeight" to info?.preview?.height,
            "error" to lastError,
        )
    }

    /**
     * Hilo de plataforma. Idempotente.
     *
     * Parte síncrona (corta): el hilo de render suelta la ventana EGL (espera a
     * lo sumo el frame en curso) y se libera la SurfaceProducer antes de volver.
     * Tiene que ser síncrono: si se libera después, un frame ya enviado llega a
     * Flutter con el FlutterEngine desacoplado y la app crashea
     * ("FlutterJNI is not attached to native").
     *
     * Parte asíncrona: cámara -> GL -> Renderer nativo, sin bloquear la UI.
     * setTint/stats/resetStats chequean [released] en este mismo hilo, así que
     * no pueden usar el Renderer destruido.
     */
    fun release() {
        if (released) return
        released = true
        if (!runOnRenderAndWait(SURFACE_CLEANUP_TIMEOUT_MS) { egl.releaseWindow() }) {
            Log.w(TAG, "release: el hilo de render no solto la ventana a tiempo")
        }
        producer?.release()
        producer = null
        cameraHandler.post {
            closeCaptureSession()
            val openDevice = camera
            camera = null
            openDevice?.close()
            renderHandler.post {
                surfaceTexture?.setOnFrameAvailableListener(null)
                surfaceTexture?.release()
                surfaceTexture = null
                cameraSurface?.release()
                cameraSurface = null
                NativeBridge.nativeReleaseGl(nativeHandle)
                egl.release()
                renderThread.quitSafely()
                mainHandler.post { NativeBridge.nativeDestroy(nativeHandle) }
            }
            // Si hay dispositivo o sesión abiertos, el último onClosed termina el hilo.
            if (!quitCameraThreadIfIdle()) {
                // Respaldo: Camera2 no garantiza todos los onClosed (p. ej. tras
                // onDisconnected, cuando otra sesión tomó la cámara). Sin esto el
                // hilo quedaría vivo para siempre.
                cameraHandler.postDelayed({ cameraThread.quitSafely() }, CAMERA_QUIT_FALLBACK_MS)
            }
        }
    }

    private fun runOnRenderAndWait(timeoutMs: Long, block: () -> Unit): Boolean {
        if (Looper.myLooper() == renderThread.looper) {
            block()
            return true
        }
        val done = CountDownLatch(1)
        val posted = renderHandler.post {
            block()
            done.countDown()
        }
        return posted && done.await(timeoutMs, TimeUnit.MILLISECONDS)
    }

    @Suppress("DEPRECATION")
    private fun displayRotationDegrees(): Int {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
    }

    private companion object {
        const val TAG = "makeup_engine"
        const val SURFACE_CLEANUP_TIMEOUT_MS = 250L
        const val CAMERA_QUIT_FALLBACK_MS = 2000L
    }
}

internal class EngineException(val code: String, message: String) : Exception(message)
