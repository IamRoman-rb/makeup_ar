#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Tinte de pantalla completa en OKLab: reemplaza solo la croma (a, b) y
// conserva L, igual que el shader de labios del informe §5.5. Ida y vuelta
// sRGB -> lineal -> OKLab -> lineal -> sRGB en cada píxel. Es el modo de
// prueba del Espejo con "Solo labios" apagado; el labial va en lips.frag.
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
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  float amount = clamp(uTintAmount, 0.0, 1.0);
  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  lab.x = clamp(lab.x, 0.0, 1.0);
  lab.yz = mix(lab.yz, uTintAb, amount);
  // En luces y sombras extremas la croma pedida sale del cubo RGB: se baja la
  // croma (no se recorta por canal) para no desviar el tono.
  vec3 outLinear = oklabToLinearInGamut(lab);
  fragColor = vec4(linearToSrgb(outLinear), 1.0);
}
