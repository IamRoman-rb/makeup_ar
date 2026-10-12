// Decodificador del detector de caras de corto alcance (BlazeFace, entrada
// 128×128) de MediaPipe: anclas SSD + regresión + NMS ponderado.
//
// Configuración tomada de face_detection_short_range de MediaPipe
// (SsdAnchorsCalculator y TensorsToDetectionsCalculator): 4 capas, strides
// {8, 16, 16, 16}, 2 anclas por capa, anclas de tamaño fijo -> 896 anclas.
// Salidas del modelo: regresores 896×16 (caja cx, cy, w, h + 6 puntos x, y, en
// px del tensor) y scores 896×1 (logits).
//
// Sin allocations después del constructor: decode() trabaja sobre memoria propia.
#pragma once

#include <array>

namespace makeup {

struct FaceDetection {
  float score = 0.0f;
  // Caja y puntos en [0,1] del tensor de entrada (espacio "recorte" del Roi).
  float xMin = 0.0f;
  float yMin = 0.0f;
  float width = 0.0f;
  float height = 0.0f;
  // 0 y 1: ojos (0 a la izquierda de la imagen con la cara derecha), 2: nariz,
  // 3: boca, 4 y 5: tragos.
  std::array<float, 12> keypoints{};
};

class BlazeFaceDecoder {
 public:
  static constexpr int kAnchorCount = 896;
  static constexpr int kCoordsPerAnchor = 16;
  static constexpr int kKeypointCount = 6;
  static constexpr int kInputSize = 128;

  BlazeFaceDecoder();

  // [regressors]: kAnchorCount × kCoordsPerAnchor; [scores]: kAnchorCount logits.
  // Devuelve true y llena [out] con la cara de mayor score (fusionada con las
  // que se le superponen, NMS ponderado) si alguna supera [minScore].
  bool decode(const float* regressors, const float* scores, float minScore, float minIou,
              FaceDetection* out);

  // Centro del ancla [index] en [0,1] (para tests).
  float anchorX(int index) const { return anchorX_[index]; }
  float anchorY(int index) const { return anchorY_[index]; }

 private:
  struct Box {
    float xMin;
    float yMin;
    float xMax;
    float yMax;
  };

  Box boxAt(const float* regressors, int index) const;
  static float iou(const Box& a, const Box& b);

  std::array<float, kAnchorCount> anchorX_{};
  std::array<float, kAnchorCount> anchorY_{};
  std::array<float, kAnchorCount> probability_{};
};

}  // namespace makeup
