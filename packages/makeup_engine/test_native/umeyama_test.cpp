#include <cmath>
#include <random>

#include "test_harness.h"
#include "tracking/umeyama.h"

using makeup::SimilarityTransform;

namespace {

// R = Rz(roll) · Ry(yaw) · Rx(pitch), fila mayor.
void rotationFromEuler(float pitch, float yaw, float roll, float r[9]) {
  const float cp = std::cos(pitch), sp = std::sin(pitch);
  const float cy = std::cos(yaw), sy = std::sin(yaw);
  const float cr = std::cos(roll), sr = std::sin(roll);
  r[0] = cr * cy;
  r[1] = cr * sy * sp - sr * cp;
  r[2] = cr * sy * cp + sr * sp;
  r[3] = sr * cy;
  r[4] = sr * sy * sp + cr * cp;
  r[5] = sr * sy * cp - cr * sp;
  r[6] = -sy;
  r[7] = cy * sp;
  r[8] = cy * cp;
}

constexpr int kPoints = 24;

}  // namespace

TEST(umeyama_recuperaSimilaridadConocida) {
  std::mt19937 rng(42);
  std::uniform_real_distribution<float> coord(-8.0f, 8.0f);
  std::normal_distribution<float> noise(0.0f, 0.01f);
  float r[9];
  rotationFromEuler(0.2f, -0.4f, 0.1f, r);
  constexpr float kScale = 2.5f;
  const float t[3] = {10.0f, -5.0f, 3.0f};

  float src[kPoints * 3];
  float dst[kPoints * 3];
  int indices[kPoints];
  for (int i = 0; i < kPoints; ++i) {
    indices[i] = i;
    for (int k = 0; k < 3; ++k) src[i * 3 + k] = coord(rng);
    for (int a = 0; a < 3; ++a) {
      const float rotated = r[a * 3] * src[i * 3] + r[a * 3 + 1] * src[i * 3 + 1] + r[a * 3 + 2] * src[i * 3 + 2];
      dst[i * 3 + a] = kScale * rotated + t[a] + noise(rng);
    }
  }
  SimilarityTransform out{};
  CHECK(makeup::solveSimilarity(src, dst, indices, kPoints, &out));
  for (int k = 0; k < 9; ++k) CHECK_NEAR(out.rotation[k], r[k], 2e-3);
  for (int k = 0; k < 3; ++k) CHECK_NEAR(out.translation[k], t[k], 2e-2);
  CHECK_NEAR(out.scale, kScale, 2e-3);

  const makeup::EulerAngles angles = makeup::eulerFromRotation(out.rotation);
  CHECK_NEAR(angles.pitch, 0.2, 2e-3);
  CHECK_NEAR(angles.yaw, -0.4, 2e-3);
  CHECK_NEAR(angles.roll, 0.1, 2e-3);
}

// Rotación grande (casi 180°): el método de cuaterniones no tiene el caso de
// reflexión de la SVD ingenua.
TEST(umeyama_rotacionGrandeYSubconjunto) {
  float r[9];
  rotationFromEuler(0.0f, 3.0f, 0.0f, r);
  float src[kPoints * 3];
  float dst[kPoints * 3];
  for (int i = 0; i < kPoints; ++i) {
    src[i * 3] = static_cast<float>(i % 5);
    src[i * 3 + 1] = static_cast<float>((i * 7) % 11);
    src[i * 3 + 2] = static_cast<float>((i * 3) % 4);
    for (int a = 0; a < 3; ++a) {
      dst[i * 3 + a] = r[a * 3] * src[i * 3] + r[a * 3 + 1] * src[i * 3 + 1] + r[a * 3 + 2] * src[i * 3 + 2];
    }
  }
  // Se corrompe un punto que NO está en el subconjunto: no debe afectar.
  dst[0] += 1000.0f;
  const int subset[] = {3, 5, 8, 13, 17, 21};
  SimilarityTransform out{};
  CHECK(makeup::solveSimilarity(src, dst, subset, 6, &out));
  for (int k = 0; k < 9; ++k) CHECK_NEAR(out.rotation[k], r[k], 1e-4);
  CHECK_NEAR(out.scale, 1.0, 1e-4);
  const float det = out.rotation[0] * (out.rotation[4] * out.rotation[8] - out.rotation[5] * out.rotation[7]) -
                    out.rotation[1] * (out.rotation[3] * out.rotation[8] - out.rotation[5] * out.rotation[6]) +
                    out.rotation[2] * (out.rotation[3] * out.rotation[7] - out.rotation[4] * out.rotation[6]);
  CHECK_NEAR(det, 1.0, 1e-4);
}

TEST(umeyama_degenerado) {
  const float same[9] = {1, 1, 1, 1, 1, 1, 1, 1, 1};
  const int indices[] = {0, 1, 2};
  SimilarityTransform out{};
  CHECK(!makeup::solveSimilarity(same, same, indices, 3, &out));
  CHECK(!makeup::solveSimilarity(same, same, indices, 2, &out));
}
