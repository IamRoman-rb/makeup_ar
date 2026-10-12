#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de cara (P5): base, contorno, rubor e iluminador en una sola pasada.
// Especificación y tests: tools/makeup/face_shading.py (compose); si cambia
// uno, cambia el otro.
//
//   a_i   = máscara_i · intensidad_i · orientación   (máscaras: mapa de cara;
//           el rubor es piel · gaussiana analítica)
//   s     = L_píxel / L_piel_medida                  (sombreado de la piel real)
//   por capa, en orden (base, contorno, rubor, iluminador):
//           lab   = mix(lab, color_i · s, a_i)        (L y croma; lumaFollow 1)
//           brillo = mix(brillo, brillo_i, a_i)       (solo el iluminador tiene)
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo · iluminado(s), aditivo en lineal
//   salida: layerOver(color, cámara, 1 - Π(1 - a_i)) (blending premultiplicado)
//
// Lecturas de textura por fragmento: 2 (cámara, mapa de cara RGB8 de ~86 KB).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cámara (sRGB), unidad 0.
//   uFaceMap       sampler2D  mapa de cara RGB8 (mesh/face_maps.h), unidad 2:
//                             .r piel, .g contorno, .b iluminador, [0,1].
//   uSkinLightness float  L OKLab medida de la piel, [0,1] (o 0,55 si no hay);
//                         Renderer la limita a >= 0,1.
//   uLayerLab[4]   vec3   OKLab de cada capa (L en [0,1], a/b en ±0,4), en el
//                         orden de mezcla (face_style.h: kFace*).
//   uLayerAmount   vec4   intensidad de cada capa × fundido del tracker, [0,1];
//                         0 = capa apagada.
//   uHighlightShine float brillo aditivo máximo del iluminador, [0, ~0,3]
//                         (lineal).

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explícito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uFaceMap;
uniform highp float uSkinLightness;
uniform highp vec3 uLayerLab[4];
uniform vec4 uLayerAmount;
uniform float uHighlightShine;

// Tope del sombreado relativo y rango en que aparece el brillo
// (face_shading.py: SHADING_MAX, SHINE_SHADING_LOW/HIGH).
#define SHADING_MAX 1.6
#define SHINE_SHADING_LOW 0.85
#define SHINE_SHADING_HIGH 1.1

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
in highp vec2 vCheek;
in float vFacing;
out vec4 fragColor;

// Mezcla una capa en OKLab, su brillo y acumula lo que queda sin cubrir.
void mixLayer(inout highp vec3 lab, inout float keep, inout float shine, highp vec3 lit, float a,
              float layerShine) {
  lab = vec3(clamp(mix(lab.x, lit.x, a), 0.0, 1.0), mix(lab.yz, lit.yz, a));
  shine = mix(shine, layerShine, a);  // una capa encima tapa el brillo de abajo
  keep *= 1.0 - a;
}

void main() {
  // Las lecturas van antes de cualquier rama (flujo uniforme).
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  vec3 map = texture(uFaceMap, vMapUv).rgb;
  // Rubor analítico: la coordenada ya viene escalada por los sigmas.
  float cheek = exp(-0.5 * dot(vCheek, vCheek));
  vec4 a = clamp(vec4(map.r, map.g, map.r * cheek, map.b) * uLayerAmount * vFacing, 0.0, 1.0);
  // Sin ninguna capa en el píxel (fuera de la piel o receta sin cara): no
  // cambia nada. Coherente por zonas grandes.
  if (a.x + a.y + a.z + a.w <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  // max: la CPU ya la limita a >= 0,1; esto cubre un uniform sin cargar (0).
  highp float shading = clamp(lab.x / max(uSkinLightness, 0.1), 0.0, SHADING_MAX);
  float keep = 1.0;
  float shine = 0.0;
  mixLayer(lab, keep, shine, uLayerLab[0] * shading, a.x, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[1] * shading, a.y, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[2] * shading, a.z, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[3] * shading, a.w, uHighlightShine);
  vec3 outLinear = oklabToLinearInGamut(lab);

  shine *= smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(shine), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - keep);
}
