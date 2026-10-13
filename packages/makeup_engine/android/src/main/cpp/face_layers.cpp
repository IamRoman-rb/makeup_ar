#include "face_layers.h"

#include <GLES2/gl2ext.h>

#include "engine_config.h"
#include "gl_program.h"
#include "mesh/eye_maps.h"
#include "mesh/face_maps.h"
#include "mesh/mesh_normals.h"
#include "shader_sources.h"

namespace makeup {

namespace {

constexpr char kShimmerDefines[] = "#define SHIMMER 1\n";
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
  return buildFaceProgram(error) && buildEyesProgram(eyes_, nullptr, error) &&
         buildEyesProgram(eyesShimmer_, kShimmerDefines, error) && buildGeometry(pointVbo, uvVbo, normalVbo) &&
         buildTextures(error);
}

void FaceLayers::release() {
  face_.program.reset();
  eyes_.program.reset();
  eyesShimmer_.program.reset();
  faceVao_.reset();
  eyesVao_.reset();
  faceIbo_.reset();
  eyesIbo_.reset();
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

bool FaceLayers::buildFaceProgram(std::string* error) {
  if (!buildCommon(face_, shaders::k_face_frag, nullptr, mesh::kFaceMapUvRect, error)) return false;
  const GLuint id = face_.program.get();
  face_.cheekMatrix = glGetUniformLocation(id, "uCheekMatrix");
  face_.cheekOffset = glGetUniformLocation(id, "uCheekOffset");
  face_.layerLab = glGetUniformLocation(id, "uLayerLab[0]");
  face_.layerAmount = glGetUniformLocation(id, "uLayerAmount");
  face_.layerLumaFollow = glGetUniformLocation(id, "uLayerLumaFollow");
  face_.highlightShine = glGetUniformLocation(id, "uHighlightShine");
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

// VAOs de cara y ojos sobre los VBOs del Renderer (puntos dinámicos, UV y
// normales estáticas) con su IBO estático cada uno.
bool FaceLayers::buildGeometry(GLuint pointVbo, GLuint uvVbo, GLuint normalVbo) {
  GLuint vaos[2] = {0, 0};
  glGenVertexArrays(2, vaos);
  faceVao_.reset(vaos[0]);
  eyesVao_.reset(vaos[1]);
  GLuint buffers[2] = {0, 0};
  glGenBuffers(2, buffers);
  faceIbo_.reset(buffers[0]);
  eyesIbo_.reset(buffers[1]);

  struct Zone {
    GLuint vao;
    GLuint ibo;
    const uint16_t* indices;
    size_t bytes;
  };
  const Zone zones[2] = {
      {faceVao_.get(), faceIbo_.get(), mesh::kFaceRegionTriangles, sizeof(mesh::kFaceRegionTriangles)},
      {eyesVao_.get(), eyesIbo_.get(), mesh::kEyeRegionTriangles, sizeof(mesh::kEyeRegionTriangles)},
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
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, frame.cameraTexture);
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
  bindCommon(face_, frame);
  glActiveTexture(GL_TEXTURE0 + kFaceMapUnit);
  glBindTexture(GL_TEXTURE_2D, faceMap_.get());
  glActiveTexture(GL_TEXTURE0);
  glUniformMatrix2fv(face_.cheekMatrix, 1, GL_FALSE, face.cheekMatrix);
  glUniform2fv(face_.cheekOffset, 1, face.cheekOffset);
  glUniform3fv(face_.layerLab, kFaceLayerCount, &face.lab[0][0]);
  glUniform4f(face_.layerAmount, face.amount[0] * frame.alpha, face.amount[1] * frame.alpha,
              face.amount[2] * frame.alpha, face.amount[3] * frame.alpha);
  glUniform4fv(face_.layerLumaFollow, 1, face.lumaFollow);
  glUniform1f(face_.highlightShine, face.highlightShine);

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

}  // namespace makeup
