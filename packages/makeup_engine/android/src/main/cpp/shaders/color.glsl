// Conversiones de color compartidas: único include (ver .claude/rules/shaders.md).
// Se inyecta en cada shader donde aparece la línea `// @include color.glsl`.
// Matrices OKLab de Björn Ottosson (2020); ida y vuelta verificada en
// tools/studio/sample_region_reference.py.

// sRGB [0,1] -> lineal. Aproximación gamma 2.2 (la misma del informe §5.5).
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

// OKLab -> RGB lineal (puede salir de gamut: recortar después).
// highp: el cubo triplica el error relativo y la matriz de salida (coeficientes
// de hasta 4,08 con cancelación) lo amplifica; en fp16 daría 1-2 LSB de error
// en altas luces, visible como escalones en degradados de piel. Costo: ~20
// operaciones fp32 por píxel.
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

// Pasos de la búsqueda binaria de oklabToLinearInGamut: la croma queda por
// debajo de la máxima que entra, a menos de 1/2^6 de la croma pedida (hasta
// ~5 % de la máxima si se pidió el triple; invisible en un labio). Es la
// perilla de costo: 4 pasos bajan el peor caso de 7 a 5 conversiones.
#define GAMUT_STEPS 6
// Tolerancia de inGamut: el redondeo de las matrices deja blancos, negros y
// canales en 0 apenas fuera del cubo (p. ej. 1,0000001) y sin tolerancia
// disparan la búsqueda completa sin necesidad. Chica a propósito: en colores
// muy oscuros el clamp por canal de 1e-4 ya desvía el tono (lip_shading.py).
#define GAMUT_EPSILON 1e-5

bool inGamut(highp vec3 c) {
  return all(greaterThanEqual(c, vec3(-GAMUT_EPSILON))) &&
         all(lessThanEqual(c, vec3(1.0 + GAMUT_EPSILON)));
}

// OKLab -> RGB lineal dentro del cubo [0,1]. Si el color pedido sale de gamut,
// baja la croma (a, b) conservando exactamente L y el tono, en vez de recortar
// cada canal (que en rojos intensos sobre sombras los vuelve marrones).
// [lab.x] tiene que estar en [0,1]: con croma 0 (gris) siempre entra.
// Costo: 1 conversión si ya está en gamut; si no, GAMUT_STEPS + 1 más. Cuántos
// píxeles salen depende del color: con labiales saturados, los reflejos del
// labio (sombreado > ~1,1 en lips.frag) salen; medir con el preset más
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

// Sombreado relativo de las capas (s = L_píxel / L_referencia): tope para los
// reflejos fuertes y rango en que aparece el brillo (cara, ojos y labios;
// tools/lips/lip_shading.py y tools/makeup/face_shading.py).
#define SHADING_MAX 1.6
#define SHINE_SHADING_LOW 0.85
#define SHINE_SHADING_HIGH 1.1

// Salida de una capa de maquillaje (cara, ojos, labios) con blending
// premultiplicado: glBlendFuncSeparate(ONE, ONE_MINUS_SRC_ALPHA, ZERO, ONE).
//   result    color final de la capa calculado sobre la cámara (sRGB [0,1]).
//   camera    píxel de cámara de este fragmento (sRGB [0,1]).
//   coverage  cobertura total de la capa [0,1] (1 - Π(1 - a_i) si mezcla varias).
// Queda dst' = result - k·camera + k·dst con k = 1 - alpha: sobre la cámara
// sola da exactamente [result]; sobre una capa anterior (p. ej. la base)
// compone encima; con A = 0 no cambia nada. La mezcla en OKLab no es lineal en
// sRGB: un oscurecimiento fuerte (delineado negro) puede dar result <
// (1 - A)·camera, y entonces k baja lo justo para que el rgb no sea negativo
// (en vez de recortarlo, que aclaraba el borde). highp: cocientes chicos.
// Referencia: tools/makeup/face_shading.py (layer_over, blend).
vec4 layerOver(vec3 result, vec3 camera, float coverage) {
  highp vec3 ratio = result / max(camera, vec3(1.0e-3));
  highp float keep = min(1.0 - coverage, min(ratio.r, min(ratio.g, ratio.b)));
  return vec4(result - keep * camera, 1.0 - keep);
}
