package com.makeupar.makeup_engine

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.view.Surface

/**
 * Contexto EGL de OpenGL ES 3.0 para el hilo de render. Todas las llamadas
 * van en ese hilo. Sin ventana se usa un pbuffer de 1x1 para que el contexto
 * siempre pueda estar actual (crear recursos GL antes de tener superficie).
 */
internal class EglCore {
    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var config: EGLConfig? = null
    private var pbuffer: EGLSurface = EGL14.EGL_NO_SURFACE
    private var window: EGLSurface = EGL14.EGL_NO_SURFACE

    val hasWindow: Boolean get() = window != EGL14.EGL_NO_SURFACE

    /** Devuelve null si salió bien, o el motivo del error. */
    fun init(): String? {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return "eglGetDisplay falló"
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) return "eglInitialize: ${eglError()}"

        val attributes = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT or EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        if (!EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) || count[0] == 0) {
            return "no hay configuración EGL RGBA8888 con OpenGL ES 3"
        }
        val chosen = configs[0] ?: return "eglChooseConfig devolvió null"
        config = chosen

        val contextAttributes = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        context = EGL14.eglCreateContext(display, chosen, EGL14.EGL_NO_CONTEXT, contextAttributes, 0)
        if (context == EGL14.EGL_NO_CONTEXT) return "eglCreateContext (ES 3.0): ${eglError()}"

        val pbufferAttributes = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        pbuffer = EGL14.eglCreatePbufferSurface(display, chosen, pbufferAttributes, 0)
        if (pbuffer == EGL14.EGL_NO_SURFACE) return "eglCreatePbufferSurface: ${eglError()}"
        if (!EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)) return "eglMakeCurrent: ${eglError()}"
        return null
    }

    /** Crea la superficie de ventana sobre la Surface de Flutter y la hace actual. */
    fun attachWindow(surface: Surface): String? {
        releaseWindow()
        val chosen = config ?: return "EGL sin inicializar"
        window = EGL14.eglCreateWindowSurface(display, chosen, surface, intArrayOf(EGL14.EGL_NONE), 0)
        if (window == EGL14.EGL_NO_SURFACE) return "eglCreateWindowSurface: ${eglError()}"
        if (!EGL14.eglMakeCurrent(display, window, window, context)) {
            val error = "eglMakeCurrent: ${eglError()}"
            // Sin esto, hasWindow quedaría en true y se dibujaría sobre el pbuffer de 1x1.
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
            EGL14.eglDestroySurface(display, window)
            window = EGL14.EGL_NO_SURFACE
            return error
        }
        return null
    }

    /** Suelta la superficie de ventana y vuelve al pbuffer. */
    fun releaseWindow() {
        if (window == EGL14.EGL_NO_SURFACE) return
        EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
        EGL14.eglDestroySurface(display, window)
        window = EGL14.EGL_NO_SURFACE
    }

    fun release() {
        if (display == EGL14.EGL_NO_DISPLAY) return
        releaseWindow()
        EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        if (pbuffer != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, pbuffer)
        if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context)
        EGL14.eglReleaseThread()
        EGL14.eglTerminate(display)
        display = EGL14.EGL_NO_DISPLAY
        context = EGL14.EGL_NO_CONTEXT
        pbuffer = EGL14.EGL_NO_SURFACE
        config = null
    }

    private fun eglError(): String = "0x" + Integer.toHexString(EGL14.eglGetError())

    private companion object {
        // EGL_KHR_create_context; EGL14 no lo expone.
        const val EGL_OPENGL_ES3_BIT_KHR = 0x0040
    }
}
