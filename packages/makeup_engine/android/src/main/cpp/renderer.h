// Compositor: dibuja el frame de cámara (textura OES) en la superficie de
// Flutter, en paso directo o con tinte OKLab (pantalla completa o solo labios),
// alimenta al tracker con recortes del mismo frame (CropPass) y, opcionalmente,
// dibuja los landmarks encima.
//
// Hilos: initGl/drawFrame/releaseGl en el hilo de render (dueño del contexto
// GL); setTint/setDisplayMatrices/setRenderOptions desde cualquier hilo
// (atómicos / mutex corto que el render solo toma cuando algo cambió).
#pragma once

#include <array>
#include <atomic>
#include <mutex>
#include <string>

#include "crop_pass.h"
#include "frame_stats.h"
#include "gl_utils.h"
#include "tracking/tracking_state.h"

namespace makeup {

// Bits del valor que devuelve drawFrame (y nativeDrawFrame a Kotlin).
enum FrameFlag : int {
  kFrameFlagCropReady = 1,  // hay un recorte listo: avisar al hilo del tracker
};

// Dónde se aplica el tinte. Mismo orden que TintRegion en Dart.
enum class TintRegion : int { kFull = 0, kLips = 1 };

class Renderer {
 public:
  // [tracking] no es dueño; tiene que vivir más que el Renderer.
  explicit Renderer(TrackingState* tracking) : tracking_(tracking) {}

  // Crea programas, geometría y la textura OES de la cámara. Devuelve el id
  // de la textura OES, o 0 si falla (ver lastError()).
  GLuint initGl();

  // Procesa un frame: termina/lanza el recorte del tracker, dibuja y hace
  // eglSwapBuffers sobre la superficie actual. [texMatrix]: 16 floats de
  // SurfaceTexture.getTransformMatrix(). Devuelve bits de FrameFlag.
  int drawFrame(const float* texMatrix, int width, int height, int64_t frameStartNs,
                int64_t cameraTimestampNs);

  void releaseGl();

  // Color sRGB [0,1] e intensidad [0,1]. amount == 0 usa el shader de paso directo.
  void setTint(float r, float g, float b, float amount);

  // 16 floats column-major cada una (ver camera_quad.vert, uDisplayMatrix):
  // [display] con espejo, para la pantalla; [tracker] sin espejo, para los
  // recortes. [mirrored]: la pantalla está espejada respecto de la imagen.
  void setDisplayMatrices(const float* display, const float* tracker, bool mirrored);

  void setRenderOptions(bool showLandmarks, TintRegion region);

  FrameStats& stats() { return stats_; }

  // GL_VENDOR / GL_RENDERER / GL_VERSION / GLSL, tras initGl().
  std::string glInfo() const;
  std::string lastError() const;

 private:
  struct Program {
    GlProgram program;
    GLint displayMatrix = -1;
    GLint texMatrix = -1;
    GLint tintAb = -1;
    GLint tintAmount = -1;
    uint32_t uploadedDisplayVersion = 0;  // versión de uDisplayMatrix ya subida
  };

  struct MeshProgram {
    GlProgram program;
    GLint imageToClip = -1;
    GLint pointSize = -1;
    GLint color = -1;
  };

  bool buildProgram(Program& out, const char* fragmentSource, const char* defines);
  bool buildMeshProgram();
  bool buildMeshGeometry();
  bool ensureMask(int width, int height);
  void runCropPass(const float* texMatrix, int width, int height, int64_t cameraTimestampNs,
                   int64_t nowNs, int* flags);
  void uploadMesh(const float* points);
  void drawLipsMask(float alpha, const float* imageToClip);
  void drawLandmarks(float alpha, const float* imageToClip, int width, int height);
  void setError(const std::string& error);

  TrackingState* tracking_;

  Program passthrough_;
  Program tint_;
  Program tintMasked_;
  MeshProgram mesh_;
  CropPass crop_;
  GlVertexArray quadVao_;
  GlBuffer quadVbo_;
  GlTexture cameraTexture_;
  GlVertexArray meshVao_;
  GlBuffer meshVbo_;
  GlBuffer lipsIbo_;
  GlTexture maskTexture_;
  GlFramebuffer maskFramebuffer_;
  int maskWidth_ = 0;
  int maskHeight_ = 0;

  std::atomic<float> tintA_{0.0f};
  std::atomic<float> tintB_{0.0f};
  std::atomic<float> tintAmount_{0.0f};
  std::atomic<bool> showLandmarks_{false};
  std::atomic<int> region_{static_cast<int>(TintRegion::kFull)};

  // Protege displayMatrix_, trackerMatrix_, mirrored_, glInfo_ y lastError_.
  mutable std::mutex configMutex_;
  std::array<float, 16> displayMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  std::array<float, 16> trackerMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  bool mirrored_ = true;
  // Se incrementa en cada setDisplayMatrices: el hilo de render solo toma el
  // mutex cuando cambia (una vez por sesión), no en cada frame.
  std::atomic<uint32_t> displayVersion_{1};

  // Solo hilo de render.
  std::array<float, 16> drawDisplayMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  std::array<float, 16> drawTrackerMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  bool drawMirrored_ = true;
  uint32_t drawDisplayVersion_ = 0;
  std::array<float, EngineConfig::kLandmarkCount * 2> meshPoints_{};
  int64_t lastFrameStartNs_ = 0;
  std::string glInfo_;
  std::string lastError_;

  FrameStats stats_;
};

}  // namespace makeup
