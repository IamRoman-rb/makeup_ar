// Muestra de la cara para la guía de maquillaje (docs/ar_engine/COACH.md),
// con lectura asíncrona como CropPass (hilo de render).
//
// issue(): dibuja el ROI de la cara desde la textura de la cámara a un FBO
// RGBA8 de kLookSampleSize² (shaders crop_roi, 2×2 lecturas por píxel), lanza
// glReadPixels hacia un PBO y pone un fence. No bloquea.
// poll(): en frames siguientes, si el fence se cumplió, copia los píxeles.
// Una muestra a pedido (la guía pide una cada ~1,5 s), nunca por frame.
// Todos los objetos GL se crean en init(): cero allocations por frame.
#pragma once

#include <cstdint>
#include <string>

#include "engine_config.h"
#include "gl_utils.h"
#include "tracking/roi.h"

namespace makeup {

class LookSamplePass {
 public:
  enum class Poll { kIdle, kPending, kDone, kFailed };

  static constexpr int kSize = EngineConfig::kLookSampleSize;
  static constexpr int kBytes = kSize * kSize * 4;

  bool init(std::string* error);
  void release();

  bool inFlight() const { return fence_ != nullptr; }

  // [displayMatrix]: UV de salida -> UV de cámara SIN espejo (como CropPass).
  // Deja enlazado el framebuffer 0. false si no se pudo poner el fence.
  bool issue(const Roi& roi, GLuint quadVao, GLuint cameraTexture, const float* texMatrix,
             const float* displayMatrix, int imageWidth, int imageHeight);

  // Si la lectura en vuelo terminó, copia kBytes a [dst] y devuelve kDone.
  Poll poll(uint8_t* dst);

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
};

}  // namespace makeup
