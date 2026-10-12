#include "roi.h"

#include <algorithm>
#include <cfloat>
#include <cmath>

namespace makeup {

namespace {

// Normaliza a (-π, π].
float normalizeRadians(float angle) {
  constexpr float kPi = 3.14159265359f;
  constexpr float kTwoPi = 2.0f * kPi;
  return angle - kTwoPi * std::floor((angle + kPi) / kTwoPi);
}

float eyeAngle(Point2 eyeA, Point2 eyeB) {
  return normalizeRadians(std::atan2(eyeB.y - eyeA.y, eyeB.x - eyeA.x));
}

}  // namespace

Point2 roiToImage(const Roi& roi, float u, float v) {
  const float c = std::cos(roi.rotation);
  const float s = std::sin(roi.rotation);
  const float du = (u - 0.5f) * roi.size;
  const float dv = (v - 0.5f) * roi.size;
  return Point2{roi.centerX + du * c - dv * s, roi.centerY + du * s + dv * c};
}

Point2 imageToRoi(const Roi& roi, float x, float y) {
  const float c = std::cos(roi.rotation);
  const float s = std::sin(roi.rotation);
  const float dx = x - roi.centerX;
  const float dy = y - roi.centerY;
  // Rotación inversa (transpuesta).
  return Point2{(dx * c + dy * s) / roi.size + 0.5f, (-dx * s + dy * c) / roi.size + 0.5f};
}

void roiCropMatrix(const Roi& roi, float imageWidth, float imageHeight, float out[9]) {
  const float c = std::cos(roi.rotation) * roi.size;
  const float s = std::sin(roi.rotation) * roi.size;
  // Columna 0: coeficiente de u; columna 1: de v; columna 2: traslación.
  out[0] = c / imageWidth;
  out[1] = s / imageHeight;
  out[2] = 0.0f;
  out[3] = -s / imageWidth;
  out[4] = c / imageHeight;
  out[5] = 0.0f;
  out[6] = (roi.centerX - 0.5f * c + 0.5f * s) / imageWidth;
  out[7] = (roi.centerY - 0.5f * s - 0.5f * c) / imageHeight;
  out[8] = 1.0f;
}

Roi letterboxRoi(float imageWidth, float imageHeight) {
  return Roi{imageWidth * 0.5f, imageHeight * 0.5f, std::max(imageWidth, imageHeight), 0.0f};
}

Roi roiFromPoints(const float* points, int count, int stride, int eyeA, int eyeB, float scale) {
  if (count <= 0 || eyeA >= count || eyeB >= count) return Roi{};
  const Point2 a{points[eyeA * stride], points[eyeA * stride + 1]};
  const Point2 b{points[eyeB * stride], points[eyeB * stride + 1]};
  const float rotation = eyeAngle(a, b);
  const float c = std::cos(rotation);
  const float s = std::sin(rotation);

  // Caja en el marco rotado (ejes u, v), relativa al origen de la imagen.
  float minU = FLT_MAX;
  float maxU = -FLT_MAX;
  float minV = FLT_MAX;
  float maxV = -FLT_MAX;
  for (int i = 0; i < count; ++i) {
    const float x = points[i * stride];
    const float y = points[i * stride + 1];
    const float u = x * c + y * s;
    const float v = -x * s + y * c;
    minU = std::min(minU, u);
    maxU = std::max(maxU, u);
    minV = std::min(minV, v);
    maxV = std::max(maxV, v);
  }
  const float midU = 0.5f * (minU + maxU);
  const float midV = 0.5f * (minV + maxV);
  return Roi{midU * c - midV * s, midU * s + midV * c,
             std::max(maxU - minU, maxV - minV) * scale, rotation};
}

Roi roiFromBox(float xMin, float yMin, float width, float height, Point2 eyeA, Point2 eyeB,
               float scale) {
  if (width <= 0.0f || height <= 0.0f) return Roi{};
  return Roi{xMin + 0.5f * width, yMin + 0.5f * height, std::max(width, height) * scale,
             eyeAngle(eyeA, eyeB)};
}

}  // namespace makeup
