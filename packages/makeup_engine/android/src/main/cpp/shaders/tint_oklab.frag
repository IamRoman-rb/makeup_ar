#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Spike P1: tinte de pantalla completa en OKLab. Es el peor caso del
// compositor: ida y vuelta sRGB -> lineal -> OKLab -> lineal -> sRGB en cada
// píxel, sin máscara. Reemplaza solo la croma (a, b) y conserva L, igual que el
// shader de labios del informe §5.5.
//
// Lecturas de textura por fragmento: 1.
// Uniforms:
//   uCamera      samplerExternalOES  frame de cámara (sRGB), unidad de textura 0.
//   uTintAb      vec2   croma OKLab (a, b) del color objetivo, adimensional.
//                       Para colores sRGB: a en [-0.23, 0.28], b en [-0.31, 0.20].
//                       Se calcula una vez en CPU (Renderer::setTint).
//   uTintAmount  float  intensidad [0, 1], adimensional; 0 = sin cambio de croma.
//                       Ya viene recortada desde CPU; el clamp es defensa barata.

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
uniform vec2 uTintAb;
uniform float uTintAmount;

// highp: ver passthrough.frag.
in highp vec2 vTexCoord;
out vec4 fragColor;

void main() {
  vec3 lab = linearToOklab(srgbToLinear(texture(uCamera, vTexCoord).rgb));
  lab.yz = mix(lab.yz, uTintAb, clamp(uTintAmount, 0.0, 1.0));
  vec3 outLinear = clamp(oklabToLinear(lab), 0.0, 1.0);
  fragColor = vec4(linearToSrgb(outLinear), 1.0);
}
