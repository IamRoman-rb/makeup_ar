#include "renderer.h"

#include <EGL/egl.h>
#include <GLES2/gl2ext.h>

#include <cstring>
#include <ctime>

#include "color_math.h"
#include "shader_sources.h"

namespace makeup {

namespace {

constexpr char kIncludeMarker[] = "// @include color.glsl";

// Triangle strip de pantalla completa en clip space.
constexpr GLfloat kQuad[] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};

int64_t monotonicNowNs() {
  timespec ts{};
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return static_cast<int64_t>(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
}

// Reemplaza el marcador de include por shaders/color.glsl (solo en init).
std::string injectColorInclude(const char* source) {
  std::string result(source);
  const size_t at = result.find(kIncludeMarker);
  if (at != std::string::npos) {
    result.replace(at, std::strlen(kIncludeMarker), shaders::k_color_glsl);
  }
  return result;
}

GLuint compileShader(GLenum type, const std::string& source, std::string* error) {
  GLuint shader = glCreateShader(type);
  const char* text = source.c_str();
  glShaderSource(shader, 1, &text, nullptr);
  glCompileShader(shader);
  GLint ok = GL_FALSE;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (ok != GL_TRUE) {
    GLint length = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
    std::string log(static_cast<size_t>(length > 1 ? length : 1), '\0');
    glGetShaderInfoLog(shader, length, nullptr, log.data());
    *error = std::string(type == GL_VERTEX_SHADER ? "vertex" : "fragment") + " shader: " + log;
    glDeleteShader(shader);
    return 0;
  }
  return shader;
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

  if (!buildProgram(passthrough_, shaders::k_passthrough_frag) ||
      !buildProgram(tint_, shaders::k_tint_oklab_frag)) {
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
  // Los dos programas usan la ubicación 0 para aPosition (glBindAttribLocation).
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

bool Renderer::buildProgram(Program& out, const char* fragmentSource) {
  std::string error;
  GLuint vertex = compileShader(GL_VERTEX_SHADER, shaders::k_camera_quad_vert, &error);
  if (vertex == 0) {
    setError(error);
    return false;
  }
  GLuint fragment = compileShader(GL_FRAGMENT_SHADER, injectColorInclude(fragmentSource), &error);
  if (fragment == 0) {
    glDeleteShader(vertex);
    setError(error);
    return false;
  }
  GlProgram program(glCreateProgram());
  glAttachShader(program.get(), vertex);
  glAttachShader(program.get(), fragment);
  glBindAttribLocation(program.get(), 0, "aPosition");
  glLinkProgram(program.get());
  glDeleteShader(vertex);
  glDeleteShader(fragment);
  GLint ok = GL_FALSE;
  glGetProgramiv(program.get(), GL_LINK_STATUS, &ok);
  if (ok != GL_TRUE) {
    GLint length = 0;
    glGetProgramiv(program.get(), GL_INFO_LOG_LENGTH, &length);
    std::string log(static_cast<size_t>(length > 1 ? length : 1), '\0');
    glGetProgramInfoLog(program.get(), length, nullptr, log.data());
    setError("link: " + log);
    return false;
  }
  out.displayMatrix = glGetUniformLocation(program.get(), "uDisplayMatrix");
  out.texMatrix = glGetUniformLocation(program.get(), "uTexMatrix");
  out.camera = glGetUniformLocation(program.get(), "uCamera");
  out.tintAb = glGetUniformLocation(program.get(), "uTintAb");
  out.tintAmount = glGetUniformLocation(program.get(), "uTintAmount");
  // El sampler siempre usa la unidad 0: se fija una vez, no por frame.
  glUseProgram(program.get());
  glUniform1i(out.camera, 0);
  glUseProgram(0);
  out.uploadedDisplayVersion = 0;
  out.program = std::move(program);
  MAKEUP_GL_CHECK("buildProgram");
  return true;
}

void Renderer::drawFrame(const float* texMatrix, int width, int height, int64_t frameStartNs,
                         int64_t cameraTimestampNs) {
  const uint32_t displayVersion = displayVersion_.load(std::memory_order_acquire);
  if (displayVersion != drawDisplayVersion_) {
    std::lock_guard<std::mutex> lock(configMutex_);  // solo cuando cambió
    drawDisplayMatrix_ = displayMatrix_;
    drawDisplayVersion_ = displayVersion;
  }
  const float amount = tintAmount_.load(std::memory_order_relaxed);
  Program& program = amount > 0.0f ? tint_ : passthrough_;

  glViewport(0, 0, width, height);
  // El quad cubre toda la superficie: en una GPU de tiles (Mali) esto evita
  // cargar el contenido anterior del framebuffer en cada tile.
  const GLenum colorAttachment = GL_COLOR;
  glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &colorAttachment);
  glUseProgram(program.program.get());
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, cameraTexture_.get());
  if (program.uploadedDisplayVersion != drawDisplayVersion_) {
    glUniformMatrix4fv(program.displayMatrix, 1, GL_FALSE, drawDisplayMatrix_.data());
    program.uploadedDisplayVersion = drawDisplayVersion_;
  }
  glUniformMatrix4fv(program.texMatrix, 1, GL_FALSE, texMatrix);
  if (program.tintAb >= 0) {
    glUniform2f(program.tintAb, tintA_.load(std::memory_order_relaxed),
                tintB_.load(std::memory_order_relaxed));
    glUniform1f(program.tintAmount, amount);
  }
  glBindVertexArray(quadVao_.get());
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArray(0);
  MAKEUP_GL_CHECK("drawFrame");

  eglSwapBuffers(eglGetCurrentDisplay(), eglGetCurrentSurface(EGL_DRAW));
  stats_.record(frameStartNs, monotonicNowNs(), cameraTimestampNs);
}

void Renderer::releaseGl() {
  passthrough_.program.reset();
  tint_.program.reset();
  quadVbo_.reset();
  quadVao_.reset();
  cameraTexture_.reset();
}

void Renderer::setTint(float r, float g, float b, float amount) {
  const Vec3 lab = srgbToOklab(std::clamp(r, 0.0f, 1.0f), std::clamp(g, 0.0f, 1.0f),
                               std::clamp(b, 0.0f, 1.0f));
  tintA_.store(lab.y, std::memory_order_relaxed);
  tintB_.store(lab.z, std::memory_order_relaxed);
  tintAmount_.store(std::clamp(amount, 0.0f, 1.0f), std::memory_order_relaxed);
}

void Renderer::setDisplayMatrix(const float* matrix) {
  std::lock_guard<std::mutex> lock(configMutex_);
  std::copy_n(matrix, 16, displayMatrix_.begin());
  displayVersion_.fetch_add(1, std::memory_order_release);
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
