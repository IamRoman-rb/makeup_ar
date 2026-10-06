// Único lugar para las constantes de rendimiento del motor (ver
// .claude/rules/native-gles.md). Kotlin las lee vía NativeBridge.nativeGetConfig()
// para no duplicarlas.
#pragma once

namespace makeup {

struct EngineConfig {
  // Stream de cámara para el compositor: lado largo y corto máximos (en la
  // orientación del sensor). Se elige el tamaño de mayor área que entre.
  static constexpr int kMaxPreviewLongSide = 1280;
  static constexpr int kMaxPreviewShortSide = 720;

  // FPS objetivo del rango de AE de la cámara (se busca un rango [x, 30]).
  static constexpr int kTargetFps = 30;

  // Cantidad de muestras para los percentiles p50/p95 (~8,5 s a 30 fps).
  static constexpr int kStatsWindow = 256;
};

// Orden del arreglo que devuelve nativeGetConfig().
enum ConfigIndex : int {
  kConfigMaxPreviewLongSide = 0,
  kConfigMaxPreviewShortSide,
  kConfigTargetFps,
  kConfigStatsWindow,
  kConfigCount,
};

}  // namespace makeup
