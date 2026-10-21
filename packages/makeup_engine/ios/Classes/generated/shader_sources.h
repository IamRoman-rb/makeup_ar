// Generado por tools/ios/gen_ios_sources.py desde cpp/shaders (como el paso de CMake). No editar.
#pragma once

namespace makeup::shaders {
inline constexpr char k_color_glsl[] = R"GLSL(// Conversiones de color compartidas: nico include (ver .claude/rules/shaders.md).
// Se inyecta en cada shader donde aparece la lnea `// @include color.glsl`.
// Matrices OKLab de Bjrn Ottosson (2020); ida y vuelta verificada en
// tools/studio/sample_region_reference.py.

// sRGB [0,1] -> lineal. Aproximacin gamma 2.2 (la misma del informe 5.5).
vec3 srgbToLinear(vec3 c) {
  return pow(max(c, vec3(0.0)), vec3(2.2));
}

// Lineal -> sRGB [0,1]. Los negativos se recortan antes del pow.
vec3 linearToSrgb(vec3 c) {
  return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

// RGB lineal -> OKLab (L en [0,1], a/b aprox. en [-0.4, 0.4]).
vec3 linearToOklab(vec3 c) {
  float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
  float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
  float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
  vec3 lms = pow(max(vec3(l, m, s), vec3(0.0)), vec3(1.0 / 3.0));
  return vec3(
      0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
      1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
      0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z);
}

// OKLab -> RGB lineal (puede salir de gamut: recortar despus).
// highp: el cubo triplica el error relativo y la matriz de salida (coeficientes
// de hasta 4,08 con cancelacin) lo amplifica; en fp16 dara 1-2 LSB de error
// en altas luces, visible como escalones en degradados de piel. Costo: ~20
// operaciones fp32 por pxel.
highp vec3 oklabToLinear(highp vec3 c) {
  highp vec3 lms = vec3(
      c.x + 0.3963377774 * c.y + 0.2158037573 * c.z,
      c.x - 0.1055613458 * c.y - 0.0638541728 * c.z,
      c.x - 0.0894841775 * c.y - 1.2914855480 * c.z);
  lms = lms * lms * lms;
  return vec3(
      4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
      -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
      -0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z);
}

// Pasos de la bsqueda binaria de oklabToLinearInGamut: la croma queda por
// debajo de la mxima que entra, a menos de 1/2^6 de la croma pedida (hasta
// ~5 % de la mxima si se pidi el triple; invisible en un labio). Es la
// perilla de costo: 4 pasos bajan el peor caso de 7 a 5 conversiones.
#define GAMUT_STEPS 6
// Tolerancia de inGamut: el redondeo de las matrices deja blancos, negros y
// canales en 0 apenas fuera del cubo (p. ej. 1,0000001) y sin tolerancia
// disparan la bsqueda completa sin necesidad. Chica a propsito: en colores
// muy oscuros el clamp por canal de 1e-4 ya desva el tono (lip_shading.py).
#define GAMUT_EPSILON 1e-5

bool inGamut(highp vec3 c) {
  return all(greaterThanEqual(c, vec3(-GAMUT_EPSILON))) &&
         all(lessThanEqual(c, vec3(1.0 + GAMUT_EPSILON)));
}

// OKLab -> RGB lineal dentro del cubo [0,1]. Si el color pedido sale de gamut,
// baja la croma (a, b) conservando exactamente L y el tono, en vez de recortar
// cada canal (que en rojos intensos sobre sombras los vuelve marrones).
// [lab.x] tiene que estar en [0,1]: con croma 0 (gris) siempre entra.
// Costo: 1 conversin si ya est en gamut; si no, GAMUT_STEPS + 1 ms. Cuntos
// pxeles salen depende del color: con labiales saturados, los reflejos del
// labio (sombreado > ~1,1 en lips.frag) salen; medir con el preset ms
// saturado. El bucle es de longitud fija (se desenrolla).
// Referencia: tools/lips/lip_shading.py (oklab_to_linear_in_gamut).
highp vec3 oklabToLinearInGamut(highp vec3 lab) {
  highp vec3 c = oklabToLinear(lab);
  if (inGamut(c)) return clamp(c, 0.0, 1.0);
  highp float lo = 0.0;
  highp float hi = 1.0;
  for (int i = 0; i < GAMUT_STEPS; ++i) {
    highp float mid = 0.5 * (lo + hi);
    bool inside = inGamut(oklabToLinear(vec3(lab.x, lab.yz * mid)));
    lo = inside ? mid : lo;
    hi = inside ? hi : mid;
  }
  // El clamp solo absorbe el error de redondeo del gris en los extremos.
  return clamp(oklabToLinear(vec3(lab.x, lab.yz * lo)), 0.0, 1.0);
}

// Sombreado relativo de las capas (s = L_pxel / L_referencia): tope para los
// reflejos fuertes y rango en que aparece el brillo (cara, ojos y labios;
// tools/lips/lip_shading.py y tools/makeup/face_shading.py).
#define SHADING_MAX 1.6
#define SHINE_SHADING_LOW 0.85
#define SHINE_SHADING_HIGH 1.1
// El sheen solo aclara lo que ya est ms iluminado que la piel media.
#define SHEEN_SHADING_LOW 0.95
#define SHEEN_SHADING_HIGH 1.2

// Salida de una capa de maquillaje (cara, ojos, labios) con blending
// premultiplicado: glBlendFuncSeparate(ONE, ONE_MINUS_SRC_ALPHA, ZERO, ONE).
//   result    color final de la capa calculado sobre la cmara (sRGB [0,1]).
//   camera    pxel de cmara de este fragmento (sRGB [0,1]).
//   coverage  cobertura total de la capa [0,1] (1 - (1 - a_i) si mezcla varias).
// Queda dst' = result - kcamera + kdst con k = 1 - alpha: sobre la cmara
// sola da exactamente [result]; sobre una capa anterior (p. ej. la base)
// compone encima; con A = 0 no cambia nada. La mezcla en OKLab no es lineal en
// sRGB: un oscurecimiento fuerte (delineado negro) puede dar result <
// (1 - A)camera, y entonces k baja lo justo para que el rgb no sea negativo
// (en vez de recortarlo, que aclaraba el borde). highp: cocientes chicos.
// Referencia: tools/makeup/face_shading.py (layer_over, blend).
vec4 layerOver(vec3 result, vec3 camera, float coverage) {
  highp vec3 ratio = result / max(camera, vec3(1.0e-3));
  highp float keep = min(1.0 - coverage, min(ratio.r, min(ratio.g, ratio.b)));
  return vec4(result - keep * camera, 1.0 - keep);
}

// Hash 2D -> [0,1) sin texturas (Dave Hoskins, "hash without sine").
// highp: con fp16 el patrn se repite en bloques visibles.
highp float hash12(highp vec2 p) {
  highp vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
)GLSL";
inline constexpr char k_camera_quad_vert[] = R"GLSL(#version 300 es
// Quad de pantalla completa (triangle strip de 4 vrtices) que muestrea el
// frame de cmara.
//
// Atributos:
//   aPosition      vec2  posicin en clip space, [-1, 1].
// Uniforms (column-major, transpose = GL_FALSE; adimensionales, espacio UV):
//   uDisplayMatrix mat4  UV de salida [0,1] -> UV de cmara "derecha": rotacin
//                        sensor->pantalla (mltiplos de 90) y espejo de la
//                        cmara frontal. Se sube solo cuando cambia.
//   uTexMatrix     mat4  SurfaceTexture.getTransformMatrix(); se sube por
//                        frame (el productor puede cambiar crop/transformacin).
// Salidas:
//   vTexCoord      vec2  coordenada en la textura de cmara.

// highp: coordenadas de textura. En mediump (fp16) el paso entre valores
// representables cerca de 1.0 es ~1/2048: a 1280 px da hasta ~0,3 px de error
// y se ve como temblor del borde. (En vertex shaders highp ya es el default de
// GLSL ES 3.00; se deja explcito como documentacin.)
precision highp float;

in vec2 aPosition;

uniform mat4 uDisplayMatrix;
uniform mat4 uTexMatrix;

out vec2 vTexCoord;

void main() {
  gl_Position = vec4(aPosition, 0.0, 1.0);
  vec2 outputUv = aPosition * 0.5 + 0.5;
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
}
)GLSL";
inline constexpr char k_passthrough_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Paso directo del frame de cmara: lnea de base para medir el costo del
// resto de los shaders.
//
// Lecturas de textura por fragmento: 1.
// Uniforms:
//   uCamera  samplerExternalOES  frame de cmara (sRGB), unidad de textura 0.

precision mediump float;

uniform mediump samplerExternalOES uCamera;

// highp: si la coordenada se interpola en fp16 se pierde la precisin subpxel
// que el vertex shader calcula en highp (ver camera_quad.vert).
in highp vec2 vTexCoord;
out vec4 fragColor;

void main() {
  fragColor = vec4(texture(uCamera, vTexCoord).rgb, 1.0);
}
)GLSL";
inline constexpr char k_tint_oklab_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Tinte de pantalla completa en OKLab: reemplaza solo la croma (a, b) y
// conserva L, igual que el shader de labios del informe 5.5. Ida y vuelta
// sRGB -> lineal -> OKLab -> lineal -> sRGB en cada pxel. Es el modo de
// prueba del Espejo con "Solo labios" apagado; el labial va en lips.frag.
//
// Lecturas de textura por fragmento: 1.
// Uniforms:
//   uCamera      samplerExternalOES  frame de cmara (sRGB), unidad de textura 0.
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
)GLSL";
inline constexpr char k_crop_roi_vert[] = R"GLSL(#version 300 es
// Recorte del tracker: dibuja un ROI (cuadrado rotado de la imagen) en un FBO
// de NN que despus se lee a CPU como tensor de entrada del modelo.
//
// Toda la cadena es afn, as que alcanza con transformar los 4 vrtices:
//   recorte [0,1] --uCropMatrix--> imagen [0,1] (y hacia abajo, SIN espejo)
//   --(x, 1 - y)--> UV de salida --uDisplayMatrix--> UV de cmara --uTexMatrix--> textura
//
// Atributos:
//   aPosition      vec2  posicin en clip space, [-1, 1] (quad del Renderer).
// Uniforms (column-major, transpose = GL_FALSE; adimensionales):
//   uCropMatrix    mat3  recorte -> imagen normalizada (tracking/roi.h, roiCropMatrix).
//   uDisplayMatrix mat4  UV de salida -> UV de cmara, SIN espejo (rotacin de pantalla).
//   uTexMatrix     mat4  SurfaceTexture.getTransformMatrix() del frame actual.
//
// La fila 0 del FBO (abajo en GL) es la fila 0 que devuelve glReadPixels; ac
// se la hace corresponder con v = 0 (arriba del recorte), as el buffer ledo
// ya est en el orden de filas del tensor.

// highp: coordenadas de textura con precisin subpxel (ver camera_quad.vert).
precision highp float;

in vec2 aPosition;

uniform mat3 uCropMatrix;
uniform mat4 uDisplayMatrix;
uniform mat4 uTexMatrix;

out vec2 vTexCoord;
out vec2 vImage;

void main() {
  gl_Position = vec4(aPosition, 0.0, 1.0);
  vec2 crop = aPosition * 0.5 + 0.5;
  vec2 image = (uCropMatrix * vec3(crop, 1.0)).xy;
  vImage = image;
  vec2 outputUv = vec2(image.x, 1.0 - image.y);
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
}
)GLSL";
inline constexpr char k_crop_roi_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Recorte del tracker con supersampling: promedia una grilla fija de TAPSTAPS
// lecturas dentro del pxel del recorte, para no aliasar al reducir el frame
// (el detector lo achica ~10x). Fuera de la imagen (letterbox, ROI que se sale
// del cuadro) escribe negro, como el relleno de MediaPipe.
//
// TAPS: constante de compilacin (CropPass la define: 4 detector, 2 landmarks).
// Lecturas de textura por fragmento: TAPS (16 o 4).
// Uniforms:
//   uCamera  samplerExternalOES  frame de cmara (sRGB), unidad de textura 0.
// La salida queda en sRGB, sin conversin: es lo que esperan los modelos.

precision mediump float;

#ifndef TAPS
#define TAPS 1
#endif

uniform mediump samplerExternalOES uCamera;

// highp: ver passthrough.frag.
in highp vec2 vTexCoord;
in highp vec2 vImage;
out vec4 fragColor;

void main() {
  // Paso de textura por pxel del recorte (la cadena es afn: es constante).
  // Las derivadas se toman antes de cualquier rama (flujo uniforme).
  highp vec2 stepX = dFdx(vTexCoord);
  highp vec2 stepY = dFdy(vTexCoord);
  vec3 sum = vec3(0.0);
  for (int i = 0; i < TAPS; ++i) {
    for (int j = 0; j < TAPS; ++j) {
      highp vec2 offset = ((float(i) + 0.5) / float(TAPS) - 0.5) * stepX +
                          ((float(j) + 0.5) / float(TAPS) - 0.5) * stepY;
      sum += texture(uCamera, vTexCoord + offset).rgb;
    }
  }
  bool outside = any(lessThan(vImage, vec2(0.0))) || any(greaterThan(vImage, vec2(1.0)));
  fragColor = vec4(outside ? vec3(0.0) : sum / float(TAPS * TAPS), 1.0);
}
)GLSL";
inline constexpr char k_face_mesh_vert[] = R"GLSL(#version 300 es
// Puntos o tringulos de la malla tracked: de px de imagen a clip space de la
// salida (o de la mscara, que cubre la misma rea).
//
// Atributos:
//   aPoint         vec2   punto en px de imagen (y hacia abajo, SIN espejo).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint  .xy + .zw. Incluye el espejo de la
//                         cmara frontal: con espejo, (-2/ancho, -2/alto, 1, 1).
//   uPointSize     float  tamao de punto en px (solo GL_POINTS), [1, 16].

// highp: posiciones en px de una imagen de hasta 1280 px; en mediump el paso
// cerca de 1280 es de 1 px.
precision highp float;

in vec2 aPoint;

uniform vec4 uImageToClip;
uniform float uPointSize;

void main() {
  gl_Position = vec4(aPoint * uImageToClip.xy + uImageToClip.zw, 0.0, 1.0);
  gl_PointSize = uPointSize;
}
)GLSL";
inline constexpr char k_solid_color_frag[] = R"GLSL(#version 300 es
// Color slido: puntos del overlay de depuracin y mscara de regin (la
// cobertura va en .r).
//
// Lecturas de textura por fragmento: 0.
// Uniforms:
//   uColor  vec4  RGBA [0, 1]. En la mscara, r = cobertura con el fundido aplicado.

precision mediump float;

uniform vec4 uColor;

out vec4 fragColor;

void main() {
  fragColor = uColor;
}
)GLSL";
inline constexpr char k_lips_vert[] = R"GLSL(#version 300 es
// Capa de labios: tringulos de la malla tracked alrededor de la boca
// (mesh::kLipsRegionTriangles), dibujados encima del quad de cmara.
//
// Atributos:
//   aPoint         vec2   vrtice tracked en px de imagen (y hacia abajo, SIN espejo).
//   aUv            vec2   UV cannico del vrtice (malla de MediaPipe, v hacia arriba).
//   aNormal        vec3   normal unitaria del vrtice en la malla cannica
//                         (mesh_normals.h; z hacia la cmara).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint  .xy + .zw; incluye el espejo de la
//                         pantalla (ver face_mesh.vert).
//   uDisplayMatrix mat4   UV de salida -> UV de cmara (ver camera_quad.vert).
//   uTexMatrix     mat4   SurfaceTexture.getTransformMatrix() del frame.
//   uMapTransform  vec4   UV cannico -> UV del mapa de labios:
//                         mapUv = aUv  .xy + .zw (mesh::kLipsMapUvRect).
//   uGlossShift    vec2   desplazamiento del brillo en UV del mapa, |.| <= ~0,1
//                         (sigue la pose: el reflejo se mueve al girar).
//   uView          vec3   direccin hacia la cmara en la malla cannica
//                         (unitaria; de frente (0, 0, 1)), de la pose.
//   uFacingFade    vec2   coseno normalvista en que el labial empieza (.x) y
//                         termina (.y) de aparecer (engine_config.h).
// Salidas:
//   vTexCoord      vec2   coordenada en la textura de cmara del pxel.
//   vMapUv         vec2   coordenada en el mapa de labios [0,1] (fuera = 0 por
//                         CLAMP_TO_EDGE con borde vaco).
//   vGlossUv       vec2   vMapUv - uGlossShift: dnde se lee el brillo. Se resta
//                         ac (es afn) para que la lectura del fragment no sea
//                         dependiente.
//   vFacing        float  [0,1]: 0 donde la superficie queda de espaldas. De
//                         perfil, la mitad lejana del labio quedara pintada
//                         encima del borde de la cara (no hay prueba de
//                         profundidad); as se desvanece.
//
// Todas las transformaciones son afines: interpolar por vrtice es exacto
// (vFacing no: es una aproximacin suave, que es lo que se busca).

// highp: posiciones en px de hasta 1280 y coordenadas de textura (ver
// camera_quad.vert y face_mesh.vert).
precision highp float;

in vec2 aPoint;
in vec2 aUv;
in vec3 aNormal;

uniform vec4 uImageToClip;
uniform mat4 uDisplayMatrix;
uniform mat4 uTexMatrix;
uniform vec4 uMapTransform;
uniform vec2 uGlossShift;
uniform vec3 uView;
uniform vec2 uFacingFade;

out vec2 vTexCoord;
out vec2 vMapUv;
out vec2 vGlossUv;
out mediump float vFacing;

void main() {
  vec2 clip = aPoint * uImageToClip.xy + uImageToClip.zw;
  gl_Position = vec4(clip, 0.0, 1.0);
  // Mismo camino que camera_quad.vert: as el labio muestrea exactamente el
  // pxel de cmara que el quad dibuj debajo.
  vec2 outputUv = clip * 0.5 + 0.5;
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
  vMapUv = aUv * uMapTransform.xy + uMapTransform.zw;
  vGlossUv = vMapUv - uGlossShift;
  vFacing = smoothstep(uFacingFade.x, uFacingFade.y, dot(aNormal, uView));
}
)GLSL";
inline constexpr char k_lips_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Labial fotorrealista (informe 5.5) sobre la malla tracked. Especificacin y
// tests: tools/lips/lip_shading.py (shade); si cambia uno, cambia el otro.
//
//   w     = mscara  opacidad  orientacin  (cobertura del labial en el pxel)
//   s     = L_pxel / L_labio_medio            (sombreado del labio real)
//   L     = mix(L_pxel, L_color  s, w  lumaFollow)
//   (a,b) = mix((a,b)_pxel, (a,b)_color  s, w)
//           OKLab es homogneo: escalar la luz lineal por k escala (L, a, b)
//           por k^(1/3). El labial bajo la luz del labio es color  s: las
//           sombras y pliegues quedan oscuros y menos saturados, los reflejos
//           ms claros (sin eso el color plano parece una calcomana).
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo: (mapa^nitidez  gloss [+ destellos])  luz  w  iluminado(s),
//           aditivo en lineal; no aparece en las sombras del labio.
//   delineado (lips.liner): anillo sobre el borde (canal .b del mapa), mezclado
//           encima con color  min(s, 1); tapa el brillo (spec  (1 - delineado))
//   oclusin (mano, dedos; tracking/lip_occlusion.h): con la compuerta prendida,
//           w y el delineado se multiplican por mix(1, parecido al labio, compuerta),
//           donde parecido = smoothstep sobre p = dot((a,b)/L  piel, eje).
//   borde real (uEdgeRefine; opcin 3 de TRACKER.md 10): en la franja del
//           contorno externo (canal .b < EDGE_BAND) la mscara se mezcla con
//           "parecido al labio" (misma p que la oclusin): el labial se retira
//           de la piel donde la malla se pas y llega al labio que asoma fuera
//           de ella. Los pxeles oscuros (sombreado < EDGE_MIN_SHADING) y los
//           quemados conservan la mscara: su croma es ruido (la boca abierta)
//           o est lavada (un reflejo en el borde).
//   salida: layerOver(color, cmara, 1 - (1 - w)(1 - delineado)) con blending premultiplicado
//           (color.glsl): el labial va encima de la base sin pisarla
//           alrededor de la boca.
//
// Variantes (Renderer las compila con #define):
//   sin SHIMMER  mate / satinado / brillo (cambian uGloss y uSharpness).
//   SHIMMER      adems destellos: celdas del mapa que titilan (hash, sin texturas).
//
// Lecturas de textura por fragmento: 3 (cmara, mscara, brillo desplazado; las
// dos ltimas sobre la misma textura RGBA8 de 128 KB, que entra en cach; el
// delineado usa la misma lectura que la mscara).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cmara (sRGB), unidad 0.
//   uLipsMap       sampler2D  mapa de labios RGBA8, unidad 1: .r mscara [0,1],
//                             .g brillo [0,1], .b distancia al borde del
//                             labial (delineado; 1 = lejos) (mesh/lips_maps.h).
//   uTargetLab     vec3   OKLab del color del labial (L en [0,1], a/b en 0,4);
//                         se calcula una vez en CPU.
//   uOpacity       float  opacidad de la receta  fundido del tracker, [0,1].
//   uLumaFollow    float  cunto sigue la L del labio a la del color, [0,1]
//                         (1: cubre el tono del labio; 0: solo croma).
//   uLipLightness  float  L OKLab media medida del labio, [0,1] (o 0,55 si no
//                         hay); Renderer la limita a >= 0,1.
//   uGloss         float  intensidad del brillo, [0,1] (0 en mate).
//   uSharpness     float  exponente sobre el mapa de brillo, [1,8]: ms alto,
//                         brillo ms chico y concentrado.
//   uLight         float  atenuacin del brillo por luz de la escena, [0,1].
//   uLinerLab      vec3   OKLab del delineado de labios.
//   uLinerAmount   float  opacidad del delineado  fundido, [0,1]; 0 = sin delineado.
//   uLinerEdge     float  distancia normalizada en que el delineado empieza a
//                         desvanecerse, (0, 1) (engine_config.h: kLipLinerEdge).
//   uOcclusionGate float  compuerta de oclusin [0,1]; 0 = sin oclusin (no se calcula).
//   uOcclusion     vec4   xy = cromaticidad (a,b)/L de la piel; zw = eje
//                         piel->labio / |eje| (p = 0 piel, 1 labio).
//   uEdgeRefine    float  borde real [0,1]; 0 = mscara del mapa tal cual (no se
//                         calcula). La CPU lo pone en 0 sin eje piel->labio.
//   uTime          float  (SHIMMER) segundos, mdulo 1000.
//   uSparkle       float  (SHIMMER) brillo de cada destello, [0,1] (acabado shimmer:
//                         kLipsSparkle  gloss; efecto glitter en labios: su
//                         intensidad). Ya no se multiplica por uGloss.

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explcito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uLipsMap;
uniform highp vec3 uTargetLab;
uniform float uOpacity;
uniform float uLumaFollow;
uniform highp float uLipLightness;
uniform float uGloss;
uniform float uSharpness;
uniform float uLight;
uniform highp vec3 uLinerLab;
uniform float uLinerAmount;
uniform float uLinerEdge;
uniform float uOcclusionGate;
uniform highp vec4 uOcclusion;
uniform float uEdgeRefine;
#ifdef SHIMMER
uniform highp float uTime;
uniform float uSparkle;

// Celdas por ancho del mapa, probabilidad de que una celda brille y
// cambios por segundo (la intensidad es uSparkle, engine_config.h:
// kLipsSparkle). TICK_PERIOD: el patrn se repite cada 256 cambios (~43 s),
// as el hash recibe nmeros chicos y no pierde resolucin en fp32.
#define SPARKLE_CELLS vec2(96.0, 48.0)
#define SPARKLE_DENSITY 0.06
#define SPARKLE_RATE 6.0
#define TICK_PERIOD 256.0

#endif

// Rango de sombreado en el que aparece el brillo del labial (lip_shading.py;
// SHADING_MAX est en color.glsl).
#define GLOSS_SHADING_LOW 0.75
#define GLOSS_SHADING_HIGH 1.05
// Oclusin: p (0 piel, 1 labio) en que el pxel empieza y termina de contar
// como labio. Piso de L para la cromaticidad (en lo muy oscuro amplifica el
// ruido de la cmara).
#define OCCLUSION_LOW 0.3
#define OCCLUSION_HIGH 0.6
#define OCCLUSION_MIN_LIGHTNESS 0.05
// Canal sRGB mximo en que un pxel quemado empieza y termina de ignorar la
// oclusin (centrado en kOcclusionClipValue de la CPU, engine_config.h).
#define OCCLUSION_CLIP_LOW 0.9
#define OCCLUSION_CLIP_HIGH 0.97
// Borde real (tools/lips/lip_shading.py: refined_mask): franja en distancia
// normalizada al contorno externo (0,5  0,85 mm), p en que el pxel pasa a
// labio y sombreado bajo el que no se usa la croma.
#define EDGE_BAND 0.5
#define EDGE_LOW 0.35
#define EDGE_HIGH 0.65
#define EDGE_MIN_SHADING 0.55
#define EDGE_SHADING_FEATHER 0.1
// Piso de la L del labio por la que se divide (la CPU ya lo aplica: cubre un
// uniform sin cargar).
#define LIP_LIGHTNESS_MIN 0.1

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
// vMapUv menos el desplazamiento del brillo por la pose (lips.vert): sin
// aritmtica en el fragment, la lectura no es dependiente y Mali la adelanta.
in highp vec2 vGlossUv;
// Orientacin hacia la cmara [0,1] (lips.vert): 0 en la mitad del labio que
// queda de espaldas al girar la cabeza.
in float vFacing;
out vec4 fragColor;

void main() {
  // Las lecturas van antes de cualquier rama (flujo uniforme).
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  vec4 lipsTexel = texture(uLipsMap, vMapUv);
  float mask = lipsTexel.r;
  float glossMap = texture(uLipsMap, vGlossUv).g;
  float w = clamp(mask * uOpacity * vFacing, 0.0, 1.0);
  // Delineado: un anillo sobre el borde del labial, antialiasado (fwidth antes
  // de cualquier rama, con piso y techo como el delineado de ojos). Sin
  // delineado (uniform en 0) no se calcula.
  float linerAa = clamp(fwidth(lipsTexel.b), 1.0e-3, 0.5);
  float liner = uLinerAmount > 0.0
                    ? (1.0 - smoothstep(uLinerEdge, uLinerEdge + linerAa, lipsTexel.b)) * uLinerAmount * vFacing
                    : 0.0;
  // Franja del borde real: 1 sobre el contorno externo, 0 desde EDGE_BAND.
  // De espaldas o con el fundido en 0 no se puede pintar: no cuenta.
  float edgeBand = uOpacity * vFacing > 0.0 ? uEdgeRefine * (1.0 - smoothstep(0.0, EDGE_BAND, lipsTexel.b)) : 0.0;
  // Fuera del labio, del delineado y de la franja (el borde de la zona
  // dibujada): no cambia el pxel. La rama es coherente por zonas grandes.
  if (w <= 0.0 && liner <= 0.0 && edgeBand <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // highp: entrada de oklabToLinearInGamut (ver color.glsl). La cmara llega
  // en mediump (srgbToLinear/linearToOklab): ~1e-3 de ruido, invisible.
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  // Sombreado del labio real (tambin lo usa el borde real). max: la CPU ya
  // limita uLipLightness a >= 0,1; esto cubre un uniform sin cargar (0).
  highp float shading = clamp(lab.x / max(uLipLightness, LIP_LIGHTNESS_MIN), 0.0, SHADING_MAX);
  // p (0 piel, 1 labio) y luz quemada, para el borde real y la oclusin: una
  // sola vez. Luz quemada: la croma no dice nada (el canal saturado la lava
  // hacia la de la piel; P8, kOcclusionClipValue).
  highp float lipP = 0.0;
  float clipped = 0.0;
  if (edgeBand > 0.0 || uOcclusionGate > 0.0) {
    lipP = dot(lab.yz / max(lab.x, OCCLUSION_MIN_LIGHTNESS) - uOcclusion.xy, uOcclusion.zw);
    clipped = smoothstep(OCCLUSION_CLIP_LOW, OCCLUSION_CLIP_HIGH, max(max(camera.r, camera.g), camera.b));
  }
  if (edgeBand > 0.0) {
    float lipLike = smoothstep(EDGE_LOW, EDGE_HIGH, lipP);
    // Oscuro (croma ruidosa, boca abierta) o quemado (croma lavada, reflejo
    // en el borde): la mscara queda como est.
    float trust = smoothstep(EDGE_MIN_SHADING - EDGE_SHADING_FEATHER, EDGE_MIN_SHADING, shading) * (1.0 - clipped);
    float refined = mix(mask, mix(mask, lipLike, trust), edgeBand);
    w = clamp(refined * uOpacity * vFacing, 0.0, 1.0);
    if (w <= 0.0 && liner <= 0.0) {
      fragColor = vec4(0.0);
      return;
    }
  }
  // Oclusin: con la compuerta prendida (la CPU vio muestras del labio con
  // color de piel), el pxel que se parece a la piel pierde el labial y el
  // delineado; el borde sigue al dedo. Rama por uniform: sin oclusin, nada.
  if (uOcclusionGate > 0.0) {
    float lipLike = smoothstep(OCCLUSION_LOW, OCCLUSION_HIGH, lipP);
    // El pxel quemado nunca pierde el labial.
    float visible = mix(1.0, max(lipLike, clipped), uOcclusionGate);
    w *= visible;
    liner *= visible;
    // La mano entera fuera: el pxel queda como la cmara, exacto (sin esto
    // layerOver con cobertura 0 dejaba el ruido del ida y vuelta de color).
    if (w <= 0.0 && liner <= 0.0) {
      fragColor = vec4(0.0);
      return;
    }
  }
  highp vec3 lit = uTargetLab * shading;
  highp float lightness = clamp(mix(lab.x, lit.x, w * uLumaFollow), 0.0, 1.0);
  highp vec2 ab = mix(lab.yz, lit.yz, w);
  // El delineado encima del labial. Sombreado con tope 1: la mitad exterior
  // del anillo cae sobre piel (ms clara que el labio) y se aclaraba.
  highp vec3 linerLit = uLinerLab * min(shading, 1.0);
  lightness = clamp(mix(lightness, linerLit.x, liner), 0.0, 1.0);
  ab = mix(ab, linerLit.yz, liner);
  vec3 outLinear = oklabToLinearInGamut(vec3(lightness, ab));

  // uSharpness >= 1 y glossMap >= 0: pow est definido.
  float spec = pow(glossMap, uSharpness);
#ifdef SHIMMER
  highp vec2 cell = floor(vMapUv * SPARKLE_CELLS);
  highp float tick = mod(floor(uTime * SPARKLE_RATE), TICK_PERIOD);
  // Desplazamientos distintos en x e y: cada cambio es otro patrn, no el
  // mismo corrido en diagonal.
  float sparkle = step(1.0 - SPARKLE_DENSITY, hash12(cell + vec2(tick * 17.0, tick * 31.0)));
  spec *= uGloss;
  spec += sparkle * uSparkle;
#else
  spec *= uGloss;
#endif
  // El delineado (mate) tapa el brillo del labial que tiene debajo.
  spec *= uLight * w * (1.0 - liner) * smoothstep(GLOSS_SHADING_LOW, GLOSS_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(spec), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - (1.0 - w) * (1.0 - liner));
}
)GLSL";
inline constexpr char k_face_vert[] = R"GLSL(#version 300 es
// Capas de cara (face.frag) y de ojos (eyes.frag): tringulos de la malla
// tracked (mesh::kFaceRegionTriangles / kEyeRegionTriangles), dibujados encima
// del quad de cmara con blending premultiplicado.
//
// Atributos (los mismos VBOs que lips.vert):
//   aPoint         vec2   vrtice tracked en px de imagen (y hacia abajo, SIN espejo).
//   aUv            vec2   UV cannico del vrtice (v hacia arriba).
//   aNormal        vec3   normal unitaria en la malla cannica (mesh_normals.h).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint  .xy + .zw (ver face_mesh.vert).
//   uDisplayMatrix mat4   UV de salida -> UV de cmara (ver camera_quad.vert).
//   uTexMatrix     mat4   SurfaceTexture.getTransformMatrix() del frame.
//   uMapTransform  vec4   UV espejada -> UV del mapa: mapUv = uv'  .xy + .zw
//                         (kFaceMapUvRect o kEyeMapUvRect).
//   uCheekMatrix   mat2   UV espejada -> coordenadas de la gaussiana del rubor
//   uCheekOffset   vec2   (g = M  uv' + o; face_style.cpp). En los ojos, 0.
//   uView          vec3   direccin hacia la cmara en la malla (unitaria).
//   uFacingFade    vec2   coseno normalvista en que la capa empieza (.x) y
//                         termina (.y) de aparecer (engine_config.h).
// Salidas:
//   vTexCoord      vec2   coordenada en la textura de cmara.
//   vMapUv         vec2   coordenada en el mapa de la pasada [0,1].
//   vCheek         vec2   coordenadas de la gaussiana del rubor.
//   vFacing        float  [0,1]: 0 donde la superficie queda de espaldas.
//   vSide          float  0 en la mitad u < 0,5 de la malla, 1 en la otra. flat:
//                         los vrtices de la lnea media tienen u ~0,4999 o
//                         ~0,5001 y, interpolado, un tringulo que los toca
//                         daba valores intermedios (semillas de hash no enteras).
//
// Espejo: los mapas guardan media cara (u <= 0,5). Ningn tringulo cruza la
// lnea media (tools/uv_masks/gen_face_maps.py), as que u' = min(u, 1 - u)
// por vrtice es exacto y las coordenadas siguen siendo afines: interpolar
// es exacto (vFacing es una aproximacin suave, como en lips.vert).

// highp: posiciones en px y coordenadas de textura (ver camera_quad.vert).
precision highp float;

in vec2 aPoint;
in vec2 aUv;
in vec3 aNormal;

uniform vec4 uImageToClip;
uniform mat4 uDisplayMatrix;
uniform mat4 uTexMatrix;
uniform vec4 uMapTransform;
uniform mat2 uCheekMatrix;
uniform vec2 uCheekOffset;
uniform vec3 uView;
uniform vec2 uFacingFade;

out vec2 vTexCoord;
out vec2 vMapUv;
out vec2 vCheek;
out mediump float vFacing;
flat out mediump float vSide;

void main() {
  vec2 clip = aPoint * uImageToClip.xy + uImageToClip.zw;
  gl_Position = vec4(clip, 0.0, 1.0);
  vec2 outputUv = clip * 0.5 + 0.5;
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
  vec2 mirrored = vec2(min(aUv.x, 1.0 - aUv.x), aUv.y);
  vMapUv = mirrored * uMapTransform.xy + uMapTransform.zw;
  vCheek = uCheekMatrix * mirrored + uCheekOffset;
  vFacing = smoothstep(uFacingFade.x, uFacingFade.y, dot(aNormal, uView));
  vSide = step(0.5, aUv.x);
}
)GLSL";
inline constexpr char k_face_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de cara (P5): base, contorno, rubor e iluminador en una sola pasada.
// Especificacin y tests: tools/makeup/face_shading.py (compose); si cambia
// uno, cambia el otro.
//
//   a_i   = mscara_i  intensidad_i  orientacin   (mscaras: mapa de cara;
//           el rubor es piel  gaussiana analtica)
//   s     = L_pxel / L_piel_medida                  (sombreado de la piel real)
//   por capa, en orden (base, contorno, rubor, iluminador):
//           L     = mix(L, (color_i  s).L, a_i  lumaFollow_i)
//           ab    = mix(ab, (color_i  s).ab, a_i)
//           brillo = mix(brillo, brillo_i, a_i)       (solo el iluminador tiene)
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo  iluminado(s), aditivo en lineal
//   salida: layerOver(color, cmara, 1 - (1 - a_i)) (blending premultiplicado)
//
// Lecturas de textura por fragmento: 2 (mapa de cara RGBA8 de ~115 KB y, solo
// donde hay alguna capa, la cmara).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cmara (sRGB), unidad 0.
//   uFaceMap       sampler2D  mapa de cara RGBA8 (mesh/face_maps.h), unidad 2:
//                             .r piel, .g contorno, .b iluminador, .a zona de
//                             efectos mejillas + nariz, [0,1].
//   uSkinLightness float  L OKLab medida de la piel, [0,1] (o 0,55 si no hay);
//                         Renderer la limita a >= 0,1.
//   uLayerLab[4]   vec3   OKLab de cada capa (L en [0,1], a/b en 0,4), en el
//                         orden de mezcla (face_style.h: kFace*).
//   uLayerAmount   vec4   intensidad de cada capa  fundido del tracker, [0,1];
//                         0 = capa apagada.
//   uLayerLumaFollow vec4 cunto sigue la L de cada capa a la de su color,
//                         [0,1] (1 salvo el iluminador).
//   uHighlightShine float brillo aditivo mximo del iluminador, [0, ~0,3]
//                         (lineal).
//   uEffectAmount  vec3   (EFFECTS) pecas (opacidad [0,1]), glitter (brillo de
//                         cada destello [0,1]) y sheen (ganancia relativa de la
//                         luz [0, ~0,4]),
//                          fundido; 0 = apagado.
//   uEffectOnSkin  vec3   (EFFECTS) por efecto: 1 = regin full_face (canal de
//                         piel), 0 = cheeks_nose (canal A).
//   uEffectDensity vec2   (EFFECTS) probabilidad por celda de glitter y pecas, [0,1].
//   uTime          float  (EFFECTS) segundos, mdulo 1000.
//
// Variante EFFECTS (Renderer la usa si la receta tiene efectos de cara):
//   pecas    puntos por celda (hash: presencia, centro, radio), color = la piel
//            del pxel ms oscura y clida (proporcional: vale en todo tono);
//            capa despus de la base.
//   glitter  destellos por celda que cambian con el tiempo, aditivos.
//   sheen    aclarado relativo donde la piel ya est ms iluminada.

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explcito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uFaceMap;
uniform highp float uSkinLightness;
uniform highp vec3 uLayerLab[4];
uniform vec4 uLayerAmount;
uniform vec4 uLayerLumaFollow;
uniform float uHighlightShine;
#ifdef EFFECTS
uniform vec3 uEffectAmount;
uniform vec3 uEffectOnSkin;
uniform vec2 uEffectDensity;
uniform highp float uTime;

// Celdas sobre el mapa de media cara (~1,5 mm las pecas, ~1 mm el glitter).
#define FRECKLE_CELLS vec2(80.0, 140.0)
#define GLITTER_CELLS vec2(120.0, 210.0)
#define GLITTER_RATE 5.0
#define TICK_PERIOD 256.0
// Pecas: L  0,74 y croma  1,2 / 1,35 (ms oscuras y ms clidas que la piel).
#define FRECKLE_SCALE vec3(0.74, 1.2, 1.35)
#endif


// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
in highp vec2 vCheek;
in float vFacing;
flat in float vSide;
out vec4 fragColor;

// Mezcla una capa en OKLab, su brillo y acumula lo que queda sin cubrir.
void mixLayer(inout highp vec3 lab, inout highp float keep, inout float shine, highp vec3 lit, float a,
              float lumaFollow, float layerShine) {
  lab = vec3(clamp(mix(lab.x, lit.x, a * lumaFollow), 0.0, 1.0), mix(lab.yz, lit.yz, a));
  shine = mix(shine, layerShine, a);  // una capa encima tapa el brillo de abajo
  keep *= 1.0 - a;
}

void main() {
  vec4 map = texture(uFaceMap, vMapUv);
  // Rubor analtico: la coordenada ya viene escalada por los sigmas.
  float cheek = exp(-0.5 * dot(vCheek, vCheek));
  vec4 a = clamp(vec4(map.r, map.g, map.r * cheek, map.b) * uLayerAmount * vFacing, 0.0, 1.0);
  vec3 effect = vec3(0.0);  // pecas, glitter, sheen ya por mscara
  float freckle = 0.0;
#ifdef EFFECTS
  effect = mix(vec3(map.a), vec3(map.r), uEffectOnSkin) * uEffectAmount * vFacing;
  // Pecas: un punto por celda (si toca), con centro y radio propios. fwidth
  // antes de cualquier rama.
  highp vec2 fc = vMapUv * FRECKLE_CELLS;
  // Piso: con aa 0 smoothstep tendra bordes iguales (indefinido); techo: de
  // lejos el punto se vuelve un promedio gris en vez de desaparecer.
  highp float faa = clamp(fwidth(fc.x), 1.0e-3, 0.5);
  // Rama por uniform: una receta sin pecas no paga los hash.
  if (uEffectAmount.x > 0.0) {
    highp vec2 fcell = floor(fc) + vec2(vSide * 613.0, 0.0);
    vec2 center = vec2(hash12(fcell + 17.0), hash12(fcell + 41.0)) * 0.6 + 0.2;
    float radius = mix(0.1, 0.26, hash12(fcell + 73.0));
    float present = step(hash12(fcell), uEffectDensity.y);
    freckle = present * (1.0 - smoothstep(radius - faa, radius + faa, length(fract(fc) - center))) * effect.x;
  }
#endif
  // Sin ninguna capa en el pxel (fuera de la piel o receta sin cara): no
  // cambia nada. Coherente por zonas grandes.
  if (a.x + a.y + a.z + a.w + freckle + effect.y + effect.z <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  // La cmara se lee despus de la salida temprana: la textura externa es la
  // lectura cara (el driver convierte YUV) y la pasada cubre toda la cara
  // aunque la receta tenga solo algunas regiones. Sin mipmaps (OES), leerla
  // dentro de la rama no depende de derivadas: el resultado es el mismo.
  vec3 camera = texture(uCamera, vTexCoord).rgb;

  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  // max: la CPU ya la limita a >= 0,1; esto cubre un uniform sin cargar (0).
  highp float shading = clamp(lab.x / max(uSkinLightness, 0.1), 0.0, SHADING_MAX);
  // highp: con fp16, 1 - a para a < ~2e-4 da 1 y el borde de las mscaras
  // quedaba sin cobertura.
  highp float keep = 1.0;
  float shine = 0.0;
  mixLayer(lab, keep, shine, uLayerLab[0] * shading, a.x, uLayerLumaFollow.x, 0.0);
#ifdef EFFECTS
  // Color de las pecas: la piel (ya con la base) ms oscura y ms clida.
  highp vec3 freckleLab = lab * FRECKLE_SCALE;
  mixLayer(lab, keep, shine, freckleLab, freckle, 1.0, 0.0);
#endif
  mixLayer(lab, keep, shine, uLayerLab[1] * shading, a.y, uLayerLumaFollow.y, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[2] * shading, a.z, uLayerLumaFollow.z, 0.0);
  mixLayer(lab, keep, shine, uLayerLab[3] * shading, a.w, uLayerLumaFollow.w, uHighlightShine);
  vec3 outLinear = oklabToLinearInGamut(lab);

#ifdef EFFECTS
  if (uEffectAmount.y > 0.0) {
    highp vec2 gcell = floor(vMapUv * GLITTER_CELLS) + vec2(vSide * 997.0, 0.0);
    highp float tick = mod(floor(uTime * GLITTER_RATE), TICK_PERIOD);
    float sparkle = step(1.0 - uEffectDensity.x, hash12(gcell + vec2(tick * 17.0, tick * 31.0)));
    shine += sparkle * effect.y;
  }
  outLinear *= 1.0 + effect.z * smoothstep(SHEEN_SHADING_LOW, SHEEN_SHADING_HIGH, shading);
#endif
  shine *= smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(shine), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - keep);
}
)GLSL";
inline constexpr char k_eyes_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de ojos (P5-P6): hasta 4 sombras (en el orden de la receta), el
// delineado y las pestaas encima, en una sola pasada. Especificacin y tests:
// tools/makeup/face_shading.py (compose); si cambia uno, cambia el otro.
//
//   sombra_i  a = (mapaA  selectA_i + mapaB.r  selectB_i)  opacidad  orientacin
//   pestaas  a = max(hebras, raz)  opacidad + hebras inferiores  opacidad_inf
//             (hebras procedurales en coordenadas de la lnea, ver lashStrands)
//   delineado a = max(lnea, wing)  opacidad  orientacin, con
//             lnea = 1 - smoothstep(borde, distancia a las pestaas) y
//             wing  = 1 - smoothstep(borde, distancia al wing), solo hasta su largo
//   s         = L_pxel / L_piel_medida
//   por capa:  lab    = mix(lab, color_i  s, a_i)
//              brillo = mix(brillo, brillo_i [+ destellos_i], a_i)
//   + brillo  iluminado(s), aditivo en lineal (el delineado no tiene brillo
//     y tapa el de las sombras que tiene debajo)
//   salida:   layerOver(color, cmara, 1 - (1 - a_i))
//
// Variantes (Renderer las compila con #define):
//   sin SHIMMER  sombras mate / satinadas.
//   SHIMMER      adems destellos por celdas del mapa (hash, sin texturas).
//
// Lecturas de textura por fragmento: 4 (mapas de ojos A, B y C, RGBA8 de
// 120 KB cada uno, y, solo donde hay alguna capa, la cmara).
// Uniforms:
//   uCamera         samplerExternalOES  frame de cmara (sRGB), unidad 0.
//   uEyeMapA        sampler2D  RGBA8 (mesh/eye_maps.h), unidad 3: prpado,
//                              pliegue, V externa, lagrimal, [0,1].
//   uEyeMapB        sampler2D  RGBA8, unidad 4: hueso de la ceja [0,1];
//                              distancia a la lnea de pestaas y al wing
//                              (normalizadas, 1 = lejos); avance del wing [0,1].
//   uSkinLightness  float  L OKLab medida de la piel, [0,1]; >= 0,1 desde la CPU.
//   uShadowLab[4]   vec3   OKLab de cada sombra.
//   uShadowAmount   vec4   opacidad de cada sombra  fundido, [0,1]; 0 = vaco.
//   uShadowSelect[4] vec4  selector one-hot de la regin de cada sombra sobre
//                          el mapa A (0 si la regin es el hueso de la ceja).
//   uShadowBrowBone vec4   1 en los slots cuya regin es el hueso de la ceja.
//   uShadowShine    vec4   brillo aditivo (lineal) por slot, [0, ~0,2].
//   uLinerLab       vec3   OKLab del delineado.
//   uLinerAmount    float  opacidad del delineado  fundido, [0,1].
//   uLinerEdge      vec2   distancia normalizada en que el delineado deja de
//                          ser opaco (.x) y desaparece (.y), [0,1], .x < .y.
//   uEyeMapC        sampler2D  RGBA8, unidad 5: pestaas superiores (posicin
//                              a lo largo de la lnea [0,1], altura [0,1]; 1 =
//                              sin pestaas) e inferiores (dem).
//   uLashLab        vec3   OKLab del color de las pestaas.
//   uLashAmount     float  opacidad de las pestaas superiores  fundido, [0,1]
//                          (0 = sin pestaas: no se calculan las hebras).
//   uLowerLashAmount float opacidad de las inferiores  fundido, [0,1].
//   uLashParams     vec4   hebras por ojo [10, 60], largo [0, 0,95] de la altura
//                          mxima, medio ancho de la hebra en la base [0, 0,32]
//                          de su celda (kLashWidthMax: con el corrimiento de la
//                          base no sale de la celda), inclinacin hacia afuera en la punta
//                          [0, 0,2] (unidades de posicin a lo largo).
//   uLashRoot       float  oscurecimiento de la raz (volumen), [0,1].
//   uWing           float  largo del wing, [0,1] del largo mximo (0 = sin wing).
//                          Con uWing = 0 no hay wing (rama por uniform).
//   uEyeSheen       float  ganancia relativa del efecto sheen sobre prpado y
//                          pliegue  fundido, [0, ~0,4]; 0 = apagado.
//   uGlitter        float  (SHIMMER) brillo de los destellos del efecto glitter
//                          sobre prpado y pliegue  fundido, [0,1].
//   uTime           float  (SHIMMER) segundos, mdulo 1000.
//   uShadowSparkle  vec4   (SHIMMER) intensidad de los destellos por slot, [0,1].

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explcito: el default de sampler2D en ES 3.00 es lowp.
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

// Ancho del final suave del wing (en fraccin de su largo mximo).
#define WING_END_FEATHER 0.05
// Pestaas: altura de la raz oscurecida, rango a lo largo de la lnea en que
// hay hebras (sin pestaas justo en los ngulos) y escala de las inferiores
// (menos hebras, ms finas y menos inclinadas).
#define LASH_ROOT_HEIGHT 0.07
#define LASH_S_START 0.03
#define LASH_S_END 0.96
#define LOWER_LASH_COUNT 0.6
#define LOWER_LASH_WIDTH 0.7
#define LOWER_LASH_CURL 0.4
// Irregularidad de las hebras (en fraccin de celda): cada una se inclina
// hacia un lado propio, ms cerca de la punta, as las vecinas se juntan o se
// separan como mechones. Corrimiento de la base 0,12 + medio ancho mximo
// 0,32 = 0,44 en la raz y ~0,40 hacia la punta: queda margen para el
// antialiasado antes del borde de la celda (0,5), donde se cortara seco.
#define LASH_LEAN 0.25

// Hebras de pestaas en coordenadas de la lnea: s a lo largo (0 ngulo
// externo -> 1 lagrimal), h altura normalizada (1 = sin pestaas). Cada celda
// de s es una hebra con posicin, largo e inclinacin propios (tres hash
// independientes: si compartieran uno, las largas seran siempre las corridas
// para el mismo lado), que se afina hacia la punta y se inclina hacia afuera
// (hacia el lagrimal, un poco hacia adentro).
// x es la coordenada en hebras (calculada afuera) y aa su fwidth: el
// antialiasado necesita derivadas, que solo valen fuera de ramas divergentes.
float lashStrands(highp float x, float s, float h, float lengthMax, float halfWidth, highp float aa,
                  float side) {
  highp float cell = floor(x);
  float jitter = hash12(vec2(cell, side * 31.0 + 7.0));
  float lengthJitter = hash12(vec2(cell, side * 31.0 + 19.0));
  float lean = hash12(vec2(cell, side * 31.0 + 23.0)) - 0.5;
  // Ms cortas hacia el lagrimal.
  float len = lengthMax * (0.45 + 0.55 * lengthJitter) * mix(0.55, 1.0, 1.0 - smoothstep(0.6, 1.0, s));
  float t = h / max(len, 1.0e-3);  // 0 base -> 1 punta
  float w = halfWidth * pow(max(1.0 - t, 0.0), 0.7);
  float offset = (jitter - 0.5) * 0.24 + lean * 2.0 * LASH_LEAN * t * t;
  float f = abs(fract(x) - 0.5 - offset);
  float strand = 1.0 - smoothstep(w - aa, w + aa, f);
  return strand * step(t, 0.98) * smoothstep(LASH_S_START, LASH_S_START + 0.04, s) *
         (1.0 - smoothstep(LASH_S_END - 0.03, LASH_S_END, s));
}

// Coordenada en hebras con la inclinacin (crece con h).
// highp: con fp16 x (hasta ~42) tendra pasos de 0,03 hebras.
highp float lashCoord(highp float s, highp float h, highp float count, highp float curl) {
  return (s + curl * h * h * (1.2 - 1.6 * s)) * count;
}

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
in float vFacing;
// 0/1 segn el lado de la cara (face.vert): los destellos no se espejan.
flat in float vSide;
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

  // Pestaas. Rama uniforme (uLashAmount es un uniform): las derivadas valen.
  float lash = 0.0;
  if (uLashAmount > 0.0) {
    float count = uLashParams.x;
    float curl = uLashParams.w;
    highp float upperX = lashCoord(mapC.r, mapC.g, count, curl);
    highp float lowerX = lashCoord(mapC.b, mapC.a, count * LOWER_LASH_COUNT, curl * LOWER_LASH_CURL);
    // fwidth antes de las ramas de abajo (las derivadas necesitan flujo uniforme).
    // Piso y techo como en face.frag (pecas).
    highp float upperAa = clamp(fwidth(upperX), 1.0e-3, 0.5);
    highp float lowerAa = clamp(fwidth(lowerX), 1.0e-3, 0.5);
    float upper = 0.0;
    float root = 0.0;
    float lower = 0.0;
    // La mayor parte de la zona de ojos (sombras, hueso de la ceja) no tiene
    // pestaas (altura 1): ah no se calculan hebras. Diverge por zonas grandes.
    if (mapC.g < 1.0) {
      upper = lashStrands(upperX, mapC.r, mapC.g, uLashParams.y, uLashParams.z, upperAa, vSide);
      root = (1.0 - smoothstep(0.0, LASH_ROOT_HEIGHT, mapC.g)) * uLashRoot *
             smoothstep(LASH_S_START, LASH_S_START + 0.08, mapC.r) *
             (1.0 - smoothstep(LASH_S_END - 0.1, LASH_S_END, mapC.r));
    }
    if (uLowerLashAmount > 0.0 && mapC.a < 1.0) {
      lower = lashStrands(lowerX, mapC.b, mapC.a, uLashParams.y, uLashParams.z * LOWER_LASH_WIDTH, lowerAa,
                          vSide + 2.0);
    }
    lash = clamp((max(upper, root) * uLashAmount + lower * uLowerLashAmount) * vFacing, 0.0, 1.0);
  }

  vec4 regions = vec4(dot(mapA, uShadowSelect[0]), dot(mapA, uShadowSelect[1]),
                      dot(mapA, uShadowSelect[2]), dot(mapA, uShadowSelect[3])) +
                 mapB.r * uShadowBrowBone;
  vec4 a = clamp(regions * uShadowAmount * vFacing, 0.0, 1.0);
  // Borde del delineado de al menos ~1,5 px de pantalla: con thickness bajo el
  // borde de la receta mide menos de un pxel y titilaba con el tracker.
  // fwidth antes de cualquier rama (necesita derivadas).
  float lineEdge = uLinerEdge.x + max(uLinerEdge.y - uLinerEdge.x, 1.5 * fwidth(mapB.g));
  float wingEdge = uLinerEdge.x + max(uLinerEdge.y - uLinerEdge.x, 1.5 * fwidth(mapB.b));
  float line = 1.0 - smoothstep(uLinerEdge.x, lineEdge, mapB.g);
  // El final del wing se difumina en WING_END_FEATHER, o en la mitad de su
  // largo si es ms corto (as un wing corto arranca opaco).
  // Sin wing, rama por uniform: smoothstep(0, 0, x) no est definido.
  float wingEnd = max(uWing - WING_END_FEATHER, 0.5 * uWing);
  float wingTail = uWing > 0.0 ? 1.0 - smoothstep(wingEnd, uWing, mapB.a) : 0.0;
  float wing = (1.0 - smoothstep(uLinerEdge.x, wingEdge, mapB.b)) * wingTail;
  float liner = clamp(max(line, wing) * uLinerAmount * vFacing, 0.0, 1.0);
  // Zona de los efectos de ojos: prpado + pliegue.
  float effectZone = clamp(mapA.r + mapA.g, 0.0, 1.0) * vFacing;
  float effectShine = effectZone * uEyeSheen;
#ifdef SHIMMER
  effectShine += effectZone * uGlitter;  // se multiplica por el destello ms abajo
#endif
  if (a.x + a.y + a.z + a.w + liner + lash + effectShine <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  // La cmara se lee despus de la salida temprana: la textura externa es la
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
  // highp: con fp16, 1 - a para a < ~2e-4 da 1 y el borde de las mscaras
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

  // Efectos encima de todo: el delineado y las pestaas los tapan.
  float uncovered = (1.0 - liner) * (1.0 - lash);
  shine += glitter * uncovered;
  outLinear *= 1.0 + effectZone * uEyeSheen * uncovered * smoothstep(SHEEN_SHADING_LOW, SHEEN_SHADING_HIGH, shading);
  shine *= smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(shine), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - keep);
}
)GLSL";
inline constexpr char k_iris_vert[] = R"GLSL(#version 300 es
// Capa de iris (iris.frag): tringulos de las aberturas de los ojos
// (mesh::kEyeOpeningTriangles). Dibujar solo ah hace la oclusin por los
// prpados: lo que queda fuera de la abertura no se toca.
//
// Atributos (los mismos VBOs que face.vert):
//   aPoint         vec2   vrtice tracked en px de imagen (y hacia abajo, SIN espejo).
//   aUv            vec2   UV cannico (no se usa; se declara para compartir el VAO).
//   aNormal        vec3   normal unitaria en la malla cannica (mesh_normals.h).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint  .xy + .zw (ver face_mesh.vert).
//   uDisplayMatrix mat4   UV de salida -> UV de cmara (ver camera_quad.vert).
//   uTexMatrix     mat4   matriz de textura de la cmara del frame.
//   uView          vec3   direccin hacia la cmara en la malla (unitaria).
//   uFacingFade    vec2   coseno normalvista en que la capa empieza (.x) y
//                         termina (.y) de aparecer (engine_config.h).
// Salidas:
//   vTexCoord      vec2   coordenada en la textura de cmara.
//   vImagePos      vec2   posicin en px de imagen (para el disco del iris).
//   vFacing        float  [0,1]: 0 donde la superficie queda de espaldas.

// highp: posiciones en px y coordenadas de textura (ver camera_quad.vert).
precision highp float;

in vec2 aPoint;
in vec2 aUv;
in vec3 aNormal;

uniform vec4 uImageToClip;
uniform mat4 uDisplayMatrix;
uniform mat4 uTexMatrix;
uniform vec3 uView;
uniform vec2 uFacingFade;

out vec2 vTexCoord;
out vec2 vImagePos;
out mediump float vFacing;

void main() {
  vec2 clip = aPoint * uImageToClip.xy + uImageToClip.zw;
  gl_Position = vec4(clip, 0.0, 1.0);
  vec2 outputUv = clip * 0.5 + 0.5;
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
  vImagePos = aPoint;
  vFacing = smoothstep(uFacingFade.x, uFacingFade.y, dot(aNormal, uView));
}
)GLSL";
inline constexpr char k_iris_frag[] = R"GLSL(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de iris (fase 4): color de lentes de contacto sobre el iris, dentro de
// la abertura del ojo (iris.vert). Especificacin y tests:
// tools/makeup/iris_shading.py; si cambia uno, cambia el otro.
//
//   r      = min_i |forma_i  (p - centro_i)|      (elipse del iris -> unidad)
//   borde  = max(borde_receta, 1,5 px en r)        (fwidth: iris chicos no titilan)
//   mscara = smoothstep(pupila  borde, r)  (1 - smoothstep(1  borde_ext, r))
//   a      = mscara  opacidad  orientacin  (1 - reflejo(L))  oscuridad(L)
//   s      = min(max(L / L_ref, s_min + pendiente  L / L_ref), s_max)
//            (piso suave: las fibras oscuras siguen ms oscuras)
//   lit    = color  s, con L  (1 - oscurecimiento  smoothstep(inicio_limbal, 1, r))
//   lab    = mix(lab, lit, a); salida: layerOver(color, cmara, a)
//
// Lecturas de textura por fragmento: 1 (la cmara, solo dentro del disco).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cmara (sRGB), unidad 0.
//   uIrisCenter[2] vec2   centro de cada iris (px de imagen, finito).
//   uIrisShape[2]  mat2   inversa de los semiejes de cada elipse (1/px): lleva
//                         el anillo a r = 1. irisEllipses garantiza semiejes
//                         con media geomtrica >= kIrisMinRadiusPx (2 px).
//   uIrisLab       vec3   OKLab del color de la receta: L [0,1], a y b ~[-0,4, 0,4].
//   uIrisAmount    float  opacidad  fundido, [0,1].
//   uIrisMask      vec4   radio de la pupila, borde de la pupila (> 0), borde
//                         exterior (> 0) e inicio del anillo limbal (< 1), en
//                         radios del iris.
//   uIrisTone      vec4   oscurecimiento limbal [0,1], 1 / L de referencia
//                         (~2,4), sombreado mnimo y mximo (adimensional).
//   uIrisFloor     vec2   pendiente del piso de sombreado [0,1] y ancho mnimo
//                         de los bordes en px de pantalla.
//   uIrisDark      vec2   L del pxel desde la que el color empieza (.y) y
//                         termina (.x) de apagarse hacia lo oscuro (pupila), .x < .y.
//   uIrisSpecular  vec2   L del pxel desde la que el reflejo empieza (.x) y
//                         termina (.y) de conservarse, [0,1], .x < .y.

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// highp: centros en px (hasta ~2000) y su producto con la forma.
uniform highp vec2 uIrisCenter[2];
uniform highp mat2 uIrisShape[2];
// highp: entra a oklabToLinearInGamut (ver color.glsl).
uniform highp vec3 uIrisLab;
uniform float uIrisAmount;
uniform vec4 uIrisMask;
uniform vec4 uIrisTone;
uniform vec2 uIrisFloor;
uniform vec2 uIrisDark;
uniform vec2 uIrisSpecular;

// highp: coordenadas de textura y posicin en px (ver iris.vert).
in highp vec2 vTexCoord;
in highp vec2 vImagePos;
in float vFacing;
out vec4 fragColor;

void main() {
  highp float r = min(length(uIrisShape[0] * (vImagePos - uIrisCenter[0])),
                      length(uIrisShape[1] * (vImagePos - uIrisCenter[1])));
  // fwidth antes de cualquier rama (necesita derivadas).
  float aa = uIrisFloor.y * fwidth(r);
  float pupilFeather = max(uIrisMask.y, aa);
  float edgeFeather = max(uIrisMask.z, aa);
  float mask = smoothstep(uIrisMask.x - pupilFeather, uIrisMask.x + pupilFeather, r) *
               (1.0 - smoothstep(1.0 - edgeFeather, 1.0 + edgeFeather, r));
  float coverage = mask * uIrisAmount * vFacing;
  // La mayor parte de la abertura (esclera) queda fuera del disco: sin lectura.
  if (coverage <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  float a = clamp(coverage * (1.0 - smoothstep(uIrisSpecular.x, uIrisSpecular.y, lab.x)) *
                      smoothstep(uIrisDark.x, uIrisDark.y, lab.x),
                  0.0, 1.0);
  highp float raw = lab.x * uIrisTone.y;
  highp float shading = min(max(raw, uIrisTone.z + uIrisFloor.x * raw), uIrisTone.w);
  highp vec3 lit = uIrisLab * shading;
  lit.x *= 1.0 - uIrisTone.x * smoothstep(uIrisMask.w, 1.0, r);
  lab = vec3(clamp(mix(lab.x, lit.x, a), 0.0, 1.0), mix(lab.yz, lit.yz, a));
  fragColor = layerOver(linearToSrgb(oklabToLinearInGamut(lab)), camera, a);
}
)GLSL";
}  // namespace makeup::shaders
