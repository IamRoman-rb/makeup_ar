// Único lugar para las constantes de rendimiento del motor (ver
// .claude/rules/native-gles.md). Kotlin las lee vía NativeBridge.nativeGetConfig()
// para no duplicarlas.
#pragma once

#include <cstdint>

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

  // Delineado de labios: borde (distancia normalizada por
  // kLipLinerMaxDistanceUv, ~1,7 mm) hasta donde es opaco; la receta no trae
  // grosor. 0,22 ≈ un trazo de ~0,8 mm centrado en el borde del labial.
  static constexpr float kLipLinerEdge = 0.22f;

  // Oclusión del labial (P7, tracking/lip_occlusion.h). Cromaticidad en
  // (a, b) / L de OKLab: una piel clara ronda (0,05, 0,07) y un labio
  // (0,15, 0,07), ~0,1 de distancia; un labio pálido, ~0,035.
  // Muestras de labio con cromaticidad necesarias para decidir (de 36).
  static constexpr int kOcclusionMinSamples = 12;
  // Contraste piel-labio mínimo: con menos no se distingue una mano del labio.
  static constexpr float kOcclusionMinContrast = 0.03f;
  // Una muestra con p (0 piel, 1 labio) debajo de esto se cuenta tapada.
  static constexpr float kOcclusionSampleThreshold = 0.4f;
  // Fracción de muestras tapadas en que la compuerta empieza y termina de
  // prenderse: 2 de 36 (un reflejo, un pliegue) no la prenden; un dedo sobre
  // un tercio del labio la prende entera.
  static constexpr float kOcclusionGateLow = 0.08f;
  static constexpr float kOcclusionGateHigh = 0.3f;
  // Suavizado por inferencia (14 Hz): sube en ~2 inferencias, baja en ~4.
  static constexpr float kOcclusionGateAttack = 0.6f;
  static constexpr float kOcclusionGateRelease = 0.3f;
  // Compuerta por debajo de esto: 0 (el shader no hace nada).
  static constexpr float kOcclusionGateFloor = 0.02f;
  // El labio de referencia se aprende solo con a lo sumo esta fracción tapada;
  // sube rápido (labio más lejos de la piel) y baja lento.
  static constexpr float kOcclusionLearnMaxFraction = 0.05f;
  static constexpr float kOcclusionLearnRise = 0.5f;
  static constexpr float kOcclusionLearnFall = 0.05f;
  // Luz quemada (P8): con algún canal sRGB >= esto la croma se lava hacia la
  // de la piel (el rojo satura) y el labio parecía una mano. Esas muestras no
  // cuentan (ni tapadas ni labio). El shader hace lo mismo por píxel con
  // OCCLUSION_CLIP_LOW/HIGH (lips.frag).
  static constexpr float kOcclusionClipValue = 0.94f;

  // Adaptación al color de la luz (P7, scene_light.h / scene_pass.h).
  // Miniatura de la cámara: lado en px y cada cuánto se lee (1 KB por lectura).
  static constexpr int kScenePassSize = 16;
  static constexpr int64_t kScenePassIntervalNs = 500000000;  // 0,5 s
  // Píxeles que no cuentan para el gray-world: un canal >= este valor sRGB
  // (quemado) o luminancia lineal menor que el mínimo (casi negro). Con menos
  // de kLightAdaptMinFraction de píxeles útiles no se actualiza.
  static constexpr int kLightAdaptClippedValue = 250;
  static constexpr float kLightAdaptMinLuminance = 0.01f;
  static constexpr float kLightAdaptMinFraction = 0.25f;
  // Margen alrededor del rectángulo de la cara que tampoco cuenta (pelo,
  // cuello), en fracción de su lado.
  static constexpr float kLightAdaptFaceMargin = 0.15f;
  // Grado de adaptación: 0 = maquillaje neutro, 1 = toma todo el tinte
  // medio de la escena (gray-world se equivoca con escenas de un solo color:
  // un sillón azul). Tope de la ganancia por canal.
  static constexpr float kLightAdaptDegree = 0.5f;
  static constexpr float kLightAdaptGainMin = 0.85f;
  static constexpr float kLightAdaptGainMax = 1.18f;
  // Suavizado por lectura (2 por segundo: ~1 s) y cambio mínimo de ganancia
  // para volver a adaptar los colores de la receta.
  static constexpr float kLightAdaptSmoothing = 0.4f;
  static constexpr float kLightAdaptEpsilon = 0.004f;

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

  // --- Efectos procedurales (P6; face.frag/eyes.frag/lips.frag) ---
  // Glitter: brillo de cada destello con intensity 1 y probabilidad de que una
  // celda brille con intensity 0 y 1.
  static constexpr float kGlitterSparkle = 0.9f;
  static constexpr float kGlitterDensityMin = 0.03f;
  static constexpr float kGlitterDensityMax = 0.12f;
  // Sheen: aclarado relativo (la luz lineal × (1 + gain)) con intensity 1,
  // solo en las zonas más iluminadas que la piel media. Relativo y no aditivo:
  // un brillo sumado dejaba un velo gris sobre la piel oscura (grilla).
  static constexpr float kSheenGain = 0.35f;
  // En los labios el sheen suma brillo al mapa de brillo del labial.
  static constexpr float kLipSheenGloss = 0.35f;
  // Pecas: opacidad con intensity 1 y probabilidad por celda con intensity 0
  // y 1. El color (piel × FRECKLE_SCALE) y el tamaño de las celdas son de
  // aspecto y están en face.frag.
  static constexpr float kFreckleOpacity = 0.75f;
  static constexpr float kFreckleDensityMin = 0.12f;
  static constexpr float kFreckleDensityMax = 0.42f;

  // Tamaño de los puntos del overlay de depuración (px de salida).
  static constexpr float kLandmarkPointSizePx = 5.0f;

  // --- Imagen -> receta (F4; docs/ar_engine/F4_PLAN.md, cpp/studio/) ---
  // No es camino caliente: una foto por análisis, en el hilo del analizador.
  // Lado máximo de la foto (px): Kotlin la reduce antes de pasarla.
  static constexpr int kStillMaxSide = 1280;
  // Supersampling máximo por eje al recortar la foto para los modelos.
  static constexpr int kStillMaxTaps = 8;
  // Pasadas de landmarks: la segunda con el ROI de los landmarks de la primera
  // (el del detector es más flojo).
  static constexpr int kStillLandmarkPasses = 2;
  // Cara mínima: distancia entre los ángulos externos de los ojos (px).
  static constexpr float kStillMinEyeDistancePx = 60.0f;
  // Perfil: desplazamiento de la punta de la nariz respecto del medio de los
  // ojos, en distancias entre ojos (de frente ~0; a ~30° de giro, ~0,2).
  static constexpr float kStillMaxYawRatio = 0.22f;
  // Triángulos vistos de costado: área en la foto menor que esta fracción de
  // la mediana (en relación con su área UV) no se muestrean.
  static constexpr float kStillMinTriangleAreaRatio = 0.25f;
  // Muestreo robusto (tools/studio/sample_region_reference.py): se descartan
  // las L más altas (brillo) y más bajas (sombra) antes de la mediana.
  static constexpr float kSampleDropHigh = 0.08f;
  static constexpr float kSampleDropLow = 0.05f;
  // gloss_score: fracción de muestras con L > mediana + delta, sobre fullAt.
  static constexpr float kGlossHighDelta = 0.12f;
  static constexpr float kGlossFullAt = 0.06f;
  // Un texel cuenta en una región si su máscara vale al menos esto.
  static constexpr float kRegionMaskThreshold = 0.5f;
  // Muestras mínimas para que una región sea válida.
  static constexpr int kRegionMinSamples = 24;
  // Radio (UV) de los parches de piel base alrededor de cada landmark.
  static constexpr float kSkinPatchRadiusUv = 0.02f;
  // Sombras: solo texels a esta distancia normalizada (canal B.g) o más de la
  // línea de pestañas, para no mezclar el delineado.
  static constexpr float kShadowMinLinerDistance = 0.75f;
  // Delineado: franjas de distancia a la línea de pestañas (B.g en [0, 1]) y
  // de avance del wing (B.a). Un texel es oscuro con L por debajo de
  // min(piel, párpado) - delta; una franja es de delineado si lo es al menos
  // esta fracción de sus texels.
  static constexpr int kLinerBands = 20;
  static constexpr int kWingBands = 10;
  static constexpr float kLinerDarkDelta = 0.12f;
  static constexpr float kLinerDarkFraction = 0.5f;
  // Distancia al wing (B.b) que cuenta como wing aunque el delineado medido
  // sea más fino.
  static constexpr float kWingMinDistance = 0.2f;
  // Paleta de producto (§10.6): lado máximo de la miniatura, clusters,
  // iteraciones de K-means, distancia OKLab al fondo (mediana del borde) que
  // se descarta, salto con un vecino que marca un píxel de borde (mezcla de
  // dos colores), blancos casi puros (L y croma), clusters que se unen y
  // fracción mínima de un swatch.
  static constexpr int kPaletteMaxSide = 96;
  static constexpr int kPaletteClusters = 5;
  static constexpr int kPaletteIterations = 12;
  static constexpr float kPaletteBackgroundDelta = 0.05f;
  static constexpr float kPaletteEdgeDelta = 0.06f;
  static constexpr float kPaletteWhiteLightness = 0.96f;
  static constexpr float kPaletteWhiteChroma = 0.02f;
  static constexpr float kPaletteMergeDelta = 0.03f;
  static constexpr float kPaletteMinFraction = 0.03f;
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
  kConfigStillMaxSide,
  kConfigLookValueCount,
  kConfigCount,
};

}  // namespace makeup
