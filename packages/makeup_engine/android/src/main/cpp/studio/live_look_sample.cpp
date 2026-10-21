#include "studio/live_look_sample.h"

#include <algorithm>

#include "engine_config.h"
#include "mesh/canonical_mesh.h"
#include "studio/look_analysis.h"
#include "studio/still_face_locator.h"
#include "studio/still_image.h"

namespace makeup {

Roi lookSampleRoi(const float* points) {
  return roiFromPoints(points, mesh::kVertexCount, 3, mesh::kEyeLeftInImage, mesh::kEyeRightInImage,
                       EngineConfig::kLookSampleRoiScale);
}

void landmarksToSample(const Roi& roi, int size, const float* imagePoints, float* out) {
  const float scale = static_cast<float>(size);
  const float zScale = roi.size > 0.0f ? scale / roi.size : 0.0f;
  for (int i = 0; i < EngineConfig::kLandmarkCount; ++i) {
    const Point2 uv = imageToRoi(roi, imagePoints[i * 3], imagePoints[i * 3 + 1]);
    out[i * 3] = uv.x * scale;
    out[i * 3 + 1] = uv.y * scale;
    out[i * 3 + 2] = imagePoints[i * 3 + 2] * zScale;
  }
}

void analyzeLiveSample(const uint8_t* rgba, int size, const float* points, float imageScale, float* out) {
  std::fill(out, out + kLookValueCount, 0.0f);
  FacePose pose = measureFacePose(points);
  pose.eyeDistancePx *= imageScale;
  StillFaceStatus status = facePoseStatus(pose);
  if (status == StillFaceStatus::kOk) {
    // Hilo del analizador (no es camino caliente): puede alocar.
    StillImage image;
    image.width = size;
    image.height = size;
    image.rgba.assign(rgba, rgba + static_cast<size_t>(size) * static_cast<size_t>(size) * 4);
    if (!analyzeLook(image, points, out)) status = StillFaceStatus::kBadImage;
  }
  out[kLookStatus] = static_cast<float>(status);
  out[kLookEyeDistancePx] = pose.eyeDistancePx;
  out[kLookYawRatio] = pose.yawRatio;
}

}  // namespace makeup
