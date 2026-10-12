#include <cmath>
#include <vector>

#include "test_harness.h"
#include "tracking/blazeface_decoder.h"

using makeup::BlazeFaceDecoder;
using makeup::FaceDetection;

TEST(blazeface_anclas) {
  const BlazeFaceDecoder decoder;
  // Grilla 16×16 con 2 anclas por celda, después 8×8 con 6.
  CHECK_NEAR(decoder.anchorX(0), 0.5 / 16, 1e-6);
  CHECK_NEAR(decoder.anchorY(0), 0.5 / 16, 1e-6);
  CHECK_NEAR(decoder.anchorX(1), 0.5 / 16, 1e-6);
  CHECK_NEAR(decoder.anchorX(2), 1.5 / 16, 1e-6);
  CHECK_NEAR(decoder.anchorY(32), 1.5 / 16, 1e-6);  // segunda fila: 16 celdas × 2
  CHECK_NEAR(decoder.anchorX(511), 15.5 / 16, 1e-6);
  CHECK_NEAR(decoder.anchorY(511), 15.5 / 16, 1e-6);
  CHECK_NEAR(decoder.anchorX(512), 0.5 / 8, 1e-6);
  CHECK_NEAR(decoder.anchorX(518), 1.5 / 8, 1e-6);
  CHECK_NEAR(decoder.anchorX(BlazeFaceDecoder::kAnchorCount - 1), 7.5 / 8, 1e-6);
  CHECK_NEAR(decoder.anchorY(BlazeFaceDecoder::kAnchorCount - 1), 7.5 / 8, 1e-6);
}

TEST(blazeface_sinCaraNoDetecta) {
  BlazeFaceDecoder decoder;
  std::vector<float> regressors(BlazeFaceDecoder::kAnchorCount * BlazeFaceDecoder::kCoordsPerAnchor, 0.0f);
  std::vector<float> scores(BlazeFaceDecoder::kAnchorCount, -5.0f);
  FaceDetection out;
  CHECK(!decoder.decode(regressors.data(), scores.data(), 0.5f, 0.3f, &out));
}

// Dos anclas de la misma celda ven la misma cara: el NMS ponderado las
// promedia por score; una tercera lejana con score alto no se mezcla.
TEST(blazeface_detectaYFusiona) {
  BlazeFaceDecoder decoder;
  constexpr int kCoords = BlazeFaceDecoder::kCoordsPerAnchor;
  std::vector<float> regressors(BlazeFaceDecoder::kAnchorCount * kCoords, 0.0f);
  std::vector<float> scores(BlazeFaceDecoder::kAnchorCount, -10.0f);

  const int a = 512 + (4 * 8 + 4) * 6;  // celda (4, 4) de la grilla 8×8: centro (0.5625, 0.5625)
  const int b = a + 1;
  const int far = 0;                    // esquina superior izquierda
  auto setBox = [&](int index, float dx, float dy, float w, float h) {
    float* raw = regressors.data() + index * kCoords;
    raw[0] = dx;
    raw[1] = dy;
    raw[2] = w;
    raw[3] = h;
    raw[4] = -16.0f;  // ojo 0: 16 px a la izquierda del ancla
    raw[5] = -8.0f;
    raw[6] = 16.0f;   // ojo 1
    raw[7] = -8.0f;
  };
  setBox(a, 0.0f, 0.0f, 64.0f, 64.0f);
  setBox(b, 4.0f, 0.0f, 64.0f, 64.0f);
  setBox(far, 0.0f, 0.0f, 8.0f, 8.0f);
  scores[a] = 3.0f;    // p ≈ 0.9526
  scores[b] = 1.0f;    // p ≈ 0.7311
  scores[far] = 2.0f;  // p ≈ 0.8808, no se superpone

  FaceDetection out;
  CHECK(decoder.decode(regressors.data(), scores.data(), 0.5f, 0.3f, &out));
  const double pa = 1.0 / (1.0 + std::exp(-3.0));
  const double pb = 1.0 / (1.0 + std::exp(-1.0));
  CHECK_NEAR(out.score, pa, 1e-5);
  const double cx = 0.5625 + (pb * 4.0 / 128.0) / (pa + pb);
  CHECK_NEAR(out.xMin + out.width * 0.5, cx, 1e-5);
  CHECK_NEAR(out.yMin + out.height * 0.5, 0.5625, 1e-5);
  CHECK_NEAR(out.width, 0.5, 1e-5);
  CHECK_NEAR(out.keypoints[0], 0.5625 - 16.0 / 128.0, 1e-5);
  CHECK_NEAR(out.keypoints[2], 0.5625 + 16.0 / 128.0, 1e-5);
  CHECK_NEAR(out.keypoints[3], 0.5625 - 8.0 / 128.0, 1e-5);
}
