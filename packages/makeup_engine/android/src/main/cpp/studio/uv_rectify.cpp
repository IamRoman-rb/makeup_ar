#include "studio/uv_rectify.h"

#include <algorithm>
#include <cmath>

#include "engine_config.h"
#include "mesh/canonical_mesh.h"

namespace makeup {

namespace {

struct Corner {
  float u;   // UV canónico (sin espejar)
  float v;
  float gx;  // posición en la grilla (texel con centro en enteros)
  float gy;
  float x;   // px de la foto
  float y;
};

float cross(float ax, float ay, float bx, float by) { return ax * by - ay * bx; }

// Área con signo en la foto dividida por el área con signo en UV (sin
// espejar). Para los triángulos de frente el signo es el mismo en toda la
// cara; de espaldas, el contrario.
float areaRatio(const Corner& a, const Corner& b, const Corner& c) {
  const float uvArea = cross(b.u - a.u, b.v - a.v, c.u - a.u, c.v - a.v);
  if (std::fabs(uvArea) < 1e-12f) return 0.0f;
  return cross(b.x - a.x, b.y - a.y, c.x - a.x, c.y - a.y) / uvArea;
}

}  // namespace

int rectifyToUv(const StillImage& image, const float* landmarks, const uint16_t* triangles, int triangleCount,
                int width, int height, const float rect[4], bool mirrored, UvGrid* grid) {
  grid->width = width;
  grid->height = height;
  for (int i = 0; i < 4; ++i) grid->rect[i] = rect[i];
  grid->sides = mirrored ? 2 : 1;
  const size_t texels = static_cast<size_t>(grid->sides) * width * height;
  grid->lab.assign(texels, Vec3{0.0f, 0.0f, 0.0f});
  grid->valid.assign(texels, 0);
  if (!image.valid() || triangleCount <= 0) return 0;

  auto corner = [&](int vertex) {
    Corner out;
    out.u = mesh::kUvs[vertex * 2];
    out.v = mesh::kUvs[vertex * 2 + 1];
    const float mappedU = mirrored ? std::min(out.u, 1.0f - out.u) : out.u;
    out.gx = (mappedU - rect[0]) / rect[2] * static_cast<float>(width) - 0.5f;
    out.gy = (out.v - rect[1]) / rect[3] * static_cast<float>(height) - 0.5f;
    out.x = landmarks[vertex * 3];
    out.y = landmarks[vertex * 3 + 1];
    return out;
  };

  // Orientación de la cara en la foto: el signo mayoritario de la relación de
  // áreas, ponderado por el área (una foto espejada lo invierte entero).
  std::vector<float> ratios(static_cast<size_t>(triangleCount));
  float signedSum = 0.0f;
  for (int t = 0; t < triangleCount; ++t) {
    const Corner a = corner(triangles[t * 3]);
    const Corner b = corner(triangles[t * 3 + 1]);
    const Corner c = corner(triangles[t * 3 + 2]);
    ratios[t] = areaRatio(a, b, c);
    signedSum += ratios[t];
  }
  const float facing = signedSum >= 0.0f ? 1.0f : -1.0f;
  std::vector<float> magnitudes;
  magnitudes.reserve(ratios.size());
  for (float r : ratios) {
    if (r * facing > 0.0f) magnitudes.push_back(r * facing);
  }
  if (magnitudes.empty()) return 0;
  std::nth_element(magnitudes.begin(), magnitudes.begin() + magnitudes.size() / 2, magnitudes.end());
  const float minRatio = magnitudes[magnitudes.size() / 2] * EngineConfig::kStillMinTriangleAreaRatio;

  int filled = 0;
  float rgb[3];
  for (int t = 0; t < triangleCount; ++t) {
    if (ratios[t] * facing < minRatio) continue;  // de espaldas o de costado
    const Corner a = corner(triangles[t * 3]);
    const Corner b = corner(triangles[t * 3 + 1]);
    const Corner c = corner(triangles[t * 3 + 2]);
    const int side = mirrored && (a.u + b.u + c.u) / 3.0f >= 0.5f ? 1 : 0;
    const float area = cross(b.gx - a.gx, b.gy - a.gy, c.gx - a.gx, c.gy - a.gy);
    if (std::fabs(area) < 1e-9f) continue;
    const float invArea = 1.0f / area;
    const int colMin = std::max(0, static_cast<int>(std::ceil(std::min({a.gx, b.gx, c.gx}))));
    const int colMax = std::min(width - 1, static_cast<int>(std::floor(std::max({a.gx, b.gx, c.gx}))));
    const int rowMin = std::max(0, static_cast<int>(std::ceil(std::min({a.gy, b.gy, c.gy}))));
    const int rowMax = std::min(height - 1, static_cast<int>(std::floor(std::max({a.gy, b.gy, c.gy}))));
    for (int row = rowMin; row <= rowMax; ++row) {
      const float py = static_cast<float>(row);
      for (int col = colMin; col <= colMax; ++col) {
        const float px = static_cast<float>(col);
        // Baricéntricas por funciones de arista (el signo de area las normaliza).
        const float wa = cross(b.gx - px, b.gy - py, c.gx - px, c.gy - py) * invArea;
        const float wb = cross(c.gx - px, c.gy - py, a.gx - px, a.gy - py) * invArea;
        const float wc = 1.0f - wa - wb;
        constexpr float kEdge = -1e-4f;
        if (wa < kEdge || wb < kEdge || wc < kEdge) continue;
        const float x = wa * a.x + wb * b.x + wc * c.x;
        const float y = wa * a.y + wb * b.y + wc * c.y;
        if (!sampleStill(image, x, y, rgb)) continue;
        const size_t index = grid->index(side, col, row);
        if (!grid->valid[index]) ++filled;
        grid->lab[index] = srgbFloatToOklab(rgb);
        grid->valid[index] = 1;
      }
    }
  }
  return filled;
}

}  // namespace makeup
