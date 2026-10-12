#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Tinte en OKLab: reemplaza solo la croma (a, b) y conserva L, igual que el
// shader de labios del informe §5.5. Ida y vuelta sRGB -> lineal -> OKLab ->
// lineal -> sRGB en cada píxel.
//
// Variantes (Renderer las compila con #define):
//   sin MASKED  pantalla completa.
//   MASKED      la intensidad se multiplica por uMask (región, p. ej. labios).
//               Es provisional (P3): en P4 los labios usan máscara UV y brillo.
//
// Lecturas de textura por fragmento: 1 (sin MASKED) o 2 (MASKED).
// Uniforms:
//   uCamera      samplerExternalOES  frame de cámara (sRGB), unidad de textura 0.
//   uMask        sampler2D  (MASKED) cobertura [0, 1] en .r, en UV de salida,
//                       unidad 1. Ya incluye el fundido al aparecer/perder la cara.
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

#ifdef MASKED
uniform sampler2D uMask;
in vec2 vOutputUv;
#endif

// highp: ver passthrough.frag.
in highp vec2 vTexCoord;
out vec4 fragColor;

void main() {
  float amount = clamp(uTintAmount, 0.0, 1.0);
#ifdef MASKED
  amount *= texture(uMask, vOutputUv).r;
#endif
  vec3 lab = linearToOklab(srgbToLinear(texture(uCamera, vTexCoord).rgb));
  lab.yz = mix(lab.yz, uTintAb, amount);
  vec3 outLinear = clamp(oklabToLinear(lab), 0.0, 1.0);
  fragColor = vec4(linearToSrgb(outLinear), 1.0);
}
