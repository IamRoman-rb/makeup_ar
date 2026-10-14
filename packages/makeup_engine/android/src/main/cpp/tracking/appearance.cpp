#include "tracking/appearance.h"

#include <algorithm>
#include <array>
#include <cmath>

#include "color_math.h"
#include "engine_config.h"
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

// Mejillas de FaceMesh (mitad izquierda y derecha de la imagen). Las
// kSkinChromaSamples primeras son las altas (pómulo, bajo el ojo).
constexpr int kCheekLandmarks[kSkinLightnessSamples] = {50, 280, 117, 346, 101, 330, 205, 425, 187, 411};
static_assert(kSkinChromaSamples <= kSkinLightnessSamples, "las muestras de color son de piel");

// Por debajo de esta L, (a, b) / L amplifica el ruido de la cámara.
constexpr float kChromaMinLightness = 0.15f;

// OKLab del promedio 2×2 alrededor de (x, y); L = NaN fuera del recorte.
// [clipped]: algún canal sRGB >= kOcclusionClipValue (luz quemada: la croma
// se lava hacia la de la piel y no sirve para la oclusión).
Vec3 sampleOklab(const uint8_t* rgba, int size, float x, float y, bool* clipped) {
  *clipped = false;
  const int x0 = static_cast<int>(std::floor(x - 0.5f));
  const int y0 = static_cast<int>(std::floor(y - 0.5f));
  if (x0 < 0 || y0 < 0 || x0 + 1 >= size || y0 + 1 >= size) return Vec3{NAN, 0.0f, 0.0f};
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
  const float brightest = static_cast<float>(std::max({r, g, b})) * kNorm;
  *clipped = brightest >= EngineConfig::kOcclusionClipValue;
  return srgbToOklab(static_cast<float>(r) * kNorm, static_cast<float>(g) * kNorm,
                     static_cast<float>(b) * kNorm);
}

template <size_t N>
float median(std::array<float, N>& values, int count) {
  if (count == 0) return NAN;
  float* middle = values.data() + count / 2;
  std::nth_element(values.data(), middle, values.data() + count);
  return *middle;
}

}  // namespace

void measureFace(const uint8_t* rgba, int size, const float* landmarks, FaceSamples* out) {
  *out = FaceSamples{};
  std::array<float, kLipLightnessSamples> lipL{};
  int lipCount = 0;
  int position = 0;
  for (int k = 0; k < mesh::kLipsOuterCount; ++k) {
    if (k == 0 || k == mesh::kLipsOuterCount / 2) continue;  // comisuras
    const float* outer = landmarks + mesh::kLipsOuter[k] * 3;
    const float* inner = landmarks + mesh::kLipsInner[k] * 3;
    for (float depth : kLipDepths) {
      const int index = position++;
      bool clipped = false;
      const Vec3 lab = sampleOklab(rgba, size, outer[0] + (inner[0] - outer[0]) * depth,
                                   outer[1] + (inner[1] - outer[1]) * depth, &clipped);
      if (std::isnan(lab.x)) continue;
      lipL[lipCount++] = lab.x;
      // Las quemadas no cuentan para la oclusión: ni tapadas ni labio.
      if (lab.x >= kChromaMinLightness && !clipped) {
        out->lipChroma[index] = Chroma{lab.y / lab.x, lab.z / lab.x};
        out->lipChromaValid[index] = true;
        ++out->lipChromaCount;
      }
    }
  }
  out->lipLightness = median(lipL, lipCount);

  std::array<float, kSkinLightnessSamples> skinL{};
  std::array<float, kSkinChromaSamples> skinA{};
  std::array<float, kSkinChromaSamples> skinB{};
  int skinCount = 0;
  int chromaCount = 0;
  for (int n = 0; n < kSkinLightnessSamples; ++n) {
    const int index = kCheekLandmarks[n];
    bool clipped = false;
    const Vec3 lab = sampleOklab(rgba, size, landmarks[index * 3], landmarks[index * 3 + 1], &clipped);
    if (std::isnan(lab.x)) continue;
    skinL[skinCount++] = lab.x;
    if (n < kSkinChromaSamples && lab.x >= kChromaMinLightness && !clipped) {
      skinA[chromaCount] = lab.y / lab.x;
      skinB[chromaCount] = lab.z / lab.x;
      ++chromaCount;
    }
  }
  out->skinLightness = median(skinL, skinCount);
  // Al menos la mitad de las muestras altas: con menos, la mediana es un punto suelto.
  if (chromaCount * 2 >= kSkinChromaSamples) {
    out->skinChroma = Chroma{median(skinA, chromaCount), median(skinB, chromaCount)};
    out->skinChromaValid = true;
  }
}

float measureLipLightness(const uint8_t* rgba, int size, const float* landmarks) {
  FaceSamples samples;
  measureFace(rgba, size, landmarks, &samples);
  return samples.lipLightness;
}

float measureSkinLightness(const uint8_t* rgba, int size, const float* landmarks) {
  FaceSamples samples;
  measureFace(rgba, size, landmarks, &samples);
  return samples.skinLightness;
}

}  // namespace makeup
