#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Labial fotorrealista (informe §5.5) sobre la malla tracked. Especificación y
// tests: tools/lips/lip_shading.py (shade); si cambia uno, cambia el otro.
//
//   w     = máscara · opacidad · orientación  (cobertura del labial en el píxel)
//   s     = L_píxel / L_labio_medio            (sombreado del labio real)
//   L     = mix(L_píxel, L_color · s, w · lumaFollow)
//   (a,b) = mix((a,b)_píxel, (a,b)_color · s, w)
//           OKLab es homogéneo: escalar la luz lineal por k escala (L, a, b)
//           por k^(1/3). El labial bajo la luz del labio es color · s: las
//           sombras y pliegues quedan oscuros y menos saturados, los reflejos
//           más claros (sin eso el color plano parece una calcomanía).
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo: (mapa^nitidez [+ destellos]) · gloss · luz · w · iluminado(s),
//           aditivo en lineal; no aparece en las sombras del labio.
//   salida: layerOver(color, cámara, w) con blending premultiplicado
//           (color.glsl): el labial va encima de la base sin pisarla
//           alrededor de la boca.
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
//   uLumaFollow    float  cuánto sigue la L del labio a la del color, [0,1]
//                         (1: cubre el tono del labio; 0: solo croma).
//   uLipLightness  float  L OKLab media medida del labio, [0,1] (o 0,55 si no
//                         hay); Renderer la limita a >= 0,1.
//   uGloss         float  intensidad del brillo, [0,1] (0 en mate).
//   uSharpness     float  exponente sobre el mapa de brillo, [1,8]: más alto,
//                         brillo más chico y concentrado.
//   uLight         float  atenuación del brillo por luz de la escena, [0,1].
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
#ifdef SHIMMER
uniform highp float uTime;
uniform float uSparkle;

// Celdas por ancho del mapa, probabilidad de que una celda brille y
// cambios por segundo (la intensidad es uSparkle, engine_config.h:
// kLipsSparkle). TICK_PERIOD: el patrón se repite cada 256 cambios (~43 s),
// así el hash recibe números chicos y no pierde resolución en fp32.
#define SPARKLE_CELLS vec2(96.0, 48.0)
#define SPARKLE_DENSITY 0.06
#define SPARKLE_RATE 6.0
#define TICK_PERIOD 256.0

#endif

// Rango de sombreado en el que aparece el brillo del labial (lip_shading.py;
// SHADING_MAX está en color.glsl).
#define GLOSS_SHADING_LOW 0.75
#define GLOSS_SHADING_HIGH 1.05

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
// vMapUv menos el desplazamiento del brillo por la pose (lips.vert): sin
// aritmética en el fragment, la lectura no es dependiente y Mali la adelanta.
in highp vec2 vGlossUv;
// Orientación hacia la cámara [0,1] (lips.vert): 0 en la mitad del labio que
// queda de espaldas al girar la cabeza.
in float vFacing;
out vec4 fragColor;

void main() {
  // Las lecturas van antes de cualquier rama (flujo uniforme).
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  float mask = texture(uLipsMap, vMapUv).r;
  float glossMap = texture(uLipsMap, vGlossUv).g;
  float w = clamp(mask * uOpacity * vFacing, 0.0, 1.0);
  // Fuera del labio (el borde de la zona dibujada): no cambia el píxel. La
  // rama es coherente por zonas grandes.
  if (w <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // highp: entrada de oklabToLinearInGamut (ver color.glsl). La cámara llega
  // en mediump (srgbToLinear/linearToOklab): ~1e-3 de ruido, invisible.
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  // max: la CPU ya la limita a >= 0,1; esto cubre un uniform sin cargar (0).
  highp float shading = clamp(lab.x / max(uLipLightness, 0.1), 0.0, SHADING_MAX);
  highp vec3 lit = uTargetLab * shading;
  highp float lightness = clamp(mix(lab.x, lit.x, w * uLumaFollow), 0.0, 1.0);
  highp vec2 ab = mix(lab.yz, lit.yz, w);
  vec3 outLinear = oklabToLinearInGamut(vec3(lightness, ab));

  // uSharpness >= 1 y glossMap >= 0: pow está definido.
  float spec = pow(glossMap, uSharpness);
#ifdef SHIMMER
  highp vec2 cell = floor(vMapUv * SPARKLE_CELLS);
  highp float tick = mod(floor(uTime * SPARKLE_RATE), TICK_PERIOD);
  // Desplazamientos distintos en x e y: cada cambio es otro patrón, no el
  // mismo corrido en diagonal.
  float sparkle = step(1.0 - SPARKLE_DENSITY, hash12(cell + vec2(tick * 17.0, tick * 31.0)));
  spec += sparkle * uSparkle;
#endif
  spec *= uGloss * uLight * w * smoothstep(GLOSS_SHADING_LOW, GLOSS_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(spec), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, w);
}
