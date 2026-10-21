// API C del núcleo del motor para el plugin de iOS (Swift). Es la misma
// superficie que el puente JNI de Android (android/src/main/cpp/jni_bridge.cpp):
// una sesión de cámara (Renderer + TrackingState) y el análisis de una foto
// (Studio, F4). Diseño en docs/ar_engine/IOS.md.
//
// Hilos, como en Android:
//   - render (dueño del EAGLContext): init_gl, set_camera_texture,
//     set_output_framebuffer, draw_frame, release_gl;
//   - tracker: tracker_*;
//   - cualquiera: set_* de la receta + commit_recipe, opciones, stats.
// Por frame de cámara hay una sola llamada (draw_frame), sin allocations.
#ifndef MAKEUP_ENGINE_C_API_H
#define MAKEUP_ENGINE_C_API_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MakeupEngine MakeupEngine;
typedef struct MakeupStill MakeupStill;

// Mismo orden que NativeBridge.CONFIG_* (engine_config.h: ConfigIndex).
enum {
  MAKEUP_CONFIG_MAX_PREVIEW_LONG_SIDE = 0,
  MAKEUP_CONFIG_MAX_PREVIEW_SHORT_SIDE = 1,
  MAKEUP_CONFIG_TARGET_FPS = 2,
  MAKEUP_CONFIG_STATS_WINDOW = 3,
  MAKEUP_CONFIG_DETECTOR_INPUT_SIZE = 4,
  MAKEUP_CONFIG_LANDMARK_INPUT_SIZE = 5,
  MAKEUP_CONFIG_LANDMARK_COUNT = 6,
  MAKEUP_CONFIG_STILL_MAX_SIDE = 7,
  MAKEUP_CONFIG_LOOK_VALUE_COUNT = 8,
  MAKEUP_CONFIG_COUNT = 9,
};

// Tamaños de los arreglos de stats (frame_stats.h, tracking_state.h).
int32_t makeup_stat_count(void);
int32_t makeup_tracker_stat_count(void);
// Llena [out] con MAKEUP_CONFIG_COUNT valores.
void makeup_get_config(int32_t* out, int32_t count);

// --- Sesión ---
MakeupEngine* makeup_create(void);
void makeup_destroy(MakeupEngine* engine);
// Hilo de render. 0 si falla (makeup_last_error). En iOS el id es una textura
// propia sin usar: la cámara llega por makeup_set_camera_texture.
uint32_t makeup_init_gl(MakeupEngine* engine);
// Copian el texto (terminado en 0) y devuelven su largo.
int32_t makeup_gl_info(MakeupEngine* engine, char* out, int32_t capacity);
int32_t makeup_last_error(MakeupEngine* engine, char* out, int32_t capacity);
void makeup_set_geometry(MakeupEngine* engine, const float* display16, const float* tracker16, int32_t width,
                         int32_t height, bool mirrored);
void makeup_set_render_options(MakeupEngine* engine, bool show_landmarks, int32_t region, bool light_adaptation);
void makeup_set_tint(MakeupEngine* engine, float r, float g, float b, float amount);
// Arnés (TRACKER.md §9–§10): One Euro, malla suave, borde real y contorno fino.
void makeup_set_tracker_tuning(MakeupEngine* engine, float min_cutoff, float beta, bool smooth_mesh, bool lip_edge,
                               bool lip_contour);

// --- Guía de maquillaje (docs/ar_engine/COACH.md) ---
// Cualquier hilo: pide una muestra de la cara (el render la toma en el próximo
// frame con cara).
void makeup_look_sample_request(MakeupEngine* engine);
// Hilo de fondo: si hay una muestra lista la mide y llena [out]
// (MAKEUP_CONFIG_LOOK_VALUE_COUNT valores, como makeup_still_analyze);
// false si todavía no hay.
bool makeup_look_sample_take(MakeupEngine* engine, float* out, int32_t count);

// Receta (como nativeSet* de NativeBridge.kt): colores sRGB [0,1].
void makeup_set_lips(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity, int32_t finish,
                     float gloss, float luma_follow);
void makeup_set_lip_liner(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity);
void makeup_set_cheeks(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity, float spread,
                       int32_t placement);
void makeup_set_skin_layer(MakeupEngine* engine, int32_t layer, bool enabled, float r, float g, float b,
                           float amount);
void makeup_set_eye_shadow(MakeupEngine* engine, int32_t slot, bool enabled, float r, float g, float b,
                           float opacity, int32_t region, int32_t finish);
void makeup_set_liner(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity,
                      float thickness, float wing);
void makeup_set_lashes(MakeupEngine* engine, bool enabled, float opacity, float length, float volume);
void makeup_set_iris(MakeupEngine* engine, bool enabled, float r, float g, float b, float opacity);
void makeup_set_effect(MakeupEngine* engine, int32_t slot, bool enabled, int32_t type, float intensity,
                       int32_t region);
void makeup_commit_recipe(MakeupEngine* engine);

// Hilo de render, por frame.
void makeup_set_camera_texture(MakeupEngine* engine, uint32_t texture);
void makeup_set_output_framebuffer(MakeupEngine* engine, uint32_t framebuffer);
// Bits: 1 = hay un recorte listo para el tracker.
int32_t makeup_draw_frame(MakeupEngine* engine, const float* tex_matrix16, int32_t width, int32_t height,
                          int64_t frame_start_ns, int64_t camera_timestamp_ns);
void makeup_release_gl(MakeupEngine* engine);

void makeup_get_stats(MakeupEngine* engine, float* out, int32_t count);
void makeup_get_tracker_stats(MakeupEngine* engine, float* out, int32_t count);
void makeup_reset_stats(MakeupEngine* engine);

// --- Tracker (hilo de inferencia) ---
void makeup_tracker_start(MakeupEngine* engine);
void makeup_tracker_stop(MakeupEngine* engine);
void makeup_tracker_abort(MakeupEngine* engine);
// 0 ninguno, 1 detector, 2 landmarks.
int32_t makeup_tracker_ready_kind(MakeupEngine* engine);
// Recorte listo -> tensor NHWC float: valor · scale + offset.
bool makeup_tracker_fill_input(MakeupEngine* engine, float* out, int32_t count, float scale, float offset);
void makeup_tracker_submit_detections(MakeupEngine* engine, const float* regressors, int32_t regressor_count,
                                      const float* scores, int32_t score_count, float inference_ms);
void makeup_tracker_submit_landmarks(MakeupEngine* engine, const float* landmarks, int32_t count,
                                     float presence_logit, float inference_ms);

// --- Studio (F4): una foto, sin sesión ---
// [rgba]: width × height × 4 bytes, derecho (orientación ya aplicada).
MakeupStill* makeup_still_create(const uint8_t* rgba, int32_t width, int32_t height);
// 0 detector, 1 landmarks, 2 listo, 3 falló.
int32_t makeup_still_step(MakeupStill* still);
bool makeup_still_fill_input(MakeupStill* still, float* out, int32_t count, float scale, float offset);
void makeup_still_submit_detections(MakeupStill* still, const float* regressors, int32_t regressor_count,
                                    const float* scores, int32_t score_count);
void makeup_still_submit_landmarks(MakeupStill* still, const float* landmarks, int32_t count, float presence_logit);
void makeup_still_fail(MakeupStill* still, int32_t status);
// Llena [out] con MAKEUP_CONFIG_LOOK_VALUE_COUNT valores (look_analysis.h).
void makeup_still_analyze(MakeupStill* still, float* out, int32_t count);
void makeup_still_destroy(MakeupStill* still);
// Paleta: (r, g, b, fracción) por swatch. Devuelve cuántos floats escribió.
int32_t makeup_still_palette(const uint8_t* rgba, int32_t width, int32_t height, float* out, int32_t capacity);

#ifdef __cplusplus
}
#endif

#endif  // MAKEUP_ENGINE_C_API_H
