// Pose rígida con escala (similaridad) entre dos nubes de puntos 3D: encuentra
// s, R, t que minimizan Σ w_i · |dst_i - (s·R·src_i + t)|² (Umeyama 1991).
//
// La rotación se resuelve con el método de cuaterniones de Horn (1987): el
// autovector de mayor autovalor de una matriz simétrica 4×4 (Jacobi). Da el
// mismo óptimo que Umeyama por SVD y siempre una rotación propia (det = +1),
// sin el caso de reflexión. Sin allocations: todo en la pila.
#pragma once

namespace makeup {

struct SimilarityTransform {
  float rotation[9];     // fila mayor: rotation[row * 3 + col]
  float translation[3];
  float scale;
};

// Ángulos en radianes con la convención R = Rz(roll) · Ry(yaw) · Rx(pitch).
struct EulerAngles {
  float pitch;
  float yaw;
  float roll;
};

// [src] y [dst]: puntos xyz contiguos (stride 3). Usa solo los [count] índices
// de [indices] (deben ser >= 3 y no colineales), con [weights] (uno por índice,
// >= 0) o pesos 1 si es nullptr. Devuelve false si el problema es degenerado
// (nubes de varianza ~0 o pesos nulos).
bool solveSimilarity(const float* src, const float* dst, const int* indices, const float* weights,
                     int count, SimilarityTransform* out);

EulerAngles eulerFromRotation(const float rotation[9]);

}  // namespace makeup
