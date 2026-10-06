// Puente JNI con com.makeupar.makeup_engine.NativeBridge.
//
// Por frame hay UNA sola llamada Kotlin -> C++ (nativeDrawFrame), sin
// allocations: la matriz se copia a un arreglo en la pila. Dart nunca cruza
// por frame: solo inicia/detiene, cambia el tinte y lee métricas (~2 Hz).
#include <jni.h>

#include <algorithm>
#include <memory>

#include "engine_config.h"
#include "renderer.h"

namespace {

using makeup::EngineConfig;
using makeup::Renderer;

Renderer* fromHandle(jlong handle) { return reinterpret_cast<Renderer*>(handle); }

jintArray nativeGetConfig(JNIEnv* env, jclass) {
  jint values[makeup::kConfigCount] = {};
  values[makeup::kConfigMaxPreviewLongSide] = EngineConfig::kMaxPreviewLongSide;
  values[makeup::kConfigMaxPreviewShortSide] = EngineConfig::kMaxPreviewShortSide;
  values[makeup::kConfigTargetFps] = EngineConfig::kTargetFps;
  values[makeup::kConfigStatsWindow] = EngineConfig::kStatsWindow;
  jintArray result = env->NewIntArray(makeup::kConfigCount);
  if (result != nullptr) env->SetIntArrayRegion(result, 0, makeup::kConfigCount, values);
  return result;
}

jlong nativeCreate(JNIEnv*, jclass) { return reinterpret_cast<jlong>(new Renderer()); }

jint nativeInitGl(JNIEnv*, jclass, jlong handle) {
  return static_cast<jint>(fromHandle(handle)->initGl());
}

jstring nativeGetGlInfo(JNIEnv* env, jclass, jlong handle) {
  return env->NewStringUTF(fromHandle(handle)->glInfo().c_str());
}

jstring nativeGetLastError(JNIEnv* env, jclass, jlong handle) {
  return env->NewStringUTF(fromHandle(handle)->lastError().c_str());
}

void nativeSetDisplayMatrix(JNIEnv* env, jclass, jlong handle, jfloatArray matrix) {
  if (matrix == nullptr || env->GetArrayLength(matrix) < 16) return;
  float values[16];
  env->GetFloatArrayRegion(matrix, 0, 16, values);
  fromHandle(handle)->setDisplayMatrix(values);
}

void nativeSetTint(JNIEnv*, jclass, jlong handle, jfloat r, jfloat g, jfloat b, jfloat amount) {
  fromHandle(handle)->setTint(r, g, b, amount);
}

void nativeDrawFrame(JNIEnv* env, jclass, jlong handle, jfloatArray texMatrix, jint width,
                     jint height, jlong frameStartNs, jlong cameraTimestampNs) {
  float matrix[16];
  env->GetFloatArrayRegion(texMatrix, 0, 16, matrix);
  fromHandle(handle)->drawFrame(matrix, width, height, frameStartNs, cameraTimestampNs);
}

void nativeGetStats(JNIEnv* env, jclass, jlong handle, jfloatArray out) {
  if (out == nullptr || env->GetArrayLength(out) < makeup::kStatCount) return;
  float values[makeup::kStatCount];
  fromHandle(handle)->stats().snapshot(values);
  env->SetFloatArrayRegion(out, 0, makeup::kStatCount, values);
}

void nativeResetStats(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->stats().reset(); }

void nativeReleaseGl(JNIEnv*, jclass, jlong handle) { fromHandle(handle)->releaseGl(); }

void nativeDestroy(JNIEnv*, jclass, jlong handle) { delete fromHandle(handle); }

const JNINativeMethod kMethods[] = {
    {"nativeGetConfig", "()[I", reinterpret_cast<void*>(nativeGetConfig)},
    {"nativeCreate", "()J", reinterpret_cast<void*>(nativeCreate)},
    {"nativeInitGl", "(J)I", reinterpret_cast<void*>(nativeInitGl)},
    {"nativeGetGlInfo", "(J)Ljava/lang/String;", reinterpret_cast<void*>(nativeGetGlInfo)},
    {"nativeGetLastError", "(J)Ljava/lang/String;", reinterpret_cast<void*>(nativeGetLastError)},
    {"nativeSetDisplayMatrix", "(J[F)V", reinterpret_cast<void*>(nativeSetDisplayMatrix)},
    {"nativeSetTint", "(JFFFF)V", reinterpret_cast<void*>(nativeSetTint)},
    {"nativeDrawFrame", "(J[FIIJJ)V", reinterpret_cast<void*>(nativeDrawFrame)},
    {"nativeGetStats", "(J[F)V", reinterpret_cast<void*>(nativeGetStats)},
    {"nativeResetStats", "(J)V", reinterpret_cast<void*>(nativeResetStats)},
    {"nativeReleaseGl", "(J)V", reinterpret_cast<void*>(nativeReleaseGl)},
    {"nativeDestroy", "(J)V", reinterpret_cast<void*>(nativeDestroy)},
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
