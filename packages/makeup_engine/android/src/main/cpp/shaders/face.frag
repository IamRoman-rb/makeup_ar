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
//           L     = mix(L, (color_i · s).L, a_i · lumaFollow_i)
//           ab    = mix(ab, (color_i · s).ab, a_i)
//           brillo = mix(brillo, brillo_i, a_i)       (solo el iluminador tiene)
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo · iluminado(s), aditivo en lineal
//   salida: layerOver(color, cámara, 1 - Π(1 - a_i)) (blending premultiplicado)
//
// Lecturas de textura por fragmento: 2 (mapa de cara RGB8 de ~86 KB y, solo
// donde hay alguna capa, la cámara).
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
//   uLayerLumaFollow vec4 cuánto sigue la L de cada capa a la de su color,
//                         [0,1] (1 salvo el iluminador).
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
uniform vec4 uLayerLumaFollow;
uniform float uHighlightShine;


// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
in highp vec2 vCheek;
in float vFacing;
out vec4 fragColor;

// Mezcla una capa en OKLab, su brillo y acumula lo que queda sin cubrir.
void mixLayer(inout highp vec3 lab, inout highp float keep, inout float shine, highp vec3 lit, float a,
              float lumaFollow, float layerShine) {
  lab = vec3(clamp(mix(lab.x, lit.x, a * lumaFollow), 0.0, 1.0), mix(lab.yz, lit.yz, a));
  shine = mix(shine, layerShine, a);  // una capa encima tapa el brillo de abajo
  keep *= 1.0 - a;
}

void main() {
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
  // La cámara se lee después de la salida temprana: la textura externa es la
  // lectura cara (el driver convierte YUV) y la pasada cubre toda la cara
  // aunque la receta tenga solo algunas regiones. Sin mipmaps (OES), leerla
  // dentro de la rama no depende de derivadas: el resultado es el mismo.
  vec3 camera = texture(uCamera, vTexCoord).rgb;

  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  // max: la CPU ya la limita a >= 0,1; esto cubre un uniform sin cargar (0).
  highp float shading = clamp(lab.x / max(uSkinLightness, 0.1), 0.0, SHADING_MAX);
  // highp: con fp16, 1 - a para a < ~2e-4 da 1 y el borde de las máscaras
  // quedaba sin cobertura.
  highp float keep = 1.0;
  float shine = 0.0;
  mixLayer(lab, keep, shine, uLayerLab[0] * shading, a.x, uLayerLumaFollow.x, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[1] * shading, a.y, uLayerLumaFollow.y, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[2] * shading, a.z, uLayerLumaFollow.z, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[3] * shading, a.w, uLayerLumaFollow.w, uHighlightShine);
  vec3 outLinear = oklabToLinearInGamut(lab);

  shine *= smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(shine), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - keep);
}
