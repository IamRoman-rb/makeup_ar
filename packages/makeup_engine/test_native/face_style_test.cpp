#include <cmath>

#include "engine_config.h"
#include "face_style.h"
#include "mesh/face_maps.h"
#include "test_harness.h"

using makeup::CheekPlacement;
using makeup::CheekStyle;
using makeup::ColorLayer;
using makeup::EyeRegion;
using makeup::EyeShadowStyle;
using makeup::LinerStyle;
using makeup::ShadowFinish;

namespace {

ColorLayer layer(float r, float g, float b, float amount, bool enabled = true) {
  ColorLayer out;
  out.enabled = enabled;
  out.r = r;
  out.g = g;
  out.b = b;
  out.amount = amount;
  return out;
}

// Coordenada de la gaussiana del rubor en una UV espejada (como face.vert).
void cheekCoord(const makeup::FaceUniforms& face, float u, float v, float out[2]) {
  const float* m = face.cheekMatrix;  // column-major
  out[0] = m[0] * u + m[2] * v + face.cheekOffset[0];
  out[1] = m[1] * u + m[3] * v + face.cheekOffset[1];
}

float cheekWeight(const makeup::FaceUniforms& face, float u, float v) {
  float g[2];
  cheekCoord(face, u, v, g);
  return std::exp(-0.5f * (g[0] * g[0] + g[1] * g[1]));
}

}  // namespace

TEST(estiloCara_capasYOrden) {
  ColorLayer skin[makeup::kSkinLayerCount];
  skin[static_cast<int>(makeup::SkinLayer::kFoundation)] = layer(0.85f, 0.66f, 0.55f, 0.35f);
  skin[static_cast<int>(makeup::SkinLayer::kContour)] = layer(0.43f, 0.35f, 0.35f, 2.0f);  // se recorta
  skin[static_cast<int>(makeup::SkinLayer::kHighlight)] = layer(0.96f, 0.89f, 0.76f, 0.4f, false);
  CheekStyle cheek;
  cheek.color = layer(0.91f, 0.51f, 0.48f, 0.25f);
  const makeup::FaceUniforms face = makeup::resolveFace(skin, cheek);
  CHECK_NEAR(face.amount[makeup::kFaceFoundation], 0.35, 1e-6);
  CHECK_NEAR(face.amount[makeup::kFaceContour], 1.0, 1e-6);
  CHECK_NEAR(face.amount[makeup::kFaceCheek], 0.25, 1e-6);
  CHECK_NEAR(face.amount[makeup::kFaceHighlight], 0.0, 1e-6);  // apagada
  CHECK(face.any());
  // OKLab: la base clara tiene más L que el contorno.
  CHECK(face.lab[makeup::kFaceFoundation][0] > face.lab[makeup::kFaceContour][0]);
  CHECK_NEAR(face.highlightShine, makeup::EngineConfig::kHighlightShine, 1e-6);
  CHECK_NEAR(face.lumaFollow[makeup::kFaceFoundation], 1.0, 0.0);
  CHECK_NEAR(face.lumaFollow[makeup::kFaceHighlight], makeup::EngineConfig::kHighlightLumaFollow, 1e-6);

  ColorLayer none[makeup::kSkinLayerCount];
  CHECK(!makeup::resolveFace(none, CheekStyle{}).any());
}

TEST(estiloCara_ruborCentradoYConSpread) {
  ColorLayer skin[makeup::kSkinLayerCount];
  for (int p = 0; p < makeup::mesh::kCheekPlacementCount; ++p) {
    CheekStyle cheek;
    cheek.color = layer(1, 0, 0, 1);
    cheek.placement = static_cast<CheekPlacement>(p);
    cheek.spread = 0.0f;
    const makeup::FaceUniforms small = makeup::resolveFace(skin, cheek);
    cheek.spread = 1.0f;
    const makeup::FaceUniforms large = makeup::resolveFace(skin, cheek);
    const float* c = makeup::mesh::kCheekPlacements[p];
    CHECK_NEAR(cheekWeight(small, c[0], c[1]), 1.0, 1e-5);
    // A un sigma (escalado) sobre el eje mayor, exp(-0,5).
    const float sigma = c[2] * makeup::EngineConfig::kCheekSpreadScaleMin;
    const float u = c[0] + sigma * std::cos(c[4]);
    const float v = c[1] + sigma * std::sin(c[4]);
    CHECK_NEAR(cheekWeight(small, u, v), std::exp(-0.5), 1e-4);
    // Con más spread el rubor llega más lejos.
    CHECK(cheekWeight(large, u, v) > cheekWeight(small, u, v));
  }
  // Placement inválido: cae a apple.
  CheekStyle invalid;
  invalid.placement = static_cast<CheekPlacement>(7);
  const makeup::FaceUniforms face = makeup::resolveFace(skin, invalid);
  const float* apple = makeup::mesh::kCheekPlacements[0];
  CHECK_NEAR(cheekWeight(face, apple[0], apple[1]), 1.0, 1e-5);
}

TEST(estiloOjos_sombrasYRegiones) {
  EyeShadowStyle shadows[makeup::kMaxEyeShadows];
  shadows[0].color = layer(0.65f, 0.48f, 0.4f, 0.25f);
  shadows[0].region = EyeRegion::kLid;
  shadows[1].color = layer(0.42f, 0.27f, 0.14f, 0.45f);
  shadows[1].region = EyeRegion::kCrease;
  shadows[1].finish = ShadowFinish::kSatin;
  shadows[2].color = layer(0.95f, 0.85f, 0.65f, 0.4f);
  shadows[2].region = EyeRegion::kBrowBone;
  shadows[2].finish = ShadowFinish::kShimmer;
  const makeup::EyeUniforms eyes = makeup::resolveEyes(shadows, LinerStyle{});
  CHECK(eyes.any());
  CHECK(eyes.shimmer);
  CHECK_NEAR(eyes.shadowSelectA[0][0], 1.0, 0.0);
  CHECK_NEAR(eyes.shadowSelectA[1][1], 1.0, 0.0);
  CHECK_NEAR(eyes.shadowSelectB[2], 1.0, 0.0);
  for (int k = 0; k < 4; ++k) CHECK_NEAR(eyes.shadowSelectA[2][k], 0.0, 0.0);
  CHECK_NEAR(eyes.shadowShine[0], 0.0, 0.0);
  CHECK_NEAR(eyes.shadowShine[1], makeup::EngineConfig::kShadowSatinShine, 1e-6);
  CHECK_NEAR(eyes.shadowSparkle[2], makeup::EngineConfig::kShadowShimmerSparkle, 1e-6);
  CHECK_NEAR(eyes.shadowAmount[3], 0.0, 0.0);  // slot vacío

  // Shimmer en un slot apagado no fuerza la variante.
  EyeShadowStyle off[makeup::kMaxEyeShadows];
  off[0].finish = ShadowFinish::kShimmer;
  const makeup::EyeUniforms empty = makeup::resolveEyes(off, LinerStyle{});
  CHECK(!empty.shimmer);
  CHECK(!empty.any());
}

TEST(estiloOjos_delineado) {
  EyeShadowStyle shadows[makeup::kMaxEyeShadows];
  LinerStyle thin;
  thin.color = layer(0.07f, 0.07f, 0.07f, 0.9f);
  thin.thickness = 0.0f;
  thin.wing = 0.4f;
  LinerStyle thick = thin;
  thick.thickness = 1.0f;
  thick.wing = 3.0f;  // se recorta
  const makeup::EyeUniforms a = makeup::resolveEyes(shadows, thin);
  const makeup::EyeUniforms b = makeup::resolveEyes(shadows, thick);
  CHECK(a.any());
  CHECK_NEAR(a.linerEdge[0], makeup::EngineConfig::kLinerThicknessMin, 1e-6);
  CHECK_NEAR(b.linerEdge[0], makeup::EngineConfig::kLinerThicknessMax, 1e-6);
  CHECK_NEAR(a.linerEdge[1] - a.linerEdge[0], makeup::EngineConfig::kLinerFeather, 1e-6);
  CHECK(b.linerEdge[1] < 1.0f);  // el canal llega a 1 lejos de la línea: nunca cubre todo
  CHECK_NEAR(a.wing, 0.4, 1e-6);
  CHECK_NEAR(b.wing, 1.0, 1e-6);
  CHECK(a.linerLab[0] < 0.3f);
}
