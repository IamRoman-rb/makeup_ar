#include "studio/look_analysis.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <utility>
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
constexpr int kSides = 2;

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

// Una región medida en cada lado de un mapa espejado.
using SidePair = std::array<Accumulator, kSides>;

float unitByte(uint8_t value) { return static_cast<float>(value) * kByteToUnit; }

// El lado con más maquillaje (mayor distancia a la piel) entre los que se ven
// lo suficiente (kSideMinCoverage de su máscara). Así una foto de 3/4 usa el
// lado visible y un look de un solo lado no se mezcla con el lado natural. Si
// ninguno llega, el de mayor cobertura. Escribe el bloque y devuelve el lado.
int writeBestSide(const SidePair& sides, const RegionColor& skin, float* out, int offset) {
  RegionColor colors[kSides];
  int best = -1;
  float bestDistance = -1.0f;
  for (int side = 0; side < kSides; ++side) {
    colors[side] = robustRegionColor(sides[side].samples);
    if (!colors[side].valid || sides[side].coverage() < EngineConfig::kSideMinCoverage) continue;
    const float distance = deltaE(colors[side].lab, skin.lab);
    if (distance > bestDistance) {
      bestDistance = distance;
      best = side;
    }
  }
  if (best < 0) best = sides[1].coverage() > sides[0].coverage() ? 1 : 0;
  writeRegion(colors[best], sides[best].coverage(), out, offset);
  return best;
}

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

// Labio de dos colores (degradé, mitad y mitad): 2-means en croma (a, b), que
// la luz casi no cambia. Si los grupos se separan y el chico no es un detalle,
// se queda con el que más se aparta de la piel (si tiene peso suficiente) o
// con el más grande: la mediana de los dos daba un color que no era ninguno.
// Devuelve true y deja en [samples] el grupo elegido si separó.
bool splitBicolor(std::vector<Vec3>* samples, const RegionColor& skin) {
  const size_t count = samples->size();
  if (count < static_cast<size_t>(2 * EngineConfig::kRegionMinSamples)) return false;
  auto chromaDistance2 = [](const Vec3& p, float a, float b) {
    const float da = p.y - a;
    const float db = p.z - b;
    return da * da + db * db;
  };
  // Semillas: la muestra más lejana a la media y la más lejana a esa.
  float meanA = 0.0f;
  float meanB = 0.0f;
  for (const Vec3& s : *samples) {
    meanA += s.y;
    meanB += s.z;
  }
  meanA /= static_cast<float>(count);
  meanB /= static_cast<float>(count);
  size_t first = 0;
  for (size_t i = 1; i < count; ++i) {
    if (chromaDistance2((*samples)[i], meanA, meanB) > chromaDistance2((*samples)[first], meanA, meanB)) first = i;
  }
  size_t second = 0;
  for (size_t i = 1; i < count; ++i) {
    const Vec3& f = (*samples)[first];
    if (chromaDistance2((*samples)[i], f.y, f.z) > chromaDistance2((*samples)[second], f.y, f.z)) second = i;
  }
  float centers[2][2] = {{(*samples)[first].y, (*samples)[first].z}, {(*samples)[second].y, (*samples)[second].z}};
  std::vector<uint8_t> group(count, 0);
  int sizes[2] = {0, 0};
  for (int iteration = 0; iteration < 8; ++iteration) {
    float sums[2][2] = {{0.0f, 0.0f}, {0.0f, 0.0f}};
    sizes[0] = sizes[1] = 0;
    for (size_t i = 0; i < count; ++i) {
      const Vec3& s = (*samples)[i];
      const int g = chromaDistance2(s, centers[1][0], centers[1][1]) < chromaDistance2(s, centers[0][0], centers[0][1]) ? 1 : 0;
      group[i] = static_cast<uint8_t>(g);
      sums[g][0] += s.y;
      sums[g][1] += s.z;
      ++sizes[g];
    }
    for (int g = 0; g < 2; ++g) {
      if (sizes[g] == 0) return false;
      centers[g][0] = sums[g][0] / static_cast<float>(sizes[g]);
      centers[g][1] = sums[g][1] / static_cast<float>(sizes[g]);
    }
  }
  const float separation = std::hypot(centers[0][0] - centers[1][0], centers[0][1] - centers[1][1]);
  const float minFraction = static_cast<float>(std::min(sizes[0], sizes[1])) / static_cast<float>(count);
  if (separation < EngineConfig::kLipSplitMinChroma || minFraction < EngineConfig::kLipSplitMinFraction) return false;
  const int larger = sizes[1] > sizes[0] ? 1 : 0;
  const int farther = std::hypot(centers[1][0] - skin.lab.y, centers[1][1] - skin.lab.z) >
                              std::hypot(centers[0][0] - skin.lab.y, centers[0][1] - skin.lab.z)
                          ? 1
                          : 0;
  const bool fartherHeavy =
      static_cast<float>(sizes[farther]) / static_cast<float>(count) >= EngineConfig::kLipSplitPreferFraction;
  const int chosen = fartherHeavy ? farther : larger;
  std::vector<Vec3> kept;
  kept.reserve(static_cast<size_t>(sizes[chosen]));
  for (size_t i = 0; i < count; ++i) {
    if (group[i] == chosen) kept.push_back((*samples)[i]);
  }
  samples->swap(kept);
  return true;
}

void measureLips(const UvGrid& lips, const RegionColor& skin, float* out) {
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
  // La cobertura es la del labio entero; el color, el del grupo elegido.
  const float coverage = all.coverage();
  std::vector<Vec3> chosen = all.samples;
  const bool split = splitBicolor(&chosen, skin);
  writeRegion(robustRegionColor(chosen), coverage, out, kLookLips);
  out[kLookLipsSplit] = split ? 1.0f : 0.0f;
  ring.write(out, kLookLipLiner);
  interior.write(out, kLookLipInterior);
}

// Rubor: la gaussiana de cada placement con spread 0,5 (face_style.cpp), por
// lado. Gana el par (placement, lado) que más se aparta de la piel en croma
// entre los que se ven lo suficiente. Devuelve el lado.
int measureCheeks(const UvGrid& face, const RegionColor& skin, float* out) {
  const float scale = 0.5f * (EngineConfig::kCheekSpreadScaleMin + EngineConfig::kCheekSpreadScaleMax);
  int bestPlacement = -1;
  int bestSide = 0;
  float bestDistance = -1.0f;
  int fallbackPlacement = 0;
  int fallbackSide = 0;
  float fallbackCoverage = -1.0f;
  RegionColor fallbackColor;
  for (int p = 0; p < mesh::kCheekPlacementCount; ++p) {
    const float* placement = mesh::kCheekPlacements[p];
    const float su = placement[2] * scale;
    const float sv = placement[3] * scale;
    const float c = std::cos(placement[4]);
    const float s = std::sin(placement[4]);
    SidePair cheek;
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
          cheek[side].add(face, face.index(side, col, row));
        }
      }
    }
    for (int side = 0; side < face.sides; ++side) {
      const RegionColor color = robustRegionColor(cheek[side].samples);
      if (!color.valid) continue;
      const float coverage = cheek[side].coverage();
      if (coverage > fallbackCoverage) {
        fallbackCoverage = coverage;
        fallbackPlacement = p;
        fallbackSide = side;
        fallbackColor = color;
      }
      if (coverage < EngineConfig::kSideMinCoverage) continue;
      // Más se aparta de la piel en croma, más rubor hay ahí.
      const float distance = std::hypot(color.lab.y - skin.lab.y, color.lab.z - skin.lab.z);
      if (distance > bestDistance) {
        bestDistance = distance;
        bestPlacement = p;
        bestSide = side;
        writeRegion(color, coverage, out, kLookCheeks);
      }
    }
  }
  if (bestPlacement < 0) {
    writeRegion(fallbackColor, std::max(fallbackCoverage, 0.0f), out, kLookCheeks);
    bestPlacement = fallbackPlacement;
    bestSide = fallbackSide;
  }
  out[kLookCheekPlacement] = static_cast<float>(bestPlacement);
  return bestSide;
}

// Delineado de un lado: franjas de distancia a la línea de pestañas; una
// franja es de delineado si la mayoría de sus texels es más oscura que la piel
// y el párpado. El grosor es la última franja contigua desde la línea; el
// wing, igual a lo largo de su avance (B.a), cerca de su eje (B.b).
struct LinerSide {
  float extent = 0.0f;
  float wing = 0.0f;
  Accumulator dark;
};

LinerSide measureLinerSide(const UvGrid& eyes, int side, float darkBelow) {
  LinerSide out;
  std::array<int, EngineConfig::kLinerBands> lineTotal{};
  std::array<int, EngineConfig::kLinerBands> lineDark{};
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
  int lineBands = 0;
  while (lineBands < EngineConfig::kLinerBands && lineTotal[lineBands] > 0 &&
         static_cast<float>(lineDark[lineBands]) >= EngineConfig::kLinerDarkFraction * lineTotal[lineBands]) {
    ++lineBands;
  }
  out.extent = static_cast<float>(lineBands) / EngineConfig::kLinerBands;
  if (lineBands == 0) return out;

  const float wingDistance = std::max(out.extent, EngineConfig::kWingMinDistance);
  std::array<int, EngineConfig::kWingBands> wingTotal{};
  std::array<int, EngineConfig::kWingBands> wingDark{};
  for (int row = 0; row < eyes.height; ++row) {
    for (int col = 0; col < eyes.width; ++col) {
      const size_t texel = (static_cast<size_t>(row) * eyes.width + col) * 4;
      const float lineD = unitByte(mesh::kEyeMapB[texel + 1]);
      const float wingD = unitByte(mesh::kEyeMapB[texel + 2]);
      const float progress = unitByte(mesh::kEyeMapB[texel + 3]);
      const size_t index = eyes.index(side, col, row);
      const bool dark = eyes.valid[index] && eyes.lab[index].x < darkBelow;
      const bool inLine = lineD < out.extent;
      if (inLine && dark) out.dark.samples.push_back(eyes.lab[index]);
      if (progress <= 0.0f || wingD >= wingDistance || !eyes.valid[index]) continue;
      const int band = std::min(static_cast<int>(progress * EngineConfig::kWingBands), EngineConfig::kWingBands - 1);
      ++wingTotal[band];
      if (dark) {
        ++wingDark[band];
        if (!inLine) out.dark.samples.push_back(eyes.lab[index]);
      }
    }
  }
  int wingBands = 0;
  while (wingBands < EngineConfig::kWingBands && wingTotal[wingBands] > 0 &&
         static_cast<float>(wingDark[wingBands]) >= EngineConfig::kLinerDarkFraction * wingTotal[wingBands]) {
    ++wingBands;
  }
  out.wing = static_cast<float>(wingBands) / EngineConfig::kWingBands;
  out.dark.maskTexels = static_cast<int>(out.dark.samples.size());
  return out;
}

// Sombras por región y delineado, cada uno del lado con más maquillaje.
// Devuelve los lados elegidos (bit 0: párpado, bit 1: delineado).
int measureEyes(const UvGrid& eyes, const RegionColor& skin, float* out) {
  std::array<SidePair, kLookEyeRegionCount> regions;
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
          if (unitByte(mapA[region]) >= kMaskThreshold) regions[region][side].add(eyes, index);
        }
        if (unitByte(mapB[0]) >= kMaskThreshold) regions[static_cast<int>(EyeRegion::kBrowBone)][side].add(eyes, index);
      }
    }
  }
  int lidSide = 0;
  for (int region = 0; region < kLookEyeRegionCount; ++region) {
    const int side = writeBestSide(regions[region], skin, out, kLookEyeRegions + region * kRegionFloats);
    if (region == static_cast<int>(EyeRegion::kLid)) lidSide = side;
  }

  // Delineado: el lado con el trazo más grueso (el oscuro se mide contra la
  // piel y el párpado de ese lado).
  LinerSide best;
  int linerSide = 0;
  for (int side = 0; side < eyes.sides; ++side) {
    const RegionColor lid = robustRegionColor(regions[static_cast<int>(EyeRegion::kLid)][side].samples);
    const float reference = lid.valid ? std::min(skin.lab.x, lid.lab.x) : skin.lab.x;
    LinerSide measured = measureLinerSide(eyes, side, reference - EngineConfig::kLinerDarkDelta);
    if (measured.extent > best.extent) {
      best = std::move(measured);
      linerSide = side;
    }
  }
  out[kLookLinerExtent] = best.extent;
  out[kLookWingExtent] = best.wing;
  best.dark.write(out, kLookLiner);
  return lidSide | (linerSide << 1);
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
  measureLips(lips, skin, out);
  const int cheekSide = measureCheeks(face, skin, out);

  UvGrid eyes;
  rectifyToUv(image, landmarks, mesh::kEyeRegionTriangles, mesh::kEyeRegionTriangleCount, mesh::kEyeMapWidth,
              mesh::kEyeMapHeight, mesh::kEyeMapUvRect, true, &eyes);
  const int eyeSides = measureEyes(eyes, skin, out);
  // Bit 0: rubor, bit 1: párpado, bit 2: delineado (0 = mitad u < 0,5 de la malla).
  out[kLookSideMask] = static_cast<float>(cheekSide | (eyeSides << 1));
  return true;
}

}  // namespace makeup
