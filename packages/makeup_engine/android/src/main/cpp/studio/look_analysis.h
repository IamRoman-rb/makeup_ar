// Medidas de un look sobre una foto ya con landmarks (F4; docs/ar_engine/F4_PLAN.md).
//
// Rectifica la foto a los tres mapas del motor (labios, cara y ojos) y mide
// con sus máscaras: piel base, labios, delineado de labios, rubor (el
// placement que más se aparta de la piel), sombras por región, delineado de
// ojos (grosor) y wing (largo). Solo números: la receta la arma Dart
// (lib/features/studio/domain/image_recipe.dart).
//
// Salida: un arreglo plano de kLookValueCount floats (para JNI) con los
// índices de abajo. Mismo orden que FaceImageAnalysis en makeup_engine.dart.
#pragma once

#include "studio/region_sampling.h"
#include "studio/still_image.h"

namespace makeup {

// Bloque de una región: válida (0/1), L, a, b OKLab, gloss_score, muestras y
// cobertura (fracción de los texels de la máscara que se vieron en la foto).
inline constexpr int kRegionValid = 0;
inline constexpr int kRegionL = 1;
inline constexpr int kRegionA = 2;
inline constexpr int kRegionB = 3;
inline constexpr int kRegionGloss = 4;
inline constexpr int kRegionSamples = 5;
inline constexpr int kRegionCoverage = 6;
inline constexpr int kRegionFloats = 7;

// Regiones de sombra, en el orden de EyeRegion (face_style.h).
inline constexpr int kLookEyeRegionCount = 5;

inline constexpr int kLookStatus = 0;          // StillFaceStatus
inline constexpr int kLookEyeDistancePx = 1;   // entre ángulos externos de los ojos
inline constexpr int kLookYawRatio = 2;        // nariz respecto del medio de los ojos
inline constexpr int kLookSkin = 3;            // piel base (frente, nariz, mentón)
inline constexpr int kLookLips = kLookSkin + kRegionFloats;
inline constexpr int kLookLipLiner = kLookLips + kRegionFloats;     // mitad interna del anillo del delineado
inline constexpr int kLookLipInterior = kLookLipLiner + kRegionFloats;  // centro del labio
inline constexpr int kLookCheeks = kLookLipInterior + kRegionFloats;    // mejor placement
inline constexpr int kLookCheekPlacement = kLookCheeks + kRegionFloats;  // CheekPlacement
inline constexpr int kLookEyeRegions = kLookCheekPlacement + 1;          // 5 bloques
inline constexpr int kLookLiner = kLookEyeRegions + kLookEyeRegionCount * kRegionFloats;  // texels oscuros
inline constexpr int kLookLinerExtent = kLookLiner + kRegionFloats;  // distancia normalizada (B.g) [0, 1]
inline constexpr int kLookWingExtent = kLookLinerExtent + 1;         // avance del wing (B.a) [0, 1]
inline constexpr int kLookValueCount = kLookWingExtent + 1;

// Llena [out] (kLookValueCount floats) con las medidas de [image] y sus
// [landmarks] (px de la foto). No toca status, distancia entre ojos ni yaw
// (los pone quien llama). Devuelve false si no hay piel base: sin
// referencia no se puede medir nada.
bool analyzeLook(const StillImage& image, const float* landmarks, float* out);

// Escribe un bloque de región en out[offset..offset + kRegionFloats).
void writeRegion(const RegionColor& color, float coverage, float* out, int offset);

}  // namespace makeup
