// Oclusión del labial (P7; docs/ar_engine/LIPS.md §9): una mano, un dedo o un
// objeto delante de la boca. Sin modelo de segmentación: el tracker sigue
// poniendo la boca donde estaba, pero las muestras del labio (FaceSamples)
// pasan a tener el color de la piel.
//
// En cada inferencia (hilo del tracker, sin allocations):
//   eje       = labio de referencia − piel, en cromaticidad (a, b) / L
//   p         = dot(c − piel, eje) / |eje|²   (0 = piel, 1 = labio)
//   tapadas   = fracción de muestras de labio con p < kOcclusionSampleThreshold
//   compuerta = smoothstep(kOcclusionGateLow, kOcclusionGateHigh, tapadas),
//               suavizada (sube rápido, baja más lento)
// El shader (lips.frag) recibe la compuerta, la piel y eje / |eje|², y con la
// compuerta prendida saca el labial de cada píxel que se parece a la piel.
//
// El labio de referencia se aprende solo mientras se ve entero (y sube rápido
// cuando el labio se aleja de la piel), así no aprende la mano. Si el
// contraste piel-labio es muy bajo, no hay oclusión: no se puede distinguir.
// Referencia de lo que hace el shader: tools/lips/lip_shading.py (occlusion).
#pragma once

#include "tracking/appearance.h"

namespace makeup {

struct LipOcclusion {
  float gate = 0.0f;  // [0, 1]; 0 = sin oclusión (el shader no hace nada)
  Chroma skin;        // cromaticidad de la piel
  Chroma axis;        // (labio − piel) / |labio − piel|²
};

class LipOcclusionEstimator {
 public:
  // Otra cara u otra luz: se aprende desde cero.
  void reset();

  // Una inferencia.
  LipOcclusion update(const FaceSamples& samples);

  // Fracción de muestras tapadas en la última inferencia (tests).
  float occludedFraction() const { return occluded_; }

 private:
  Chroma lip_;
  bool hasLip_ = false;
  float gate_ = 0.0f;
  float occluded_ = 0.0f;
  LipOcclusion last_;
};

}  // namespace makeup
