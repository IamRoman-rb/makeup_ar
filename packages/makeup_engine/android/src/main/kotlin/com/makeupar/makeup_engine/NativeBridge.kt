package com.makeupar.makeup_engine

/**
 * Funciones del núcleo C++ (registradas en JNI_OnLoad, ver cpp/jni_bridge.cpp).
 *
 * Todas las que tocan GL (nativeInitGl, nativeDrawFrame, nativeReleaseGl) se
 * llaman SOLO desde el hilo de render, con el contexto EGL actual.
 */
internal object NativeBridge {
    init {
        System.loadLibrary("makeup_engine")
    }

    // Índices de nativeGetConfig(); mismo orden que ConfigIndex en engine_config.h.
    const val CONFIG_MAX_PREVIEW_LONG_SIDE = 0
    const val CONFIG_MAX_PREVIEW_SHORT_SIDE = 1
    const val CONFIG_TARGET_FPS = 2
    const val CONFIG_STATS_WINDOW = 3

    // Índices de nativeGetStats(); mismo orden que StatIndex en frame_stats.h.
    const val STAT_FRAMES = 0
    const val STAT_INTERVAL_P50_MS = 1
    const val STAT_INTERVAL_P95_MS = 2
    const val STAT_CPU_P50_MS = 3
    const val STAT_CPU_P95_MS = 4
    const val STAT_CAMERA_INTERVAL_P50_MS = 5
    const val STAT_CAMERA_INTERVAL_P95_MS = 6
    const val STAT_COUNT = 7

    @JvmStatic external fun nativeGetConfig(): IntArray
    @JvmStatic external fun nativeCreate(): Long
    @JvmStatic external fun nativeInitGl(handle: Long): Int
    @JvmStatic external fun nativeGetGlInfo(handle: Long): String
    @JvmStatic external fun nativeGetLastError(handle: Long): String
    @JvmStatic external fun nativeSetDisplayMatrix(handle: Long, matrix: FloatArray)
    @JvmStatic external fun nativeSetTint(handle: Long, r: Float, g: Float, b: Float, amount: Float)
    @JvmStatic external fun nativeDrawFrame(
        handle: Long,
        texMatrix: FloatArray,
        width: Int,
        height: Int,
        frameStartNs: Long,
        cameraTimestampNs: Long,
    )
    @JvmStatic external fun nativeGetStats(handle: Long, out: FloatArray)
    @JvmStatic external fun nativeResetStats(handle: Long)
    @JvmStatic external fun nativeReleaseGl(handle: Long)
    @JvmStatic external fun nativeDestroy(handle: Long)
}
