#version 300 es
// Recorte del tracker: dibuja un ROI (cuadrado rotado de la imagen) en un FBO
// de N×N que después se lee a CPU como tensor de entrada del modelo.
//
// Toda la cadena es afín, así que alcanza con transformar los 4 vértices:
//   recorte [0,1]² --uCropMatrix--> imagen [0,1]² (y hacia abajo, SIN espejo)
//   --(x, 1 - y)--> UV de salida --uDisplayMatrix--> UV de cámara --uTexMatrix--> textura
//
// Atributos:
//   aPosition      vec2  posición en clip space, [-1, 1] (quad del Renderer).
// Uniforms (column-major, transpose = GL_FALSE; adimensionales):
//   uCropMatrix    mat3  recorte -> imagen normalizada (tracking/roi.h, roiCropMatrix).
//   uDisplayMatrix mat4  UV de salida -> UV de cámara, SIN espejo (rotación de pantalla).
//   uTexMatrix     mat4  SurfaceTexture.getTransformMatrix() del frame actual.
//
// La fila 0 del FBO (abajo en GL) es la fila 0 que devuelve glReadPixels; acá
// se la hace corresponder con v = 0 (arriba del recorte), así el buffer leído
// ya está en el orden de filas del tensor.

// highp: coordenadas de textura con precisión subpíxel (ver camera_quad.vert).
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
