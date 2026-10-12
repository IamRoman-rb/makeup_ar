#include "blazeface_decoder.h"

#include <algorithm>
#include <cmath>

namespace makeup {

namespace {

// Strides por capa (SsdAnchorsCalculator). Capas consecutivas con el mismo
// stride comparten grilla; cada capa aporta 2 anclas por celda (relación de
// aspecto 1 + escala interpolada), todas de tamaño fijo 1×1.
constexpr int kStrides[] = {8, 16, 16, 16};
constexpr int kAnchorsPerLayer = 2;
constexpr float kScoreClip = 100.0f;

}  // namespace

BlazeFaceDecoder::BlazeFaceDecoder() {
  constexpr int kLayers = static_cast<int>(sizeof(kStrides) / sizeof(kStrides[0]));
  int index = 0;
  int layer = 0;
  while (layer < kLayers) {
    int last = layer;
    while (last < kLayers && kStrides[last] == kStrides[layer]) ++last;
    const int anchorsPerCell = (last - layer) * kAnchorsPerLayer;
    const int grid = (kInputSize + kStrides[layer] - 1) / kStrides[layer];
    for (int y = 0; y < grid; ++y) {
      for (int x = 0; x < grid; ++x) {
        for (int a = 0; a < anchorsPerCell; ++a) {
          anchorX_[index] = (static_cast<float>(x) + 0.5f) / static_cast<float>(grid);
          anchorY_[index] = (static_cast<float>(y) + 0.5f) / static_cast<float>(grid);
          ++index;
        }
      }
    }
    layer = last;
  }
}

BlazeFaceDecoder::Box BlazeFaceDecoder::boxAt(const float* regressors, int index) const {
  const float* raw = regressors + index * kCoordsPerAnchor;
  constexpr float kScale = 1.0f / static_cast<float>(kInputSize);
  const float cx = raw[0] * kScale + anchorX_[index];
  const float cy = raw[1] * kScale + anchorY_[index];
  const float w = raw[2] * kScale;
  const float h = raw[3] * kScale;
  return Box{cx - 0.5f * w, cy - 0.5f * h, cx + 0.5f * w, cy + 0.5f * h};
}

float BlazeFaceDecoder::iou(const Box& a, const Box& b) {
  const float ix = std::max(0.0f, std::min(a.xMax, b.xMax) - std::max(a.xMin, b.xMin));
  const float iy = std::max(0.0f, std::min(a.yMax, b.yMax) - std::max(a.yMin, b.yMin));
  const float inter = ix * iy;
  const float areaA = (a.xMax - a.xMin) * (a.yMax - a.yMin);
  const float areaB = (b.xMax - b.xMin) * (b.yMax - b.yMin);
  const float denominator = areaA + areaB - inter;
  return denominator > 0.0f ? inter / denominator : 0.0f;
}

bool BlazeFaceDecoder::decode(const float* regressors, const float* scores, float minScore,
                              float minIou, FaceDetection* out) {
  int best = -1;
  for (int i = 0; i < kAnchorCount; ++i) {
    const float logit = std::clamp(scores[i], -kScoreClip, kScoreClip);
    const float p = 1.0f / (1.0f + std::exp(-logit));
    probability_[i] = p;
    if (p >= minScore && (best < 0 || p > probability_[best])) best = i;
  }
  if (best < 0) return false;

  // NMS ponderado, solo para la mejor cara: se promedian (por score) todas las
  // candidatas que se superponen con ella.
  const Box bestBox = boxAt(regressors, best);
  float weight = 0.0f;
  float xMin = 0.0f;
  float yMin = 0.0f;
  float xMax = 0.0f;
  float yMax = 0.0f;
  std::array<float, 12> keypoints{};
  constexpr float kScale = 1.0f / static_cast<float>(kInputSize);
  for (int i = 0; i < kAnchorCount; ++i) {
    const float p = probability_[i];
    if (p < minScore) continue;
    const Box box = boxAt(regressors, i);
    if (i != best && iou(box, bestBox) < minIou) continue;
    weight += p;
    xMin += p * box.xMin;
    yMin += p * box.yMin;
    xMax += p * box.xMax;
    yMax += p * box.yMax;
    const float* raw = regressors + i * kCoordsPerAnchor + 4;
    for (int k = 0; k < kKeypointCount; ++k) {
      keypoints[2 * k] += p * (raw[2 * k] * kScale + anchorX_[i]);
      keypoints[2 * k + 1] += p * (raw[2 * k + 1] * kScale + anchorY_[i]);
    }
  }
  const float inv = 1.0f / weight;  // weight >= probability_[best] > 0
  out->score = probability_[best];
  out->xMin = xMin * inv;
  out->yMin = yMin * inv;
  out->width = (xMax - xMin) * inv;
  out->height = (yMax - yMin) * inv;
  for (int k = 0; k < 2 * kKeypointCount; ++k) out->keypoints[k] = keypoints[k] * inv;
  return true;
}

}  // namespace makeup
