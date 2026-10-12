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

  // --- Tracker (informe §5.2–5.3; diseño en docs/ar_engine/TRACKER.md) ---

  // Lado del tensor de entrada de cada modelo (px). Los fija el modelo.
  static constexpr int kDetectorInputSize = 128;
  static constexpr int kLandmarkInputSize = 256;
  // Puntos de FaceMesh-V2: 468 de la malla + 10 de iris.
  static constexpr int kLandmarkCount = 478;

  // Tasa máxima de recortes: landmarks con cara, detector buscándola.
  static constexpr float kTrackerMaxHz = 20.0f;
  static constexpr float kDetectorMaxHz = 10.0f;

  // Supersampling por eje al recortar (taps² lecturas por píxel): el detector
  // reduce el frame ~10x y sin esto se alía.
  static constexpr int kDetectorTaps = 4;
  static constexpr int kLandmarkTaps = 2;

  // Si el readback no terminó en esta cantidad de frames, se descarta.
  static constexpr int kCropTimeoutFrames = 10;

  // Umbrales (valores de MediaPipe).
  static constexpr float kDetectorMinScore = 0.5f;
  static constexpr float kDetectorNmsIou = 0.3f;
  static constexpr float kPresenceThreshold = 0.5f;
  // Lado del ROI = lado de la caja de la cara × esta escala.
  static constexpr float kRoiScale = 1.5f;

  // One Euro sobre cada coordenada, en px de imagen (a ajustar en el E20).
  static constexpr float kOneEuroMinCutoff = 1.0f;
  static constexpr float kOneEuroBeta = 0.05f;
  static constexpr float kOneEuroDCutoff = 1.0f;
  // Más que esto entre resultados (o tras perder la cara): filtros desde cero.
  static constexpr float kFilterResetGapSeconds = 0.5f;

  // Extrapolación entre inferencias: hasta 1,5 intervalos (§5.3.3).
  static constexpr float kExtrapolationMaxIntervals = 1.5f;
  // Fundido del maquillaje al aparecer o perder la cara (§5.3.4).
  static constexpr float kFadeSeconds = 0.15f;
  // Suavizado (EMA por resultado, 0..1) de la L medida de labio y piel:
  // 0,3 ≈ media de los últimos ~3 resultados (~0,2 s a 15 Hz).
  static constexpr float kAppearanceSmoothing = 0.3f;

  // Máscara de región (labios) a 1/N de la resolución de salida: el filtrado
  // lineal al ampliarla da el borde suave.
  static constexpr int kMaskDownscale = 4;
  // Tamaño de los puntos del overlay de depuración (px de salida).
  static constexpr float kLandmarkPointSizePx = 5.0f;
};

// Orden del arreglo que devuelve nativeGetConfig().
enum ConfigIndex : int {
  kConfigMaxPreviewLongSide = 0,
  kConfigMaxPreviewShortSide,
  kConfigTargetFps,
  kConfigStatsWindow,
  kConfigDetectorInputSize,
  kConfigLandmarkInputSize,
  kConfigLandmarkCount,
  kConfigCount,
};

}  // namespace makeup
