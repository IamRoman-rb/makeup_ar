#include <set>
#include <tuple>

#include "mesh/canonical_mesh.h"
#include "test_harness.h"
#include "tracking/umeyama.h"

namespace mesh = makeup::mesh;

TEST(malla_tamanosEIndicesValidos) {
  CHECK(sizeof(mesh::kPositions) / sizeof(float) == mesh::kVertexCount * 3);
  CHECK(sizeof(mesh::kUvs) / sizeof(float) == mesh::kVertexCount * 2);
  CHECK(sizeof(mesh::kTriangles) / sizeof(uint16_t) == mesh::kTriangleCount * 3);
  CHECK(sizeof(mesh::kLipTriangles) / sizeof(uint16_t) == mesh::kLipTriangleCount * 3);
  for (uint16_t index : mesh::kTriangles) CHECK(index < mesh::kVertexCount);
  for (float uv : mesh::kUvs) CHECK(uv >= 0.0f && uv <= 1.0f);
  for (int index : mesh::kProcrustesIndices) CHECK(index >= 0 && index < mesh::kVertexCount);
}

TEST(malla_labiosSonSubconjuntoDeLaMalla) {
  std::set<std::tuple<int, int, int>> all;
  for (int t = 0; t < mesh::kTriangleCount; ++t) {
    all.emplace(mesh::kTriangles[t * 3], mesh::kTriangles[t * 3 + 1], mesh::kTriangles[t * 3 + 2]);
  }
  CHECK(mesh::kLipTriangleCount > 50);
  for (int t = 0; t < mesh::kLipTriangleCount; ++t) {
    CHECK(all.count({mesh::kLipTriangles[t * 3], mesh::kLipTriangles[t * 3 + 1],
                     mesh::kLipTriangles[t * 3 + 2]}) == 1);
  }
  // Comisuras y centro de los labios en los contornos.
  CHECK(mesh::kLipsOuter[0] == 61);
  CHECK(mesh::kLipsInner[0] == 78);
}

// Orientación de la malla: ojo 33 a la izquierda de la imagen, frente arriba,
// nariz hacia la cámara.
TEST(malla_orientacion) {
  const float* p = mesh::kPositions;
  CHECK(p[mesh::kEyeLeftInImage * 3] < 0.0f);
  CHECK(p[mesh::kEyeRightInImage * 3] > 0.0f);
  CHECK(p[10 * 3 + 1] > p[152 * 3 + 1]);  // frente (10) arriba del mentón (152)
  CHECK(p[1 * 3 + 2] > p[234 * 3 + 2]);   // punta de nariz (1) más cerca que la mejilla (234)
}

// La base de Procrustes, con sus pesos, recupera una pose conocida de la malla.
TEST(malla_procrustesRecuperaPose) {
  for (float w : mesh::kProcrustesWeights) CHECK(w > 0.0f);  // MediaPipe no los normaliza (suman ~1,06)

  const float c = 0.9553365f;  // cos(0.3)
  const float s = 0.2955202f;  // sin(0.3): yaw de 0,3 rad
  float moved[mesh::kVertexCount * 3];
  for (int i = 0; i < mesh::kVertexCount; ++i) {
    const float x = mesh::kPositions[i * 3];
    const float y = mesh::kPositions[i * 3 + 1];
    const float z = mesh::kPositions[i * 3 + 2];
    moved[i * 3] = 20.0f * (c * x + s * z) + 300.0f;
    moved[i * 3 + 1] = 20.0f * y - 100.0f;
    moved[i * 3 + 2] = 20.0f * (-s * x + c * z);
  }
  makeup::SimilarityTransform pose{};
  CHECK(makeup::solveSimilarity(mesh::kPositions, moved, mesh::kProcrustesIndices,
                                mesh::kProcrustesWeights, mesh::kProcrustesCount, &pose));
  CHECK_NEAR(pose.scale, 20.0, 1e-3);
  CHECK_NEAR(makeup::eulerFromRotation(pose.rotation).yaw, 0.3, 1e-4);
  CHECK_NEAR(pose.translation[0], 300.0, 1e-2);
}
