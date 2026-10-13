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

  // --- Labios (P4; diseño en docs/ar_engine/LIPS.md, shader lips.frag) ---

  // L OKLab del labio si todavía no se midió (valor del informe §5.5).
  static constexpr float kLipsFallbackLightness = 0.55f;
  // Piso de la L medida: el shader divide por ella (sombreado relativo).
  static constexpr float kLipsMinLightness = 0.1f;
  // Orientación (coseno normal·vista) en que el labial empieza y termina de
  // aparecer. De frente el labio está entre 0,77 y 0,99; a 60° de giro la
  // comisura lejana queda en ~0 y se desvanece, la cercana sigue entera.
  static constexpr float kLipsFacingFadeStart = 0.0f;
  static constexpr float kLipsFacingFadeEnd = 0.3f;
  // Desplazamiento del brillo por unidad de dirección de vista (UV canónico):
  // con ~1 cm de radio de curvatura del labio y el labio de ~0,236 UV para
  // ~5 cm, girar 20° corre el reflejo ~0,016 UV. Tope para giros grandes.
  static constexpr float kLipsGlossShiftPerView = 0.045f;
  static constexpr float kLipsGlossShiftMaxUv = 0.02f;
  // Exponente sobre el mapa de brillo por acabado: satinado ancho y suave,
  // brillo chico e intenso. Shimmer usa el del satinado más destellos.
  static constexpr float kLipsSharpnessSatin = 1.5f;
  static constexpr float kLipsSharpnessGloss = 4.0f;
  // El satinado refleja menos que el brillo con el mismo "gloss" de la receta.
  static constexpr float kLipsSatinGlossScale = 0.5f;
  // Intensidad de los destellos de shimmer (relativa a gloss). Celdas, densidad
  // y ritmo están en lips.frag (SPARKLE_*).
  static constexpr float kLipsSparkle = 0.6f;
  // Luz de la escena según la L de las mejillas: solo atenúa el brillo en
  // escenas muy oscuras (L < ~0,25). No más arriba: la L de la piel depende
  // también del tono de piel y no hay que quitarle brillo a las pieles oscuras.
  static constexpr float kLipsLightDarkLightness = 0.10f;
  static constexpr float kLipsLightFullLightness = 0.25f;
  static constexpr float kLipsLightMin = 0.3f;

  // --- Cara y ojos (P5; docs/ar_engine/FACE.md, face_style.cpp) ---

  // Desvanecido por orientación de las pasadas de cara y ojos (como el de los
  // labios). Más permisivo: de frente la mandíbula y las sienes ya están en
  // coseno 0,18-0,45 y con el rango de los labios perdían hasta un 30 %; a 30°
  // de giro el pómulo lejano (coseno ~0-0,2) desaparecía aunque se ve.
  static constexpr float kFaceFacingFadeStart = -0.15f;
  static constexpr float kFaceFacingFadeEnd = 0.1f;

  // Escala de los sigmas del rubor según spread (0 -> mínima, 1 -> máxima).
  static constexpr float kCheekSpreadScaleMin = 0.7f;
  static constexpr float kCheekSpreadScaleMax = 1.4f;
  // Iluminador: cuánto sigue la L de su color (el resto es brillo aditivo,
  // lineal, con opacidad 1 y solo donde hay luz). Con lumaFollow 1 un
  // iluminador crema sobre piel oscura queda como una franja de tiza
  // (grilla de calibración, tools/makeup/calibration_grid.py).
  static constexpr float kHighlightLumaFollow = 0.4f;
  static constexpr float kHighlightShine = 0.16f;
  // Brillo de las sombras satinadas y destellos de las shimmer (con opacidad 1).
  static constexpr float kShadowSatinShine = 0.08f;
  static constexpr float kShadowShimmerSparkle = 0.5f;
  // Delineado en distancia normalizada (kLinerMaxDistanceUv = 1, ~3 mm):
  // grosor con thickness 0 y 1 de la receta, y ancho del borde suave.
  static constexpr float kLinerThicknessMin = 0.12f;
  static constexpr float kLinerThicknessMax = 0.6f;
  static constexpr float kLinerFeather = 0.08f;

  // --- Pestañas (P6; eyes.frag: lashStrands) ---
  // Color de máscara de pestañas (sRGB; la receta no trae color).
  static constexpr float kLashColor[3] = {0.07f, 0.055f, 0.05f};
  // Hebras por ojo y medio ancho en la base (fracción de su celda) con volume
  // 0 y 1: en el E20 el ojo mide ~100-130 px, una hebra por cada 2-5 px.
  static constexpr float kLashCountMin = 22.0f;
  static constexpr float kLashCountMax = 38.0f;
  static constexpr float kLashWidthMin = 0.2f;
  static constexpr float kLashWidthMax = 0.32f;
  // Largo (fracción de kLashMaxLengthUv, ~7 mm) con length 0 y 1. Tope < 0,98:
  // la altura 1 del mapa significa "sin pestañas".
  static constexpr float kLashLengthMin = 0.35f;
  static constexpr float kLashLengthMax = 0.92f;
  // Inclinación hacia afuera en la punta (unidades de posición a lo largo).
  static constexpr float kLashCurl = 0.08f;
  // Oscurecimiento máximo de la raíz (volume 1) y opacidad relativa de las
  // pestañas inferiores.
  static constexpr float kLashRootMax = 0.7f;
  static constexpr float kLowerLashOpacity = 0.45f;

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
