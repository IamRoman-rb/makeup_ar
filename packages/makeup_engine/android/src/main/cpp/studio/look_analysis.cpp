#include "studio/look_analysis.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

#include "engine_config.h"
#include "face_style.h"
#include "mesh/canonical_mesh.h"
#include "mesh/eye_maps.h"
#include "mesh/face_maps.h"
#include "mesh/lips_maps.h"
#include "studio/uv_rectify.h"

namespace makeup {

namespace {

// Piel base (§10.5 paso 3): frente, entrecejo, puente de la nariz y mentón,
// zonas que casi nunca llevan color (la base no cuenta: tiñe todo parejo).
constexpr int kSkinLandmarks[] = {151, 108, 9, 168, 6, 175, 199};

constexpr float kByteToUnit = 1.0f / 255.0f;
const float kMaskThreshold = EngineConfig::kRegionMaskThreshold;

// Región en construcción: muestras y conteo de texels de la máscara.
struct Accumulator {
  std::vector<Vec3> samples;
  int maskTexels = 0;

  void add(const UvGrid& grid, size_t index) {
    ++maskTexels;
    if (grid.valid[index]) samples.push_back(grid.lab[index]);
  }
  float coverage() const {
    return maskTexels > 0 ? static_cast<float>(samples.size()) / static_cast<float>(maskTexels) : 0.0f;
  }
  void write(float* out, int offset) const { writeRegion(robustRegionColor(samples), coverage(), out, offset); }
};

float unitByte(uint8_t value) { return static_cast<float>(value) * kByteToUnit; }

RegionColor measureSkin(const UvGrid& face, Accumulator* skin) {
  for (int side = 0; side < face.sides; ++side) {
    for (int row = 0; row < face.height; ++row) {
      const float v = face.texelV(row);
      for (int col = 0; col < face.width; ++col) {
        const float u = face.texelU(col);
        bool near = false;
        for (int landmark : kSkinLandmarks) {
          const float lu = mesh::kUvs[landmark * 2];
          const float lv = mesh::kUvs[landmark * 2 + 1];
          const float du = u - std::min(lu, 1.0f - lu);
          const float dv = v - lv;
          if (du * du + dv * dv <= EngineConfig::kSkinPatchRadiusUv * EngineConfig::kSkinPatchRadiusUv) {
            near = true;
            break;
          }
        }
        if (!near) continue;
        const uint8_t* map = &mesh::kFaceMapRgba[(static_cast<size_t>(row) * face.width + col) * 4];
        // Piel (R) sin contorno (G) ni iluminador (B).
        if (unitByte(map[0]) < kMaskThreshold || unitByte(map[1]) > 0.25f || unitByte(map[2]) > 0.25f) continue;
        skin->add(face, face.index(side, col, row));
      }
    }
  }
  return robustRegionColor(skin->samples);
}

void measureLips(const UvGrid& lips, float* out) {
  Accumulator all;
  Accumulator ring;
  Accumulator interior;
  for (int row = 0; row < lips.height; ++row) {
    for (int col = 0; col < lips.width; ++col) {
      const uint8_t* map = &mesh::kLipsMapRgba[(static_cast<size_t>(row) * lips.width + col) * 4];
      const float mask = unitByte(map[0]);
      if (mask < kMaskThreshold) continue;
      const float distance = unitByte(map[2]);
      const size_t index = lips.index(0, col, row);
      all.add(lips, index);
      if (distance < EngineConfig::kLipLinerEdge) ring.add(lips, index);
      if (mask >= 0.9f && distance > 0.5f) interior.add(lips, index);
    }
  }
  all.write(out, kLookLips);
  ring.write(out, kLookLipLiner);
  interior.write(out, kLookLipInterior);
}

// Rubor: la gaussiana de cada placement con spread 0,5 (face_style.cpp).
void measureCheeks(const UvGrid& face, const RegionColor& skin, float* out) {
  const float scale = 0.5f * (EngineConfig::kCheekSpreadScaleMin + EngineConfig::kCheekSpreadScaleMax);
  int best = -1;
  float bestDistance = -1.0f;
  for (int p = 0; p < mesh::kCheekPlacementCount; ++p) {
    const float* placement = mesh::kCheekPlacements[p];
    const float su = placement[2] * scale;
    const float sv = placement[3] * scale;
    const float c = std::cos(placement[4]);
    const float s = std::sin(placement[4]);
    Accumulator cheek;
    for (int side = 0; side < face.sides; ++side) {
      for (int row = 0; row < face.height; ++row) {
        const float dv = face.texelV(row) - placement[1];
        for (int col = 0; col < face.width; ++col) {
          const float du = face.texelU(col) - placement[0];
          const float gu = (c * du + s * dv) / su;
          const float gv = (-s * du + c * dv) / sv;
          const uint8_t* map = &mesh::kFaceMapRgba[(static_cast<size_t>(row) * face.width + col) * 4];
          const float weight = std::exp(-0.5f * (gu * gu + gv * gv)) * unitByte(map[0]);
          if (weight < kMaskThreshold) continue;
          cheek.add(face, face.index(side, col, row));
        }
      }
    }
    const RegionColor color = robustRegionColor(cheek.samples);
    if (!color.valid) continue;
    // Más se aparta de la piel en croma, más rubor hay ahí.
    const float distance = std::hypot(color.lab.y - skin.lab.y, color.lab.z - skin.lab.z);
    if (distance > bestDistance) {
      bestDistance = distance;
      best = p;
      writeRegion(color, cheek.coverage(), out, kLookCheeks);
    }
  }
  out[kLookCheekPlacement] = static_cast<float>(std::max(best, 0));
}

// Sombras por región y delineado (grosor y wing) sobre el mapa de ojos.
void measureEyes(const UvGrid& eyes, const RegionColor& skin, float* out) {
  std::array<Accumulator, kLookEyeRegionCount> regions;
  for (int side = 0; side < eyes.sides; ++side) {
    for (int row = 0; row < eyes.height; ++row) {
      for (int col = 0; col < eyes.width; ++col) {
        const size_t texel = (static_cast<size_t>(row) * eyes.width + col) * 4;
        const uint8_t* mapA = &mesh::kEyeMapA[texel];
        const uint8_t* mapB = &mesh::kEyeMapB[texel];
        if (unitByte(mapB[1]) < EngineConfig::kShadowMinLinerDistance) continue;
        const size_t index = eyes.index(side, col, row);
        // Mapa A: párpado, pliegue, V externa, lagrimal; B.r: hueso de la ceja.
        for (int region = 0; region < 4; ++region) {
          if (unitByte(mapA[region]) >= kMaskThreshold) regions[region].add(eyes, index);
        }
        if (unitByte(mapB[0]) >= kMaskThreshold) regions[static_cast<int>(EyeRegion::kBrowBone)].add(eyes, index);
      }
    }
  }
  RegionColor lid;
  for (int region = 0; region < kLookEyeRegionCount; ++region) {
    const RegionColor color = robustRegionColor(regions[region].samples);
    if (region == static_cast<int>(EyeRegion::kLid)) lid = color;
    writeRegion(color, regions[region].coverage(), out, kLookEyeRegions + region * kRegionFloats);
  }

  // Delineado: franjas de distancia a la línea de pestañas; una franja es de
  // delineado si la mayoría de sus texels es más oscura que la piel y el
  // párpado. El grosor es la última franja contigua desde la línea.
  const float reference = lid.valid ? std::min(skin.lab.x, lid.lab.x) : skin.lab.x;
  const float darkBelow = reference - EngineConfig::kLinerDarkDelta;
  std::array<int, EngineConfig::kLinerBands> lineTotal{};
  std::array<int, EngineConfig::kLinerBands> lineDark{};
  for (int side = 0; side < eyes.sides; ++side) {
    for (int row = 0; row < eyes.height; ++row) {
      for (int col = 0; col < eyes.width; ++col) {
        const size_t index = eyes.index(side, col, row);
        if (!eyes.valid[index]) continue;
        const float distance = unitByte(mesh::kEyeMapB[(static_cast<size_t>(row) * eyes.width + col) * 4 + 1]);
        if (distance >= 1.0f) continue;
        const int band = std::min(static_cast<int>(distance * EngineConfig::kLinerBands), EngineConfig::kLinerBands - 1);
        ++lineTotal[band];
        if (eyes.lab[index].x < darkBelow) ++lineDark[band];
      }
    }
  }
  int lineBands = 0;
  while (lineBands < EngineConfig::kLinerBands && lineTotal[lineBands] > 0 &&
         static_cast<float>(lineDark[lineBands]) >= EngineConfig::kLinerDarkFraction * lineTotal[lineBands]) {
    ++lineBands;
  }
  const float extent = static_cast<float>(lineBands) / EngineConfig::kLinerBands;
  out[kLookLinerExtent] = extent;

  // Wing: avance a lo largo del wing (B.a) en franjas, cerca de su eje (B.b).
  const float wingDistance = std::max(extent, EngineConfig::kWingMinDistance);
  std::array<int, EngineConfig::kWingBands> wingTotal{};
  std::array<int, EngineConfig::kWingBands> wingDark{};
  Accumulator liner;
  for (int side = 0; side < eyes.sides; ++side) {
    for (int row = 0; row < eyes.height; ++row) {
      for (int col = 0; col < eyes.width; ++col) {
        const size_t texel = (static_cast<size_t>(row) * eyes.width + col) * 4;
        const float lineD = unitByte(mesh::kEyeMapB[texel + 1]);
        const float wingD = unitByte(mesh::kEyeMapB[texel + 2]);
        const float progress = unitByte(mesh::kEyeMapB[texel + 3]);
        const size_t index = eyes.index(side, col, row);
        const bool dark = eyes.valid[index] && eyes.lab[index].x < darkBelow;
        const bool inLine = lineD < extent;
        if (lineBands > 0 && inLine && dark) liner.samples.push_back(eyes.lab[index]);
        if (progress <= 0.0f || wingD >= wingDistance || !eyes.valid[index]) continue;
        const int band = std::min(static_cast<int>(progress * EngineConfig::kWingBands), EngineConfig::kWingBands - 1);
        ++wingTotal[band];
        if (dark) {
          ++wingDark[band];
          if (lineBands > 0 && !inLine) liner.samples.push_back(eyes.lab[index]);
        }
      }
    }
  }
  int wingBands = 0;
  while (wingBands < EngineConfig::kWingBands && wingTotal[wingBands] > 0 &&
         static_cast<float>(wingDark[wingBands]) >= EngineConfig::kLinerDarkFraction * wingTotal[wingBands]) {
    ++wingBands;
  }
  out[kLookWingExtent] = lineBands > 0 ? static_cast<float>(wingBands) / EngineConfig::kWingBands : 0.0f;
  liner.maskTexels = static_cast<int>(liner.samples.size());
  liner.write(out, kLookLiner);
}

}  // namespace

void writeRegion(const RegionColor& color, float coverage, float* out, int offset) {
  out[offset + kRegionValid] = color.valid ? 1.0f : 0.0f;
  out[offset + kRegionL] = color.lab.x;
  out[offset + kRegionA] = color.lab.y;
  out[offset + kRegionB] = color.lab.z;
  out[offset + kRegionGloss] = color.gloss;
  out[offset + kRegionSamples] = static_cast<float>(color.count);
  out[offset + kRegionCoverage] = coverage;
}

bool analyzeLook(const StillImage& image, const float* landmarks, float* out) {
  for (int i = kLookSkin; i < kLookValueCount; ++i) out[i] = 0.0f;

  UvGrid face;
  rectifyToUv(image, landmarks, mesh::kFaceRegionTriangles, mesh::kFaceRegionTriangleCount, mesh::kFaceMapWidth,
              mesh::kFaceMapHeight, mesh::kFaceMapUvRect, true, &face);
  Accumulator skinSamples;
  const RegionColor skin = measureSkin(face, &skinSamples);
  writeRegion(skin, skinSamples.coverage(), out, kLookSkin);
  if (!skin.valid) return false;

  UvGrid lips;
  rectifyToUv(image, landmarks, mesh::kLipsRegionTriangles, mesh::kLipsRegionTriangleCount, mesh::kLipsMapWidth,
              mesh::kLipsMapHeight, mesh::kLipsMapUvRect, false, &lips);
  measureLips(lips, out);
  measureCheeks(face, skin, out);

  UvGrid eyes;
  rectifyToUv(image, landmarks, mesh::kEyeRegionTriangles, mesh::kEyeRegionTriangleCount, mesh::kEyeMapWidth,
              mesh::kEyeMapHeight, mesh::kEyeMapUvRect, true, &eyes);
  measureEyes(eyes, skin, out);
  return true;
}

}  // namespace makeup
