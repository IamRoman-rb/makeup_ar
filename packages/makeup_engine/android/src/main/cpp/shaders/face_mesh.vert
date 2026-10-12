#version 300 es
// Puntos o triángulos de la malla tracked: de px de imagen a clip space de la
// salida (o de la máscara, que cubre la misma área).
//
// Atributos:
//   aPoint         vec2   punto en px de imagen (y hacia abajo, SIN espejo).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint · .xy + .zw. Incluye el espejo de la
//                         cámara frontal: con espejo, (-2/ancho, -2/alto, 1, 1).
//   uPointSize     float  tamaño de punto en px (solo GL_POINTS), [1, 16].

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
