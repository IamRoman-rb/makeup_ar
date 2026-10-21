// Malla suave (docs/ar_engine/TRACKER.md §9): la malla de 468 landmarks con
// un punto nuevo por arista (mesh/subdivided_mesh.h, generado por
// tools/mesh/gen_subdivided_mesh.py). Cada triángulo se dibuja como 4.
//
// Orden de los puntos: [0, kVertexCount) los landmarks de la malla y
// [kVertexCount, kSubVertexCount) los de las aristas (kVertexCount + e).
//
// subdividePoints corre por frame en el hilo de render: sin allocations
// (escribe en el buffer de quien llama). El resto corre una vez, al crear la
// geometría GL.
#pragma once

#include <cstdint>

#include "mesh/subdivided_mesh.h"

namespace makeup::mesh {

// [points]: landmarks (x, y, z por punto, px de imagen), al menos kVertexCount.
// [out]: kSubVertexCount × (x, y). [smooth]: stencils butterfly, con el
// corrimiento respecto del punto medio recortado a [maxOffset] × el largo de
// la arista; si no, punto medio lineal (misma imagen que la malla de 468).
void subdividePoints(const float* points, bool smooth, float maxOffset, float* out);

// Posiciones 3D (kVertexCount × 3) -> kSubVertexCount × 3 con los stencils
// suaves y el mismo tope (normales de la malla subdividida).
void subdividePositions(const float* positions, float maxOffset, float* out);

// UV de los kSubVertexCount puntos (kUvs + punto medio de cada arista).
void subdividedUvs(float* out);

// Punto nuevo de la arista (a, b) (en cualquier orden), o -1 si no es arista.
int subEdgeVertex(int a, int b);

// Cada triángulo (a, b, c) -> 4 en el mismo sentido: (a, ab, ca), (ab, b, bc),
// (ca, bc, c) y (ab, bc, ca). [out]: 12 · [count] índices. false si alguna
// arista no está en la malla.
bool subdivideTriangles(const uint16_t* triangles, int count, uint16_t* out);

}  // namespace makeup::mesh
