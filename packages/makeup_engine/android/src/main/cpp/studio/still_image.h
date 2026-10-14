// Foto estática para el Studio (F4; docs/ar_engine/F4_PLAN.md): píxeles en
// RAM, muestreo bilineal y recorte a tensor para los modelos del tracker.
//
// No es camino caliente: corre una vez por foto en el hilo del analizador
// (StillImageAnalyzer.kt), así que puede alocar.
#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

#include "color_math.h"
#include "tracking/roi.h"

namespace makeup {

// RGBA8, fila 0 arriba, sin espejo (como la vería otra persona). Mismo espacio
// "imagen" que tracking/roi.h.
struct StillImage {
  int width = 0;
  int height = 0;
  std::vector<uint8_t> rgba;

  bool valid() const {
    return width > 0 && height > 0 && rgba.size() == static_cast<size_t>(width) * static_cast<size_t>(height) * 4;
  }
};

// ARGB empaquetado (Bitmap.getPixels de Android) -> RGBA8.
void stillImageFromArgb(const int32_t* argb, int width, int height, StillImage* out);

// [count] píxeles ARGB -> RGBA8 en [rgba] (count·4 bytes).
void argbToRgba(const int32_t* argb, int count, uint8_t* rgba);

// sRGB 8 bits -> lineal (tabla de 256 entradas, srgbToLinear de color_math.h).
float srgb8ToLinear(uint8_t value);

// Color sRGB [0,1] en (x, y) px con interpolación bilineal; el centro del
// píxel (i, j) está en (i + 0,5, j + 0,5). Devuelve false (y negro) fuera de
// la imagen.
bool sampleStill(const StillImage& image, float x, float y, float out[3]);

// sRGB 8 bits -> OKLab (con una tabla de sRGB a lineal).
Vec3 srgb8ToOklab(uint8_t r, uint8_t g, uint8_t b);

// sRGB [0,1] -> OKLab.
Vec3 srgbFloatToOklab(const float rgb[3]);

// Tensor RGB float de [size]×[size] del recorte [roi] (espacio de tracking/roi.h):
// valor/255·scale + offset, fila 0 arriba. Supersampling de taps×taps por píxel
// según cuánto se reduce la foto (hasta kStillMaxTaps). Fuera de la foto,
// negro (el relleno del letterbox de MediaPipe). [count] = size²·3.
bool fillStillTensor(const StillImage& image, const Roi& roi, int size, float scale, float offset, float* out,
                     int count);

}  // namespace makeup
