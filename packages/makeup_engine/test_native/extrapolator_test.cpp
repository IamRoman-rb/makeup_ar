#include "test_harness.h"
#include "tracking/extrapolator.h"

namespace {
constexpr int64_t kMs = 1000000;
}

TEST(extrapolador_lineal) {
  const float previous[] = {0.0f, 10.0f};
  const float latest[] = {5.0f, 10.0f};
  float out[2];
  // Mitad de un intervalo después del último resultado.
  makeup::extrapolateLinear(previous, 0, latest, 50 * kMs, 75 * kMs, 1.5f, 2, out);
  CHECK_NEAR(out[0], 7.5, 1e-5);
  CHECK_NEAR(out[1], 10.0, 1e-5);
}

TEST(extrapolador_acotado) {
  const float previous[] = {0.0f};
  const float latest[] = {5.0f};
  float out[1];
  // 10 intervalos después: se queda en 1,5 intervalos.
  makeup::extrapolateLinear(previous, 0, latest, 50 * kMs, 550 * kMs, 1.5f, 1, out);
  CHECK_NEAR(out[0], 12.5, 1e-4);
  // Antes del último resultado: no extrapola hacia atrás.
  makeup::extrapolateLinear(previous, 0, latest, 50 * kMs, 10 * kMs, 1.5f, 1, out);
  CHECK_NEAR(out[0], 5.0, 1e-6);
}

TEST(extrapolador_sinPrevioCopia) {
  const float previous[] = {1.0f};
  const float latest[] = {3.0f};
  float out[1];
  makeup::extrapolateLinear(previous, 50 * kMs, latest, 50 * kMs, 80 * kMs, 1.5f, 1, out);
  CHECK_NEAR(out[0], 3.0, 0.0);
}
