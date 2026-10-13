// Conversión de color en CPU para valores uniformes (se calculan una vez, no
// por píxel). Mismas fórmulas que shaders/color.glsl.
#pragma once

#include <algorithm>
#include <cmath>

namespace makeup {

struct Vec3 {
  float x;
  float y;
  float z;
};

inline float srgbToLinear(float c) { return std::pow(std::max(c, 0.0f), 2.2f); }

inline Vec3 srgbToOklab(float r, float g, float b) {
  const float lr = srgbToLinear(r);
  const float lg = srgbToLinear(g);
  const float lb = srgbToLinear(b);
  const float l = std::cbrt(0.4122214708f * lr + 0.5363325363f * lg + 0.0514459929f * lb);
  const float m = std::cbrt(0.2119034982f * lr + 0.6806995451f * lg + 0.1073969566f * lb);
  const float s = std::cbrt(0.0883024619f * lr + 0.2817188376f * lg + 0.6299787005f * lb);
  return Vec3{
      0.2104542553f * l + 0.7936177850f * m - 0.0040720468f * s,
      1.9779984951f * l - 2.4285922050f * m + 0.4505937099f * s,
      0.0259040371f * l + 0.7827717662f * m - 0.8086757660f * s,
  };
}

inline Vec3 linearToOklab(const Vec3& c) {
  const float l = std::cbrt(0.4122214708f * c.x + 0.5363325363f * c.y + 0.0514459929f * c.z);
  const float m = std::cbrt(0.2119034982f * c.x + 0.6806995451f * c.y + 0.1073969566f * c.z);
  const float s = std::cbrt(0.0883024619f * c.x + 0.2817188376f * c.y + 0.6299787005f * c.z);
  return Vec3{
      0.2104542553f * l + 0.7936177850f * m - 0.0040720468f * s,
      1.9779984951f * l - 2.4285922050f * m + 0.4505937099f * s,
      0.0259040371f * l + 0.7827717662f * m - 0.8086757660f * s,
  };
}

// Inversa de linearToOklab (puede salir de [0, 1]: sin recorte de gamut).
inline Vec3 oklabToLinear(const Vec3& lab) {
  const float l = lab.x + 0.3963377774f * lab.y + 0.2158037573f * lab.z;
  const float m = lab.x - 0.1055613458f * lab.y - 0.0638541728f * lab.z;
  const float s = lab.x - 0.0894841775f * lab.y - 1.2914855480f * lab.z;
  const float l3 = l * l * l;
  const float m3 = m * m * m;
  const float s3 = s * s * s;
  return Vec3{
      4.0767416621f * l3 - 3.3077115913f * m3 + 0.2309699292f * s3,
      -1.2684380046f * l3 + 2.6097574011f * m3 - 0.3413193965f * s3,
      -0.0041960863f * l3 - 0.7034186147f * m3 + 1.7076147010f * s3,
  };
}

}  // namespace makeup
