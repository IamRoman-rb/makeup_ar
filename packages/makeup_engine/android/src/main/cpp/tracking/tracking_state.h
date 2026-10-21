// Estado del tracker facial compartido entre el hilo de render y el del
// tracker (Kotlin, LiteRT). No depende de GL ni del modelo concreto: recibe las
// salidas crudas y las pasa a puntos en espacio imagen (ver tracking/roi.h).
//
// Ciclo de un recorte ("cola de un elemento"; stage_ atómico, transiciones con CAS):
//   kIdle --start()--> kWaitRender --takeCropRequest()--> kGpu --cropReady()--> kReady
//   kReady --submit*()--> kWaitRender ...        stop(): cualquiera -> kIdle
// En kGpu el recorte es del render; en kReady, del tracker. Así ningún buffer
// se comparte a la vez y no hace falta mutex en el camino caliente.
//
// Hilos:
//   tracker: start, stop, readyCropKind, fillInput, submitDetections, submitLandmarks, abortCrop
//   render:  setImageSize, takeCropRequest, cropPixels, cropReady, cropFailed, landmarksForRender
//   cualquiera: snapshotStats
// Sin allocations después del constructor.
#pragma once

#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <mutex>

#include "engine_config.h"
#include "stat_window.h"
#include "tracking/blazeface_decoder.h"
#include "tracking/lip_contour.h"
#include "tracking/lip_occlusion.h"
#include "tracking/one_euro.h"
#include "tracking/roi.h"
#include "tracking/triple_buffer.h"

namespace makeup {

enum class CropKind : int32_t { kNone = 0, kDetector = 1, kLandmarks = 2 };

struct CropRequest {
  CropKind kind = CropKind::kNone;
  Roi roi;
  int size = 0;  // lado del tensor, px
  int taps = 1;  // supersampling por eje
};

// Mismo orden que TrackerStats en Dart (vía EngineSession.stats()).
enum TrackerStatIndex : int {
  kTrackStatState = 0,       // 0 apagado/cargando, 1 buscando cara, 2 siguiendo
  kTrackStatLandmarkRuns,    // inferencias de landmarks desde el último reset
  kTrackStatDetectorRuns,    // inferencias del detector
  kTrackStatLosses,          // veces que se perdió la cara
  kTrackStatIntervalP50Ms,   // entre resultados de landmarks (1000 / Hz)
  kTrackStatIntervalP95Ms,
  kTrackStatLandmarkP50Ms,   // landmarks: escribir entrada + run + leer salida (Kotlin)
  kTrackStatLandmarkP95Ms,
  kTrackStatDetectorP50Ms,
  kTrackStatJitterP50Px,     // desplazamiento medio de los puntos estables entre resultados
  kTrackStatPresence,        // último puntaje de presencia [0, 1]
  kTrackStatPitchDeg,        // pose de la cabeza (Procrustes)
  kTrackStatYawDeg,
  kTrackStatRollDeg,
  kTrackStatReadbackMs,      // último recorte: de pedirlo en GPU a tenerlo en CPU
  kTrackStatCropFailures,    // recortes descartados (fence fallido o timeout: GPU ocupada)
  kTrackStatOcclusionGate,   // compuerta de oclusión del labial [0, 1] (lip_occlusion.h)
  kTrackStatFilterMinCutoff, // One Euro en uso (setFilterTuning o engine_config.h)
  kTrackStatFilterBeta,
  kTrackStatLipContourPx,    // ajuste medio del contorno de labios (px del recorte; 0 apagado)
  kTrackStatCount,
};

// Apariencia de la cara medida en cada resultado de landmarks (ver
// tracking/appearance.h). La usa el shader de labios.
struct FaceAppearance {
  float lipLightness = NAN;   // L OKLab mediana del labio [0, 1]; NaN = sin medir
  float skinLightness = NAN;  // L OKLab mediana de las mejillas [0, 1]
  // Dirección hacia la cámara en coordenadas de la malla canónica (x a la
  // derecha de la imagen, y hacia arriba, z hacia la cámara), unitaria. De
  // frente: (0, 0, 1). x/y dicen dónde cae el brillo especular de una luz
  // junto a la cámara; con z, qué parte de la malla queda de espaldas.
  float viewX = 0.0f;
  float viewY = 0.0f;
  float viewZ = 1.0f;
  // Oclusión del labial (tracking/lip_occlusion.h): compuerta [0, 1] y, para
  // el shader, cromaticidad de la piel y eje piel->labio / |eje|².
  float occlusionGate = 0.0f;
  float skinChromaA = 0.0f;
  float skinChromaB = 0.0f;
  float occlusionAxisA = 0.0f;
  float occlusionAxisB = 0.0f;
};

struct RenderLandmarks {
  const float* points = nullptr;  // kLandmarkCount × (x, y, z) en px de imagen
  float alpha = 0.0f;             // fundido [0, 1]
  FaceAppearance appearance;      // del último resultado (no se extrapola)
};

class TrackingState {
 public:
  static constexpr int kPoints = EngineConfig::kLandmarkCount;
  static constexpr int kFloats = kPoints * 3;

  TrackingState();

  void setImageSize(int width, int height);

  // --- Hilo del tracker ---
  void start();
  void stop();
  // Tipo de recorte listo para inferir (kNone si no hay).
  CropKind readyCropKind() const;
  // RGBA8 del recorte listo -> RGB float (valor / 255 · scale + offset).
  // [count] tiene que ser size² · 3. Devuelve false si no hay recorte o no coincide.
  bool fillInput(float* out, int count, float scale, float offset) const;
  // Salidas del detector: [regressors] 896×16, [scores] 896 logits.
  void submitDetections(const float* regressors, const float* scores, float inferenceMs);
  // Salidas de landmarks: [landmarks] >= kFloats floats (x, y, z en px del
  // tensor) y el logit de presencia.
  void submitLandmarks(const float* landmarks, int floatCount, float presenceLogit, float inferenceMs);
  // El recorte listo no se pudo inferir (entrada o salidas inválidas): se
  // descarta y se vuelve al detector. Sin esto el ciclo quedaría en kReady.
  void abortCrop();

  // --- Hilo de render ---
  // Si el tracker pidió un recorte y el throttle lo permite, lo toma (pasa a
  // kGpu) y devuelve true.
  bool takeCropRequest(int64_t cameraTimestampNs, CropRequest* out);
  // Destino del readback: kLandmarkInputSize² · 4 bytes.
  uint8_t* cropPixels() { return cropPixels_.data(); }
  void cropReady(float readbackMs);
  void cropFailed();
  // Puntos extrapolados a [targetTimestampNs] con su fundido. false si no hay
  // nada que dibujar. out->points vale hasta la próxima llamada.
  bool landmarksForRender(int64_t targetTimestampNs, float frameDtSeconds, RenderLandmarks* out);

  // --- Cualquier hilo ---
  // Ajuste del One Euro en vivo (arnés): el tracker lo toma en el próximo
  // resultado. Se recorta a [kOneEuroTuneMin*, kOneEuroTuneMax*].
  void setFilterTuning(float minCutoff, float beta);
  // Segunda pasada sobre la boca (tracking/lip_contour.h). Cualquier hilo.
  void setLipContourRefine(bool enabled);
  void snapshotStats(float* out);
  void resetStats();

 private:
  enum Stage : int { kIdle = 0, kWaitRender, kGpu, kReady };

  struct LandmarkFrame {
    int64_t timestampNs = 0;
    bool present = false;
    bool continuous = false;  // false: no extrapolar desde el resultado anterior
    std::array<float, kFloats> points{};
    FaceAppearance appearance;
  };

  void requestDetector();
  void requestLandmarks(const Roi& roi);
  void finishSubmit();
  void publishLost(int64_t timestampNs);
  void resetFilters();
  // Pose para stats y dirección de vista para el render; false si no se pudo resolver.
  bool updatePose(const float* points, float view[3]);
  // Mide labio y piel sobre el recorte y los suaviza entre resultados.
  void updateAppearance(const float* tensorLandmarks, int size);

  std::atomic<int> stage_{kIdle};
  std::atomic<int> imageWidth_{0};
  std::atomic<int> imageHeight_{0};

  // Pedido del tracker; se lee en takeCropRequest (después de ver kWaitRender).
  CropRequest request_;
  // Recorte en curso; lo escribe el render en takeCropRequest y lo lee el
  // tracker después de ver kReady.
  CropRequest inFlight_;
  int64_t inFlightTimestampNs_ = 0;
  std::array<uint8_t, EngineConfig::kLandmarkInputSize * EngineConfig::kLandmarkInputSize * 4> cropPixels_{};

  // Solo render.
  int64_t lastCropNs_ = 0;
  LandmarkFrame current_;
  LandmarkFrame previous_;
  std::array<float, kFloats> drawPoints_{};
  float alpha_ = 0.0f;

  // Solo tracker.
  BlazeFaceDecoder decoder_;
  OneEuroParams filterParams_;
  std::array<OneEuroFilter, kFloats> filters_{};
  std::array<float, kFloats> raw_{};
  std::array<float, kFloats> filtered_{};
  std::array<float, kFloats> poseTarget_{};
  std::array<float, 80> stableBefore_{};  // x, y de los puntos de Procrustes (33)
  bool hasFace_ = false;
  FaceAppearance appearance_;
  LipOcclusionEstimator occlusion_;
  FaceSamples faceSamples_;  // scratch de updateAppearance
  int64_t lastLandmarkNs_ = 0;
  TripleBuffer<LandmarkFrame> frames_;

  // Ajuste pedido (cualquier hilo); el tracker lo copia a filterParams_.
  std::atomic<float> tuneMinCutoff_{EngineConfig::kOneEuroMinCutoff};
  std::atomic<float> tuneBeta_{EngineConfig::kOneEuroBeta};
  std::atomic<bool> lipContour_{EngineConfig::kLipContourDefault};
  // Solo tracker: landmarks del tensor con el contorno ajustado.
  std::array<float, kFloats> refined_{};
  float lipContourPx_ = 0.0f;  // stats (statsMutex_)

  std::atomic<float> readbackMs_{NAN};
  std::atomic<uint32_t> cropFailures_{0};

  // Stats: tracker escribe, cualquiera lee.
  std::mutex statsMutex_;
  StatWindow interval_;
  StatWindow landmarkMs_;
  StatWindow detectorMs_;
  StatWindow jitter_;
  StatWindow::Samples scratch_{};
  int64_t lastIntervalNs_ = 0;
  uint32_t landmarkRuns_ = 0;
  uint32_t detectorRuns_ = 0;
  uint32_t losses_ = 0;
  int state_ = 0;
  float presence_ = NAN;
  float occlusionGate_ = 0.0f;
  float pitchDeg_ = NAN;
  float yawDeg_ = NAN;
  float rollDeg_ = NAN;
};

}  // namespace makeup
