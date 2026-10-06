#version 300 es
// Quad de pantalla completa (triangle strip de 4 vértices) que muestrea el
// frame de cámara.
//
// Atributos:
//   aPosition      vec2  posición en clip space, [-1, 1].
// Uniforms (column-major, transpose = GL_FALSE; adimensionales, espacio UV):
//   uDisplayMatrix mat4  UV de salida [0,1] -> UV de cámara "derecha": rotación
//                        sensor->pantalla (múltiplos de 90°) y espejo de la
//                        cámara frontal. Se sube solo cuando cambia.
//   uTexMatrix     mat4  SurfaceTexture.getTransformMatrix(); se sube por
//                        frame (el productor puede cambiar crop/transformación).

// highp: coordenadas de textura. En mediump (fp16) el paso entre valores
// representables cerca de 1.0 es ~1/2048: a 1280 px da hasta ~0,3 px de error
// y se ve como temblor del borde. (En vertex shaders highp ya es el default de
// GLSL ES 3.00; se deja explícito como documentación.)
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
