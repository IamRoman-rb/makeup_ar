// Filtro One Euro (Casiez et al., 2012) para una señal escalar.
// Port 1:1 de la clase Dart del informe §5.3 (misma semántica: la derivada se
// estima con el valor crudo anterior). Sin allocations: el estado son 5 floats.
#pragma once

#include <cmath>

namespace makeup {

struct OneEuroParams {
  float minCutoff = 1.0f;  // Hz
  float beta = 0.007f;     // s: cuánto sube el corte con la velocidad
  float dCutoff = 1.0f;    // Hz, para la derivada
};

class OneEuroFilter {
 public:
  // [dt] en segundos. Si dt <= 0 devuelve el último valor filtrado (o x si no hay).
  float filter(float x, float dt, const OneEuroParams& params) {
    if (dt <= 0.0f) return hasValue_ ? xHat_ : x;
    const float dx = hasValue_ ? (x - prevRaw_) / dt : 0.0f;
    prevRaw_ = x;

    const float aD = alpha(dt, params.dCutoff);
    dxHat_ = hasValue_ ? aD * dx + (1.0f - aD) * dxHat_ : dx;

    const float cutoff = params.minCutoff + params.beta * std::fabs(dxHat_);
    const float a = alpha(dt, cutoff);
    xHat_ = hasValue_ ? a * x + (1.0f - a) * xHat_ : x;
    hasValue_ = true;
    return xHat_;
  }

  void reset() { hasValue_ = false; }

 private:
  static float alpha(float dt, float cutoff) {
    constexpr float kTwoPi = 6.28318530718f;
    const float tau = 1.0f / (kTwoPi * cutoff);
    return 1.0f / (1.0f + tau / dt);
  }

  bool hasValue_ = false;
  float prevRaw_ = 0.0f;
  float xHat_ = 0.0f;
  float dxHat_ = 0.0f;
};

}  // namespace makeup
