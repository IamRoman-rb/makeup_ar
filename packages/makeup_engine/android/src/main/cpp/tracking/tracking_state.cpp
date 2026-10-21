#include "tracking/tracking_state.h"

#include <algorithm>
#include <cmath>

#include "mesh/canonical_mesh.h"
#include "tracking/appearance.h"
#include "tracking/extrapolator.h"
#include "tracking/umeyama.h"

namespace makeup {

namespace {

constexpr float kNsPerSecond = 1.0e9f;
constexpr float kNsPerMs = 1.0e6f;
constexpr float kRadToDeg = 57.2957795f;
// Un ROI más chico que esto (px) no es una cara útil: se vuelve al detector.
constexpr float kMinRoiSizePx = 24.0f;

static_assert(mesh::kProcrustesCount * 2 <= 80, "agrandar TrackingState::stableBefore_");
static_assert(mesh::kVertexCount <= EngineConfig::kLandmarkCount, "la malla no entra en los landmarks");

float sigmoid(float logit) {
  const float clamped = std::clamp(logit, -100.0f, 100.0f);
  return 1.0f / (1.0f + std::exp(-clamped));
}

}  // namespace

TrackingState::TrackingState() {
  filterParams_ = OneEuroParams{EngineConfig::kOneEuroMinCutoff, EngineConfig::kOneEuroBeta,
                                EngineConfig::kOneEuroDCutoff};
}

void TrackingState::setImageSize(int width, int height) {
  imageWidth_.store(width, std::memory_order_relaxed);
  imageHeight_.store(height, std::memory_order_relaxed);
}

// --- Hilo del tracker ---

void TrackingState::start() {
  if (stage_.load(std::memory_order_acquire) != kIdle) return;
  hasFace_ = false;
  appearance_ = FaceAppearance{};
  resetFilters();
  {
    std::lock_guard<std::mutex> lock(statsMutex_);
    state_ = 1;
  }
  requestDetector();
  stage_.store(kWaitRender, std::memory_order_release);
}

void TrackingState::stop() {
  stage_.store(kIdle, std::memory_order_release);
  if (hasFace_) publishLost(lastLandmarkNs_);
  hasFace_ = false;
  std::lock_guard<std::mutex> lock(statsMutex_);
  state_ = 0;
}

void TrackingState::abortCrop() {
  if (stage_.load(std::memory_order_acquire) != kReady) return;
  if (hasFace_) publishLost(lastLandmarkNs_);
  hasFace_ = false;
  requestDetector();
  finishSubmit();
}

CropKind TrackingState::readyCropKind() const {
  if (stage_.load(std::memory_order_acquire) != kReady) return CropKind::kNone;
  return inFlight_.kind;
}

bool TrackingState::fillInput(float* out, int count, float scale, float offset) const {
  if (stage_.load(std::memory_order_acquire) != kReady) return false;
  const int pixels = inFlight_.size * inFlight_.size;
  if (count != pixels * 3) return false;
  const float factor = scale / 255.0f;
  const uint8_t* src = cropPixels_.data();
  for (int i = 0; i < pixels; ++i) {
    out[0] = static_cast<float>(src[0]) * factor + offset;
    out[1] = static_cast<float>(src[1]) * factor + offset;
    out[2] = static_cast<float>(src[2]) * factor + offset;
    out += 3;
    src += 4;
  }
  return true;
}

void TrackingState::submitDetections(const float* regressors, const float* scores, float inferenceMs) {
  if (stage_.load(std::memory_order_acquire) != kReady || inFlight_.kind != CropKind::kDetector) return;
  {
    std::lock_guard<std::mutex> lock(statsMutex_);
    ++detectorRuns_;
    detectorMs_.push(inferenceMs);
  }
  FaceDetection detection;
  if (!decoder_.decode(regressors, scores, EngineConfig::kDetectorMinScore,
                       EngineConfig::kDetectorNmsIou, &detection)) {
    requestDetector();
    finishSubmit();
    return;
  }
  // Recorte del detector -> imagen. El letterbox no rota: la caja sigue alineada.
  const Roi& crop = inFlight_.roi;
  const Point2 topLeft = roiToImage(crop, detection.xMin, detection.yMin);
  const Point2 bottomRight =
      roiToImage(crop, detection.xMin + detection.width, detection.yMin + detection.height);
  const Point2 eyeA = roiToImage(crop, detection.keypoints[0], detection.keypoints[1]);
  const Point2 eyeB = roiToImage(crop, detection.keypoints[2], detection.keypoints[3]);
  const Roi roi = roiFromBox(topLeft.x, topLeft.y, bottomRight.x - topLeft.x,
                             bottomRight.y - topLeft.y, eyeA, eyeB, EngineConfig::kRoiScale);
  if (roi.size >= kMinRoiSizePx) {
    requestLandmarks(roi);
  } else {
    requestDetector();
  }
  finishSubmit();
}

void TrackingState::submitLandmarks(const float* landmarks, int floatCount, float presenceLogit,
                                    float inferenceMs) {
  if (stage_.load(std::memory_order_acquire) != kReady || inFlight_.kind != CropKind::kLandmarks) return;
  const int64_t timestampNs = inFlightTimestampNs_;
  const float presence = sigmoid(presenceLogit);
  {
    std::lock_guard<std::mutex> lock(statsMutex_);
    ++landmarkRuns_;
    landmarkMs_.push(inferenceMs);
    presence_ = presence;
  }
  if (floatCount < kFloats || presence < EngineConfig::kPresenceThreshold) {
    if (hasFace_) {
      publishLost(timestampNs);
      std::lock_guard<std::mutex> lock(statsMutex_);
      ++losses_;
    }
    hasFace_ = false;
    {
      std::lock_guard<std::mutex> lock(statsMutex_);
      state_ = 1;
    }
    requestDetector();
    finishSubmit();
    return;
  }

  // Tensor (px) -> imagen (px). z viene en la misma escala que x, y del tensor.
  const Roi roi = inFlight_.roi;
  const float inv = 1.0f / static_cast<float>(inFlight_.size);
  const float zScale = roi.size * inv;
  for (int i = 0; i < kPoints; ++i) {
    const Point2 p = roiToImage(roi, landmarks[i * 3] * inv, landmarks[i * 3 + 1] * inv);
    raw_[i * 3] = p.x;
    raw_[i * 3 + 1] = p.y;
    raw_[i * 3 + 2] = landmarks[i * 3 + 2] * zScale;
  }

  const float dt = static_cast<float>(timestampNs - lastLandmarkNs_) / kNsPerSecond;
  const bool continuous = hasFace_ && dt > 0.0f && dt <= EngineConfig::kFilterResetGapSeconds;
  if (!continuous) {
    resetFilters();
    appearance_ = FaceAppearance{};  // otra cara u otra luz: medir desde cero
    occlusion_.reset();
  }
  // El recorte sigue siendo del tracker (kReady) hasta finishSubmit().
  updateAppearance(landmarks, inFlight_.size);
  // Jitter: desplazamiento medio (2D) de los puntos estables de Procrustes
  // entre dos resultados filtrados. Con la cara quieta, es el temblor.
  float jitterSum = 0.0f;
  if (continuous) {
    for (int n = 0; n < mesh::kProcrustesCount; ++n) {
      const int i = mesh::kProcrustesIndices[n] * 3;
      stableBefore_[n * 2] = filtered_[i];
      stableBefore_[n * 2 + 1] = filtered_[i + 1];
    }
  }
  filterParams_.minCutoff = tuneMinCutoff_.load(std::memory_order_relaxed);
  filterParams_.beta = tuneBeta_.load(std::memory_order_relaxed);
  // dt del primer resultado: cualquier valor > 0 (el filtro devuelve x tal cual).
  for (int i = 0; i < kFloats; ++i) {
    filtered_[i] = filters_[i].filter(raw_[i], continuous ? dt : 1.0f, filterParams_);
  }
  if (continuous) {
    for (int n = 0; n < mesh::kProcrustesCount; ++n) {
      const int i = mesh::kProcrustesIndices[n] * 3;
      jitterSum += std::hypot(filtered_[i] - stableBefore_[n * 2], filtered_[i + 1] - stableBefore_[n * 2 + 1]);
    }
    std::lock_guard<std::mutex> lock(statsMutex_);
    jitter_.push(jitterSum / static_cast<float>(mesh::kProcrustesCount));
  }
  float view[3] = {0.0f, 0.0f, 1.0f};
  if (updatePose(filtered_.data(), view)) {
    appearance_.viewX = view[0];
    appearance_.viewY = view[1];
    appearance_.viewZ = view[2];
  }

  LandmarkFrame& frame = frames_.writeBuffer();
  frame.timestampNs = timestampNs;
  frame.present = true;
  frame.continuous = continuous;
  std::copy(filtered_.begin(), filtered_.end(), frame.points.begin());
  frame.appearance = appearance_;
  frames_.publish();
  hasFace_ = true;
  lastLandmarkNs_ = timestampNs;

  {
    std::lock_guard<std::mutex> lock(statsMutex_);
    state_ = 2;
    if (lastIntervalNs_ > 0 && timestampNs > lastIntervalNs_) {
      interval_.push(static_cast<float>(timestampNs - lastIntervalNs_) / kNsPerMs);
    }
    lastIntervalNs_ = timestampNs;
  }

  // Próximo ROI desde los puntos crudos de la malla (sin iris), como MediaPipe.
  const Roi next = roiFromPoints(raw_.data(), mesh::kVertexCount, 3, mesh::kEyeLeftInImage,
                                 mesh::kEyeRightInImage, EngineConfig::kRoiScale);
  if (next.size >= kMinRoiSizePx) {
    requestLandmarks(next);
  } else {
    requestDetector();
  }
  finishSubmit();
}

void TrackingState::requestDetector() {
  const auto width = static_cast<float>(imageWidth_.load(std::memory_order_relaxed));
  const auto height = static_cast<float>(imageHeight_.load(std::memory_order_relaxed));
  request_ = CropRequest{CropKind::kDetector, letterboxRoi(width, height),
                         EngineConfig::kDetectorInputSize, EngineConfig::kDetectorTaps};
}

void TrackingState::requestLandmarks(const Roi& roi) {
  request_ = CropRequest{CropKind::kLandmarks, roi, EngineConfig::kLandmarkInputSize,
                         EngineConfig::kLandmarkTaps};
}

void TrackingState::finishSubmit() {
  int expected = kReady;
  stage_.compare_exchange_strong(expected, kWaitRender, std::memory_order_acq_rel);
}

void TrackingState::publishLost(int64_t timestampNs) {
  LandmarkFrame& frame = frames_.writeBuffer();
  frame.timestampNs = timestampNs;
  frame.present = false;
  frame.continuous = false;
  frames_.publish();
}

void TrackingState::resetFilters() {
  for (auto& filter : filters_) filter.reset();
}

void TrackingState::updateAppearance(const float* tensorLandmarks, int size) {
  measureFace(cropPixels_.data(), size, tensorLandmarks, &faceSamples_);
  const float lip = faceSamples_.lipLightness;
  const float skin = faceSamples_.skinLightness;
  // EMA: una sola inferencia con un reflejo o un parpadeo de la luz no mueve
  // el color del labial de golpe.
  const auto smooth = [](float previous, float value) {
    if (std::isnan(value)) return previous;
    if (std::isnan(previous)) return value;
    return previous + (value - previous) * EngineConfig::kAppearanceSmoothing;
  };
  appearance_.lipLightness = smooth(appearance_.lipLightness, lip);
  appearance_.skinLightness = smooth(appearance_.skinLightness, skin);
  const LipOcclusion occlusion = occlusion_.update(faceSamples_);
  appearance_.occlusionGate = occlusion.gate;
  {
    std::lock_guard<std::mutex> lock(statsMutex_);
    occlusionGate_ = occlusion.gate;
  }
  appearance_.skinChromaA = occlusion.skin.a;
  appearance_.skinChromaB = occlusion.skin.b;
  appearance_.occlusionAxisA = occlusion.axis.a;
  appearance_.occlusionAxisB = occlusion.axis.b;
}

bool TrackingState::updatePose(const float* points, float view[3]) {
  // La malla canónica tiene y hacia arriba y z hacia la cámara; la imagen, y
  // hacia abajo y z (de FaceMesh) creciendo al alejarse: se invierten ambas.
  for (int n = 0; n < mesh::kProcrustesCount; ++n) {
    const int i = mesh::kProcrustesIndices[n] * 3;
    poseTarget_[i] = points[i];
    poseTarget_[i + 1] = -points[i + 1];
    poseTarget_[i + 2] = -points[i + 2];
  }
  SimilarityTransform pose{};
  if (!solveSimilarity(mesh::kPositions, poseTarget_.data(), mesh::kProcrustesIndices,
                       mesh::kProcrustesWeights, mesh::kProcrustesCount, &pose)) {
    return false;
  }
  // destino = s·R·malla + t, con la cámara mirando por +z del destino: la
  // dirección a la cámara en la malla es Rᵀ·(0, 0, 1), la fila 2 de R.
  view[0] = pose.rotation[6];
  view[1] = pose.rotation[7];
  view[2] = pose.rotation[8];
  const EulerAngles angles = eulerFromRotation(pose.rotation);
  std::lock_guard<std::mutex> lock(statsMutex_);
  pitchDeg_ = angles.pitch * kRadToDeg;
  yawDeg_ = angles.yaw * kRadToDeg;
  rollDeg_ = angles.roll * kRadToDeg;
  return true;
}

// --- Hilo de render ---

bool TrackingState::takeCropRequest(int64_t cameraTimestampNs, CropRequest* out) {
  if (stage_.load(std::memory_order_acquire) != kWaitRender) return false;
  // request_ se lee recién con el stage tomado (kGpu): así el tracker no puede
  // reescribirlo a la vez (stop() + start() entre la lectura y el CAS).
  int expected = kWaitRender;
  if (!stage_.compare_exchange_strong(expected, kGpu, std::memory_order_acq_rel)) return false;
  const CropRequest request = request_;
  const float maxHz = request.kind == CropKind::kDetector ? EngineConfig::kDetectorMaxHz
                                                          : EngineConfig::kTrackerMaxHz;
  const auto minIntervalNs = static_cast<int64_t>(kNsPerSecond / maxHz);
  // Tolerancia de 2 ms: con cámara a 30 fps los frames llegan cada ~33 ms y
  // sin margen un pedido a 20 Hz podría saltearse un frame de más.
  if (lastCropNs_ > 0 && cameraTimestampNs - lastCropNs_ < minIntervalNs - 2000000) {
    // Todavía no: se devuelve el pedido (si el tracker paró mientras, queda en kIdle).
    expected = kGpu;
    stage_.compare_exchange_strong(expected, kWaitRender, std::memory_order_acq_rel);
    return false;
  }
  inFlight_ = request;
  inFlightTimestampNs_ = cameraTimestampNs;
  lastCropNs_ = cameraTimestampNs;
  *out = request;
  return true;
}

void TrackingState::cropReady(float readbackMs) {
  readbackMs_.store(readbackMs, std::memory_order_relaxed);
  int expected = kGpu;
  stage_.compare_exchange_strong(expected, kReady, std::memory_order_acq_rel);
}

void TrackingState::cropFailed() {
  cropFailures_.fetch_add(1, std::memory_order_relaxed);
  int expected = kGpu;
  stage_.compare_exchange_strong(expected, kWaitRender, std::memory_order_acq_rel);
}

bool TrackingState::landmarksForRender(int64_t targetTimestampNs, float frameDtSeconds,
                                       RenderLandmarks* out) {
  if (frames_.acquire()) {
    const LandmarkFrame& frame = frames_.readBuffer();
    if (frame.present) {
      if (current_.present && frame.continuous) {
        previous_ = current_;
      } else {
        previous_ = frame;  // sin velocidad: no se extrapola desde un salto
      }
      current_ = frame;
    } else {
      current_.present = false;  // se conservan los puntos para el fundido de salida
    }
  }
  const float step = frameDtSeconds / EngineConfig::kFadeSeconds;
  alpha_ = std::clamp(alpha_ + (current_.present ? step : -step), 0.0f, 1.0f);
  if (alpha_ <= 0.0f) return false;
  if (current_.present) {
    extrapolateLinear(previous_.points.data(), previous_.timestampNs, current_.points.data(),
                      current_.timestampNs, targetTimestampNs,
                      EngineConfig::kExtrapolationMaxIntervals, kFloats, drawPoints_.data());
  }
  out->points = drawPoints_.data();
  out->alpha = alpha_;
  out->appearance = current_.appearance;
  return true;
}

// --- Cualquier hilo ---

void TrackingState::setFilterTuning(float minCutoff, float beta) {
  // NaN o fuera de rango: se recorta (std::clamp con NaN no es seguro).
  const float cutoff = std::isfinite(minCutoff) ? minCutoff : EngineConfig::kOneEuroMinCutoff;
  const float b = std::isfinite(beta) ? beta : EngineConfig::kOneEuroBeta;
  tuneMinCutoff_.store(std::clamp(cutoff, EngineConfig::kOneEuroTuneMinCutoff, EngineConfig::kOneEuroTuneMaxCutoff),
                       std::memory_order_relaxed);
  tuneBeta_.store(std::clamp(b, 0.0f, EngineConfig::kOneEuroTuneMaxBeta), std::memory_order_relaxed);
}

// --- Stats ---

void TrackingState::snapshotStats(float* out) {
  std::lock_guard<std::mutex> lock(statsMutex_);
  out[kTrackStatState] = static_cast<float>(state_);
  out[kTrackStatLandmarkRuns] = static_cast<float>(landmarkRuns_);
  out[kTrackStatDetectorRuns] = static_cast<float>(detectorRuns_);
  out[kTrackStatLosses] = static_cast<float>(losses_);
  out[kTrackStatIntervalP50Ms] = interval_.percentile(scratch_, 0.50f);
  out[kTrackStatIntervalP95Ms] = interval_.percentile(scratch_, 0.95f);
  out[kTrackStatLandmarkP50Ms] = landmarkMs_.percentile(scratch_, 0.50f);
  out[kTrackStatLandmarkP95Ms] = landmarkMs_.percentile(scratch_, 0.95f);
  out[kTrackStatDetectorP50Ms] = detectorMs_.percentile(scratch_, 0.50f);
  out[kTrackStatJitterP50Px] = jitter_.percentile(scratch_, 0.50f);
  out[kTrackStatPresence] = presence_;
  out[kTrackStatPitchDeg] = pitchDeg_;
  out[kTrackStatYawDeg] = yawDeg_;
  out[kTrackStatRollDeg] = rollDeg_;
  out[kTrackStatReadbackMs] = readbackMs_.load(std::memory_order_relaxed);
  out[kTrackStatCropFailures] = static_cast<float>(cropFailures_.load(std::memory_order_relaxed));
  // Sin cara la compuerta no se actualiza: 0, no el último valor.
  out[kTrackStatOcclusionGate] = state_ == 2 ? occlusionGate_ : 0.0f;
  out[kTrackStatFilterMinCutoff] = tuneMinCutoff_.load(std::memory_order_relaxed);
  out[kTrackStatFilterBeta] = tuneBeta_.load(std::memory_order_relaxed);
}

void TrackingState::resetStats() {
  std::lock_guard<std::mutex> lock(statsMutex_);
  interval_.clear();
  landmarkMs_.clear();
  detectorMs_.clear();
  jitter_.clear();
  lastIntervalNs_ = 0;
  landmarkRuns_ = 0;
  detectorRuns_ = 0;
  losses_ = 0;
  cropFailures_.store(0, std::memory_order_relaxed);
}

}  // namespace makeup
