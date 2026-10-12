// Ventana circular preasignada de muestras y percentiles por rango más cercano
// (mismo criterio que ModelBenchmark.percentile en Kotlin). Sin allocations.
// No es thread-safe: el dueño la protege (ver FrameStats, TrackingState).
#pragma once

#include <algorithm>
#include <array>
#include <cmath>

#include "engine_config.h"

namespace makeup {

struct StatWindow {
  using Samples = std::array<float, EngineConfig::kStatsWindow>;

  Samples samples{};
  int head = 0;
  int count = 0;

  void push(float value) {
    samples[head] = value;
    head = (head + 1) % EngineConfig::kStatsWindow;
    if (count < EngineConfig::kStatsWindow) ++count;
  }

  void clear() {
    head = 0;
    count = 0;
  }

  // NaN si está vacía. [scratch] evita copiar sobre la ventana.
  float percentile(Samples& scratch, float p) const {
    if (count == 0) return NAN;
    std::copy_n(samples.begin(), count, scratch.begin());
    int index = static_cast<int>(std::ceil(p * static_cast<float>(count))) - 1;
    index = std::clamp(index, 0, count - 1);
    std::nth_element(scratch.begin(), scratch.begin() + index, scratch.begin() + count);
    return scratch[index];
  }
};

}  // namespace makeup
