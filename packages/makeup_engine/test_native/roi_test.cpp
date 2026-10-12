#include <cmath>

#include "test_harness.h"
#include "tracking/roi.h"

using makeup::Point2;
using makeup::Roi;

namespace {
constexpr float kPi = 3.14159265359f;
}

TEST(roi_idaYVuelta) {
  const Roi roi{360.0f, 640.0f, 300.0f, 0.4f};
  const float uvs[][2] = {{0.0f, 0.0f}, {1.0f, 0.0f}, {0.3f, 0.8f}, {0.5f, 0.5f}};
  for (const auto& uv : uvs) {
    const Point2 image = makeup::roiToImage(roi, uv[0], uv[1]);
    const Point2 back = makeup::imageToRoi(roi, image.x, image.y);
    CHECK_NEAR(back.x, uv[0], 1e-5);
    CHECK_NEAR(back.y, uv[1], 1e-5);
  }
  const Point2 center = makeup::roiToImage(roi, 0.5f, 0.5f);
  CHECK_NEAR(center.x, 360.0, 1e-4);
  CHECK_NEAR(center.y, 640.0, 1e-4);
}

TEST(roi_sinRotacionEsUnCuadradoAlineado) {
  const Roi roi{100.0f, 200.0f, 50.0f, 0.0f};
  const Point2 topLeft = makeup::roiToImage(roi, 0.0f, 0.0f);
  const Point2 bottomRight = makeup::roiToImage(roi, 1.0f, 1.0f);
  CHECK_NEAR(topLeft.x, 75.0, 1e-4);
  CHECK_NEAR(topLeft.y, 175.0, 1e-4);
  CHECK_NEAR(bottomRight.x, 125.0, 1e-4);
  CHECK_NEAR(bottomRight.y, 225.0, 1e-4);
}

TEST(roi_matrizDeRecorteCoincideConRoiToImage) {
  constexpr float kWidth = 720.0f;
  constexpr float kHeight = 1280.0f;
  const Roi roi{300.0f, 700.0f, 420.0f, -0.3f};
  float m[9];
  makeup::roiCropMatrix(roi, kWidth, kHeight, m);
  const float uvs[][2] = {{0.0f, 0.0f}, {1.0f, 0.25f}, {0.6f, 0.9f}};
  for (const auto& uv : uvs) {
    const Point2 image = makeup::roiToImage(roi, uv[0], uv[1]);
    // Column-major: x' = m0·u + m3·v + m6.
    CHECK_NEAR(m[0] * uv[0] + m[3] * uv[1] + m[6], image.x / kWidth, 1e-5);
    CHECK_NEAR(m[1] * uv[0] + m[4] * uv[1] + m[7], image.y / kHeight, 1e-5);
  }
  CHECK_NEAR(m[2], 0.0, 0.0);
  CHECK_NEAR(m[5], 0.0, 0.0);
  CHECK_NEAR(m[8], 1.0, 0.0);
}

TEST(roi_letterboxCubreLaImagenEntera) {
  const Roi roi = makeup::letterboxRoi(720.0f, 1280.0f);
  CHECK_NEAR(roi.size, 1280.0, 0.0);
  const Point2 topLeft = makeup::roiToImage(roi, 0.0f, 0.0f);
  CHECK_NEAR(topLeft.x, -280.0, 1e-3);  // banda negra a cada lado
  CHECK_NEAR(topLeft.y, 0.0, 1e-3);
}

// Puntos de un rectángulo rotado: el ROI recupera centro, ángulo y lado.
TEST(roi_desdePuntosRotados) {
  const float angle = 0.35f;
  const float c = std::cos(angle);
  const float s = std::sin(angle);
  constexpr float kCx = 400.0f;
  constexpr float kCy = 600.0f;
  // Esquinas de un rectángulo 200 (a lo largo de los ojos) × 300, y los ojos.
  const float local[][2] = {{-100, -150}, {100, -150}, {100, 150}, {-100, 150}, {-60, -40}, {60, -40}};
  float points[12];
  for (int i = 0; i < 6; ++i) {
    points[i * 2] = kCx + local[i][0] * c - local[i][1] * s;
    points[i * 2 + 1] = kCy + local[i][0] * s + local[i][1] * c;
  }
  const Roi roi = makeup::roiFromPoints(points, 6, 2, 4, 5, 1.5f);
  CHECK_NEAR(roi.rotation, angle, 1e-5);
  CHECK_NEAR(roi.centerX, kCx, 1e-3);
  CHECK_NEAR(roi.centerY, kCy, 1e-3);
  CHECK_NEAR(roi.size, 300.0 * 1.5, 1e-3);
}

TEST(roi_desdePuntosConCaraInvertida) {
  // Ojo "A" a la derecha de la imagen: la cara está cabeza abajo -> ±π.
  const float points[] = {200.0f, 100.0f, 100.0f, 100.0f};
  const Roi roi = makeup::roiFromPoints(points, 2, 2, 0, 1, 1.0f);
  CHECK_NEAR(std::fabs(roi.rotation), kPi, 1e-5);
}

TEST(roi_desdeCaja) {
  const Roi roi = makeup::roiFromBox(100.0f, 200.0f, 80.0f, 120.0f, Point2{110.0f, 230.0f},
                                     Point2{170.0f, 230.0f}, 1.5f);
  CHECK_NEAR(roi.centerX, 140.0, 1e-4);
  CHECK_NEAR(roi.centerY, 260.0, 1e-4);
  CHECK_NEAR(roi.size, 180.0, 1e-4);
  CHECK_NEAR(roi.rotation, 0.0, 1e-6);
  CHECK(!makeup::roiFromBox(0.0f, 0.0f, 0.0f, 10.0f, Point2{0, 0}, Point2{1, 0}, 1.5f).valid());
  CHECK(!makeup::roiFromPoints(nullptr, 0, 2, 0, 1, 1.5f).valid());
}
