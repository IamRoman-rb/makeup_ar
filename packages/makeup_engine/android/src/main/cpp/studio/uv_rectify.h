// Rectificación de una foto a UV (F4, informe §10.5 paso 2): la cara de la
// foto se "desenvuelve" sobre la grilla de un mapa del motor (labios, cara u
// ojos) con la misma malla del render. Así las máscaras de los shaders caen
// directo sobre la foto, sin lógica nueva por región.
//
// Por cada triángulo de la región se rasterizan los texels de la grilla que
// cubre en UV; cada texel toma el punto de la foto por baricéntricas y guarda
// su color en OKLab. Los mapas espejados (cara, ojos: media cara, u' =
// min(u, 1 - u) por vértice, como face.vert) se llenan en dos lados: 0 para
// la mitad u < 0,5 de la malla y 1 para la otra.
//
// Los triángulos de espaldas o muy de costado en la foto (área en la foto
// chica respecto de la mediana) no se muestrean: esos texels quedan inválidos.
#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

#include "color_math.h"
#include "studio/still_image.h"

namespace makeup {

struct UvGrid {
  int width = 0;
  int height = 0;
  float rect[4] = {0.0f, 0.0f, 1.0f, 1.0f};  // u0, v0, ancho, alto (v hacia arriba; fila 0 = v0)
  int sides = 1;                             // 2 en los mapas espejados
  std::vector<Vec3> lab;                     // sides × height × width
  std::vector<uint8_t> valid;                // 1 = texel muestreado

  size_t index(int side, int col, int row) const {
    return (static_cast<size_t>(side) * height + row) * width + col;
  }
  // Centro UV del texel (en el espacio espejado si sides == 2).
  float texelU(int col) const { return rect[0] + (static_cast<float>(col) + 0.5f) / width * rect[2]; }
  float texelV(int row) const { return rect[1] + (static_cast<float>(row) + 0.5f) / height * rect[3]; }
};

// Prepara [grid] (width × height sobre [rect]) y la llena con la foto.
// [landmarks]: al menos los 468 de la malla, (x, y, z) en px de la foto.
// [triangles]: índices de la malla (3 por triángulo). Devuelve la cantidad de
// texels válidos.
int rectifyToUv(const StillImage& image, const float* landmarks, const uint16_t* triangles, int triangleCount,
                int width, int height, const float rect[4], bool mirrored, UvGrid* grid);

}  // namespace makeup
