#include "studio/still_face_locator.h"

#include <algorithm>
#include <cmath>

#include "mesh/canonical_mesh.h"

namespace makeup {

namespace {

constexpr int kNoseTip = 1;
constexpr int kAnchorCount = BlazeFaceDecoder::kAnchorCount;
constexpr int kRegressorFloats = kAnchorCount * BlazeFaceDecoder::kCoordsPerAnchor;

float sigmoid(float logit) {
  const float clamped = std::clamp(logit, -100.0f, 100.0f);
  return 1.0f / (1.0f + std::exp(-clamped));
}

}  // namespace

FacePose measureFacePose(const float* points) {
  // Ojos (ángulos externos) y nariz en el marco de la línea de los ojos.
  const float ax = points[mesh::kEyeLeftInImage * 3];
  const float ay = points[mesh::kEyeLeftInImage * 3 + 1];
  const float bx = points[mesh::kEyeRightInImage * 3];
  const float by = points[mesh::kEyeRightInImage * 3 + 1];
  const float dx = bx - ax;
  const float dy = by - ay;
  FacePose pose;
  pose.eyeDistancePx = std::hypot(dx, dy);
  if (pose.eyeDistancePx > 0.0f) {
    const float nx = points[kNoseTip * 3] - 0.5f * (ax + bx);
    const float ny = points[kNoseTip * 3 + 1] - 0.5f * (ay + by);
    pose.yawRatio = (nx * dx + ny * dy) / (pose.eyeDistancePx * pose.eyeDistancePx);
  }
  return pose;
}

StillFaceStatus facePoseStatus(const FacePose& pose) {
  if (!(pose.eyeDistancePx >= EngineConfig::kStillMinEyeDistancePx)) return StillFaceStatus::kFaceTooSmall;
  if (!(std::fabs(pose.yawRatio) <= EngineConfig::kStillMaxYawRatio)) return StillFaceStatus::kProfile;
  return StillFaceStatus::kOk;
}

void StillFaceLocator::begin(int width, int height) {
  width_ = width;
  height_ = height;
  landmarkPasses_ = 0;
  eyeDistancePx_ = 0.0f;
  yawRatio_ = 0.0f;
  if (width <= 0 || height <= 0) {
    finish(StillFaceStatus::kBadImage);
    return;
  }
  roi_ = letterboxRoi(static_cast<float>(width), static_cast<float>(height));
  step_ = Step::kDetector;
  status_ = StillFaceStatus::kOk;
}

int StillFaceLocator::inputSize() const {
  switch (step_) {
    case Step::kDetector:
      return EngineConfig::kDetectorInputSize;
    case Step::kLandmarks:
      return EngineConfig::kLandmarkInputSize;
    default:
      return 0;
  }
}

bool StillFaceLocator::fillInput(const StillImage& image, float* out, int count, float scale, float offset) const {
  const int size = inputSize();
  if (size == 0 || image.width != width_ || image.height != height_) return false;
  return fillStillTensor(image, roi_, size, scale, offset, out, count);
}

void StillFaceLocator::submitDetections(const float* regressors, int regressorCount, const float* scores,
                                        int scoreCount) {
  if (step_ != Step::kDetector) return;
  if (regressorCount < kRegressorFloats || scoreCount < kAnchorCount) {
    finish(StillFaceStatus::kBadImage);
    return;
  }
  FaceDetection detection;
  if (!decoder_.decode(regressors, scores, EngineConfig::kDetectorMinScore, EngineConfig::kDetectorNmsIou,
                       &detection)) {
    finish(StillFaceStatus::kNoFace);
    return;
  }
  // Igual que TrackingState::submitDetections: el letterbox no rota.
  const Point2 topLeft = roiToImage(roi_, detection.xMin, detection.yMin);
  const Point2 bottomRight = roiToImage(roi_, detection.xMin + detection.width, detection.yMin + detection.height);
  const Point2 eyeA = roiToImage(roi_, detection.keypoints[0], detection.keypoints[1]);
  const Point2 eyeB = roiToImage(roi_, detection.keypoints[2], detection.keypoints[3]);
  const Roi next = roiFromBox(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y, eyeA,
                              eyeB, EngineConfig::kRoiScale);
  if (!next.valid()) {
    finish(StillFaceStatus::kNoFace);
    return;
  }
  roi_ = next;
  step_ = Step::kLandmarks;
}

void StillFaceLocator::submitLandmarks(const float* landmarks, int floatCount, float presenceLogit) {
  if (step_ != Step::kLandmarks) return;
  if (floatCount < kPoints * 3) {
    finish(StillFaceStatus::kBadImage);
    return;
  }
  if (sigmoid(presenceLogit) < EngineConfig::kPresenceThreshold) {
    finish(StillFaceStatus::kLowPresence);
    return;
  }
  for (int i = 0; i < kPoints * 3; ++i) {
    if (!std::isfinite(landmarks[i])) {
      finish(StillFaceStatus::kBadImage);
      return;
    }
  }
  const float inv = 1.0f / static_cast<float>(EngineConfig::kLandmarkInputSize);
  const float zScale = roi_.size * inv;
  for (int i = 0; i < kPoints; ++i) {
    const Point2 p = roiToImage(roi_, landmarks[i * 3] * inv, landmarks[i * 3 + 1] * inv);
    points_[i * 3] = p.x;
    points_[i * 3 + 1] = p.y;
    points_[i * 3 + 2] = landmarks[i * 3 + 2] * zScale;
  }
  ++landmarkPasses_;

  const FacePose pose = measureFacePose(points_.data());
  eyeDistancePx_ = pose.eyeDistancePx;
  yawRatio_ = pose.yawRatio;

  if (landmarkPasses_ < EngineConfig::kStillLandmarkPasses) {
    const Roi next = roiFromPoints(points_.data(), mesh::kVertexCount, 3, mesh::kEyeLeftInImage,
                                   mesh::kEyeRightInImage, EngineConfig::kRoiScale);
    if (next.valid()) {
      roi_ = next;
      return;  // otra pasada de landmarks
    }
  }
  finish(facePoseStatus(pose));
}

void StillFaceLocator::fail(StillFaceStatus status) { finish(status); }

void StillFaceLocator::finish(StillFaceStatus status) {
  status_ = status;
  step_ = status == StillFaceStatus::kOk ? Step::kDone : Step::kFailed;
}

}  // namespace makeup
