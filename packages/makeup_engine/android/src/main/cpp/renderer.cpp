#include "renderer.h"

#include <EGL/egl.h>
#include <GLES2/gl2ext.h>

#include <cmath>
#include <cstring>
#include <ctime>

#include "color_math.h"
#include "gl_program.h"
#include "mesh/canonical_mesh.h"
#include "mesh/lips_maps.h"
#include "shader_sources.h"

namespace makeup {

namespace {

// Triangle strip de pantalla completa en clip space.
constexpr GLfloat kQuad[] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};
constexpr char kShimmerDefines[] = "#define SHIMMER 1\n";
// Color de los puntos del overlay (verde menta, visible sobre piel y fondo).
constexpr float kLandmarkColor[3] = {0.2f, 1.0f, 0.6f};
// Unidad de textura del mapa de labios (la 0 es la cámara).
constexpr int kLipsMapTextureUnit = 1;
// Ubicaciones de atributos de la capa de labios.
constexpr GLuint kPointAttribute = 0;
constexpr GLuint kUvAttribute = 1;
constexpr float kNsPerSecond = 1.0e9f;
// Si pasó más que esto entre frames (pausa, primer frame), el fundido avanza
// como si fuera un frame normal.
constexpr float kMaxFrameDtSeconds = 0.1f;
// uTime del shimmer: módulo para que el float no pierda precisión.
constexpr double kTimeWrapSeconds = 1000.0;

static_assert(sizeof(mesh::kLipsMapRg) ==
                  static_cast<size_t>(mesh::kLipsMapWidth) * mesh::kLipsMapHeight * 2,
              "mapa de labios RG8 incompleto");

int64_t monotonicNowNs() {
  timespec ts{};
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return static_cast<int64_t>(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
}

const char* glString(GLenum name) {
  const auto* value = reinterpret_cast<const char*>(glGetString(name));
  return value != nullptr ? value : "?";
}

float smoothstep(float edge0, float edge1, float x) {
  const float t = std::clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

}  // namespace

GLuint Renderer::initGl() {
  {
    std::lock_guard<std::mutex> lock(configMutex_);
    glInfo_ = std::string(glString(GL_VENDOR)) + " | " + glString(GL_RENDERER) + " | " +
              glString(GL_VERSION) + " | " + glString(GL_SHADING_LANGUAGE_VERSION);
  }
  MAKEUP_LOGI("GL: %s", glInfo().c_str());

  const char* extensions = glString(GL_EXTENSIONS);
  if (std::strstr(extensions, "GL_OES_EGL_image_external_essl3") == nullptr) {
    setError("el driver no soporta GL_OES_EGL_image_external_essl3");
    return 0;
  }

  if (!buildProgram(passthrough_, shaders::k_passthrough_frag, nullptr) ||
      !buildProgram(tint_, shaders::k_tint_oklab_frag, nullptr) || !buildMeshProgram() ||
      !buildLipsProgram(lips_, nullptr) || !buildLipsProgram(lipsShimmer_, kShimmerDefines) ||
      !buildMeshGeometry() || !buildLipsMap()) {
    return 0;
  }

  std::string error;
  if (!crop_.init(&error)) {
    setError(error);
    return 0;
  }

  GLuint vao = 0;
  glGenVertexArrays(1, &vao);
  quadVao_.reset(vao);
  GLuint vbo = 0;
  glGenBuffers(1, &vbo);
  quadVbo_.reset(vbo);
  glBindVertexArray(quadVao_.get());
  glBindBuffer(GL_ARRAY_BUFFER, quadVbo_.get());
  glBufferData(GL_ARRAY_BUFFER, sizeof(kQuad), kQuad, GL_STATIC_DRAW);
  // Todos los programas de quad usan la ubicación 0 para aPosition.
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
  glBindVertexArray(0);
  MAKEUP_GL_CHECK("quad");

  GLuint texture = 0;
  glGenTextures(1, &texture);
  cameraTexture_.reset(texture);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture);
  glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);
  MAKEUP_GL_CHECK("cameraTexture");

  glDisable(GL_DEPTH_TEST);
  glDisable(GL_BLEND);
  return texture;
}

bool Renderer::buildProgram(Program& out, const char* fragmentSource, const char* defines) {
  std::string error;
  const char* attributes[] = {"aPosition"};
  GlProgram program = buildGlProgram(shaders::k_camera_quad_vert, fragmentSource, attributes, 1,
                                     &error, defines);
  if (!program) {
    setError(error);
    return false;
  }
  out.displayMatrix = glGetUniformLocation(program.get(), "uDisplayMatrix");
  out.texMatrix = glGetUniformLocation(program.get(), "uTexMatrix");
  out.tintAb = glGetUniformLocation(program.get(), "uTintAb");
  out.tintAmount = glGetUniformLocation(program.get(), "uTintAmount");
  // El sampler siempre usa la unidad 0: se fija una vez, no por frame.
  glUseProgram(program.get());
  glUniform1i(glGetUniformLocation(program.get(), "uCamera"), 0);
  glUseProgram(0);
  out.uploadedDisplayVersion = 0;
  out.program = std::move(program);
  MAKEUP_GL_CHECK("buildProgram");
  return true;
}

bool Renderer::buildMeshProgram() {
  std::string error;
  const char* attributes[] = {"aPoint"};
  GlProgram program =
      buildGlProgram(shaders::k_face_mesh_vert, shaders::k_solid_color_frag, attributes, 1, &error);
  if (!program) {
    setError(error);
    return false;
  }
  mesh_.imageToClip = glGetUniformLocation(program.get(), "uImageToClip");
  mesh_.pointSize = glGetUniformLocation(program.get(), "uPointSize");
  mesh_.color = glGetUniformLocation(program.get(), "uColor");
  mesh_.program = std::move(program);
  return true;
}

bool Renderer::buildLipsProgram(LipsProgram& out, const char* defines) {
  std::string error;
  // Mismo orden que kPointAttribute / kUvAttribute.
  const char* attributes[] = {"aPoint", "aUv"};
  GlProgram program =
      buildGlProgram(shaders::k_lips_vert, shaders::k_lips_frag, attributes, 2, &error, defines);
  if (!program) {
    setError(error);
    return false;
  }
  const GLuint id = program.get();
  out.imageToClip = glGetUniformLocation(id, "uImageToClip");
  out.displayMatrix = glGetUniformLocation(id, "uDisplayMatrix");
  out.texMatrix = glGetUniformLocation(id, "uTexMatrix");
  out.targetLab = glGetUniformLocation(id, "uTargetLab");
  out.opacity = glGetUniformLocation(id, "uOpacity");
  out.lumaFollow = glGetUniformLocation(id, "uLumaFollow");
  out.lipLightness = glGetUniformLocation(id, "uLipLightness");
  out.gloss = glGetUniformLocation(id, "uGloss");
  out.sharpness = glGetUniformLocation(id, "uSharpness");
  out.light = glGetUniformLocation(id, "uLight");
  out.glossShift = glGetUniformLocation(id, "uGlossShift");
  out.time = glGetUniformLocation(id, "uTime");
  out.sparkle = glGetUniformLocation(id, "uSparkle");
  // Constantes de la sesión: samplers y la transformación UV -> mapa.
  const float* rect = mesh::kLipsMapUvRect;
  glUseProgram(id);
  glUniform1i(glGetUniformLocation(id, "uCamera"), 0);
  glUniform1i(glGetUniformLocation(id, "uLipsMap"), kLipsMapTextureUnit);
  glUniform4f(glGetUniformLocation(id, "uMapTransform"), 1.0f / rect[2], 1.0f / rect[3],
              -rect[0] / rect[2], -rect[1] / rect[3]);
  if (out.sparkle >= 0) glUniform1f(out.sparkle, EngineConfig::kLipsSparkle);
  glUseProgram(0);
  out.uploadedDisplayVersion = 0;
  out.program = std::move(program);
  MAKEUP_GL_CHECK("buildLipsProgram");
  return true;
}

// VBO dinámico con los puntos tracked (se actualiza por frame sin realocar),
// VBO estático con las UV canónicas e IBO estático con los triángulos de la
// zona de labios. meshVao_ (puntos) e lipsVao_ (puntos + UV + IBO) comparten
// el VBO de puntos.
bool Renderer::buildMeshGeometry() {
  GLuint vaos[2] = {0, 0};
  glGenVertexArrays(2, vaos);
  meshVao_.reset(vaos[0]);
  lipsVao_.reset(vaos[1]);
  GLuint buffers[3] = {0, 0, 0};
  glGenBuffers(3, buffers);
  meshVbo_.reset(buffers[0]);
  uvVbo_.reset(buffers[1]);
  lipsIbo_.reset(buffers[2]);

  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glBufferData(GL_ARRAY_BUFFER, sizeof(meshPoints_), nullptr, GL_DYNAMIC_DRAW);
  glBindBuffer(GL_ARRAY_BUFFER, uvVbo_.get());
  glBufferData(GL_ARRAY_BUFFER, sizeof(mesh::kUvs), mesh::kUvs, GL_STATIC_DRAW);

  glBindVertexArray(meshVao_.get());
  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glEnableVertexAttribArray(kPointAttribute);
  glVertexAttribPointer(kPointAttribute, 2, GL_FLOAT, GL_FALSE, 0, nullptr);

  glBindVertexArray(lipsVao_.get());
  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glEnableVertexAttribArray(kPointAttribute);
  glVertexAttribPointer(kPointAttribute, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
  glBindBuffer(GL_ARRAY_BUFFER, uvVbo_.get());
  glEnableVertexAttribArray(kUvAttribute);
  glVertexAttribPointer(kUvAttribute, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, lipsIbo_.get());
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(mesh::kLipsRegionTriangles),
               mesh::kLipsRegionTriangles, GL_STATIC_DRAW);

  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  MAKEUP_GL_CHECK("buildMeshGeometry");
  return true;
}

// Mapa de labios RG8 (mesh/lips_maps.h): se sube una vez. Lineal para que la
// máscara y el brillo se amplíen suaves; CLAMP_TO_EDGE con borde vacío (0)
// para que el brillo desplazado fuera del mapa no aparezca.
bool Renderer::buildLipsMap() {
  // Descarta errores previos (en release MAKEUP_GL_CHECK no los consume) para
  // que el chequeo de abajo sea solo de esta textura.
  while (glGetError() != GL_NO_ERROR) {
  }
  GLuint texture = 0;
  glGenTextures(1, &texture);
  lipsMap_.reset(texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexStorage2D(GL_TEXTURE_2D, 1, GL_RG8, mesh::kLipsMapWidth, mesh::kLipsMapHeight);
  // Filas de 256 × 2 bytes: múltiplo de 4, pero se fija por si el mapa cambia.
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, mesh::kLipsMapWidth, mesh::kLipsMapHeight, GL_RG,
                  GL_UNSIGNED_BYTE, mesh::kLipsMapRg);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindTexture(GL_TEXTURE_2D, 0);
  if (glGetError() != GL_NO_ERROR) {
    setError("no se pudo crear el mapa de labios");
    return false;
  }
  return true;
}

int Renderer::drawFrame(const float* texMatrix, int width, int height, int64_t frameStartNs,
                        int64_t cameraTimestampNs) {
  const uint32_t displayVersion = displayVersion_.load(std::memory_order_acquire);
  if (displayVersion != drawDisplayVersion_) {
    std::lock_guard<std::mutex> lock(configMutex_);  // solo cuando cambió
    drawDisplayMatrix_ = displayMatrix_;
    drawTrackerMatrix_ = trackerMatrix_;
    drawMirrored_ = mirrored_;
    drawDisplayVersion_ = displayVersion;
  }
  const uint32_t lipsVersion = lipsVersion_.load(std::memory_order_acquire);
  if (lipsVersion != drawLipsVersion_) {
    std::lock_guard<std::mutex> lock(configMutex_);  // solo al cambiar la receta
    drawLips_ = lipUniforms_;
    drawLipsVersion_ = lipsVersion;
  }

  int flags = 0;
  runCropPass(texMatrix, width, height, cameraTimestampNs, frameStartNs, &flags);

  // Malla del tracker extrapolada a este frame (si alguna opción la usa).
  const bool showLandmarks = showLandmarks_.load(std::memory_order_relaxed);
  const auto region = static_cast<TintRegion>(region_.load(std::memory_order_relaxed));
  const bool wantLips = region == TintRegion::kLips && drawLips_.enabled && drawLips_.opacity > 0.0f;
  float frameDt = lastFrameStartNs_ > 0
                      ? static_cast<float>(frameStartNs - lastFrameStartNs_) / kNsPerSecond
                      : 0.0f;
  frameDt = std::clamp(frameDt, 0.0f, kMaxFrameDtSeconds);
  lastFrameStartNs_ = frameStartNs;
  RenderLandmarks landmarks;
  const bool hasMesh = (showLandmarks || region == TintRegion::kLips) && tracking_ != nullptr &&
                       tracking_->landmarksForRender(cameraTimestampNs, frameDt, &landmarks);
  // px de imagen -> clip de la salida, con el espejo de la pantalla.
  const float sx = (drawMirrored_ ? -2.0f : 2.0f) / static_cast<float>(width);
  const float imageToClip[4] = {sx, -2.0f / static_cast<float>(height), drawMirrored_ ? 1.0f : -1.0f,
                                1.0f};
  if (hasMesh) uploadMesh(landmarks.points);

  const float amount = tintAmount_.load(std::memory_order_relaxed);
  Program* program = amount > 0.0f && region == TintRegion::kFull ? &tint_ : &passthrough_;

  glViewport(0, 0, width, height);
  // El quad cubre toda la superficie: en una GPU de tiles (Mali) esto evita
  // cargar el contenido anterior del framebuffer en cada tile.
  const GLenum colorAttachment = GL_COLOR;
  glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &colorAttachment);
  glUseProgram(program->program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, cameraTexture_.get());
  if (program->uploadedDisplayVersion != drawDisplayVersion_) {
    glUniformMatrix4fv(program->displayMatrix, 1, GL_FALSE, drawDisplayMatrix_.data());
    program->uploadedDisplayVersion = drawDisplayVersion_;
  }
  glUniformMatrix4fv(program->texMatrix, 1, GL_FALSE, texMatrix);
  if (program->tintAb >= 0) {
    glUniform2f(program->tintAb, tintA_.load(std::memory_order_relaxed),
                tintB_.load(std::memory_order_relaxed));
    glUniform1f(program->tintAmount, amount);
  }
  glBindVertexArray(quadVao_.get());
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArray(0);
  MAKEUP_GL_CHECK("drawFrame");

  // Sin cara no hay labios: queda el paso directo.
  if (wantLips && hasMesh) drawLips(landmarks, imageToClip, texMatrix, frameStartNs);
  if (showLandmarks && hasMesh) drawLandmarks(landmarks.alpha, imageToClip, width, height);

  eglSwapBuffers(eglGetCurrentDisplay(), eglGetCurrentSurface(EGL_DRAW));
  stats_.record(frameStartNs, monotonicNowNs(), cameraTimestampNs);
  return flags;
}

void Renderer::runCropPass(const float* texMatrix, int width, int height,
                           int64_t cameraTimestampNs, int64_t nowNs, int* flags) {
  if (tracking_ == nullptr) return;
  float readbackMs = 0.0f;
  switch (crop_.poll(tracking_->cropPixels(), &readbackMs, nowNs)) {
    case CropPass::Poll::kDone:
      tracking_->cropReady(readbackMs);
      *flags |= kFrameFlagCropReady;
      break;
    case CropPass::Poll::kFailed:
      tracking_->cropFailed();
      break;
    case CropPass::Poll::kIdle:
    case CropPass::Poll::kPending:
      break;
  }
  CropRequest request;
  if (!crop_.inFlight() && tracking_->takeCropRequest(cameraTimestampNs, &request) &&
      !crop_.issue(request, quadVao_.get(), cameraTexture_.get(), texMatrix,
                   drawTrackerMatrix_.data(), width, height, nowNs)) {
    tracking_->cropFailed();
  }
}

// Solo x, y de cada punto: z no se usa para dibujar.
void Renderer::uploadMesh(const float* points) {
  for (int i = 0; i < EngineConfig::kLandmarkCount; ++i) {
    meshPoints_[i * 2] = points[i * 3];
    meshPoints_[i * 2 + 1] = points[i * 3 + 1];
  }
  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(meshPoints_), meshPoints_.data());
  glBindBuffer(GL_ARRAY_BUFFER, 0);
}

// Triángulos de la zona de labios sobre el quad de cámara, sin blending: el
// shader devuelve el píxel final (cámara tal cual fuera del labio).
void Renderer::drawLips(const RenderLandmarks& landmarks, const float* imageToClip,
                        const float* texMatrix, int64_t frameStartNs) {
  LipsProgram& program = drawLips_.shimmer ? lipsShimmer_ : lips_;
  const FaceAppearance& look = landmarks.appearance;
  const float lipLightness = std::isnan(look.lipLightness) ? EngineConfig::kLipsFallbackLightness
                                                           : look.lipLightness;
  // Sin medición todavía: luz plena (no apagar el brillo por falta de dato).
  const float light =
      std::isnan(look.skinLightness)
          ? 1.0f
          : EngineConfig::kLipsLightMin +
                (1.0f - EngineConfig::kLipsLightMin) *
                    smoothstep(EngineConfig::kLipsLightDarkLightness,
                               EngineConfig::kLipsLightFullLightness, look.skinLightness);
  // El reflejo cae donde la superficie mira a la cámara: se corre hacia la
  // dirección de vista. En el shader se muestrea en (uv - shift).
  const float* rect = mesh::kLipsMapUvRect;
  const float maxShift = EngineConfig::kLipsGlossShiftMaxUv;
  const float shiftU = std::clamp(look.viewX * EngineConfig::kLipsGlossShiftPerView, -maxShift, maxShift);
  const float shiftV = std::clamp(look.viewY * EngineConfig::kLipsGlossShiftPerView, -maxShift, maxShift);

  glUseProgram(program.program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, cameraTexture_.get());
  glActiveTexture(GL_TEXTURE0 + kLipsMapTextureUnit);
  glBindTexture(GL_TEXTURE_2D, lipsMap_.get());
  glActiveTexture(GL_TEXTURE0);
  if (program.uploadedDisplayVersion != drawDisplayVersion_) {
    glUniformMatrix4fv(program.displayMatrix, 1, GL_FALSE, drawDisplayMatrix_.data());
    program.uploadedDisplayVersion = drawDisplayVersion_;
  }
  glUniformMatrix4fv(program.texMatrix, 1, GL_FALSE, texMatrix);
  glUniform4fv(program.imageToClip, 1, imageToClip);
  glUniform3fv(program.targetLab, 1, drawLips_.targetLab);
  glUniform1f(program.opacity, drawLips_.opacity * landmarks.alpha);
  glUniform1f(program.lumaFollow, drawLips_.lumaFollow);
  glUniform1f(program.lipLightness, lipLightness);
  glUniform1f(program.gloss, drawLips_.gloss);
  glUniform1f(program.sharpness, drawLips_.sharpness);
  glUniform1f(program.light, light);
  glUniform2f(program.glossShift, shiftU / rect[2], shiftV / rect[3]);
  if (program.time >= 0) {
    const double seconds = static_cast<double>(frameStartNs) / 1.0e9;
    glUniform1f(program.time, static_cast<float>(std::fmod(seconds, kTimeWrapSeconds)));
  }
  glBindVertexArray(lipsVao_.get());
  glDrawElements(GL_TRIANGLES, mesh::kLipsRegionTriangleCount * 3, GL_UNSIGNED_SHORT, nullptr);
  glBindVertexArray(0);
  MAKEUP_GL_CHECK("drawLips");
}

void Renderer::drawLandmarks(float alpha, const float* imageToClip, int width, int height) {
  glViewport(0, 0, width, height);
  glEnable(GL_BLEND);
  // El alpha del framebuffer queda en 1: Flutter compone la Texture con alpha
  // y, si bajara durante el fundido, se vería el fondo a través de los puntos.
  glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
  glUseProgram(mesh_.program.get());
  glUniform4fv(mesh_.imageToClip, 1, imageToClip);
  glUniform1f(mesh_.pointSize, EngineConfig::kLandmarkPointSizePx);
  glUniform4f(mesh_.color, kLandmarkColor[0], kLandmarkColor[1], kLandmarkColor[2], alpha);
  glBindVertexArray(meshVao_.get());
  glDrawArrays(GL_POINTS, 0, EngineConfig::kLandmarkCount);
  glBindVertexArray(0);
  glDisable(GL_BLEND);
  MAKEUP_GL_CHECK("drawLandmarks");
}

void Renderer::releaseGl() {
  crop_.release();
  passthrough_.program.reset();
  tint_.program.reset();
  mesh_.program.reset();
  lips_.program.reset();
  lipsShimmer_.program.reset();
  quadVbo_.reset();
  quadVao_.reset();
  meshVbo_.reset();
  uvVbo_.reset();
  lipsIbo_.reset();
  meshVao_.reset();
  lipsVao_.reset();
  lipsMap_.reset();
  cameraTexture_.reset();
}

void Renderer::setTint(float r, float g, float b, float amount) {
  const Vec3 lab = srgbToOklab(std::clamp(r, 0.0f, 1.0f), std::clamp(g, 0.0f, 1.0f),
                               std::clamp(b, 0.0f, 1.0f));
  tintA_.store(lab.y, std::memory_order_relaxed);
  tintB_.store(lab.z, std::memory_order_relaxed);
  tintAmount_.store(std::clamp(amount, 0.0f, 1.0f), std::memory_order_relaxed);
}

void Renderer::setLips(const LipStyle& style) {
  LipUniforms uniforms;
  uniforms.enabled = style.enabled;
  const Vec3 lab = srgbToOklab(std::clamp(style.r, 0.0f, 1.0f), std::clamp(style.g, 0.0f, 1.0f),
                               std::clamp(style.b, 0.0f, 1.0f));
  uniforms.targetLab[0] = lab.x;
  uniforms.targetLab[1] = lab.y;
  uniforms.targetLab[2] = lab.z;
  uniforms.opacity = std::clamp(style.opacity, 0.0f, 1.0f);
  uniforms.lumaFollow = std::clamp(style.lumaFollow, 0.0f, 1.0f);
  const float gloss = std::clamp(style.gloss, 0.0f, 1.0f);
  switch (style.finish) {
    case LipFinish::kMatte:
      uniforms.gloss = 0.0f;
      break;
    case LipFinish::kGloss:
      uniforms.gloss = gloss;
      uniforms.sharpness = EngineConfig::kLipsSharpnessGloss;
      break;
    case LipFinish::kShimmer:
      uniforms.shimmer = true;
      [[fallthrough]];
    case LipFinish::kSatin:
      uniforms.gloss = gloss * EngineConfig::kLipsSatinGlossScale;
      uniforms.sharpness = EngineConfig::kLipsSharpnessSatin;
      break;
  }
  std::lock_guard<std::mutex> lock(configMutex_);
  lipUniforms_ = uniforms;
  lipsVersion_.fetch_add(1, std::memory_order_release);
}

void Renderer::setDisplayMatrices(const float* display, const float* tracker, bool mirrored) {
  std::lock_guard<std::mutex> lock(configMutex_);
  std::copy_n(display, 16, displayMatrix_.begin());
  std::copy_n(tracker, 16, trackerMatrix_.begin());
  mirrored_ = mirrored;
  displayVersion_.fetch_add(1, std::memory_order_release);
}

void Renderer::setRenderOptions(bool showLandmarks, TintRegion region) {
  showLandmarks_.store(showLandmarks, std::memory_order_relaxed);
  region_.store(static_cast<int>(region), std::memory_order_relaxed);
}

std::string Renderer::glInfo() const {
  std::lock_guard<std::mutex> lock(configMutex_);
  return glInfo_;
}

std::string Renderer::lastError() const {
  std::lock_guard<std::mutex> lock(configMutex_);
  return lastError_;
}

void Renderer::setError(const std::string& error) {
  MAKEUP_LOGE("%s", error.c_str());
  std::lock_guard<std::mutex> lock(configMutex_);
  lastError_ = error;
}

}  // namespace makeup
