#version 300 es
// Capa de iris (iris.frag): triángulos de las aberturas de los ojos
// (mesh::kEyeOpeningTriangles). Dibujar solo ahí hace la oclusión por los
// párpados: lo que queda fuera de la abertura no se toca.
//
// Atributos (los mismos VBOs que face.vert):
//   aPoint         vec2   vértice tracked en px de imagen (y hacia abajo, SIN espejo).
//   aUv            vec2   UV canónico (no se usa; se declara para compartir el VAO).
//   aNormal        vec3   normal unitaria en la malla canónica (mesh_normals.h).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint · .xy + .zw (ver face_mesh.vert).
//   uDisplayMatrix mat4   UV de salida -> UV de cámara (ver camera_quad.vert).
//   uTexMatrix     mat4   matriz de textura de la cámara del frame.
//   uView          vec3   dirección hacia la cámara en la malla (unitaria).
//   uFacingFade    vec2   coseno normal·vista en que la capa empieza (.x) y
//                         termina (.y) de aparecer (engine_config.h).
// Salidas:
//   vTexCoord      vec2   coordenada en la textura de cámara.
//   vImagePos      vec2   posición en px de imagen (para el disco del iris).
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
