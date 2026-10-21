// Guía de maquillaje (docs/ar_engine/COACH.md): medir el look de la cámara en
// vivo con lo mismo que "Desde foto" (studio/look_analysis.h), pero con los
// landmarks del tracker en lugar de correr los modelos sobre una foto.
//
// El render recorta el ROI de la cara a kLookSampleSize² (LookSamplePass) y
// pasa los landmarks a px de ese recorte; el hilo del analizador (Kotlin, de
// fondo) mide con analyzeLiveSample. Nada se guarda: solo salen números.
#pragma once

#include <cstdint>

#include "tracking/roi.h"

namespace makeup {

// ROI de la cara para la muestra: el del tracker (línea de los ojos derecha)
// con kLookSampleRoiScale. [points]: landmarks (x, y, z) en px de imagen.
Roi lookSampleRoi(const float* points);

// Landmarks (kLandmarkCount × 3, px de imagen) -> px del recorte de [size]²
// de [roi] (z con la misma escala que x).
void landmarksToSample(const Roi& roi, int size, const float* imagePoints, float* out);

// Mide la muestra: [rgba] de [size]², [points] en px del recorte e
// [imageScale] px de cámara por px del recorte (roi.size / size). Llena [out]
// (kLookValueCount floats, orden de look_analysis.h) con estado, distancia
// entre ojos EN PX DE CÁMARA (el recorte normaliza el tamaño de la cara: es
// la que dice si la cara está lejos), yaw y, si la pose sirve, las medidas
// de cada región.
void analyzeLiveSample(const uint8_t* rgba, int size, const float* points, float imageScale, float* out);

}  // namespace makeup
