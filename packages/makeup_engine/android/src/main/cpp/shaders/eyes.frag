#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de ojos (P5): hasta 4 sombras (en el orden de la receta) y el
// delineado encima, en una sola pasada. Especificación y tests:
// tools/makeup/face_shading.py (compose); si cambia uno, cambia el otro.
//
//   sombra_i  a = (mapaA · selectA_i + mapaB.r · selectB_i) · opacidad · orientación
//   delineado a = max(línea, wing) · opacidad · orientación, con
//             línea = 1 - smoothstep(borde, distancia a las pestañas) y
//             wing  = 1 - smoothstep(borde, distancia al wing), solo hasta su largo
//   s         = L_píxel / L_piel_medida
//   por capa:  lab    = mix(lab, color_i · s, a_i)
//              brillo = mix(brillo, brillo_i [+ destellos_i], a_i)
//   + brillo · iluminado(s), aditivo en lineal (el delineado no tiene brillo
//     y tapa el de las sombras que tiene debajo)
//   salida:   layerOver(color, cámara, 1 - Π(1 - a_i))
//
// Variantes (Renderer las compila con #define):
//   sin SHIMMER  sombras mate / satinadas.
//   SHIMMER      además destellos por celdas del mapa (hash, sin texturas).
//
// Lecturas de textura por fragmento: 3 (mapas de ojos A y B, RGBA8 de 120 KB
// cada uno, y, solo donde hay alguna capa, la cámara).
// Uniforms:
//   uCamera         samplerExternalOES  frame de cámara (sRGB), unidad 0.
//   uEyeMapA        sampler2D  RGBA8 (mesh/eye_maps.h), unidad 3: párpado,
//                              pliegue, V externa, lagrimal, [0,1].
//   uEyeMapB        sampler2D  RGBA8, unidad 4: hueso de la ceja [0,1];
//                              distancia a la línea de pestañas y al wing
//                              (normalizadas, 1 = lejos); avance del wing [0,1].
//   uSkinLightness  float  L OKLab medida de la piel, [0,1]; >= 0,1 desde la CPU.
//   uShadowLab[4]   vec3   OKLab de cada sombra.
//   uShadowAmount   vec4   opacidad de cada sombra × fundido, [0,1]; 0 = vacío.
//   uShadowSelect[4] vec4  selector one-hot de la región de cada sombra sobre
//                          el mapa A (0 si la región es el hueso de la ceja).
//   uShadowBrowBone vec4   1 en los slots cuya región es el hueso de la ceja.
//   uShadowShine    vec4   brillo aditivo (lineal) por slot, [0, ~0,2].
//   uLinerLab       vec3   OKLab del delineado.
//   uLinerAmount    float  opacidad del delineado × fundido, [0,1].
//   uLinerEdge      vec2   distancia normalizada en que el delineado deja de
//                          ser opaco (.x) y desaparece (.y), [0,1], .x < .y.
//   uWing           float  largo del wing, [0,1] del largo máximo (0 = sin wing).
//                          Con uWing = 0 la máscara del wing es 0 (smoothstep(0, 0, x) = 1).
//   uTime           float  (SHIMMER) segundos, módulo 1000.
//   uShadowSparkle  vec4   (SHIMMER) intensidad de los destellos por slot, [0,1].

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explícito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uEyeMapA;
uniform mediump sampler2D uEyeMapB;
uniform highp float uSkinLightness;
uniform highp vec3 uShadowLab[4];
uniform vec4 uShadowAmount;
uniform vec4 uShadowSelect[4];
uniform vec4 uShadowBrowBone;
uniform vec4 uShadowShine;
uniform highp vec3 uLinerLab;
uniform float uLinerAmount;
uniform vec2 uLinerEdge;
uniform float uWing;
#ifdef SHIMMER
uniform highp float uTime;
uniform vec4 uShadowSparkle;

// Mismo esquema que los destellos del labial (lips.frag).
#define SPARKLE_CELLS vec2(160.0, 128.0)
#define SPARKLE_DENSITY 0.05
#define SPARKLE_RATE 5.0
#define TICK_PERIOD 256.0

// Hash 2D -> [0,1) sin texturas (Dave Hoskins, "hash without sine").
// highp: con fp16 el patrón se repite en bloques visibles.
highp float hash12(highp vec2 p) {
  highp vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
#endif

// Ancho del final suave del wing (en fracción de su largo máximo).
#define WING_END_FEATHER 0.05

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
in float vFacing;
// 0/1 según el lado de la cara (face.vert): los destellos no se espejan.
in float vSide;
out vec4 fragColor;

void mixLayer(inout highp vec3 lab, inout highp float keep, inout float shine, highp vec3 lit, float a,
              float layerShine) {
  lab = vec3(clamp(mix(lab.x, lit.x, a), 0.0, 1.0), mix(lab.yz, lit.yz, a));
  shine = mix(shine, layerShine, a);  // una capa encima tapa el brillo de abajo
  keep *= 1.0 - a;
}

void main() {
  vec4 mapA = texture(uEyeMapA, vMapUv);
  vec4 mapB = texture(uEyeMapB, vMapUv);

  vec4 regions = vec4(dot(mapA, uShadowSelect[0]), dot(mapA, uShadowSelect[1]),
                      dot(mapA, uShadowSelect[2]), dot(mapA, uShadowSelect[3])) +
                 mapB.r * uShadowBrowBone;
  vec4 a = clamp(regions * uShadowAmount * vFacing, 0.0, 1.0);
  // Borde del delineado de al menos ~1,5 px de pantalla: con thickness bajo el
  // borde de la receta mide menos de un píxel y titilaba con el tracker.
  // fwidth antes de cualquier rama (necesita derivadas).
  float lineEdge = uLinerEdge.x + max(uLinerEdge.y - uLinerEdge.x, 1.5 * fwidth(mapB.g));
  float wingEdge = uLinerEdge.x + max(uLinerEdge.y - uLinerEdge.x, 1.5 * fwidth(mapB.b));
  float line = 1.0 - smoothstep(uLinerEdge.x, lineEdge, mapB.g);
  // El final del wing se difumina en WING_END_FEATHER, o en la mitad de su
  // largo si es más corto (así un wing corto arranca opaco).
  float wingEnd = max(uWing - WING_END_FEATHER, 0.5 * uWing);
  float wing = (1.0 - smoothstep(uLinerEdge.x, wingEdge, mapB.b)) *
               (1.0 - smoothstep(wingEnd, uWing, mapB.a));
  float liner = clamp(max(line, wing) * uLinerAmount * vFacing, 0.0, 1.0);
  if (a.x + a.y + a.z + a.w + liner <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  // La cámara se lee después de la salida temprana: la textura externa es la
  // lectura cara (el driver convierte YUV) y la pasada cubre toda la cara
  // aunque la receta tenga solo algunas regiones. Sin mipmaps (OES), leerla
  // dentro de la rama no depende de derivadas: el resultado es el mismo.
  vec3 camera = texture(uCamera, vTexCoord).rgb;

  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  highp float shading = clamp(lab.x / max(uSkinLightness, 0.1), 0.0, SHADING_MAX);
  vec4 layerShine = uShadowShine;
#ifdef SHIMMER
  highp vec2 cell = floor(vMapUv * SPARKLE_CELLS) + vec2(vSide * 997.0, 0.0);
  highp float tick = mod(floor(uTime * SPARKLE_RATE), TICK_PERIOD);
  float sparkle = step(1.0 - SPARKLE_DENSITY, hash12(cell + vec2(tick * 17.0, tick * 31.0)));
  layerShine += sparkle * uShadowSparkle;
#endif
  // highp: con fp16, 1 - a para a < ~2e-4 da 1 y el borde de las máscaras
  // quedaba sin cobertura.
  highp float keep = 1.0;
  float shine = 0.0;
  mixLayer(lab, keep, shine, uShadowLab[0] * shading, a.x, layerShine.x);
  mixLayer(lab, keep, shine, uShadowLab[1] * shading, a.y, layerShine.y);
  mixLayer(lab, keep, shine, uShadowLab[2] * shading, a.z, layerShine.z);
  mixLayer(lab, keep, shine, uShadowLab[3] * shading, a.w, layerShine.w);
  mixLayer(lab, keep, shine, uLinerLab * shading, liner, 0.0);
  vec3 outLinear = oklabToLinearInGamut(lab);

  shine *= smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(shine), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - keep);
}
