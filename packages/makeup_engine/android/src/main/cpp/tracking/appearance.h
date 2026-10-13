// Medición de apariencia de la cara sobre el recorte de landmarks (CPU, hilo
// del tracker): luminosidad OKLab media del labio y de la piel de las mejillas,
// y la cromaticidad de ambos para la oclusión del labial (lip_occlusion.h).
// El shader de labios usa la L para acercar la del labio a la del color sin
// borrar su textura, adaptándose al tono de piel y a la luz (docs/ar_engine/LIPS.md).
//
// Unas decenas de muestras de 2×2 píxeles por inferencia, mediana robusta a
// brillos y sombras. Sin allocations: scratch en la pila.
#pragma once

#include <array>
#include <cmath>
#include <cstdint>

namespace makeup {

// Muestras de labio: puntos entre el contorno externo y el interno.
inline constexpr int kLipLightnessSamples = 36;
// Muestras de piel: mejillas (por debajo de los ojos, lejos de la boca).
inline constexpr int kSkinLightnessSamples = 10;
// Las primeras de esas muestras de piel, las altas (pómulo y bajo el ojo):
// las de abajo caen en la barba en caras con barba y sesgan el color.
inline constexpr int kSkinChromaSamples = 6;

// Cromaticidad OKLab: (a, b) / L. Con el modelo de sombreado del motor (la
// luz escala L, a y b juntos) no cambia con la sombra: sirve para comparar
// la piel y el labio de la misma cara aunque estén iluminados distinto.
struct Chroma {
  float a = 0.0f;
  float b = 0.0f;
};

// Lo medido en un recorte.
struct FaceSamples {
  float lipLightness = NAN;   // mediana de L del labio [0, 1]; NaN = sin muestras
  float skinLightness = NAN;  // mediana de L de las mejillas [0, 1]
  Chroma skinChroma;          // mediana por componente de las mejillas altas
  bool skinChromaValid = false;
  // Cromaticidad de cada muestra de labio con L suficiente (las muy oscuras
  // no tienen cromaticidad confiable).
  std::array<Chroma, kLipLightnessSamples> lipChroma{};
  int lipChromaCount = 0;
};

// [rgba]: recorte de [size]×[size] RGBA8, fila 0 arriba (el orden del tensor).
// [landmarks]: puntos (x, y, z) en px del tensor, al menos los 468 de la malla.
void measureFace(const uint8_t* rgba, int size, const float* landmarks, FaceSamples* out);

// Atajos sobre measureFace: la mediana de L en [0, 1], o NaN si ninguna
// muestra cae dentro del recorte.
float measureLipLightness(const uint8_t* rgba, int size, const float* landmarks);
float measureSkinLightness(const uint8_t* rgba, int size, const float* landmarks);

}  // namespace makeup
