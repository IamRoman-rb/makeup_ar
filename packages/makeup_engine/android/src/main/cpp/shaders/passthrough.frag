#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Paso directo del frame de cámara: línea de base para medir el costo del
// resto de los shaders.
//
// Lecturas de textura por fragmento: 1.
// Uniforms:
//   uCamera  samplerExternalOES  frame de cámara (sRGB), unidad de textura 0.

precision mediump float;

uniform mediump samplerExternalOES uCamera;

// highp: si la coordenada se interpola en fp16 se pierde la precisión subpíxel
// que el vertex shader calcula en highp (ver camera_quad.vert).
in highp vec2 vTexCoord;
out vec4 fragColor;

void main() {
  fragColor = vec4(texture(uCamera, vTexCoord).rgb, 1.0);
}
