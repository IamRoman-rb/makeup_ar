#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Labial fotorrealista (informe §5.5) sobre la malla tracked. Especificación y
// tests: tools/lips/lip_shading.py (shade); si cambia uno, cambia el otro.
//
//   w     = máscara · opacidad · orientación  (cobertura del labial en el píxel)
//   s     = L_píxel / L_labio_medio            (sombreado del labio real)
//   L     = mix(L_píxel, L_color · s, w · lumaFollow)
//   (a,b) = mix((a,b)_píxel, (a,b)_color · s, w)
//           OKLab es homogéneo: escalar la luz lineal por k escala (L, a, b)
//           por k^(1/3). El labial bajo la luz del labio es color · s: las
//           sombras y pliegues quedan oscuros y menos saturados, los reflejos
//           más claros (sin eso el color plano parece una calcomanía).
//   color = OKLab -> lineal bajando croma si sale de gamut (color.glsl)
//   + brillo: (mapa^nitidez · gloss [+ destellos]) · luz · w · iluminado(s),
//           aditivo en lineal; no aparece en las sombras del labio.
//   delineado (lips.liner): anillo sobre el borde (canal .b del mapa), mezclado
//           encima con color · min(s, 1); tapa el brillo (spec · (1 - delineado))
//   oclusión (mano, dedos; tracking/lip_occlusion.h): con la compuerta prendida,
//           w y el delineado se multiplican por mix(1, parecido al labio, compuerta),
//           donde parecido = smoothstep sobre p = dot((a,b)/L − piel, eje).
//   borde real (uEdgeRefine; opción 3 de TRACKER.md §10): en la franja del
//           contorno externo (canal .b < EDGE_BAND) la máscara se mezcla con
//           "parecido al labio" (misma p que la oclusión): el labial se retira
//           de la piel donde la malla se pasó y llega al labio que asoma fuera
//           de ella. Los píxeles oscuros (sombreado < EDGE_MIN_SHADING) y los
//           quemados conservan la máscara: su croma es ruido (la boca abierta)
//           o está lavada (un reflejo en el borde).
//   salida: layerOver(color, cámara, 1 - (1 - w)(1 - delineado)) con blending premultiplicado
//           (color.glsl): el labial va encima de la base sin pisarla
//           alrededor de la boca.
//
// Variantes (Renderer las compila con #define):
//   sin SHIMMER  mate / satinado / brillo (cambian uGloss y uSharpness).
//   SHIMMER      además destellos: celdas del mapa que titilan (hash, sin texturas).
//
// Lecturas de textura por fragmento: 3 (cámara, máscara, brillo desplazado; las
// dos últimas sobre la misma textura RGBA8 de 128 KB, que entra en caché; el
// delineado usa la misma lectura que la máscara).
// Uniforms:
//   uCamera        samplerExternalOES  frame de cámara (sRGB), unidad 0.
//   uLipsMap       sampler2D  mapa de labios RGBA8, unidad 1: .r máscara [0,1],
//                             .g brillo [0,1], .b distancia al borde del
//                             labial (delineado; 1 = lejos) (mesh/lips_maps.h).
//   uTargetLab     vec3   OKLab del color del labial (L en [0,1], a/b en ±0,4);
//                         se calcula una vez en CPU.
//   uOpacity       float  opacidad de la receta × fundido del tracker, [0,1].
//   uLumaFollow    float  cuánto sigue la L del labio a la del color, [0,1]
//                         (1: cubre el tono del labio; 0: solo croma).
//   uLipLightness  float  L OKLab media medida del labio, [0,1] (o 0,55 si no
//                         hay); Renderer la limita a >= 0,1.
//   uGloss         float  intensidad del brillo, [0,1] (0 en mate).
//   uSharpness     float  exponente sobre el mapa de brillo, [1,8]: más alto,
//                         brillo más chico y concentrado.
//   uLight         float  atenuación del brillo por luz de la escena, [0,1].
//   uLinerLab      vec3   OKLab del delineado de labios.
//   uLinerAmount   float  opacidad del delineado × fundido, [0,1]; 0 = sin delineado.
//   uLinerEdge     float  distancia normalizada en que el delineado empieza a
//                         desvanecerse, (0, 1) (engine_config.h: kLipLinerEdge).
//   uOcclusionGate float  compuerta de oclusión [0,1]; 0 = sin oclusión (no se calcula).
//   uOcclusion     vec4   xy = cromaticidad (a,b)/L de la piel; zw = eje
//                         piel->labio / |eje|² (p = 0 piel, 1 labio).
//   uEdgeRefine    float  borde real [0,1]; 0 = máscara del mapa tal cual (no se
//                         calcula). La CPU lo pone en 0 sin eje piel->labio.
//   uTime          float  (SHIMMER) segundos, módulo 1000.
//   uSparkle       float  (SHIMMER) brillo de cada destello, [0,1] (acabado shimmer:
//                         kLipsSparkle · gloss; efecto glitter en labios: su
//                         intensidad). Ya no se multiplica por uGloss.

precision mediump float;

// @include color.glsl

uniform mediump samplerExternalOES uCamera;
// mediump explícito: el default de sampler2D en ES 3.00 es lowp.
uniform mediump sampler2D uLipsMap;
uniform highp vec3 uTargetLab;
uniform float uOpacity;
uniform float uLumaFollow;
uniform highp float uLipLightness;
uniform float uGloss;
uniform float uSharpness;
uniform float uLight;
uniform highp vec3 uLinerLab;
uniform float uLinerAmount;
uniform float uLinerEdge;
uniform float uOcclusionGate;
uniform highp vec4 uOcclusion;
uniform float uEdgeRefine;
#ifdef SHIMMER
uniform highp float uTime;
uniform float uSparkle;

// Celdas por ancho del mapa, probabilidad de que una celda brille y
// cambios por segundo (la intensidad es uSparkle, engine_config.h:
// kLipsSparkle). TICK_PERIOD: el patrón se repite cada 256 cambios (~43 s),
// así el hash recibe números chicos y no pierde resolución en fp32.
#define SPARKLE_CELLS vec2(96.0, 48.0)
#define SPARKLE_DENSITY 0.06
#define SPARKLE_RATE 6.0
#define TICK_PERIOD 256.0

#endif

// Rango de sombreado en el que aparece el brillo del labial (lip_shading.py;
// SHADING_MAX está en color.glsl).
#define GLOSS_SHADING_LOW 0.75
#define GLOSS_SHADING_HIGH 1.05
// Oclusión: p (0 piel, 1 labio) en que el píxel empieza y termina de contar
// como labio. Piso de L para la cromaticidad (en lo muy oscuro amplifica el
// ruido de la cámara).
#define OCCLUSION_LOW 0.3
#define OCCLUSION_HIGH 0.6
#define OCCLUSION_MIN_LIGHTNESS 0.05
// Canal sRGB máximo en que un píxel quemado empieza y termina de ignorar la
// oclusión (centrado en kOcclusionClipValue de la CPU, engine_config.h).
#define OCCLUSION_CLIP_LOW 0.9
#define OCCLUSION_CLIP_HIGH 0.97
// Borde real (tools/lips/lip_shading.py: refined_mask): franja en distancia
// normalizada al contorno externo (0,5 ≈ 0,85 mm), p en que el píxel pasa a
// labio y sombreado bajo el que no se usa la croma.
#define EDGE_BAND 0.5
#define EDGE_LOW 0.35
#define EDGE_HIGH 0.65
#define EDGE_MIN_SHADING 0.55
#define EDGE_SHADING_FEATHER 0.1
// Piso de la L del labio por la que se divide (la CPU ya lo aplica: cubre un
// uniform sin cargar).
#define LIP_LIGHTNESS_MIN 0.1

// highp: coordenadas de textura (ver camera_quad.vert).
in highp vec2 vTexCoord;
in highp vec2 vMapUv;
// vMapUv menos el desplazamiento del brillo por la pose (lips.vert): sin
// aritmética en el fragment, la lectura no es dependiente y Mali la adelanta.
in highp vec2 vGlossUv;
// Orientación hacia la cámara [0,1] (lips.vert): 0 en la mitad del labio que
// queda de espaldas al girar la cabeza.
in float vFacing;
out vec4 fragColor;

void main() {
  // Las lecturas van antes de cualquier rama (flujo uniforme).
  vec3 camera = texture(uCamera, vTexCoord).rgb;
  vec4 lipsTexel = texture(uLipsMap, vMapUv);
  float mask = lipsTexel.r;
  float glossMap = texture(uLipsMap, vGlossUv).g;
  float w = clamp(mask * uOpacity * vFacing, 0.0, 1.0);
  // Delineado: un anillo sobre el borde del labial, antialiasado (fwidth antes
  // de cualquier rama, con piso y techo como el delineado de ojos). Sin
  // delineado (uniform en 0) no se calcula.
  float linerAa = clamp(fwidth(lipsTexel.b), 1.0e-3, 0.5);
  float liner = uLinerAmount > 0.0
                    ? (1.0 - smoothstep(uLinerEdge, uLinerEdge + linerAa, lipsTexel.b)) * uLinerAmount * vFacing
                    : 0.0;
  // Franja del borde real: 1 sobre el contorno externo, 0 desde EDGE_BAND.
  // De espaldas o con el fundido en 0 no se puede pintar: no cuenta.
  float edgeBand = uOpacity * vFacing > 0.0 ? uEdgeRefine * (1.0 - smoothstep(0.0, EDGE_BAND, lipsTexel.b)) : 0.0;
  // Fuera del labio, del delineado y de la franja (el borde de la zona
  // dibujada): no cambia el píxel. La rama es coherente por zonas grandes.
  if (w <= 0.0 && liner <= 0.0 && edgeBand <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // highp: entrada de oklabToLinearInGamut (ver color.glsl). La cámara llega
  // en mediump (srgbToLinear/linearToOklab): ~1e-3 de ruido, invisible.
  highp vec3 lab = linearToOklab(srgbToLinear(camera));
  // Sombreado del labio real (también lo usa el borde real). max: la CPU ya
  // limita uLipLightness a >= 0,1; esto cubre un uniform sin cargar (0).
  highp float shading = clamp(lab.x / max(uLipLightness, LIP_LIGHTNESS_MIN), 0.0, SHADING_MAX);
  // p (0 piel, 1 labio) y luz quemada, para el borde real y la oclusión: una
  // sola vez. Luz quemada: la croma no dice nada (el canal saturado la lava
  // hacia la de la piel; P8, kOcclusionClipValue).
  highp float lipP = 0.0;
  float clipped = 0.0;
  if (edgeBand > 0.0 || uOcclusionGate > 0.0) {
    lipP = dot(lab.yz / max(lab.x, OCCLUSION_MIN_LIGHTNESS) - uOcclusion.xy, uOcclusion.zw);
    clipped = smoothstep(OCCLUSION_CLIP_LOW, OCCLUSION_CLIP_HIGH, max(max(camera.r, camera.g), camera.b));
  }
  if (edgeBand > 0.0) {
    float lipLike = smoothstep(EDGE_LOW, EDGE_HIGH, lipP);
    // Oscuro (croma ruidosa, boca abierta) o quemado (croma lavada, reflejo
    // en el borde): la máscara queda como está.
    float trust = smoothstep(EDGE_MIN_SHADING - EDGE_SHADING_FEATHER, EDGE_MIN_SHADING, shading) * (1.0 - clipped);
    float refined = mix(mask, mix(mask, lipLike, trust), edgeBand);
    w = clamp(refined * uOpacity * vFacing, 0.0, 1.0);
    if (w <= 0.0 && liner <= 0.0) {
      fragColor = vec4(0.0);
      return;
    }
  }
  // Oclusión: con la compuerta prendida (la CPU vio muestras del labio con
  // color de piel), el píxel que se parece a la piel pierde el labial y el
  // delineado; el borde sigue al dedo. Rama por uniform: sin oclusión, nada.
  if (uOcclusionGate > 0.0) {
    float lipLike = smoothstep(OCCLUSION_LOW, OCCLUSION_HIGH, lipP);
    // El píxel quemado nunca pierde el labial.
    float visible = mix(1.0, max(lipLike, clipped), uOcclusionGate);
    w *= visible;
    liner *= visible;
    // La mano entera fuera: el píxel queda como la cámara, exacto (sin esto
    // layerOver con cobertura 0 dejaba el ruido del ida y vuelta de color).
    if (w <= 0.0 && liner <= 0.0) {
      fragColor = vec4(0.0);
      return;
    }
  }
  highp vec3 lit = uTargetLab * shading;
  highp float lightness = clamp(mix(lab.x, lit.x, w * uLumaFollow), 0.0, 1.0);
  highp vec2 ab = mix(lab.yz, lit.yz, w);
  // El delineado encima del labial. Sombreado con tope 1: la mitad exterior
  // del anillo cae sobre piel (más clara que el labio) y se aclaraba.
  highp vec3 linerLit = uLinerLab * min(shading, 1.0);
  lightness = clamp(mix(lightness, linerLit.x, liner), 0.0, 1.0);
  ab = mix(ab, linerLit.yz, liner);
  vec3 outLinear = oklabToLinearInGamut(vec3(lightness, ab));

  // uSharpness >= 1 y glossMap >= 0: pow está definido.
  float spec = pow(glossMap, uSharpness);
#ifdef SHIMMER
  highp vec2 cell = floor(vMapUv * SPARKLE_CELLS);
  highp float tick = mod(floor(uTime * SPARKLE_RATE), TICK_PERIOD);
  // Desplazamientos distintos en x e y: cada cambio es otro patrón, no el
  // mismo corrido en diagonal.
  float sparkle = step(1.0 - SPARKLE_DENSITY, hash12(cell + vec2(tick * 17.0, tick * 31.0)));
  spec *= uGloss;
  spec += sparkle * uSparkle;
#else
  spec *= uGloss;
#endif
  // El delineado (mate) tapa el brillo del labial que tiene debajo.
  spec *= uLight * w * (1.0 - liner) * smoothstep(GLOSS_SHADING_LOW, GLOSS_SHADING_HIGH, shading);
  outLinear = min(outLinear + vec3(spec), vec3(1.0));
  fragColor = layerOver(linearToSrgb(outLinear), camera, 1.0 - (1.0 - w) * (1.0 - liner));
}
