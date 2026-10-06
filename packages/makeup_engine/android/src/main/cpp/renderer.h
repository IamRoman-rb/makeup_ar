// Compositor del spike P1: dibuja el frame de cámara (textura OES) en la
// superficie de Flutter, en paso directo o con tinte OKLab.
//
// Hilos: initGl/draw/releaseGl en el hilo de render (dueño del contexto GL);
// setTint/setDisplayMatrix desde cualquier hilo (atómicos / mutex corto).
#pragma once

#include <array>
#include <atomic>
#include <mutex>
#include <string>

#include "frame_stats.h"
#include "gl_utils.h"

namespace makeup {

class Renderer {
 public:
  // Crea programas, geometría y la textura OES de la cámara. Devuelve el id
  // de la textura OES, o 0 si falla (ver lastError()).
  GLuint initGl();

  // Dibuja un frame y hace eglSwapBuffers sobre la superficie actual.
  // [texMatrix]: 16 floats de SurfaceTexture.getTransformMatrix().
  void drawFrame(const float* texMatrix, int width, int height, int64_t frameStartNs,
                 int64_t cameraTimestampNs);

  void releaseGl();

  // Color sRGB [0,1] e intensidad [0,1]. amount == 0 usa el shader de paso directo.
  void setTint(float r, float g, float b, float amount);

  // 16 floats column-major (ver camera_quad.vert, uDisplayMatrix).
  void setDisplayMatrix(const float* matrix);

  FrameStats& stats() { return stats_; }

  // GL_VENDOR / GL_RENDERER / GL_VERSION / GLSL, tras initGl().
  std::string glInfo() const;
  std::string lastError() const;

 private:
  struct Program {
    GlProgram program;
    GLint displayMatrix = -1;
    GLint texMatrix = -1;
    GLint camera = -1;
    GLint tintAb = -1;
    GLint tintAmount = -1;
    uint32_t uploadedDisplayVersion = 0;  // versión de uDisplayMatrix ya subida
  };

  bool buildProgram(Program& out, const char* fragmentSource);
  void setError(const std::string& error);

  Program passthrough_;
  Program tint_;
  GlVertexArray quadVao_;
  GlBuffer quadVbo_;
  GlTexture cameraTexture_;

  std::atomic<float> tintA_{0.0f};
  std::atomic<float> tintB_{0.0f};
  std::atomic<float> tintAmount_{0.0f};

  mutable std::mutex configMutex_;  // protege displayMatrix_, glInfo_ y lastError_
  std::array<float, 16> displayMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  // Se incrementa en cada setDisplayMatrix: el hilo de render solo toma el
  // mutex cuando cambia (una vez por sesión), no en cada frame.
  std::atomic<uint32_t> displayVersion_{1};

  // Solo hilo de render.
  std::array<float, 16> drawDisplayMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  uint32_t drawDisplayVersion_ = 0;
  std::string glInfo_;
  std::string lastError_;

  FrameStats stats_;
};

}  // namespace makeup
