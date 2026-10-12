// Medición de apariencia de la cara sobre el recorte de landmarks (CPU, hilo
// del tracker): luminosidad OKLab media del labio y de la piel de las mejillas.
// El shader de labios la usa para acercar la L del labio a la del color sin
// borrar su textura, adaptándose al tono de piel y a la luz (docs/ar_engine/LIPS.md).
//
// Unas decenas de muestras de 2×2 píxeles por inferencia, mediana robusta a
// brillos y sombras. Sin allocations: scratch en la pila.
#pragma once

#include <cstdint>

namespace makeup {

// Muestras de labio: puntos entre el contorno externo y el interno.
inline constexpr int kLipLightnessSamples = 36;
// Muestras de piel: mejillas (por debajo de los ojos, lejos de la boca).
inline constexpr int kSkinLightnessSamples = 10;

// [rgba]: recorte de [size]×[size] RGBA8, fila 0 arriba (el orden del tensor).
// [landmarks]: puntos (x, y, z) en px del tensor, al menos los 468 de la malla.
// Devuelven la mediana de L OKLab en [0, 1], o NaN si ninguna muestra cae
// dentro del recorte.
float measureLipLightness(const uint8_t* rgba, int size, const float* landmarks);
float measureSkinLightness(const uint8_t* rgba, int size, const float* landmarks);

}  // namespace makeup
