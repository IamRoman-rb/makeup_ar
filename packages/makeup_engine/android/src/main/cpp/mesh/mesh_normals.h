// Normales por vértice de la malla canónica (se calculan una vez, al crear la
// geometría GL). Las usa lips.vert para desvanecer el labial en la parte de la
// boca que queda de espaldas a la cámara al girar la cabeza.
#pragma once

#include <cmath>
#include <cstdint>

#include "mesh/canonical_mesh.h"

namespace makeup::mesh {

inline constexpr int kNormalComponents = 3;

// out: [vertexCount] × (x, y, z), unitarias y hacia afuera de la cara (z
// hacia la cámara de frente). Promedio de las normales de los triángulos
// vecinos ponderado por área (el producto vectorial sin normalizar). Los
// triángulos están en sentido antihorario visto desde afuera.
inline void computeNormals(const float* positions, int vertexCount, const uint16_t* triangles, int triangleCount,
                           float* out) {
  for (int i = 0; i < vertexCount * kNormalComponents; ++i) out[i] = 0.0f;
  for (int t = 0; t < triangleCount; ++t) {
    const int ia = triangles[t * 3] * 3;
    const int ib = triangles[t * 3 + 1] * 3;
    const int ic = triangles[t * 3 + 2] * 3;
    const float e1[3] = {positions[ib] - positions[ia], positions[ib + 1] - positions[ia + 1],
                         positions[ib + 2] - positions[ia + 2]};
    const float e2[3] = {positions[ic] - positions[ia], positions[ic + 1] - positions[ia + 1],
                         positions[ic + 2] - positions[ia + 2]};
    const float n[3] = {e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2],
                        e1[0] * e2[1] - e1[1] * e2[0]};
    for (const int vertex : {ia, ib, ic}) {
      out[vertex] += n[0];
      out[vertex + 1] += n[1];
      out[vertex + 2] += n[2];
    }
  }
  for (int v = 0; v < vertexCount; ++v) {
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

// Normales de la malla canónica: kVertexCount × (x, y, z).
inline void computeVertexNormals(float* out) {
  computeNormals(kPositions, kVertexCount, kTriangles, kTriangleCount, out);
}

}  // namespace makeup::mesh
