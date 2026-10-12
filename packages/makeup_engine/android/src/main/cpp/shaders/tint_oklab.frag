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
// mediump explícito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uMask;
// highp: coordenada de textura (ver camera_quad.vert).
in highp vec2 vOutputUv;
#endif

// highp: ver passthrough.frag.
in highp vec2 vTexCoord;
out vec4 fragColor;

void main() {
  // Las dos lecturas van antes de cualquier rama (flujo uniforme).
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  float amount = clamp(uTintAmount, 0.0, 1.0);
#ifdef MASKED
  amount *= texture(uMask, vOutputUv).r;
  // Fuera de la región (casi toda la imagen) no se toca el color: ahorra la
  // ida y vuelta a OKLab y no degrada las sombras en fp16. La rama es
  // coherente por zonas grandes, así que es barata.
  if (amount <= 0.0) {
    fragColor = vec4(camera, 1.0);
    return;
  }
#endif
  // Nota (P4): el clamp por canal de abajo no conserva el gamut. En luces y
  // sombras extremas la croma pedida sale del cubo RGB y el tono se desvía;
  // P4 debe reducir la croma hasta entrar en gamut.
  vec3 lab = linearToOklab(srgbToLinear(camera));
  lab.yz = mix(lab.yz, uTintAb, amount);
  vec3 outLinear = clamp(oklabToLinear(lab), 0.0, 1.0);
  fragColor = vec4(linearToSrgb(outLinear), 1.0);
}
