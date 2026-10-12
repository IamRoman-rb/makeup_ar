#include <cmath>
#include <set>
#include <tuple>

#include "mesh/canonical_mesh.h"
#include "mesh/eye_maps.h"
#include "mesh/face_maps.h"
#include "test_harness.h"

namespace mesh = makeup::mesh;

namespace {

float vertexU(int vertex) { return mesh::kUvs[vertex * 2]; }
float vertexV(int vertex) { return mesh::kUvs[vertex * 2 + 1]; }

// Texel más cercano (valor [0,1]) de un mapa de media cara: espeja u como el
// vertex shader (u' = min(u, 1 - u)).
float sampleMirrored(const uint8_t* map, int width, int height, int channels, const float* rect, float u,
                     float v, int channel) {
  const float mirrored = u < 1.0f - u ? u : 1.0f - u;
  int x = static_cast<int>((mirrored - rect[0]) / rect[2] * width);
  int y = static_cast<int>((v - rect[1]) / rect[3] * height);
  x = x < 0 ? 0 : (x >= width ? width - 1 : x);
  y = y < 0 ? 0 : (y >= height ? height - 1 : y);
  return map[(y * width + x) * channels + channel] / 255.0f;
}

float face(float u, float v, int channel) {
  return sampleMirrored(mesh::kFaceMapRgb, mesh::kFaceMapWidth, mesh::kFaceMapHeight, 3, mesh::kFaceMapUvRect, u,
                        v, channel);
}

float eyeA(float u, float v, int channel) {
  return sampleMirrored(mesh::kEyeMapA, mesh::kEyeMapWidth, mesh::kEyeMapHeight, 4, mesh::kEyeMapUvRect, u, v,
                        channel);
}

float eyeB(float u, float v, int channel) {
  return sampleMirrored(mesh::kEyeMapB, mesh::kEyeMapWidth, mesh::kEyeMapHeight, 4, mesh::kEyeMapUvRect, u, v,
                        channel);
}

// Punto medio UV entre dos vértices.
float midU(int a, int b) { return 0.5f * (vertexU(a) + vertexU(b)); }
float midV(int a, int b) { return 0.5f * (vertexV(a) + vertexV(b)); }

using Triangle = std::tuple<int, int, int>;

Triangle sorted(int a, int b, int c) {
  if (a > b) std::swap(a, b);
  if (b > c) std::swap(b, c);
  if (a > b) std::swap(a, b);
  return {a, b, c};
}

}  // namespace

TEST(caraMapas_tamanos) {
  CHECK(sizeof(mesh::kFaceMapRgb) == static_cast<size_t>(mesh::kFaceMapWidth) * mesh::kFaceMapHeight * 3);
  CHECK(sizeof(mesh::kEyeMapA) == static_cast<size_t>(mesh::kEyeMapWidth) * mesh::kEyeMapHeight * 4);
  CHECK(sizeof(mesh::kEyeMapB) == sizeof(mesh::kEyeMapA));
  CHECK(sizeof(mesh::kFaceRegionTriangles) / sizeof(uint16_t) ==
        static_cast<size_t>(mesh::kFaceRegionTriangleCount) * 3);
  CHECK(sizeof(mesh::kEyeRegionTriangles) / sizeof(uint16_t) ==
        static_cast<size_t>(mesh::kEyeRegionTriangleCount) * 3);
  // Media cara: el mapa termina en la línea media.
  CHECK_NEAR(mesh::kFaceMapUvRect[0] + mesh::kFaceMapUvRect[2], 0.5, 1e-6);
  CHECK(mesh::kEyeMapUvRect[0] + mesh::kEyeMapUvRect[2] <= 0.5f);
}

// El espejo por vértice es válido: cada vértice tiene su simétrico en UV.
TEST(caraMapas_uvSimetricas) {
  for (int i = 0; i < mesh::kVertexCount; ++i) {
    float best = 1.0f;
    for (int j = 0; j < mesh::kVertexCount; ++j) {
      const float du = vertexU(i) - (1.0f - vertexU(j));
      const float dv = vertexV(i) - vertexV(j);
      best = std::fmin(best, std::sqrt(du * du + dv * dv));
    }
    CHECK(best < 0.0016f);
  }
}

TEST(caraMapas_pielDentroYFuera) {
  CHECK(face(vertexU(50), vertexV(50), 0) > 0.95f);    // mejilla derecha
  CHECK(face(vertexU(280), vertexV(280), 0) > 0.95f);  // mejilla izquierda (espejo)
  CHECK(face(0.5f, vertexV(4), 0) > 0.9f);              // punta de la nariz
  CHECK(face(midU(159, 145), midV(159, 145), 0) < 0.05f);  // dentro del ojo
  CHECK(face(midU(386, 374), midV(386, 374), 0) < 0.05f);  // ojo izquierdo
  CHECK(face(midU(52, 105), midV(52, 105), 0) < 0.05f);    // ceja
  CHECK(face(0.5f, midV(0, 13), 0) < 0.05f);               // labio superior
  CHECK(face(0.5f, midV(17, 14), 0) < 0.05f);              // labio inferior
  CHECK(face(0.05f, 0.95f, 0) < 0.05f);                    // fuera del óvalo
}

TEST(caraMapas_contornoEIluminador) {
  // Bajo el pómulo hay contorno y no iluminador; en el puente de la nariz, al revés.
  CHECK(face(0.15f, 0.415f, 1) > 0.6f);
  CHECK(face(0.15f, 0.415f, 2) < 0.2f);
  CHECK(face(0.5f, 0.56f, 2) > 0.6f);
  CHECK(face(0.5f, 0.56f, 1) < 0.2f);
  // Sin piel no hay contorno ni iluminador.
  CHECK(face(midU(159, 145), midV(159, 145), 1) < 0.05f);
  CHECK(face(midU(159, 145), midV(159, 145), 2) < 0.05f);
}

TEST(caraMapas_ruborSobrePiel) {
  for (int p = 0; p < mesh::kCheekPlacementCount; ++p) {
    const float* c = mesh::kCheekPlacements[p];
    CHECK(c[0] < 0.5f);
    CHECK(c[2] > 0.0f && c[3] > 0.0f);
    CHECK(face(c[0], c[1], 0) > 0.9f);
  }
}

TEST(ojosMapas_regiones) {
  const float u = vertexU(159);
  const float lashV = vertexV(159);
  CHECK(eyeA(u, lashV + 0.01f, 0) > 0.7f);                 // párpado sobre la línea de pestañas
  CHECK(eyeA(midU(159, 145), midV(159, 145), 0) < 0.05f);  // nada dentro del ojo
  CHECK(eyeA(midU(159, 145), midV(159, 145), 1) < 0.05f);
  CHECK(eyeA(vertexU(133) + 0.006f, vertexV(133), 3) > 0.6f);  // lagrimal
  CHECK(eyeB(vertexU(52), vertexV(52) - 0.012f, 0) > 0.5f);    // hueso de la ceja, bajo la ceja
  // Ojo izquierdo por espejo: el mismo párpado.
  CHECK(eyeA(vertexU(386), vertexV(386) + 0.01f, 0) > 0.7f);
}

TEST(ojosMapas_delineadoYWing) {
  // Distancia ~0 sobre la línea de pestañas superior y máxima lejos de ella.
  CHECK(eyeB(vertexU(159), vertexV(159) + 0.001f, 1) < 0.15f);
  CHECK(eyeB(vertexU(52), vertexV(52), 1) > 0.95f);
  // Más fino hacia el lagrimal: a la misma distancia, valor normalizado mayor.
  const float d = 0.003f;
  CHECK(eyeB(vertexU(158), vertexV(158) + d, 1) > eyeB(vertexU(160), vertexV(160) + d, 1));
  // El wing arranca en el ángulo externo y sale hacia afuera y arriba.
  const float cu = vertexU(33);
  const float cv = vertexV(33);
  CHECK(eyeB(cu - 0.003f, cv + 0.001f, 3) < 0.2f);
  CHECK(eyeB(cu - 0.025f, cv + 0.01f, 3) > 0.6f);
  CHECK(eyeB(cu - 0.025f, cv + 0.01f, 2) < 0.6f);
  CHECK(eyeB(cu + 0.02f, cv, 2) > 0.95f);  // hacia adentro del ojo no hay wing
}

TEST(caraMapas_triangulosDeZona) {
  for (uint16_t index : mesh::kFaceRegionTriangles) CHECK(index < mesh::kVertexCount);
  for (uint16_t index : mesh::kEyeRegionTriangles) CHECK(index < mesh::kVertexCount);
  // Sin los 18 de la boca ni los 14 de cada ojo.
  CHECK(mesh::kFaceRegionTriangleCount == mesh::kTriangleCount - 46);

  std::set<Triangle> faceSet;
  for (int t = 0; t < mesh::kFaceRegionTriangleCount; ++t) {
    const uint16_t* tri = mesh::kFaceRegionTriangles + t * 3;
    faceSet.insert(sorted(tri[0], tri[1], tri[2]));
  }
  // La zona de ojos es un subconjunto de la cara y llega a los dos ojos.
  bool right = false;
  bool left = false;
  for (int t = 0; t < mesh::kEyeRegionTriangleCount; ++t) {
    const uint16_t* tri = mesh::kEyeRegionTriangles + t * 3;
    CHECK(faceSet.count(sorted(tri[0], tri[1], tri[2])) == 1);
    right = right || vertexU(tri[0]) < 0.5f;
    left = left || vertexU(tri[0]) > 0.5f;
  }
  CHECK(right && left);
  // Ningún triángulo de la cara une el párpado superior con el inferior.
  const std::set<int> upper = {246, 161, 160, 159, 158, 157, 173};
  const std::set<int> lower = {7, 163, 144, 145, 153, 154, 155};
  for (int t = 0; t < mesh::kFaceRegionTriangleCount; ++t) {
    const uint16_t* tri = mesh::kFaceRegionTriangles + t * 3;
    int up = 0;
    int down = 0;
    for (int k = 0; k < 3; ++k) {
      up += upper.count(tri[k]) ? 1 : 0;
      down += lower.count(tri[k]) ? 1 : 0;
    }
    CHECK(!(up > 0 && down > 0));
  }
}
