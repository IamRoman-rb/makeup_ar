#include "tracking/lip_occlusion.h"

#include <algorithm>
#include <array>

#include "engine_config.h"

namespace makeup {

namespace {

float smoothstep(float edge0, float edge1, float x) {
  const float t = std::clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

// Mediana por componente de las muestras de labio (count > 0).
Chroma medianChroma(const FaceSamples& samples) {
  std::array<float, kLipLightnessSamples> a{};
  std::array<float, kLipLightnessSamples> b{};
  const int count = samples.lipChromaCount;
  for (int i = 0; i < count; ++i) {
    a[i] = samples.lipChroma[i].a;
    b[i] = samples.lipChroma[i].b;
  }
  std::nth_element(a.begin(), a.begin() + count / 2, a.begin() + count);
  std::nth_element(b.begin(), b.begin() + count / 2, b.begin() + count);
  return Chroma{a[count / 2], b[count / 2]};
}

float distance2(Chroma p, Chroma q) {
  const float da = p.a - q.a;
  const float db = p.b - q.b;
  return da * da + db * db;
}

}  // namespace

void LipOcclusionEstimator::reset() { *this = LipOcclusionEstimator{}; }

LipOcclusion LipOcclusionEstimator::update(const FaceSamples& samples) {
  float target = 0.0f;
  occluded_ = 0.0f;
  if (samples.skinChromaValid && samples.lipChromaCount >= EngineConfig::kOcclusionMinSamples) {
    const Chroma skin = samples.skinChroma;
    const Chroma current = medianChroma(samples);
    if (!hasLip_) {
      lip_ = current;
      hasLip_ = true;
    }
    const float minContrast2 = EngineConfig::kOcclusionMinContrast * EngineConfig::kOcclusionMinContrast;
    float axis2 = distance2(lip_, skin);
    if (axis2 >= minContrast2) {
      const float axisA = (lip_.a - skin.a) / axis2;
      const float axisB = (lip_.b - skin.b) / axis2;
      int hidden = 0;
      for (int i = 0; i < samples.lipChromaCount; ++i) {
        const float p =
            (samples.lipChroma[i].a - skin.a) * axisA + (samples.lipChroma[i].b - skin.b) * axisB;
        if (p < EngineConfig::kOcclusionSampleThreshold) ++hidden;
      }
      occluded_ = static_cast<float>(hidden) / static_cast<float>(samples.lipChromaCount);
      target = smoothstep(EngineConfig::kOcclusionGateLow, EngineConfig::kOcclusionGateHigh, occluded_);
    }
    // Aprende el labio solo si se ve entero (si no, aprendería la mano). Sube
    // rápido cuando el labio medido se aleja de la piel: al empezar con la
    // boca tapada o con poco contraste, en cuanto aparece el labio.
    if (occluded_ <= EngineConfig::kOcclusionLearnMaxFraction) {
      const float rate = distance2(current, skin) > axis2 ? EngineConfig::kOcclusionLearnRise
                                                          : EngineConfig::kOcclusionLearnFall;
      lip_.a += (current.a - lip_.a) * rate;
      lip_.b += (current.b - lip_.b) * rate;
      axis2 = distance2(lip_, skin);
    }
    last_.skin = skin;
    if (axis2 >= minContrast2) {
      last_.axis = Chroma{(lip_.a - skin.a) / axis2, (lip_.b - skin.b) / axis2};
    } else {
      last_.axis = Chroma{};
      target = 0.0f;
    }
  }
  // Sin medición (target 0), la compuerta se apaga de a poco.
  const float rate = target > gate_ ? EngineConfig::kOcclusionGateAttack : EngineConfig::kOcclusionGateRelease;
  gate_ += (target - gate_) * rate;
  // Debajo del piso, 0 exacto: el shader saltea la oclusión (rama por uniform).
  last_.gate = gate_ < EngineConfig::kOcclusionGateFloor ? 0.0f : gate_;
  return last_;
}

}  // namespace makeup
