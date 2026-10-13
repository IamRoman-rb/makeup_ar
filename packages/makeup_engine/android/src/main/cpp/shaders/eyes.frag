#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de ojos (P5-P6): hasta 4 sombras (en el orden de la receta), el
// delineado y las pestañas encima, en una sola pasada. Especificación y tests:
// tools/makeup/face_shading.py (compose); si cambia uno, cambia el otro.
//
//   sombra_i  a = (mapaA · selectA_i + mapaB.r · selectB_i) · opacidad · orientación
//   pestañas  a = max(hebras, raíz) · opacidad + hebras inferiores · opacidad_inf
//             (hebras procedurales en coordenadas de la línea, ver lashStrands)
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
// Lecturas de textura por fragmento: 4 (mapas de ojos A, B y C, RGBA8 de
// 120 KB cada uno, y, solo donde hay alguna capa, la cámara).
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
//   uEyeMapC        sampler2D  RGBA8, unidad 5: pestañas superiores (posición
//                              a lo largo de la línea [0,1], altura [0,1]; 1 =
//                              sin pestañas) e inferiores (ídem).
//   uLashLab        vec3   OKLab del color de las pestañas.
//   uLashAmount     float  opacidad de las pestañas superiores × fundido, [0,1]
//                          (0 = sin pestañas: no se calculan las hebras).
//   uLowerLashAmount float opacidad de las inferiores × fundido, [0,1].
//   uLashParams     vec4   hebras por ojo [10, 60], largo [0, 0,95] de la altura
//                          máxima, medio ancho de la hebra en la base [0, 0,5]
//                          de su celda, inclinación hacia afuera en la punta
//                          [0, 0,2] (unidades de posición a lo largo).
//   uLashRoot       float  oscurecimiento de la raíz (volumen), [0,1].
//   uWing           float  largo del wing, [0,1] del largo máximo (0 = sin wing).
//                          Con uWing = 0 la máscara del wing es 0 (smoothstep(0, 0, x) = 1).
//   uEyeSheen       float  brillo del efecto sheen sobre párpado y pliegue × fundido,
//                          [0, ~0,2] (lineal); 0 = apagado.
//   uGlitter        float  (SHIMMER) brillo de los destellos del efecto glitter
//                          sobre párpado y pliegue × fundido, [0,1].
//   uTime           float  (SHIMMER) segundos, módulo 1000.
//   uShadowSparkle  vec4   (SHIMMER) intensidad de los destellos por slot, [0,1].

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explícito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uEyeMapA;
uniform mediump sampler2D uEyeMapB;
uniform mediump sampler2D uEyeMapC;
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
uniform highp vec3 uLashLab;
uniform float uLashAmount;
uniform float uLowerLashAmount;
uniform vec4 uLashParams;
uniform float uLashRoot;
uniform float uEyeSheen;
#ifdef SHIMMER
uniform highp float uTime;
uniform vec4 uShadowSparkle;
uniform float uGlitter;

// Mismo esquema que los destellos del labial (lips.frag).
#define SPARKLE_CELLS vec2(160.0, 128.0)
#define SPARKLE_DENSITY 0.05
#define SPARKLE_RATE 5.0
#define TICK_PERIOD 256.0

#endif

// Ancho del final suave del wing (en fracción de su largo máximo).
#define WING_END_FEATHER 0.05
// Pestañas: altura de la raíz oscurecida, rango a lo largo de la línea en que
// hay hebras (sin pestañas justo en los ángulos) y escala de las inferiores
// (menos hebras, más finas y menos inclinadas).
#define LASH_ROOT_HEIGHT 0.07
#define LASH_S_START 0.03
#define LASH_S_END 0.96
#define LOWER_LASH_COUNT 0.6
#define LOWER_LASH_WIDTH 0.7
#define LOWER_LASH_CURL 0.4

// Hebras de pestañas en coordenadas de la línea: s a lo largo (0 ángulo
// externo -> 1 lagrimal), h altura normalizada (1 = sin pestañas). Cada celda
// de s es una hebra con largo y posición propios (hash), que se afina hacia la
// punta y se inclina hacia afuera (hacia el lagrimal, un poco hacia adentro).
// x es la coordenada en hebras (calculada afuera) y aa su fwidth: el
// antialiasado necesita derivadas, que solo valen fuera de ramas divergentes.
float lashStrands(highp float x, float s, float h, float lengthMax, float halfWidth, highp float aa,
                  float side) {
  highp float cell = floor(x);
  float jitter = hash12(vec2(cell, side * 31.0 + 7.0));
  // Más cortas hacia el lagrimal.
  float len = lengthMax * (0.6 + 0.4 * jitter) * mix(0.55, 1.0, smoothstep(1.0, 0.6, s));
  float t = h / max(len, 1.0e-3);  // 0 base -> 1 punta
  float w = halfWidth * pow(max(1.0 - t, 0.0), 0.7);
  float f = abs(fract(x) - 0.5 - (jitter - 0.5) * 0.3);
  float strand = 1.0 - smoothstep(w - aa, w + aa, f);
  return strand * step(t, 0.98) * smoothstep(LASH_S_START, LASH_S_START + 0.04, s) *
         (1.0 - smoothstep(LASH_S_END - 0.03, LASH_S_END, s));
}

// Coordenada en hebras con la inclinación (crece con h²).
highp float lashCoord(float s, float h, float count, float curl) {
  return (s + curl * h * h * (1.2 - 1.6 * s)) * count;
}

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
  vec4 mapC = texture(uEyeMapC, vMapUv);

  // Pestañas. Rama uniforme (uLashAmount es un uniform): las derivadas valen.
  float lash = 0.0;
  if (uLashAmount > 0.0) {
    float count = uLashParams.x;
    float curl = uLashParams.w;
    highp float upperX = lashCoord(mapC.r, mapC.g, count, curl);
    highp float lowerX = lashCoord(mapC.b, mapC.a, count * LOWER_LASH_COUNT, curl * LOWER_LASH_CURL);
    highp float upperAa = fwidth(upperX);
    highp float lowerAa = fwidth(lowerX);
    float upper = lashStrands(upperX, mapC.r, mapC.g, uLashParams.y, uLashParams.z, upperAa, vSide);
    float root = (1.0 - smoothstep(0.0, LASH_ROOT_HEIGHT, mapC.g)) * uLashRoot *
                 smoothstep(LASH_S_START, LASH_S_START + 0.08, mapC.r) *
                 (1.0 - smoothstep(LASH_S_END - 0.1, LASH_S_END, mapC.r));
    float lower = lashStrands(lowerX, mapC.b, mapC.a, uLashParams.y, uLashParams.z * LOWER_LASH_WIDTH, lowerAa,
                              vSide + 2.0);
    lash = clamp((max(upper, root) * uLashAmount + lower * uLowerLashAmount) * vFacing, 0.0, 1.0);
  }

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
  // Zona de los efectos de ojos: párpado + pliegue.
  float effectZone = clamp(mapA.r + mapA.g, 0.0, 1.0) * vFacing;
  float effectShine = effectZone * uEyeSheen;
#ifdef SHIMMER
  effectShine += effectZone * uGlitter;  // se multiplica por el destello más abajo
#endif
  if (a.x + a.y + a.z + a.w + liner + lash + effectShine <= 0.0) {
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
  float glitter = sparkle * effectZone * uGlitter;
#else
  float glitter = 0.0;
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
  mixLayer(lab, keep, shine, uLashLab * shading, lash, 0.0);
  vec3 outLinear = oklabToLinearInGamut(lab);

  // Efectos encima de todo: el delineado y las pestañas los tapan.
  shine += (glitter + effectZone * uEyeSheen) * (1.0 - liner) * (1.0 - lash);
  shine *= smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(shine), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - keep);
}
