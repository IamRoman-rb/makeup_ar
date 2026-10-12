#include <cmath>
#include <memory>
#include <vector>

#include "mesh/canonical_mesh.h"
#include "test_harness.h"
#include "tracking/tracking_state.h"
#include "tracking/triple_buffer.h"

using makeup::CropKind;
using makeup::CropRequest;
using makeup::EngineConfig;
using makeup::RenderLandmarks;
using makeup::TrackingState;

namespace {

constexpr int64_t kMs = 1000000;
constexpr int64_t kStart = 1000 * kMs;
constexpr int kWidth = 720;
constexpr int kHeight = 1280;

// Salidas del detector con una cara en el ancla de la celda (4, 4) de la
// grilla 8×8 (centro 0.5625, 0.5625 del recorte), caja de 64 px y ojos a ±16 px.
void syntheticDetection(std::vector<float>* regressors, std::vector<float>* scores) {
  constexpr int kCoords = makeup::BlazeFaceDecoder::kCoordsPerAnchor;
  regressors->assign(makeup::BlazeFaceDecoder::kAnchorCount * kCoords, 0.0f);
  scores->assign(makeup::BlazeFaceDecoder::kAnchorCount, -10.0f);
  const int anchor = 512 + (4 * 8 + 4) * 6;
  float* raw = regressors->data() + anchor * kCoords;
  raw[2] = 64.0f;
  raw[3] = 64.0f;
  raw[4] = -16.0f;
  raw[6] = 16.0f;
  (*scores)[anchor] = 4.0f;
}

// Landmarks de una cara frontal en px del tensor 256: la malla canónica (cm)
// escalada ×8 y centrada; y y z invertidas como las da FaceMesh. [shiftX]
// desplaza toda la cara (px del tensor).
std::vector<float> syntheticLandmarks(float shiftX) {
  std::vector<float> out(TrackingState::kFloats, 0.0f);
  for (int i = 0; i < TrackingState::kPoints; ++i) {
    const int v = i < makeup::mesh::kVertexCount ? i : 1;  // iris: cualquier punto
    out[i * 3] = 128.0f + shiftX + makeup::mesh::kPositions[v * 3] * 8.0f;
    out[i * 3 + 1] = 128.0f - makeup::mesh::kPositions[v * 3 + 1] * 8.0f;
    out[i * 3 + 2] = -makeup::mesh::kPositions[v * 3 + 2] * 8.0f;
  }
  return out;
}

// Lleva el estado de kWaitRender a kReady como lo haría el render.
bool renderCrop(TrackingState& state, int64_t timestampNs, CropRequest* request) {
  if (!state.takeCropRequest(timestampNs, request)) return false;
  state.cropReady(1.0f);
  return true;
}

}  // namespace

TEST(tripleBuffer_ultimoValorGana) {
  makeup::TripleBuffer<int> buffer;
  CHECK(!buffer.acquire());
  for (int value = 1; value <= 3; ++value) {
    buffer.writeBuffer() = value;
    buffer.publish();
  }
  CHECK(buffer.acquire());
  CHECK(buffer.readBuffer() == 3);
  CHECK(!buffer.acquire());
  buffer.writeBuffer() = 4;
  buffer.publish();
  CHECK(buffer.acquire());
  CHECK(buffer.readBuffer() == 4);
}

TEST(tracking_sinStartNoPideRecortes) {
  auto state = std::make_unique<TrackingState>();
  state->setImageSize(kWidth, kHeight);
  CropRequest request;
  CHECK(!state->takeCropRequest(kStart, &request));
  CHECK(state->readyCropKind() == CropKind::kNone);
}

TEST(tracking_cicloDetectorLandmarksYPerdida) {
  auto state = std::make_unique<TrackingState>();
  state->setImageSize(kWidth, kHeight);
  state->start();

  // 1) Detector: letterbox de toda la imagen.
  CropRequest request;
  CHECK(renderCrop(*state, kStart, &request));
  CHECK(request.kind == CropKind::kDetector);
  CHECK(request.size == EngineConfig::kDetectorInputSize);
  CHECK_NEAR(request.roi.size, kHeight, 1e-3);
  CHECK(state->readyCropKind() == CropKind::kDetector);

  // fillInput: RGBA -> RGB con escala y offset; tamaño incorrecto se rechaza.
  uint8_t* pixels = state->cropPixels();
  pixels[0] = 255;
  pixels[1] = 0;
  pixels[2] = 51;
  std::vector<float> input(EngineConfig::kDetectorInputSize * EngineConfig::kDetectorInputSize * 3);
  CHECK(state->fillInput(input.data(), static_cast<int>(input.size()), 2.0f, -1.0f));
  CHECK_NEAR(input[0], 1.0, 1e-6);
  CHECK_NEAR(input[1], -1.0, 1e-6);
  CHECK_NEAR(input[2], -0.6, 1e-6);
  CHECK(!state->fillInput(input.data(), 12, 1.0f, 0.0f));

  std::vector<float> regressors;
  std::vector<float> scores;
  syntheticDetection(&regressors, &scores);
  state->submitDetections(regressors.data(), scores.data(), 6.0f);
  CHECK(state->readyCropKind() == CropKind::kNone);

  // 2) Landmarks sobre el ROI de la detección; el throttle espera ~50 ms.
  CHECK(!state->takeCropRequest(kStart + 20 * kMs, &request));
  CHECK(renderCrop(*state, kStart + 50 * kMs, &request));
  CHECK(request.kind == CropKind::kLandmarks);
  CHECK(request.size == EngineConfig::kLandmarkInputSize);
  // Centro del ancla en la imagen: 360 + 0.0625·1280 = 440; 640 + 80 = 720.
  CHECK_NEAR(request.roi.centerX, 440.0, 0.01);
  CHECK_NEAR(request.roi.centerY, 720.0, 0.01);
  CHECK_NEAR(request.roi.size, 640.0 * EngineConfig::kRoiScale, 0.01);
  CHECK_NEAR(request.roi.rotation, 0.0, 1e-5);
  const makeup::Roi landmarkRoi = request.roi;

  const std::vector<float> face = syntheticLandmarks(0.0f);
  state->submitLandmarks(face.data(), static_cast<int>(face.size()), 5.0f, 17.0f);

  // El render ve la cara fundiéndose de entrada y en espacio imagen.
  RenderLandmarks rendered;
  CHECK(state->landmarksForRender(kStart + 60 * kMs, 0.075f, &rendered));
  CHECK_NEAR(rendered.alpha, 0.5, 1e-5);
  const makeup::Point2 nose = makeup::roiToImage(landmarkRoi, face[3] / 256.0f, face[4] / 256.0f);
  CHECK_NEAR(rendered.points[3], nose.x, 1e-3);
  CHECK_NEAR(rendered.points[4], nose.y, 1e-3);

  float stats[makeup::kTrackStatCount];
  state->snapshotStats(stats);
  CHECK_NEAR(stats[makeup::kTrackStatState], 2.0, 0.0);
  CHECK_NEAR(stats[makeup::kTrackStatLandmarkRuns], 1.0, 0.0);
  CHECK_NEAR(stats[makeup::kTrackStatDetectorRuns], 1.0, 0.0);
  // Cara frontal: pose ~0.
  CHECK_NEAR(stats[makeup::kTrackStatYawDeg], 0.0, 0.5);
  CHECK_NEAR(stats[makeup::kTrackStatPitchDeg], 0.0, 0.5);
  CHECK_NEAR(stats[makeup::kTrackStatRollDeg], 0.0, 0.5);

  // 3) Sigue con landmarks sobre un ROI derivado de los puntos.
  CHECK(renderCrop(*state, kStart + 100 * kMs, &request));
  CHECK(request.kind == CropKind::kLandmarks);
  CHECK_NEAR(request.roi.rotation, 0.0, 1e-4);

  // 4) Presencia baja: se pierde la cara, vuelve el detector y el render funde a 0.
  state->submitLandmarks(face.data(), static_cast<int>(face.size()), -5.0f, 17.0f);
  state->snapshotStats(stats);
  CHECK_NEAR(stats[makeup::kTrackStatLosses], 1.0, 0.0);
  CHECK_NEAR(stats[makeup::kTrackStatState], 1.0, 0.0);
  CHECK(renderCrop(*state, kStart + 200 * kMs, &request));
  CHECK(request.kind == CropKind::kDetector);
  CHECK(state->landmarksForRender(kStart + 210 * kMs, 0.03f, &rendered));
  CHECK(!state->landmarksForRender(kStart + 400 * kMs, 0.2f, &rendered));

  // 5) stop(): no hay más recortes y un submit tardío se ignora.
  state->stop();
  CHECK(state->readyCropKind() == CropKind::kNone);
  CHECK(!state->takeCropRequest(kStart + 500 * kMs, &request));
  state->submitDetections(regressors.data(), scores.data(), 6.0f);
  state->snapshotStats(stats);
  CHECK_NEAR(stats[makeup::kTrackStatDetectorRuns], 1.0, 0.0);
  CHECK_NEAR(stats[makeup::kTrackStatState], 0.0, 0.0);
}

// Dos resultados seguidos: el render extrapola hacia adelante (acotado) y el
// jitter mide el desplazamiento entre resultados.
TEST(tracking_extrapolaYMideJitter) {
  auto state = std::make_unique<TrackingState>();
  state->setImageSize(kWidth, kHeight);
  state->start();
  CropRequest request;
  std::vector<float> regressors;
  std::vector<float> scores;
  syntheticDetection(&regressors, &scores);
  CHECK(renderCrop(*state, kStart, &request));
  state->submitDetections(regressors.data(), scores.data(), 6.0f);

  RenderLandmarks rendered;
  int64_t t = kStart;
  float lastX = 0.0f;
  // La cara se mueve 2 px del tensor por resultado, cada 50 ms.
  for (int k = 0; k < 20; ++k) {
    t += 50 * kMs;
    CHECK(renderCrop(*state, t, &request));
    const std::vector<float> face = syntheticLandmarks(2.0f * static_cast<float>(k));
    state->submitLandmarks(face.data(), static_cast<int>(face.size()), 5.0f, 17.0f);
    CHECK(state->landmarksForRender(t, 0.05f, &rendered));
    lastX = rendered.points[3];
  }
  // Media interval después la malla está más adelante que el último resultado.
  CHECK(state->landmarksForRender(t + 25 * kMs, 0.025f, &rendered));
  CHECK(rendered.points[3] > lastX);
  // Muy después, la extrapolación se detiene en 1,5 intervalos.
  CHECK(state->landmarksForRender(t + 500 * kMs, 0.025f, &rendered));
  const float clamped = rendered.points[3];
  CHECK(state->landmarksForRender(t + 900 * kMs, 0.025f, &rendered));
  CHECK_NEAR(rendered.points[3], clamped, 1e-4);

  float stats[makeup::kTrackStatCount];
  state->snapshotStats(stats);
  CHECK(stats[makeup::kTrackStatJitterP50Px] > 0.0f);
  CHECK_NEAR(stats[makeup::kTrackStatIntervalP50Ms], 50.0, 0.01);
}

// Un recorte que no se puede inferir no traba el ciclo: abortCrop vuelve al
// detector y un recorte fallido en GPU se cuenta y se reintenta.
TEST(tracking_seRecuperaDeRecortesInvalidos) {
  auto state = std::make_unique<TrackingState>();
  state->setImageSize(kWidth, kHeight);
  state->start();
  CropRequest request;
  CHECK(renderCrop(*state, kStart, &request));
  CHECK(state->readyCropKind() == CropKind::kDetector);
  state->abortCrop();
  CHECK(state->readyCropKind() == CropKind::kNone);
  // El throttle del detector (10 Hz) devuelve el pedido sin perderlo.
  CHECK(!state->takeCropRequest(kStart + 30 * kMs, &request));
  CHECK(state->takeCropRequest(kStart + 100 * kMs, &request));
  CHECK(request.kind == CropKind::kDetector);
  state->cropFailed();
  CHECK(state->takeCropRequest(kStart + 200 * kMs, &request));

  float stats[makeup::kTrackStatCount];
  state->snapshotStats(stats);
  CHECK_NEAR(stats[makeup::kTrackStatCropFailures], 1.0, 0.0);
  state->resetStats();
  state->snapshotStats(stats);
  CHECK_NEAR(stats[makeup::kTrackStatCropFailures], 0.0, 0.0);
}
