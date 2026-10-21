// Guía de maquillaje (studio/live_look_sample.h): el recorte de la cara y sus
// landmarks miden lo mismo que la foto entera (studio_synthetic.h).
#include <cmath>
#include <cstdint>
#include <vector>

#include "color_math.h"
#include "engine_config.h"
#include "studio/live_look_sample.h"
#include "studio/look_analysis.h"
#include "studio/still_face_locator.h"
#include "studio/still_image.h"
#include "studio_synthetic.h"
#include "test_harness.h"

namespace {

constexpr int kSampleSize = makeup::EngineConfig::kLookSampleSize;

// Lo que hace LookSamplePass en GPU, en CPU: el ROI de la cara a kSampleSize².
std::vector<uint8_t> cropLike(const makeup::StillImage& image, const makeup::Roi& roi) {
  std::vector<uint8_t> rgba(static_cast<size_t>(kSampleSize) * kSampleSize * 4);
  for (int row = 0; row < kSampleSize; ++row) {
    for (int col = 0; col < kSampleSize; ++col) {
      const makeup::Point2 p = makeup::roiToImage(roi, (col + 0.5f) / kSampleSize, (row + 0.5f) / kSampleSize);
      float rgb[3];
      makeup::sampleStill(image, p.x, p.y, rgb);
      uint8_t* out = rgba.data() + (static_cast<size_t>(row) * kSampleSize + col) * 4;
      for (int c = 0; c < 3; ++c) out[c] = static_cast<uint8_t>(std::lround(rgb[c] * 255.0f));
      out[3] = 255;
    }
  }
  return rgba;
}

std::vector<float> sampleAndAnalyze(const synthetic::Look& look) {
  const makeup::StillImage image = synthetic::photo(look);
  const std::vector<float> points = synthetic::landmarks();
  const makeup::Roi roi = makeup::lookSampleRoi(points.data());
  CHECK(roi.valid());
  const std::vector<uint8_t> rgba = cropLike(image, roi);
  std::vector<float> samplePoints(points.size());
  makeup::landmarksToSample(roi, kSampleSize, points.data(), samplePoints.data());
  std::vector<float> values(makeup::kLookValueCount, -1.0f);
  makeup::analyzeLiveSample(rgba.data(), kSampleSize, samplePoints.data(), roi.size / kSampleSize, values.data());
  return values;
}

}  // namespace

TEST(muestraEnVivo_landmarksAlRecorteYDeVuelta) {
  const std::vector<float> points = synthetic::landmarks();
  const makeup::Roi roi = makeup::lookSampleRoi(points.data());
  std::vector<float> sample(points.size());
  makeup::landmarksToSample(roi, kSampleSize, points.data(), sample.data());
  for (int i = 0; i < makeup::EngineConfig::kLandmarkCount; ++i) {
    const makeup::Point2 back =
        makeup::roiToImage(roi, sample[i * 3] / kSampleSize, sample[i * 3 + 1] / kSampleSize);
    CHECK(std::fabs(back.x - points[i * 3]) < 0.05f);
    CHECK(std::fabs(back.y - points[i * 3 + 1]) < 0.05f);
    // La cara entra en el recorte (con margen).
    CHECK(sample[i * 3] > 0.0f && sample[i * 3] < kSampleSize);
    CHECK(sample[i * 3 + 1] > 0.0f && sample[i * 3 + 1] < kSampleSize);
  }
}

TEST(muestraEnVivo_mideLoPintado) {
  synthetic::Look look;
  // En el recorte de 512 la cara mide ~360 px (como en la cámara frontal a
  // 720p): un delineado de 0,3 queda en ~1,3 px y no se distingue. La guía
  // pide acercarse para juzgar el delineado (COACH.md); acá, uno visible.
  look.linerDistance = 0.7f;
  const std::vector<float> values = sampleAndAnalyze(look);
  CHECK(values[makeup::kLookStatus] == static_cast<float>(makeup::StillFaceStatus::kOk));
  // En px de la foto, no del recorte: la misma que mide "Desde foto".
  const std::vector<float> points = synthetic::landmarks();
  const float photoEyes = makeup::measureFacePose(points.data()).eyeDistancePx;
  CHECK(std::fabs(values[makeup::kLookEyeDistancePx] - photoEyes) < 0.5f);
  CHECK(values[makeup::kLookLips + makeup::kRegionValid] == 1.0f);
  const makeup::Vec3 lips{values[makeup::kLookLips + makeup::kRegionL], values[makeup::kLookLips + makeup::kRegionA],
                          values[makeup::kLookLips + makeup::kRegionB]};
  CHECK(makeup::deltaE(lips, makeup::srgbToOklab(look.lip[0], look.lip[1], look.lip[2])) < 0.03f);
  // El delineado y el wing pintados se ven.
  CHECK(values[makeup::kLookLinerExtent] > 0.1f);
  CHECK(values[makeup::kLookWingExtent] > 0.2f);
}

TEST(muestraEnVivo_caraChicaOGiradaNoMide) {
  // Cara lejos: en el recorte se ve igual, pero en px de cámara los ojos
  // quedan a menos de kStillMinEyeDistancePx.
  std::vector<float> points = synthetic::landmarks();
  const makeup::Roi roi = makeup::lookSampleRoi(points.data());
  std::vector<float> sample(points.size());
  makeup::landmarksToSample(roi, kSampleSize, points.data(), sample.data());
  std::vector<uint8_t> rgba(static_cast<size_t>(kSampleSize) * kSampleSize * 4, 128);
  std::vector<float> values(makeup::kLookValueCount, -1.0f);
  makeup::analyzeLiveSample(rgba.data(), kSampleSize, sample.data(), 0.05f, values.data());
  CHECK(values[makeup::kLookStatus] == static_cast<float>(makeup::StillFaceStatus::kFaceTooSmall));
  CHECK(values[makeup::kLookLips + makeup::kRegionValid] == 0.0f);

  // Nariz corrida (cara de perfil).
  points = synthetic::landmarks();
  const makeup::FacePose pose = makeup::measureFacePose(points.data());
  points[1 * 3] += pose.eyeDistancePx * (makeup::EngineConfig::kStillMaxYawRatio + 0.1f);
  makeup::analyzeLiveSample(rgba.data(), kSampleSize, points.data(), 1.0f, values.data());
  CHECK(values[makeup::kLookStatus] == static_cast<float>(makeup::StillFaceStatus::kProfile));
}
