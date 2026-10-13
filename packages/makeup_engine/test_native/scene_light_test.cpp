#include <cmath>
#include <vector>

#include "color_math.h"
#include "engine_config.h"
#include "scene_light.h"
#include "test_harness.h"

using makeup::EngineConfig;
using makeup::SceneLightEstimator;
using makeup::Vec3;

namespace {

constexpr int kSize = EngineConfig::kScenePassSize;
constexpr int kPixels = kSize * kSize;

std::vector<uint8_t> uniform(uint8_t r, uint8_t g, uint8_t b) {
  std::vector<uint8_t> out(kPixels * 4);
  for (int i = 0; i < kPixels; ++i) {
    out[i * 4] = r;
    out[i * 4 + 1] = g;
    out[i * 4 + 2] = b;
    out[i * 4 + 3] = 255;
  }
  return out;
}

float luminance(const Vec3& c) { return 0.2126f * c.x + 0.7152f * c.y + 0.0722f * c.z; }

}  // namespace

TEST(luz_oklabIdaYVuelta) {
  const Vec3 linear{0.4f, 0.1f, 0.05f};
  const Vec3 back = makeup::oklabToLinear(makeup::linearToOklab(linear));
  CHECK_NEAR(back.x, linear.x, 1e-4);
  CHECK_NEAR(back.y, linear.y, 1e-4);
  CHECK_NEAR(back.z, linear.z, 1e-4);
  // Mismas fórmulas que srgbToOklab.
  const Vec3 a = makeup::srgbToOklab(0.7f, 0.2f, 0.3f);
  const Vec3 b = makeup::linearToOklab(
      Vec3{makeup::srgbToLinear(0.7f), makeup::srgbToLinear(0.2f), makeup::srgbToLinear(0.3f)});
  CHECK_NEAR(a.x, b.x, 1e-6);
  CHECK_NEAR(a.y, b.y, 1e-6);
}

TEST(luz_escenaGrisNoCambiaNada) {
  SceneLightEstimator light;
  const std::vector<uint8_t> gray = uniform(128, 128, 128);
  light.update(gray.data(), kSize, nullptr);
  CHECK_NEAR(light.gain().x, 1.0, 1e-4);
  CHECK_NEAR(light.gain().y, 1.0, 1e-4);
  CHECK_NEAR(light.gain().z, 1.0, 1e-4);
  float lab[3] = {0.5f, 0.15f, 0.05f};
  makeup::adaptOklab(lab, light.gain());
  CHECK_NEAR(lab[0], 0.5, 1e-4);
  CHECK_NEAR(lab[1], 0.15, 1e-4);
}

TEST(luz_escenaCalidaCalientaElMaquillaje) {
  SceneLightEstimator light;
  const std::vector<uint8_t> warm = uniform(200, 160, 120);
  CHECK(light.update(warm.data(), kSize, nullptr));
  const Vec3& gain = light.gain();
  CHECK(gain.x > 1.0f && gain.z < 1.0f);
  CHECK(gain.x <= EngineConfig::kLightAdaptGainMax + 1e-6f);
  CHECK_NEAR(luminance(gain), 1.0, 1e-4);  // no cambia la luminosidad
  // Un rojo frío se corre hacia el amarillo (b de OKLab sube), con L casi igual.
  float lab[3];
  const Vec3 red = makeup::srgbToOklab(0.70f, 0.07f, 0.18f);
  lab[0] = red.x;
  lab[1] = red.y;
  lab[2] = red.z;
  makeup::adaptOklab(lab, gain);
  CHECK(lab[2] > red.z + 0.01f);
  CHECK_NEAR(lab[0], red.x, 0.03);
}

TEST(luz_ignoraQuemadosYNegrosYSeSuaviza) {
  SceneLightEstimator light;
  // Casi todo quemado o negro: no alcanza para medir.
  std::vector<uint8_t> bad = uniform(255, 255, 255);
  for (int i = 0; i < kPixels / 2; ++i) bad[i * 4] = bad[i * 4 + 1] = bad[i * 4 + 2] = 0;
  CHECK(!light.update(bad.data(), kSize, nullptr));
  CHECK(light.gain().x == 1.0f);
  // Escena cálida y después neutra: la ganancia vuelve de a poco.
  const std::vector<uint8_t> warm = uniform(200, 160, 120);
  light.update(warm.data(), kSize, nullptr);
  const float warmGain = light.gain().x;
  const std::vector<uint8_t> gray = uniform(128, 128, 128);
  CHECK(light.update(gray.data(), kSize, nullptr));
  CHECK(light.gain().x < warmGain && light.gain().x > 1.0f);
  for (int i = 0; i < 30; ++i) light.update(gray.data(), kSize, nullptr);
  CHECK_NEAR(light.gain().x, 1.0, 0.01);
  // Sin cambios, no pide volver a adaptar.
  CHECK(!light.update(gray.data(), kSize, nullptr));
}

TEST(luz_sinLaCara) {
  // Fondo gris y la cara (cálida) en el centro: excluida, la luz es neutra.
  std::vector<uint8_t> scene = uniform(128, 128, 128);
  for (int y = 4; y < 12; ++y) {
    for (int x = 4; x < 12; ++x) {
      uint8_t* p = scene.data() + (y * kSize + x) * 4;
      p[0] = 220;
      p[1] = 160;
      p[2] = 130;
    }
  }
  SceneLightEstimator withFace;
  withFace.update(scene.data(), kSize, nullptr);
  CHECK(withFace.gain().x > 1.02f);  // la piel tiñe la medición
  SceneLightEstimator withoutFace;
  const float face[4] = {0.25f, 0.25f, 0.75f, 0.75f};
  withoutFace.update(scene.data(), kSize, face);
  CHECK_NEAR(withoutFace.gain().x, 1.0, 1e-3);
  // La cara tapa casi todo: no hay suficiente escena para medir.
  SceneLightEstimator close;
  const float big[4] = {0.0f, 0.0f, 1.0f, 0.9f};
  CHECK(!close.update(scene.data(), kSize, big));
}
