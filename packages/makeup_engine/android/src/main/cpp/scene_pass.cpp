#include "scene_pass.h"

#include <cstring>

#include "gl_program.h"
#include "shader_sources.h"

namespace makeup {

namespace {

// 4×4 lecturas por píxel: 16×16 píxeles cubren el frame con 4096 muestras.
constexpr char kDefines[] = "#define TAPS 4\n";
// Recorte = imagen entera: la identidad.
constexpr float kIdentity3[9] = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};

}  // namespace

bool ScenePass::init(std::string* error) {
  const char* attributes[] = {"aPosition"};
  program_ = buildGlProgram(shaders::k_crop_roi_vert, shaders::k_crop_roi_frag, attributes, 1, error, kDefines);
  if (!program_) return false;
  cropMatrix_ = glGetUniformLocation(program_.get(), "uCropMatrix");
  displayMatrix_ = glGetUniformLocation(program_.get(), "uDisplayMatrix");
  texMatrix_ = glGetUniformLocation(program_.get(), "uTexMatrix");
  glUseProgram(program_.get());
  glUniform1i(glGetUniformLocation(program_.get(), "uCamera"), 0);
  glUniformMatrix3fv(cropMatrix_, 1, GL_FALSE, kIdentity3);
  glUseProgram(0);

  constexpr int kSize = EngineConfig::kScenePassSize;
  GLuint texture = 0;
  glGenTextures(1, &texture);
  texture_.reset(texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, kSize, kSize);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glBindTexture(GL_TEXTURE_2D, 0);

  GLuint framebuffer = 0;
  glGenFramebuffers(1, &framebuffer);
  framebuffer_.reset(framebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
  const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  if (status != GL_FRAMEBUFFER_COMPLETE) {
    *error = "FBO de la escena incompleto: " + std::to_string(status);
    return false;
  }

  GLuint buffer = 0;
  glGenBuffers(1, &buffer);
  pixelBuffer_.reset(buffer);
  glBindBuffer(GL_PIXEL_PACK_BUFFER, buffer);
  glBufferData(GL_PIXEL_PACK_BUFFER, kPixelCount * 4, nullptr, GL_STREAM_READ);
  glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  MAKEUP_GL_CHECK("ScenePass::init");
  return true;
}

void ScenePass::maybeIssue(GLuint quadVao, GLuint cameraTexture, const float* texMatrix,
                           const float* displayMatrix, int64_t nowNs) {
  if (fence_ != nullptr) return;
  if (lastIssueNs_ != 0 && nowNs - lastIssueNs_ < EngineConfig::kScenePassIntervalNs) return;
  constexpr int kSize = EngineConfig::kScenePassSize;
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_.get());
  glViewport(0, 0, kSize, kSize);
  const GLenum attachment = GL_COLOR_ATTACHMENT0;
  glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &attachment);
  glUseProgram(program_.get());
  glUniformMatrix4fv(displayMatrix_, 1, GL_FALSE, displayMatrix);
  glUniformMatrix4fv(texMatrix_, 1, GL_FALSE, texMatrix);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(MAKEUP_CAMERA_TEXTURE, cameraTexture);
  glBindVertexArray(quadVao);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArray(0);

  glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelBuffer_.get());
  glReadPixels(0, 0, kSize, kSize, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
  glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  fence_ = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  MAKEUP_GL_CHECK("ScenePass::issue");
  lastIssueNs_ = nowNs;  // aunque falle el fence: se reintenta en el próximo intervalo
  framesWaiting_ = 0;
}

bool ScenePass::poll() {
  if (fence_ == nullptr) return false;
  const GLenum wait = glClientWaitSync(fence_, 0, 0);
  if (wait == GL_TIMEOUT_EXPIRED) {
    if (++framesWaiting_ > EngineConfig::kCropTimeoutFrames) dropFence();
    return false;
  }
  dropFence();
  if (wait == GL_WAIT_FAILED) return false;
  glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelBuffer_.get());
  const void* mapped = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, kPixelCount * 4, GL_MAP_READ_BIT);
  bool ok = mapped != nullptr;
  if (ok) {
    std::memcpy(pixels_.data(), mapped, pixels_.size());
    ok = glUnmapBuffer(GL_PIXEL_PACK_BUFFER) == GL_TRUE;  // false: datos corruptos
  }
  glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  MAKEUP_GL_CHECK("ScenePass::poll");
  return ok;
}

void ScenePass::dropFence() {
  if (fence_ != nullptr) glDeleteSync(fence_);
  fence_ = nullptr;
}

void ScenePass::release() {
  dropFence();
  program_.reset();
  framebuffer_.reset();
  texture_.reset();
  pixelBuffer_.reset();
  lastIssueNs_ = 0;
}

}  // namespace makeup
