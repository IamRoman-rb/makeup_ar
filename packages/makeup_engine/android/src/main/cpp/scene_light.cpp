#include "scene_light.h"

#include <algorithm>
#include <cmath>

#include "engine_config.h"

namespace makeup {

namespace {

// Luminancia de RGB lineal (Rec. 709, la de sRGB).
float luminance(const Vec3& c) { return 0.2126f * c.x + 0.7152f * c.y + 0.0722f * c.z; }

}  // namespace

void SceneLightEstimator::reset() { *this = SceneLightEstimator{}; }

bool SceneLightEstimator::update(const uint8_t* rgba, int size, const float* exclude) {
  constexpr float kNorm = 1.0f / 255.0f;
  const int pixelCount = size * size;
  const float cell = 1.0f / static_cast<float>(size);
  Vec3 sum{0.0f, 0.0f, 0.0f};
  int used = 0;
  for (int i = 0; i < pixelCount; ++i) {
    if (exclude != nullptr) {
      const float x = (static_cast<float>(i % size) + 0.5f) * cell;
      const float y = (static_cast<float>(i / size) + 0.5f) * cell;
      if (x >= exclude[0] && x <= exclude[2] && y >= exclude[1] && y <= exclude[3]) continue;
    }
    const uint8_t* p = rgba + i * 4;
    // Quemados: un canal saturado ya no dice el color de la luz.
    if (std::max({p[0], p[1], p[2]}) >= EngineConfig::kLightAdaptClippedValue) continue;
    const Vec3 linear{srgbToLinear(p[0] * kNorm), srgbToLinear(p[1] * kNorm), srgbToLinear(p[2] * kNorm)};
    // Casi negros: ruido de la cámara.
    if (luminance(linear) < EngineConfig::kLightAdaptMinLuminance) continue;
    sum.x += linear.x;
    sum.y += linear.y;
    sum.z += linear.z;
    ++used;
  }
  if (used < pixelCount * EngineConfig::kLightAdaptMinFraction || used == 0) return false;

  const float gray = (sum.x + sum.y + sum.z) / 3.0f;
  const auto channel = [gray](float value) {
    return std::clamp(std::pow(value / gray, EngineConfig::kLightAdaptDegree), EngineConfig::kLightAdaptGainMin,
                      EngineConfig::kLightAdaptGainMax);
  };
  Vec3 target{channel(sum.x), channel(sum.y), channel(sum.z)};
  // Luminancia 1: la luminosidad ya la adapta el sombreado relativo.
  const float norm = 1.0f / luminance(target);
  target = Vec3{target.x * norm, target.y * norm, target.z * norm};

  if (!measured_) {
    gain_ = target;
    measured_ = true;
  } else {
    const float rate = EngineConfig::kLightAdaptSmoothing;
    gain_ = Vec3{gain_.x + (target.x - gain_.x) * rate, gain_.y + (target.y - gain_.y) * rate,
                 gain_.z + (target.z - gain_.z) * rate};
  }
  const float change = std::max({std::fabs(gain_.x - published_.x), std::fabs(gain_.y - published_.y),
                                 std::fabs(gain_.z - published_.z)});
  if (change < EngineConfig::kLightAdaptEpsilon) return false;
  published_ = gain_;
  return true;
}

void adaptOklab(float lab[3], const Vec3& gain) {
  const Vec3 linear = oklabToLinear(Vec3{lab[0], lab[1], lab[2]});
  const Vec3 adapted = linearToOklab(Vec3{linear.x * gain.x, linear.y * gain.y, linear.z * gain.z});
  lab[0] = adapted.x;
  lab[1] = adapted.y;
  lab[2] = adapted.z;
}

}  // namespace makeup
