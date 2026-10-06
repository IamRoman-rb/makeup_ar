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

}  // namespace makeup
