#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Capa de iris (fase 4): color de lentes de contacto sobre el iris, dentro de
// la abertura del ojo (iris.vert). Especificación y tests:
// tools/makeup/iris_shading.py; si cambia uno, cambia el otro.
//
//   r      = min_i |forma_i · (p - centro_i)|      (elipse del iris -> unidad)
//   borde  = max(borde_receta, 1,5 px en r)        (fwidth: iris chicos no titilan)
//   máscara = smoothstep(pupila ± borde, r) · (1 - smoothstep(1 ± borde_ext, r))
//   a      = máscara · opacidad · orientación · (1 - reflejo(L)) · oscuridad(L)
//   s      = min(max(L / L_ref, s_min + pendiente · L / L_ref), s_max)
//            (piso suave: las fibras oscuras siguen más oscuras)
//   lit    = color · s, con L · (1 - oscurecimiento · smoothstep(inicio_limbal, 1, r))
//   lab    = mix(lab, lit, a); salida: layerOver(color, cámara, a)
//
// Lecturas de textura por fragmento: 1 (la cámara, solo dentro del disco).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cámara (sRGB), unidad 0.
//   uIrisCenter[2] vec2   centro de cada iris (px de imagen, finito).
//   uIrisShape[2]  mat2   inversa de los semiejes de cada elipse (1/px): lleva
//                         el anillo a r = 1. irisEllipses garantiza semiejes
//                         con media geométrica >= kIrisMinRadiusPx (2 px).
//   uIrisLab       vec3   OKLab del color de la receta: L [0,1], a y b ~[-0,4, 0,4].
//   uIrisAmount    float  opacidad × fundido, [0,1].
//   uIrisMask      vec4   radio de la pupila, borde de la pupila (> 0), borde
//                         exterior (> 0) e inicio del anillo limbal (< 1), en
//                         radios del iris.
//   uIrisTone      vec4   oscurecimiento limbal [0,1], 1 / L de referencia
//                         (~2,4), sombreado mínimo y máximo (adimensional).
//   uIrisFloor     vec2   pendiente del piso de sombreado [0,1] y ancho mínimo
//                         de los bordes en px de pantalla.
//   uIrisDark      vec2   L del píxel desde la que el color empieza (.y) y
//                         termina (.x) de apagarse hacia lo oscuro (pupila), .x < .y.
//   uIrisSpecular  vec2   L del píxel desde la que el reflejo empieza (.x) y
//                         termina (.y) de conservarse, [0,1], .x < .y.

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// highp: centros en px (hasta ~2000) y su producto con la forma.
uniform highp vec2 uIrisCenter[2];
uniform highp mat2 uIrisShape[2];
// highp: entra a oklabToLinearInGamut (ver color.glsl).
uniform highp vec3 uIrisLab;
uniform float uIrisAmount;
uniform vec4 uIrisMask;
uniform vec4 uIrisTone;
uniform vec2 uIrisFloor;
uniform vec2 uIrisDark;
uniform vec2 uIrisSpecular;

// highp: coordenadas de textura y posición en px (ver iris.vert).
in highp vec2 vTexCoord;
in highp vec2 vImagePos;
in float vFacing;
out vec4 fragColor;

void main() {
  highp float r = min(length(uIrisShape[0] * (vImagePos - uIrisCenter[0])),
                      length(uIrisShape[1] * (vImagePos - uIrisCenter[1])));
  // fwidth antes de cualquier rama (necesita derivadas).
  float aa = uIrisFloor.y * fwidth(r);
  float pupilFeather = max(uIrisMask.y, aa);
  float edgeFeather = max(uIrisMask.z, aa);
  float mask = smoothstep(uIrisMask.x - pupilFeather, uIrisMask.x + pupilFeather, r) *
               (1.0 - smoothstep(1.0 - edgeFeather, 1.0 + edgeFeather, r));
  float coverage = mask * uIrisAmount * vFacing;
  // La mayor parte de la abertura (esclera) queda fuera del disco: sin lectura.
  if (coverage <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  // highp: entrada de oklabToLinearInGamut (ver color.glsl).
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  float a = clamp(coverage * (1.0 - smoothstep(uIrisSpecular.x, uIrisSpecular.y, lab.x)) *
                      smoothstep(uIrisDark.x, uIrisDark.y, lab.x),
                  0.0, 1.0);
  highp float raw = lab.x * uIrisTone.y;
  highp float shading = min(max(raw, uIrisTone.z + uIrisFloor.x * raw), uIrisTone.w);
  highp vec3 lit = uIrisLab * shading;
  lit.x *= 1.0 - uIrisTone.x * smoothstep(uIrisMask.w, 1.0, r);
  lab = vec3(clamp(mix(lab.x, lit.x, a), 0.0, 1.0), mix(lab.yz, lit.yz, a));
  fragColor = layerOver(linearToSrgb(oklabToLinearInGamut(lab)), camera, a);
}
