#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Labial fotorrealista (informe §5.5) sobre la malla tracked. Especificación y
// tests: tools/lips/lip_shading.py (shade); si cambia uno, cambia el otro.
//
//   w     = máscara · opacidad               (cobertura del labial en el píxel)
//   L     = L_labio + (L_color - L_labio_medio) · w · lumaFollow
//           (corre la media del labio hacia la L del color; conserva textura)
//   (a,b) = mix((a,b)_labio, (a,b)_color, w)
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo: (mapa^nitidez [+ destellos]) · gloss · luz · w, aditivo en lineal
//
// Variantes (Renderer las compila con #define):
//   sin SHIMMER  mate / satinado / brillo (cambian uGloss y uSharpness).
//   SHIMMER      además destellos: celdas del mapa que titilan (hash, sin texturas).
//
// Lecturas de textura por fragmento: 3 (cámara, máscara, brillo desplazado; las
// dos últimas sobre la misma textura RG8 de 64 KB, que entra en caché).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cámara (sRGB), unidad 0.
//   uLipsMap       sampler2D  mapa de labios RG8, unidad 1: .r máscara [0,1],
//                             .g brillo [0,1] (mesh/lips_maps.h).
//   uTargetLab     vec3   OKLab del color del labial (L en [0,1], a/b en ±0,4);
//                         se calcula una vez en CPU.
//   uOpacity       float  opacidad de la receta × fundido del tracker, [0,1].
//   uLumaFollow    float  cuánto se acerca la L del labio a la del color, [0,1].
//   uLipLightness  float  L OKLab media medida del labio, [0,1] (o 0,55 si no hay).
//   uGloss         float  intensidad del brillo, [0,1] (0 en mate).
//   uSharpness     float  exponente sobre el mapa de brillo, [1,8]: más alto,
//                         brillo más chico y concentrado.
//   uLight         float  atenuación del brillo por luz de la escena, [0,1].
//   uGlossShift    vec2   desplazamiento del brillo en UV del mapa, |.| <= ~0,1
//                         (sigue la pose: el reflejo se mueve al girar).
//   uTime          float  (SHIMMER) segundos, módulo 1000.
//   uSparkle       float  (SHIMMER) intensidad de los destellos, [0,1].

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explícito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uLipsMap;
uniform highp vec3 uTargetLab;
uniform float uOpacity;
uniform float uLumaFollow;
uniform highp float uLipLightness;
uniform float uGloss;
uniform float uSharpness;
uniform float uLight;
uniform highp vec2 uGlossShift;
#ifdef SHIMMER
uniform highp float uTime;
uniform float uSparkle;

// Celdas por ancho del mapa, probabilidad de que una celda brille y
// cambios por segundo (ver engine_config.h: kLipsSparkle*).
#define SPARKLE_CELLS vec2(96.0, 48.0)
#define SPARKLE_DENSITY 0.06
#define SPARKLE_RATE 6.0

// Hash 2D -> [0,1) sin texturas (Dave Hoskins, "hash without sine").
// highp: con fp16 el patrón se repite en bloques visibles.
highp float hash12(highp vec2 p) {
  highp vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
#endif

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
out vec4 fragColor;

void main() {
  // Las lecturas van antes de cualquier rama (flujo uniforme).
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  float mask = texture(uLipsMap, vMapUv).r;
  float glossMap = texture(uLipsMap, vMapUv - uGlossShift).g;
  float w = clamp(mask * uOpacity, 0.0, 1.0);
  // Fuera del labio (el borde de la zona dibujada): el mismo píxel que dibujó
  // el quad. La rama es coherente por zonas grandes.
  if (w <= 0.0) {
    fragColor = vec4(camera, 1.0);
    return;
  }

  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  highp float lightness =
      clamp(lab.x + (uTargetLab.x - uLipLightness) * w * uLumaFollow, 0.0, 1.0);
  highp vec2 ab = mix(lab.yz, uTargetLab.yz, w);
  vec3 outLinear = oklabToLinearInGamut(vec3(lightness, ab));

  // uSharpness >= 1 y glossMap >= 0: pow está definido.
  float spec = pow(glossMap, uSharpness);
#ifdef SHIMMER
  highp vec2 cell = floor(vMapUv * SPARKLE_CELLS);
  highp float tick = floor(uTime * SPARKLE_RATE);
  float sparkle = step(1.0 - SPARKLE_DENSITY, hash12(cell + tick * 17.0));
  spec += sparkle * uSparkle;
#endif
  spec *= uGloss * uLight * w;
  outLinear = min(outLinear + vec3(spec), vec3(1.0));
  fragColor = vec4(linearToSrgb(outLinear), 1.0);
}
