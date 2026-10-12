package com.makeupar.makeup_engine

import android.content.Context
import java.io.File

/** Modelos del tracker empaquetados en los assets del plugin (ver third_party/). */
internal object ModelAssets {
    const val DETECTOR = "face_detector.tflite"
    const val LANDMARKS = "face_landmarks_detector.tflite"
    private const val ASSET_DIR = "makeup_engine/models"

    /**
     * Devuelve la ruta de un archivo con el modelo: CompiledModel lee de un
     * archivo y los assets del APK pueden estar comprimidos. Solo se copia si
     * falta o si la app se actualizó después de la última copia (así no se
     * reescriben ~4 MB en cada sesión). Bloqueante: llamar fuera del hilo de UI.
     */
    fun file(context: Context, name: String): String {
        val target = File(context.filesDir, "$ASSET_DIR/$name")
        val appUpdated = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        if (target.isFile && target.length() > 0 && target.lastModified() >= appUpdated) {
            return target.absolutePath
        }
        target.parentFile?.mkdirs()
        val temporary = File(target.parentFile, "$name.tmp")
        context.assets.open("$ASSET_DIR/$name").use { input ->
            temporary.outputStream().use { output -> input.copyTo(output) }
        }
        // Renombrar al final: un proceso cortado a mitad de la copia no deja un modelo truncado.
        if (!temporary.renameTo(target)) {
            target.delete()
            temporary.renameTo(target)
        }
        return target.absolutePath
    }
}
