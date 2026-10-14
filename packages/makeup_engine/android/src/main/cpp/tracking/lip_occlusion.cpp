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
    const float minContrast2 = EngineConfig::kOcclusionMinContrast * EngineConfig::kOcclusionMinContrast;

    // Voto de cada posición contra su propia referencia.
    int votes = 0;
    int hidden = 0;
    for (int i = 0; i < kLipLightnessSamples; ++i) {
      if (!samples.lipChromaValid[i] || !hasRef_[i]) continue;
      const float axis2 = distance2(ref_[i], skin);
      if (axis2 < minContrast2) continue;  // sin contraste: no se distingue una mano
      const float p = ((samples.lipChroma[i].a - skin.a) * (ref_[i].a - skin.a) +
                       (samples.lipChroma[i].b - skin.b) * (ref_[i].b - skin.b)) /
                      axis2;
      ++votes;
      if (p < EngineConfig::kOcclusionSampleThreshold) ++hidden;
    }
    if (votes >= EngineConfig::kOcclusionMinSamples) {
      occluded_ = static_cast<float>(hidden) / static_cast<float>(votes);
      target = smoothstep(EngineConfig::kOcclusionGateLow, EngineConfig::kOcclusionGateHigh, occluded_);
    }

    // Aprende cada posición solo si el labio se ve entero (si no, aprendería
    // la mano). Sube rápido cuando la muestra se aleja de la piel: al empezar
    // con la boca tapada o con poco contraste, en cuanto aparece el labio.
    if (occluded_ <= EngineConfig::kOcclusionLearnMaxFraction) {
      for (int i = 0; i < kLipLightnessSamples; ++i) {
        if (!samples.lipChromaValid[i]) continue;
        const Chroma current = samples.lipChroma[i];
        if (!hasRef_[i]) {
          ref_[i] = current;
          hasRef_[i] = true;
          continue;
        }
        const float rate = distance2(current, skin) > distance2(ref_[i], skin) ? EngineConfig::kOcclusionLearnRise
                                                                               : EngineConfig::kOcclusionLearnFall;
        ref_[i].a += (current.a - ref_[i].a) * rate;
        ref_[i].b += (current.b - ref_[i].b) * rate;
      }
    }

    // Eje global para el shader: mediana de las referencias − piel.
    std::array<float, kLipLightnessSamples> a{};
    std::array<float, kLipLightnessSamples> b{};
    int count = 0;
    for (int i = 0; i < kLipLightnessSamples; ++i) {
      if (!hasRef_[i]) continue;
      a[count] = ref_[i].a;
      b[count] = ref_[i].b;
      ++count;
    }
    last_.skin = skin;
    last_.axis = Chroma{};
    if (count > 0) {
      std::nth_element(a.begin(), a.begin() + count / 2, a.begin() + count);
      std::nth_element(b.begin(), b.begin() + count / 2, b.begin() + count);
      const Chroma lip{a[count / 2], b[count / 2]};
      const float axis2 = distance2(lip, skin);
      if (axis2 >= minContrast2) last_.axis = Chroma{(lip.a - skin.a) / axis2, (lip.b - skin.b) / axis2};
    }
    // Sin eje para el shader no hay oclusión (no sabría qué píxel es labio).
    if (last_.axis.a == 0.0f && last_.axis.b == 0.0f) target = 0.0f;
  }
  // Sin medición (target 0), la compuerta se apaga de a poco.
  const float rate = target > gate_ ? EngineConfig::kOcclusionGateAttack : EngineConfig::kOcclusionGateRelease;
  gate_ += (target - gate_) * rate;
  // Debajo del piso, 0 exacto: el shader saltea la oclusión (rama por uniform).
  last_.gate = gate_ < EngineConfig::kOcclusionGateFloor ? 0.0f : gate_;
  return last_;
}

}  // namespace makeup
