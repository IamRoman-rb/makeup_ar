// Paleta de una foto de producto (F4, informe §10.6): K-means en OKLab sobre
// una miniatura, sin el fondo (lo parecido a la mediana del borde) ni los
// blancos casi puros. Corre en el teléfono, sin LLM. Determinista: semillas
// por el punto más lejano.
#pragma once

#include "color_math.h"
#include "studio/still_image.h"

namespace makeup {

struct PaletteSwatch {
  Vec3 lab{0.0f, 0.0f, 0.0f};
  float rgb[3] = {0.0f, 0.0f, 0.0f};  // sRGB [0,1] (recortado al gamut)
  float fraction = 0.0f;              // fracción de los píxeles útiles
};

// Floats por swatch en la salida de JNI: r, g, b sRGB [0,1] y fracción.
inline constexpr int kPaletteSwatchFloats = 4;

// Hasta [maxSwatches] swatches ordenados por área (de mayor a menor).
// Devuelve cuántos escribió (0 si la foto no tiene colores útiles).
int extractPalette(const StillImage& image, PaletteSwatch* out, int maxSwatches);

}  // namespace makeup
