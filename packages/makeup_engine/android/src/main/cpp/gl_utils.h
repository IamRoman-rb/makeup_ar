// RAII para objetos GL y chequeo de errores en debug.
// Los handles se liberan con reset() en el hilo dueño del contexto GL; el
// destructor también libera, así que solo debe correr con el contexto actual.
//
// Plataforma (fase 4, iOS con GLES; docs/ar_engine/IOS.md): headers de GL,
// logging y el tipo de la textura de cámara. Android: GLES 3 + textura
// externa (SurfaceTexture). iOS: OpenGL ES 3 de EAGL + textura 2D de
// CVOpenGLESTextureCache (los shaders cambian samplerExternalOES por
// sampler2D al compilar, gl_program.cpp).
#pragma once

#define MAKEUP_LOG_TAG "makeup_engine"

// tools/ios/check_ios_cpp.py lo define a mano para compilar la rama iOS con el
// NDK (shims de los headers de Apple) y verificarla sin una Mac.
#if defined(__APPLE__) && !defined(MAKEUP_PLATFORM_IOS)
#define MAKEUP_PLATFORM_IOS 1
#endif

#if defined(MAKEUP_PLATFORM_IOS)
#define GLES_SILENCE_DEPRECATION 1
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
#include <os/log.h>

#include <cstdarg>
#include <cstdio>

namespace makeup {
// os_log necesita un formato literal: se formatea antes (solo init y errores).
inline void logLine(os_log_type_t type, const char* format, ...) {
  char buffer[512];
  va_list args;
  va_start(args, format);
  std::vsnprintf(buffer, sizeof(buffer), format, args);
  va_end(args);
  os_log_with_type(OS_LOG_DEFAULT, type, "[%{public}s] %{public}s", MAKEUP_LOG_TAG, buffer);
}
}  // namespace makeup

#define MAKEUP_LOGI(...) ::makeup::logLine(OS_LOG_TYPE_INFO, __VA_ARGS__)
#define MAKEUP_LOGE(...) ::makeup::logLine(OS_LOG_TYPE_ERROR, __VA_ARGS__)
// Textura de cámara: 2D (CVOpenGLESTextureCache), sin extensión.
#define MAKEUP_CAMERA_TEXTURE GL_TEXTURE_2D
#else
// gl3.h antes que gl2ext.h: la extensión usa sus tipos.
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>
#include <android/log.h>

#define MAKEUP_LOGI(...) __android_log_print(ANDROID_LOG_INFO, MAKEUP_LOG_TAG, __VA_ARGS__)
#define MAKEUP_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, MAKEUP_LOG_TAG, __VA_ARGS__)
// Textura de cámara: externa (SurfaceTexture, GL_OES_EGL_image_external_essl3).
#define MAKEUP_CAMERA_TEXTURE GL_TEXTURE_EXTERNAL_OES
#endif

#ifndef NDEBUG
#define MAKEUP_GL_CHECK(label)                                                   \
  do {                                                                           \
    for (GLenum glErr = glGetError(); glErr != GL_NO_ERROR; glErr = glGetError()) \
      MAKEUP_LOGE("GL error 0x%04x en %s", glErr, label);                        \
  } while (0)
#else
#define MAKEUP_GL_CHECK(label) \
  do {                         \
  } while (0)
#endif

namespace makeup {

inline void deleteGlProgram(GLuint id) { glDeleteProgram(id); }
inline void deleteGlBuffer(GLuint id) { glDeleteBuffers(1, &id); }
inline void deleteGlVertexArray(GLuint id) { glDeleteVertexArrays(1, &id); }
inline void deleteGlTexture(GLuint id) { glDeleteTextures(1, &id); }
inline void deleteGlFramebuffer(GLuint id) { glDeleteFramebuffers(1, &id); }

template <void (*Deleter)(GLuint)>
class GlHandle {
 public:
  GlHandle() = default;
  explicit GlHandle(GLuint id) : id_(id) {}
  ~GlHandle() { reset(); }

  GlHandle(const GlHandle&) = delete;
  GlHandle& operator=(const GlHandle&) = delete;
  GlHandle(GlHandle&& other) noexcept : id_(other.release()) {}
  GlHandle& operator=(GlHandle&& other) noexcept {
    if (this != &other) {
      reset();
      id_ = other.release();
    }
    return *this;
  }

  GLuint get() const { return id_; }
  explicit operator bool() const { return id_ != 0; }

  void reset(GLuint id = 0) {
    if (id_ != 0) Deleter(id_);
    id_ = id;
  }

  GLuint release() {
    GLuint id = id_;
    id_ = 0;
    return id;
  }

 private:
  GLuint id_ = 0;
};

using GlProgram = GlHandle<deleteGlProgram>;
using GlBuffer = GlHandle<deleteGlBuffer>;
using GlVertexArray = GlHandle<deleteGlVertexArray>;
using GlTexture = GlHandle<deleteGlTexture>;
using GlFramebuffer = GlHandle<deleteGlFramebuffer>;

}  // namespace makeup
