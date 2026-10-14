// Rectificación a UV y medidas del look (F4) sobre la cara sintética de
// studio_synthetic.h: se recupera lo que se pintó.
#include <cmath>
#include <vector>

#include "color_math.h"
#include "face_style.h"
#include "mesh/canonical_mesh.h"
#include "mesh/lips_maps.h"
#include "studio/look_analysis.h"
#include "studio/region_sampling.h"
#include "studio/uv_rectify.h"
#include "studio_synthetic.h"
#include "test_harness.h"

using makeup::Vec3;

namespace {

Vec3 labOf(const float rgb[3]) { return makeup::srgbToOklab(rgb[0], rgb[1], rgb[2]); }

Vec3 regionLab(const std::vector<float>& values, int offset) {
  return Vec3{values[offset + makeup::kRegionL], values[offset + makeup::kRegionA], values[offset + makeup::kRegionB]};
}

int eyeRegion(makeup::EyeRegion region) {
  return makeup::kLookEyeRegions + static_cast<int>(region) * makeup::kRegionFloats;
}

std::vector<float> analyze(const synthetic::Look& look, bool mirror = false) {
  const makeup::StillImage image = synthetic::photo(look, mirror);
  const std::vector<float> points = synthetic::landmarks(mirror);
  std::vector<float> values(makeup::kLookValueCount, -1.0f);
  CHECK(makeup::analyzeLook(image, points.data(), values.data()));
  return values;
}

}  // namespace

TEST(rectificar_labiosDeLaFoto) {
  synthetic::Look look;
  const makeup::StillImage image = synthetic::photo(look);
  const std::vector<float> points = synthetic::landmarks();
  makeup::UvGrid grid;
  const int filled = makeup::rectifyToUv(image, points.data(), makeup::mesh::kLipsRegionTriangles,
                                         makeup::mesh::kLipsRegionTriangleCount, makeup::mesh::kLipsMapWidth,
                                         makeup::mesh::kLipsMapHeight, makeup::mesh::kLipsMapUvRect, false, &grid);
  CHECK(filled > makeup::mesh::kLipsMapWidth * makeup::mesh::kLipsMapHeight / 4);
  // Un texel del centro del labio tiene el color del labio.
  int checked = 0;
  for (int row = 0; row < grid.height; ++row) {
    for (int col = 0; col < grid.width; ++col) {
      const uint8_t mask = makeup::mesh::kLipsMapRgba[(static_cast<size_t>(row) * grid.width + col) * 4];
      const size_t index = grid.index(0, col, row);
      if (mask < 250 || !grid.valid[index]) continue;
      CHECK(makeup::deltaE(grid.lab[index], labOf(look.lip)) < 0.02f);
      ++checked;
    }
  }
  CHECK(checked > 100);
}

TEST(rectificar_triangulosDeEspaldasNoCuentan) {
  synthetic::Look look;
  const makeup::StillImage image = synthetic::photo(look);
  std::vector<float> points = synthetic::landmarks();
  // Media cara (u > 0,5) aplastada sobre la línea media: de costado.
  for (int i = 0; i < makeup::mesh::kVertexCount; ++i) {
    if (makeup::mesh::kUvs[i * 2] > 0.5f) points[i * 3] = 0.5f * synthetic::kSize + 0.01f * (points[i * 3] - 0.5f * synthetic::kSize);
  }
  makeup::UvGrid grid;
  makeup::rectifyToUv(image, points.data(), makeup::mesh::kFaceRegionTriangles, makeup::mesh::kFaceRegionTriangleCount,
                      makeup::mesh::kFaceMapWidth, makeup::mesh::kFaceMapHeight, makeup::mesh::kFaceMapUvRect, true,
                      &grid);
  int side0 = 0;
  int side1 = 0;
  for (int row = 0; row < grid.height; ++row) {
    for (int col = 0; col < grid.width; ++col) {
      side0 += grid.valid[grid.index(0, col, row)];
      side1 += grid.valid[grid.index(1, col, row)];
    }
  }
  CHECK(side0 > 1000);
  CHECK(side1 == 0);
}

TEST(look_recuperaLoPintado) {
  synthetic::Look look;
  const std::vector<float> values = analyze(look);
  CHECK(values[makeup::kLookSkin + makeup::kRegionValid] == 1.0f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookSkin), labOf(look.skin)) < 0.01f);
  CHECK(values[makeup::kLookSkin + makeup::kRegionCoverage] > 0.95f);

  CHECK(values[makeup::kLookLips + makeup::kRegionValid] == 1.0f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookLips), labOf(look.lip)) < 0.03f);
  CHECK(values[makeup::kLookLips + makeup::kRegionGloss] < 0.1f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookLipInterior), labOf(look.lip)) < 0.01f);

  // Rubor: el placement pintado y más rojo que la piel.
  CHECK(values[makeup::kLookCheekPlacement] == static_cast<float>(look.placement));
  CHECK(values[makeup::kLookCheeks + makeup::kRegionA] > values[makeup::kLookSkin + makeup::kRegionA] + 0.02f);

  // Sombra del párpado.
  const int lid = eyeRegion(makeup::EyeRegion::kLid);
  CHECK(values[lid + makeup::kRegionValid] == 1.0f);
  CHECK(makeup::deltaE(regionLab(values, lid), labOf(look.shadowColor)) < 0.03f);

  // Delineado: grosor y wing pintados (franjas de 0,05 y 0,1).
  CHECK_NEAR(values[makeup::kLookLinerExtent], look.linerDistance, 0.051);
  CHECK_NEAR(values[makeup::kLookWingExtent], look.wing, 0.11);
  CHECK(values[makeup::kLookLiner + makeup::kRegionValid] == 1.0f);
  CHECK(values[makeup::kLookLiner + makeup::kRegionL] < 0.25f);
}

// Piel local (P10): junto al rubor y en la ojera da la piel pintada.
TEST(look_pielLocal) {
  synthetic::Look look;
  const std::vector<float> values = analyze(look);
  CHECK(values[makeup::kLookCheekSkin + makeup::kRegionValid] == 1.0f);
  CHECK(values[makeup::kLookEyeSkin + makeup::kRegionValid] == 1.0f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookCheekSkin), labOf(look.skin)) < 0.03f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookEyeSkin), labOf(look.skin)) < 0.01f);
}

TEST(look_sinMaquillajeNoInventa) {
  synthetic::Look look;
  look.blush = false;
  look.shadow = false;
  look.liner = false;
  const std::vector<float> values = analyze(look);
  CHECK(values[makeup::kLookLinerExtent] == 0.0f);
  CHECK(values[makeup::kLookWingExtent] == 0.0f);
  CHECK(values[makeup::kLookLiner + makeup::kRegionValid] == 0.0f);
  const int lid = eyeRegion(makeup::EyeRegion::kLid);
  CHECK(makeup::deltaE(regionLab(values, lid), labOf(look.skin)) < 0.01f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookCheeks), labOf(look.skin)) < 0.01f);
}

// Maquillaje en un solo lado (P8): sombra, rubor y delineado salen del lado
// maquillado, sin mezclarse con el natural.
TEST(look_unSoloLadoNoSeLava) {
  synthetic::Look look;
  look.oneSide = true;
  const std::vector<float> values = analyze(look);
  const int lid = eyeRegion(makeup::EyeRegion::kLid);
  CHECK(makeup::deltaE(regionLab(values, lid), labOf(look.shadowColor)) < 0.03f);
  CHECK(values[lid + makeup::kRegionCoverage] > 0.9f);
  CHECK_NEAR(values[makeup::kLookLinerExtent], look.linerDistance, 0.051);
  CHECK(values[makeup::kLookCheekPlacement] == static_cast<float>(look.placement));
  CHECK(values[makeup::kLookCheeks + makeup::kRegionA] > values[makeup::kLookSkin + makeup::kRegionA] + 0.02f);
}

// Foto de 3/4 (P8): con media cara de costado, la sombra sale del lado que se
// ve con su cobertura entera (antes la cobertura juntaba los dos lados y
// quedaba en ~0,5: la región se descartaba).
TEST(look_tresCuartosUsaElLadoVisible) {
  synthetic::Look look;
  const makeup::StillImage image = synthetic::photo(look);
  std::vector<float> points = synthetic::landmarks();
  for (int i = 0; i < makeup::mesh::kVertexCount; ++i) {
    if (makeup::mesh::kUvs[i * 2] > 0.5f) points[i * 3] = 0.5f * synthetic::kSize + 0.01f * (points[i * 3] - 0.5f * synthetic::kSize);
  }
  std::vector<float> values(makeup::kLookValueCount, 0.0f);
  CHECK(makeup::analyzeLook(image, points.data(), values.data()));
  const int lid = eyeRegion(makeup::EyeRegion::kLid);
  CHECK(values[lid + makeup::kRegionCoverage] > 0.9f);
  CHECK(makeup::deltaE(regionLab(values, lid), labOf(look.shadowColor)) < 0.03f);
  CHECK((static_cast<int>(values[makeup::kLookSideMask]) & 2) == 0);  // párpado del lado 0
}

// Labio bicolor (P8): se queda con el color más maquillado, no con la mezcla.
TEST(look_labioBicolorEligeUnColor) {
  synthetic::Look look;
  look.bicolor = true;
  const std::vector<float> values = analyze(look);
  CHECK(values[makeup::kLookLipsSplit] == 1.0f);
  CHECK(makeup::deltaE(regionLab(values, makeup::kLookLips), labOf(look.lip)) < 0.03f);
  // Un solo color: no separa.
  synthetic::Look plain;
  CHECK(analyze(plain)[makeup::kLookLipsSplit] == 0.0f);
}

// Ahumado sin delineado (P9): el degradé oscuro pegado a las pestañas no se
// lee como un delineado grueso, y la V externa ahumada no da wing. Con un
// delineado negro real encima, sí.
TEST(look_ahumadoNoEsDelineado) {
  synthetic::Look look;
  look.liner = false;
  look.smoky = true;
  const std::vector<float> values = analyze(look);
  CHECK(values[makeup::kLookLinerExtent] <= 0.15f);
  CHECK(values[makeup::kLookWingExtent] == 0.0f);
  const int lid = eyeRegion(makeup::EyeRegion::kLid);
  const int outerV = eyeRegion(makeup::EyeRegion::kOuterV);
  CHECK(values[outerV + makeup::kRegionValid] == 1.0f);
  CHECK(values[outerV + makeup::kRegionL] < values[lid + makeup::kRegionL]);

  look.liner = true;
  const std::vector<float> lined = analyze(look);
  CHECK_NEAR(lined[makeup::kLookLinerExtent], look.linerDistance, 0.051);
  CHECK(lined[makeup::kLookWingExtent] >= 0.4f);
}

TEST(look_fotoEspejadaDaLoMismo) {
  synthetic::Look look;
  look.placement = 0;
  const std::vector<float> straight = analyze(look);
  const std::vector<float> mirrored = analyze(look, true);
  CHECK(mirrored[makeup::kLookCheekPlacement] == 0.0f);
  CHECK(makeup::deltaE(regionLab(straight, makeup::kLookLips), regionLab(mirrored, makeup::kLookLips)) < 0.01f);
  CHECK_NEAR(mirrored[makeup::kLookLinerExtent], straight[makeup::kLookLinerExtent], 0.051);
}
