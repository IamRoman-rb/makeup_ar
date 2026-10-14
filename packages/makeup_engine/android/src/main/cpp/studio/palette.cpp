#include "studio/palette.h"

#include <algorithm>
#include <cfloat>
#include <cmath>
#include <vector>

#include "engine_config.h"
#include "studio/region_sampling.h"

namespace makeup {

namespace {

struct Cluster {
  Vec3 center{0.0f, 0.0f, 0.0f};
  int size = 0;
};

float distanceSquared(const Vec3& a, const Vec3& b) {
  const float dl = a.x - b.x;
  const float da = a.y - b.y;
  const float db = a.z - b.z;
  return dl * dl + da * da + db * db;
}

// Miniatura en OKLab: promedio en RGB lineal de bloques de block×block px.
std::vector<Vec3> thumbnail(const StillImage& image, int* outWidth, int* outHeight) {
  const int longSide = std::max(image.width, image.height);
  const int block = std::max(1, (longSide + EngineConfig::kPaletteMaxSide - 1) / EngineConfig::kPaletteMaxSide);
  const int width = std::max(1, image.width / block);
  const int height = std::max(1, image.height / block);
  std::vector<Vec3> lab(static_cast<size_t>(width) * height);
  for (int row = 0; row < height; ++row) {
    for (int col = 0; col < width; ++col) {
      Vec3 sum{0.0f, 0.0f, 0.0f};
      int count = 0;
      for (int y = row * block; y < std::min((row + 1) * block, image.height); ++y) {
        for (int x = col * block; x < std::min((col + 1) * block, image.width); ++x) {
          const uint8_t* p = &image.rgba[(static_cast<size_t>(y) * image.width + x) * 4];
          sum.x += srgb8ToLinear(p[0]);
          sum.y += srgb8ToLinear(p[1]);
          sum.z += srgb8ToLinear(p[2]);
          ++count;
        }
      }
      const float inv = count > 0 ? 1.0f / static_cast<float>(count) : 0.0f;
      lab[static_cast<size_t>(row) * width + col] = linearToOklab(Vec3{sum.x * inv, sum.y * inv, sum.z * inv});
    }
  }
  *outWidth = width;
  *outHeight = height;
  return lab;
}

Vec3 borderMedian(const std::vector<Vec3>& lab, int width, int height) {
  std::vector<float> l;
  std::vector<float> a;
  std::vector<float> b;
  for (int row = 0; row < height; ++row) {
    for (int col = 0; col < width; ++col) {
      if (row != 0 && row != height - 1 && col != 0 && col != width - 1) continue;
      const Vec3& c = lab[static_cast<size_t>(row) * width + col];
      l.push_back(c.x);
      a.push_back(c.y);
      b.push_back(c.z);
    }
  }
  return Vec3{medianInPlace(l), medianInPlace(a), medianInPlace(b)};
}

void toSrgb(const Vec3& lab, float out[3]) {
  const Vec3 linear = oklabToLinear(lab);
  const float channels[3] = {linear.x, linear.y, linear.z};
  for (int c = 0; c < 3; ++c) out[c] = std::pow(std::clamp(channels[c], 0.0f, 1.0f), 1.0f / 2.2f);
}

}  // namespace

int extractPalette(const StillImage& image, PaletteSwatch* out, int maxSwatches) {
  if (!image.valid() || maxSwatches <= 0) return 0;
  int width = 0;
  int height = 0;
  const std::vector<Vec3> lab = thumbnail(image, &width, &height);

  // Fondo: lo parecido a la mediana del borde. Si eso deja muy poco (el
  // producto llena la foto), no se descarta.
  const Vec3 background = borderMedian(lab, width, height);
  const float backgroundSq = EngineConfig::kPaletteBackgroundDelta * EngineConfig::kPaletteBackgroundDelta;
  const float edgeSq = EngineConfig::kPaletteEdgeDelta * EngineConfig::kPaletteEdgeDelta;
  // Píxeles de borde (mezcla de dos colores por el antialias o por la
  // miniatura): un salto grande con algún vecino. Formaban swatches falsos.
  auto isEdge = [&](int col, int row) {
    const Vec3& c = lab[static_cast<size_t>(row) * width + col];
    const int neighbors[4][2] = {{col - 1, row}, {col + 1, row}, {col, row - 1}, {col, row + 1}};
    for (const auto& n : neighbors) {
      if (n[0] < 0 || n[1] < 0 || n[0] >= width || n[1] >= height) continue;
      if (distanceSquared(c, lab[static_cast<size_t>(n[1]) * width + n[0]]) >= edgeSq) return true;
    }
    return false;
  };
  std::vector<Vec3> points;
  std::vector<Vec3> withBackground;
  std::vector<Vec3> withEdges;
  points.reserve(lab.size());
  for (int row = 0; row < height; ++row) {
    for (int col = 0; col < width; ++col) {
      const Vec3& c = lab[static_cast<size_t>(row) * width + col];
      const bool white =
          c.x > EngineConfig::kPaletteWhiteLightness && std::hypot(c.y, c.z) < EngineConfig::kPaletteWhiteChroma;
      if (white) continue;
      withBackground.push_back(c);
      if (distanceSquared(c, background) < backgroundSq) continue;
      withEdges.push_back(c);
      if (!isEdge(col, row)) points.push_back(c);
    }
  }
  // Si un filtro deja muy poco (producto que llena la foto, textura con
  // brillos), se lo saltea.
  const size_t enough = lab.size() / 10;
  if (points.size() < enough) points.swap(withEdges);
  if (points.size() < enough) points.swap(withBackground);
  if (points.empty()) return 0;

  // Semillas: la más cercana a la media y después, una a una, la más lejana
  // a las ya elegidas.
  const int k = std::min(EngineConfig::kPaletteClusters, static_cast<int>(points.size()));
  Vec3 mean{0.0f, 0.0f, 0.0f};
  for (const Vec3& p : points) {
    mean.x += p.x;
    mean.y += p.y;
    mean.z += p.z;
  }
  const float invCount = 1.0f / static_cast<float>(points.size());
  mean = Vec3{mean.x * invCount, mean.y * invCount, mean.z * invCount};
  std::vector<Cluster> clusters;
  std::vector<float> nearest(points.size(), FLT_MAX);
  size_t first = 0;
  for (size_t i = 1; i < points.size(); ++i) {
    if (distanceSquared(points[i], mean) < distanceSquared(points[first], mean)) first = i;
  }
  clusters.push_back(Cluster{points[first], 0});
  while (static_cast<int>(clusters.size()) < k) {
    size_t farthest = 0;
    for (size_t i = 0; i < points.size(); ++i) {
      nearest[i] = std::min(nearest[i], distanceSquared(points[i], clusters.back().center));
      if (nearest[i] > nearest[farthest]) farthest = i;
    }
    if (nearest[farthest] <= 0.0f) break;  // menos colores distintos que k
    clusters.push_back(Cluster{points[farthest], 0});
  }

  std::vector<int> assignment(points.size(), 0);
  for (int iteration = 0; iteration < EngineConfig::kPaletteIterations; ++iteration) {
    for (size_t i = 0; i < points.size(); ++i) {
      int best = 0;
      float bestDistance = FLT_MAX;
      for (size_t c = 0; c < clusters.size(); ++c) {
        const float d = distanceSquared(points[i], clusters[c].center);
        if (d < bestDistance) {
          bestDistance = d;
          best = static_cast<int>(c);
        }
      }
      assignment[i] = best;
    }
    std::vector<Vec3> sums(clusters.size(), Vec3{0.0f, 0.0f, 0.0f});
    for (Cluster& c : clusters) c.size = 0;
    for (size_t i = 0; i < points.size(); ++i) {
      Vec3& s = sums[assignment[i]];
      s.x += points[i].x;
      s.y += points[i].y;
      s.z += points[i].z;
      ++clusters[assignment[i]].size;
    }
    for (size_t c = 0; c < clusters.size(); ++c) {
      if (clusters[c].size == 0) continue;  // queda donde estaba
      const float inv = 1.0f / static_cast<float>(clusters[c].size);
      clusters[c].center = Vec3{sums[c].x * inv, sums[c].y * inv, sums[c].z * inv};
    }
  }

  // Unir clusters casi iguales (promedio ponderado) y descartar los chicos.
  const float mergeSq = EngineConfig::kPaletteMergeDelta * EngineConfig::kPaletteMergeDelta;
  for (size_t i = 0; i < clusters.size(); ++i) {
    for (size_t j = i + 1; j < clusters.size(); ++j) {
      if (clusters[i].size == 0 || clusters[j].size == 0) continue;
      if (distanceSquared(clusters[i].center, clusters[j].center) >= mergeSq) continue;
      const float total = static_cast<float>(clusters[i].size + clusters[j].size);
      const float wi = clusters[i].size / total;
      const float wj = clusters[j].size / total;
      const Vec3& a = clusters[i].center;
      const Vec3& b = clusters[j].center;
      clusters[i].center = Vec3{a.x * wi + b.x * wj, a.y * wi + b.y * wj, a.z * wi + b.z * wj};
      clusters[i].size += clusters[j].size;
      clusters[j].size = 0;
    }
  }
  std::sort(clusters.begin(), clusters.end(), [](const Cluster& a, const Cluster& b) { return a.size > b.size; });
  int written = 0;
  for (const Cluster& c : clusters) {
    if (written >= maxSwatches) break;
    const float fraction = static_cast<float>(c.size) * invCount;
    if (c.size == 0 || fraction < EngineConfig::kPaletteMinFraction) continue;
    PaletteSwatch& swatch = out[written++];
    swatch.lab = c.center;
    swatch.fraction = fraction;
    toSrgb(c.center, swatch.rgb);
  }
  return written;
}

}  // namespace makeup
