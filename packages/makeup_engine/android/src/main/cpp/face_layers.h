// Pasadas de cara (base, contorno, rubor, iluminador) y de ojos (sombras y
// delineado) sobre la malla tracked (P5; docs/ar_engine/FACE.md). Dueña de sus
// programas, IBOs, VAOs y mapas UV; usa los VBOs de puntos, UV y normales del
// Renderer. Todo en el hilo de render.
#pragma once

#include <cstdint>
#include <string>

#include "face_style.h"
#include "gl_utils.h"

namespace makeup {

// Lo que comparten las pasadas en un frame (mismo origen que drawLips).
struct LayerFrame {
  GLuint cameraTexture = 0;
  const float* imageToClip = nullptr;   // 4 floats
  const float* displayMatrix = nullptr;  // 16 floats
  uint32_t displayVersion = 0;           // para no resubir uDisplayMatrix
  const float* texMatrix = nullptr;      // 16 floats
  float view[3] = {0.0f, 0.0f, 1.0f};    // dirección a la cámara en la malla
  float skinLightness = 0.55f;           // >= kLipsMinLightness
  float alpha = 1.0f;                    // fundido del tracker
  float timeSeconds = 0.0f;              // módulo 1000 (destellos)
};

class FaceLayers {
 public:
  // Atributos: 0 puntos, 1 UV, 2 normales (mismas ubicaciones que los labios).
  bool init(GLuint pointVbo, GLuint uvVbo, GLuint normalVbo, std::string* error);
  void release();

  // Cada una no dibuja nada si la receta no tiene capas en esa zona. Dejan el
  // blending apagado al salir.
  void drawFace(const FaceUniforms& face, const LayerFrame& frame);
  void drawEyes(const EyeUniforms& eyes, const LayerFrame& frame);

 private:
  struct Common {
    GlProgram program;
    GLint imageToClip = -1;
    GLint displayMatrix = -1;
    GLint texMatrix = -1;
    GLint view = -1;
    GLint skinLightness = -1;
    uint32_t uploadedDisplayVersion = 0;
  };
  struct FaceProgram : Common {
    GLint cheekMatrix = -1;
    GLint cheekOffset = -1;
    GLint layerLab = -1;
    GLint layerAmount = -1;
    GLint layerLumaFollow = -1;
    GLint highlightShine = -1;
  };
  struct EyesProgram : Common {
    GLint shadowLab = -1;
    GLint shadowAmount = -1;
    GLint shadowSelect = -1;
    GLint shadowBrowBone = -1;
    GLint shadowShine = -1;
    GLint linerLab = -1;
    GLint linerAmount = -1;
    GLint linerEdge = -1;
    GLint wing = -1;
    GLint lashLab = -1;
    GLint lashAmount = -1;
    GLint lowerLashAmount = -1;
    GLint lashParams = -1;
    GLint lashRoot = -1;
    GLint time = -1;           // solo SHIMMER
    GLint shadowSparkle = -1;  // solo SHIMMER
  };

  bool buildCommon(Common& out, const char* fragmentSource, const char* defines, const float* mapRect,
                   std::string* error);
  bool buildFaceProgram(std::string* error);
  bool buildEyesProgram(EyesProgram& out, const char* defines, std::string* error);
  bool buildGeometry(GLuint pointVbo, GLuint uvVbo, GLuint normalVbo);
  bool buildTextures(std::string* error);
  void bindCommon(Common& program, const LayerFrame& frame);

  FaceProgram face_;
  EyesProgram eyes_;
  EyesProgram eyesShimmer_;
  GlVertexArray faceVao_;
  GlVertexArray eyesVao_;
  GlBuffer faceIbo_;
  GlBuffer eyesIbo_;
  GlTexture faceMap_;
  GlTexture eyeMapA_;
  GlTexture eyeMapB_;
  GlTexture eyeMapC_;
};

}  // namespace makeup
