// Oclusión del labial (P7; docs/ar_engine/LIPS.md §9): una mano, un dedo o un
// objeto delante de la boca. Sin modelo de segmentación: el tracker sigue
// poniendo la boca donde estaba, pero las muestras del labio (FaceSamples)
// pasan a tener el color de la piel.
//
// Cada una de las kLipLightnessSamples posiciones del labio tiene su propia
// referencia (P9): con luz de costado, la mitad iluminada de un labio pálido
// queda más cerca de la piel que la otra, y con una referencia única votaba
// como "tapada" aunque no hubiera mano. Comparada consigo misma, no.
//
// En cada inferencia (hilo del tracker, sin allocations):
//   eje_i     = referencia_i − piel, en cromaticidad (a, b) / L
//   p_i       = dot(c_i − piel, eje_i) / |eje_i|²   (0 = piel, 1 = labio)
//   tapadas   = fracción de las muestras que votan (válidas, con referencia y
//               contraste suficiente) con p_i < kOcclusionSampleThreshold
//   compuerta = smoothstep(kOcclusionGateLow, kOcclusionGateHigh, tapadas),
//               suavizada (sube rápido, baja más lento)
// El shader (lips.frag) recibe la compuerta, la piel y un eje global (mediana
// de las referencias − piel) / |eje|², y con la compuerta prendida saca el
// labial de cada píxel que se parece a la piel.
//
// Las referencias se aprenden solo mientras el labio se ve entero (y suben
// rápido cuando la muestra se aleja de la piel), así no aprenden la mano. Una
// posición sin contraste con la piel no vota: no se puede distinguir.
// Referencia de lo que hace el shader: tools/lips/lip_shading.py (occlusion).
#pragma once

#include <array>

#include "tracking/appearance.h"

namespace makeup {

struct LipOcclusion {
  float gate = 0.0f;  // [0, 1]; 0 = sin oclusión (el shader no hace nada)
  Chroma skin;        // cromaticidad de la piel
  Chroma axis;        // (labio − piel) / |labio − piel|² (labio = mediana de las referencias)
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
  std::array<Chroma, kLipLightnessSamples> ref_{};
  std::array<bool, kLipLightnessSamples> hasRef_{};
  float gate_ = 0.0f;
  float occluded_ = 0.0f;
  LipOcclusion last_;
};

}  // namespace makeup
