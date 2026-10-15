#include "crop_pass.h"

#include <cstring>

#include "gl_program.h"
#include "shader_sources.h"
#include "tracking/roi.h"

namespace makeup {

namespace {

constexpr float kNsPerMs = 1.0e6f;
constexpr char kDetectorDefines[] = "#define TAPS 4\n";
constexpr char kLandmarkDefines[] = "#define TAPS 2\n";
static_assert(EngineConfig::kDetectorTaps == 4 && EngineConfig::kLandmarkTaps == 2,
              "actualizar los #define TAPS de CropPass");

}  // namespace

bool CropPass::init(std::string* error) {
  if (!buildProgram(detectorProgram_, kDetectorDefines, error) ||
      !buildProgram(landmarkProgram_, kLandmarkDefines, error) ||
      !buildTarget(detectorTarget_, EngineConfig::kDetectorInputSize, error) ||
      !buildTarget(landmarkTarget_, EngineConfig::kLandmarkInputSize, error)) {
    return false;
  }
  GLuint buffer = 0;
  glGenBuffers(1, &buffer);
  pixelBuffer_.reset(buffer);
  constexpr int kMaxBytes = EngineConfig::kLandmarkInputSize * EngineConfig::kLandmarkInputSize * 4;
  glBindBuffer(GL_PIXEL_PACK_BUFFER, buffer);
  glBufferData(GL_PIXEL_PACK_BUFFER, kMaxBytes, nullptr, GL_STREAM_READ);
  glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  MAKEUP_GL_CHECK("CropPass::init");
  return true;
}

bool CropPass::buildProgram(Program& out, const char* defines, std::string* error) {
  const char* attributes[] = {"aPosition"};
  GlProgram program = buildGlProgram(shaders::k_crop_roi_vert, shaders::k_crop_roi_frag,
                                     attributes, 1, error, defines);
  if (!program) return false;
  out.cropMatrix = glGetUniformLocation(program.get(), "uCropMatrix");
  out.displayMatrix = glGetUniformLocation(program.get(), "uDisplayMatrix");
  out.texMatrix = glGetUniformLocation(program.get(), "uTexMatrix");
  glUseProgram(program.get());
  glUniform1i(glGetUniformLocation(program.get(), "uCamera"), 0);
  glUseProgram(0);
  out.program = std::move(program);
  return true;
}

bool CropPass::buildTarget(Target& out, int size, std::string* error) {
  GLuint texture = 0;
  glGenTextures(1, &texture);
  out.texture.reset(texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, size, size);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glBindTexture(GL_TEXTURE_2D, 0);

  GLuint framebuffer = 0;
  glGenFramebuffers(1, &framebuffer);
  out.framebuffer.reset(framebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
  const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  if (status != GL_FRAMEBUFFER_COMPLETE) {
    *error = "FBO de recorte incompleto: " + std::to_string(status);
    return false;
  }
  out.size = size;
  return true;
}

bool CropPass::issue(const CropRequest& request, GLuint quadVao, GLuint cameraTexture,
                     const float* texMatrix, const float* displayMatrix, int imageWidth,
                     int imageHeight, int64_t nowNs) {
  const bool detector = request.kind == CropKind::kDetector;
  Program& program = detector ? detectorProgram_ : landmarkProgram_;
  Target& target = detector ? detectorTarget_ : landmarkTarget_;

  float cropMatrix[9];
  roiCropMatrix(request.roi, static_cast<float>(imageWidth), static_cast<float>(imageHeight),
                cropMatrix);

  glBindFramebuffer(GL_FRAMEBUFFER, target.framebuffer.get());
  glViewport(0, 0, target.size, target.size);
  const GLenum attachment = GL_COLOR_ATTACHMENT0;
  glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &attachment);
  glUseProgram(program.program.get());
  glUniformMatrix3fv(program.cropMatrix, 1, GL_FALSE, cropMatrix);
  glUniformMatrix4fv(program.displayMatrix, 1, GL_FALSE, displayMatrix);
  glUniformMatrix4fv(program.texMatrix, 1, GL_FALSE, texMatrix);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(MAKEUP_CAMERA_TEXTURE, cameraTexture);
  glBindVertexArray(quadVao);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArray(0);

  glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelBuffer_.get());
  glReadPixels(0, 0, target.size, target.size, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
  glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  fence_ = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  MAKEUP_GL_CHECK("CropPass::issue");

  if (fence_ == nullptr) return false;  // contexto perdido o sin memoria en el driver
  pendingBytes_ = target.size * target.size * 4;
  framesWaiting_ = 0;
  issuedNs_ = nowNs;
  return true;
}

CropPass::Poll CropPass::poll(uint8_t* dst, float* readbackMs, int64_t nowNs) {
  if (fence_ == nullptr) return Poll::kIdle;
  const GLenum wait = glClientWaitSync(fence_, 0, 0);
  if (wait == GL_TIMEOUT_EXPIRED) {
    if (++framesWaiting_ <= EngineConfig::kCropTimeoutFrames) return Poll::kPending;
    dropFence();
    return Poll::kFailed;
  }
  dropFence();
  if (wait == GL_WAIT_FAILED) return Poll::kFailed;

  glBindBuffer(GL_PIXEL_PACK_BUFFER, pixelBuffer_.get());
  const void* mapped = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, pendingBytes_, GL_MAP_READ_BIT);
  bool ok = mapped != nullptr;
  if (ok) {
    std::memcpy(dst, mapped, static_cast<size_t>(pendingBytes_));
    ok = glUnmapBuffer(GL_PIXEL_PACK_BUFFER) == GL_TRUE;  // false: datos corruptos
  }
  glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
  MAKEUP_GL_CHECK("CropPass::poll");
  if (!ok) return Poll::kFailed;
  *readbackMs = static_cast<float>(nowNs - issuedNs_) / kNsPerMs;
  return Poll::kDone;
}

void CropPass::dropFence() {
  if (fence_ != nullptr) glDeleteSync(fence_);
  fence_ = nullptr;
}

void CropPass::release() {
  dropFence();
  detectorProgram_.program.reset();
  landmarkProgram_.program.reset();
  detectorTarget_.framebuffer.reset();
  detectorTarget_.texture.reset();
  landmarkTarget_.framebuffer.reset();
  landmarkTarget_.texture.reset();
  pixelBuffer_.reset();
}

}  // namespace makeup
