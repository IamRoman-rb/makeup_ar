#include <cmath>
#include <set>
#include <tuple>

#include "mesh/canonical_mesh.h"
#include "mesh/lips_maps.h"
#include "test_harness.h"

namespace mesh = makeup::mesh;

namespace {

// Texel (canal 0 = máscara, 1 = brillo) más cercano a una UV canónica.
int sampleMap(float u, float v, int channel) {
  const float* rect = mesh::kLipsMapUvRect;
  int x = static_cast<int>((u - rect[0]) / rect[2] * mesh::kLipsMapWidth);
  int y = static_cast<int>((v - rect[1]) / rect[3] * mesh::kLipsMapHeight);
  x = x < 0 ? 0 : (x >= mesh::kLipsMapWidth ? mesh::kLipsMapWidth - 1 : x);
  y = y < 0 ? 0 : (y >= mesh::kLipsMapHeight ? mesh::kLipsMapHeight - 1 : y);
  return mesh::kLipsMapRg[(y * mesh::kLipsMapWidth + x) * 2 + channel];
}

float vertexU(int vertex) { return mesh::kUvs[vertex * 2]; }
float vertexV(int vertex) { return mesh::kUvs[vertex * 2 + 1]; }

using Triangle = std::tuple<int, int, int>;

}  // namespace

TEST(labiosMapa_tamanos) {
  CHECK(sizeof(mesh::kLipsMapRg) == static_cast<size_t>(mesh::kLipsMapWidth) * mesh::kLipsMapHeight * 2);
  CHECK(sizeof(mesh::kLipsRegionTriangles) / sizeof(uint16_t) ==
        static_cast<size_t>(mesh::kLipsRegionTriangleCount) * 3);
  for (uint16_t index : mesh::kLipsRegionTriangles) CHECK(index < mesh::kVertexCount);
  CHECK(mesh::kLipsMapUvRect[2] > 0.0f && mesh::kLipsMapUvRect[3] > 0.0f);
}

// El rectángulo cubre todo el contorno externo de los labios.
TEST(labiosMapa_rectanguloCubreLosLabios) {
  const float* rect = mesh::kLipsMapUvRect;
  for (uint16_t vertex : mesh::kLipsOuter) {
    CHECK(vertexU(vertex) > rect[0] && vertexU(vertex) < rect[0] + rect[2]);
    CHECK(vertexV(vertex) > rect[1] && vertexV(vertex) < rect[1] + rect[3]);
  }
}

TEST(labiosMapa_mascaraDentroYFuera) {
  // Centro del labio inferior y superior: entre el contorno externo (17 / 0)
  // y el interno (14 / 13), sobre la línea media.
  const float lowerV = 0.5f * (vertexV(17) + vertexV(14));
  const float upperV = 0.5f * (vertexV(0) + vertexV(13));
  CHECK(sampleMap(0.5f, lowerV, 0) == 255);
  CHECK(sampleMap(0.5f, upperV, 0) == 255);
  // Boca (entre los dos contornos internos) y bordes del mapa: 0.
  CHECK(sampleMap(0.5f, 0.5f * (vertexV(14) + vertexV(13)), 0) == 0);
  const float* rect = mesh::kLipsMapUvRect;
  CHECK(sampleMap(rect[0], rect[1], 0) == 0);
  CHECK(sampleMap(rect[0] + rect[2], rect[1] + rect[3], 0) == 0);
  CHECK(sampleMap(0.5f, rect[1], 0) == 0);
  // Comisura: el labio llega hasta el landmark de la esquina externa.
  CHECK(sampleMap(vertexU(61) + 0.004f, vertexV(61), 0) > 128);
}

TEST(labiosMapa_brilloSobreElLabioInferior) {
  const float lowerV = 0.5f * (vertexV(17) + vertexV(14));
  CHECK(sampleMap(0.5f, lowerV, 1) > 200);
  // Sin brillo fuera de la máscara.
  for (int i = 0; i < mesh::kLipsMapWidth * mesh::kLipsMapHeight; ++i) {
    if (mesh::kLipsMapRg[i * 2] == 0) CHECK(mesh::kLipsMapRg[i * 2 + 1] == 0);
  }
}

// La zona dibujada contiene todos los triángulos de labio de la malla y
// ninguno que cruce la boca.
TEST(labiosMapa_triangulosDeZona) {
  std::set<Triangle> region;
  for (int t = 0; t < mesh::kLipsRegionTriangleCount; ++t) {
    region.emplace(mesh::kLipsRegionTriangles[t * 3], mesh::kLipsRegionTriangles[t * 3 + 1],
                   mesh::kLipsRegionTriangles[t * 3 + 2]);
  }
  for (int t = 0; t < mesh::kLipTriangleCount; ++t) {
    CHECK(region.count({mesh::kLipTriangles[t * 3], mesh::kLipTriangles[t * 3 + 1],
                        mesh::kLipTriangles[t * 3 + 2]}) == 1);
  }
  std::set<int> inner(std::begin(mesh::kLipsInner), std::end(mesh::kLipsInner));
  for (int t = 0; t < mesh::kLipsRegionTriangleCount; ++t) {
    size_t onInner = 0;
    for (int k = 0; k < 3; ++k) onInner += inner.count(mesh::kLipsRegionTriangles[t * 3 + k]);
    // Un triángulo con los 3 vértices en el contorno interno cubre la boca.
    CHECK(onInner < 3);
  }
}
