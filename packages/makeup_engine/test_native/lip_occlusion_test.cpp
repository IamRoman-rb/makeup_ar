#include <vector>

#include "engine_config.h"
#include "mesh/canonical_mesh.h"
#include "test_harness.h"
#include "tracking/appearance.h"
#include "tracking/lip_occlusion.h"

using makeup::Chroma;
using makeup::FaceSamples;
using makeup::LipOcclusion;
using makeup::LipOcclusionEstimator;

namespace {

// Cromaticidades típicas ((a, b) / L): piel clara y labio rosado.
constexpr Chroma kSkin{0.05f, 0.07f};
constexpr Chroma kLip{0.15f, 0.07f};

// Muestras de labio: las primeras [hidden] con el color de la piel (una mano
// encima) y el resto con el del labio.
FaceSamples samples(int hidden, Chroma lip = kLip, Chroma skin = kSkin) {
  FaceSamples out;
  out.skinChroma = skin;
  out.skinChromaValid = true;
  out.lipChromaCount = makeup::kLipLightnessSamples;
  for (int i = 0; i < out.lipChromaCount; ++i) out.lipChroma[i] = i < hidden ? skin : lip;
  return out;
}

LipOcclusion run(LipOcclusionEstimator& estimator, const FaceSamples& input, int times) {
  LipOcclusion out;
  for (int i = 0; i < times; ++i) out = estimator.update(input);
  return out;
}

}  // namespace

TEST(oclusion_sinManoNoHaceNada) {
  LipOcclusionEstimator estimator;
  const LipOcclusion out = run(estimator, samples(0), 10);
  CHECK(out.gate == 0.0f);
  // El eje lleva de la piel al labio: p(piel) = 0, p(labio) = 1.
  const float pLip = (kLip.a - out.skin.a) * out.axis.a + (kLip.b - out.skin.b) * out.axis.b;
  CHECK_NEAR(pLip, 1.0, 1e-4);
  CHECK_NEAR(out.skin.a, kSkin.a, 1e-6);
}

TEST(oclusion_unReflejoNoPrendeLaCompuerta) {
  LipOcclusionEstimator estimator;
  run(estimator, samples(0), 5);
  CHECK(run(estimator, samples(2), 10).gate == 0.0f);  // 2 de 36
}

TEST(oclusion_manoSobreLaBoca) {
  LipOcclusionEstimator estimator;
  run(estimator, samples(0), 5);
  // La mitad del labio tapada: la compuerta sube en pocas inferencias.
  CHECK(estimator.update(samples(18)).gate > 0.5f);
  const LipOcclusion covered = run(estimator, samples(18), 5);
  CHECK(covered.gate > 0.95f);
  CHECK_NEAR(estimator.occludedFraction(), 0.5, 1e-6);
  // Toda la boca tapada durante un rato: no aprende la mano como labio.
  run(estimator, samples(36), 30);
  const LipOcclusion still = estimator.update(samples(36));
  CHECK(still.gate > 0.95f);
  const float pLip = (kLip.a - still.skin.a) * still.axis.a + (kLip.b - still.skin.b) * still.axis.b;
  CHECK_NEAR(pLip, 1.0, 1e-4);
  // Se saca la mano: baja más lento de lo que subió, pero baja.
  const float afterOne = estimator.update(samples(0)).gate;
  CHECK(afterOne > 0.3f);
  CHECK(run(estimator, samples(0), 15).gate == 0.0f);
}

TEST(oclusion_labioPalidoSinContraste) {
  // Labio casi del color de la piel: no se puede distinguir una mano.
  LipOcclusionEstimator estimator;
  const Chroma pale{0.065f, 0.07f};
  run(estimator, samples(0, pale), 5);
  CHECK(run(estimator, samples(30, pale), 10).gate == 0.0f);
}

TEST(oclusion_empiezaConLaBocaTapada) {
  // El primer labio que ve es la mano: sin contraste, sin oclusión. En cuanto
  // aparece el labio, lo aprende rápido y la oclusión funciona.
  LipOcclusionEstimator estimator;
  CHECK(run(estimator, samples(36), 5).gate == 0.0f);
  run(estimator, samples(0), 8);
  CHECK(run(estimator, samples(24), 6).gate > 0.95f);
}

TEST(oclusion_sinMedicionSeApaga) {
  LipOcclusionEstimator estimator;
  run(estimator, samples(0), 5);
  CHECK(run(estimator, samples(36), 5).gate > 0.95f);
  FaceSamples empty;  // la cara salió del recorte
  CHECK(run(estimator, empty, 15).gate == 0.0f);
  estimator.reset();
  CHECK(estimator.update(samples(0)).gate == 0.0f);
}

// measureFace sobre un recorte pintado: la cromaticidad del labio y la de la
// piel salen de los colores pintados.
TEST(oclusion_midenCromaticidadEnElRecorte) {
  constexpr int kSize = makeup::EngineConfig::kLandmarkInputSize;
  std::vector<float> face(makeup::mesh::kVertexCount * 3, 0.0f);
  for (int i = 0; i < makeup::mesh::kVertexCount; ++i) {
    face[i * 3] = 128.0f + makeup::mesh::kPositions[i * 3] * 8.0f;
    face[i * 3 + 1] = 128.0f - makeup::mesh::kPositions[i * 3 + 1] * 8.0f;
  }
  // Recorte de un solo color: labio y piel iguales.
  std::vector<uint8_t> crop(kSize * kSize * 4, 0);
  for (int i = 0; i < kSize * kSize; ++i) {
    crop[i * 4] = 200;
    crop[i * 4 + 1] = 150;
    crop[i * 4 + 2] = 130;
    crop[i * 4 + 3] = 255;
  }
  FaceSamples out;
  makeup::measureFace(crop.data(), kSize, face.data(), &out);
  CHECK(out.skinChromaValid);
  CHECK(out.lipChromaCount == makeup::kLipLightnessSamples);
  CHECK_NEAR(out.lipChroma[0].a, out.skinChroma.a, 1e-5);
  CHECK_NEAR(out.lipChroma[0].b, out.skinChroma.b, 1e-5);
  CHECK(out.skinChroma.a > 0.0f);  // piel cálida: a y b positivos
  CHECK(out.skinChroma.b > 0.0f);
}
