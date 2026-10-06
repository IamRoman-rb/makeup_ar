#include "frame_stats.h"

#include <algorithm>
#include <cmath>

namespace makeup {

namespace {
constexpr float kNsPerMs = 1.0e6f;
}  // namespace

void FrameStats::Window::push(float value) {
  samples[head] = value;
  head = (head + 1) % EngineConfig::kStatsWindow;
  if (count < EngineConfig::kStatsWindow) ++count;
}

void FrameStats::Window::clear() {
  head = 0;
  count = 0;
}

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

float FrameStats::percentile(const Window& window, Samples& scratch, float p) {
  if (window.count == 0) return NAN;
  std::copy_n(window.samples.begin(), window.count, scratch.begin());
  // Percentil por rango más cercano: ceil(p * n) - 1.
  int index = static_cast<int>(std::ceil(p * static_cast<float>(window.count))) - 1;
  index = std::clamp(index, 0, window.count - 1);
  std::nth_element(scratch.begin(), scratch.begin() + index, scratch.begin() + window.count);
  return scratch[index];
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
  out[kStatIntervalP50Ms] = percentile(intervalCopy_, scratch_, 0.50f);
  out[kStatIntervalP95Ms] = percentile(intervalCopy_, scratch_, 0.95f);
  out[kStatCpuP50Ms] = percentile(cpuCopy_, scratch_, 0.50f);
  out[kStatCpuP95Ms] = percentile(cpuCopy_, scratch_, 0.95f);
  out[kStatCameraIntervalP50Ms] = percentile(cameraIntervalCopy_, scratch_, 0.50f);
  out[kStatCameraIntervalP95Ms] = percentile(cameraIntervalCopy_, scratch_, 0.95f);
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
