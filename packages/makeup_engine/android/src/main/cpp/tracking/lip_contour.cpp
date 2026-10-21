#include "tracking/lip_contour.h"

#include <algorithm>
#include <array>
#include <cmath>

#include "color_math.h"
#include "engine_config.h"
#include "mesh/canonical_mesh.h"

namespace makeup {

namespace {

constexpr int kOuter = mesh::kLipsOuterCount;
// Comisuras (61 y 291): el borde ahí dobla y la normal no está definida.
constexpr int kCornerA = 61;
constexpr int kCornerB = 291;
constexpr int kMaxSteps = 64;

// p (0 piel, 1 labio) del píxel (x, y) con interpolación bilineal; NaN fuera
// del recorte o con poca luz (la croma es ruido).
float lipness(const uint8_t* rgba, int size, float x, float y, const Chroma& skin, const Chroma& axis) {
  const float fx = x - 0.5f;
  const float fy = y - 0.5f;
  const int x0 = static_cast<int>(std::floor(fx));
  const int y0 = static_cast<int>(std::floor(fy));
  if (x0 < 0 || y0 < 0 || x0 + 1 >= size || y0 + 1 >= size) return NAN;
  const float tx = fx - static_cast<float>(x0);
  const float ty = fy - static_cast<float>(y0);
  float rgb[3] = {0.0f, 0.0f, 0.0f};
  const float weights[4] = {(1 - tx) * (1 - ty), tx * (1 - ty), (1 - tx) * ty, tx * ty};
  for (int k = 0; k < 4; ++k) {
    const uint8_t* texel = rgba + ((y0 + k / 2) * size + x0 + k % 2) * 4;
    for (int c = 0; c < 3; ++c) rgb[c] += weights[k] * static_cast<float>(texel[c]);
  }
  constexpr float kNorm = 1.0f / 255.0f;
  const Vec3 lab = srgbToOklab(rgb[0] * kNorm, rgb[1] * kNorm, rgb[2] * kNorm);
  if (lab.x < EngineConfig::kLipContourMinLightness) return NAN;
  const float ca = lab.y / lab.x - skin.a;
  const float cb = lab.z / lab.x - skin.b;
  return ca * axis.a + cb * axis.b;
}

}  // namespace

LipContourResult refineLipContour(const uint8_t* rgba, int size, float* points, const Chroma& skin,
                                  const Chroma& axis, float searchPx, float maxShiftPx) {
  LipContourResult result;
  if ((axis.a == 0.0f && axis.b == 0.0f) || searchPx <= 0.0f) return result;
  const float step = EngineConfig::kLipContourStepPx;
  const int half = std::min(static_cast<int>(searchPx / step), kMaxSteps / 2);
  if (half < 1) return result;

  float cx = 0.0f;
  float cy = 0.0f;
  for (int i = 0; i < kOuter; ++i) {
    cx += points[mesh::kLipsOuter[i] * 3];
    cy += points[mesh::kLipsOuter[i] * 3 + 1];
  }
  cx /= kOuter;
  cy /= kOuter;

  std::array<float, kOuter> shift{};
  std::array<bool, kOuter> found{};
  std::array<float, kOuter * 2> normal{};
  std::array<float, kMaxSteps + 1> profile{};
  for (int i = 0; i < kOuter; ++i) {
    const int index = mesh::kLipsOuter[i];
    if (index == kCornerA || index == kCornerB) continue;
    const float* prev = points + mesh::kLipsOuter[(i + kOuter - 1) % kOuter] * 3;
    const float* next = points + mesh::kLipsOuter[(i + 1) % kOuter] * 3;
    const float px = points[index * 3];
    const float py = points[index * 3 + 1];
    float nx = next[1] - prev[1];
    float ny = prev[0] - next[0];
    const float length = std::sqrt(nx * nx + ny * ny);
    if (length <= 0.0f) continue;
    nx /= length;
    ny /= length;
    // Hacia afuera de la boca.
    if (nx * (px - cx) + ny * (py - cy) < 0.0f) {
      nx = -nx;
      ny = -ny;
    }
    normal[i * 2] = nx;
    normal[i * 2 + 1] = ny;
    // Perfil de -half a +half pasos: labio adentro (p ~ 1), piel afuera (p ~ 0).
    bool complete = true;
    for (int k = -half; k <= half; ++k) {
      const float s = static_cast<float>(k) * step;
      const float value = lipness(rgba, size, px + nx * s, py + ny * s, skin, axis);
      if (std::isnan(value)) {
        complete = false;
        break;
      }
      profile[k + half] = value;
    }
    if (!complete) continue;
    // Contraste entre los extremos: sin labio adentro y piel afuera, no hay borde.
    if (profile[0] - profile[2 * half] < EngineConfig::kLipContourMinContrast) continue;
    // El cruce de 0,5 (bajando hacia afuera) más cercano al punto del modelo.
    float best = NAN;
    for (int k = 0; k < 2 * half; ++k) {
      const float a = profile[k] - 0.5f;
      const float b = profile[k + 1] - 0.5f;
      if (a < 0.0f || b > 0.0f || a == b) continue;
      const float s = (static_cast<float>(k - half) + a / (a - b)) * step;
      if (std::isnan(best) || std::fabs(s) < std::fabs(best)) best = s;
    }
    if (std::isnan(best)) continue;
    shift[i] = std::clamp(best, -maxShiftPx, maxShiftPx);
    found[i] = true;
  }

  // Suavizado entre vecinos (1/4, 1/2, 1/4); un vecino sin borde aporta 0.
  std::array<float, kOuter> smooth{};
  for (int i = 0; i < kOuter; ++i) {
    if (!found[i]) continue;
    const int a = (i + kOuter - 1) % kOuter;
    const int b = (i + 1) % kOuter;
    smooth[i] = 0.5f * shift[i] + 0.25f * (found[a] ? shift[a] : shift[i]) + 0.25f * (found[b] ? shift[b] : shift[i]);
  }
  float total = 0.0f;
  for (int i = 0; i < kOuter; ++i) {
    if (!found[i]) continue;
    const int index = mesh::kLipsOuter[i];
    points[index * 3] += normal[i * 2] * smooth[i];
    points[index * 3 + 1] += normal[i * 2 + 1] * smooth[i];
    total += std::fabs(smooth[i]);
    ++result.refined;
  }
  if (result.refined > 0) result.meanShiftPx = total / static_cast<float>(result.refined);
  return result;
}

}  // namespace makeup
