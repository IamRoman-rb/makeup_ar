#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Recorte del tracker con supersampling: promedia una grilla fija de TAPS×TAPS
// lecturas dentro del píxel del recorte, para no aliasar al reducir el frame
// (el detector lo achica ~10x). Fuera de la imagen (letterbox, ROI que se sale
// del cuadro) escribe negro, como el relleno de MediaPipe.
//
// TAPS: constante de compilación (CropPass la define: 4 detector, 2 landmarks).
// Lecturas de textura por fragmento: TAPS² (16 o 4).
// Uniforms:
//   uCamera  samplerExternalOES  frame de cámara (sRGB), unidad de textura 0.
// La salida queda en sRGB, sin conversión: es lo que esperan los modelos.

precision mediump float;

#ifndef TAPS
#define TAPS 1
#endif

uniform mediump samplerExternalOES uCamera;

// highp: ver passthrough.frag.
in highp vec2 vTexCoord;
in highp vec2 vImage;
out vec4 fragColor;

void main() {
  // Paso de textura por píxel del recorte (la cadena es afín: es constante).
  // Las derivadas se toman antes de cualquier rama (flujo uniforme).
  highp vec2 stepX = dFdx(vTexCoord);
  highp vec2 stepY = dFdy(vTexCoord);
  vec3 sum = vec3(0.0);
  for (int i = 0; i < TAPS; ++i) {
    for (int j = 0; j < TAPS; ++j) {
      highp vec2 offset = ((float(i) + 0.5) / float(TAPS) - 0.5) * stepX +
                          ((float(j) + 0.5) / float(TAPS) - 0.5) * stepY;
      sum += texture(uCamera, vTexCoord + offset).rgb;
    }
  }
  bool outside = any(lessThan(vImage, vec2(0.0))) || any(greaterThan(vImage, vec2(1.0)));
  fragColor = vec4(outside ? vec3(0.0) : sum / float(TAPS * TAPS), 1.0);
}
