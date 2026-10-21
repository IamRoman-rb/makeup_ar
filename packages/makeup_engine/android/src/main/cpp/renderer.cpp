#include "renderer.h"

#if !defined(MAKEUP_PLATFORM_IOS)
#include <EGL/egl.h>
#endif

#include <algorithm>
#include <cmath>
#include <cstring>
#include <ctime>
#include <vector>

#include "color_math.h"
#include "gl_program.h"
#include "mesh/canonical_mesh.h"
#include "mesh/lips_maps.h"
#include "mesh/mesh_normals.h"
#include "mesh/subdivision.h"
#include "shader_sources.h"
#include "studio/live_look_sample.h"

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
constexpr GLuint kNormalAttribute = 2;
constexpr float kNsPerSecond = 1.0e9f;
// Si pasó más que esto entre frames (pausa, primer frame), el fundido avanza
// como si fuera un frame normal.
constexpr float kMaxFrameDtSeconds = 0.1f;
// uTime del shimmer: módulo para que el float no pierda precisión.
constexpr double kTimeWrapSeconds = 1000.0;

static_assert(sizeof(mesh::kLipsMapRgba) ==
                  static_cast<size_t>(mesh::kLipsMapWidth) * mesh::kLipsMapHeight * 4,
              "mapa de labios RGBA8 incompleto");

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

#if !defined(MAKEUP_PLATFORM_IOS)
  // En iOS la cámara llega como textura 2D: no hace falta la extensión.
  const char* extensions = glString(GL_EXTENSIONS);
  if (std::strstr(extensions, "GL_OES_EGL_image_external_essl3") == nullptr) {
    setError("el driver no soporta GL_OES_EGL_image_external_essl3");
    return 0;
  }
#endif

  if (!buildProgram(passthrough_, shaders::k_passthrough_frag, nullptr) ||
      !buildProgram(tint_, shaders::k_tint_oklab_frag, nullptr) || !buildMeshProgram() ||
      !buildLipsProgram(lips_, nullptr) || !buildLipsProgram(lipsShimmer_, kShimmerDefines) ||
      !buildMeshGeometry() || !buildLipsMap()) {
    return 0;
  }
  {
    std::string layersError;
    if (!faceLayers_.init(meshVbo_.get(), uvVbo_.get(), normalVbo_.get(), &layersError)) {
      setError(layersError);
      return 0;
    }
  }

  std::string error;
  if (!scene_.init(&error)) {
    setError(error);
    return false;
  }
  if (!crop_.init(&error) || !lookSample_.init(&error)) {
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
  glBindTexture(MAKEUP_CAMERA_TEXTURE, texture);
  glTexParameteri(MAKEUP_CAMERA_TEXTURE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(MAKEUP_CAMERA_TEXTURE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(MAKEUP_CAMERA_TEXTURE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(MAKEUP_CAMERA_TEXTURE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindTexture(MAKEUP_CAMERA_TEXTURE, 0);
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
  // Mismo orden que kPointAttribute / kUvAttribute / kNormalAttribute.
  const char* attributes[] = {"aPoint", "aUv", "aNormal"};
  GlProgram program =
      buildGlProgram(shaders::k_lips_vert, shaders::k_lips_frag, attributes, 3, &error, defines);
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
  out.glossShift = glGetUniformLocation(id, "uGlossShift");  // en lips.vert
  out.view = glGetUniformLocation(id, "uView");
  out.time = glGetUniformLocation(id, "uTime");
  out.sparkle = glGetUniformLocation(id, "uSparkle");
  out.linerLab = glGetUniformLocation(id, "uLinerLab");
  out.linerAmount = glGetUniformLocation(id, "uLinerAmount");
  out.occlusionGate = glGetUniformLocation(id, "uOcclusionGate");
  out.edgeRefine = glGetUniformLocation(id, "uEdgeRefine");
  out.occlusion = glGetUniformLocation(id, "uOcclusion");
  // Constantes de la sesión: samplers y la transformación UV -> mapa.
  const float* rect = mesh::kLipsMapUvRect;
  glUseProgram(id);
  glUniform1i(glGetUniformLocation(id, "uCamera"), 0);
  glUniform1i(glGetUniformLocation(id, "uLipsMap"), kLipsMapTextureUnit);
  glUniform1f(glGetUniformLocation(id, "uLinerEdge"), EngineConfig::kLipLinerEdge);
  glUniform4f(glGetUniformLocation(id, "uMapTransform"), 1.0f / rect[2], 1.0f / rect[3],
              -rect[0] / rect[2], -rect[1] / rect[3]);
  glUniform2f(glGetUniformLocation(id, "uFacingFade"), EngineConfig::kLipsFacingFadeStart,
              EngineConfig::kLipsFacingFadeEnd);
  glUseProgram(0);
  out.uploadedDisplayVersion = 0;
  out.program = std::move(program);
  MAKEUP_GL_CHECK("buildLipsProgram");
  return true;
}

// VBO dinámico con los puntos tracked (se actualiza por frame sin realocar),
// VBOs estáticos con las UV y las normales canónicas e IBO estático con los
// triángulos de la zona de labios. meshVao_ (puntos) e lipsVao_ (puntos + UV
// + normales + IBO) comparten el VBO de puntos.
bool Renderer::buildMeshGeometry() {
  GLuint vaos[2] = {0, 0};
  glGenVertexArrays(2, vaos);
  meshVao_.reset(vaos[0]);
  lipsVao_.reset(vaos[1]);
  GLuint buffers[4] = {0, 0, 0, 0};
  glGenBuffers(4, buffers);
  meshVbo_.reset(buffers[0]);
  uvVbo_.reset(buffers[1]);
  normalVbo_.reset(buffers[2]);
  lipsIbo_.reset(buffers[3]);

  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glBufferData(GL_ARRAY_BUFFER, sizeof(meshPoints_), nullptr, GL_DYNAMIC_DRAW);
  // Malla suave (mesh/subdivision.h): UV, normales e índices de la malla
  // subdividida. Una vez por contexto GL (no por frame): ~90 KB temporales.
  std::vector<uint16_t> lipsIndices(static_cast<size_t>(mesh::kLipsRegionTriangleCount) * 12);
  {
    std::vector<float> uvs(static_cast<size_t>(mesh::kSubVertexCount) * 2);
    mesh::subdividedUvs(uvs.data());
    glBindBuffer(GL_ARRAY_BUFFER, uvVbo_.get());
    glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(uvs.size() * sizeof(float)), uvs.data(), GL_STATIC_DRAW);

    std::vector<float> positions(static_cast<size_t>(mesh::kSubVertexCount) * 3);
    mesh::subdividePositions(mesh::kPositions, EngineConfig::kSmoothMeshMaxOffset, positions.data());
    std::vector<uint16_t> triangles(static_cast<size_t>(mesh::kTriangleCount) * 12);
    if (!mesh::subdivideTriangles(mesh::kTriangles, mesh::kTriangleCount, triangles.data()) ||
        !mesh::subdivideTriangles(mesh::kLipsRegionTriangles, mesh::kLipsRegionTriangleCount, lipsIndices.data())) {
      setError("malla suave: arista que no está en la malla");
      return false;
    }
    std::vector<float> normals(static_cast<size_t>(mesh::kSubVertexCount) * mesh::kNormalComponents);
    mesh::computeNormals(positions.data(), mesh::kSubVertexCount, triangles.data(), mesh::kTriangleCount * 4,
                         normals.data());
    glBindBuffer(GL_ARRAY_BUFFER, normalVbo_.get());
    glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(normals.size() * sizeof(float)),
                 normals.data(), GL_STATIC_DRAW);
  }

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
  glBindBuffer(GL_ARRAY_BUFFER, normalVbo_.get());
  glEnableVertexAttribArray(kNormalAttribute);
  glVertexAttribPointer(kNormalAttribute, mesh::kNormalComponents, GL_FLOAT, GL_FALSE, 0, nullptr);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, lipsIbo_.get());
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(lipsIndices.size() * sizeof(uint16_t)),
               lipsIndices.data(), GL_STATIC_DRAW);

  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  MAKEUP_GL_CHECK("buildMeshGeometry");
  return true;
}

// Mapa de labios RGBA8 (mesh/lips_maps.h): se sube una vez. Lineal para que la
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
  glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, mesh::kLipsMapWidth, mesh::kLipsMapHeight);
  // Filas de 256 × 2 bytes: múltiplo de 4, pero se fija por si el mapa cambia.
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, mesh::kLipsMapWidth, mesh::kLipsMapHeight, GL_RGBA,
                  GL_UNSIGNED_BYTE, mesh::kLipsMapRgba);
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
  const uint32_t recipeVersion = recipeVersion_.load(std::memory_order_acquire);
  bool adapt = false;
  if (recipeVersion != drawRecipeVersion_) {
    std::lock_guard<std::mutex> lock(configMutex_);  // solo al cambiar la receta
    baseLips_ = lipUniforms_;
    baseFace_ = faceUniforms_;
    baseEyes_ = eyeUniforms_;
    baseIris_ = irisUniforms_;
    drawRecipeVersion_ = recipeVersion;
    adapt = true;
  }
  // Antes de decidir qué se dibuja: draw*_ ya tiene la receta nueva.
  const bool lightAdaptation = lightAdaptation_.load(std::memory_order_relaxed);
  if (lightAdaptation != drawLightAdapted_) adapt = true;
  if (adapt) adaptRecipeColors(lightAdaptation);

  int flags = 0;
  runCropPass(texMatrix, width, height, cameraTimestampNs, frameStartNs, &flags);

  // Malla del tracker extrapolada a este frame (si alguna opción la usa).
  const bool showLandmarks = showLandmarks_.load(std::memory_order_relaxed);
  const auto region = static_cast<TintRegion>(region_.load(std::memory_order_relaxed));
  const bool wantLips = region == TintRegion::kMakeup && drawLips_.enabled && drawLips_.opacity > 0.0f;
  const bool wantFace =
      region == TintRegion::kMakeup && (drawFace_.any() || drawEyes_.any() || drawIris_.any());
  float frameDt = lastFrameStartNs_ > 0
                      ? static_cast<float>(frameStartNs - lastFrameStartNs_) / kNsPerSecond
                      : 0.0f;
  frameDt = std::clamp(frameDt, 0.0f, kMaxFrameDtSeconds);
  lastFrameStartNs_ = frameStartNs;
  RenderLandmarks landmarks;
  const bool hasMesh = (showLandmarks || region == TintRegion::kMakeup) && tracking_ != nullptr &&
                       tracking_->landmarksForRender(cameraTimestampNs, frameDt, &landmarks);
  // px de imagen -> clip de la salida, con el espejo de la pantalla.
  const float sx = (drawMirrored_ ? -2.0f : 2.0f) / static_cast<float>(width);
  const float imageToClip[4] = {sx, -2.0f / static_cast<float>(height), drawMirrored_ ? 1.0f : -1.0f,
                                1.0f};
  // Solo si algo la dibuja: en la guía de maquillaje hay cara pero no receta.
  if (hasMesh && (wantLips || wantFace || showLandmarks)) uploadMesh(landmarks.points);
  runLookSample(hasMesh ? landmarks.points : nullptr, landmarks.alpha, texMatrix, width, height);
  // Luz de la escena: una miniatura cada ~0,5 s, sin la cara; los colores se
  // vuelven a adaptar solo si la ganancia cambió (o la receta, o la opción).
  // Solo si hay maquillaje que adaptar y cara: cada lectura cierra un render
  // pass chico en Mali, y sin cara la piel entraría en el gray-world.
  if (lightAdaptation && hasMesh && (wantLips || wantFace)) {
    float face[4];
    if (scene_.poll() && faceRect(landmarks.points, width, height, face) &&
        sceneLight_.update(scene_.pixels(), EngineConfig::kScenePassSize, face)) {
      adaptRecipeColors(true);
    }
    scene_.maybeIssue(quadVao_.get(), cameraTexture(), texMatrix, drawTrackerMatrix_.data(), frameStartNs);
  }

  const float amount = tintAmount_.load(std::memory_order_relaxed);
  Program* program = amount > 0.0f && region == TintRegion::kFull ? &tint_ : &passthrough_;

  // Las pasadas de recorte y de escena dejan el framebuffer 0; la salida puede
  // ser otro (iOS: FBO sobre el CVPixelBuffer de Flutter).
  const GLuint outputFramebuffer = outputFramebuffer_.load(std::memory_order_relaxed);
  glBindFramebuffer(GL_FRAMEBUFFER, outputFramebuffer);
  glViewport(0, 0, width, height);
  // El quad cubre toda la superficie: en una GPU de tiles (Mali) esto evita
  // cargar el contenido anterior del framebuffer en cada tile. GL_COLOR solo
  // vale para el framebuffer por defecto; en un FBO, el adjunto 0.
  const GLenum colorAttachment = outputFramebuffer == 0 ? GL_COLOR : GL_COLOR_ATTACHMENT0;
  glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &colorAttachment);
  glUseProgram(program->program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(MAKEUP_CAMERA_TEXTURE, cameraTexture());
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

  // Sin cara no hay maquillaje: queda el paso directo. Orden de las capas:
  // cara (base, contorno, rubor, iluminador), ojos, iris, labios.
  if (wantFace && hasMesh) drawFaceLayers(landmarks, imageToClip, texMatrix, frameStartNs);
  if (wantLips && hasMesh) drawLips(landmarks, imageToClip, texMatrix, frameStartNs);
  if (showLandmarks && hasMesh) drawLandmarks(landmarks.alpha, imageToClip, width, height);

#if !defined(MAKEUP_PLATFORM_IOS)
  eglSwapBuffers(eglGetCurrentDisplay(), eglGetCurrentSurface(EGL_DRAW));
#endif
  // En iOS presenta la plataforma: blit al CVPixelBuffer, fence y un solo
  // glFlush (EngineSession.swift).
  stats_.record(frameStartNs, monotonicNowNs(), cameraTimestampNs);
  return flags;
}

// Rectángulo de la cara (x0, y0, x1, y1) en la imagen normalizada, con margen.
bool Renderer::faceRect(const float* points, int width, int height, float out[4]) {
  float minX = points[0];
  float maxX = points[0];
  float minY = points[1];
  float maxY = points[1];
  for (int i = 1; i < mesh::kVertexCount; ++i) {
    minX = std::min(minX, points[i * 3]);
    maxX = std::max(maxX, points[i * 3]);
    minY = std::min(minY, points[i * 3 + 1]);
    maxY = std::max(maxY, points[i * 3 + 1]);
  }
  if (width <= 0 || height <= 0 || maxX <= minX || maxY <= minY) return false;
  const float marginX = (maxX - minX) * EngineConfig::kLightAdaptFaceMargin;
  const float marginY = (maxY - minY) * EngineConfig::kLightAdaptFaceMargin;
  out[0] = (minX - marginX) / static_cast<float>(width);
  out[1] = (minY - marginY) / static_cast<float>(height);
  out[2] = (maxX + marginX) / static_cast<float>(width);
  out[3] = (maxY + marginY) / static_cast<float>(height);
  return true;
}

// draw*_ = colores de la receta bajo la luz de la escena (o tal cual, sin
// adaptación). Pocos colores, sin allocations: solo cuando algo cambió.
void Renderer::adaptRecipeColors(bool enabled) {
  drawLips_ = baseLips_;
  drawFace_ = baseFace_;
  drawEyes_ = baseEyes_;
  drawIris_ = baseIris_;
  drawLightAdapted_ = enabled;
  if (!enabled) return;
  const Vec3& gain = sceneLight_.gain();
  adaptOklab(drawLips_.targetLab, gain);
  adaptOklab(drawLips_.linerLab, gain);
  for (auto& lab : drawFace_.lab) adaptOklab(lab, gain);
  for (auto& lab : drawEyes_.shadowLab) adaptOklab(lab, gain);
  adaptOklab(drawEyes_.linerLab, gain);
  adaptOklab(drawEyes_.lashLab, gain);
  adaptOklab(drawIris_.lab, gain);
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
      !crop_.issue(request, quadVao_.get(), cameraTexture(), texMatrix,
                   drawTrackerMatrix_.data(), width, height, nowNs)) {
    tracking_->cropFailed();
  }
}

// Solo x, y de cada punto: z no se usa para dibujar. La malla suave y, al
// final, los puntos del iris (los usa el overlay).
void Renderer::uploadMesh(const float* points) {
  mesh::subdividePoints(points, smoothMesh_.load(std::memory_order_relaxed), EngineConfig::kSmoothMeshMaxOffset,
                        meshPoints_.data());
  for (int i = 0; i < kIrisPointCount; ++i) {
    const int source = (mesh::kVertexCount + i) * 3;
    const int target = (mesh::kSubVertexCount + i) * 2;
    meshPoints_[target] = points[source];
    meshPoints_[target + 1] = points[source + 1];
  }
  glBindBuffer(GL_ARRAY_BUFFER, meshVbo_.get());
  glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(meshPoints_), meshPoints_.data());
  glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void Renderer::drawFaceLayers(const RenderLandmarks& landmarks, const float* imageToClip,
                              const float* texMatrix, int64_t frameStartNs) {
  const FaceAppearance& look = landmarks.appearance;
  LayerFrame frame;
  frame.cameraTexture = cameraTexture();
  frame.imageToClip = imageToClip;
  frame.displayMatrix = drawDisplayMatrix_.data();
  frame.displayVersion = drawDisplayVersion_;
  frame.texMatrix = texMatrix;
  frame.view[0] = look.viewX;
  frame.view[1] = look.viewY;
  frame.view[2] = look.viewZ;
  // Los shaders dividen por ella (sombreado relativo a la piel).
  frame.skinLightness = std::isnan(look.skinLightness)
                            ? EngineConfig::kLipsFallbackLightness
                            : std::max(look.skinLightness, EngineConfig::kLipsMinLightness);
  frame.alpha = landmarks.alpha;
  frame.timeSeconds =
      static_cast<float>(std::fmod(static_cast<double>(frameStartNs) / 1.0e9, kTimeWrapSeconds));
  faceLayers_.drawFace(drawFace_, frame);
  faceLayers_.drawEyes(drawEyes_, frame);
  faceLayers_.drawIris(drawIris_, frame, landmarks.points);
}

// Triángulos de la zona de labios encima de lo ya dibujado (cámara y capas de
// cara), con blending premultiplicado (color.glsl: layerOver). El alpha del
// framebuffer queda en 1.
void Renderer::drawLips(const RenderLandmarks& landmarks, const float* imageToClip,
                        const float* texMatrix, int64_t frameStartNs) {
  LipsProgram& program = drawLips_.shimmer ? lipsShimmer_ : lips_;
  const FaceAppearance& look = landmarks.appearance;
  // El shader divide por ella (sombreado relativo del labio).
  const float lipLightness = std::isnan(look.lipLightness)
                                 ? EngineConfig::kLipsFallbackLightness
                                 : std::max(look.lipLightness, EngineConfig::kLipsMinLightness);
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
  glBindTexture(MAKEUP_CAMERA_TEXTURE, cameraTexture());
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
  if (program.sparkle >= 0) glUniform1f(program.sparkle, drawLips_.sparkle);
  glUniform3fv(program.linerLab, 1, drawLips_.linerLab);
  glUniform1f(program.linerAmount, drawLips_.linerAmount * landmarks.alpha);
  glUniform1f(program.occlusionGate, look.occlusionGate);
  // Borde real (tools/lips/lip_shading.py: edge_strength): hace falta el eje
  // piel->labio que aprendió la oclusión; sin él la croma no distingue el labio
  // de la piel. La fuerza sube con el contraste |labio − piel| = 1 / |eje|
  // entre kOcclusionMinContrast y el doble: sin saltos cuando el eje aparece.
  float edgeRefine = 0.0f;
  const float axisNorm = std::hypot(look.occlusionAxisA, look.occlusionAxisB);
  if (lipEdgeRefine_.load(std::memory_order_relaxed) && axisNorm > 0.0f) {
    edgeRefine = EngineConfig::kLipEdgeRefineStrength *
                 smoothstep(EngineConfig::kOcclusionMinContrast, 2.0f * EngineConfig::kOcclusionMinContrast,
                            1.0f / axisNorm);
  }
  glUniform1f(program.edgeRefine, edgeRefine);
  glUniform4f(program.occlusion, look.skinChromaA, look.skinChromaB, look.occlusionAxisA, look.occlusionAxisB);
  glUniform1f(program.sharpness, drawLips_.sharpness);
  glUniform1f(program.light, light);
  glUniform2f(program.glossShift, shiftU / rect[2], shiftV / rect[3]);
  glUniform3f(program.view, look.viewX, look.viewY, look.viewZ);
  if (program.time >= 0) {
    const double seconds = static_cast<double>(frameStartNs) / 1.0e9;
    glUniform1f(program.time, static_cast<float>(std::fmod(seconds, kTimeWrapSeconds)));
  }
  glEnable(GL_BLEND);
  glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
  glBindVertexArray(lipsVao_.get());
  // Malla suave: 4 triángulos por cada uno de la región.
  glDrawElements(GL_TRIANGLES, mesh::kLipsRegionTriangleCount * 12, GL_UNSIGNED_SHORT, nullptr);
  glBindVertexArray(0);
  glDisable(GL_BLEND);
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
  // Los landmarks (sin los puntos nuevos de la malla suave) y el iris.
  glDrawArrays(GL_POINTS, 0, mesh::kVertexCount);
  glDrawArrays(GL_POINTS, mesh::kSubVertexCount, kIrisPointCount);
  glBindVertexArray(0);
  glDisable(GL_BLEND);
  MAKEUP_GL_CHECK("drawLandmarks");
}

GLuint Renderer::cameraTexture() const {
  return externalCameraTexture_ != 0 ? externalCameraTexture_ : cameraTexture_.get();
}

void Renderer::releaseGl() {
  crop_.release();
  lookSample_.release();
  // Una lectura en vuelo no va a terminar: se vuelve a pedir con el próximo contexto.
  int inFlight = kSampleInFlight;
  lookSampleState_.compare_exchange_strong(inFlight, kSampleRequested, std::memory_order_acq_rel);
  scene_.release();
  sceneLight_.reset();
  faceLayers_.release();
  passthrough_.program.reset();
  tint_.program.reset();
  mesh_.program.reset();
  lips_.program.reset();
  lipsShimmer_.program.reset();
  quadVbo_.reset();
  quadVao_.reset();
  meshVbo_.reset();
  uvVbo_.reset();
  normalVbo_.reset();
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
  // Mismo brillo de destellos que antes (se multiplicaban por gloss en el shader).
  if (uniforms.shimmer) uniforms.sparkle = EngineConfig::kLipsSparkle * uniforms.gloss;
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingLips_ = uniforms;
}

void Renderer::setLipLiner(const ColorLayer& style) {
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingLipLiner_ = style;
}

void Renderer::setCheeks(const CheekStyle& style) {
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingCheek_ = style;
}

void Renderer::setSkinLayer(SkinLayer layer, const ColorLayer& style) {
  const int index = static_cast<int>(layer);
  if (index < 0 || index >= kSkinLayerCount) return;
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingSkin_[index] = style;
}

void Renderer::setEyeShadow(int slot, const EyeShadowStyle& style) {
  if (slot < 0 || slot >= kMaxEyeShadows) return;
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingShadows_[slot] = style;
}

void Renderer::setLiner(const LinerStyle& style) {
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingLiner_ = style;
}

void Renderer::setLashes(const LashStyle& style) {
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingLashes_ = style;
}

void Renderer::setIris(const ColorLayer& style) {
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingIris_ = style;
}

void Renderer::setEffect(int slot, const EffectStyle& style) {
  if (slot < 0 || slot >= kMaxEffects) return;
  std::lock_guard<std::mutex> lock(configMutex_);
  pendingEffects_[slot] = style;
}

void Renderer::commitRecipe() {
  std::lock_guard<std::mutex> lock(configMutex_);
  lipUniforms_ = pendingLips_;
  faceUniforms_ = resolveFace(pendingSkin_, pendingCheek_);
  eyeUniforms_ = resolveEyes(pendingShadows_, pendingLiner_, pendingLashes_);
  resolveColorLayer(pendingIris_, irisUniforms_.lab, &irisUniforms_.amount);
  LipEffects lipEffects;
  applyEffects(pendingEffects_, &faceUniforms_, &eyeUniforms_, &lipEffects);
  // Delineado de labios (face_style: mismo recorte que las otras capas).
  resolveColorLayer(pendingLipLiner_, lipUniforms_.linerLab, &lipUniforms_.linerAmount);
  // Glitter y sheen en los labios: solo si hay labial (si no, no hay capa).
  if (lipUniforms_.enabled) {
    if (lipEffects.sparkle > 0.0f) {
      lipUniforms_.shimmer = true;
      lipUniforms_.sparkle = std::max(lipUniforms_.sparkle, lipEffects.sparkle);
    }
    lipUniforms_.gloss = std::min(1.0f, lipUniforms_.gloss + lipEffects.gloss);
  }
  recipeVersion_.fetch_add(1, std::memory_order_release);
}

void Renderer::setDisplayMatrices(const float* display, const float* tracker, bool mirrored) {
  std::lock_guard<std::mutex> lock(configMutex_);
  std::copy_n(display, 16, displayMatrix_.begin());
  std::copy_n(tracker, 16, trackerMatrix_.begin());
  mirrored_ = mirrored;
  displayVersion_.fetch_add(1, std::memory_order_release);
}

void Renderer::setRenderOptions(bool showLandmarks, TintRegion region, bool lightAdaptation) {
  showLandmarks_.store(showLandmarks, std::memory_order_relaxed);
  lightAdaptation_.store(lightAdaptation, std::memory_order_relaxed);
  region_.store(static_cast<int>(region), std::memory_order_relaxed);
}

void Renderer::setSmoothMesh(bool enabled) { smoothMesh_.store(enabled, std::memory_order_relaxed); }

void Renderer::setLipEdgeRefine(bool enabled) { lipEdgeRefine_.store(enabled, std::memory_order_relaxed); }

void Renderer::requestLookSample() {
  int expected = kSampleIdle;
  if (lookSampleState_.compare_exchange_strong(expected, kSampleRequested, std::memory_order_acq_rel)) return;
  // Una lista que nadie leyó se descarta: la próxima es más reciente.
  expected = kSampleReady;
  lookSampleState_.compare_exchange_strong(expected, kSampleRequested, std::memory_order_acq_rel);
}

bool Renderer::peekLookSample(const uint8_t** pixels, const float** points, float* imageScale) const {
  if (lookSampleState_.load(std::memory_order_acquire) != kSampleReady) return false;
  *pixels = lookSamplePixels_.data();
  *points = lookSamplePoints_.data();
  *imageScale = lookSampleScale_;
  return true;
}

void Renderer::releaseLookSample() {
  int expected = kSampleReady;
  lookSampleState_.compare_exchange_strong(expected, kSampleIdle, std::memory_order_acq_rel);
}

// Hilo de render, sin allocations: los buffers se crean con el Renderer.
void Renderer::runLookSample(const float* points, float alpha, const float* texMatrix, int width, int height) {
  const int state = lookSampleState_.load(std::memory_order_acquire);
  if (state == kSampleInFlight) {
    switch (lookSample_.poll(lookSamplePixels_.data())) {
      case LookSamplePass::Poll::kDone:
        lookSampleState_.store(kSampleReady, std::memory_order_release);
        break;
      case LookSamplePass::Poll::kFailed:
        lookSampleState_.store(kSampleRequested, std::memory_order_release);  // se reintenta
        break;
      case LookSamplePass::Poll::kIdle:
      case LookSamplePass::Poll::kPending:
        break;
    }
    return;
  }
  // Con la cara entera (sin fundido): una cara a medio aparecer mide mal.
  if (state != kSampleRequested || points == nullptr || alpha < 1.0f) return;
  const Roi roi = lookSampleRoi(points);
  if (!roi.valid()) return;
  if (!lookSample_.issue(roi, quadVao_.get(), cameraTexture(), texMatrix, drawTrackerMatrix_.data(), width,
                         height)) {
    return;  // se reintenta en el próximo frame
  }
  landmarksToSample(roi, LookSamplePass::kSize, points, lookSamplePoints_.data());
  lookSampleScale_ = roi.size / static_cast<float>(LookSamplePass::kSize);
  lookSampleState_.store(kSampleInFlight, std::memory_order_release);
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
