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
  const makeup::EyeUniforms eyes = makeup::resolveEyes(shadows, LinerStyle{}, makeup::LashStyle{});
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
  const makeup::EyeUniforms empty = makeup::resolveEyes(off, LinerStyle{}, makeup::LashStyle{});
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
  const makeup::EyeUniforms a = makeup::resolveEyes(shadows, thin, makeup::LashStyle{});
  const makeup::EyeUniforms b = makeup::resolveEyes(shadows, thick, makeup::LashStyle{});
  CHECK(a.any());
  CHECK_NEAR(a.linerEdge[0], makeup::EngineConfig::kLinerThicknessMin, 1e-6);
  CHECK_NEAR(b.linerEdge[0], makeup::EngineConfig::kLinerThicknessMax, 1e-6);
  CHECK_NEAR(a.linerEdge[1] - a.linerEdge[0], makeup::EngineConfig::kLinerFeather, 1e-6);
  CHECK(b.linerEdge[1] < 1.0f);  // el canal llega a 1 lejos de la línea: nunca cubre todo
  CHECK_NEAR(a.wing, 0.4, 1e-6);
  CHECK_NEAR(b.wing, 1.0, 1e-6);
  CHECK(a.linerLab[0] < 0.3f);
}

TEST(estiloOjos_pestanas) {
  EyeShadowStyle shadows[makeup::kMaxEyeShadows];
  makeup::LashStyle off;
  off.opacity = 0.9f;  // apagadas aunque tengan opacidad
  const makeup::EyeUniforms none = makeup::resolveEyes(shadows, LinerStyle{}, off);
  CHECK(!none.any());
  CHECK_NEAR(none.lashAmount, 0.0, 0.0);

  makeup::LashStyle thin;
  thin.enabled = true;
  thin.opacity = 0.8f;
  thin.length = 0.0f;
  thin.volume = 0.0f;
  makeup::LashStyle full = thin;
  full.length = 1.0f;
  full.volume = 3.0f;  // se recorta
  const makeup::EyeUniforms a = makeup::resolveEyes(shadows, LinerStyle{}, thin);
  const makeup::EyeUniforms b = makeup::resolveEyes(shadows, LinerStyle{}, full);
  CHECK(a.any());
  CHECK_NEAR(a.lashAmount, 0.8, 1e-6);
  CHECK_NEAR(a.lowerLashAmount, 0.8 * makeup::EngineConfig::kLowerLashOpacity, 1e-6);
  CHECK_NEAR(a.lashParams[0], makeup::EngineConfig::kLashCountMin, 1e-6);
  CHECK_NEAR(b.lashParams[0], makeup::EngineConfig::kLashCountMax, 1e-6);
  CHECK_NEAR(a.lashParams[1], makeup::EngineConfig::kLashLengthMin, 1e-6);
  CHECK_NEAR(b.lashParams[1], makeup::EngineConfig::kLashLengthMax, 1e-6);
  CHECK(b.lashParams[1] < 0.98f);  // altura 1 del mapa = sin pestañas
  CHECK(b.lashParams[2] > a.lashParams[2]);
  CHECK_NEAR(b.lashRoot, makeup::EngineConfig::kLashRootMax, 1e-6);
  CHECK(a.lashLab[0] < 0.3f);  // negro de máscara
}

TEST(estiloEfectos_repartoPorPasada) {
  makeup::EffectStyle effects[makeup::kMaxEffects];
  effects[0].enabled = true;
  effects[0].type = makeup::EffectType::kGlitter;
  effects[0].intensity = 0.3f;
  effects[0].region = makeup::EffectRegion::kEyes;
  effects[1].enabled = true;
  effects[1].type = makeup::EffectType::kSheen;
  effects[1].intensity = 0.25f;
  effects[1].region = makeup::EffectRegion::kCheeksNose;
  effects[2].enabled = true;
  effects[2].type = makeup::EffectType::kFreckles;
  effects[2].intensity = 2.0f;  // se recorta
  effects[2].region = makeup::EffectRegion::kFullFace;

  makeup::FaceUniforms face;
  makeup::EyeUniforms eyes;
  makeup::LipEffects lips;
  makeup::applyEffects(effects, &face, &eyes, &lips);
  CHECK(face.effects());
  CHECK(face.any());  // solo efectos alcanza para dibujar la pasada
  CHECK_NEAR(face.effectAmount[static_cast<int>(makeup::EffectType::kSheen)],
             0.25 * makeup::EngineConfig::kSheenGain, 1e-6);
  CHECK_NEAR(face.effectOnSkin[static_cast<int>(makeup::EffectType::kSheen)], 0.0, 0.0);
  CHECK_NEAR(face.effectAmount[static_cast<int>(makeup::EffectType::kFreckles)],
             makeup::EngineConfig::kFreckleOpacity, 1e-6);
  CHECK_NEAR(face.effectOnSkin[static_cast<int>(makeup::EffectType::kFreckles)], 1.0, 0.0);
  CHECK_NEAR(face.freckleDensity, makeup::EngineConfig::kFreckleDensityMax, 1e-6);
  CHECK_NEAR(face.effectAmount[static_cast<int>(makeup::EffectType::kGlitter)], 0.0, 0.0);  // fue a los ojos
  CHECK_NEAR(eyes.glitter, 0.3 * makeup::EngineConfig::kGlitterSparkle, 1e-6);
  CHECK(eyes.shimmer);
  CHECK(eyes.any());
  CHECK_NEAR(lips.sparkle, 0.0, 0.0);
}

TEST(estiloEfectos_labiosYApagados) {
  makeup::EffectStyle effects[makeup::kMaxEffects];
  effects[0].enabled = true;
  effects[0].type = makeup::EffectType::kGlitter;
  effects[0].intensity = 0.5f;
  effects[0].region = makeup::EffectRegion::kLips;
  effects[1].enabled = true;
  effects[1].type = makeup::EffectType::kSheen;
  effects[1].intensity = 1.0f;
  effects[1].region = makeup::EffectRegion::kLips;
  effects[2].enabled = false;  // apagado aunque tenga intensidad
  effects[2].type = makeup::EffectType::kFreckles;
  effects[2].intensity = 1.0f;
  effects[2].region = makeup::EffectRegion::kCheeksNose;
  makeup::FaceUniforms face;
  makeup::EyeUniforms eyes;
  makeup::LipEffects lips;
  makeup::applyEffects(effects, &face, &eyes, &lips);
  CHECK(!face.effects());
  CHECK(!eyes.any());
  CHECK_NEAR(lips.sparkle, 0.5 * makeup::EngineConfig::kGlitterSparkle, 1e-6);
  CHECK_NEAR(lips.gloss, makeup::EngineConfig::kLipSheenGloss, 1e-6);
}

namespace {

// Pone el iris [eye] (0 o 1) con centro (cx, cy) y semiejes u, v en [points].
void setIris(float* points, int eye, float cx, float cy, const float u[2], const float v[2]) {
  const int first = eye == 0 ? makeup::EngineConfig::kIrisFirstCenter : makeup::EngineConfig::kIrisSecondCenter;
  const float ring[4][2] = {{cx + u[0], cy + u[1]}, {cx + v[0], cy + v[1]}, {cx - u[0], cy - u[1]}, {cx - v[0], cy - v[1]}};
  points[first * 3] = cx;
  points[first * 3 + 1] = cy;
  for (int k = 0; k < 4; ++k) {
    points[(first + 1 + k) * 3] = ring[k][0];
    points[(first + 1 + k) * 3 + 1] = ring[k][1];
  }
}

// |M · (p - c)| con M column-major (como glUniformMatrix2fv / iris.frag).
float ellipseR(const float* centers, const float* inverse, int eye, float x, float y) {
  const float dx = x - centers[eye * 2];
  const float dy = y - centers[eye * 2 + 1];
  const float* m = inverse + eye * 4;
  return std::hypot(m[0] * dx + m[2] * dy, m[1] * dx + m[3] * dy);
}

}  // namespace

TEST(iris_elipsesDesdeLosLandmarks) {
  float points[makeup::EngineConfig::kLandmarkCount * 3] = {};
  // Iris 0: ojo girado (7 px de ancho, 10 de alto). Iris 1: cabeza inclinada 30°.
  const float u0[2] = {7.0f, 0.0f};
  const float v0[2] = {0.0f, -10.0f};
  const float c30 = std::cos(0.5236f);
  const float s30 = std::sin(0.5236f);
  const float u1[2] = {12.0f * c30, 12.0f * s30};
  const float v1[2] = {-12.0f * s30, 12.0f * c30};
  setIris(points, 0, 100.0f, 50.0f, u0, v0);
  setIris(points, 1, 200.0f, 52.0f, u1, v1);
  float centers[4] = {};
  float inverse[8] = {};
  CHECK(makeup::irisEllipses(points, centers, inverse));
  CHECK_NEAR(centers[0], 100.0, 1e-4);
  CHECK_NEAR(centers[3], 52.0, 1e-4);
  // El anillo cae en r = 1, el centro en 0.
  CHECK_NEAR(ellipseR(centers, inverse, 0, 107.0f, 50.0f), 1.0, 1e-5);
  CHECK_NEAR(ellipseR(centers, inverse, 0, 100.0f, 40.0f), 1.0, 1e-5);
  CHECK_NEAR(ellipseR(centers, inverse, 0, 100.0f, 50.0f), 0.0, 1e-6);
  CHECK_NEAR(ellipseR(centers, inverse, 1, 200.0f + u1[0], 52.0f + u1[1]), 1.0, 1e-5);
  CHECK_NEAR(ellipseR(centers, inverse, 1, 200.0f - v1[0], 52.0f - v1[1]), 1.0, 1e-5);
  // Esclera a 9 px del centro en horizontal: fuera del iris achatado (r > 1,1).
  CHECK(ellipseR(centers, inverse, 0, 109.0f, 50.0f) > 1.2f);

  // Anillo degenerado (ojo muy lejos o puntos colapsados): no se dibuja.
  const float tiny[2] = {1.0f, 0.0f};
  const float tinyV[2] = {0.0f, 1.0f};
  setIris(points, 1, 200.0f, 52.0f, tiny, tinyV);
  CHECK(!makeup::irisEllipses(points, centers, inverse));
  // NaN: tampoco.
  setIris(points, 1, 200.0f, 52.0f, u1, v1);
  points[(makeup::EngineConfig::kIrisSecondCenter + 1) * 3] = std::nanf("");
  CHECK(!makeup::irisEllipses(points, centers, inverse));
}

TEST(iris_resolverColor) {
  float lab[3] = {};
  float amount = -1.0f;
  makeup::resolveColorLayer(layer(0.2f, 0.45f, 0.85f, 0.7f), lab, &amount);
  makeup::IrisUniforms iris;
  CHECK(!iris.any());
  iris.amount = amount;
  CHECK(iris.any());
  CHECK_NEAR(amount, 0.7, 1e-6);
  CHECK(lab[2] < 0.0f);  // azul: b negativo
}
