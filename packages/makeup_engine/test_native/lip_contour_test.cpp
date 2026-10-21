// Segunda pasada sobre la boca (tracking/lip_contour.h): con un labio
// sintético (elipse de color labio sobre piel), los puntos del contorno
// corridos hacia afuera vuelven al borde real.
#include <cmath>
#include <cstdint>
#include <vector>

#include "color_math.h"
#include "engine_config.h"
#include "mesh/canonical_mesh.h"
#include "test_harness.h"
#include "tracking/lip_contour.h"

namespace {

constexpr int kSize = 256;
constexpr float kCx = 128.0f;
constexpr float kCy = 160.0f;
constexpr float kRx = 40.0f;
constexpr float kRy = 16.0f;
constexpr float kPi = 3.14159265f;
const float kSkin[3] = {0.82f, 0.64f, 0.56f};
const float kLip[3] = {0.72f, 0.36f, 0.38f};

makeup::Chroma chroma(const float rgb[3]) {
  const makeup::Vec3 lab = makeup::srgbToOklab(rgb[0], rgb[1], rgb[2]);
  return makeup::Chroma{lab.y / lab.x, lab.z / lab.x};
}

// Eje piel->labio / |eje|² (como lip_occlusion.h).
makeup::Chroma axis() {
  const makeup::Chroma s = chroma(kSkin);
  const makeup::Chroma l = chroma(kLip);
  const float da = l.a - s.a;
  const float db = l.b - s.b;
  const float d2 = da * da + db * db;
  return makeup::Chroma{da / d2, db / d2};
}

float ellipse(float x, float y) {
  const float dx = (x - kCx) / kRx;
  const float dy = (y - kCy) / kRy;
  return std::sqrt(dx * dx + dy * dy) - 1.0f;
}

std::vector<uint8_t> image(float scale = 1.0f) {
  std::vector<uint8_t> rgba(static_cast<size_t>(kSize) * kSize * 4);
  for (int y = 0; y < kSize; ++y) {
    for (int x = 0; x < kSize; ++x) {
      const bool lip = ellipse(x + 0.5f, y + 0.5f) < 0.0f;
      const float* c = lip ? kLip : kSkin;
      uint8_t* out = rgba.data() + (static_cast<size_t>(y) * kSize + x) * 4;
      for (int k = 0; k < 3; ++k) out[k] = static_cast<uint8_t>(std::lround(c[k] * scale * 255.0f));
      out[3] = 255;
    }
  }
  return rgba;
}

// Landmarks con el contorno externo sobre la elipse agrandada [grow] px.
std::vector<float> points(float grow) {
  std::vector<float> p(static_cast<size_t>(makeup::EngineConfig::kLandmarkCount) * 3, 0.0f);
  for (int i = 0; i < makeup::mesh::kLipsOuterCount; ++i) {
    // 61 (comisura izquierda) -> labio inferior -> 291 -> labio superior.
    const float phi = kPi - static_cast<float>(i) * 2.0f * kPi / makeup::mesh::kLipsOuterCount;
    const int index = makeup::mesh::kLipsOuter[i];
    p[index * 3] = kCx + (kRx + grow) * std::cos(phi);
    p[index * 3 + 1] = kCy + (kRy + grow) * std::sin(phi);
  }
  return p;
}

bool corner(int index) { return index == 61 || index == 291; }

}  // namespace

TEST(contornoLabios_vuelveAlBordeReal) {
  const std::vector<uint8_t> rgba = image();
  std::vector<float> p = points(1.5f);
  const std::vector<float> before = p;
  const makeup::Chroma skin = chroma(kSkin);
  const makeup::LipContourResult result = makeup::refineLipContour(
      rgba.data(), kSize, p.data(), skin, axis(), makeup::EngineConfig::kLipContourSearchPx,
      makeup::EngineConfig::kLipContourMaxShiftPx);
  CHECK(result.refined >= makeup::mesh::kLipsOuterCount - 2);
  CHECK(result.meanShiftPx > 0.8f);
  for (int i = 0; i < makeup::mesh::kLipsOuterCount; ++i) {
    const int index = makeup::mesh::kLipsOuter[i];
    if (corner(index)) continue;
    const float was = std::fabs(ellipse(before[index * 3], before[index * 3 + 1]));
    const float now = std::fabs(ellipse(p[index * 3], p[index * 3 + 1]));
    CHECK(now < 0.5f * was);
  }
}

TEST(contornoLabios_sinEjeOSinLuzNoToca) {
  std::vector<float> p = points(1.5f);
  const std::vector<float> before = p;
  const std::vector<uint8_t> rgba = image();
  // Sin eje (sin contraste aprendido): nada.
  makeup::refineLipContour(rgba.data(), kSize, p.data(), chroma(kSkin), makeup::Chroma{}, 3.0f, 2.0f);
  CHECK(p == before);
  // Muy oscuro: la croma no sirve.
  const std::vector<uint8_t> dark = image(0.08f);
  const makeup::LipContourResult result =
      makeup::refineLipContour(dark.data(), kSize, p.data(), chroma(kSkin), axis(), 3.0f, 2.0f);
  CHECK(result.refined == 0);
  CHECK(p == before);
}

TEST(contornoLabios_topeDelAjuste) {
  // Corridos 2,6 px: el borde está a la vista (búsqueda de 3) pero el ajuste
  // se corta en 1 px.
  const std::vector<uint8_t> rgba = image();
  std::vector<float> p = points(2.6f);
  const std::vector<float> before = p;
  makeup::refineLipContour(rgba.data(), kSize, p.data(), chroma(kSkin), axis(), 3.0f, 1.0f);
  for (int i = 0; i < makeup::mesh::kLipsOuterCount; ++i) {
    const int index = makeup::mesh::kLipsOuter[i];
    const float moved = std::hypot(p[index * 3] - before[index * 3], p[index * 3 + 1] - before[index * 3 + 1]);
    CHECK(moved <= 1.0f + 1e-4f);
  }
}
