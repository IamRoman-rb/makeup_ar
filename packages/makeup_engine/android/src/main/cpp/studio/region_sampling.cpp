#include "studio/region_sampling.h"

#include <algorithm>
#include <cmath>

#include "engine_config.h"

namespace makeup {

namespace {

// numpy.quantile (método lineal) sobre valores ya ordenados.
float quantileSorted(const std::vector<float>& sorted, float q) {
  if (sorted.empty()) return 0.0f;
  const float position = q * static_cast<float>(sorted.size() - 1);
  const size_t below = static_cast<size_t>(std::floor(position));
  const size_t above = std::min(below + 1, sorted.size() - 1);
  const float t = position - static_cast<float>(below);
  return sorted[below] + (sorted[above] - sorted[below]) * t;
}

}  // namespace

float medianInPlace(std::vector<float>& values) {
  if (values.empty()) return 0.0f;
  const size_t mid = values.size() / 2;
  std::nth_element(values.begin(), values.begin() + mid, values.end());
  const float upper = values[mid];
  if (values.size() % 2 == 1) return upper;
  const float lower = *std::max_element(values.begin(), values.begin() + mid);
  return 0.5f * (lower + upper);
}

float deltaE(const Vec3& a, const Vec3& b) {
  const float dl = a.x - b.x;
  const float da = a.y - b.y;
  const float db = a.z - b.z;
  return std::sqrt(dl * dl + da * da + db * db);
}

float glossScore(const std::vector<Vec3>& samples) {
  if (samples.empty()) return 0.0f;
  std::vector<float> lightness;
  lightness.reserve(samples.size());
  for (const Vec3& s : samples) lightness.push_back(s.x);
  const float threshold = medianInPlace(lightness) + EngineConfig::kGlossHighDelta;
  int bright = 0;
  for (const Vec3& s : samples) {
    if (s.x > threshold) ++bright;
  }
  const float fraction = static_cast<float>(bright) / static_cast<float>(samples.size());
  return std::clamp(fraction / EngineConfig::kGlossFullAt, 0.0f, 1.0f);
}

RegionColor robustRegionColor(const std::vector<Vec3>& samples) {
  RegionColor out;
  out.count = static_cast<int>(samples.size());
  if (out.count < EngineConfig::kRegionMinSamples) return out;

  std::vector<float> sorted;
  sorted.reserve(samples.size());
  for (const Vec3& s : samples) sorted.push_back(s.x);
  std::sort(sorted.begin(), sorted.end());
  const float low = quantileSorted(sorted, EngineConfig::kSampleDropLow);
  const float high = quantileSorted(sorted, 1.0f - EngineConfig::kSampleDropHigh);

  std::vector<float> l;
  std::vector<float> a;
  std::vector<float> b;
  l.reserve(samples.size());
  a.reserve(samples.size());
  b.reserve(samples.size());
  for (const Vec3& s : samples) {
    if (s.x < low || s.x > high) continue;
    l.push_back(s.x);
    a.push_back(s.y);
    b.push_back(s.z);
  }
  if (l.empty()) return out;
  out.lab = Vec3{medianInPlace(l), medianInPlace(a), medianInPlace(b)};
  out.gloss = glossScore(samples);
  out.valid = true;
  return out;
}

}  // namespace makeup
