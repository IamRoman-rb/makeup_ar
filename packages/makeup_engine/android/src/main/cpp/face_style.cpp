#include "face_style.h"

#include <algorithm>
#include <cmath>

#include "color_math.h"
#include "engine_config.h"
#include "mesh/face_maps.h"

namespace makeup {

namespace {

float unit(float value) { return std::isnan(value) ? 0.0f : std::clamp(value, 0.0f, 1.0f); }

// Intensidad efectiva: 0 si la capa está apagada.
float amountOf(const ColorLayer& layer) { return layer.enabled ? unit(layer.amount) : 0.0f; }

void toLab(const ColorLayer& layer, float out[3]) {
  const Vec3 lab = srgbToOklab(unit(layer.r), unit(layer.g), unit(layer.b));
  out[0] = lab.x;
  out[1] = lab.y;
  out[2] = lab.z;
}

}  // namespace

bool FaceUniforms::any() const {
  return std::any_of(std::begin(amount), std::end(amount), [](float a) { return a > 0.0f; });
}

bool EyeUniforms::any() const {
  return linerAmount > 0.0f || lashAmount > 0.0f ||
         std::any_of(std::begin(shadowAmount), std::end(shadowAmount), [](float a) { return a > 0.0f; });
}

FaceUniforms resolveFace(const ColorLayer skin[kSkinLayerCount], const CheekStyle& cheek) {
  FaceUniforms out;
  const ColorLayer* layers[kFaceLayerCount] = {};
  layers[kFaceFoundation] = &skin[static_cast<int>(SkinLayer::kFoundation)];
  layers[kFaceContour] = &skin[static_cast<int>(SkinLayer::kContour)];
  layers[kFaceCheek] = &cheek.color;
  layers[kFaceHighlight] = &skin[static_cast<int>(SkinLayer::kHighlight)];
  for (int i = 0; i < kFaceLayerCount; ++i) {
    out.amount[i] = amountOf(*layers[i]);
    toLab(*layers[i], out.lab[i]);
  }
  out.lumaFollow[kFaceHighlight] = EngineConfig::kHighlightLumaFollow;
  out.highlightShine = EngineConfig::kHighlightShine;

  // Gaussiana elíptica del rubor (mesh/face_maps.h): g = S⁻¹·Rᵀ·(uv - centro),
  // con los sigmas escalados por spread.
  int placement = static_cast<int>(cheek.placement);
  if (placement < 0 || placement >= mesh::kCheekPlacementCount) placement = 0;
  const float* p = mesh::kCheekPlacements[placement];
  const float scale = EngineConfig::kCheekSpreadScaleMin +
                      (EngineConfig::kCheekSpreadScaleMax - EngineConfig::kCheekSpreadScaleMin) * unit(cheek.spread);
  const float su = p[2] * scale;
  const float sv = p[3] * scale;
  const float c = std::cos(p[4]);
  const float s = std::sin(p[4]);
  const float m00 = c / su;
  const float m01 = s / su;
  const float m10 = -s / sv;
  const float m11 = c / sv;
  out.cheekMatrix[0] = m00;  // columna 0
  out.cheekMatrix[1] = m10;
  out.cheekMatrix[2] = m01;  // columna 1
  out.cheekMatrix[3] = m11;
  out.cheekOffset[0] = -(m00 * p[0] + m01 * p[1]);
  out.cheekOffset[1] = -(m10 * p[0] + m11 * p[1]);
  return out;
}

EyeUniforms resolveEyes(const EyeShadowStyle shadows[kMaxEyeShadows], const LinerStyle& liner,
                        const LashStyle& lashes) {
  EyeUniforms out;
  for (int i = 0; i < kMaxEyeShadows; ++i) {
    const EyeShadowStyle& shadow = shadows[i];
    out.shadowAmount[i] = amountOf(shadow.color);
    toLab(shadow.color, out.shadowLab[i]);
    int region = static_cast<int>(shadow.region);
    if (region < 0 || region > static_cast<int>(EyeRegion::kBrowBone)) region = 0;
    // Mapa A: párpado, pliegue, V externa, lagrimal; el hueso de la ceja está
    // en el canal R del mapa B.
    if (region == static_cast<int>(EyeRegion::kBrowBone)) {
      out.shadowSelectB[i] = 1.0f;
    } else {
      out.shadowSelectA[i][region] = 1.0f;
    }
    switch (shadow.finish) {
      case ShadowFinish::kSatin:
        out.shadowShine[i] = EngineConfig::kShadowSatinShine;
        break;
      case ShadowFinish::kShimmer:
        out.shadowShine[i] = EngineConfig::kShadowSatinShine;
        out.shadowSparkle[i] = EngineConfig::kShadowShimmerSparkle;
        out.shimmer = out.shimmer || out.shadowAmount[i] > 0.0f;
        break;
      case ShadowFinish::kMatte:
      default:
        break;
    }
  }
  out.linerAmount = amountOf(liner.color);
  toLab(liner.color, out.linerLab);
  const float threshold = EngineConfig::kLinerThicknessMin +
                          (EngineConfig::kLinerThicknessMax - EngineConfig::kLinerThicknessMin) * unit(liner.thickness);
  out.linerEdge[0] = threshold;
  out.linerEdge[1] = threshold + EngineConfig::kLinerFeather;
  out.wing = unit(liner.wing);

  // Pestañas: color fijo de máscara (la receta no trae color); volumen = más
  // hebras, más gruesas y raíz más oscura.
  const float opacity = lashes.enabled ? unit(lashes.opacity) : 0.0f;
  const Vec3 lash = srgbToOklab(EngineConfig::kLashColor[0], EngineConfig::kLashColor[1], EngineConfig::kLashColor[2]);
  out.lashLab[0] = lash.x;
  out.lashLab[1] = lash.y;
  out.lashLab[2] = lash.z;
  out.lashAmount = opacity;
  out.lowerLashAmount = opacity * EngineConfig::kLowerLashOpacity;
  const float volume = unit(lashes.volume);
  const auto lerp = [](float a, float b, float t) { return a + (b - a) * t; };
  out.lashParams[0] = lerp(EngineConfig::kLashCountMin, EngineConfig::kLashCountMax, volume);
  out.lashParams[1] = lerp(EngineConfig::kLashLengthMin, EngineConfig::kLashLengthMax, unit(lashes.length));
  out.lashParams[2] = lerp(EngineConfig::kLashWidthMin, EngineConfig::kLashWidthMax, volume);
  out.lashParams[3] = EngineConfig::kLashCurl;
  out.lashRoot = volume * EngineConfig::kLashRootMax;
  return out;
}

}  // namespace makeup
