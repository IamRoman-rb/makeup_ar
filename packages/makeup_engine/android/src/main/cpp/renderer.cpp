#include "renderer.h"

#include <EGL/egl.h>
#include <GLES2/gl2ext.h>

#include <cstring>
#include <ctime>

#include "color_math.h"
#include "gl_program.h"
#include "mesh/canonical_mesh.h"
#include "shader_sources.h"

namespace makeup {

namespace {

// Triangle strip de pantalla completa en clip space.
constexpr GLfloat kQuad[] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};
constexpr char kMaskedDefines[] = "#define MASKED 1\n";
// Color de los puntos del overlay (verde menta, visible sobre piel y fondo).
constexpr float kLandmarkColor[3] = {0.2f, 1.0f, 0.6f};
// Unidad de textura de la máscara (la 0 es la cámara).
constexpr int kMaskTextureUnit = 1;
constexpr float kNsPerSecond = 1.0e9f;
// Si pasó más que esto entre frames (pausa, primer frame), el fundido avanza
// como si fuera un frame normal.
constexpr float kMaxFrameDtSeconds = 0.1f;

int64_t monotonicNowNs() {
  timespec ts{};
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return static_cast<int64_t>(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
}

const char* glString(GLenum name) {
  const auto* value = reinterpret_cast<const char*>(glGetString(name));
  return value != nullptr ? value : "?";
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
      !buildProgram(tint_, shaders::k_tint_oklab_frag, nullptr) ||
      !buildProgram(tintMasked_, shaders::k_tint_oklab_frag, kMaskedDefines) ||
      !buildMeshProgram() || !buildMeshGeometry()) {
    return 0;
  }
  glUseProgram(tintMasked_.program.get());
  glUniform1i(glGetUniformLocation(tintMasked_.program.get(), "uMask"), kMaskTextureUnit);
  glUseProgram(0);

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

// VBO dinámico con los puntos (se actualiza por frame sin realocar) e IBO
// estático con los triángulos de los labios de la malla canónica.
bool Renderer::buildMeshGeometry() {
  GLuint vao = 0;
  glGenVertexArrays(1, &vao);
  meshVao_.reset(vao);
  GLuint vbo = 0;
  glGenBuffers(1, &vbo);
  meshVbo_.reset(vbo);
  GLuint ibo = 0;
  glGenBuffers(1, &ibo);
  lipsIbo_.reset(ibo);

  glBindVertexArray(meshVao_.get());
  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glBufferData(GL_ARRAY_BUFFER, sizeof(meshPoints_), nullptr, GL_DYNAMIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, lipsIbo_.get());
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(mesh::kLipTriangles), mesh::kLipTriangles,
               GL_STATIC_DRAW);
  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  MAKEUP_GL_CHECK("buildMeshGeometry");
  return true;
}

// Textura R8 a 1/kMaskDownscale de la salida. Se crea la primera vez que se
// usa (o si cambia el tamaño de salida), nunca por frame.
bool Renderer::ensureMask(int width, int height) {
  const int maskWidth = std::max(1, width / EngineConfig::kMaskDownscale);
  const int maskHeight = std::max(1, height / EngineConfig::kMaskDownscale);
  if (maskWidth == maskWidth_ && maskHeight == maskHeight_) {
    // Ya creada, o ya falló con este tamaño: no se reintenta en cada frame.
    return static_cast<bool>(maskFramebuffer_);
  }
  maskWidth_ = maskWidth;
  maskHeight_ = maskHeight;
  maskFramebuffer_.reset();
  maskTexture_.reset();
  GLuint texture = 0;
  glGenTextures(1, &texture);
  maskTexture_.reset(texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexStorage2D(GL_TEXTURE_2D, 1, GL_R8, maskWidth, maskHeight);
  // Lineal: al ampliar la máscara chica, el borde sale suave sin costo extra.
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindTexture(GL_TEXTURE_2D, 0);
  GLuint framebuffer = 0;
  glGenFramebuffers(1, &framebuffer);
  maskFramebuffer_.reset(framebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
  const bool complete = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  if (!complete) {
    maskFramebuffer_.reset();
    maskTexture_.reset();
    setError("FBO de máscara incompleto");
    return false;
  }
  MAKEUP_GL_CHECK("ensureMask");
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

  int flags = 0;
  runCropPass(texMatrix, width, height, cameraTimestampNs, frameStartNs, &flags);

  // Malla del tracker extrapolada a este frame (si alguna opción la usa).
  const bool showLandmarks = showLandmarks_.load(std::memory_order_relaxed);
  const auto region = static_cast<TintRegion>(region_.load(std::memory_order_relaxed));
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
  Program* program = &passthrough_;
  if (amount > 0.0f && region == TintRegion::kFull) {
    program = &tint_;
  } else if (amount > 0.0f && hasMesh && ensureMask(width, height)) {
    // Solo labios: sin cara no hay máscara y se dibuja en paso directo.
    drawLipsMask(landmarks.alpha, imageToClip);
    program = &tintMasked_;
  }

  glViewport(0, 0, width, height);
  // El quad cubre toda la superficie: en una GPU de tiles (Mali) esto evita
  // cargar el contenido anterior del framebuffer en cada tile.
  const GLenum colorAttachment = GL_COLOR;
  glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &colorAttachment);
  glUseProgram(program->program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, cameraTexture_.get());
  if (program == &tintMasked_) {
    glActiveTexture(GL_TEXTURE0 + kMaskTextureUnit);
    glBindTexture(GL_TEXTURE_2D, maskTexture_.get());
    glActiveTexture(GL_TEXTURE0);
  }
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

void Renderer::drawLipsMask(float alpha, const float* imageToClip) {
  glBindFramebuffer(GL_FRAMEBUFFER, maskFramebuffer_.get());
  glViewport(0, 0, maskWidth_, maskHeight_);
  glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  glUseProgram(mesh_.program.get());
  glUniform4fv(mesh_.imageToClip, 1, imageToClip);
  glUniform4f(mesh_.color, alpha, 0.0f, 0.0f, 1.0f);
  glBindVertexArray(meshVao_.get());
  glDrawElements(GL_TRIANGLES, mesh::kLipTriangleCount * 3, GL_UNSIGNED_SHORT, nullptr);
  glBindVertexArray(0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  MAKEUP_GL_CHECK("drawLipsMask");
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
  tintMasked_.program.reset();
  mesh_.program.reset();
  quadVbo_.reset();
  quadVao_.reset();
  meshVbo_.reset();
  lipsIbo_.reset();
  meshVao_.reset();
  maskFramebuffer_.reset();
  maskTexture_.reset();
  cameraTexture_.reset();
}

void Renderer::setTint(float r, float g, float b, float amount) {
  const Vec3 lab = srgbToOklab(std::clamp(r, 0.0f, 1.0f), std::clamp(g, 0.0f, 1.0f),
                               std::clamp(b, 0.0f, 1.0f));
  tintA_.store(lab.y, std::memory_order_relaxed);
  tintB_.store(lab.z, std::memory_order_relaxed);
  tintAmount_.store(std::clamp(amount, 0.0f, 1.0f), std::memory_order_relaxed);
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
