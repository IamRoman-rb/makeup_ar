#include "tracking/appearance.h"

#include <algorithm>
#include <array>
#include <cmath>

#include "color_math.h"
#include "mesh/canonical_mesh.h"

namespace makeup {

namespace {

// Fracciones del camino contorno externo -> interno donde se muestrea el labio
// (lejos de los dos bordes: ni piel ni dientes).
constexpr float kLipDepths[] = {0.35f, 0.65f};
constexpr int kLipDepthCount = 2;
// Pares externo/interno usados: todos menos las dos comisuras (índices 0 y 10
// de kLipsOuter/kLipsInner), donde el labio se afina a nada.
constexpr int kLipPairCount = mesh::kLipsOuterCount - 2;
static_assert(kLipPairCount * kLipDepthCount == kLipLightnessSamples, "ajustar kLipLightnessSamples");
static_assert(mesh::kLipsOuterCount == mesh::kLipsInnerCount, "los contornos se recorren en pares");

// Mejillas de FaceMesh (mitad izquierda y derecha de la imagen).
constexpr int kCheekLandmarks[kSkinLightnessSamples] = {50, 280, 205, 425, 117, 346, 101, 330, 187, 411};

// L OKLab del promedio 2×2 alrededor de (x, y); NaN fuera del recorte.
float sampleLightness(const uint8_t* rgba, int size, float x, float y) {
  const int x0 = static_cast<int>(std::floor(x - 0.5f));
  const int y0 = static_cast<int>(std::floor(y - 0.5f));
  if (x0 < 0 || y0 < 0 || x0 + 1 >= size || y0 + 1 >= size) return NAN;
  int r = 0;
  int g = 0;
  int b = 0;
  for (int dy = 0; dy < 2; ++dy) {
    const uint8_t* row = rgba + ((y0 + dy) * size + x0) * 4;
    r += row[0] + row[4];
    g += row[1] + row[5];
    b += row[2] + row[6];
  }
  constexpr float kNorm = 1.0f / (4.0f * 255.0f);
  return srgbToOklab(static_cast<float>(r) * kNorm, static_cast<float>(g) * kNorm,
                     static_cast<float>(b) * kNorm)
      .x;
}

template <size_t N>
float median(std::array<float, N>& values, int count) {
  if (count == 0) return NAN;
  float* middle = values.data() + count / 2;
  std::nth_element(values.data(), middle, values.data() + count);
  return *middle;
}

}  // namespace

float measureLipLightness(const uint8_t* rgba, int size, const float* landmarks) {
  std::array<float, kLipLightnessSamples> samples{};
  int count = 0;
  for (int k = 0; k < mesh::kLipsOuterCount; ++k) {
    if (k == 0 || k == mesh::kLipsOuterCount / 2) continue;  // comisuras
    const float* outer = landmarks + mesh::kLipsOuter[k] * 3;
    const float* inner = landmarks + mesh::kLipsInner[k] * 3;
    for (float depth : kLipDepths) {
      const float lightness = sampleLightness(rgba, size, outer[0] + (inner[0] - outer[0]) * depth,
                                              outer[1] + (inner[1] - outer[1]) * depth);
      if (!std::isnan(lightness)) samples[count++] = lightness;
    }
  }
  return median(samples, count);
}

float measureSkinLightness(const uint8_t* rgba, int size, const float* landmarks) {
  std::array<float, kSkinLightnessSamples> samples{};
  int count = 0;
  for (int index : kCheekLandmarks) {
    const float lightness = sampleLightness(rgba, size, landmarks[index * 3], landmarks[index * 3 + 1]);
    if (!std::isnan(lightness)) samples[count++] = lightness;
  }
  return median(samples, count);
}

}  // namespace makeup
