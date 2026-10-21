// Segunda pasada sobre la boca (opción 4 de precisión, TRACKER.md §10): ajusta
// los puntos del contorno externo de los labios al borde real, con visión
// clásica y sin otro modelo. Por cada punto de kLipsOuter (salvo las dos
// comisuras) busca, a lo largo de la normal del contorno, dónde la
// cromaticidad pasa de labio a piel (la misma proyección p de la oclusión,
// lip_occlusion.h) e interpola el cruce con precisión subpíxel. El corrimiento
// tiene tope y se suaviza entre vecinos para que el contorno no quede dentado.
//
// Corre en el hilo del tracker sobre el recorte de landmarks ya leído (una
// vez por resultado, ~15 Hz). Sin allocations: todo en la pila. Recibe la
// imagen y los puntos en sus px, así que puede usar más adelante un recorte
// dedicado de la boca a más resolución si el E20 lo pide.
#pragma once

#include <cstdint>

#include "tracking/appearance.h"

namespace makeup {

struct LipContourResult {
  int refined = 0;           // puntos que encontraron el borde
  float meanShiftPx = 0.0f;  // corrimiento medio aplicado (px del recorte)
};

// [rgba]: recorte de [size]² RGBA8, fila 0 arriba. [points]: landmarks (x, y,
// z) en px del recorte, al menos los 468 de la malla; se modifican en su
// lugar los de kLipsOuter. [skin]/[axis]: cromaticidad de la piel y eje
// piel->labio / |eje|² (lip_occlusion.h); con eje cero no hace nada.
// [searchPx]: hasta dónde busca a cada lado; [maxShiftPx]: tope del ajuste.
LipContourResult refineLipContour(const uint8_t* rgba, int size, float* points, const Chroma& skin,
                                  const Chroma& axis, float searchPx, float maxShiftPx);

}  // namespace makeup
