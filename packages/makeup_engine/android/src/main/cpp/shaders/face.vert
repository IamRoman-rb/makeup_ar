#version 300 es
// Capas de cara (face.frag) y de ojos (eyes.frag): triángulos de la malla
// tracked (mesh::kFaceRegionTriangles / kEyeRegionTriangles), dibujados encima
// del quad de cámara con blending premultiplicado.
//
// Atributos (los mismos VBOs que lips.vert):
//   aPoint         vec2   vértice tracked en px de imagen (y hacia abajo, SIN espejo).
//   aUv            vec2   UV canónico del vértice (v hacia arriba).
//   aNormal        vec3   normal unitaria en la malla canónica (mesh_normals.h).
// Uniforms:
//   uImageToClip   vec4   clip = aPoint · .xy + .zw (ver face_mesh.vert).
//   uDisplayMatrix mat4   UV de salida -> UV de cámara (ver camera_quad.vert).
//   uTexMatrix     mat4   SurfaceTexture.getTransformMatrix() del frame.
//   uMapTransform  vec4   UV espejada -> UV del mapa: mapUv = uv' · .xy + .zw
//                         (kFaceMapUvRect o kEyeMapUvRect).
//   uCheekMatrix   mat2   UV espejada -> coordenadas de la gaussiana del rubor
//   uCheekOffset   vec2   (g = M · uv' + o; face_style.cpp). En los ojos, 0.
//   uView          vec3   dirección hacia la cámara en la malla (unitaria).
//   uFacingFade    vec2   coseno normal·vista en que la capa empieza (.x) y
//                         termina (.y) de aparecer (engine_config.h).
// Salidas:
//   vTexCoord      vec2   coordenada en la textura de cámara.
//   vMapUv         vec2   coordenada en el mapa de la pasada [0,1].
//   vCheek         vec2   coordenadas de la gaussiana del rubor.
//   vFacing        float  [0,1]: 0 donde la superficie queda de espaldas.
//   vSide          float  0 en la mitad u < 0,5 de la malla, 1 en la otra
//                         (constante por triángulo: ninguno cruza la línea media).
//
// Espejo: los mapas guardan media cara (u <= 0,5). Ningún triángulo cruza la
// línea media (tools/uv_masks/gen_face_maps.py), así que u' = min(u, 1 - u)
// por vértice es exacto y las coordenadas siguen siendo afines: interpolar
// es exacto (vFacing es una aproximación suave, como en lips.vert).

// highp: posiciones en px y coordenadas de textura (ver camera_quad.vert).
precision highp float;

in vec2 aPoint;
in vec2 aUv;
in vec3 aNormal;

uniform vec4 uImageToClip;
uniform mat4 uDisplayMatrix;
uniform mat4 uTexMatrix;
uniform vec4 uMapTransform;
uniform mat2 uCheekMatrix;
uniform vec2 uCheekOffset;
uniform vec3 uView;
uniform vec2 uFacingFade;

out vec2 vTexCoord;
out vec2 vMapUv;
out vec2 vCheek;
out mediump float vFacing;
out mediump float vSide;

void main() {
  vec2 clip = aPoint * uImageToClip.xy + uImageToClip.zw;
  gl_Position = vec4(clip, 0.0, 1.0);
  vec2 outputUv = clip * 0.5 + 0.5;
  vec4 cameraUv = uDisplayMatrix * vec4(outputUv, 0.0, 1.0);
  vTexCoord = (uTexMatrix * vec4(cameraUv.xy, 0.0, 1.0)).xy;
  vec2 mirrored = vec2(min(aUv.x, 1.0 - aUv.x), aUv.y);
  vMapUv = mirrored * uMapTransform.xy + uMapTransform.zw;
  vCheek = uCheekMatrix * mirrored + uCheekOffset;
  vFacing = smoothstep(uFacingFade.x, uFacingFade.y, dot(aNormal, uView));
  vSide = step(0.5, aUv.x);
}
