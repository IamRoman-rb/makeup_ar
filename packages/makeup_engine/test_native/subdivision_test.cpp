// Malla suave (mesh/subdivision.h): aristas, expansión de índices y puntos.
#include <cmath>
#include <set>
#include <utility>
#include <vector>

#include "engine_config.h"
#include "mesh/canonical_mesh.h"
#include "mesh/eye_maps.h"
#include "mesh/face_maps.h"
#include "mesh/lips_maps.h"
#include "mesh/mesh_normals.h"
#include "mesh/subdivision.h"
#include "test_harness.h"

namespace mesh = makeup::mesh;

namespace {

// Landmarks sintéticos: la malla canónica proyectada (x, y en px) con una
// escala y un corrimiento cualquiera.
std::vector<float> projectedLandmarks() {
  std::vector<float> points(static_cast<size_t>(mesh::kVertexCount) * 3);
  for (int v = 0; v < mesh::kVertexCount; ++v) {
    points[v * 3] = 360.0f + 40.0f * mesh::kPositions[v * 3];
    points[v * 3 + 1] = 640.0f - 40.0f * mesh::kPositions[v * 3 + 1];
    points[v * 3 + 2] = mesh::kPositions[v * 3 + 2];
  }
  return points;
}

bool near(float a, float b, float tolerance) { return std::fabs(a - b) <= tolerance; }

}  // namespace

TEST(subdivision_aristasOrdenadasYUnicas) {
  CHECK(mesh::kSubEdgeCount == 1365);
  for (int e = 0; e < mesh::kSubEdgeCount; ++e) {
    const int a = mesh::kSubEdges[e * 2];
    const int b = mesh::kSubEdges[e * 2 + 1];
    CHECK(a < b && b < mesh::kVertexCount);
    if (e > 0) {
      const int pa = mesh::kSubEdges[e * 2 - 2];
      const int pb = mesh::kSubEdges[e * 2 - 1];
      CHECK(pa < a || (pa == a && pb < b));
    }
    CHECK(mesh::subEdgeVertex(a, b) == mesh::kVertexCount + e);
    CHECK(mesh::subEdgeVertex(b, a) == mesh::kVertexCount + e);
  }
  CHECK(mesh::subEdgeVertex(0, 0) == -1);
}

TEST(subdivision_stencilsSumanUno) {
  for (int e = 0; e < mesh::kSubEdgeCount; ++e) {
    float sum = 0.0f;
    for (int i = mesh::kSubStencilStart[e]; i < mesh::kSubStencilStart[e + 1]; ++i) {
      CHECK(mesh::kSubStencilIndex[i] < mesh::kVertexCount);
      sum += mesh::kSubStencilWeight[i];
    }
    CHECK(near(sum, 1.0f, 1e-5f));
  }
}

TEST(subdivision_zonasSeExpandenA4Hijos) {
  struct Zone {
    const uint16_t* triangles;
    int count;
  };
  const Zone zones[] = {
      {mesh::kTriangles, mesh::kTriangleCount},
      {mesh::kLipsRegionTriangles, mesh::kLipsRegionTriangleCount},
      {mesh::kFaceRegionTriangles, mesh::kFaceRegionTriangleCount},
      {mesh::kEyeRegionTriangles, mesh::kEyeRegionTriangleCount},
      {mesh::kEyeOpeningTriangles, mesh::kEyeOpeningTriangleCount},
  };
  for (const Zone& zone : zones) {
    std::vector<uint16_t> out(static_cast<size_t>(zone.count) * 12);
    CHECK(mesh::subdivideTriangles(zone.triangles, zone.count, out.data()));
    for (uint16_t index : out) CHECK(index < mesh::kSubVertexCount);
    // Cada hijo esquina conserva su vértice original.
    for (int t = 0; t < zone.count; ++t) {
      CHECK(out[t * 12] == zone.triangles[t * 3]);
      CHECK(out[t * 12 + 4] == zone.triangles[t * 3 + 1]);
      CHECK(out[t * 12 + 8] == zone.triangles[t * 3 + 2]);
    }
  }
}

TEST(subdivision_sinSuavizarEsElPuntoMedio) {
  const std::vector<float> points = projectedLandmarks();
  std::vector<float> out(static_cast<size_t>(mesh::kSubVertexCount) * 2);
  mesh::subdividePoints(points.data(), false, makeup::EngineConfig::kSmoothMeshMaxOffset, out.data());
  for (int v = 0; v < mesh::kVertexCount; ++v) {
    CHECK(out[v * 2] == points[v * 3]);
    CHECK(out[v * 2 + 1] == points[v * 3 + 1]);
  }
  for (int e = 0; e < mesh::kSubEdgeCount; ++e) {
    const int a = mesh::kSubEdges[e * 2] * 3;
    const int b = mesh::kSubEdges[e * 2 + 1] * 3;
    const float* p = out.data() + (mesh::kVertexCount + e) * 2;
    CHECK(near(p[0], 0.5f * (points[a] + points[b]), 1e-4f));
    CHECK(near(p[1], 0.5f * (points[a + 1] + points[b + 1]), 1e-4f));
  }
}

TEST(subdivision_suavePasaPorLosLandmarksYQuedaCerca) {
  const std::vector<float> points = projectedLandmarks();
  std::vector<float> smooth(static_cast<size_t>(mesh::kSubVertexCount) * 2);
  std::vector<float> linear(smooth.size());
  const float maxOffset = makeup::EngineConfig::kSmoothMeshMaxOffset;
  mesh::subdividePoints(points.data(), true, maxOffset, smooth.data());
  mesh::subdividePoints(points.data(), false, maxOffset, linear.data());
  for (int v = 0; v < mesh::kVertexCount * 2; ++v) CHECK(smooth[v] == linear[v]);
  // El punto suave se aparta del medio de la arista a lo sumo el tope (no hay
  // picos) y en algún lado suaviza de verdad.
  float worst = 0.0f;
  int moved = 0;
  for (int e = 0; e < mesh::kSubEdgeCount; ++e) {
    const int a = mesh::kSubEdges[e * 2] * 3;
    const int b = mesh::kSubEdges[e * 2 + 1] * 3;
    const float length = std::hypot(points[b] - points[a], points[b + 1] - points[a + 1]);
    const int i = (mesh::kVertexCount + e) * 2;
    const float offset = std::hypot(smooth[i] - linear[i], smooth[i + 1] - linear[i + 1]);
    if (length > 0.0f) worst = std::fmax(worst, offset / length);
    if (offset > 0.01f) ++moved;
  }
  CHECK(worst <= maxOffset + 1e-4f);
  CHECK(moved > 100);
}

TEST(subdivision_uvsYNormales) {
  std::vector<float> uvs(static_cast<size_t>(mesh::kSubVertexCount) * 2);
  mesh::subdividedUvs(uvs.data());
  for (float uv : uvs) CHECK(uv >= 0.0f && uv <= 1.0f);
  std::vector<float> positions(static_cast<size_t>(mesh::kSubVertexCount) * 3);
  mesh::subdividePositions(mesh::kPositions, makeup::EngineConfig::kSmoothMeshMaxOffset, positions.data());
  std::vector<uint16_t> triangles(static_cast<size_t>(mesh::kTriangleCount) * 12);
  CHECK(mesh::subdivideTriangles(mesh::kTriangles, mesh::kTriangleCount, triangles.data()));
  std::vector<float> normals(static_cast<size_t>(mesh::kSubVertexCount) * 3);
  mesh::computeNormals(positions.data(), mesh::kSubVertexCount, triangles.data(), mesh::kTriangleCount * 4,
                       normals.data());
  // La punta de la nariz (landmark 4) mira a la cámara.
  CHECK(normals[4 * 3 + 2] > 0.9f);
  for (int v = 0; v < mesh::kSubVertexCount; ++v) {
    const float* n = normals.data() + v * 3;
    CHECK(near(std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]), 1.0f, 1e-4f));
  }
}
