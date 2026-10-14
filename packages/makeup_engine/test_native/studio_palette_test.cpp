// Paleta de producto (F4, §10.6): K-means en OKLab sin fondo ni blancos.
#include <cmath>
#include <cstdint>

#include "color_math.h"
#include "studio/palette.h"
#include "studio/region_sampling.h"
#include "test_harness.h"

namespace {

struct Rect {
  int x0;
  int x1;
  uint8_t rgb[3];
};

// 300×100 con fondo [background] y franjas verticales de color.
makeup::StillImage stripes(const uint8_t background[3], const Rect* rects, int count) {
  makeup::StillImage image;
  image.width = 300;
  image.height = 100;
  image.rgba.resize(300 * 100 * 4);
  for (int y = 0; y < 100; ++y) {
    for (int x = 0; x < 300; ++x) {
      const uint8_t* color = background;
      for (int r = 0; r < count; ++r) {
        if (x >= rects[r].x0 && x < rects[r].x1 && y >= 10 && y < 90) color = rects[r].rgb;
      }
      uint8_t* dst = &image.rgba[(static_cast<size_t>(y) * 300 + x) * 4];
      dst[0] = color[0];
      dst[1] = color[1];
      dst[2] = color[2];
      dst[3] = 255;
    }
  }
  return image;
}

makeup::Vec3 lab(const uint8_t rgb[3]) { return makeup::srgbToOklab(rgb[0] / 255.0f, rgb[1] / 255.0f, rgb[2] / 255.0f); }

}  // namespace

TEST(paleta_tresColoresSobreFondoBlancoPorArea) {
  const uint8_t white[3] = {250, 250, 250};
  const Rect rects[] = {
      {10, 130, {180, 20, 50}},   // rojo: 120 px de ancho
      {140, 220, {120, 70, 50}},  // marrón: 80
      {230, 270, {200, 140, 160}},  // rosa: 40
  };
  const makeup::StillImage image = stripes(white, rects, 3);
  makeup::PaletteSwatch swatches[5];
  const int count = makeup::extractPalette(image, swatches, 5);
  CHECK(count == 3);
  if (count != 3) return;
  for (int i = 0; i < 3; ++i) CHECK(makeup::deltaE(swatches[i].lab, lab(rects[i].rgb)) < 0.02f);
  CHECK(swatches[0].fraction > swatches[1].fraction);
  CHECK(swatches[1].fraction > swatches[2].fraction);
  CHECK_NEAR(swatches[0].fraction + swatches[1].fraction + swatches[2].fraction, 1.0, 0.08);
  CHECK_NEAR(swatches[0].rgb[0], 180.0 / 255.0, 0.02);
}

TEST(paleta_fondoDeColorSeDescarta) {
  const uint8_t gray[3] = {90, 100, 110};
  const Rect rects[] = {{100, 200, {220, 120, 40}}};
  const makeup::StillImage image = stripes(gray, rects, 1);
  makeup::PaletteSwatch swatches[5];
  const int count = makeup::extractPalette(image, swatches, 5);
  CHECK(count == 1);
  if (count == 1) CHECK(makeup::deltaE(swatches[0].lab, lab(rects[0].rgb)) < 0.02f);
}

TEST(paleta_todoBlancoNoDaNada) {
  const uint8_t white[3] = {255, 255, 255};
  const makeup::StillImage image = stripes(white, nullptr, 0);
  makeup::PaletteSwatch swatches[5];
  CHECK(makeup::extractPalette(image, swatches, 5) == 0);
}
