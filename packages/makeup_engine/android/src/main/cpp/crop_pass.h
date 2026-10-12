// Recorte del tracker en GPU con lectura asíncrona (hilo de render).
//
// issue(): dibuja el ROI desde la textura OES de la cámara a un FBO RGBA8 de
// N×N, lanza glReadPixels hacia un PBO y pone un fence. No bloquea.
// poll(): en frames siguientes, si el fence ya se cumplió, mapea el PBO y
// copia los píxeles. Un solo recorte en vuelo a la vez.
// Todos los objetos GL se crean en init(): cero allocations por frame.
#pragma once

#include <cstdint>
#include <string>

#include "gl_utils.h"
#include "tracking/tracking_state.h"

namespace makeup {

class CropPass {
 public:
  enum class Poll { kIdle, kPending, kDone, kFailed };

  bool init(std::string* error);
  void release();

  bool inFlight() const { return fence_ != nullptr; }

  // [quadVao]: quad de pantalla completa con aPosition en la ubicación 0.
  // [displayMatrix]: UV de salida -> UV de cámara SIN espejo.
  // [imageWidth]/[imageHeight]: tamaño de la imagen (= salida) en px.
  // Deja enlazado el framebuffer 0.
  void issue(const CropRequest& request, GLuint quadVao, GLuint cameraTexture, const float* texMatrix,
             const float* displayMatrix, int imageWidth, int imageHeight, int64_t nowNs);

  // Si el recorte en vuelo terminó, copia size² · 4 bytes a [dst] y devuelve kDone.
  Poll poll(uint8_t* dst, float* readbackMs, int64_t nowNs);

 private:
  struct Program {
    GlProgram program;
    GLint cropMatrix = -1;
    GLint displayMatrix = -1;
    GLint texMatrix = -1;
  };

  struct Target {
    GlTexture texture;
    GlFramebuffer framebuffer;
    int size = 0;
  };

  bool buildProgram(Program& out, const char* defines, std::string* error);
  bool buildTarget(Target& out, int size, std::string* error);
  void dropFence();

  Program detectorProgram_;
  Program landmarkProgram_;
  Target detectorTarget_;
  Target landmarkTarget_;
  GlBuffer pixelBuffer_;
  GLsync fence_ = nullptr;
  int pendingBytes_ = 0;
  int framesWaiting_ = 0;
  int64_t issuedNs_ = 0;
};

}  // namespace makeup
