#include <cmath>
#include <memory>
#include <vector>

#include "color_math.h"
#include "mesh/canonical_mesh.h"
#include "test_harness.h"
#include "tracking/appearance.h"
#include "tracking/tracking_state.h"

using makeup::CropRequest;
using makeup::EngineConfig;
using makeup::RenderLandmarks;
using makeup::TrackingState;
namespace mesh = makeup::mesh;

namespace {

constexpr int kSize = EngineConfig::kLandmarkInputSize;
constexpr int64_t kMs = 1000000;
constexpr int64_t kStart = 1000 * kMs;

// Cara canónica en px del tensor (como syntheticLandmarks de
// tracking_state_test), girada [yawRad] alrededor del eje vertical.
std::vector<float> faceLandmarks(float yawRad) {
  std::vector<float> out(TrackingState::kFloats, 0.0f);
  const float c = std::cos(yawRad);
  const float s = std::sin(yawRad);
  for (int i = 0; i < TrackingState::kPoints; ++i) {
    const int v = i < mesh::kVertexCount ? i : 1;
    const float x = mesh::kPositions[v * 3];
    const float y = mesh::kPositions[v * 3 + 1];
    const float z = mesh::kPositions[v * 3 + 2];
    // Rotación Ry: la nariz (+z) gira hacia +x de la imagen con yaw > 0.
    const float rx = c * x + s * z;
    const float rz = -s * x + c * z;
    out[i * 3] = 128.0f + rx * 8.0f;
    out[i * 3 + 1] = 128.0f - y * 8.0f;
    out[i * 3 + 2] = -rz * 8.0f;
  }
  return out;
}

bool insidePolygon(float x, float y, const uint16_t* contour, int count, const float* points) {
  bool inside = false;
  for (int i = 0, j = count - 1; i < count; j = i++) {
    const float xi = points[contour[i] * 3];
    const float yi = points[contour[i] * 3 + 1];
    const float xj = points[contour[j] * 3];
    const float yj = points[contour[j] * 3 + 1];
    if ((yi > y) != (yj > y) && x < xi + (y - yi) * (xj - xi) / (yj - yi)) inside = !inside;
  }
  return inside;
}

// Recorte con piel de un color y labios (entre los contornos) de otro.
void paintFace(uint8_t* rgba, const float* points, const uint8_t skin[3], const uint8_t lip[3]) {
  for (int y = 0; y < kSize; ++y) {
    for (int x = 0; x < kSize; ++x) {
      const float px = static_cast<float>(x) + 0.5f;
      const float py = static_cast<float>(y) + 0.5f;
      const bool isLip = insidePolygon(px, py, mesh::kLipsOuter, mesh::kLipsOuterCount, points) &&
                         !insidePolygon(px, py, mesh::kLipsInner, mesh::kLipsInnerCount, points);
      const uint8_t* color = isLip ? lip : skin;
      uint8_t* out = rgba + (y * kSize + x) * 4;
      out[0] = color[0];
      out[1] = color[1];
      out[2] = color[2];
      out[3] = 255;
    }
  }
}

float lightnessOf(const uint8_t rgb[3]) {
  return makeup::srgbToOklab(rgb[0] / 255.0f, rgb[1] / 255.0f, rgb[2] / 255.0f).x;
}

}  // namespace

TEST(apariencia_mideLabioYPiel) {
  const std::vector<float> face = faceLandmarks(0.0f);
  std::vector<uint8_t> crop(kSize * kSize * 4);
  const uint8_t skin[3] = {205, 160, 135};
  const uint8_t lip[3] = {150, 70, 80};
  paintFace(crop.data(), face.data(), skin, lip);
  CHECK_NEAR(makeup::measureLipLightness(crop.data(), kSize, face.data()), lightnessOf(lip), 0.01);
  CHECK_NEAR(makeup::measureSkinLightness(crop.data(), kSize, face.data()), lightnessOf(skin), 0.01);
}

// Luz quemada (P8): las muestras con un canal saturado no dan croma (para la
// oclusión parecían piel); la L sigue midiéndose.
TEST(apariencia_quemadoNoDaCroma) {
  const std::vector<float> face = faceLandmarks(0.0f);
  std::vector<uint8_t> crop(kSize * kSize * 4);
  const uint8_t skin[3] = {205, 160, 135};
  const uint8_t lip[3] = {150, 70, 80};
  paintFace(crop.data(), face.data(), skin, lip);
  makeup::FaceSamples normal;
  makeup::measureFace(crop.data(), kSize, face.data(), &normal);
  CHECK(normal.lipChromaCount == makeup::kLipLightnessSamples);

  const uint8_t burned[3] = {255, 210, 205};
  paintFace(crop.data(), face.data(), skin, burned);
  makeup::FaceSamples clipped;
  makeup::measureFace(crop.data(), kSize, face.data(), &clipped);
  CHECK(clipped.lipChromaCount == 0);
  CHECK(!std::isnan(clipped.lipLightness));
  CHECK(clipped.skinChromaValid);
}

TEST(apariencia_fueraDelRecorteEsNaN) {
  std::vector<float> face = faceLandmarks(0.0f);
  for (float& value : face) value += 10000.0f;
  std::vector<uint8_t> crop(kSize * kSize * 4, 128);
  CHECK(std::isnan(makeup::measureLipLightness(crop.data(), kSize, face.data())));
  CHECK(std::isnan(makeup::measureSkinLightness(crop.data(), kSize, face.data())));
}

// TrackingState mide sobre el recorte, suaviza y lo pasa al render junto con
// la dirección de vista de la pose.
TEST(apariencia_llegaAlRenderConLaVista) {
  auto state = std::make_unique<TrackingState>();
  state->setImageSize(720, 1280);
  state->start();
  CropRequest request;
  // Detector -> landmarks: se fuerza con una detección sintética como en
  // tracking_state_test.
  CHECK(state->takeCropRequest(kStart, &request));
  state->cropReady(1.0f);
  std::vector<float> regressors(makeup::BlazeFaceDecoder::kAnchorCount *
                                    makeup::BlazeFaceDecoder::kCoordsPerAnchor,
                                0.0f);
  std::vector<float> scores(makeup::BlazeFaceDecoder::kAnchorCount, -10.0f);
  const int anchor = 512 + (4 * 8 + 4) * 6;
  float* raw = regressors.data() + anchor * makeup::BlazeFaceDecoder::kCoordsPerAnchor;
  raw[2] = 64.0f;
  raw[3] = 64.0f;
  raw[4] = -16.0f;
  raw[6] = 16.0f;
  scores[anchor] = 4.0f;
  state->submitDetections(regressors.data(), scores.data(), 6.0f);

  const float yaw = 0.35f;  // ~20°: la nariz apunta a la derecha de la imagen
  const std::vector<float> face = faceLandmarks(yaw);
  const uint8_t skin[3] = {120, 85, 65};
  const uint8_t lip[3] = {95, 45, 50};
  CHECK(state->takeCropRequest(kStart + 50 * kMs, &request));
  paintFace(state->cropPixels(), face.data(), skin, lip);
  state->cropReady(1.0f);
  state->submitLandmarks(face.data(), static_cast<int>(face.size()), 5.0f, 17.0f);

  RenderLandmarks rendered;
  CHECK(state->landmarksForRender(kStart + 60 * kMs, 0.05f, &rendered));
  CHECK_NEAR(rendered.appearance.lipLightness, lightnessOf(lip), 0.02);
  CHECK_NEAR(rendered.appearance.skinLightness, lightnessOf(skin), 0.02);
  // Cara girada a la derecha: la cámara queda hacia la izquierda de la malla.
  CHECK_NEAR(rendered.appearance.viewX, -std::sin(yaw), 0.03);
  CHECK_NEAR(rendered.appearance.viewY, 0.0, 0.03);
  CHECK_NEAR(rendered.appearance.viewZ, std::cos(yaw), 0.03);

  // Un segundo resultado con labios más claros se acerca con la EMA, sin saltar.
  const uint8_t lighter[3] = {200, 120, 130};
  CHECK(state->takeCropRequest(kStart + 100 * kMs, &request));
  paintFace(state->cropPixels(), face.data(), skin, lighter);
  state->cropReady(1.0f);
  state->submitLandmarks(face.data(), static_cast<int>(face.size()), 5.0f, 17.0f);
  CHECK(state->landmarksForRender(kStart + 110 * kMs, 0.05f, &rendered));
  const float expected = lightnessOf(lip) + (lightnessOf(lighter) - lightnessOf(lip)) *
                                                EngineConfig::kAppearanceSmoothing;
  CHECK_NEAR(rendered.appearance.lipLightness, expected, 0.02);
}
