// Puente JNI con com.makeupar.makeup_engine.NativeBridge.
//
// Por frame de cámara hay UNA llamada Kotlin -> C++ (nativeDrawFrame), sin
// allocations: la matriz se copia a un arreglo en la pila. Por resultado del
// tracker (15–20 Hz, hilo propio) hay tres: fillInput, submit y nada más.
// Dart nunca cruza por frame: solo inicia/detiene, cambia el tinte y lee
// métricas (~2 Hz).
//
// Studio (F4): nativeStill* analiza una foto fuera de la sesión de cámara
// (StillImageAnalyzer.kt, hilo propio, una vez por foto).
#include <jni.h>

#include <algorithm>
#include <array>
#include <vector>

#include "engine_config.h"
#include "renderer.h"
#include "studio/look_analysis.h"
#include "studio/palette.h"
#include "studio/still_face_locator.h"
#include "studio/still_image.h"
#include "tracking/tracking_state.h"

namespace {

using makeup::CropKind;
using makeup::EngineConfig;
using makeup::Renderer;
using makeup::TrackingState;

// Lo que apunta el handle de Kotlin. El estado de tracking vive antes que el
// Renderer (que guarda un puntero a él) y se destruye después.
struct Engine {
  static constexpr int kRegressorCount =
      makeup::BlazeFaceDecoder::kAnchorCount * makeup::BlazeFaceDecoder::kCoordsPerAnchor;

  TrackingState tracking;
  Renderer renderer{&tracking};
  // Copias de las salidas de los modelos (solo hilo del tracker): así el
  // submit no corre con un arreglo de Java tomado en sección crítica.
  std::array<float, kRegressorCount> regressors{};
  std::array<float, makeup::BlazeFaceDecoder::kAnchorCount> scores{};
  std::array<float, TrackingState::kFloats> landmarks{};
};

Engine* fromHandle(jlong handle) { return reinterpret_cast<Engine*>(handle); }

// Análisis de una foto (F4): la foto, el localizador y el scratch de las salidas.
struct StillSession {
  makeup::StillImage image;
  makeup::StillFaceLocator locator;
  std::vector<float> regressors;
  std::vector<float> scores;
  std::vector<float> landmarks;
};

StillSession* stillFromHandle(jlong handle) { return reinterpret_cast<StillSession*>(handle); }

// Copia un IntArray ARGB (Bitmap.getPixels) a [image] por bloques de filas:
// sin una copia entera intermedia (pico de memoria en el E20). false si no coincide.
bool copyArgb(JNIEnv* env, jintArray argb, jint width, jint height, makeup::StillImage* image) {
  if (argb == nullptr || width <= 0 || height <= 0) return false;
  const jsize count = env->GetArrayLength(argb);
  if (static_cast<long long>(count) != static_cast<long long>(width) * height) return false;
  constexpr int kRowsPerBlock = 64;
  image->width = width;
  image->height = height;
  image->rgba.resize(static_cast<size_t>(count) * 4);
  std::vector<jint> block(static_cast<size_t>(width) * kRowsPerBlock);
  for (int row = 0; row < height; row += kRowsPerBlock) {
    const int rows = std::min(kRowsPerBlock, height - row);
    env->GetIntArrayRegion(argb, row * width, rows * width, block.data());
    makeup::argbToRgba(reinterpret_cast<const int32_t*>(block.data()), rows * width,
                       &image->rgba[static_cast<size_t>(row) * width * 4]);
  }
  return true;
}

std::vector<float> copyFloats(JNIEnv* env, jfloatArray array) {
  std::vector<float> out;
  if (array == nullptr) return out;
  out.resize(static_cast<size_t>(env->GetArrayLength(array)));
  if (!out.empty()) env->GetFloatArrayRegion(array, 0, static_cast<jsize>(out.size()), out.data());
  return out;
}

jfloatArray toFloatArray(JNIEnv* env, const float* values, int count) {
  jfloatArray result = env->NewFloatArray(count);
  if (result != nullptr && count > 0) env->SetFloatArrayRegion(result, 0, count, values);
  return result;
}

jintArray nativeGetConfig(JNIEnv* env, jclass) {
  jint values[makeup::kConfigCount] = {};
  values[makeup::kConfigMaxPreviewLongSide] = EngineConfig::kMaxPreviewLongSide;
  values[makeup::kConfigMaxPreviewShortSide] = EngineConfig::kMaxPreviewShortSide;
  values[makeup::kConfigTargetFps] = EngineConfig::kTargetFps;
  values[makeup::kConfigStatsWindow] = EngineConfig::kStatsWindow;
  values[makeup::kConfigDetectorInputSize] = EngineConfig::kDetectorInputSize;
  values[makeup::kConfigLandmarkInputSize] = EngineConfig::kLandmarkInputSize;
  values[makeup::kConfigLandmarkCount] = EngineConfig::kLandmarkCount;
  values[makeup::kConfigStillMaxSide] = EngineConfig::kStillMaxSide;
  values[makeup::kConfigLookValueCount] = makeup::kLookValueCount;
  jintArray result = env->NewIntArray(makeup::kConfigCount);
  if (result != nullptr) env->SetIntArrayRegion(result, 0, makeup::kConfigCount, values);
  return result;
}

jlong nativeCreate(JNIEnv*, jclass) { return reinterpret_cast<jlong>(new Engine()); }

jint nativeInitGl(JNIEnv*, jclass, jlong handle) {
  return static_cast<jint>(fromHandle(handle)->renderer.initGl());
}

jstring nativeGetGlInfo(JNIEnv* env, jclass, jlong handle) {
  return env->NewStringUTF(fromHandle(handle)->renderer.glInfo().c_str());
}

jstring nativeGetLastError(JNIEnv* env, jclass, jlong handle) {
  return env->NewStringUTF(fromHandle(handle)->renderer.lastError().c_str());
}

void nativeSetGeometry(JNIEnv* env, jclass, jlong handle, jfloatArray display, jfloatArray tracker,
                       jint width, jint height, jboolean mirrored) {
  if (display == nullptr || tracker == nullptr || env->GetArrayLength(display) < 16 ||
      env->GetArrayLength(tracker) < 16) {
    return;
  }
  float displayValues[16];
  float trackerValues[16];
  env->GetFloatArrayRegion(display, 0, 16, displayValues);
  env->GetFloatArrayRegion(tracker, 0, 16, trackerValues);
  Engine* engine = fromHandle(handle);
  engine->renderer.setDisplayMatrices(displayValues, trackerValues, mirrored == JNI_TRUE);
  engine->tracking.setImageSize(width, height);
}

void nativeSetRenderOptions(JNIEnv*, jclass, jlong handle, jboolean showLandmarks, jint region,
                            jboolean lightAdaptation) {
  const auto tintRegion = region == static_cast<jint>(makeup::TintRegion::kMakeup)
                              ? makeup::TintRegion::kMakeup
                              : makeup::TintRegion::kFull;
  fromHandle(handle)->renderer.setRenderOptions(showLandmarks == JNI_TRUE, tintRegion,
                                                lightAdaptation == JNI_TRUE);
}

void nativeSetTint(JNIEnv*, jclass, jlong handle, jfloat r, jfloat g, jfloat b, jfloat amount) {
  fromHandle(handle)->renderer.setTint(r, g, b, amount);
}

// [finish]: LipFinish (NativeBridge.LIP_FINISH_*); fuera de rango, satinado.
void nativeSetLips(JNIEnv*, jclass, jlong handle, jboolean enabled, jfloat r, jfloat g, jfloat b,
                   jfloat opacity, jint finish, jfloat gloss, jfloat lumaFollow) {
  makeup::LipStyle style;
  style.enabled = enabled == JNI_TRUE;
  style.r = r;
  style.g = g;
  style.b = b;
  style.opacity = opacity;
  style.finish = finish >= static_cast<jint>(makeup::LipFinish::kMatte) &&
                         finish <= static_cast<jint>(makeup::LipFinish::kShimmer)
                     ? static_cast<makeup::LipFinish>(finish)
                     : makeup::LipFinish::kSatin;
  style.gloss = gloss;
  style.lumaFollow = lumaFollow;
  fromHandle(handle)->renderer.setLips(style);
}

makeup::ColorLayer colorLayer(jboolean enabled, jfloat r, jfloat g, jfloat b, jfloat amount) {
  makeup::ColorLayer layer;
  layer.enabled = enabled == JNI_TRUE;
  layer.r = r;
  layer.g = g;
  layer.b = b;
  layer.amount = amount;
  return layer;
}

// Enums fuera de rango caen al primero (Kotlin ya valida; segunda defensa).
template <typename E>
E enumOr(jint value, E last) {
  return value >= 0 && value <= static_cast<jint>(last) ? static_cast<E>(value) : static_cast<E>(0);
}

void nativeSetLipLiner(JNIEnv*, jclass, jlong handle, jboolean enabled, jfloat r, jfloat g, jfloat b,
                       jfloat opacity) {
  fromHandle(handle)->renderer.setLipLiner(colorLayer(enabled, r, g, b, opacity));
}

void nativeSetCheeks(JNIEnv*, jclass, jlong handle, jboolean enabled, jfloat r, jfloat g, jfloat b,
                     jfloat opacity, jfloat spread, jint placement) {
  makeup::CheekStyle style;
  style.color = colorLayer(enabled, r, g, b, opacity);
  style.spread = spread;
  style.placement = enumOr(placement, makeup::CheekPlacement::kLow);
  fromHandle(handle)->renderer.setCheeks(style);
}

void nativeSetSkinLayer(JNIEnv*, jclass, jlong handle, jint layer, jboolean enabled, jfloat r, jfloat g,
                        jfloat b, jfloat amount) {
  if (layer < 0 || layer >= makeup::kSkinLayerCount) return;
  fromHandle(handle)->renderer.setSkinLayer(static_cast<makeup::SkinLayer>(layer),
                                            colorLayer(enabled, r, g, b, amount));
}

void nativeSetEyeShadow(JNIEnv*, jclass, jlong handle, jint slot, jboolean enabled, jfloat r, jfloat g,
                        jfloat b, jfloat opacity, jint region, jint finish) {
  makeup::EyeShadowStyle style;
  style.color = colorLayer(enabled, r, g, b, opacity);
  style.region = enumOr(region, makeup::EyeRegion::kBrowBone);
  style.finish = enumOr(finish, makeup::ShadowFinish::kShimmer);
  fromHandle(handle)->renderer.setEyeShadow(slot, style);
}

void nativeSetLiner(JNIEnv*, jclass, jlong handle, jboolean enabled, jfloat r, jfloat g, jfloat b,
                    jfloat opacity, jfloat thickness, jfloat wing) {
  makeup::LinerStyle style;
  style.color = colorLayer(enabled, r, g, b, opacity);
  style.thickness = thickness;
  style.wing = wing;
  fromHandle(handle)->renderer.setLiner(style);
}

void nativeSetLashes(JNIEnv*, jclass, jlong handle, jboolean enabled, jfloat opacity, jfloat length,
                     jfloat volume) {
  makeup::LashStyle style;
  style.enabled = enabled == JNI_TRUE;
  style.opacity = opacity;
  style.length = length;
  style.volume = volume;
  fromHandle(handle)->renderer.setLashes(style);
}

void nativeSetIris(JNIEnv*, jclass, jlong handle, jboolean enabled, jfloat r, jfloat g, jfloat b,
                   jfloat opacity) {
  fromHandle(handle)->renderer.setIris(colorLayer(enabled, r, g, b, opacity));
}

void nativeSetEffect(JNIEnv*, jclass, jlong handle, jint slot, jboolean enabled, jint type, jfloat intensity,
                     jint region) {
  makeup::EffectStyle style;
  style.enabled = enabled == JNI_TRUE;
  style.type = enumOr(type, makeup::EffectType::kSheen);
  style.intensity = intensity;
  style.region = enumOr(region, makeup::EffectRegion::kFullFace);
  fromHandle(handle)->renderer.setEffect(slot, style);
}

void nativeCommitRecipe(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->renderer.commitRecipe(); }

jint nativeDrawFrame(JNIEnv* env, jclass, jlong handle, jfloatArray texMatrix, jint width,
                     jint height, jlong frameStartNs, jlong cameraTimestampNs) {
  float matrix[16];
  env->GetFloatArrayRegion(texMatrix, 0, 16, matrix);
  return fromHandle(handle)->renderer.drawFrame(matrix, width, height, frameStartNs,
                                                cameraTimestampNs);
}

void nativeGetStats(JNIEnv* env, jclass, jlong handle, jfloatArray out) {
  if (out == nullptr || env->GetArrayLength(out) < makeup::kStatCount) return;
  float values[makeup::kStatCount];
  fromHandle(handle)->renderer.stats().snapshot(values);
  env->SetFloatArrayRegion(out, 0, makeup::kStatCount, values);
}

void nativeGetTrackerStats(JNIEnv* env, jclass, jlong handle, jfloatArray out) {
  if (out == nullptr || env->GetArrayLength(out) < makeup::kTrackStatCount) return;
  float values[makeup::kTrackStatCount];
  fromHandle(handle)->tracking.snapshotStats(values);
  env->SetFloatArrayRegion(out, 0, makeup::kTrackStatCount, values);
}

void nativeResetStats(JNIEnv*, jclass, jlong handle) {
  Engine* engine = fromHandle(handle);
  engine->renderer.stats().reset();
  engine->tracking.resetStats();
}

void nativeReleaseGl(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->renderer.releaseGl(); }

void nativeDestroy(JNIEnv*, jclass, jlong handle) { delete fromHandle(handle); }

// --- Tracker (hilo "makeup-tracker") ---

void nativeTrackerStart(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->tracking.start(); }

void nativeTrackerStop(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->tracking.stop(); }

void nativeTrackerAbort(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->tracking.abortCrop(); }

jint nativeTrackerReadyKind(JNIEnv*, jclass, jlong handle) {
  return static_cast<jint>(fromHandle(handle)->tracking.readyCropKind());
}

jboolean nativeTrackerFillInput(JNIEnv* env, jclass, jlong handle, jfloatArray out, jfloat scale,
                                jfloat offset) {
  if (out == nullptr) return JNI_FALSE;
  const jsize count = env->GetArrayLength(out);
  // Sección crítica: solo la conversión, sin otras llamadas JNI adentro.
  auto* data = static_cast<float*>(env->GetPrimitiveArrayCritical(out, nullptr));
  if (data == nullptr) return JNI_FALSE;
  const bool ok = fromHandle(handle)->tracking.fillInput(data, count, scale, offset);
  env->ReleasePrimitiveArrayCritical(out, data, ok ? 0 : JNI_ABORT);
  return ok ? JNI_TRUE : JNI_FALSE;
}

void nativeTrackerSubmitDetections(JNIEnv* env, jclass, jlong handle, jfloatArray regressors,
                                   jfloatArray scores, jfloat inferenceMs) {
  Engine* engine = fromHandle(handle);
  if (regressors == nullptr || scores == nullptr ||
      env->GetArrayLength(regressors) < Engine::kRegressorCount ||
      env->GetArrayLength(scores) < makeup::BlazeFaceDecoder::kAnchorCount) {
    engine->tracking.abortCrop();  // salidas inesperadas: no dejar el ciclo trabado
    return;
  }
  env->GetFloatArrayRegion(regressors, 0, Engine::kRegressorCount, engine->regressors.data());
  env->GetFloatArrayRegion(scores, 0, makeup::BlazeFaceDecoder::kAnchorCount, engine->scores.data());
  engine->tracking.submitDetections(engine->regressors.data(), engine->scores.data(), inferenceMs);
}

void nativeTrackerSubmitLandmarks(JNIEnv* env, jclass, jlong handle, jfloatArray landmarks,
                                  jfloat presenceLogit, jfloat inferenceMs) {
  Engine* engine = fromHandle(handle);
  if (landmarks == nullptr) {
    engine->tracking.abortCrop();
    return;
  }
  // Si el modelo devuelve menos puntos, submitLandmarks lo trata como cara perdida.
  const jsize count = std::min<jsize>(env->GetArrayLength(landmarks), TrackingState::kFloats);
  env->GetFloatArrayRegion(landmarks, 0, count, engine->landmarks.data());
  engine->tracking.submitLandmarks(engine->landmarks.data(), count, presenceLogit, inferenceMs);
}

// --- Studio (F4): una foto ---

jlong nativeStillCreate(JNIEnv* env, jclass, jintArray argb, jint width, jint height) {
  auto* session = new StillSession();
  if (copyArgb(env, argb, width, height, &session->image)) {
    session->locator.begin(width, height);
  } else {
    session->locator.begin(0, 0);  // kFailed / kBadImage
  }
  return reinterpret_cast<jlong>(session);
}

jint nativeStillStep(JNIEnv*, jclass, jlong handle) {
  return static_cast<jint>(stillFromHandle(handle)->locator.step());
}

jboolean nativeStillFillInput(JNIEnv* env, jclass, jlong handle, jfloatArray out, jfloat scale, jfloat offset) {
  if (out == nullptr) return JNI_FALSE;
  StillSession* session = stillFromHandle(handle);
  const jsize count = env->GetArrayLength(out);
  std::vector<float> tensor(static_cast<size_t>(count));
  if (!session->locator.fillInput(session->image, tensor.data(), count, scale, offset)) return JNI_FALSE;
  env->SetFloatArrayRegion(out, 0, count, tensor.data());
  return JNI_TRUE;
}

void nativeStillSubmitDetections(JNIEnv* env, jclass, jlong handle, jfloatArray regressors, jfloatArray scores) {
  StillSession* session = stillFromHandle(handle);
  session->regressors = copyFloats(env, regressors);
  session->scores = copyFloats(env, scores);
  session->locator.submitDetections(session->regressors.data(), static_cast<int>(session->regressors.size()),
                                    session->scores.data(), static_cast<int>(session->scores.size()));
}

void nativeStillSubmitLandmarks(JNIEnv* env, jclass, jlong handle, jfloatArray landmarks, jfloat presenceLogit) {
  StillSession* session = stillFromHandle(handle);
  session->landmarks = copyFloats(env, landmarks);
  session->locator.submitLandmarks(session->landmarks.data(), static_cast<int>(session->landmarks.size()),
                                   presenceLogit);
}

void nativeStillFail(JNIEnv*, jclass, jlong handle, jint status) {
  stillFromHandle(handle)->locator.fail(static_cast<makeup::StillFaceStatus>(status));
}

// kLookValueCount floats (look_analysis.h). Sin cara, solo el estado.
jfloatArray nativeStillAnalyze(JNIEnv* env, jclass, jlong handle) {
  StillSession* session = stillFromHandle(handle);
  std::vector<float> values(makeup::kLookValueCount, 0.0f);
  makeup::StillFaceStatus status = session->locator.status();
  if (session->locator.step() == makeup::StillFaceLocator::Step::kDone &&
      !makeup::analyzeLook(session->image, session->locator.landmarks(), values.data())) {
    status = makeup::StillFaceStatus::kBadImage;  // sin piel base no hay referencia
  }
  values[makeup::kLookStatus] = static_cast<float>(status);
  values[makeup::kLookEyeDistancePx] = session->locator.eyeDistancePx();
  values[makeup::kLookYawRatio] = session->locator.yawRatio();
  return toFloatArray(env, values.data(), makeup::kLookValueCount);
}

void nativeStillDestroy(JNIEnv*, jclass, jlong handle) { delete stillFromHandle(handle); }

// Swatches × kPaletteSwatchFloats (r, g, b sRGB [0,1], fracción), por área.
jfloatArray nativeStillPalette(JNIEnv* env, jclass, jintArray argb, jint width, jint height) {
  makeup::StillImage image;
  if (!copyArgb(env, argb, width, height, &image)) return toFloatArray(env, nullptr, 0);
  std::array<makeup::PaletteSwatch, EngineConfig::kPaletteClusters> swatches{};
  const int count = makeup::extractPalette(image, swatches.data(), EngineConfig::kPaletteClusters);
  std::vector<float> values;
  values.reserve(static_cast<size_t>(count) * makeup::kPaletteSwatchFloats);
  for (int i = 0; i < count; ++i) {
    values.push_back(swatches[i].rgb[0]);
    values.push_back(swatches[i].rgb[1]);
    values.push_back(swatches[i].rgb[2]);
    values.push_back(swatches[i].fraction);
  }
  return toFloatArray(env, values.data(), static_cast<int>(values.size()));
}

const JNINativeMethod kMethods[] = {
    {"nativeGetConfig", "()[I", reinterpret_cast<void*>(nativeGetConfig)},
    {"nativeCreate", "()J", reinterpret_cast<void*>(nativeCreate)},
    {"nativeInitGl", "(J)I", reinterpret_cast<void*>(nativeInitGl)},
    {"nativeGetGlInfo", "(J)Ljava/lang/String;", reinterpret_cast<void*>(nativeGetGlInfo)},
    {"nativeGetLastError", "(J)Ljava/lang/String;", reinterpret_cast<void*>(nativeGetLastError)},
    {"nativeSetGeometry", "(J[F[FIIZ)V", reinterpret_cast<void*>(nativeSetGeometry)},
    {"nativeSetRenderOptions", "(JZIZ)V", reinterpret_cast<void*>(nativeSetRenderOptions)},
    {"nativeSetTint", "(JFFFF)V", reinterpret_cast<void*>(nativeSetTint)},
    {"nativeSetLips", "(JZFFFFIFF)V", reinterpret_cast<void*>(nativeSetLips)},
    {"nativeSetLipLiner", "(JZFFFF)V", reinterpret_cast<void*>(nativeSetLipLiner)},
    {"nativeSetCheeks", "(JZFFFFFI)V", reinterpret_cast<void*>(nativeSetCheeks)},
    {"nativeSetSkinLayer", "(JIZFFFF)V", reinterpret_cast<void*>(nativeSetSkinLayer)},
    {"nativeSetEyeShadow", "(JIZFFFFII)V", reinterpret_cast<void*>(nativeSetEyeShadow)},
    {"nativeSetLiner", "(JZFFFFFF)V", reinterpret_cast<void*>(nativeSetLiner)},
    {"nativeSetLashes", "(JZFFF)V", reinterpret_cast<void*>(nativeSetLashes)},
    {"nativeSetIris", "(JZFFFF)V", reinterpret_cast<void*>(nativeSetIris)},
    {"nativeSetEffect", "(JIZIFI)V", reinterpret_cast<void*>(nativeSetEffect)},
    {"nativeCommitRecipe", "(J)V", reinterpret_cast<void*>(nativeCommitRecipe)},
    {"nativeDrawFrame", "(J[FIIJJ)I", reinterpret_cast<void*>(nativeDrawFrame)},
    {"nativeGetStats", "(J[F)V", reinterpret_cast<void*>(nativeGetStats)},
    {"nativeGetTrackerStats", "(J[F)V", reinterpret_cast<void*>(nativeGetTrackerStats)},
    {"nativeResetStats", "(J)V", reinterpret_cast<void*>(nativeResetStats)},
    {"nativeReleaseGl", "(J)V", reinterpret_cast<void*>(nativeReleaseGl)},
    {"nativeDestroy", "(J)V", reinterpret_cast<void*>(nativeDestroy)},
    {"nativeTrackerStart", "(J)V", reinterpret_cast<void*>(nativeTrackerStart)},
    {"nativeTrackerStop", "(J)V", reinterpret_cast<void*>(nativeTrackerStop)},
    {"nativeTrackerAbort", "(J)V", reinterpret_cast<void*>(nativeTrackerAbort)},
    {"nativeTrackerReadyKind", "(J)I", reinterpret_cast<void*>(nativeTrackerReadyKind)},
    {"nativeTrackerFillInput", "(J[FFF)Z", reinterpret_cast<void*>(nativeTrackerFillInput)},
    {"nativeTrackerSubmitDetections", "(J[F[FF)V",
     reinterpret_cast<void*>(nativeTrackerSubmitDetections)},
    {"nativeTrackerSubmitLandmarks", "(J[FFF)V",
     reinterpret_cast<void*>(nativeTrackerSubmitLandmarks)},
    {"nativeStillCreate", "([III)J", reinterpret_cast<void*>(nativeStillCreate)},
    {"nativeStillStep", "(J)I", reinterpret_cast<void*>(nativeStillStep)},
    {"nativeStillFillInput", "(J[FFF)Z", reinterpret_cast<void*>(nativeStillFillInput)},
    {"nativeStillSubmitDetections", "(J[F[F)V", reinterpret_cast<void*>(nativeStillSubmitDetections)},
    {"nativeStillSubmitLandmarks", "(J[FF)V", reinterpret_cast<void*>(nativeStillSubmitLandmarks)},
    {"nativeStillFail", "(JI)V", reinterpret_cast<void*>(nativeStillFail)},
    {"nativeStillAnalyze", "(J)[F", reinterpret_cast<void*>(nativeStillAnalyze)},
    {"nativeStillDestroy", "(J)V", reinterpret_cast<void*>(nativeStillDestroy)},
    {"nativeStillPalette", "([III)[F", reinterpret_cast<void*>(nativeStillPalette)},
};

}  // namespace

extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void*) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
  jclass bridge = env->FindClass("com/makeupar/makeup_engine/NativeBridge");
  if (bridge == nullptr) return JNI_ERR;
  const auto count = static_cast<jint>(sizeof(kMethods) / sizeof(kMethods[0]));
  if (env->RegisterNatives(bridge, kMethods, count) != JNI_OK) return JNI_ERR;
  env->DeleteLocalRef(bridge);
  return JNI_VERSION_1_6;
}
