// Implementación de engine_c_api.h: mismos cuerpos que jni_bridge.cpp, sin JNI.
#include "engine_c_api.h"

#include <algorithm>
#include <array>
#include <cstring>
#include <string>
#include <vector>

#include "engine_config.h"
#include "renderer.h"
#include "studio/live_look_sample.h"
#include "studio/look_analysis.h"
#include "studio/palette.h"
#include "studio/still_face_locator.h"
#include "studio/still_image.h"
#include "tracking/tracking_state.h"

static_assert(MAKEUP_CONFIG_COUNT == makeup::kConfigCount, "índices de configuración de iOS desactualizados");

// Como Engine en jni_bridge.cpp: el tracking vive antes que el Renderer.
struct MakeupEngine {
  static constexpr int kRegressorCount =
      makeup::BlazeFaceDecoder::kAnchorCount * makeup::BlazeFaceDecoder::kCoordsPerAnchor;

  makeup::TrackingState tracking;
  makeup::Renderer renderer{&tracking};
  std::array<float, kRegressorCount> regressors{};
  std::array<float, makeup::BlazeFaceDecoder::kAnchorCount> scores{};
  std::array<float, makeup::TrackingState::kFloats> landmarks{};
};

struct MakeupStill {
  makeup::StillImage image;
  makeup::StillFaceLocator locator;
  std::vector<float> regressors;
  std::vector<float> scores;
  std::vector<float> landmarks;
};

namespace {

using makeup::EngineConfig;

makeup::ColorLayer colorLayer(bool enabled, float r, float g, float b, float amount) {
  makeup::ColorLayer layer;
  layer.enabled = enabled;
  layer.r = r;
  layer.g = g;
  layer.b = b;
  layer.amount = amount;
  return layer;
}

// Enums fuera de rango caen al primero (Swift ya valida; segunda defensa).
template <typename E>
E enumOr(int32_t value, E last) {
  return value >= 0 && value <= static_cast<int32_t>(last) ? static_cast<E>(value) : static_cast<E>(0);
}

int32_t copyText(const std::string& text, char* out, int32_t capacity) {
  if (out == nullptr || capacity <= 0) return static_cast<int32_t>(text.size());
  const size_t count = std::min(text.size(), static_cast<size_t>(capacity - 1));
  std::memcpy(out, text.data(), count);
  out[count] = '\0';
  return static_cast<int32_t>(count);
}

bool copyRgba(const uint8_t* rgba, int32_t width, int32_t height, makeup::StillImage* image) {
  if (rgba == nullptr || width <= 0 || height <= 0) return false;
  image->width = width;
  image->height = height;
  image->rgba.assign(rgba, rgba + static_cast<size_t>(width) * static_cast<size_t>(height) * 4);
  return true;
}

}  // namespace

extern "C" {

int32_t makeup_stat_count(void) { return makeup::kStatCount; }

int32_t makeup_tracker_stat_count(void) { return makeup::kTrackStatCount; }

void makeup_get_config(int32_t* out, int32_t count) {
  if (out == nullptr || count < makeup::kConfigCount) return;
  out[makeup::kConfigMaxPreviewLongSide] = EngineConfig::kMaxPreviewLongSide;
  out[makeup::kConfigMaxPreviewShortSide] = EngineConfig::kMaxPreviewShortSide;
  out[makeup::kConfigTargetFps] = EngineConfig::kTargetFps;
  out[makeup::kConfigStatsWindow] = EngineConfig::kStatsWindow;
  out[makeup::kConfigDetectorInputSize] = EngineConfig::kDetectorInputSize;
  out[makeup::kConfigLandmarkInputSize] = EngineConfig::kLandmarkInputSize;
  out[makeup::kConfigLandmarkCount] = EngineConfig::kLandmarkCount;
  out[makeup::kConfigStillMaxSide] = EngineConfig::kStillMaxSide;
  out[makeup::kConfigLookValueCount] = makeup::kLookValueCount;
}

MakeupEngine* makeup_create(void) { return new MakeupEngine(); }

void makeup_destroy(MakeupEngine* engine) { delete engine; }

uint32_t makeup_init_gl(MakeupEngine* engine) { return engine->renderer.initGl(); }

int32_t makeup_gl_info(MakeupEngine* engine, char* out, int32_t capacity) {
  return copyText(engine->renderer.glInfo(), out, capacity);
}

int32_t makeup_last_error(MakeupEngine* engine, char* out, int32_t capacity) {
  return copyText(engine->renderer.lastError(), out, capacity);
}

void makeup_set_geometry(MakeupEngine* engine, const float* display16, const float* tracker16, int32_t width,
                         int32_t height, bool mirrored) {
  if (display16 == nullptr || tracker16 == nullptr) return;
  engine->renderer.setDisplayMatrices(display16, tracker16, mirrored);
  engine->tracking.setImageSize(width, height);
}

void makeup_set_render_options(MakeupEngine* engine, bool show_landmarks, int32_t region, bool light_adaptation) {
  const auto tintRegion = region == static_cast<int32_t>(makeup::TintRegion::kMakeup) ? makeup::TintRegion::kMakeup
                                                                                     : makeup::TintRegion::kFull;
  engine->renderer.setRenderOptions(show_landmarks, tintRegion, light_adaptation);
}

void makeup_set_tint(MakeupEngine* engine, float r, float g, float b, float amount) {
  engine->renderer.setTint(r, g, b, amount);
}

void makeup_set_tracker_tuning(MakeupEngine* engine, float min_cutoff, float beta, bool smooth_mesh, bool lip_edge,
                               bool lip_contour) {
  engine->tracking.setFilterTuning(min_cutoff, beta);
  engine->tracking.setLipContourRefine(lip_contour);
  engine->renderer.setSmoothMesh(smooth_mesh);
  engine->renderer.setLipEdgeRefine(lip_edge);
}

void makeup_look_sample_request(MakeupEngine* engine) { engine->renderer.requestLookSample(); }

bool makeup_look_sample_take(MakeupEngine* engine, float* out, int32_t count) {
  if (out == nullptr || count < makeup::kLookValueCount) return false;
  const uint8_t* pixels = nullptr;
  const float* points = nullptr;
  float imageScale = 1.0f;
  if (!engine->renderer.peekLookSample(&pixels, &points, &imageScale)) return false;
  makeup::analyzeLiveSample(pixels, makeup::LookSamplePass::kSize, points, imageScale, out);
  engine->renderer.releaseLookSample();
  return true;
}

void makeup_set_lips(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity, int32_t finish,
                     float gloss, float luma_follow) {
  makeup::LipStyle style;
  style.enabled = enabled;
  style.r = r;
  style.g = g;
  style.b = b;
  style.opacity = opacity;
  style.finish = finish >= static_cast<int32_t>(makeup::LipFinish::kMatte) &&
                         finish <= static_cast<int32_t>(makeup::LipFinish::kShimmer)
                     ? static_cast<makeup::LipFinish>(finish)
                     : makeup::LipFinish::kSatin;
  style.gloss = gloss;
  style.lumaFollow = luma_follow;
  engine->renderer.setLips(style);
}

void makeup_set_lip_liner(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity) {
  engine->renderer.setLipLiner(colorLayer(enabled, r, g, b, opacity));
}

void makeup_set_cheeks(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity, float spread,
                       int32_t placement) {
  makeup::CheekStyle style;
  style.color = colorLayer(enabled, r, g, b, opacity);
  style.spread = spread;
  style.placement = enumOr(placement, makeup::CheekPlacement::kLow);
  engine->renderer.setCheeks(style);
}

void makeup_set_skin_layer(MakeupEngine* engine, int32_t layer, bool enabled, float r, float g, float b,
                           float amount) {
  if (layer < 0 || layer >= makeup::kSkinLayerCount) return;
  engine->renderer.setSkinLayer(static_cast<makeup::SkinLayer>(layer), colorLayer(enabled, r, g, b, amount));
}

void makeup_set_eye_shadow(MakeupEngine* engine, int32_t slot, bool enabled, float r, float g, float b,
                           float opacity, int32_t region, int32_t finish) {
  makeup::EyeShadowStyle style;
  style.color = colorLayer(enabled, r, g, b, opacity);
  style.region = enumOr(region, makeup::EyeRegion::kBrowBone);
  style.finish = enumOr(finish, makeup::ShadowFinish::kShimmer);
  engine->renderer.setEyeShadow(slot, style);
}

void makeup_set_liner(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity,
                      float thickness, float wing) {
  makeup::LinerStyle style;
  style.color = colorLayer(enabled, r, g, b, opacity);
  style.thickness = thickness;
  style.wing = wing;
  engine->renderer.setLiner(style);
}

void makeup_set_lashes(MakeupEngine* engine, bool enabled, float opacity, float length, float volume) {
  makeup::LashStyle style;
  style.enabled = enabled;
  style.opacity = opacity;
  style.length = length;
  style.volume = volume;
  engine->renderer.setLashes(style);
}

void makeup_set_iris(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity) {
  engine->renderer.setIris(colorLayer(enabled, r, g, b, opacity));
}

void makeup_set_effect(MakeupEngine* engine, int32_t slot, bool enabled, int32_t type, float intensity,
                       int32_t region) {
  makeup::EffectStyle style;
  style.enabled = enabled;
  style.type = enumOr(type, makeup::EffectType::kSheen);
  style.intensity = intensity;
  style.region = enumOr(region, makeup::EffectRegion::kFullFace);
  engine->renderer.setEffect(slot, style);
}

void makeup_commit_recipe(MakeupEngine* engine) { engine->renderer.commitRecipe(); }

void makeup_set_camera_texture(MakeupEngine* engine, uint32_t texture) { engine->renderer.setCameraTexture(texture); }

void makeup_set_output_framebuffer(MakeupEngine* engine, uint32_t framebuffer) {
  engine->renderer.setOutputFramebuffer(framebuffer);
}

int32_t makeup_draw_frame(MakeupEngine* engine, const float* tex_matrix16, int32_t width, int32_t height,
                          int64_t frame_start_ns, int64_t camera_timestamp_ns) {
  return engine->renderer.drawFrame(tex_matrix16, width, height, frame_start_ns, camera_timestamp_ns);
}

void makeup_release_gl(MakeupEngine* engine) { engine->renderer.releaseGl(); }

void makeup_get_stats(MakeupEngine* engine, float* out, int32_t count) {
  if (out == nullptr || count < makeup::kStatCount) return;
  engine->renderer.stats().snapshot(out);
}

void makeup_get_tracker_stats(MakeupEngine* engine, float* out, int32_t count) {
  if (out == nullptr || count < makeup::kTrackStatCount) return;
  engine->tracking.snapshotStats(out);
}

void makeup_reset_stats(MakeupEngine* engine) {
  engine->renderer.stats().reset();
  engine->tracking.resetStats();
}

void makeup_tracker_start(MakeupEngine* engine) { engine->tracking.start(); }

void makeup_tracker_stop(MakeupEngine* engine) { engine->tracking.stop(); }

void makeup_tracker_abort(MakeupEngine* engine) { engine->tracking.abortCrop(); }

int32_t makeup_tracker_ready_kind(MakeupEngine* engine) {
  return static_cast<int32_t>(engine->tracking.readyCropKind());
}

bool makeup_tracker_fill_input(MakeupEngine* engine, float* out, int32_t count, float scale, float offset) {
  return out != nullptr && engine->tracking.fillInput(out, count, scale, offset);
}

void makeup_tracker_submit_detections(MakeupEngine* engine, const float* regressors, int32_t regressor_count,
                                      const float* scores, int32_t score_count, float inference_ms) {
  if (regressors == nullptr || scores == nullptr || regressor_count < MakeupEngine::kRegressorCount ||
      score_count < makeup::BlazeFaceDecoder::kAnchorCount) {
    engine->tracking.abortCrop();  // salidas inesperadas: no dejar el ciclo trabado
    return;
  }
  std::copy_n(regressors, MakeupEngine::kRegressorCount, engine->regressors.data());
  std::copy_n(scores, makeup::BlazeFaceDecoder::kAnchorCount, engine->scores.data());
  engine->tracking.submitDetections(engine->regressors.data(), engine->scores.data(), inference_ms);
}

void makeup_tracker_submit_landmarks(MakeupEngine* engine, const float* landmarks, int32_t count,
                                     float presence_logit, float inference_ms) {
  if (landmarks == nullptr) {
    engine->tracking.abortCrop();
    return;
  }
  // Menos puntos que los esperados: submitLandmarks lo trata como cara perdida.
  const int32_t copied = std::min<int32_t>(std::max<int32_t>(count, 0), makeup::TrackingState::kFloats);
  std::copy_n(landmarks, copied, engine->landmarks.data());
  engine->tracking.submitLandmarks(engine->landmarks.data(), copied, presence_logit, inference_ms);
}

MakeupStill* makeup_still_create(const uint8_t* rgba, int32_t width, int32_t height) {
  auto* still = new MakeupStill();
  if (copyRgba(rgba, width, height, &still->image)) {
    still->locator.begin(width, height);
  } else {
    still->locator.begin(0, 0);  // kFailed / kBadImage
  }
  return still;
}

int32_t makeup_still_step(MakeupStill* still) { return static_cast<int32_t>(still->locator.step()); }

bool makeup_still_fill_input(MakeupStill* still, float* out, int32_t count, float scale, float offset) {
  return out != nullptr && still->locator.fillInput(still->image, out, count, scale, offset);
}

void makeup_still_submit_detections(MakeupStill* still, const float* regressors, int32_t regressor_count,
                                    const float* scores, int32_t score_count) {
  still->regressors.assign(regressors, regressors + std::max<int32_t>(regressor_count, 0));
  still->scores.assign(scores, scores + std::max<int32_t>(score_count, 0));
  still->locator.submitDetections(still->regressors.data(), static_cast<int>(still->regressors.size()),
                                  still->scores.data(), static_cast<int>(still->scores.size()));
}

void makeup_still_submit_landmarks(MakeupStill* still, const float* landmarks, int32_t count, float presence_logit) {
  still->landmarks.assign(landmarks, landmarks + std::max<int32_t>(count, 0));
  still->locator.submitLandmarks(still->landmarks.data(), static_cast<int>(still->landmarks.size()), presence_logit);
}

void makeup_still_fail(MakeupStill* still, int32_t status) {
  still->locator.fail(static_cast<makeup::StillFaceStatus>(status));
}

void makeup_still_analyze(MakeupStill* still, float* out, int32_t count) {
  if (out == nullptr || count < makeup::kLookValueCount) return;
  std::fill(out, out + makeup::kLookValueCount, 0.0f);
  makeup::StillFaceStatus status = still->locator.status();
  if (still->locator.step() == makeup::StillFaceLocator::Step::kDone &&
      !makeup::analyzeLook(still->image, still->locator.landmarks(), out)) {
    status = makeup::StillFaceStatus::kBadImage;  // sin piel base no hay referencia
  }
  out[makeup::kLookStatus] = static_cast<float>(status);
  out[makeup::kLookEyeDistancePx] = still->locator.eyeDistancePx();
  out[makeup::kLookYawRatio] = still->locator.yawRatio();
}

void makeup_still_destroy(MakeupStill* still) { delete still; }

int32_t makeup_still_palette(const uint8_t* rgba, int32_t width, int32_t height, float* out, int32_t capacity) {
  makeup::StillImage image;
  if (out == nullptr || !copyRgba(rgba, width, height, &image)) return 0;
  std::array<makeup::PaletteSwatch, EngineConfig::kPaletteClusters> swatches{};
  const int count = makeup::extractPalette(image, swatches.data(), EngineConfig::kPaletteClusters);
  int32_t written = 0;
  for (int i = 0; i < count && written + makeup::kPaletteSwatchFloats <= capacity; ++i) {
    out[written++] = swatches[i].rgb[0];
    out[written++] = swatches[i].rgb[1];
    out[written++] = swatches[i].rgb[2];
    out[written++] = swatches[i].fraction;
  }
  return written;
}

}  // extern "C"
