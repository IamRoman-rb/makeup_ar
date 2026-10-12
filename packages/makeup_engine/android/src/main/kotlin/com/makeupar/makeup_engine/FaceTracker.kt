package com.makeupar.makeup_engine

/**
 * Contrato del tracker facial (`IFaceTracker` del informe §5.2).
 *
 * La implementación corre la inferencia en su propio hilo. Los recortes, la
 * decodificación, los filtros y la pose viven en C++ (TrackingState): el
 * tracker solo convierte el recorte listo en tensor, corre el modelo y entrega
 * las salidas crudas. Cambiar de modelo no toca nada más, siempre que respete
 * la topología de FaceMesh (478 puntos).
 */
internal interface FaceTracker {
    /** Empieza a cargar los modelos en su hilo. No bloquea. */
    fun start()

    /** Hilo de render: hay un recorte listo para inferir. No bloquea ni aloca. */
    fun onCropReady()

    /** Cualquier hilo: con false deja de pedir recortes (los modelos quedan cargados). */
    fun setEnabled(enabled: Boolean)

    /** Backends en uso ("detector=gpu landmarks=gpu"), o null mientras carga. */
    val backend: String?

    /** Último error, o null. */
    val error: String?

    /** Tiempo de carga de los modelos en ms (NaN mientras carga). */
    val initMs: Double

    /**
     * Libera los modelos en el hilo del tracker. [onReleased] se llama en el
     * hilo de plataforma cuando el tracker ya no va a tocar el núcleo nativo.
     */
    fun release(onReleased: () -> Unit)
}
