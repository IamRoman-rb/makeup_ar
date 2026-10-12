#include "umeyama.h"

#include <cmath>

namespace makeup {

namespace {

constexpr int kJacobiMaxSweeps = 32;
constexpr double kDegenerateVariance = 1e-12;

// Autovalores/autovectores de una matriz simétrica 4×4 (Jacobi cíclico).
// [a] se destruye; [v] queda con los autovectores en columnas.
void jacobiEigen4(double a[4][4], double v[4][4], double eigenvalues[4]) {
  for (int i = 0; i < 4; ++i) {
    for (int j = 0; j < 4; ++j) v[i][j] = i == j ? 1.0 : 0.0;
  }
  for (int sweep = 0; sweep < kJacobiMaxSweeps; ++sweep) {
    double offDiagonal = 0.0;
    for (int p = 0; p < 4; ++p) {
      for (int q = p + 1; q < 4; ++q) offDiagonal += a[p][q] * a[p][q];
    }
    if (offDiagonal < 1e-24) break;
    for (int p = 0; p < 4; ++p) {
      for (int q = p + 1; q < 4; ++q) {
        if (std::fabs(a[p][q]) < 1e-300) continue;
        const double theta = (a[q][q] - a[p][p]) / (2.0 * a[p][q]);
        const double t = (theta >= 0.0 ? 1.0 : -1.0) /
                         (std::fabs(theta) + std::sqrt(theta * theta + 1.0));
        const double c = 1.0 / std::sqrt(t * t + 1.0);
        const double s = t * c;
        for (int k = 0; k < 4; ++k) {
          const double akp = a[k][p];
          const double akq = a[k][q];
          a[k][p] = c * akp - s * akq;
          a[k][q] = s * akp + c * akq;
        }
        for (int k = 0; k < 4; ++k) {
          const double apk = a[p][k];
          const double aqk = a[q][k];
          a[p][k] = c * apk - s * aqk;
          a[q][k] = s * apk + c * aqk;
        }
        for (int k = 0; k < 4; ++k) {
          const double vkp = v[k][p];
          const double vkq = v[k][q];
          v[k][p] = c * vkp - s * vkq;
          v[k][q] = s * vkp + c * vkq;
        }
      }
    }
  }
  for (int i = 0; i < 4; ++i) eigenvalues[i] = a[i][i];
}

}  // namespace

bool solveSimilarity(const float* src, const float* dst, const int* indices, const float* weights,
                     int count, SimilarityTransform* out) {
  if (count < 3) return false;
  double totalWeight = 0.0;
  double ms[3] = {0, 0, 0};
  double md[3] = {0, 0, 0};
  for (int n = 0; n < count; ++n) {
    const int i = indices[n] * 3;
    const double w = weights != nullptr ? weights[n] : 1.0;
    totalWeight += w;
    for (int k = 0; k < 3; ++k) {
      ms[k] += w * src[i + k];
      md[k] += w * dst[i + k];
    }
  }
  if (totalWeight <= 0.0) return false;
  for (int k = 0; k < 3; ++k) {
    ms[k] /= totalWeight;
    md[k] /= totalWeight;
  }

  // Covarianza cruzada ponderada S[a][b] = Σ w · src'_a · dst'_b y varianzas.
  double s[3][3] = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}};
  double srcVariance = 0.0;
  double dstVariance = 0.0;
  for (int n = 0; n < count; ++n) {
    const int i = indices[n] * 3;
    const double w = weights != nullptr ? weights[n] : 1.0;
    double ps[3];
    double pd[3];
    for (int k = 0; k < 3; ++k) {
      ps[k] = src[i + k] - ms[k];
      pd[k] = dst[i + k] - md[k];
      srcVariance += w * ps[k] * ps[k];
      dstVariance += w * pd[k] * pd[k];
    }
    for (int a = 0; a < 3; ++a) {
      for (int b = 0; b < 3; ++b) s[a][b] += w * ps[a] * pd[b];
    }
  }
  if (srcVariance < kDegenerateVariance || dstVariance < kDegenerateVariance) return false;

  const double sxx = s[0][0], sxy = s[0][1], sxz = s[0][2];
  const double syx = s[1][0], syy = s[1][1], syz = s[1][2];
  const double szx = s[2][0], szy = s[2][1], szz = s[2][2];
  double n4[4][4] = {
      {sxx + syy + szz, syz - szy, szx - sxz, sxy - syx},
      {syz - szy, sxx - syy - szz, sxy + syx, szx + sxz},
      {szx - sxz, sxy + syx, -sxx + syy - szz, syz + szy},
      {sxy - syx, szx + sxz, syz + szy, -sxx - syy + szz},
  };
  double vectors[4][4];
  double values[4];
  jacobiEigen4(n4, vectors, values);
  int best = 0;
  for (int i = 1; i < 4; ++i) {
    if (values[i] > values[best]) best = i;
  }
  double qw = vectors[0][best];
  double qx = vectors[1][best];
  double qy = vectors[2][best];
  double qz = vectors[3][best];
  const double norm = std::sqrt(qw * qw + qx * qx + qy * qy + qz * qz);
  qw /= norm;
  qx /= norm;
  qy /= norm;
  qz /= norm;

  const double r[9] = {
      1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qw * qz),     2 * (qx * qz + qw * qy),
      2 * (qx * qy + qw * qz),     1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qw * qx),
      2 * (qx * qz - qw * qy),     2 * (qy * qz + qw * qx),     1 - 2 * (qx * qx + qy * qy),
  };
  // Escala de Umeyama: tr(R^T S^T) / var(src) = Σ w · dst' · R src' / Σ w · |src'|².
  double dot = 0.0;
  for (int a = 0; a < 3; ++a) {
    for (int b = 0; b < 3; ++b) dot += r[a * 3 + b] * s[b][a];
  }
  const double scale = dot / srcVariance;

  for (int k = 0; k < 9; ++k) out->rotation[k] = static_cast<float>(r[k]);
  for (int a = 0; a < 3; ++a) {
    const double rotated = r[a * 3] * ms[0] + r[a * 3 + 1] * ms[1] + r[a * 3 + 2] * ms[2];
    out->translation[a] = static_cast<float>(md[a] - scale * rotated);
  }
  out->scale = static_cast<float>(scale);
  return true;
}

EulerAngles eulerFromRotation(const float rotation[9]) {
  const float r20 = rotation[6];
  const float clamped = r20 > 1.0f ? 1.0f : (r20 < -1.0f ? -1.0f : r20);
  return EulerAngles{
      std::atan2(rotation[7], rotation[8]),
      std::asin(-clamped),
      std::atan2(rotation[3], rotation[0]),
  };
}

}  // namespace makeup
