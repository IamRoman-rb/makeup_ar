// Compositor: dibuja el frame de cámara (textura OES) en la superficie de
// Flutter, en paso directo o con tinte OKLab de pantalla completa; encima, las
// capas de la receta sobre la malla tracked: cara, ojos (FaceLayers,
// docs/ar_engine/FACE.md) y labios (docs/ar_engine/LIPS.md);
// alimenta al tracker con recortes del mismo frame (CropPass) y, opcionalmente,
// dibuja los landmarks.
//
// Hilos: initGl/drawFrame/releaseGl en el hilo de render (dueño del contexto
// GL); setTint/set* de la receta/commitRecipe/setDisplayMatrices/
// setRenderOptions desde cualquier hilo (atómicos / mutex corto que el render
// solo toma cuando algo cambió).
#pragma once

#include <array>
#include <atomic>
#include <mutex>
#include <string>

#include "crop_pass.h"
#include "scene_light.h"
#include "scene_pass.h"
#include "face_layers.h"
#include "face_style.h"
#include "frame_stats.h"
#include "gl_utils.h"
#include "tracking/tracking_state.h"

namespace makeup {

// Bits del valor que devuelve drawFrame (y nativeDrawFrame a Kotlin).
enum FrameFlag : int {
  kFrameFlagCropReady = 1,  // hay un recorte listo: avisar al hilo del tracker
};

// Qué se pinta. Mismo orden que TintRegion en Dart.
//   kFull: tinte de pantalla completa (setTint).
//   kMakeup: maquillaje de la receta (set* + commitRecipe) sobre la malla tracked.
enum class TintRegion : int { kFull = 0, kMakeup = 1 };

// Acabado del labial. Mismo orden que LIP_FINISH_* en NativeBridge.kt.
enum class LipFinish : int { kMatte = 0, kSatin = 1, kGloss = 2, kShimmer = 3 };

// Labial de la receta, ya validado y con valores por defecto (RecipeParams.kt).
struct LipStyle {
  bool enabled = false;
  float r = 0.0f;  // color sRGB [0,1]
  float g = 0.0f;
  float b = 0.0f;
  float opacity = 0.0f;     // [0,1]
  LipFinish finish = LipFinish::kSatin;
  float gloss = 0.0f;       // [0,1]
  float lumaFollow = 0.0f;  // [0,1]
};

class Renderer {
 public:
  // [tracking] no es dueño; tiene que vivir más que el Renderer.
  explicit Renderer(TrackingState* tracking) : tracking_(tracking) {}

  // Crea programas, geometría, el mapa de labios y la textura OES de la
  // cámara. Devuelve el id de la textura OES, o 0 si falla (ver lastError()).
  GLuint initGl();

  // Procesa un frame: termina/lanza el recorte del tracker, dibuja y hace
  // eglSwapBuffers sobre la superficie actual (en iOS no presenta: la salida
  // es el framebuffer de setOutputFramebuffer y la plataforma hace el flush). [texMatrix]: 16 floats de
  // SurfaceTexture.getTransformMatrix(). Devuelve bits de FrameFlag.
  int drawFrame(const float* texMatrix, int width, int height, int64_t frameStartNs,
                int64_t cameraTimestampNs);

  void releaseGl();

  // iOS (hilo de render, antes de drawFrame): textura 2D del frame de cámara
  // (CVOpenGLESTextureCache crea una por frame; no es dueño) y framebuffer de
  // salida. En Android no se llaman: textura OES propia y framebuffer 0.
  void setCameraTexture(GLuint texture) { externalCameraTexture_ = texture; }
  void setOutputFramebuffer(GLuint framebuffer) {
    outputFramebuffer_.store(framebuffer, std::memory_order_relaxed);
  }

  // Tinte de pantalla completa (TintRegion::kFull): color sRGB [0,1] e
  // intensidad [0,1]. amount == 0 usa el shader de paso directo.
  void setTint(float r, float g, float b, float amount);

  // Receta (TintRegion::kMakeup): cada set* guarda la región en una receta
  // pendiente; commitRecipe() la publica entera, así el render nunca dibuja
  // media receta. Los valores se recortan a rango.
  void setLips(const LipStyle& style);
  // Delineado de labios (lips.liner): solo se dibuja con labial.
  void setLipLiner(const ColorLayer& style);
  void setCheeks(const CheekStyle& style);
  void setSkinLayer(SkinLayer layer, const ColorLayer& style);
  // [slot] en [0, kMaxEyeShadows): en el orden de la receta (se pintan en ese orden).
  void setEyeShadow(int slot, const EyeShadowStyle& style);
  void setLiner(const LinerStyle& style);
  void setLashes(const LashStyle& style);
  // Color de iris (lentes de contacto).
  void setIris(const ColorLayer& style);
  // [slot] en [0, kMaxEffects).
  void setEffect(int slot, const EffectStyle& style);
  void commitRecipe();

  // 16 floats column-major cada una (ver camera_quad.vert, uDisplayMatrix):
  // [display] con espejo, para la pantalla; [tracker] sin espejo, para los
  // recortes. [mirrored]: la pantalla está espejada respecto de la imagen.
  void setDisplayMatrices(const float* display, const float* tracker, bool mirrored);

  // [lightAdaptation]: adaptar los colores de la receta al color de la luz de
  // la escena (scene_light.h); apagada, salen tal cual (comparación A/B).
  void setRenderOptions(bool showLandmarks, TintRegion region, bool lightAdaptation);

  FrameStats& stats() { return stats_; }

  // GL_VENDOR / GL_RENDERER / GL_VERSION / GLSL, tras initGl().
  std::string glInfo() const;
  std::string lastError() const;

 private:
  struct Program {
    GlProgram program;
    GLint displayMatrix = -1;
    GLint texMatrix = -1;
    GLint tintAb = -1;
    GLint tintAmount = -1;
    uint32_t uploadedDisplayVersion = 0;  // versión de uDisplayMatrix ya subida
  };

  struct MeshProgram {
    GlProgram program;
    GLint imageToClip = -1;
    GLint pointSize = -1;
    GLint color = -1;
  };

  struct LipsProgram {
    GlProgram program;
    GLint imageToClip = -1;
    GLint displayMatrix = -1;
    GLint texMatrix = -1;
    GLint targetLab = -1;
    GLint opacity = -1;
    GLint lumaFollow = -1;
    GLint lipLightness = -1;
    GLint gloss = -1;
    GLint sharpness = -1;
    GLint light = -1;
    GLint glossShift = -1;
    GLint view = -1;
    GLint time = -1;     // solo SHIMMER
    GLint sparkle = -1;  // solo SHIMMER
    GLint linerLab = -1;
    GLint linerAmount = -1;
    GLint occlusionGate = -1;
    GLint occlusion = -1;
    uint32_t uploadedDisplayVersion = 0;
  };

  // Labial listo para los uniforms (color ya en OKLab, acabado resuelto).
  struct LipUniforms {
    bool enabled = false;
    bool shimmer = false;
    float targetLab[3] = {0.0f, 0.0f, 0.0f};
    float opacity = 0.0f;
    float lumaFollow = 0.0f;
    float gloss = 0.0f;
    float sharpness = 1.0f;
    float sparkle = 0.0f;  // destellos (SHIMMER): acabado shimmer o efecto glitter
    float linerLab[3] = {0.0f, 0.0f, 0.0f};
    float linerAmount = 0.0f;  // delineado de labios; 0 = sin delineado
  };

  bool buildProgram(Program& out, const char* fragmentSource, const char* defines);
  bool buildMeshProgram();
  bool buildLipsProgram(LipsProgram& out, const char* defines);
  bool buildMeshGeometry();
  bool buildLipsMap();
  void runCropPass(const float* texMatrix, int width, int height, int64_t cameraTimestampNs,
                   int64_t nowNs, int* flags);
  void uploadMesh(const float* points);
  void adaptRecipeColors(bool enabled);
  static bool faceRect(const float* points, int width, int height, float out[4]);
  void drawFaceLayers(const RenderLandmarks& landmarks, const float* imageToClip, const float* texMatrix,
                      int64_t frameStartNs);
  void drawLips(const RenderLandmarks& landmarks, const float* imageToClip, const float* texMatrix,
                int64_t frameStartNs);
  void drawLandmarks(float alpha, const float* imageToClip, int width, int height);
  void setError(const std::string& error);
  GLuint cameraTexture() const;

  TrackingState* tracking_;

  Program passthrough_;
  Program tint_;
  MeshProgram mesh_;
  LipsProgram lips_;
  LipsProgram lipsShimmer_;
  FaceLayers faceLayers_;
  CropPass crop_;
  ScenePass scene_;
  SceneLightEstimator sceneLight_;
  GlVertexArray quadVao_;
  GlBuffer quadVbo_;
  GlTexture cameraTexture_;
  GLuint externalCameraTexture_ = 0;  // iOS; solo hilo de render
  std::atomic<GLuint> outputFramebuffer_{0};
  // Puntos tracked (VBO dinámico) para los landmarks y, con las UV, los labios.
  GlVertexArray meshVao_;
  GlVertexArray lipsVao_;
  GlBuffer meshVbo_;
  GlBuffer uvVbo_;
  GlBuffer normalVbo_;
  GlBuffer lipsIbo_;
  GlTexture lipsMap_;

  std::atomic<float> tintA_{0.0f};
  std::atomic<float> tintB_{0.0f};
  std::atomic<float> tintAmount_{0.0f};
  std::atomic<bool> showLandmarks_{false};
  std::atomic<int> region_{static_cast<int>(TintRegion::kFull)};

  // Protege displayMatrix_, trackerMatrix_, mirrored_, la receta pendiente y la
  // publicada, glInfo_ y lastError_.
  mutable std::mutex configMutex_;
  std::array<float, 16> displayMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  std::array<float, 16> trackerMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  bool mirrored_ = true;
  // Receta pendiente (set*) y publicada (commitRecipe).
  LipUniforms pendingLips_;
  ColorLayer pendingLipLiner_;
  ColorLayer pendingSkin_[kSkinLayerCount];
  CheekStyle pendingCheek_;
  EyeShadowStyle pendingShadows_[kMaxEyeShadows];
  LinerStyle pendingLiner_;
  LashStyle pendingLashes_;
  ColorLayer pendingIris_;
  EffectStyle pendingEffects_[kMaxEffects];
  LipUniforms lipUniforms_;
  FaceUniforms faceUniforms_;
  EyeUniforms eyeUniforms_;
  IrisUniforms irisUniforms_;
  // Se incrementan al cambiar la geometría o publicar una receta: el hilo de
  // render solo toma el mutex cuando cambian, no en cada frame.
  std::atomic<uint32_t> displayVersion_{1};
  std::atomic<uint32_t> recipeVersion_{1};

  // Solo hilo de render.
  std::array<float, 16> drawDisplayMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  std::array<float, 16> drawTrackerMatrix_{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  bool drawMirrored_ = true;
  uint32_t drawDisplayVersion_ = 0;
  LipUniforms drawLips_;
  FaceUniforms drawFace_;
  EyeUniforms drawEyes_;
  IrisUniforms drawIris_;
  uint32_t drawRecipeVersion_ = 0;
  // Colores de la receta sin adaptar (draw*_ son las copias adaptadas a la
  // luz de la escena; scene_light.h). Solo hilo de render.
  LipUniforms baseLips_;
  FaceUniforms baseFace_;
  EyeUniforms baseEyes_;
  IrisUniforms baseIris_;
  bool drawLightAdapted_ = false;
  std::atomic<bool> lightAdaptation_{true};
  std::array<float, EngineConfig::kLandmarkCount * 2> meshPoints_{};
  int64_t lastFrameStartNs_ = 0;
  std::string glInfo_;
  std::string lastError_;

  FrameStats stats_;
};

}  // namespace makeup
