// Landmarks de una foto estática con los mismos modelos del tracker (F4).
//
// Kotlin (StillImageAnalyzer) corre los modelos; esta clase arma los tensores
// y decodifica las salidas, igual que TrackingState pero sin hilos, sin
// filtros y sin GPU:
//   kDetector: letterbox de toda la foto -> BlazeFace -> ROI de la cara.
//   kLandmarks: recorte del ROI -> FaceMesh-V2, kStillLandmarkPasses veces
//               (la segunda con el ROI de los landmarks de la primera).
//   kDone: landmarks() en px de la foto; kFailed: status() dice por qué.
#pragma once

#include <array>
#include <cstdint>

#include "engine_config.h"
#include "studio/still_image.h"
#include "tracking/blazeface_decoder.h"
#include "tracking/roi.h"

namespace makeup {

// Mismo orden que FaceImageStatus en Dart (makeup_engine.dart).
enum class StillFaceStatus : int {
  kOk = 0,
  kNoFace = 1,        // el detector no encontró una cara
  kFaceTooSmall = 2,  // distancia entre ojos < kStillMinEyeDistancePx
  kLowPresence = 3,   // el modelo de landmarks no confirmó la cara
  kProfile = 4,       // cara muy girada (kStillMaxYawRatio)
  kBadImage = 5,      // foto vacía o salidas del modelo inválidas
};

class StillFaceLocator {
 public:
  enum class Step : int { kDetector = 0, kLandmarks = 1, kDone = 2, kFailed = 3 };

  static constexpr int kPoints = EngineConfig::kLandmarkCount;

  // Empieza con la foto de [width]×[height] px.
  void begin(int width, int height);

  Step step() const { return step_; }
  StillFaceStatus status() const { return status_; }
  // Lado del tensor del paso actual (0 si terminó).
  int inputSize() const;
  const Roi& roi() const { return roi_; }

  // Tensor del paso actual: valor/255·scale + offset. false si no hay paso o
  // [count] no coincide.
  bool fillInput(const StillImage& image, float* out, int count, float scale, float offset) const;
  // Salidas del detector: regresores 896×16 y scores 896.
  void submitDetections(const float* regressors, int regressorCount, const float* scores, int scoreCount);
  // Salidas de landmarks: (x, y, z) en px del tensor y el logit de presencia.
  void submitLandmarks(const float* landmarks, int floatCount, float presenceLogit);
  // El paso no se pudo correr (modelo caído): termina en kFailed/kBadImage.
  void fail(StillFaceStatus status);

  // kPoints × (x, y, z) en px de la foto (z en la escala de x). Válidos en kDone.
  const float* landmarks() const { return points_.data(); }
  // Medidas de la cara de la última pasada: distancia entre ojos (px) y
  // desplazamiento de la nariz en distancias entre ojos (signo: hacia +x
  // de la línea de los ojos).
  float eyeDistancePx() const { return eyeDistancePx_; }
  float yawRatio() const { return yawRatio_; }

 private:
  void finish(StillFaceStatus status);

  BlazeFaceDecoder decoder_;
  Step step_ = Step::kFailed;
  StillFaceStatus status_ = StillFaceStatus::kBadImage;
  int width_ = 0;
  int height_ = 0;
  Roi roi_;
  int landmarkPasses_ = 0;
  float eyeDistancePx_ = 0.0f;
  float yawRatio_ = 0.0f;
  std::array<float, kPoints * 3> points_{};
};

}  // namespace makeup
