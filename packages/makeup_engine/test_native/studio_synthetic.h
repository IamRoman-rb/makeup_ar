// "Foto" sintética de una cara maquillada para los tests de F4: la cara es el
// UV canónico proyectado afín (x = u·S, y = (1 - v)·S) y cada píxel se pinta
// con los mapas del motor (labios, rubor, sombra del párpado, delineado y
// wing). Los landmarks son esos mismos UV, así que la rectificación es exacta
// salvo en los bordes.
#pragma once

#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

#include "engine_config.h"
#include "mesh/canonical_mesh.h"
#include "mesh/eye_maps.h"
#include "mesh/face_maps.h"
#include "mesh/lips_maps.h"
#include "studio/still_image.h"

namespace synthetic {

struct Look {
  float skin[3] = {0.80f, 0.62f, 0.52f};
  float lip[3] = {0.70f, 0.10f, 0.20f};
  bool blush = true;
  int placement = 1;  // high
  float blushColor[3] = {0.90f, 0.35f, 0.40f};
  float blushOpacity = 0.6f;
  bool shadow = true;
  float shadowColor[3] = {0.55f, 0.35f, 0.60f};
  bool liner = true;
  float linerDistance = 0.3f;  // B.g normalizado
  float wing = 0.6f;           // avance B.a
  // Rubor, sombra y delineado solo en la mitad u < 0,5 de la cara.
  bool oneSide = false;
  // Otro color de labio en la mitad u >= 0,5 (labio bicolor).
  bool bicolor = false;
  float lip2[3] = {0.85f, 0.55f, 0.55f};
  // Ahumado: color oscuro en la V externa y en degradé desde la línea de
  // pestañas, encima de la sombra del párpado.
  bool smoky = false;
  float smokyColor[3] = {0.16f, 0.13f, 0.32f};
};

constexpr int kSize = 1000;

inline bool mapTexel(const float rect[4], int width, int height, float u, float v, int* col, int* row) {
  const float gx = (u - rect[0]) / rect[2] * width;
  const float gy = (v - rect[1]) / rect[3] * height;
  if (gx < 0.0f || gy < 0.0f || gx >= width || gy >= height) return false;
  *col = static_cast<int>(gx);
  *row = static_cast<int>(gy);
  return true;
}

inline void mix(float dst[3], const float src[3], float t) {
  for (int c = 0; c < 3; ++c) dst[c] += (src[c] - dst[c]) * t;
}

// Color sRGB de la cara en (u, v).
inline void paint(const Look& look, float u, float v, float out[3]) {
  for (int c = 0; c < 3; ++c) out[c] = look.skin[c];
  const float mirrored = std::fmin(u, 1.0f - u);
  const bool madeUp = !look.oneSide || u < 0.5f;
  int col = 0;
  int row = 0;
  if (look.blush && madeUp) {
    const float* p = makeup::mesh::kCheekPlacements[look.placement];
    const float scale = 0.5f * (makeup::EngineConfig::kCheekSpreadScaleMin + makeup::EngineConfig::kCheekSpreadScaleMax);
    const float du = mirrored - p[0];
    const float dv = v - p[1];
    const float cs = std::cos(p[4]);
    const float sn = std::sin(p[4]);
    const float gu = (cs * du + sn * dv) / (p[2] * scale);
    const float gv = (-sn * du + cs * dv) / (p[3] * scale);
    mix(out, look.blushColor, look.blushOpacity * std::exp(-0.5f * (gu * gu + gv * gv)));
  }
  if (mapTexel(makeup::mesh::kEyeMapUvRect, makeup::mesh::kEyeMapWidth, makeup::mesh::kEyeMapHeight, mirrored, v,
               &col, &row)) {
    const size_t texel = (static_cast<size_t>(row) * makeup::mesh::kEyeMapWidth + col) * 4;
    const float lid = makeup::mesh::kEyeMapA[texel] / 255.0f;
    const float lineD = makeup::mesh::kEyeMapB[texel + 1] / 255.0f;
    const float wingD = makeup::mesh::kEyeMapB[texel + 2] / 255.0f;
    const float progress = makeup::mesh::kEyeMapB[texel + 3] / 255.0f;
    if (look.shadow && madeUp) mix(out, look.shadowColor, lid);
    if (look.smoky && madeUp) {
      const float outerV = makeup::mesh::kEyeMapA[texel + 2] / 255.0f;
      // Degradé desde la línea de pestañas (un ahumado se esfuma hacia arriba).
      mix(out, look.smokyColor, std::fmax(outerV, std::fmax(0.0f, 1.0f - lineD / 0.9f)));
    }
    if (look.liner && madeUp) {
      const float black[3] = {0.05f, 0.05f, 0.05f};
      const bool line = lineD < look.linerDistance;
      const bool wing = progress > 0.0f && progress < look.wing && wingD < look.linerDistance;
      if (line || wing) mix(out, black, 1.0f);
    }
  }
  if (mapTexel(makeup::mesh::kLipsMapUvRect, makeup::mesh::kLipsMapWidth, makeup::mesh::kLipsMapHeight, u, v, &col,
               &row)) {
    const float mask = makeup::mesh::kLipsMapRgba[(static_cast<size_t>(row) * makeup::mesh::kLipsMapWidth + col) * 4] / 255.0f;
    mix(out, look.bicolor && u >= 0.5f ? look.lip2 : look.lip, mask);
  }
}

inline makeup::StillImage photo(const Look& look, bool mirrorImage = false) {
  makeup::StillImage image;
  image.width = kSize;
  image.height = kSize;
  image.rgba.resize(static_cast<size_t>(kSize) * kSize * 4);
  float rgb[3];
  for (int y = 0; y < kSize; ++y) {
    for (int x = 0; x < kSize; ++x) {
      const float px = (static_cast<float>(x) + 0.5f) / kSize;
      const float u = mirrorImage ? 1.0f - px : px;
      const float v = 1.0f - (static_cast<float>(y) + 0.5f) / kSize;
      paint(look, u, v, rgb);
      uint8_t* dst = &image.rgba[(static_cast<size_t>(y) * kSize + x) * 4];
      for (int c = 0; c < 3; ++c) dst[c] = static_cast<uint8_t>(std::lround(std::fmin(std::fmax(rgb[c], 0.0f), 1.0f) * 255.0f));
      dst[3] = 255;
    }
  }
  return image;
}

inline std::vector<float> landmarks(bool mirrorImage = false) {
  std::vector<float> points(makeup::EngineConfig::kLandmarkCount * 3, 0.0f);
  for (int i = 0; i < makeup::EngineConfig::kLandmarkCount; ++i) {
    const int vertex = i < makeup::mesh::kVertexCount ? i : 0;
    const float u = makeup::mesh::kUvs[vertex * 2];
    const float v = makeup::mesh::kUvs[vertex * 2 + 1];
    points[i * 3] = (mirrorImage ? 1.0f - u : u) * kSize;
    points[i * 3 + 1] = (1.0f - v) * kSize;
  }
  return points;
}

}  // namespace synthetic
