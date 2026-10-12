package com.makeupar.makeup_engine

/**
 * Funciones del núcleo C++ (registradas en JNI_OnLoad, ver cpp/jni_bridge.cpp).
 *
 * Hilos:
 *  - render (con el contexto EGL actual): nativeInitGl, nativeDrawFrame, nativeReleaseGl.
 *  - tracker: nativeTracker*.
 *  - cualquiera: el resto.
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
    const val CONFIG_DETECTOR_INPUT_SIZE = 4
    const val CONFIG_LANDMARK_INPUT_SIZE = 5
    const val CONFIG_LANDMARK_COUNT = 6

    // Índices de nativeGetStats(); mismo orden que StatIndex en frame_stats.h.
    const val STAT_FRAMES = 0
    const val STAT_INTERVAL_P50_MS = 1
    const val STAT_INTERVAL_P95_MS = 2
    const val STAT_CPU_P50_MS = 3
    const val STAT_CPU_P95_MS = 4
    const val STAT_CAMERA_INTERVAL_P50_MS = 5
    const val STAT_CAMERA_INTERVAL_P95_MS = 6
    const val STAT_COUNT = 7

    // Índices de nativeGetTrackerStats(); mismo orden que TrackerStatIndex en tracking_state.h.
    const val TRACK_STAT_STATE = 0
    const val TRACK_STAT_LANDMARK_RUNS = 1
    const val TRACK_STAT_DETECTOR_RUNS = 2
    const val TRACK_STAT_LOSSES = 3
    const val TRACK_STAT_INTERVAL_P50_MS = 4
    const val TRACK_STAT_INTERVAL_P95_MS = 5
    const val TRACK_STAT_LANDMARK_P50_MS = 6
    const val TRACK_STAT_LANDMARK_P95_MS = 7
    const val TRACK_STAT_DETECTOR_P50_MS = 8
    const val TRACK_STAT_JITTER_P50_PX = 9
    const val TRACK_STAT_PRESENCE = 10
    const val TRACK_STAT_PITCH_DEG = 11
    const val TRACK_STAT_YAW_DEG = 12
    const val TRACK_STAT_ROLL_DEG = 13
    const val TRACK_STAT_READBACK_MS = 14
    const val TRACK_STAT_CROP_FAILURES = 15
    const val TRACK_STAT_COUNT = 16

    // Bits de nativeDrawFrame(); mismo valor que FrameFlag en renderer.h.
    const val FRAME_FLAG_CROP_READY = 1

    // Valores de nativeSetRenderOptions(); mismo orden que TintRegion en renderer.h y en Dart.
    const val REGION_FULL = 0
    const val REGION_LIPS = 1

    // [finish] de nativeSetLips(); mismo orden que LipFinish en renderer.h.
    const val LIP_FINISH_MATTE = 0
    const val LIP_FINISH_SATIN = 1
    const val LIP_FINISH_GLOSS = 2
    const val LIP_FINISH_SHIMMER = 3

    // Valores de nativeTrackerReadyKind(); mismo valor que CropKind en tracking_state.h.
    const val CROP_NONE = 0
    const val CROP_DETECTOR = 1
    const val CROP_LANDMARKS = 2

    @JvmStatic external fun nativeGetConfig(): IntArray
    @JvmStatic external fun nativeCreate(): Long
    @JvmStatic external fun nativeInitGl(handle: Long): Int
    @JvmStatic external fun nativeGetGlInfo(handle: Long): String
    @JvmStatic external fun nativeGetLastError(handle: Long): String

    /**
     * [display] para la pantalla, [tracker] sin espejo (recortes); tamaño de la
     * salida en px; [mirrored]: la pantalla está espejada respecto de la imagen.
     */
    @JvmStatic external fun nativeSetGeometry(
        handle: Long,
        display: FloatArray,
        tracker: FloatArray,
        width: Int,
        height: Int,
        mirrored: Boolean,
    )

    /** [region]: REGION_FULL o REGION_LIPS. */
    @JvmStatic external fun nativeSetRenderOptions(handle: Long, showLandmarks: Boolean, region: Int)
    @JvmStatic external fun nativeSetTint(handle: Long, r: Float, g: Float, b: Float, amount: Float)

    /**
     * Labial de la receta (REGION_LIPS): color sRGB [0,1], opacidad, acabado
     * (LIP_FINISH_*), brillo y lumaFollow [0,1]. [enabled] = false lo apaga.
     */
    @JvmStatic external fun nativeSetLips(
        handle: Long,
        enabled: Boolean,
        r: Float,
        g: Float,
        b: Float,
        opacity: Float,
        finish: Int,
        gloss: Float,
        lumaFollow: Float,
    )

    /** Devuelve bits FRAME_FLAG_*. */
    @JvmStatic external fun nativeDrawFrame(
        handle: Long,
        texMatrix: FloatArray,
        width: Int,
        height: Int,
        frameStartNs: Long,
        cameraTimestampNs: Long,
    ): Int
    @JvmStatic external fun nativeGetStats(handle: Long, out: FloatArray)
    @JvmStatic external fun nativeGetTrackerStats(handle: Long, out: FloatArray)
    @JvmStatic external fun nativeResetStats(handle: Long)
    @JvmStatic external fun nativeReleaseGl(handle: Long)
    @JvmStatic external fun nativeDestroy(handle: Long)

    @JvmStatic external fun nativeTrackerStart(handle: Long)
    @JvmStatic external fun nativeTrackerStop(handle: Long)
    @JvmStatic external fun nativeTrackerReadyKind(handle: Long): Int

    /** El recorte listo no se pudo inferir: se descarta y se vuelve al detector. */
    @JvmStatic external fun nativeTrackerAbort(handle: Long)

    /** RGBA8 del recorte listo -> [out] RGB float (byte / 255 · scale + offset). */
    @JvmStatic external fun nativeTrackerFillInput(handle: Long, out: FloatArray, scale: Float, offset: Float): Boolean
    @JvmStatic external fun nativeTrackerSubmitDetections(handle: Long, regressors: FloatArray, scores: FloatArray, inferenceMs: Float)
    @JvmStatic external fun nativeTrackerSubmitLandmarks(handle: Long, landmarks: FloatArray, presenceLogit: Float, inferenceMs: Float)
}
