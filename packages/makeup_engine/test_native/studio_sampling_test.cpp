// Muestreo robusto (F4): reproduce tools/studio/sample_region_reference.py
// sobre los mismos datos sintéticos (labio mate y con 7 % de píxeles
// especulares). El generador aleatorio no es el de numpy: se comparan las
// propiedades, no los números exactos.
#include <algorithm>
#include <array>
#include <cmath>
#include <random>
#include <vector>

#include "color_math.h"
#include "studio/region_sampling.h"
#include "test_harness.h"

using makeup::Vec3;

namespace {

constexpr float kBase[3] = {0.62f, 0.18f, 0.20f};

std::vector<std::array<float, 3>> matteLip(std::mt19937& rng, int count) {
  std::normal_distribution<float> noise(0.0f, 0.02f);
  std::vector<std::array<float, 3>> pixels(count);
  for (auto& p : pixels) {
    for (int c = 0; c < 3; ++c) p[c] = std::clamp(kBase[c] + noise(rng), 0.0f, 1.0f);
  }
  return pixels;
}

std::vector<Vec3> toLab(const std::vector<std::array<float, 3>>& pixels) {
  std::vector<Vec3> lab;
  lab.reserve(pixels.size());
  for (const auto& p : pixels) lab.push_back(makeup::srgbToOklab(p[0], p[1], p[2]));
  return lab;
}

// OKLab -> sRGB [0,1] con la misma gamma 2.2 del motor.
std::array<float, 3> toSrgb(const Vec3& lab) {
  const Vec3 linear = makeup::oklabToLinear(lab);
  return {std::pow(std::max(linear.x, 0.0f), 1.0f / 2.2f), std::pow(std::max(linear.y, 0.0f), 1.0f / 2.2f),
          std::pow(std::max(linear.z, 0.0f), 1.0f / 2.2f)};
}

}  // namespace

TEST(muestreo_medianaComoNumpy) {
  std::vector<float> odd = {3.0f, 1.0f, 2.0f};
  CHECK_NEAR(makeup::medianInPlace(odd), 2.0, 1e-6);
  std::vector<float> even = {4.0f, 1.0f, 3.0f, 2.0f};
  CHECK_NEAR(makeup::medianInPlace(even), 2.5, 1e-6);
  std::vector<float> empty;
  CHECK_NEAR(makeup::medianInPlace(empty), 0.0, 1e-6);
}

TEST(muestreo_mateSinBrilloYColorRobusto) {
  std::mt19937 rng(1);
  const std::vector<Vec3> lab = toLab(matteLip(rng, 4000));
  const makeup::RegionColor color = makeup::robustRegionColor(lab);
  CHECK(color.valid);
  CHECK(color.count == 4000);
  CHECK(color.gloss <= 0.05f);  // el script: 0,00
  const auto rgb = toSrgb(color.lab);
  for (int c = 0; c < 3; ++c) CHECK_NEAR(rgb[c], kBase[c], 0.005);
}

TEST(muestreo_brillanteDaUnoYNoBlanquea) {
  std::mt19937 rng(1);
  auto pixels = matteLip(rng, 4000);
  // 7 % de píxeles especulares: pix·0,3 + 0,75 (como el script).
  std::vector<int> order(pixels.size());
  for (size_t i = 0; i < order.size(); ++i) order[i] = static_cast<int>(i);
  std::shuffle(order.begin(), order.end(), rng);
  for (int i = 0; i < 280; ++i) {
    auto& p = pixels[order[i]];
    for (int c = 0; c < 3; ++c) p[c] = std::clamp(p[c] * 0.3f + 0.75f, 0.0f, 1.0f);
  }
  const makeup::RegionColor color = makeup::robustRegionColor(toLab(pixels));
  CHECK(color.valid);
  CHECK(color.gloss >= 0.95f);  // el script: 1,00
  // El color robusto no sale "blanquecino": descarta los brillos.
  const auto rgb = toSrgb(color.lab);
  for (int c = 0; c < 3; ++c) CHECK_NEAR(rgb[c], kBase[c], 0.005);
}

TEST(muestreo_pocasMuestrasNoEsValida) {
  std::vector<Vec3> few(10, Vec3{0.5f, 0.1f, 0.0f});
  const makeup::RegionColor color = makeup::robustRegionColor(few);
  CHECK(!color.valid);
  CHECK(color.count == 10);
}

TEST(muestreo_deltaE) {
  CHECK_NEAR(makeup::deltaE(Vec3{0.5f, 0.0f, 0.0f}, Vec3{0.5f, 0.03f, 0.04f}), 0.05, 1e-6);
}
