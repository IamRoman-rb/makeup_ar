#include "mesh/subdivision.h"

#include <cmath>
#include <cstddef>

namespace makeup::mesh {

namespace {

static_assert(sizeof(kSubEdges) / sizeof(uint16_t) == kSubEdgeCount * 2, "aristas incompletas");
static_assert(sizeof(kSubEdgeUvs) / sizeof(float) == kSubEdgeCount * 2, "UV de aristas incompletas");
static_assert(sizeof(kSubStencilStart) / sizeof(uint16_t) == kSubEdgeCount + 1, "inicios de stencils");
static_assert(sizeof(kSubStencilIndex) / sizeof(uint16_t) == kSubStencilEntries, "índices de stencils");
static_assert(sizeof(kSubStencilWeight) / sizeof(float) == kSubStencilEntries, "pesos de stencils");
static_assert(kSubVertexCount <= 0xFFFF, "los índices son uint16_t");

// Recorta el corrimiento [d] (dim componentes) a maxOffset × el largo de la
// arista ([lengthSquared] = largo²). Sin raíces salvo al recortar (por frame:
// 1365 aristas).
template <int dim>
void clampOffset(float* d, float lengthSquared, float maxOffset) {
  float squared = 0.0f;
  for (int i = 0; i < dim; ++i) squared += d[i] * d[i];
  const float limitSquared = maxOffset * maxOffset * lengthSquared;
  if (squared <= limitSquared || squared <= 0.0f) return;
  const float scale = std::sqrt(limitSquared / squared);
  for (int i = 0; i < dim; ++i) d[i] *= scale;
}

}  // namespace

void subdividePoints(const float* points, bool smooth, float maxOffset, float* out) {
  for (int v = 0; v < kVertexCount; ++v) {
    out[v * 2] = points[v * 3];
    out[v * 2 + 1] = points[v * 3 + 1];
  }
  float* edgeOut = out + kVertexCount * 2;
  if (!smooth) {
    for (int e = 0; e < kSubEdgeCount; ++e) {
      const int a = kSubEdges[e * 2] * 3;
      const int b = kSubEdges[e * 2 + 1] * 3;
      edgeOut[e * 2] = 0.5f * (points[a] + points[b]);
      edgeOut[e * 2 + 1] = 0.5f * (points[a + 1] + points[b + 1]);
    }
    return;
  }
  for (int e = 0; e < kSubEdgeCount; ++e) {
    float x = 0.0f;
    float y = 0.0f;
    for (int i = kSubStencilStart[e]; i < kSubStencilStart[e + 1]; ++i) {
      const int p = kSubStencilIndex[i] * 3;
      const float w = kSubStencilWeight[i];
      x += w * points[p];
      y += w * points[p + 1];
    }
    const int a = kSubEdges[e * 2] * 3;
    const int b = kSubEdges[e * 2 + 1] * 3;
    const float midX = 0.5f * (points[a] + points[b]);
    const float midY = 0.5f * (points[a + 1] + points[b + 1]);
    float d[2] = {x - midX, y - midY};
    const float ex = points[b] - points[a];
    const float ey = points[b + 1] - points[a + 1];
    clampOffset<2>(d, ex * ex + ey * ey, maxOffset);
    edgeOut[e * 2] = midX + d[0];
    edgeOut[e * 2 + 1] = midY + d[1];
  }
}

void subdividePositions(const float* positions, float maxOffset, float* out) {
  for (int i = 0; i < kVertexCount * 3; ++i) out[i] = positions[i];
  for (int e = 0; e < kSubEdgeCount; ++e) {
    float* p = out + (kVertexCount + e) * 3;
    p[0] = p[1] = p[2] = 0.0f;
    for (int i = kSubStencilStart[e]; i < kSubStencilStart[e + 1]; ++i) {
      const float* q = positions + kSubStencilIndex[i] * 3;
      const float w = kSubStencilWeight[i];
      p[0] += w * q[0];
      p[1] += w * q[1];
      p[2] += w * q[2];
    }
    const float* a = positions + kSubEdges[e * 2] * 3;
    const float* b = positions + kSubEdges[e * 2 + 1] * 3;
    float mid[3];
    float d[3];
    float squared = 0.0f;
    for (int c = 0; c < 3; ++c) {
      mid[c] = 0.5f * (a[c] + b[c]);
      d[c] = p[c] - mid[c];
      squared += (b[c] - a[c]) * (b[c] - a[c]);
    }
    clampOffset<3>(d, squared, maxOffset);
    for (int c = 0; c < 3; ++c) p[c] = mid[c] + d[c];
  }
}

void subdividedUvs(float* out) {
  for (int i = 0; i < kVertexCount * 2; ++i) out[i] = kUvs[i];
  for (int i = 0; i < kSubEdgeCount * 2; ++i) out[kVertexCount * 2 + i] = kSubEdgeUvs[i];
}

int subEdgeVertex(int a, int b) {
  if (a > b) {
    const int t = a;
    a = b;
    b = t;
  }
  int lo = 0;
  int hi = kSubEdgeCount - 1;
  while (lo <= hi) {
    const int mid = (lo + hi) / 2;
    const int ma = kSubEdges[mid * 2];
    const int mb = kSubEdges[mid * 2 + 1];
    if (ma == a && mb == b) return kVertexCount + mid;
    if (ma < a || (ma == a && mb < b)) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}

bool subdivideTriangles(const uint16_t* triangles, int count, uint16_t* out) {
  for (int t = 0; t < count; ++t) {
    const int a = triangles[t * 3];
    const int b = triangles[t * 3 + 1];
    const int c = triangles[t * 3 + 2];
    const int ab = subEdgeVertex(a, b);
    const int bc = subEdgeVertex(b, c);
    const int ca = subEdgeVertex(c, a);
    if (ab < 0 || bc < 0 || ca < 0) return false;
    const int children[12] = {a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca};
    for (int i = 0; i < 12; ++i) out[t * 12 + i] = static_cast<uint16_t>(children[i]);
  }
  return true;
}

}  // namespace makeup::mesh
