// Miniatura de la cámara para la adaptación a la luz (P7, scene_light.h), con
// lectura asíncrona como CropPass (hilo de render).
//
// issue(): cada kScenePassIntervalNs dibuja el frame entero en un FBO RGBA8
// de kScenePassSize² (shaders crop_roi con 4×4 lecturas por píxel), lanza
// glReadPixels hacia un PBO y pone un fence. No bloquea.
// poll(): en frames siguientes, si el fence se cumplió, copia los píxeles.
// Todos los objetos GL se crean en init(): cero allocations por frame.
#pragma once

#include <array>
#include <cstdint>
#include <string>

#include "engine_config.h"
#include "gl_utils.h"

namespace makeup {

class ScenePass {
 public:
  static constexpr int kPixelCount = EngineConfig::kScenePassSize * EngineConfig::kScenePassSize;

  bool init(std::string* error);
  void release();

  // Lanza una lectura si no hay otra en vuelo y pasó el intervalo.
  // [displayMatrix]: UV de salida -> UV de cámara SIN espejo (como CropPass).
  void maybeIssue(GLuint quadVao, GLuint cameraTexture, const float* texMatrix, const float* displayMatrix,
                  int64_t nowNs);

  // true si terminó una lectura: los píxeles quedan en pixels().
  bool poll();

  const uint8_t* pixels() const { return pixels_.data(); }

 private:
  void dropFence();

  GlProgram program_;
  GLint cropMatrix_ = -1;
  GLint displayMatrix_ = -1;
  GLint texMatrix_ = -1;
  GlTexture texture_;
  GlFramebuffer framebuffer_;
  GlBuffer pixelBuffer_;
  GLsync fence_ = nullptr;
  int framesWaiting_ = 0;
  int64_t lastIssueNs_ = 0;
  std::array<uint8_t, kPixelCount * 4> pixels_{};
};

}  // namespace makeup
