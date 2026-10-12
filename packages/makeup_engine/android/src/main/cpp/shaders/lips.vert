#version 300 es
// Capa de labios: triángulos de la malla tracked alrededor de la boca
// (mesh::kLipsRegionTriangles), dibujados encima del quad de cámara.
//
// Atributos:
//   aPoint         vec2   vértice tracked en px de imagen (y hacia abajo, SIN espejo).
//   aUv            vec2   UV canónico del vértice (malla de MediaPipe, v hacia arriba).
//   aNormal        vec3   normal unitaria del vértice en la malla canónica
//                         (mesh_normals.h; z hacia la cámara).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint · .xy + .zw; incluye el espejo de la
//                         pantalla (ver face_mesh.vert).
//   uDisplayMatrix mat4   UV de salida -> UV de cámara (ver camera_quad.vert).
//   uTexMatrix     mat4   SurfaceTexture.getTransformMatrix() del frame.
//   uMapTransform  vec4   UV canónico -> UV del mapa de labios:
//                         mapUv = aUv · .xy + .zw (mesh::kLipsMapUvRect).
//   uView          vec3   dirección hacia la cámara en la malla canónica
//                         (unitaria; de frente (0, 0, 1)), de la pose.
//   uFacingFade    vec2   coseno normal·vista en que el labial empieza (.x) y
//                         termina (.y) de aparecer (engine_config.h).
// Salidas:
//   vTexCoord      vec2   coordenada en la textura de cámara del píxel.
//   vMapUv         vec2   coordenada en el mapa de labios [0,1] (fuera = 0 por
//                         CLAMP_TO_EDGE con borde vacío).
//   vFacing        float  [0,1]: 0 donde la superficie queda de espaldas. De
//                         perfil, la mitad lejana del labio quedaría pintada
//                         encima del borde de la cara (no hay prueba de
//                         profundidad); así se desvanece.
//
// Todas las transformaciones son afines: interpolar por vértice es exacto
// (vFacing no: es una aproximación suave, que es lo que se busca).

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
uniform vec3 uView;
uniform vec2 uFacingFade;

out vec2 vTexCoord;
out vec2 vMapUv;
out mediump float vFacing;

void main() {
  vec2 clip = aPoint * uImageToClip.xy + uImageToClip.zw;
  gl_Position = vec4(clip, 0.0, 1.0);
  // Mismo camino que camera_quad.vert: así el labio muestrea exactamente el
  // píxel de cámara que el quad dibujó debajo.
  vec2 outputUv = clip * 0.5 + 0.5;
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
  vMapUv = aUv * uMapTransform.xy + uMapTransform.zw;
  vFacing = smoothstep(uFacingFade.x, uFacingFade.y, dot(aNormal, uView));
}
