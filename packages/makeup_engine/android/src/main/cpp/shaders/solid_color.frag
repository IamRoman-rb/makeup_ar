#version 300 es
// Color sólido: puntos del overlay de depuración y máscara de región (la
// cobertura va en .r).
//
// Lecturas de textura por fragmento: 0.
// Uniforms:
//   uColor  vec4  RGBA [0, 1]. En la máscara, r = cobertura con el fundido aplicado.

precision mediump float;

uniform vec4 uColor;

out vec4 fragColor;

void main() {
  fragColor = uColor;
}
