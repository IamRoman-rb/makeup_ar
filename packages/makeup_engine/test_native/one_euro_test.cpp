#include <cmath>
#include <cstdio>
#include <random>

#include "test_harness.h"
#include "tracking/one_euro.h"

using makeup::OneEuroFilter;
using makeup::OneEuroParams;

namespace {

constexpr float kDt = 0.05f;  // 20 Hz, la tasa de inferencia objetivo

// Desvío estándar de la salida con la entrada quieta + ruido gaussiano σ = 1 px.
double restingStd(const OneEuroParams& params) {
  std::mt19937 rng(1234);
  std::normal_distribution<float> noise(0.0f, 1.0f);
  OneEuroFilter filter;
  constexpr int kWarmup = 100;
  constexpr int kSamples = 4000;
  double sum = 0.0;
  double sumSq = 0.0;
  for (int i = 0; i < kWarmup + kSamples; ++i) {
    const float y = filter.filter(100.0f + noise(rng), kDt, params);
    if (i < kWarmup) continue;
    sum += y;
    sumSq += static_cast<double>(y) * y;
  }
  const double mean = sum / kSamples;
  return std::sqrt(sumSq / kSamples - mean * mean);
}

}  // namespace

// Informe §5.3: con σ = 1 px a 20 Hz el desvío en reposo baja a ~0,49 px.
TEST(oneEuro_reduceRuidoEnReposo) {
  const double withBeta = restingStd(OneEuroParams{1.0f, 0.05f, 1.0f});
  const double defaultBeta = restingStd(OneEuroParams{});
  std::printf("    reposo: beta=0.05 -> %.3f px, beta=0.007 -> %.3f px\n", withBeta, defaultBeta);
  CHECK(withBeta < 0.6);
  CHECK(defaultBeta < 0.6);
  CHECK(defaultBeta <= withBeta + 1e-6);  // menos beta = más suavizado en reposo
}

// Informe §5.3: retraso de ~2 px en una rampa de 30 px/s con beta = 0,05.
TEST(oneEuro_retrasoAcotadoEnRampa) {
  const OneEuroParams params{1.0f, 0.05f, 1.0f};
  OneEuroFilter filter;
  float lag = 0.0f;
  for (int i = 0; i < 400; ++i) {
    const float x = 30.0f * kDt * static_cast<float>(i);
    lag = x - filter.filter(x, kDt, params);
  }
  std::printf("    rampa 30 px/s: retraso %.3f px\n", lag);
  CHECK_NEAR(lag, 2.0, 0.5);
}

TEST(oneEuro_primerValorYDtInvalido) {
  OneEuroFilter filter;
  const OneEuroParams params;
  CHECK_NEAR(filter.filter(5.0f, 0.0f, params), 5.0, 0.0);  // sin estado: devuelve x
  CHECK_NEAR(filter.filter(7.0f, kDt, params), 7.0, 0.0);   // primer valor pasa tal cual
  CHECK_NEAR(filter.filter(9.0f, -1.0f, params), 7.0, 0.0); // dt inválido: último filtrado
  filter.reset();
  CHECK_NEAR(filter.filter(3.0f, kDt, params), 3.0, 0.0);
}
