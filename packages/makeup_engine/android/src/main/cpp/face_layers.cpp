#include "face_layers.h"

#include "engine_config.h"
#include "gl_program.h"
#include "mesh/eye_maps.h"
#include "mesh/face_maps.h"
#include "mesh/mesh_normals.h"
#include "shader_sources.h"

namespace makeup {

namespace {

constexpr char kShimmerDefines[] = "#define SHIMMER 1\n";
constexpr char kEffectsDefines[] = "#define EFFECTS 1\n";
// Unidades de textura (0 = cámara, 1 = mapa de labios).
constexpr int kFaceMapUnit = 2;
constexpr int kEyeMapAUnit = 3;
constexpr int kEyeMapBUnit = 4;
constexpr int kEyeMapCUnit = 5;
constexpr GLuint kPointAttribute = 0;
constexpr GLuint kUvAttribute = 1;
constexpr GLuint kNormalAttribute = 2;

static_assert(sizeof(mesh::kFaceMapRgba) == static_cast<size_t>(mesh::kFaceMapWidth) * mesh::kFaceMapHeight * 4,
              "mapa de cara RGBA8 incompleto");
static_assert(sizeof(mesh::kEyeMapA) == static_cast<size_t>(mesh::kEyeMapWidth) * mesh::kEyeMapHeight * 4,
              "mapa de ojos A incompleto");
static_assert(sizeof(mesh::kEyeMapB) == sizeof(mesh::kEyeMapA), "mapa de ojos B incompleto");
static_assert(sizeof(mesh::kEyeMapC) == sizeof(mesh::kEyeMapA), "mapa de ojos C incompleto");

// Textura 2D inmutable, lineal y CLAMP_TO_EDGE (los bordes de los mapas son
// "sin maquillaje": máscaras en 0 y distancias en 1).
void uploadTexture(GlTexture& out, GLenum internalFormat, GLenum format, int width, int height,
                   const uint8_t* data) {
  GLuint texture = 0;
  glGenTextures(1, &texture);
  out.reset(texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexStorage2D(GL_TEXTURE_2D, 1, internalFormat, width, height);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, format, GL_UNSIGNED_BYTE, data);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindTexture(GL_TEXTURE_2D, 0);
}

}  // namespace

bool FaceLayers::init(GLuint pointVbo, GLuint uvVbo, GLuint normalVbo, std::string* error) {
  return buildFaceProgram(face_, nullptr, error) && buildFaceProgram(faceEffects_, kEffectsDefines, error) &&
         buildEyesProgram(eyes_, nullptr, error) &&
         buildEyesProgram(eyesShimmer_, kShimmerDefines, error) && buildIrisProgram(error) &&
         buildGeometry(pointVbo, uvVbo, normalVbo) &&
         buildTextures(error);
}

void FaceLayers::release() {
  face_.program.reset();
  faceEffects_.program.reset();
  eyes_.program.reset();
  eyesShimmer_.program.reset();
  iris_.program.reset();
  faceVao_.reset();
  eyesVao_.reset();
  irisVao_.reset();
  faceIbo_.reset();
  eyesIbo_.reset();
  irisIbo_.reset();
  faceMap_.reset();
  eyeMapA_.reset();
  eyeMapB_.reset();
  eyeMapC_.reset();
}

bool FaceLayers::buildCommon(Common& out, const char* fragmentSource, const char* defines, const float* mapRect,
                             std::string* error) {
  // Mismo orden que kPointAttribute / kUvAttribute / kNormalAttribute.
  const char* attributes[] = {"aPoint", "aUv", "aNormal"};
  GlProgram program = buildGlProgram(shaders::k_face_vert, fragmentSource, attributes, 3, error, defines);
  if (!program) return false;
  const GLuint id = program.get();
  out.imageToClip = glGetUniformLocation(id, "uImageToClip");
  out.displayMatrix = glGetUniformLocation(id, "uDisplayMatrix");
  out.texMatrix = glGetUniformLocation(id, "uTexMatrix");
  out.view = glGetUniformLocation(id, "uView");
  out.skinLightness = glGetUniformLocation(id, "uSkinLightness");
  // Constantes de la sesión: transformación UV espejada -> mapa y desvanecido.
  glUseProgram(id);
  glUniform1i(glGetUniformLocation(id, "uCamera"), 0);
  glUniform4f(glGetUniformLocation(id, "uMapTransform"), 1.0f / mapRect[2], 1.0f / mapRect[3],
              -mapRect[0] / mapRect[2], -mapRect[1] / mapRect[3]);
  glUniform2f(glGetUniformLocation(id, "uFacingFade"), EngineConfig::kFaceFacingFadeStart,
              EngineConfig::kFaceFacingFadeEnd);
  glUseProgram(0);
  out.uploadedDisplayVersion = 0;
  out.program = std::move(program);
  return true;
}

bool FaceLayers::buildFaceProgram(FaceProgram& out, const char* defines, std::string* error) {
  if (!buildCommon(out, shaders::k_face_frag, defines, mesh::kFaceMapUvRect, error)) return false;
  const GLuint id = out.program.get();
  out.cheekMatrix = glGetUniformLocation(id, "uCheekMatrix");
  out.cheekOffset = glGetUniformLocation(id, "uCheekOffset");
  out.layerLab = glGetUniformLocation(id, "uLayerLab[0]");
  out.layerAmount = glGetUniformLocation(id, "uLayerAmount");
  out.layerLumaFollow = glGetUniformLocation(id, "uLayerLumaFollow");
  out.highlightShine = glGetUniformLocation(id, "uHighlightShine");
  out.effectAmount = glGetUniformLocation(id, "uEffectAmount");
  out.effectOnSkin = glGetUniformLocation(id, "uEffectOnSkin");
  out.effectDensity = glGetUniformLocation(id, "uEffectDensity");
  out.time = glGetUniformLocation(id, "uTime");
  glUseProgram(id);
  glUniform1i(glGetUniformLocation(id, "uFaceMap"), kFaceMapUnit);
  glUseProgram(0);
  MAKEUP_GL_CHECK("buildFaceProgram");
  return true;
}

bool FaceLayers::buildEyesProgram(EyesProgram& out, const char* defines, std::string* error) {
  if (!buildCommon(out, shaders::k_eyes_frag, defines, mesh::kEyeMapUvRect, error)) return false;
  const GLuint id = out.program.get();
  out.shadowLab = glGetUniformLocation(id, "uShadowLab[0]");
  out.shadowAmount = glGetUniformLocation(id, "uShadowAmount");
  out.shadowSelect = glGetUniformLocation(id, "uShadowSelect[0]");
  out.shadowBrowBone = glGetUniformLocation(id, "uShadowBrowBone");
  out.shadowShine = glGetUniformLocation(id, "uShadowShine");
  out.linerLab = glGetUniformLocation(id, "uLinerLab");
  out.linerAmount = glGetUniformLocation(id, "uLinerAmount");
  out.linerEdge = glGetUniformLocation(id, "uLinerEdge");
  out.wing = glGetUniformLocation(id, "uWing");
  out.lashLab = glGetUniformLocation(id, "uLashLab");
  out.lashAmount = glGetUniformLocation(id, "uLashAmount");
  out.lowerLashAmount = glGetUniformLocation(id, "uLowerLashAmount");
  out.lashParams = glGetUniformLocation(id, "uLashParams");
  out.lashRoot = glGetUniformLocation(id, "uLashRoot");
  out.eyeSheen = glGetUniformLocation(id, "uEyeSheen");
  out.glitter = glGetUniformLocation(id, "uGlitter");
  out.time = glGetUniformLocation(id, "uTime");
  out.shadowSparkle = glGetUniformLocation(id, "uShadowSparkle");
  glUseProgram(id);
  glUniform1i(glGetUniformLocation(id, "uEyeMapA"), kEyeMapAUnit);
  glUniform1i(glGetUniformLocation(id, "uEyeMapB"), kEyeMapBUnit);
  glUniform1i(glGetUniformLocation(id, "uEyeMapC"), kEyeMapCUnit);
  // Los ojos no tienen rubor: la gaussiana queda en 0 (uniform sin usar en el
  // fragment, pero el vertex shader lo calcula igual).
  const float zero[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  glUniformMatrix2fv(glGetUniformLocation(id, "uCheekMatrix"), 1, GL_FALSE, zero);
  glUniform2f(glGetUniformLocation(id, "uCheekOffset"), 0.0f, 0.0f);
  glUseProgram(0);
  MAKEUP_GL_CHECK("buildEyesProgram");
  return true;
}

// Iris: mismos atributos que las otras pasadas; los parámetros de la máscara
// y del tono son constantes de la sesión (engine_config.h).
bool FaceLayers::buildIrisProgram(std::string* error) {
  const char* attributes[] = {"aPoint", "aUv", "aNormal"};
  GlProgram program = buildGlProgram(shaders::k_iris_vert, shaders::k_iris_frag, attributes, 3, error);
  if (!program) return false;
  const GLuint id = program.get();
  iris_.imageToClip = glGetUniformLocation(id, "uImageToClip");
  iris_.displayMatrix = glGetUniformLocation(id, "uDisplayMatrix");
  iris_.texMatrix = glGetUniformLocation(id, "uTexMatrix");
  iris_.view = glGetUniformLocation(id, "uView");
  iris_.irisCenter = glGetUniformLocation(id, "uIrisCenter[0]");
  iris_.irisShape = glGetUniformLocation(id, "uIrisShape[0]");
  iris_.irisLab = glGetUniformLocation(id, "uIrisLab");
  iris_.irisAmount = glGetUniformLocation(id, "uIrisAmount");
  glUseProgram(id);
  glUniform1i(glGetUniformLocation(id, "uCamera"), 0);
  glUniform2f(glGetUniformLocation(id, "uFacingFade"), EngineConfig::kFaceFacingFadeStart,
              EngineConfig::kFaceFacingFadeEnd);
  glUniform4f(glGetUniformLocation(id, "uIrisMask"), EngineConfig::kIrisPupil, EngineConfig::kIrisPupilFeather,
              EngineConfig::kIrisEdgeFeather, EngineConfig::kIrisLimbalStart);
  glUniform4f(glGetUniformLocation(id, "uIrisTone"), EngineConfig::kIrisLimbalDarken, 1.0f / EngineConfig::kIrisRefL,
              EngineConfig::kIrisShadingMin, EngineConfig::kIrisShadingMax);
  glUniform2f(glGetUniformLocation(id, "uIrisFloor"), EngineConfig::kIrisShadingSlope,
              EngineConfig::kIrisMinFeatherPx);
  glUniform2f(glGetUniformLocation(id, "uIrisDark"), EngineConfig::kIrisDarkLow, EngineConfig::kIrisDarkHigh);
  glUniform2f(glGetUniformLocation(id, "uIrisSpecular"), EngineConfig::kIrisSpecularLow,
              EngineConfig::kIrisSpecularHigh);
  glUseProgram(0);
  iris_.uploadedDisplayVersion = 0;
  iris_.program = std::move(program);
  MAKEUP_GL_CHECK("buildIrisProgram");
  return true;
}

// VAOs de cara, ojos e iris sobre los VBOs del Renderer (puntos dinámicos, UV
// y normales estáticas) con su IBO estático cada uno.
bool FaceLayers::buildGeometry(GLuint pointVbo, GLuint uvVbo, GLuint normalVbo) {
  GLuint vaos[3] = {0, 0, 0};
  glGenVertexArrays(3, vaos);
  faceVao_.reset(vaos[0]);
  eyesVao_.reset(vaos[1]);
  irisVao_.reset(vaos[2]);
  GLuint buffers[3] = {0, 0, 0};
  glGenBuffers(3, buffers);
  faceIbo_.reset(buffers[0]);
  eyesIbo_.reset(buffers[1]);
  irisIbo_.reset(buffers[2]);

  struct Zone {
    GLuint vao;
    GLuint ibo;
    const uint16_t* indices;
    size_t bytes;
  };
  const Zone zones[3] = {
      {faceVao_.get(), faceIbo_.get(), mesh::kFaceRegionTriangles, sizeof(mesh::kFaceRegionTriangles)},
      {eyesVao_.get(), eyesIbo_.get(), mesh::kEyeRegionTriangles, sizeof(mesh::kEyeRegionTriangles)},
      {irisVao_.get(), irisIbo_.get(), mesh::kEyeOpeningTriangles, sizeof(mesh::kEyeOpeningTriangles)},
  };
  for (const Zone& zone : zones) {
    glBindVertexArray(zone.vao);
    glBindBuffer(GL_ARRAY_BUFFER, pointVbo);
    glEnableVertexAttribArray(kPointAttribute);
    glVertexAttribPointer(kPointAttribute, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glBindBuffer(GL_ARRAY_BUFFER, uvVbo);
    glEnableVertexAttribArray(kUvAttribute);
    glVertexAttribPointer(kUvAttribute, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glBindBuffer(GL_ARRAY_BUFFER, normalVbo);
    glEnableVertexAttribArray(kNormalAttribute);
    glVertexAttribPointer(kNormalAttribute, mesh::kNormalComponents, GL_FLOAT, GL_FALSE, 0, nullptr);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, zone.ibo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(zone.bytes), zone.indices, GL_STATIC_DRAW);
  }
  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  MAKEUP_GL_CHECK("FaceLayers::buildGeometry");
  return true;
}

bool FaceLayers::buildTextures(std::string* error) {
  // Descarta errores previos para que el chequeo sea solo de estas texturas.
  while (glGetError() != GL_NO_ERROR) {
  }
  uploadTexture(faceMap_, GL_RGBA8, GL_RGBA, mesh::kFaceMapWidth, mesh::kFaceMapHeight, mesh::kFaceMapRgba);
  uploadTexture(eyeMapA_, GL_RGBA8, GL_RGBA, mesh::kEyeMapWidth, mesh::kEyeMapHeight, mesh::kEyeMapA);
  uploadTexture(eyeMapB_, GL_RGBA8, GL_RGBA, mesh::kEyeMapWidth, mesh::kEyeMapHeight, mesh::kEyeMapB);
  uploadTexture(eyeMapC_, GL_RGBA8, GL_RGBA, mesh::kEyeMapWidth, mesh::kEyeMapHeight, mesh::kEyeMapC);
  if (glGetError() != GL_NO_ERROR) {
    *error = "no se pudieron crear los mapas de cara y ojos";
    return false;
  }
  return true;
}

void FaceLayers::bindCommon(Common& program, const LayerFrame& frame) {
  glUseProgram(program.program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(MAKEUP_CAMERA_TEXTURE, frame.cameraTexture);
  if (program.uploadedDisplayVersion != frame.displayVersion) {
    glUniformMatrix4fv(program.displayMatrix, 1, GL_FALSE, frame.displayMatrix);
    program.uploadedDisplayVersion = frame.displayVersion;
  }
  glUniformMatrix4fv(program.texMatrix, 1, GL_FALSE, frame.texMatrix);
  glUniform4fv(program.imageToClip, 1, frame.imageToClip);
  glUniform3fv(program.view, 1, frame.view);
  glUniform1f(program.skinLightness, frame.skinLightness);
}

void FaceLayers::drawFace(const FaceUniforms& face, const LayerFrame& frame) {
  if (!face.any()) return;
  FaceProgram& program = face.effects() ? faceEffects_ : face_;
  bindCommon(program, frame);
  glActiveTexture(GL_TEXTURE0 + kFaceMapUnit);
  glBindTexture(GL_TEXTURE_2D, faceMap_.get());
  glActiveTexture(GL_TEXTURE0);
  glUniformMatrix2fv(program.cheekMatrix, 1, GL_FALSE, face.cheekMatrix);
  glUniform2fv(program.cheekOffset, 1, face.cheekOffset);
  glUniform3fv(program.layerLab, kFaceLayerCount, &face.lab[0][0]);
  glUniform4f(program.layerAmount, face.amount[0] * frame.alpha, face.amount[1] * frame.alpha,
              face.amount[2] * frame.alpha, face.amount[3] * frame.alpha);
  glUniform4fv(program.layerLumaFollow, 1, face.lumaFollow);
  glUniform1f(program.highlightShine, face.highlightShine);
  if (program.effectAmount >= 0) {
    const float a = frame.alpha;
    glUniform3f(program.effectAmount, face.effectAmount[0] * a, face.effectAmount[1] * a, face.effectAmount[2] * a);
    glUniform3fv(program.effectOnSkin, 1, face.effectOnSkin);
    glUniform2f(program.effectDensity, face.glitterDensity, face.freckleDensity);
    glUniform1f(program.time, frame.timeSeconds);
  }

  glEnable(GL_BLEND);
  glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
  glBindVertexArray(faceVao_.get());
  glDrawElements(GL_TRIANGLES, mesh::kFaceRegionTriangleCount * 3, GL_UNSIGNED_SHORT, nullptr);
  glBindVertexArray(0);
  glDisable(GL_BLEND);
  MAKEUP_GL_CHECK("drawFace");
}

void FaceLayers::drawEyes(const EyeUniforms& eyes, const LayerFrame& frame) {
  if (!eyes.any()) return;
  EyesProgram& program = eyes.shimmer ? eyesShimmer_ : eyes_;
  bindCommon(program, frame);
  glActiveTexture(GL_TEXTURE0 + kEyeMapAUnit);
  glBindTexture(GL_TEXTURE_2D, eyeMapA_.get());
  glActiveTexture(GL_TEXTURE0 + kEyeMapBUnit);
  glBindTexture(GL_TEXTURE_2D, eyeMapB_.get());
  glActiveTexture(GL_TEXTURE0 + kEyeMapCUnit);
  glBindTexture(GL_TEXTURE_2D, eyeMapC_.get());
  glActiveTexture(GL_TEXTURE0);
  const float a = frame.alpha;
  glUniform3fv(program.shadowLab, kMaxEyeShadows, &eyes.shadowLab[0][0]);
  glUniform4f(program.shadowAmount, eyes.shadowAmount[0] * a, eyes.shadowAmount[1] * a,
              eyes.shadowAmount[2] * a, eyes.shadowAmount[3] * a);
  glUniform4fv(program.shadowSelect, kMaxEyeShadows, &eyes.shadowSelectA[0][0]);
  glUniform4fv(program.shadowBrowBone, 1, eyes.shadowSelectB);
  glUniform4fv(program.shadowShine, 1, eyes.shadowShine);
  glUniform3fv(program.linerLab, 1, eyes.linerLab);
  glUniform1f(program.linerAmount, eyes.linerAmount * a);
  glUniform2fv(program.linerEdge, 1, eyes.linerEdge);
  glUniform1f(program.wing, eyes.wing);
  glUniform3fv(program.lashLab, 1, eyes.lashLab);
  glUniform1f(program.lashAmount, eyes.lashAmount * a);
  glUniform1f(program.lowerLashAmount, eyes.lowerLashAmount * a);
  glUniform4fv(program.lashParams, 1, eyes.lashParams);
  glUniform1f(program.lashRoot, eyes.lashRoot);
  glUniform1f(program.eyeSheen, eyes.sheen * a);
  if (program.glitter >= 0) glUniform1f(program.glitter, eyes.glitter * a);
  if (program.time >= 0) glUniform1f(program.time, frame.timeSeconds);
  if (program.shadowSparkle >= 0) glUniform4fv(program.shadowSparkle, 1, eyes.shadowSparkle);

  glEnable(GL_BLEND);
  glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
  glBindVertexArray(eyesVao_.get());
  glDrawElements(GL_TRIANGLES, mesh::kEyeRegionTriangleCount * 3, GL_UNSIGNED_SHORT, nullptr);
  glBindVertexArray(0);
  glDisable(GL_BLEND);
  MAKEUP_GL_CHECK("drawEyes");
}

// Encima de las sombras y el delineado: solo cubre la abertura del ojo.
void FaceLayers::drawIris(const IrisUniforms& iris, const LayerFrame& frame, const float* points) {
  if (!iris.any() || points == nullptr || !irisEllipses(points, irisCenters_, irisInverse_)) return;
  glUseProgram(iris_.program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(MAKEUP_CAMERA_TEXTURE, frame.cameraTexture);
  if (iris_.uploadedDisplayVersion != frame.displayVersion) {
    glUniformMatrix4fv(iris_.displayMatrix, 1, GL_FALSE, frame.displayMatrix);
    iris_.uploadedDisplayVersion = frame.displayVersion;
  }
  glUniformMatrix4fv(iris_.texMatrix, 1, GL_FALSE, frame.texMatrix);
  glUniform4fv(iris_.imageToClip, 1, frame.imageToClip);
  glUniform3fv(iris_.view, 1, frame.view);
  glUniform2fv(iris_.irisCenter, 2, irisCenters_);
  glUniformMatrix2fv(iris_.irisShape, 2, GL_FALSE, irisInverse_);
  glUniform3fv(iris_.irisLab, 1, iris.lab);
  glUniform1f(iris_.irisAmount, iris.amount * frame.alpha);

  glEnable(GL_BLEND);
  glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
  glBindVertexArray(irisVao_.get());
  glDrawElements(GL_TRIANGLES, mesh::kEyeOpeningTriangleCount * 3, GL_UNSIGNED_SHORT, nullptr);
  glBindVertexArray(0);
  glDisable(GL_BLEND);
  MAKEUP_GL_CHECK("drawIris");
}

}  // namespace makeup
