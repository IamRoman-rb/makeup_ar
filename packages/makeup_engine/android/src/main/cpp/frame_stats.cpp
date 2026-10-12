#include "frame_stats.h"

namespace makeup {

namespace {
constexpr float kNsPerMs = 1.0e6f;
}  // namespace

void FrameStats::record(int64_t frameStartNs, int64_t frameEndNs, int64_t cameraTimestampNs) {
  std::lock_guard<std::mutex> lock(mutex_);
  ++frames_;
  cpu_.push(static_cast<float>(frameEndNs - frameStartNs) / kNsPerMs);
  if (lastFrameEndNs_ > 0) {
    interval_.push(static_cast<float>(frameEndNs - lastFrameEndNs_) / kNsPerMs);
  }
  lastFrameEndNs_ = frameEndNs;
  // Un timestamp repetido (mismo buffer) o hacia atrás no es un intervalo válido.
  if (lastCameraNs_ > 0 && cameraTimestampNs > lastCameraNs_) {
    cameraInterval_.push(static_cast<float>(cameraTimestampNs - lastCameraNs_) / kNsPerMs);
  }
  if (cameraTimestampNs > 0) lastCameraNs_ = cameraTimestampNs;
}

void FrameStats::snapshot(float* out) {
  std::lock_guard<std::mutex> snapshotLock(snapshotMutex_);
  uint64_t frames = 0;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    frames = frames_;
    intervalCopy_ = interval_;
    cpuCopy_ = cpu_;
    cameraIntervalCopy_ = cameraInterval_;
  }
  out[kStatFrames] = static_cast<float>(frames);
  out[kStatIntervalP50Ms] = intervalCopy_.percentile(scratch_, 0.50f);
  out[kStatIntervalP95Ms] = intervalCopy_.percentile(scratch_, 0.95f);
  out[kStatCpuP50Ms] = cpuCopy_.percentile(scratch_, 0.50f);
  out[kStatCpuP95Ms] = cpuCopy_.percentile(scratch_, 0.95f);
  out[kStatCameraIntervalP50Ms] = cameraIntervalCopy_.percentile(scratch_, 0.50f);
  out[kStatCameraIntervalP95Ms] = cameraIntervalCopy_.percentile(scratch_, 0.95f);
}

void FrameStats::reset() {
  std::lock_guard<std::mutex> lock(mutex_);
  interval_.clear();
  cpu_.clear();
  cameraInterval_.clear();
  lastFrameEndNs_ = 0;
  lastCameraNs_ = 0;
  frames_ = 0;
}

}  // namespace makeup
