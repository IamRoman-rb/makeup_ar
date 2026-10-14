// Muestreo robusto de una región (F4, informe §10.5 pasos 4 y 6). Port de
// tools/studio/sample_region_reference.py (robust_lab y gloss_score): los tests
// de host reproducen sus resultados sobre datos sintéticos.
#pragma once

#include <vector>

#include "color_math.h"

namespace makeup {

struct RegionColor {
  bool valid = false;           // al menos kRegionMinSamples muestras
  Vec3 lab{0.0f, 0.0f, 0.0f};   // mediana OKLab sin brillos ni sombras
  float gloss = 0.0f;           // gloss_score [0, 1]
  int count = 0;                // muestras de la región
};

// Mediana por canal de las muestras con L entre los cuantiles
// kSampleDropLow y 1 - kSampleDropHigh (interpolación lineal, como
// numpy.quantile), y gloss_score sobre todas. [samples] no se modifica.
RegionColor robustRegionColor(const std::vector<Vec3>& samples);

// Fracción de muestras con L > mediana(L) + kGlossHighDelta, sobre
// kGlossFullAt, recortada a [0, 1].
float glossScore(const std::vector<Vec3>& samples);

// Mediana (numpy: promedio de los dos centrales si la cantidad es par). [values]
// se reordena. 0 si está vacío.
float medianInPlace(std::vector<float>& values);

// Distancia euclídea OKLab (ΔE OK).
float deltaE(const Vec3& a, const Vec3& b);

}  // namespace makeup
