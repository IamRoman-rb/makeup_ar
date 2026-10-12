// Extrapolación lineal acotada entre inferencias (informe §5.3.3):
//   p(t) = p_k + v_k · clamp(t - t_k, 0, maxIntervals · (t_k - t_{k-1}))
// con v_k de los dos últimos resultados. El clamp evita el overshoot cuando el
// usuario frena: más allá de ~1,5 intervalos la malla se queda quieta.
#pragma once

#include <cstdint>

namespace makeup {

// [previous] y [latest]: [count] floats (coordenadas) en los instantes
// [previousNs] < [latestNs]. Escribe en [out] el valor en [targetNs].
// Si no hay previo válido (previousNs >= latestNs) copia [latest].
inline void extrapolateLinear(const float* previous, int64_t previousNs, const float* latest,
                              int64_t latestNs, int64_t targetNs, float maxIntervals, int count,
                              float* out) {
  const int64_t interval = latestNs - previousNs;
  if (interval <= 0) {
    for (int i = 0; i < count; ++i) out[i] = latest[i];
    return;
  }
  int64_t ahead = targetNs - latestNs;
  if (ahead < 0) ahead = 0;
  const auto maxAhead = static_cast<int64_t>(maxIntervals * static_cast<float>(interval));
  if (ahead > maxAhead) ahead = maxAhead;
  const float factor = static_cast<float>(ahead) / static_cast<float>(interval);
  for (int i = 0; i < count; ++i) out[i] = latest[i] + (latest[i] - previous[i]) * factor;
}

}  // namespace makeup
