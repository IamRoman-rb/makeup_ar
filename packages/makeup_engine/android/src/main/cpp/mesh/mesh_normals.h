// Normales por vértice de la malla canónica (se calculan una vez, al crear la
// geometría GL). Las usa lips.vert para desvanecer el labial en la parte de la
// boca que queda de espaldas a la cámara al girar la cabeza.
#pragma once

#include <cmath>

#include "mesh/canonical_mesh.h"

namespace makeup::mesh {

inline constexpr int kNormalComponents = 3;

// out: kVertexCount × (x, y, z), unitarias y hacia afuera de la cara (z hacia
// la cámara de frente). Promedio de las normales de los triángulos vecinos
// ponderado por área (el producto vectorial sin normalizar). Los triángulos
// de kTriangles están en sentido antihorario visto desde afuera.
inline void computeVertexNormals(float* out) {
  for (int i = 0; i < kVertexCount * kNormalComponents; ++i) out[i] = 0.0f;
  for (int t = 0; t < kTriangleCount; ++t) {
    const int ia = kTriangles[t * 3] * 3;
    const int ib = kTriangles[t * 3 + 1] * 3;
    const int ic = kTriangles[t * 3 + 2] * 3;
    const float e1[3] = {kPositions[ib] - kPositions[ia], kPositions[ib + 1] - kPositions[ia + 1],
                         kPositions[ib + 2] - kPositions[ia + 2]};
    const float e2[3] = {kPositions[ic] - kPositions[ia], kPositions[ic + 1] - kPositions[ia + 1],
                         kPositions[ic + 2] - kPositions[ia + 2]};
    const float n[3] = {e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2],
                        e1[0] * e2[1] - e1[1] * e2[0]};
    for (const int vertex : {ia, ib, ic}) {
      out[vertex] += n[0];
      out[vertex + 1] += n[1];
      out[vertex + 2] += n[2];
    }
  }
  for (int v = 0; v < kVertexCount; ++v) {
    float* n = out + v * kNormalComponents;
    const float length = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    if (length > 0.0f) {
      n[0] /= length;
      n[1] /= length;
      n[2] /= length;
    } else {
      // Vértice sin triángulos (no pasa en la malla de MediaPipe): de frente.
      n[0] = 0.0f;
      n[1] = 0.0f;
      n[2] = 1.0f;
    }
  }
}

}  // namespace makeup::mesh
