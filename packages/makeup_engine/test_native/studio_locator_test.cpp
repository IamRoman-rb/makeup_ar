// Landmarks de una foto (F4): StillFaceLocator con salidas de modelo armadas
// a mano (detector -> 2 pasadas de landmarks) y sus rechazos.
#include <cmath>
#include <vector>

#include "engine_config.h"
#include "mesh/canonical_mesh.h"
#include "studio/still_face_locator.h"
#include "test_harness.h"
#include "tracking/blazeface_decoder.h"

using makeup::BlazeFaceDecoder;
using makeup::EngineConfig;
using makeup::StillFaceLocator;
using makeup::StillFaceStatus;

namespace {

constexpr int kCoords = BlazeFaceDecoder::kCoordsPerAnchor;

// Una cara de [boxPx] px del tensor en el centro (ancla de la celda (4, 4) de 8×8).
void detection(float boxPx, std::vector<float>* regressors, std::vector<float>* scores) {
  regressors->assign(BlazeFaceDecoder::kAnchorCount * kCoords, 0.0f);
  scores->assign(BlazeFaceDecoder::kAnchorCount, -10.0f);
  const int anchor = 512 + (4 * 8 + 4) * 6;
  float* raw = regressors->data() + anchor * kCoords;
  raw[2] = boxPx;
  raw[3] = boxPx;
  raw[4] = -boxPx / 4;
  raw[5] = -boxPx / 8;
  raw[6] = boxPx / 4;
  raw[7] = -boxPx / 8;
  (*scores)[anchor] = 4.0f;
}

// Landmarks en px del tensor: el UV canónico dentro del 60 % central.
std::vector<float> tensorLandmarks() {
  std::vector<float> out(EngineConfig::kLandmarkCount * 3, 0.0f);
  const float size = static_cast<float>(EngineConfig::kLandmarkInputSize);
  for (int i = 0; i < EngineConfig::kLandmarkCount; ++i) {
    const int vertex = i < makeup::mesh::kVertexCount ? i : 0;
    out[i * 3] = (0.2f + 0.6f * makeup::mesh::kUvs[vertex * 2]) * size;
    out[i * 3 + 1] = (0.2f + 0.6f * (1.0f - makeup::mesh::kUvs[vertex * 2 + 1])) * size;
  }
  return out;
}

void runToEnd(StillFaceLocator* locator, float boxPx, float presenceLogit) {
  std::vector<float> regressors;
  std::vector<float> scores;
  detection(boxPx, &regressors, &scores);
  locator->submitDetections(regressors.data(), static_cast<int>(regressors.size()), scores.data(),
                            static_cast<int>(scores.size()));
  const std::vector<float> points = tensorLandmarks();
  for (int pass = 0; pass < EngineConfig::kStillLandmarkPasses && locator->step() == StillFaceLocator::Step::kLandmarks;
       ++pass) {
    locator->submitLandmarks(points.data(), static_cast<int>(points.size()), presenceLogit);
  }
}

}  // namespace

TEST(localizador_detectorYDosPasadas) {
  StillFaceLocator locator;
  locator.begin(1000, 800);
  CHECK(locator.step() == StillFaceLocator::Step::kDetector);
  CHECK(locator.inputSize() == EngineConfig::kDetectorInputSize);

  makeup::StillImage image;
  image.width = 1000;
  image.height = 800;
  image.rgba.assign(1000 * 800 * 4, 128);
  std::vector<float> input(128 * 128 * 3);
  CHECK(locator.fillInput(image, input.data(), static_cast<int>(input.size()), 2.0f, -1.0f));
  // El letterbox rellena con negro arriba y abajo: -1.
  CHECK_NEAR(input[0], -1.0, 1e-6);
  CHECK_NEAR(input[(64 * 128 + 64) * 3], 128.0 / 255.0 * 2.0 - 1.0, 1e-4);
  CHECK(!locator.fillInput(image, input.data(), 10, 1.0f, 0.0f));

  runToEnd(&locator, 64.0f, 5.0f);
  CHECK(locator.step() == StillFaceLocator::Step::kDone);
  CHECK(locator.status() == StillFaceStatus::kOk);
  CHECK(locator.eyeDistancePx() > EngineConfig::kStillMinEyeDistancePx);
  CHECK(std::fabs(locator.yawRatio()) < 0.05f);
  CHECK(locator.inputSize() == 0);
}

TEST(localizador_sinCara) {
  StillFaceLocator locator;
  locator.begin(640, 480);
  std::vector<float> regressors(BlazeFaceDecoder::kAnchorCount * kCoords, 0.0f);
  std::vector<float> scores(BlazeFaceDecoder::kAnchorCount, -10.0f);
  locator.submitDetections(regressors.data(), static_cast<int>(regressors.size()), scores.data(),
                           static_cast<int>(scores.size()));
  CHECK(locator.step() == StillFaceLocator::Step::kFailed);
  CHECK(locator.status() == StillFaceStatus::kNoFace);
}

TEST(localizador_presenciaBajaYCaraChica) {
  StillFaceLocator low;
  low.begin(1000, 800);
  runToEnd(&low, 64.0f, -5.0f);
  CHECK(low.status() == StillFaceStatus::kLowPresence);

  StillFaceLocator small;
  small.begin(120, 100);
  runToEnd(&small, 64.0f, 5.0f);
  CHECK(small.status() == StillFaceStatus::kFaceTooSmall);
}

TEST(localizador_landmarksNoFinitos) {
  StillFaceLocator locator;
  locator.begin(1000, 800);
  std::vector<float> regressors;
  std::vector<float> scores;
  detection(64.0f, &regressors, &scores);
  locator.submitDetections(regressors.data(), static_cast<int>(regressors.size()), scores.data(),
                           static_cast<int>(scores.size()));
  std::vector<float> points = tensorLandmarks();
  points[10] = NAN;
  locator.submitLandmarks(points.data(), static_cast<int>(points.size()), 5.0f);
  CHECK(locator.status() == StillFaceStatus::kBadImage);
}

TEST(localizador_fotoVaciaYSalidasCortas) {
  StillFaceLocator empty;
  empty.begin(0, 0);
  CHECK(empty.status() == StillFaceStatus::kBadImage);

  StillFaceLocator shortOutputs;
  shortOutputs.begin(640, 480);
  std::vector<float> few(10, 0.0f);
  shortOutputs.submitDetections(few.data(), 10, few.data(), 10);
  CHECK(shortOutputs.status() == StillFaceStatus::kBadImage);
}
