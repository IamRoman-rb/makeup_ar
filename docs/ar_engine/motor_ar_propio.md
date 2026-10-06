# Motor AR propio para maquillaje: investigación y arquitectura

**Proyecto:** `makeup_ar` (Flutter) · **Fecha:** 6 oct 2026 · **Objetivo:** dejar de depender de un proveedor externo (Banuba, DeepAR, etc.) para generar y obtener filtros, con un motor propio compatible con el proyecto actual y que corra a 20–30 FPS en un Moto E20.

---

## 0. Resumen ejecutivo

1. **"Desde cero" tiene tres niveles** (renderizado, geometría/tracking, redes neuronales). Los dos primeros se pueden construir 100% propios en semanas. El tercero (entrenar tu propio modelo de landmarks y segmentación) es posible, pero es el tramo caro y legalmente delicado por la licencia de los datasets. Recomiendo hacerlo **por fases, con el modelo de landmarks detrás de una interfaz intercambiable**, para que hoy uses un modelo de licencia abierta y mañana el tuyo sin tocar nada más.
2. **El techo de fotorrealismo no está en `CustomPainter` ni en shaders de Flutter**, sino en la arquitectura: pintar *regiones de maquillaje en espacio UV sobre una malla facial tracked* y componer por píxel en GPU sobre el frame de cámara. Eso exige **vertex + fragment shaders**, que `FragmentProgram` de Flutter no ofrece (solo fragment). Por eso el núcleo de render debe ser **nativo (C++/OpenGL ES 3.0)**, mostrado en Flutter con un `Texture` widget.
3. **El cuello de botella en gama baja no es el shader: es mover frames YUV por Dart.** El pipeline debe quedar entero en nativo/GPU y Dart solo manda *recetas* (JSON chico) y recibe métricas.
4. **Hallazgo sobre el repo:** `main` hoy **no contiene** el pipeline AR (ver §1). Hay que decidir de dónde se parte.
5. **ML Kit Face Mesh es solo Android** (beta). Tu stack describe BGRA/iOS; con ML Kit eso no existe. Un tracker propio/abierto sobre LiteRT resuelve ambas plataformas.
6. **No necesitás saber crear filtros AR.** En este motor un filtro es una *receta JSON* validada, no un programa. Se genera desde un **prompt**, una **imagen de referencia**, una **foto de producto/paleta** o un **remix** de un look existente (§10). Los shaders los escribe Claude Code una sola vez; la IA solo elige parámetros.
7. **Hoy la API key de Groq vive en la app**, lo que la hace extraíble. La generación de filtros debe pasar por una Cloud Function con App Check, auth y cuota por usuario (§10.9).
8. **Claude Code**: la §11 trae la configuración (CLAUDE.md, reglas por ruta, subagentes, hook de protección), el protocolo de medición en el E20 y una serie de prompts por fase. El `CLAUDE.md` listo para copiar está en el doc `claude/CLAUDE.md`.

---

## 1. Estado real del repositorio (`IamRoman-rb/makeup_ar`, rama `main`, commit `e462a34`)

Revisé el repo clonado (shallow). Lo que hay:

- `pubspec.yaml`: `camera ^0.12`, Firebase (core/auth/firestore/storage), `purchases_flutter`, `video_player`, `image_picker`, `permission_handler`, `google_fonts`, `intl`. **No hay** `google_mlkit_face_mesh_detection`, ni TFLite/LiteRT, ni HTTP para Groq.
- `lib/camera_screen.dart` (77 líneas): "Espejo simple: cámara frontal en vivo, sin ningún filtro ni maquillaje encima". Solo `CameraPreview` espejado.
- Búsqueda de `CustomPainter`, `FaceMesh`, `mlkit`, `Groq`, `FragmentProgram`, `NV21`, `startImageStream` en `lib/`: **0 resultados**.
- Lo demás es app "alrededor" del AR: catálogo, looks guardados, tutoriales paso a paso, `filter_editor_screen.dart` (edita looks de Firestore: nombre, imagen, video, categoría Lips/Eyes/Complexion, pasos; **no** edita parámetros de render), VIP/RevenueCat, i18n (es/en/pt/fr), `firestore.rules` (lectura pública de `looks`, escritura solo `is_admin`).
- Una sola rama (`main`); el último merge es el PR #11 `claude/flutter-ar-makeup-migration-plan-…`. El proyecto sincroniza sin `/android/`.

**Implicación:** el motor `CustomPainter` + ML Kit + Groq que describe el proyecto no está en `main` (probablemente se removió en la migración o vive en otra rama/repo local). Antes de empezar hay que confirmar esto, porque define si el motor nuevo *reemplaza* o *se integra* con algo existente. La arquitectura de abajo asume el caso más limpio: un contrato `IMakeupRenderer` y varias implementaciones.

---

## 2. Qué significa "desde cero": tres niveles

| Nivel | Qué es | ¿Propio? | Esfuerzo | Riesgo |
|---|---|---|---|---|
| **A. Motor de render + geometría + formato de filtros** | Pipeline de cámara, malla UV, shaders de maquillaje, estabilización, receta JSON, editor | **100% tuyo** | Medio | Bajo |
| **B. Tracker facial** | Detector + modelo de 468 landmarks | Fase 1: modelo de licencia abierta tras interfaz. Fase 3: modelo entrenado por vos | Alto | Medio-alto |
| **C. Segmentación / oclusión / iris** | Máscara de labios/piel, manos tapando la boca, iris | Heurística propia primero; red propia después | Alto | Medio-alto |

**Decisión recomendada:** construir **A completo** ya, poner **B detrás de `IFaceTracker`** (hoy un modelo abierto auditado, mañana el tuyo), y atacar **C** con heurísticas geométricas antes de entrenar. Así el "proveedor externo" desaparece de la parte que define el producto (cómo se ve y cómo se crean los filtros) sin bloquearte meses en ML.

Si por requisito "desde cero" entendés *también* los pesos de la red, §6 detalla qué implica.

---

## 3. Restricciones duras (verificadas)

**Hardware objetivo (Moto E20, GSMArena):** Unisoc T606 (12 nm), 2×Cortex-A75 + 6×Cortex-A55 a 1.6 GHz, **GPU Mali-G57 MP1**, 2 o 3 GB de RAM, Android 11 (Go edition), cámara frontal de 5 MP. Es un presupuesto muy ajustado: **1 solo cluster de shaders en la GPU**, poca RAM (Go edition mata procesos en segundo plano agresivamente).

**Flutter (docs oficiales de fragment shaders):**
- Solo fragment shaders (`.frag`); **sin vertex shaders**, sin varyings propios, solo `sampler2D`, `texture()` de 2 argumentos, sin UBO/SSBO.
- `ImageFilter.shader` solo en Impeller.
- **Flutter GPU** (`flutter_gpu`) sí expone `RenderPipeline`, `VertexBuffer`, `Texture`, `ShaderLibrary`, etc., pero sus docs lo describen como *early preview*, sin garantía de estabilidad, requiere Impeller y flujos experimentales de build. La versión de la API aparece como `0.0.0`. **No lo usaría como base de un producto hoy**; sí vale un spike para reevaluar cada trimestre.

**ML Kit Face Mesh (pub.dev):** "beta" y **solo Android**; funciona mejor con el rostro a ≤ 2 m y con al menos la mitad de la cara visible. Además es una dependencia cerrada de Google/Play Services: justo el tipo de proveedor que querés evitar.

**MediaPipe Face Mesh (referencia de diseño, paper arXiv 1907.06724 + docs):**
- Dos etapas: detector tipo BlazeFace + modelo de landmarks sobre un recorte.
- 468 vértices; entrada de 256×256 (completo) a 128×128 (el más liviano).
- Entrenado con ~30.000 fotos de móvil *in the wild* más datos sintéticos para la profundidad.
- Latencias publicadas del modelo: Pixel 3 7.4 ms (full), 3.4 ms (light), 2.6 ms (lightest); iPhone XS 2.5/1/0.7 ms. **No hay dato público para Mali-G57 MP1: hay que medirlo.**
- Suavizado temporal: filtro 1D por coordenada basado en **One Euro** (más suavizado en reposo, más reactividad en movimiento).
- El detector se salta en la mayoría de los frames: el recorte se genera desde los landmarks del frame anterior y solo se reinvoca el detector si el modelo pierde la cara.
- `refine_landmarks` (attention mesh) mejora labios, ojos e iris a costa de cómputo.
- Módulo *Face Geometry*: modelo canónico en unidades métricas y alineación por **Procrustes**.

**LiteRT (ex TFLite) GPU delegate:** soporta modelos cuantizados por defecto, hay que crear el delegate en el mismo hilo que lo ejecuta y comprobar compatibilidad en runtime con `CompatibilityList` con fallback a CPU. La documentación consultada **no dice nada específico sobre Mali de gama baja**: el comportamiento en el E20 (GPU vs. CPU con XNNPACK) se decide midiendo.

---

## 4. Arquitectura propuesta

```
┌────────────────────────── Flutter (Dart) ───────────────────────────┐
│ UI · catálogo · editor · Groq → RecipeValidator → MakeupRecipe(JSON) │
│        IMakeupRenderer  ◄── feature flag (--dart-define)            │
│   ├─ NativeGpuMakeupRenderer  (nuevo, este documento)               │
│   └─ CustomPainterMakeupRenderer (fallback / iOS hasta tener Metal) │
└───────────────┬───────────────────────────────▲─────────────────────┘
   setRecipe(json) · start/stop (FFI/MethodChannel)   │ Texture(textureId) + stats
┌───────────────▼───────────────────────────────┴─────────────────────┐
│                  Núcleo nativo C++ (NDK, GLES 3.0)                   │
│                                                                      │
│  Cámara (Camera2/CameraX) ─► SurfaceTexture / OES                    │
│        │                                                             │
│        ├─► [GPU] downscale + YUV→RGB ─► tensor 128–192 px            │
│        │          └► IFaceTracker (hilo propio, 15–20 Hz)            │
│        │                ├ FaceDetector (cada N frames o al perder)   │
│        │                └ LandmarkNet  (ROI del frame previo)        │
│        │                         │ 468×3                             │
│        │      PoseSolver (Procrustes→R,t,s) + OneEuro + extrapolación│
│        │                         │ malla suavizada @ tasa de render  │
│        └────────────► Compositor GLES (30 fps)                       │
│                 malla canónica + UV  →  máscaras UV por región       │
│                 fragment: muestrea cámara, mezcla en OKLab,          │
│                 especular/gloss, foundation (Kubelka-Munk aprox.)    │
│                         │                                            │
│                 SurfaceTexture de salida ──► Flutter Texture         │
└──────────────────────────────────────────────────────────────────────┘
```

Principios:

1. **Render y ML desacoplados.** El render va a 30 fps con la última malla conocida + extrapolación por velocidad; la inferencia corre a 15–20 Hz en otro hilo. En un E20 esto es la diferencia entre "fluido" y "se calienta". Los números son objetivos de diseño, **no mediciones**.
2. **Cero cruces por Dart por frame.** Dart solo manda la receta y lee métricas (FPS, latencia p95, estado de tracking).
3. **Todo detrás de interfaces:** `IFaceTracker`, `IMakeupRenderer`, `IRecipeSource`. Cambiar el modelo de landmarks o el backend gráfico no toca UI ni IA.
4. **La IA (Groq) nunca genera código ni shaders**, solo parámetros validados contra un esquema (ver §5.8).

---

## 5. Módulos en detalle

### 5.1 Ingesta de cámara (el cambio que más FPS regala)

- El paquete `camera` con `startImageStream` copia planos YUV a Dart y obliga a convertir NV21→RGB en CPU; en gama baja eso por sí solo consume el presupuesto. Lo reemplaza un **plugin nativo propio** (`makeup_engine`) que abre la cámara con Camera2/CameraX y consume `SurfaceTexture` (textura externa OES) directamente en GLES.
- Resolución de trabajo: **640×480 o menor** para tracking (el detector/landmarks usan 128–192 px de todos modos) y la resolución de preview para el compositor. Para el sensor de 5 MP del E20, pedir un stream de preview moderado, no el máximo.
- Flutter muestra el resultado con `Texture(textureId: …)` (SurfaceProducer API en Android). Dart nunca ve píxeles.
- iOS: mismo contrato con `AVCaptureSession` + Metal; los shaders GLSL ES se portan a MSL (p. ej. con SPIRV-Cross). Puede quedar para la fase 4 con el renderer `CustomPainter` como respaldo.

### 5.2 Tracker facial (`IFaceTracker`)

Contrato mínimo:

```dart
abstract interface class IFaceTracker {
  /// Landmarks normalizados [0..1] en espacio de imagen: 468×(x,y,z).
  /// null si no hay cara. No lanza.
  FaceMesh? get latest;
  Future<void> start(TrackerConfig config);
  Future<void> stop();
}
```

(El contrato real vive en C++; esta versión Dart es la fachada para tests y para el renderer de respaldo.)

Estrategia de dos etapas (la misma que MediaPipe documenta): detector liviano cuando no hay cara y modelo de landmarks sobre un ROI derivado del frame anterior. Esto reduce muchísimo el costo medio por frame.

### 5.3 Geometría y estabilización

1. **Pose rígida con Procrustes/Umeyama:** alinear un subconjunto estable de landmarks (frente, nariz, sienes; evitar boca y ojos) contra el modelo canónico → rotación, traslación y escala. Da yaw/pitch/roll robustos y una **escala métrica** para dimensionar efectos.
2. **One Euro por coordenada** sobre los landmarks (o mejor, sobre los parámetros de pose + residuo no rígido). Parámetros iniciales a ajustar en dispositivo: `minCutoff≈1.0`, `beta≈0.007–0.05`, `dCutoff=1.0`. Lo validé numéricamente: con ruido gaussiano σ=1 px a 20 Hz, la desviación en reposo bajó de 1.08 a 0.49 px y el retraso en una rampa a 30 px/s fue de ~2 px (β=0.05). Implementación de referencia:

```dart
import 'dart:math' as math;

/// Filtro One Euro (Casiez et al., 2012) para una señal escalar.
final class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.007, this.dCutoff = 1.0});

  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _prevRaw;
  double? _xHat;
  double? _dxHat;

  static double _alpha(double dt, double cutoff) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  /// [dt] en segundos (> 0). Devuelve el valor filtrado.
  double filter(double x, double dt) {
    if (dt <= 0) return _xHat ?? x;
    final dx = _prevRaw == null ? 0.0 : (x - _prevRaw!) / dt;
    _prevRaw = x;

    final aD = _alpha(dt, dCutoff);
    _dxHat = _dxHat == null ? dx : aD * dx + (1 - aD) * _dxHat!;

    final cutoff = minCutoff + beta * _dxHat!.abs();
    final a = _alpha(dt, cutoff);
    _xHat = _xHat == null ? x : a * x + (1 - a) * _xHat!;
    return _xHat!;
  }

  void reset() {
    _prevRaw = null;
    _xHat = null;
    _dxHat = null;
  }
}
```

   *(Esta es la fachada Dart para el renderer de respaldo y las pruebas; en el núcleo nativo se porta 1:1 a C++ con arrays preasignados, sin allocations por frame. No la compilé: la lógica equivalente sí está validada en Python.)*

3. **Extrapolación entre inferencias:** `p(t) = p_k + v_k·(t − t_k)` con `v_k` de los últimos dos resultados y *clamp* de la extrapolación (≤ ~1.5 intervalos) para evitar overshoot cuando el usuario frena.
4. **Estado de confianza:** si el modelo pierde la cara, fundir el maquillaje a opacidad 0 en ~150 ms en lugar de cortarlo (evita parpadeo).

### 5.4 Maquillaje en espacio UV (el cambio de paradigma respecto de Bézier)

En vez de dibujar curvas por frame, se **autoran una sola vez** máscaras y mapas en el espacio UV del modelo canónico (468 vértices, ~900 triángulos):

| Mapa UV (textura chica, 256² o 512², 8 bits) | Uso |
|---|---|
| `lips_mask` (borde ya difuminado en autoría) | labial |
| `lip_gloss_map` (highlights en el labio inferior/centro) | brillo |
| `lid_mask`, `crease_mask`, `outer_v_mask` | sombras |
| `liner_upper`, `liner_lower` | delineado |
| `cheek_mask` (gaussiana grande) | rubor |
| `contour_mask`, `highlight_mask` | contorno e iluminador |
| `skin_mask` (excluye ojos/boca/cejas) | base/foundation |

Ventajas: el difuminado de bordes cuesta **cero en runtime** (ya está en la textura), el costo por frame es "dibujar ~900 triángulos con 1–3 texturas", y el mapeo sigue la deformación real de la cara (no hay "maquillaje flotante": no hay `_scale`/`_offsetX` que calibrar, la malla se proyecta con la misma matriz que el frame). Las máscaras se pueden generar con herramientas propias (pintar sobre el UV) y versionar.

Pasada de render, en orden: frame de cámara → (opcional) suavizado de piel → capas por región (base, contorno, rubor, sombras, delineado, labios) → composición final.

### 5.5 Shading fotorrealista

Principios, en orden de impacto visual:

1. **Mezclar en un espacio perceptual (OKLab), conservando la luminancia de la piel/labio.** Reemplazar solo la croma (a, b) y mezclar L parcialmente conserva textura, poros y sombras; el `BlendMode.multiply` sobre RGB oscurece y ensucia el color.
2. **Acabado como parámetros, no como código:** `matte` (sin especular), `satin`, `gloss` (especular alto y estrecho), `shimmer` (ruido de partículas con tiempo/ángulo).
3. **Especular guiado por la malla:** mapa de brillo en UV modulado por el ángulo cabeza–luz (la pose del §5.3 da la orientación) para que el brillo "se mueva" al girar.
4. **Base/foundation:** el paper *Scalable and Realistic Virtual Try-on for Foundation Makeup with Kubelka-Munk Theory* (arXiv 2507.07333) usa `R = R_m + (T_m² · R_s) / (1 − R_m · R_s)` entre reflectancia del producto y de la piel, descomposición intrínseca (albedo/sombreado/brillos) y una aproximación por Taylor que baja el costo de 0.925 s a 0.17 s. Es de **sombreado por pasada completa**, no de 30 fps en gama baja tal cual: se adapta como aproximación en el shader (mezcla en XYZ/OKLab con un término de cobertura) y se mide.
5. **Adaptación a la luz:** estimar luminancia media y balance de una zona de piel estable (mejillas/frente) y usarla para normalizar brillo del especular y saturación del color. Sin esto el labial se ve "pegado" en luz cálida/fría.

**Shader de labios (GLSL ES 3.00, esqueleto completo).** Es el patrón base de todas las regiones; las demás cambian el mapa y los términos. *No lo compilé en este entorno (no hay validador GLSL disponible); las matrices OKLab sí las verifiqué con ida y vuelta numérica, error máximo ≈ 2.5e-7.*

```glsl
#version 300 es
precision mediump float;

uniform sampler2D uCamera;     // frame de cámara (RGB sRGB)
uniform sampler2D uMask;       // máscara UV de labios (R, ya difuminada)
uniform sampler2D uGloss;      // mapa UV de brillo (R)

uniform vec3  uColor;          // color objetivo, sRGB 0..1
uniform float uOpacity;        // 0..1
uniform float uLumaFollow;     // 0..1: cuánto sigue la luminosidad del color objetivo
uniform float uGloss;          // 0..1 intensidad de brillo (0 = mate)
uniform float uLightAtten;     // 0..1 factor de luz estimada por pose/entorno

in vec2 vUV;      // UV canónico del vértice
in vec2 vScreen;  // coordenada de pantalla 0..1 para muestrear la cámara
out vec4 fragColor;

vec3 toLinear(vec3 c)   { return pow(c, vec3(2.2)); }
vec3 toSRGB(vec3 c)     { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

vec3 toOklab(vec3 c) {
  float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
  float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
  float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
  float l_ = pow(max(l, 0.0), 1.0 / 3.0);
  float m_ = pow(max(m, 0.0), 1.0 / 3.0);
  float s_ = pow(max(s, 0.0), 1.0 / 3.0);
  return vec3(
    0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_);
}

vec3 fromOklab(vec3 c) {
  float l_ = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
  float m_ = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
  float s_ = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
  float l = l_ * l_ * l_;
  float m = m_ * m_ * m_;
  float s = s_ * s_ * s_;
  return vec3(
     4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}

void main() {
  vec3 skinLin = toLinear(texture(uCamera, vScreen).rgb);
  float mask = texture(uMask, vUV).r;
  float w = clamp(mask * uOpacity, 0.0, 1.0);

  vec3 lab    = toOklab(skinLin);
  vec3 target = toOklab(toLinear(uColor));

  // Croma: reemplazo ponderado. Luminancia: se conserva la textura del labio
  // y se acerca (opcionalmente) a la del color objetivo.
  float L = mix(lab.x, lab.x + (target.x - 0.55), w * uLumaFollow);
  vec2  ab = mix(lab.yz, target.yz, w);
  vec3 outLin = fromOklab(vec3(clamp(L, 0.0, 1.0), ab));

  // Especular aproximado: mapa UV de brillo * intensidad * luz estimada.
  float spec = texture(uGloss, vUV).r * uGloss * uLightAtten * w;
  outLin += vec3(spec);

  fragColor = vec4(toSRGB(clamp(outLin, 0.0, 1.0)), 1.0);
}
```

(`0.55` es un L de referencia de un labio medio; debe calibrarse y exponerse como uniform una vez medido con tonos de piel reales.)

### 5.6 Oclusión y segmentación (fase 2)

Orden por costo/beneficio:
1. **Sin red:** usar los landmarks para que la máscara siga la boca abierta (el UV ya deforma) y recortar por **distancia de color a la piel** dentro del polígono de labios para detectar dientes/lengua.
2. **Red chica de labios** (U-Net/MobileNet ~64×64 sobre el ROI de la boca, int8) para oclusión por manos/objetos.
3. Máscara de piel y de pelo solo si el producto lo pide (colorear pelo está fuera del alcance inicial).

### 5.7 Ojos e iris

El modelo de landmarks "normal" no da iris; la variante con refinamiento sí, a más costo. Camino propio: red mínima sobre el recorte del ojo (≈ 64×64) que regresa centro y radio del iris, y shader de color de iris con máscara circular + oclusión por párpados desde los landmarks. Va después de que labios/rubor/sombras estén sólidos.

### 5.8 Recetas y puente con la IA (Groq)

Formato versionado, validado y *clampeado* en el dispositivo; la IA no puede salirse de rango:

```json
{
  "schema": "makeup-recipe/2",
  "name": "Rojo clásico",
  "lips": {
    "color": "#B3122D",
    "opacity": 0.85,
    "finish": "gloss",
    "gloss": 0.6,
    "lumaFollow": 0.35
  },
  "cheeks": { "color": "#E8837A", "opacity": 0.28, "spread": 0.7 },
  "eyes": {
    "shadow": [
      { "color": "#5B3A29", "opacity": 0.4, "region": "lid" },
      { "color": "#2B1B17", "opacity": 0.5, "region": "outer_v" }
    ],
    "liner": { "color": "#111111", "opacity": 0.9, "thickness": 0.5, "wing": 0.3 }
  },
  "skin": { "foundation": { "color": "#D9A98B", "coverage": 0.35 } }
}
```

El esquema JSON completo (draft 2020-12) está en `docs/ar_engine/recipe_v2.schema.json`; lo validé con `jsonschema` contra una receta correcta y contra 7 recetas inválidas (opacidad > 1, HEX malformado, enum inválido, propiedad extra tipo `shader`, más de 4 sombras, versión errónea, nombre vacío): las 7 se rechazan. Todo el flujo de generación está en §10.

Reglas: enums cerrados para `finish` y `region`; HEX validado con regex; números *clamp* a rango en `RecipeValidator`; si la respuesta no valida, se descarta y se usa el preset local. Groq con `response_format: json_object` sigue siendo apropiado para esto; **el contrato real lo da el validador, no el modelo**. Firestore guarda recetas; el `FilterEditorScreen` actual (que hoy edita metadatos del catálogo) se extiende con sliders sobre estos campos y vista previa en vivo en el mismo `Texture`.

### 5.9 Presupuesto de frame (objetivo de diseño en el E20, a medir)

Meta 30 fps = 33 ms/frame; reservo ~12 ms de margen térmico.

| Etapa | Objetivo | Nota |
|---|---|---|
| Captura + YUV→RGB + downscale (GPU) | ≤ 3 ms | sin copia a CPU |
| Inferencia landmarks (hilo aparte, 15–20 Hz) | ≤ 25 ms *fuera* del camino crítico | no bloquea el render |
| Pose + filtro + extrapolación | ≤ 1 ms | arrays preasignados |
| Compositor (malla + máscaras + shader) | ≤ 8 ms | 1–3 capas por defecto |
| Margen | ~12 ms | térmico y variabilidad |

Si el compositor no entra, palancas en orden: bajar resolución del frame de composición, fusionar regiones en una sola pasada, reducir capas simultáneas, bajar a 24 fps adaptativo.

---

## 6. Entrenar modelos propios: lo que implica de verdad

### 6.1 Datos y licencias (el verdadero cuello de botella)

- **FaceSynthetics (Microsoft):** 100.000 imágenes de 512×512, 70 landmarks (esquema iBUG 68 + pupilas) y segmentación de 19 clases; **licencia solo para investigación no comercial** (verificado en el repo). **No sirve para un producto comercial.**
- Los datasets académicos clásicos de caras (300W/300W-LP, WFLW, CelebA/CelebAMask-HQ, FFHQ, LaPa) suelen traer licencias de investigación/no comercial o términos restrictivos. **No verifiqué cada una en esta sesión**; esa lista es conocimiento previo y hay que leer la licencia de cada dataset antes de entrenar nada que vaya a producción. Mismo cuidado con los modelos 3D morfables (BFM, FLAME).
- **Camino limpio:** datos propios con **consentimiento explícito y documentado** (releases firmados), más datos sintéticos generados por vos (render propio de caras con tu propio asset pipeline). Para un modelo de 468 puntos necesitás etiquetas densas: la forma práctica es **destilación** (un modelo "maestro" etiqueta tus propias imágenes y entrenás el "alumno" liviano), siempre que la licencia del maestro lo permita (hay que leer la tarjeta del modelo).
- Los datos faciales son datos personales sensibles. Si más adelante los datos salen de usuarios de la app, necesitás consentimiento informado, minimización y política de retención. No soy abogado: conviene consultar la normativa local (Argentina: Ley 25.326) antes de recolectar.

### 6.2 Modelo y entrenamiento (si seguís por acá)

- Backbone liviano (MobileNetV3-Small o una red tipo BlazeFace/BlazePose) con cabezal de regresión de 468×3; entrada 128–192 px; pérdida tipo Wing/L1 sobre landmarks normalizados + término de consistencia de forma.
- **Cuantización int8 con QAT** (post-training suele degradar los landmarks finos en labios/ojos); exportación a LiteRT o a otro runtime móvil.
- Métricas que sí importan al producto: **NME** por región, **jitter** (σ en px sobre videos estáticos) y **latencia p95 en el E20**, no solo en el equipo de entrenamiento.
- Esfuerzo orden de magnitud para una persona a tiempo parcial (estimación mía, no validada): **meses**, dominados por datos y evaluación, no por la red.

### 6.3 Runtime de inferencia

No conviene escribir tu propio runtime de redes: LiteRT (GPU delegate con fallback CPU/XNNPACK) o un runtime móvil abierto equivalente. "Propio" acá debe ser el **modelo y el pipeline**, no el motor de tensores.

---

## 7. Hoja de ruta con criterios de salida

| Fase | Contenido | Criterio de salida (medible en el E20) |
|---|---|---|
| **0. Spike (1–2 sem)** | Benchmark de un modelo de landmarks abierto en el E20 (GPU delegate vs CPU); `Texture` widget con cámara nativa; un quad con un shader de color | Mediciones reales de latencia p50/p95 y térmica a 5 min; decisión go/no-go sobre GLES nativo |
| **1. Núcleo A (6–8 sem)** | Plugin cámara→GLES→`Texture`, `IFaceTracker`, Procrustes + One Euro + extrapolación, malla UV, labios + rubor + sombras, receta v2 + validador | 30 fps (o 24 adaptativo) sostenidos 10 min, jitter estático < 0.5 px, sin crecimiento de memoria |
| **2. Calidad (4–6 sem)** | Delineado, foundation (KM aprox.), adaptación a luz, oclusión heurística, editor con vista previa | Comparación A/B ciega con grabaciones en 5+ tonos de piel y 3 condiciones de luz |
| **3. Modelo propio (3–6 meses)** | Recolección consentida/sintética, destilación, QAT, evaluación | NME ≤ modelo abierto en tu set de validación, misma latencia p95 |
| **4. iOS + extras** | Metal, iris, segmentación de labios | Paridad visual con Android |

**Pista paralela "Filter Studio" (§10)** — no depende del motor nativo salvo donde se indica:

| Paso | Contenido | Depende de | Criterio de salida |
|---|---|---|---|
| **F1** | Receta v2 + `RecipeValidator` (Dart) + presets locales + tests | nada | Las 8 pruebas del §10.11 pasan en Dart igual que en Python |
| **F2** | Cloud Function `generateRecipe` (Secret Manager, App Check, auth, cuota) y migración de la key fuera de la app | F1 | La app ya no contiene ninguna key de LLM; prompt → 3 variantes válidas |
| **F3** | Pantalla Studio (admin): variantes en vivo, sliders, borrador/publicado | F1, F2 y el compositor (Fase 1 del motor) | Un look generado por prompt se publica sin editar JSON a mano |
| **F4** | Imagen → receta (rectificación UV + muestreo + visión) y foto de producto → paleta | tracker en modo imagen + máscaras UV (Fase 1) | Error de color de la receta sobre 20 fotos de referencia dentro del umbral que definas en el §10.5 |
| **F5** | QA automático con caras de prueba y efectos procedurales (pecas, glitter) | Fase 2 del motor | Ningún look publicado falla los chequeos del §10.10 |

*(Los plazos son estimaciones de orden de magnitud, no compromisos.)*

---

## 8. Riesgos y qué verificar primero

1. **GLES en Android 11 Go + Mali-G57 MP1:** GLES 3.0 es la apuesta conservadora (Vulkan en gamas bajas viejas es menos predecible). Verificar en el dispositivo real.
2. **GPU delegate de LiteRT en Mali de gama baja:** la doc no lo garantiza; medir contra CPU con XNNPACK.
3. **Memoria (2 GB, Go):** texturas UV en 8 bits y ≤ 512², pooling de buffers, sin allocations por frame en el hilo de render.
4. **Térmica:** limitar inferencia a 15 Hz si la temperatura sube; degradar capas antes que FPS.
5. **Licencias** de modelos y datasets (§6.1): leer cada una antes de cualquier uso comercial.
6. **Estabilidad de Flutter GPU:** reevaluar cada trimestre; si madura, podría reemplazar parte del puente nativo.
7. **Estado del repo (§1):** confirmar dónde vive el código AR actual y si hay que migrarlo o descartarlo.

---

## 9. Integración con el proyecto actual

Estructura sugerida (feature-first, sin romper lo existente):

```
lib/
  features/ar/
    domain/        makeup_recipe.dart · i_makeup_renderer.dart · recipe_validator.dart
    data/          native_gpu_renderer.dart · custom_painter_renderer.dart (fallback)
                   recipe_repository.dart (Firestore) · groq_recipe_service.dart
    presentation/  ar_camera_screen.dart (usa Texture) · filter_editor/ (extiende el actual)
packages/
  makeup_engine/   plugin Flutter: android/ (Kotlin + C++/GLES), ios/ (futuro), lib/ (FFI)
functions/         Cloud Functions (generateRecipe, validación server-side, cuotas)
tools/uv_masks/    herramientas para autorar/versionar máscaras UV y golden images
docs/ar_engine/    este informe, AUDIT.md, SPIKE_RESULTS.md, recipe_v2.schema.json
.claude/           rules/, agents/, hooks/, settings.json (ver §11)
CLAUDE.md          instrucciones de proyecto para Claude Code (< 200 líneas)
```

- Feature flag con `--dart-define=AR_RENDERER=native|painter` (mismo mecanismo que ya usás para alternar renderers).
- `camera_screen.dart` pasa de `CameraPreview` a `Texture` cuando el motor nativo esté listo; hasta entonces sigue como espejo.
- `firestore.rules` no cambia: las recetas viven en `looks`, con escritura solo para admin.
- El `CameraPreview`/`camera` actual se mantiene para pantallas que no usen AR.

---

## 10. Cómo generar filtros sin saber hacer filtros AR ("Filter Studio")

### 10.1 La idea que lo simplifica todo

En este motor **un filtro no es un programa AR: es una receta JSON** (`makeup-recipe/2`) más, opcionalmente, efectos procedurales de una lista cerrada (pecas, glitter, brillo). El motor ya sabe pintar cualquier receta válida. Por eso:

- **Vos nunca escribís shaders ni modelás en 3D.** Los shaders los escribe Claude Code una vez (Fase 1 del motor) y quedan fijos.
- **La IA solo elige parámetros**, nunca código. Una receta no puede ejecutar nada: el esquema rechaza cualquier propiedad que no esté definida (verificado, ver §10.11).
- Crear un filtro nuevo = producir un JSON válido, y eso se puede hacer desde un **prompt**, una **imagen**, una **foto de producto** o editando uno existente.

### 10.2 Las cuatro formas de crear un filtro

| Entrada | Qué hace | Quién calcula qué |
|---|---|---|
| **Prompt** ("labios góticos y rubor naranja") | Genera 3 variantes: fiel, más intensa, más sutil | LLM de texto en Cloud Function → validador |
| **Imagen de referencia** (foto de un look) | Extrae color, intensidad y acabado por región | **Píxeles** → números exactos; **LLM de visión** → semántica (acabado, estilo de delineado) |
| **Foto de producto o paleta** | Devuelve una paleta de colores para asignar a labios/sombras | K-means en OKLab, en el dispositivo |
| **Remix** ("más natural", "más cálido") | Modifica una receta existente | LLM recibe receta + instrucción y devuelve la receta completa, que se re-valida |

### 10.3 Flujo común

```
Entrada (texto / imagen / receta + instrucción)
   │
   ▼
Cloud Function `generateRecipe`  ── App Check · auth · cuota · límites de tamaño
   │   LLM (secret en Secret Manager)
   ▼
JSON  ──►  Validador (esquema + rangos + enums)  ──►  Moderación del texto
   │                                                    (si no pasa: se descarta, preset local)
   ▼
Preview EN VIVO en el motor (mismo renderer que producción) · sliders del editor
   │
   ▼
QA automático (caras de prueba × luces) ──► borrador (`status: draft`) ──► publicar
```

### 10.4 Prompt → receta

- **Siempre del lado servidor.** El cliente manda `{prompt, locale}`; la función devuelve `{variants: [recipe×3]}` ya validadas. La app vuelve a validar (defensa en profundidad).
- **Temperatura baja** (0.2–0.4) y salida en modo JSON, pero **el contrato lo impone el validador, no el modelo**.
- Si una variante no valida, se descarta; si no queda ninguna, se usa el preset local más cercano por palabras clave.

System prompt propuesto (en inglés porque suele ser más estable; el usuario puede escribir en cualquier idioma):

```text
You are a makeup look designer for an AR try-on engine. Convert the user's request into makeup recipes.
Return ONLY one JSON object: {"variants":[R1,R2,R3]} where every R follows the schema "makeup-recipe/2".
- R1 is faithful to the request, R2 is bolder, R3 is subtler/more natural. Give each a different "name"
  (max 60 chars) in the user's language.
- Use only the keys defined in the schema. Never add keys. Omit regions the user did not mention unless the
  look needs them to be coherent (then keep them subtle).
- Colors are "#RRGGBB". Opacity, coverage, spread, gloss, intensity are numbers in [0,1].
- lips.finish: matte|satin|gloss|shimmer. eyes.shadow[].finish: matte|satin|shimmer.
- Typical ranges: lips.opacity 0.6-0.95; cheeks.opacity 0.15-0.45; shadow opacity 0.25-0.7;
  liner opacity 0.7-1; foundation coverage 0.2-0.6.
- Vocabulary: "nude" = low-chroma warm browns/pinks; "gothic" = near-black plum or burgundy lips, strong liner,
  cool tones; "glossy" = finish gloss with gloss >= 0.5; "matte" = finish matte with gloss 0;
  "natural"/"no-makeup" = low opacities everywhere.
- Never output code, markdown, comments or any text outside the JSON object.
- If the request is not about makeup or asks for something unsafe, return {"variants":[]}.
```

Contrato de la función (para que Claude Code la implemente sin ambigüedad):

| | |
|---|---|
| **Entrada** | `{ kind: "prompt"\|"image"\|"remix", prompt?: string(≤300), locale: string, baseRecipe?: Recipe, imageStats?: ImageStats }` |
| **Salida** | `{ variants: Recipe[0..3], model: string, requestId: string }` |
| **Errores** | `unauthenticated`, `failed-precondition` (App Check), `resource-exhausted` (cuota), `invalid-argument`, `unavailable` (LLM caído → la app usa preset local) |
| **Límites** | Texto ≤ 300 caracteres; N llamadas por usuario por día (valor a definir); timeout corto y 1 reintento |
| **Nunca** | Devolver texto libre, código, ni recetas sin validar |

### 10.5 Imagen de referencia → receta

Es la parte con más matemática, pero se resuelve con piezas que el motor ya tiene.

1. **Landmarks de la foto** con el mismo tracker (modo imagen estática). Si no hay cara clara, se rechaza con un mensaje, sin adivinar.
2. **Rectificación a UV:** se "desenvuelve" la cara a la plantilla UV canónica usando la misma malla del render, en sentido inverso. Resultado: las máscaras de §5.4 (`lips_mask`, `lid_mask`, `cheek_mask`…) caen directamente sobre la foto, sin lógica por región nueva.
3. **Piel base:** mediana en OKLab de zonas con poco maquillaje (puente de la nariz, frente, mentón). Es la referencia "sin maquillaje" para medir cuánto cambió cada región.
4. **Color por región (muestreo robusto):** mediana en OKLab de los píxeles de la máscara, **descartando brillos especulares (L alto) y sombras (L bajo)**, para que un labial con brillo no salga "blanquecino".
5. **Color y opacidad no son identificables por separado:** lo que se observa es `obs = piel + w·(objetivo − piel)`, es decir, solo el producto. Convención: se **fija la opacidad por política** (labios ~0.85, rubor ~0.35, sombras ~0.5) y se despeja el color objetivo; si el color sale de gamut sRGB, se sube la opacidad hasta que entre. Lo probé: con tres políticas distintas (0.35, 0.6, 0.85) el **render resultante es idéntico (error de croma 0)** aunque el par color/opacidad cambie. Al usuario le sirve igual, porque en el editor puede mover ambos sliders y mantener el aspecto.
6. **Acabado:** `gloss_score` = fracción de píxeles claramente más claros que la mediana de la región (umbrales iniciales a calibrar). En la prueba sintética: labio mate → 0.00, labio con 7 % de píxeles especulares → 1.00, y el color robusto recuperado coincidió con el verdadero (0.621/0.179/0.199 vs 0.62/0.18/0.20). *Es una prueba sintética; con fotos reales hay que recalibrar.*
7. **El LLM de visión aporta lo que los píxeles no dicen:** estilo de delineado (ala, grosor), si hay sombra con brillo (`shimmer`), qué regiones tienen maquillaje y cuáles no. **No se le piden colores HEX**: los modelos de visión son malos para valores exactos. El resultado se fusiona con reglas deterministas: colores y opacidades salen del muestreo; enums y presencia de regiones, de la visión.
8. **Salida:** una receta + un puntaje de confianza por región. Siempre pasa por preview y sliders.

Opciones de visión (según la doc de Groq consultada hoy): hay **un solo modelo con entrada de imagen** (`qwen/qwen3.8-27b`), hasta **3 imágenes por request**, 20 MB, por URL o base64, y **el modo JSON funciona con visión**. Esto cambia rápido: verificá el nombre del modelo antes de implementar. Alternativa ya mencionada en la primera investigación: Gemini Flash multimodal.

Límites honestos: la iluminación, el balance de blancos y los filtros de belleza de la foto original sesgan el color. Mitigación: normalizar por la piel base y avisar la baja confianza. **La foto no se guarda**: se procesa en memoria/dispositivo y solo salen números.

Aviso de derechos: extraer parámetros de color de la foto de otra persona para un catálogo público puede tener implicancias de imagen y de datos personales. Para el catálogo, usá fotos propias o con autorización; para usuarios finales, procesamiento en el dispositivo y sin retención. No soy abogado.

Referencia ejecutable del paso 3–6 (probada): `tools/studio/sample_region_reference.py`.

### 10.6 Foto de producto o paleta → colores

K-means (k≈5) en OKLab sobre los píxeles de la foto, descartando fondo y blancos casi puros; devuelve swatches ordenados por área. En el Studio el usuario toca un swatch y lo asigna a labios, una sombra o el rubor. Corre en el dispositivo, sin LLM.

### 10.7 Remix

Se envía la receta actual y una instrucción corta ("más natural", "más intenso", "tonos más cálidos", "sin sombra"). El LLM devuelve **la receta completa**, no un parche, para evitar errores al aplicar diffs. El Studio muestra el antes/después y los campos que cambiaron.

### 10.8 Efectos que necesitan "assets" (pecas, glitter, pintura facial)

- **Ahora:** efectos **procedurales** de lista cerrada (`freckles`, `glitter`, `sheen`) con intensidad y región. No requieren imágenes.
- **Más adelante, experimental:** generar una textura RGBA en el espacio UV con un modelo de imágenes guiado por la plantilla UV. No verifiqué la calidad ni los costos de esta vía; probala con un prototipo antes de comprometerla.
- **Fuera de alcance:** accesorios 3D (lentes, orejas) y modelos 3D generados desde imágenes.

### 10.9 Backend seguro: lo que hay que cambiar ya

Hoy el proyecto llama a Groq directo desde la app. Una key dentro de la app se puede extraer, y con ella cualquiera consume tu cuota. Según el checklist de seguridad de Firebase: las keys de Firebase no son secretas, pero **las de otros servicios sí** y deben restringirse; se recomienda **App Check** en todos los servicios que lo soporten y autenticación requerida. Diseño:

1. **Cloud Function callable** `generateRecipe` (contrato en §10.4).
2. La key del LLM en **Secret Manager**, nunca en el código ni en variables de entorno de la app.
3. **App Check** activado en la función + usuario autenticado obligatorio.
4. **Cuota por usuario/día** (contador transaccional en Firestore) y límites de tamaño de entrada.
5. **Revocar la key actual** de Groq y sacarla del historial de git si alguna vez estuvo en el repo (el prompt P0 de §11 lo audita).

### 10.10 Auto-QA antes de publicar

Cada receta se renderiza sobre un set pequeño de **caras de prueba con consentimiento** (por ejemplo 6 tonos de piel × 3 condiciones de luz) y se chequea: *(umbrales iniciales, a calibrar con tus propias pruebas)*

| Chequeo | Falla si… |
|---|---|
| Visibilidad | ΔE medio (OKLab) entre con y sin filtro en la región es demasiado bajo → "no se nota" |
| Saturación/clipping | Un porcentaje alto de píxeles de la región sale de gamut o clipea |
| Cobertura | La región pintada ocupa un área implausible respecto de la máscara |
| Coste | El frame con esta receta excede el presupuesto de §5.9 |
| Consistencia | La misma receta en dos tonos de piel produce un resultado ilegible en alguno |

### 10.11 Esquema, validador y pruebas (hechas)

- **Esquema:** `docs/ar_engine/recipe_v2.schema.json` (JSON Schema draft 2020-12, `additionalProperties: false` en todos los niveles, enums cerrados, HEX `^#[0-9A-Fa-f]{6}$`, `[0,1]` para todos los factores, máx. 4 sombras y 3 efectos).
- **Pruebas ejecutadas** con `jsonschema` 4.26: 1 receta válida aceptada y 7 inválidas rechazadas (opacidad 1.7; color `"rojo"`; `finish: "metalico"`; propiedad extra `shader`; 5 sombras; `schema: "makeup-recipe/1"`; nombre vacío). El validador Dart de F1 debe reproducir exactamente estos 8 casos.
- El esquema valida estructura y rangos, **no calidad estética**: de eso se ocupa el auto-QA (§10.10) y vos en el preview.

### 10.12 Modelo de datos y reglas de Firestore (esbozo, no probado)

```
looks/{lookId}                           // ya existe
  name, category ('Lips'|'Eyes'|'Complexion'), image, video_url, steps[]   // existentes
  recipe: map (makeup-recipe/2)          // nuevo
  recipeSchema: 'makeup-recipe/2'        // nuevo
  minEngine: int                         // nuevo: versión mínima del motor que la renderiza
  status: 'draft' | 'published'          // nuevo
  source: { type: 'prompt'|'image'|'remix'|'manual', prompt?: string, model?: string }
  createdBy: uid · createdAt · updatedAt

users/{uid}/ai_looks/{id}                // looks generados por usuarios finales
  escritos SOLO por la Cloud Function (Admin SDK); el cliente solo lee los suyos
users/{uid}/usage/{yyyymmdd}             // contador de cuota diaria
```

Puntos para las reglas (a implementar y probar con el emulador): lectura pública de `looks` **solo si `status == 'published'`** o si es admin, tratando la ausencia de `status` en looks viejos como publicado (`resource.data.get('status','published')`); escritura de `looks` solo admin (como hoy); `users/{uid}/ai_looks` solo lectura para su dueño y escritura denegada al cliente; `usage` sin acceso del cliente. La app ignora recetas con `minEngine` mayor al del motor instalado.

### 10.13 La pantalla "Studio" (admin primero, usuarios después)

1. Caja de texto + botón "subir imagen".
2. **Tres variantes lado a lado**, renderizadas en vivo con el motor sobre la cámara o una foto de prueba.
3. Sliders (el `FilterEditorScreen` actual crece para editar los campos de la receta) y botón "Remix".
4. Auto-QA en segundo plano con semáforo por chequeo.
5. "Guardar borrador" → "Publicar". Los usuarios finales pueden recibir después una versión reducida (prompt → 3 variantes → guardar en sus looks).

---

## 11. Instrucciones para Claude Code

Claude Code es quien va a escribir casi todo este código, así que importa prepararle el terreno. Estructura verificada contra la documentación actual de Claude Code.

### 11.1 Qué se configura y dónde

| Pieza | Ubicación | Para qué |
|---|---|---|
| **CLAUDE.md** | `./CLAUDE.md` (o `./.claude/CLAUDE.md`) | Instrucciones permanentes del proyecto. Meta: **menos de 200 líneas**; archivos más largos consumen contexto y bajan el cumplimiento |
| **CLAUDE.local.md** | `./CLAUDE.local.md` (en `.gitignore`) | Preferencias personales (rutas de tu PC, id del E20) |
| **Reglas por ruta** | `.claude/rules/*.md` con `paths:` en el frontmatter | Reglas que solo se cargan al tocar archivos que coinciden (Dart AR, C++/GLES, shaders, Firebase) |
| **Subagentes** | `.claude/agents/<nombre>.md` (frontmatter `name`, `description`, `tools`, `model`) | Revisores especializados con contexto aislado |
| **Hooks** | `.claude/settings.json` + `.claude/hooks/*.sh` | **Aplican de forma determinista** lo que CLAUDE.md solo *sugiere* |
| **Modo plan** | `claude --permission-mode plan` o `Shift+Tab` | Claude propone el plan y no edita hasta que lo aprobás |
| **Worktrees** | `claude --worktree <nombre>` | Sesiones paralelas aisladas (p. ej. motor nativo y Studio a la vez) |
| **Continuar** | `claude --continue` / `/resume` | Retomar una tarea larga |

Detalles que conviene saber (de la documentación):
- CLAUDE.md es **contexto, no configuración obligatoria**: Claude lo trata como guía. Para *bloquear* algo sin excepciones, usá un hook `PreToolUse`.
- `@ruta` dentro de CLAUDE.md **importa** el archivo y lo carga siempre, así que **no reduce el costo de contexto**. Por eso el informe de 30 KB **no** se importa: CLAUDE.md lo nombra entre backticks para que lo lea solo cuando haga falta.
- `/init` genera un CLAUDE.md inicial analizando el repo; si ya existe uno, sugiere mejoras en vez de pisarlo. Usalo **después** de copiar el nuestro.
- Si dos instrucciones se contradicen, Claude puede elegir una al azar: revisalas de vez en cuando (hay un `/doctor prompt-audit`).

### 11.2 Puesta en marcha (una vez)

1. Copiá el doc `claude/CLAUDE.md` a la raíz del repo como `CLAUDE.md`.
2. Copiá este informe a `docs/ar_engine/motor_ar_propio.md`, el esquema a `docs/ar_engine/recipe_v2.schema.json` y la referencia Python a `tools/studio/sample_region_reference.py`.
3. Creá los archivos de §11.3 y §11.4.
4. En el repo, `claude` → `/init` (que sugiera mejoras sin pisar nada).
5. Arrancá cada fase con **modo plan** y el prompt de §11.6.

### 11.3 Reglas por ruta (`.claude/rules/`)

Archivos creados en el repo: `dart-ar.md`, `native-gles.md`, `shaders.md`, `firebase.md` (ver `.claude/rules/`). Contenido de referencia:

`.claude/rules/dart-ar.md`
```markdown
---
paths:
  - "lib/features/ar/**/*.dart"
  - "packages/makeup_engine/lib/**/*.dart"
---
# Dart del módulo AR
- Null-safety estricta: nada de `!` sin comprobación previa en la misma función; preferí `?.` y valores por defecto.
- Prohibido instanciar objetos pesados (Paint, Path, Shader, listas) dentro de `paint()` o de loops por frame: crealos una vez y reutilizalos.
- Un solo `ValueNotifier`/`Listenable` por flujo; nada de `setState` por frame.
- Todo `StreamSubscription`, `Timer`, controller y `Isolate` se cancela en `dispose()`.
- Los frames se descartan con una bandera tipo `_frameInFlight`; nunca se encolan.
- Código nuevo con test unitario; comentarios en español, identificadores en inglés.
```

`.claude/rules/native-gles.md`
```markdown
---
paths:
  - "packages/makeup_engine/android/**/*.{cpp,h,hpp,kt}"
  - "packages/makeup_engine/ios/**/*"
---
# Motor nativo (C++/GLES)
- OpenGL ES 3.0 como mínimo común; nada de Vulkan sin spike aprobado.
- Cero allocations por frame en el hilo de render: buffers y texturas se crean al iniciar y se reutilizan.
- Un hilo dueño del contexto GL; la inferencia corre en otro hilo y se comunica por una cola de un solo elemento (último valor gana).
- Recursos GL con RAII; en debug, comprobar `glGetError` tras cada bloque de llamadas.
- Nada de cruces JNI/FFI por frame: Dart envía recetas y lee métricas.
- Toda constante de rendimiento (resoluciones, Hz de inferencia) en un único header de configuración.
```

`.claude/rules/shaders.md`
```markdown
---
paths:
  - "packages/makeup_engine/**/*.{frag,vert,glsl}"
---
# Shaders
- GLSL ES 3.00 (`#version 300 es`), `precision mediump float` por defecto; `highp` solo donde se justifique con un comentario.
- Las conversiones de color (sRGB↔lineal, OKLab) viven en un único include compartido.
- Máximo de lecturas de textura por fragmento: documentarlo en el encabezado del shader y no superarlo sin medir.
- Sin bucles de longitud variable ni ramas costosas en el fragment shader.
- Cada uniform se documenta (rango y unidad) en el encabezado.
```

`.claude/rules/firebase.md`
```markdown
---
paths:
  - "firestore.rules"
  - "functions/**"
---
# Firebase y Cloud Functions
- Ninguna key ni secreto en el repo: Secret Manager para las functions.
- Toda entrada del cliente se valida en la función con el mismo esquema JSON que usa la app.
- Las reglas de Firestore se prueban con el emulador antes de proponer cambios.
- Cambios en `firestore.rules` o en cuotas: plan primero y pedir confirmación.
```

### 11.4 Subagentes y hook de protección

Subagentes creados en `.claude/agents/`: `perf-auditor.md` y `shader-reviewer.md`.

`.claude/agents/perf-auditor.md`
```markdown
---
name: perf-auditor
description: Audita código del motor AR buscando allocations por frame, trabajo en el hilo de UI/render, fugas de recursos y llamadas JNI/FFI por frame. Usalo antes de cerrar cada fase.
tools: Read, Grep, Glob
model: sonnet
---
Sos un ingeniero de rendimiento móvil. Revisá solo lo que se te indique. Para cada hallazgo informá: archivo:línea,
qué ocurre por frame, por qué cuesta en un Moto E20 (2 GB, Mali-G57 MP1) y la corrección mínima.
No edites archivos. Si no encontrás problemas, decilo explícitamente y listá qué revisaste.
```

`.claude/agents/shader-reviewer.md`
```markdown
---
name: shader-reviewer
description: Revisa shaders GLSL ES del motor: corrección del color (sRGB/lineal/OKLab), uso de precisión, cantidad de lecturas de textura y riesgos de artefactos. Usalo al crear o modificar un .frag.
tools: Read, Grep, Glob
model: sonnet
---
Revisá cada shader contra las reglas de `.claude/rules/shaders.md`. Verificá que los uniforms estén
documentados y en rango, que no haya divisiones por cero ni `pow` de negativos, y que el resultado se
conserve en gamut. Informá hallazgos priorizados; no edites archivos.
```

**Hook:** `.claude/hooks/protect-files.sh` + `.claude/settings.json` (`PreToolUse`, matcher `Edit|Write`). Patrones protegidos: `.env`, `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `.jks`, `revenue_cat_keys.dart`, `.git/`. Sale con código 2 para bloquear.

> **Nota de implementación (difiere de la plantilla original del informe):** la versión del repo no depende de `jq` (no está instalado en la PC de desarrollo: con la plantilla original el hook dejaba pasar todo sin avisar), extrae `tool_input.file_path` con `grep`/`sed`, **falla cerrada** si no puede leer la ruta y normaliza `\` → `/`. La línea `FILE_PATH="${FILE_PATH//\\//}"` de la plantilla original tenía un bug: borraba las `/` en lugar de convertir las `\`, por lo que el patrón `.git/` nunca coincidía. El hook solo cubre `Edit`/`Write`: no impide que un comando `Bash` escriba esos archivos. `revenue_cat_keys.example.dart` no coincide con `revenue_cat_keys.dart`, así que el ejemplo sigue editable.

### 11.5 Protocolo de medición en el Moto E20 (lo corrés vos)

Claude Code **no puede ejecutar nada en tu teléfono**. Su trabajo es dejar el arnés listo; el tuyo, correrlo y pegarle los resultados.

1. `flutter run --profile -d <id-del-E20>`. **Nunca medir en debug.**
2. FPS y latencias: contadores nativos con overlay (p50/p95 de cámara, inferencia, compositor).
3. Memoria: `adb shell dumpsys meminfo <paquete>` al inicio y a los 10 minutos; no debe crecer de forma sostenida.
4. Térmica: `adb shell dumpsys thermalservice` y `adb shell dumpsys battery` (temperatura) cada 2–3 minutos durante una sesión de 10 minutos.
5. Frames de UI: `adb shell dumpsys gfxinfo <paquete> framestats`.
6. Anotá siempre: build (`profile`), resolución, receta usada, brillo de pantalla, cargando o no, temperatura inicial.

*(Son comandos estándar de Android; no los probé en un E20 concreto. Si alguno no devuelve datos en Android 11 Go, avisale a Claude Code para que adapte el arnés.)*

### 11.6 Prompts por fase (para pegar en Claude Code, en modo plan)

Cada prompt asume que `CLAUDE.md` ya está en la raíz. Orden recomendado: **P0 → P1 → F1 → P2…**

**P0 — Auditoría del repo (sin modificar código)**
```text
Objetivo: averiguar dónde quedó el pipeline AR (ML Kit, CustomPainter, Groq) y qué se puede reutilizar.
No modifiques archivos del proyecto. Pasos:
1) Revisá todas las ramas y el PR #11. Buscá en el historial código que mencione FaceMesh, CustomPainter,
   groq, startImageStream, usando `git log --all -S"<término>" --oneline` y
   `git log --all --diff-filter=D --name-only`.
2) Identificá qué se borró, en qué commit, y qué conviene recuperar (editor de looks, i18n, VIP, etc.).
3) Buscá API keys o secretos en el historial. Si encontrás alguno, NO lo copies: reportá archivo, commit y
   tipo de secreto, y recordame revocarlo.
4) Entregable: docs/ar_engine/AUDIT.md con: qué existe hoy, qué se perdió, qué se recupera, riesgos.
Parar y preguntarme si algo es ambiguo.
```

**P1 — Spike de viabilidad en el E20**
```text
Contexto: leé docs/ar_engine/motor_ar_propio.md §3, §4, §5.1, §5.9 y §11.5.
Objetivo: demostrar que el camino nativo funciona en un Moto E20 antes de construir nada más.
1) Creá packages/makeup_engine (plugin Flutter, solo Android por ahora).
2) Cámara Camera2 → SurfaceTexture → GLES 3.0 → Texture de Flutter, con un quad de paso directo y un shader
   de tinte. Overlay con tiempo de frame p50/p95 calculado en nativo.
3) Arnés de benchmark de un modelo de landmarks con LiteRT: GPU delegate vs CPU (XNNPACK), entradas de
   192x192, 300 iteraciones, p50/p95 por backend, sin UI.
4) Dejá docs/ar_engine/SPIKE_RESULTS.md con una tabla vacía para completar y los comandos de §11.5.
Restricciones: NO elijas el modelo vos: proponeme 2–3 candidatos con su licencia y pará para que yo confirme.
Criterio de aceptación: compila, corre en el E20 y el overlay muestra métricas. Yo completo los números.
```

**F1 — Receta v2 y validador (puede ir en paralelo con P1)**
```text
Contexto: docs/ar_engine/recipe_v2.schema.json y motor_ar_propio.md §5.8 y §10.
Objetivo: dominio de recetas, independiente del motor.
1) lib/features/ar/domain: MakeupRecipe (inmutable), enums cerrados y RecipeValidator que aplique el esquema
   y haga clamp de rangos. Sin dependencias de Flutter en el dominio.
2) Tests que reproduzcan EXACTAMENTE estos 8 casos: 1 receta válida (aceptada) y 7 inválidas (opacidad 1.7;
   color "rojo"; finish "metalico"; propiedad extra "shader"; 5 sombras; schema "makeup-recipe/1"; nombre vacío).
3) Presets locales (5 looks) como fallback cuando la IA falle.
Criterio: `flutter analyze` sin warnings y `flutter test` en verde.
```

**F2 — Cloud Function `generateRecipe`**
```text
Contexto: motor_ar_propio.md §10.4 y §10.9. Plan primero y mostrame el plan antes de editar.
Objetivo: sacar la key de Groq de la app.
1) functions/: callable `generateRecipe` con el contrato de §10.4, key en Secret Manager, App Check exigido,
   usuario autenticado obligatorio y cuota diaria por usuario (transacción en users/{uid}/usage/{yyyymmdd}).
2) Validación server-side con el mismo esquema JSON.
3) En la app: reemplazá la llamada directa a Groq por la callable; eliminá toda key del cliente.
4) Tests con el emulador de Functions.
Parar y preguntarme antes de tocar firestore.rules o configurar cuotas reales.
```

**P2 — Núcleo de cámara y render** (solo si el spike es "go")
```text
Contexto: §4 y §5.1–5.4. Objetivo: pipeline estable cámara → compositor → Texture con malla UV de prueba.
Entregables por orden, cada uno en su commit: (a) hilo de render dueño del contexto GL; (b) carga de malla
canónica + UV (pedime confirmar la licencia del asset); (c) dibujo de la malla con landmarks simulados;
(d) API FFI mínima: start/stop, setRecipe(json), getStats().
Criterio: 10 minutos a ≥24 fps sin crecimiento de memoria en el E20 (yo mido con §11.5).
Usá el subagente perf-auditor antes de cerrar.
```

**P3 — Tracker, pose y estabilización**
```text
Contexto: §5.2 y §5.3. Objetivo: IFaceTracker en C++ con detector + ROI del frame previo, pose por Umeyama
(Procrustes), One Euro por coordenada (portá la clase Dart de §5.3) y extrapolación acotada.
Tests de host (CMake) para Umeyama y One Euro con datos sintéticos. Métrica: jitter estático < 0.5 px.
```

**P4 — Compositor UV y labios**
```text
Contexto: §5.4 y §5.5 (shader de labios). Objetivo: labios fotorrealistas sobre la malla tracked.
Entregables: herramienta tools/uv_masks para autorar y versionar la máscara de labios y el mapa de brillo;
shader de labios del informe adaptado a las reglas de .claude/rules/shaders.md (usá shader-reviewer);
ajuste de uLumaFollow y del L de referencia con 5 tonos de piel. Capturas antes/después para que yo juzgue.
```

**P5 — Resto de regiones y API final**
```text
Contexto: §5.4–5.8. Regiones en este orden: rubor, sombras, delineado, foundation, contorno/iluminador.
Cada región con su máscara UV, shader, tests y captura. Cierre: API Dart estable detrás de IMakeupRenderer
y feature flag --dart-define=AR_RENDERER=native|painter. Pasada final con perf-auditor.
```

**F3 — Pantalla Studio (después de P4)**
```text
Contexto: §10.3, §10.12 y §10.13. Extendé FilterEditorScreen: prompt → 3 variantes en vivo (usa
generateRecipe), sliders sobre la receta, borrador/publicado y campos nuevos de Firestore.
Migración: looks existentes sin `status` se tratan como publicados. Plan primero.
```

**F4 — Imagen → receta (después de P3 y P4)**
```text
Contexto: §10.5, §10.6 y tools/studio/sample_region_reference.py (ya probado).
Objetivo: portar a Dart/C++ el muestreo robusto, la política de opacidad y el gloss_score; rectificación a UV
con la malla del render; K-means en OKLab para paletas. La visión (LLM) solo aporta enums y presencia de
regiones, nunca HEX. Tests: reproducir los resultados del script de referencia en datos sintéticos
(mate → gloss_score ~0, brillante → ~1, color robusto dentro de ±0.005 por canal sRGB).
```

### 11.7 Reglas de trabajo con Claude Code

- **Plan primero, siempre** en tareas que toquen más de 2–3 archivos o cambien arquitectura. Leé el plan antes de aprobarlo.
- **Una fase por rama/worktree** y commits chicos. Pedile que no mezcle refactors con features.
- **Medir antes de optimizar:** ninguna "mejora de rendimiento" se acepta sin números del E20.
- **Pedile que pare y pregunte** ante: licencias de modelos/assets, dependencias nuevas, cambios en `firestore.rules`, cambios de costos o cuotas, y secretos encontrados.
- **Si se atasca** (más de 2–3 intentos con el mismo error): pedile que pare, resuma qué probó y qué descartó, y abrí una sesión nueva con ese resumen en vez de seguir acumulando contexto.
- **Una cosa que no puede hacer por vos:** probar en el teléfono. Pegale los resultados de §11.5 como texto y capturas.

---

## 12. Fuentes

Verificadas en esta sesión:
- Repo `IamRoman-rb/makeup_ar` (clonado, `main` @ `e462a34`).
- [Moto E20 – GSMArena](https://m.gsmarena.com/motorola_moto_e20-11072.php)
- [Flutter: fragment shaders (limitaciones)](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
- [Flutter GPU – documentación de Impeller](https://flutter.googlesource.com/mirrors/engine/+/HEAD/docs/impeller/Flutter-GPU.md) · [API `flutter_gpu`](https://api.flutter.dev/flutter/flutter_gpu/)
- [google_mlkit_face_mesh_detection (pub.dev)](https://pub.dev/documentation/google_mlkit_face_mesh_detection/latest/)
- [Real-time Facial Surface Geometry from Monocular Video on Mobile GPUs (arXiv 1907.06724)](https://arxiv.org/pdf/1907.06724)
- [MediaPipe Face Mesh – docs](https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/face_mesh.md)
- [Microsoft FaceSynthetics (licencia no comercial)](https://github.com/microsoft/FaceSynthetics)
- [LiteRT GPU delegate (Android)](https://developers.google.com/edge/litert/android/gpu)
- [Foundation makeup con Kubelka-Munk (arXiv 2507.07333)](https://arxiv.org/html/2507.07333v1)
- [Claude Code: memoria y CLAUDE.md](https://code.claude.com/docs/en/memory) · [flujos comunes (modo plan, worktrees, continuar sesiones)](https://code.claude.com/docs/en/common-workflows) · [guía de hooks](https://code.claude.com/docs/en/hooks-guide) · [subagentes](https://code.claude.com/docs/en/sub-agents)
- [Groq: visión](https://console.groq.com/docs/vision.md)
- [Firebase: checklist de seguridad](https://firebase.google.com/support/guides/security-checklist)

Probado por mí en esta sesión (Python): esquema de recetas v2 (1 válida + 7 inválidas), ida y vuelta OKLab, filtro One Euro, estimación color/opacidad/brillo sobre datos sintéticos.

No verificadas en esta sesión (conocimiento previo, a confirmar antes de decidir): licencias concretas de 300W/WFLW/CelebA/FFHQ/LaPa/BFM/FLAME; número exacto de triángulos del modelo canónico (~900); comportamiento de Vulkan en gamas bajas; compatibilidad `Texture`/SurfaceProducer en la versión de Flutter del proyecto; comandos `adb` de §11.5 en un E20 concreto; reglas de Firestore y contrato de la Cloud Function de §10 (no ejecutados contra el emulador); disponibilidad actual del modelo de visión de Groq; plantillas de reglas y subagentes de §11 (no ejecutadas).
