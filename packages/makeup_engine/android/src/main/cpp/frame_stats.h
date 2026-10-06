// Métricas de frame con ventanas circulares preasignadas: record() corre en el
// hilo de render sin allocations; snapshot() se llama desde otro hilo (~2 Hz).
#pragma once

#include <array>
#include <cstdint>
#include <mutex>

#include "engine_config.h"

namespace makeup {

// Orden del arreglo que llena snapshot(). Mismo orden que EngineStats en Dart.
enum StatIndex : int {
  kStatFrames = 0,          // frames dibujados desde el último reset
  kStatIntervalP50Ms,       // intervalo entre frames dibujados
  kStatIntervalP95Ms,
  kStatCpuP50Ms,            // updateTexImage + draw + eglSwapBuffers (CPU, hilo de render)
  kStatCpuP95Ms,
  kStatCameraIntervalP50Ms, // intervalo entre timestamps de cámara (fps real del sensor)
  kStatCameraIntervalP95Ms,
  kStatCount,
};

class FrameStats {
 public:
  // Tiempos en ns de CLOCK_MONOTONIC (System.nanoTime). [cameraTimestampNs] es
  // SurfaceTexture.getTimestamp(); solo se usan sus diferencias.
  void record(int64_t frameStartNs, int64_t frameEndNs, int64_t cameraTimestampNs);

  // Llena [out] con kStatCount valores. Thread-safe.
  void snapshot(float* out);

  void reset();

 private:
  using Samples = std::array<float, EngineConfig::kStatsWindow>;

  struct Window {
    Samples samples{};
    int head = 0;
    int count = 0;

    void push(float value);
    void clear();
  };

  static float percentile(const Window& window, Samples& scratch, float p);

  std::mutex mutex_;  // record() vs copia en snapshot(); se retiene ~1 µs
  Window interval_;
  Window cpu_;
  Window cameraInterval_;

  // Solo snapshot(), bajo snapshotMutex_: los percentiles se calculan sobre
  // copias, fuera de mutex_, para no demorar al hilo de render.
  std::mutex snapshotMutex_;
  Window intervalCopy_;
  Window cpuCopy_;
  Window cameraIntervalCopy_;
  Samples scratch_{};
  int64_t lastFrameEndNs_ = 0;
  int64_t lastCameraNs_ = 0;
  uint64_t frames_ = 0;
};

}  // namespace makeup
