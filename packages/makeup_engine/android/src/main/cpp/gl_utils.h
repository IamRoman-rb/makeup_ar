// RAII para objetos GL y chequeo de errores en debug.
// Los handles se liberan con reset() en el hilo dueño del contexto GL; el
// destructor también libera, así que solo debe correr con el contexto actual.
#pragma once

#include <GLES3/gl3.h>
#include <android/log.h>

#define MAKEUP_LOG_TAG "makeup_engine"
#define MAKEUP_LOGI(...) __android_log_print(ANDROID_LOG_INFO, MAKEUP_LOG_TAG, __VA_ARGS__)
#define MAKEUP_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, MAKEUP_LOG_TAG, __VA_ARGS__)

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

}  // namespace makeup
