// Adaptación del maquillaje al color de la luz de la escena (P7; FACE.md §11).
// Sin GL: se testea en host.
//
// El motor ya adapta la luminosidad (L medida del labio y de la piel), pero
// no el color de la luz: con una escena cálida el maquillaje quedaba "neutro"
// encima y se veía pegado. Gray-world sobre una miniatura de la cámara
// (ScenePass, 16×16 cada ~0,5 s):
//
//   media     = promedio en RGB lineal (sin píxeles casi negros ni quemados,
//               ni los de la cara: la piel es cálida y, con la cara cerca de
//               la cámara, el gray-world la tomaba por el color de la luz)
//   ganancia  = (media / gris(media)) ^ kLightAdaptDegree, recortada por canal
//               y normalizada a luminancia 1 (la L ya la adapta el sombreado)
//   color     = OKLab -> lineal × ganancia -> OKLab  (cada color de la receta)
//
// La ganancia se suaviza (EMA) para que un cambio de encuadre no salte.
#pragma once

#include <cstdint>

#include "color_math.h"

namespace makeup {

class SceneLightEstimator {
 public:
  void reset();

  // [rgba]: miniatura de [size]×[size] RGBA8 sRGB, fila 0 arriba (la imagen
  // entera). [exclude]: rectángulo (x0, y0, x1, y1) de la imagen normalizada
  // (y hacia abajo) que no cuenta, la cara; nullptr = ninguno. Devuelve true
  // si la ganancia cambió más que kLightAdaptEpsilon desde la última vez que
  // devolvió true (hay que volver a adaptar los colores).
  bool update(const uint8_t* rgba, int size, const float* exclude);

  // Ganancia actual por canal (1, 1, 1 sin medición).
  const Vec3& gain() const { return gain_; }

 private:
  Vec3 gain_{1.0f, 1.0f, 1.0f};
  Vec3 published_{1.0f, 1.0f, 1.0f};
  bool measured_ = false;
};

// Color OKLab bajo la luz de la escena: lineal × ganancia (en el lugar).
void adaptOklab(float lab[3], const Vec3& gain);

}  // namespace makeup
