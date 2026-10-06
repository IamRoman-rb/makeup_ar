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
