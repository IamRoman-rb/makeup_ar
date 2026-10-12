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

inline constexpr int kSkinLayerCount = 3;
inline constexpr int kMaxEyeShadows = 4;

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
  // UV espejada (u <= 0,5) -> coordenadas de la gaussiana del rubor:
  // g = matrix · uv + offset (column-major, como glUniformMatrix2fv).
  float cheekMatrix[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  float cheekOffset[2] = {0.0f, 0.0f};
  float highlightShine = 0.0f;  // brillo aditivo máximo del iluminador

  bool any() const;
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
  bool shimmer = false;  // algún slot con shimmer: variante SHIMMER

  bool any() const;
};

// Valores fuera de rango se recortan; región, placement o acabado inválidos
// caen al primero de su enum (Kotlin ya los valida: segunda línea de defensa).
FaceUniforms resolveFace(const ColorLayer skin[kSkinLayerCount], const CheekStyle& cheek);
EyeUniforms resolveEyes(const EyeShadowStyle shadows[kMaxEyeShadows], const LinerStyle& liner);

}  // namespace makeup
