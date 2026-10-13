// Regiones de cara y ojos de la receta (P5; docs/ar_engine/FACE.md): estilos
// ya validados (RecipeParams.kt) y su conversión a los valores que usan los
// shaders face.frag / eyes.frag. Sin GL: se prueba en el host.
#pragma once

namespace makeup {

// Mismo orden que las constantes de NativeBridge.kt.
enum class CheekPlacement : int { kApple = 0, kHigh = 1, kLow = 2 };
enum class SkinLayer : int { kFoundation = 0, kContour = 1, kHighlight = 2 };
enum class EyeRegion : int { kLid = 0, kCrease = 1, kOuterV = 2, kInnerCorner = 3, kBrowBone = 4 };
enum class ShadowFinish : int { kMatte = 0, kSatin = 1, kShimmer = 2 };
enum class EffectType : int { kFreckles = 0, kGlitter = 1, kSheen = 2 };
enum class EffectRegion : int { kCheeksNose = 0, kEyes = 1, kLips = 2, kFullFace = 3 };

inline constexpr int kSkinLayerCount = 3;
inline constexpr int kMaxEyeShadows = 4;
inline constexpr int kMaxEffects = 3;
inline constexpr int kEffectTypeCount = 3;

// Un color de la receta con su intensidad (opacidad o coverage).
struct ColorLayer {
  bool enabled = false;
  float r = 0.0f;  // sRGB [0,1]
  float g = 0.0f;
  float b = 0.0f;
  float amount = 0.0f;  // [0,1]
};

struct CheekStyle {
  ColorLayer color;
  float spread = 0.5f;  // [0,1]: tamaño del rubor
  CheekPlacement placement = CheekPlacement::kApple;
};

struct EyeShadowStyle {
  ColorLayer color;
  EyeRegion region = EyeRegion::kLid;
  ShadowFinish finish = ShadowFinish::kMatte;
};

struct LashStyle {
  bool enabled = false;
  float opacity = 0.0f;  // [0,1]
  float length = 0.5f;   // [0,1]
  float volume = 0.5f;   // [0,1]: cantidad y grosor de hebras, raíz más oscura
};

// Efecto procedural de la receta. La región la resuelve Kotlin (por defecto
// según el tipo).
struct EffectStyle {
  bool enabled = false;
  EffectType type = EffectType::kGlitter;
  float intensity = 0.0f;  // [0,1]
  EffectRegion region = EffectRegion::kEyes;
};

struct LinerStyle {
  ColorLayer color;
  float thickness = 0.5f;  // [0,1]
  float wing = 0.0f;       // [0,1]: largo del wing (0 = sin wing)
};

// Uniforms de face.frag. Capas en orden de mezcla: base, contorno, rubor,
// iluminador (ver kFace*).
inline constexpr int kFaceFoundation = 0;
inline constexpr int kFaceContour = 1;
inline constexpr int kFaceCheek = 2;
inline constexpr int kFaceHighlight = 3;
inline constexpr int kFaceLayerCount = 4;

struct FaceUniforms {
  float lab[kFaceLayerCount][3] = {};  // OKLab del color de cada capa
  float amount[kFaceLayerCount] = {};  // 0 = capa apagada
  float lumaFollow[kFaceLayerCount] = {1.0f, 1.0f, 1.0f, 1.0f};  // peso de la L del color
  // UV espejada (u <= 0,5) -> coordenadas de la gaussiana del rubor:
  // g = matrix · uv + offset (column-major, como glUniformMatrix2fv).
  float cheekMatrix[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  float cheekOffset[2] = {0.0f, 0.0f};
  float highlightShine = 0.0f;  // brillo aditivo máximo del iluminador
  // Efectos de la pasada de cara (variante EFFECTS), por EffectType: pecas
  // (opacidad), glitter (brillo de cada destello), sheen (brillo). onSkin = 1
  // si la región es full_face (piel), 0 si es cheeks_nose (canal A).
  float effectAmount[kEffectTypeCount] = {};
  float effectOnSkin[kEffectTypeCount] = {};
  float glitterDensity = 0.0f;
  float freckleDensity = 0.0f;

  bool any() const;
  bool effects() const;
};

// Uniforms de eyes.frag.
struct EyeUniforms {
  float shadowLab[kMaxEyeShadows][3] = {};
  float shadowAmount[kMaxEyeShadows] = {};  // 0 = slot vacío
  // Selector de región por slot: máscara = dot(mapaA, selectA) + mapaB.r · selectB.
  float shadowSelectA[kMaxEyeShadows][4] = {};
  float shadowSelectB[kMaxEyeShadows] = {};
  float shadowShine[kMaxEyeShadows] = {};    // satinado
  float shadowSparkle[kMaxEyeShadows] = {};  // shimmer
  float linerLab[3] = {0.0f, 0.0f, 0.0f};
  float linerAmount = 0.0f;
  // Borde del delineado en distancia normalizada (mesh/eye_maps.h): opaco
  // hasta linerEdge[0], transparente desde linerEdge[1].
  float linerEdge[2] = {0.0f, 0.0f};
  float wing = 0.0f;  // largo del wing [0,1]
  // Pestañas (0 = sin pestañas).
  float lashLab[3] = {0.0f, 0.0f, 0.0f};
  float lashAmount = 0.0f;
  float lowerLashAmount = 0.0f;
  float lashParams[4] = {0.0f, 0.0f, 0.0f, 0.0f};  // hebras, largo, medio ancho, inclinación
  float lashRoot = 0.0f;
  // Efectos en los párpados: glitter (destellos, variante SHIMMER) y sheen.
  float glitter = 0.0f;
  float sheen = 0.0f;
  bool shimmer = false;  // algún slot con shimmer o glitter: variante SHIMMER

  bool any() const;
};

// Color OKLab e intensidad recortada de una capa (0 si está apagada).
void resolveColorLayer(const ColorLayer& layer, float lab[3], float* amount);

// Lo que los efectos le agregan al labial (Renderer::commitRecipe).
struct LipEffects {
  float sparkle = 0.0f;  // destellos (variante SHIMMER de lips.frag)
  float gloss = 0.0f;    // brillo extra
};

// Valores fuera de rango se recortan; región, placement o acabado inválidos
// caen al primero de su enum (Kotlin ya los valida: segunda línea de defensa).
FaceUniforms resolveFace(const ColorLayer skin[kSkinLayerCount], const CheekStyle& cheek);
EyeUniforms resolveEyes(const EyeShadowStyle shadows[kMaxEyeShadows], const LinerStyle& liner,
                        const LashStyle& lashes);
// Reparte los efectos entre las pasadas según la región. Con varios del mismo
// tipo en la misma pasada gana la intensidad mayor; freckles en ojos o labios
// no se dibujan.
void applyEffects(const EffectStyle effects[kMaxEffects], FaceUniforms* face, EyeUniforms* eyes, LipEffects* lips);

}  // namespace makeup
