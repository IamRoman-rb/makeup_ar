# Spike P1: resultados

**Objetivo (informe §7, fase 0):** demostrar en el Moto E20 que el camino nativo cámara → GLES 3.0 → `Texture` de Flutter es viable antes de construir el motor, y medir la latencia de un modelo de landmarks (GPU delegate vs CPU).

**Estado (2026-10-06):**

| Pieza | Estado |
|---|---|
| Plugin `packages/makeup_engine` (Camera2 → SurfaceTexture/OES → GLES 3.0 → SurfaceProducer → `Texture`) | ✅ Hecho, compila, probado en el emulador |
| Shaders de paso directo y tinte OKLab de pantalla completa | ✅ Hecho |
| Overlay con métricas calculadas en nativo (p50/p95) | ✅ Hecho |
| Tests: 10 JVM (`CameraMath`) + 6 Dart (API del plugin) | ✅ En verde |
| **Mediciones en el E20** | ⏳ **Te toca a vos** (sección 3) |
| Arnés de benchmark LiteRT (landmarks) | ⏸️ **Bloqueado**: necesita que elijas el modelo y apruebes la dependencia (sección 4) |

---

## 1. Qué se construyó

```
Camera2 (hilo "makeup-camera", cámara frontal, AE [x,30])
   │ Surface(SurfaceTexture)
   ▼
SurfaceTexture → textura OES                     ← updateTexImage() en el hilo de render
   │
   ▼  1 llamada JNI por frame, sin allocations
Renderer C++ (hilo "makeup-render", dueño de EGL/GL)
   ├ passthrough.frag  (tinte = 0)
   └ tint_oklab.frag   (tinte > 0: ida y vuelta sRGB→OKLab→sRGB por píxel = peor caso)
   │ eglSwapBuffers
   ▼
SurfaceProducer (Flutter) → Texture(textureId)    ← Dart solo lee métricas a 2 Hz
```

- **Constantes de rendimiento:** `packages/makeup_engine/android/src/main/cpp/engine_config.h`. Preview máximo 1280×720, AE con techo de 30 fps y ventana de 256 muestras. Kotlin las lee del header por JNI, sin duplicarlas.
- **Métricas (todas nativas):** intervalo entre frames dibujados, CPU del hilo de render (`updateTexImage` + draw + `eglSwapBuffers`) e intervalo entre timestamps de cámara (fps real del sensor), en p50/p95. **No** mide tiempo de GPU: eso requiere `GL_EXT_disjoint_timer_query` y queda para P2 si el driver del E20 lo expone.
- **Entrypoint separado:** `lib/main_spike.dart` no carga Firebase ni RevenueCat, así que compila aunque falte `revenue_cat_keys.dart` (hallazgo 4 de `AUDIT.md`).
- **Rotación (corregida el 2026-10-07):** Camera2 ya corrige la orientación del sensor en la matriz de `SurfaceTexture`, así que en vertical no hay rotación extra; solo el espejo de la cámara frontal. La primera versión aplicaba la orientación del sensor una segunda vez y la imagen salía girada 90°. Se detectó comparando con la vista previa de CameraX en el emulador (las 4 rotaciones lado a lado) y se corrigió en `CameraMath.extraRotation`/`outputSize`. Las pantallas del motor se bloquean en vertical: las orientaciones horizontales no están validadas. Si en el E20 la imagen sale girada, el botón **"Rotar 90°"** del spike prueba las 4 orientaciones.
- **Decisión de diseño a validar:** hay una llamada JNI Kotlin→C++ por frame (`nativeDrawFrame`). La regla de `native-gles.md` apunta a los cruces **Dart**↔nativo, que acá son cero. Esta llamada es inevitable con `minSdk 24`, porque `SurfaceTexture.updateTexImage()` es API Java (`ASurfaceTexture` en NDK exige API 28).

## 2. Prueba de humo en el emulador (NO son números del E20)

Emulador `Medium_Phone` (API 37, x86_64, **GPU por software SwiftShader**, cámara frontal sintética). Solo sirve para comprobar que funciona; los tiempos de SwiftShader no predicen nada del Mali-G57.

| Comprobación | Resultado |
|---|---|
| GL | `OpenGL ES 3.0 SwiftShader`, GLSL ES 3.00, `GL_OES_EGL_image_external_essl3` disponible |
| Compilación y link de shaders | OK |
| Cámara → GL → `Texture` | OK: 1280×720 → 720×1280, sensor 270°, rotación 270°, AE 30–30 |
| FPS render / cámara | ~28,5 / ~29 |
| Tinte OKLab al 100% | Cambia la croma y conserva la luminancia: las zonas oscuras siguen oscuras y las claras siguen claras (verificado con capturas de pantalla) |
| Estrés del ciclo de vida: 3 rondas de 5 reinicios rápidos (cada 300 ms, o sea stop durante start y durante la apertura de cámara) + salir y reabrir + salir enseguida | 21 inicializaciones de GL: **0 crashes, 0 ANR, 0 warnings, 0 hilos del motor vivos al salir** |

## 2.1 Filtro de prueba dentro de la app

En el **Espejo** de la app normal, el botón ✨ de la barra cambia de la cámara de siempre (plugin `camera`) al motor nativo, con chips para los 5 presets locales (el color de labios de cada uno, aplicado como tinte OKLab a toda la imagen) y un slider de intensidad. Todavía no es maquillaje por zona: eso necesita el tracker (P3). Sirve para ver en el teléfono, sin herramientas, que el camino cámara → GLES → `Texture` funciona y a cuántos fps (el badge de arriba a la izquierda).

Probado en el emulador: alternar ida y vuelta (también rápido), cambiar de preset y salir. 0 crashes del motor.

## 3. Mediciones en el E20 (completar)

### 3.1 Preparación

```bash
flutter run --profile -t lib/main_spike.dart -d <id-del-E20>
```

Nunca medir en debug. Antes de cada corrida anotá: brillo de pantalla, si está cargando, temperatura inicial (`adb shell dumpsys battery | grep temperature`) y la orientación que quedó bien.

### 3.2 Render (overlay de la app; tocá "Reset" y esperá 10 s antes de anotar)

| Escenario | Render fps | Intervalo p50 / p95 (ms) | CPU render p50 / p95 (ms) | Cámara p50 / p95 (ms) |
|---|---|---|---|---|
| Paso directo (tinte 0%) | | | | |
| Tinte OKLab 100% | | | | |
| Tinte OKLab 100% a los 10 min | | | | |

Línea de GL del overlay (vendor | renderer | versión | GLSL): `____________`

### 3.3 Memoria y térmica (sesión de 10 min con tinte al 100%)

```bash
adb shell dumpsys meminfo com.example.ar_makeup_app
adb shell dumpsys thermalservice
adb shell dumpsys battery
adb shell dumpsys gfxinfo com.example.ar_makeup_app framestats
```

| Minuto | PSS total (MB) | Temperatura batería (°C) | Estado térmico | Render fps |
|---|---|---|---|---|
| 0 | | | | |
| 3 | | | | |
| 6 | | | | |
| 10 | | | | |

### 3.4 Criterio go / no-go

- **Go** si con tinte al 100% el render sostiene **≥ 24 fps (intervalo p50 ≤ 41,7 ms)** durante 10 min, la memoria no crece de forma sostenida y el dispositivo no entra en throttling severo.
- Con tinte 0% y 100% iguales y ambos a ~30 fps, el compositor tiene margen para las capas de P4/P5.
- Si el tinte al 100% cae por debajo de 24 fps pero el paso directo no: el costo está en el shader de pantalla completa. En el motor real el maquillaje solo se pinta dentro de las máscaras UV (informe §5.4), así que no es bloqueante, pero hay que medirlo de nuevo en P4.

## 4. Benchmark de landmarks: candidatos (necesito tu decisión)

`CLAUDE.md` exige que vos elijas el modelo y apruebes la dependencia. Verifiqué la licencia en el model card oficial de cada uno.

| # | Modelo | Entrada | Salida | Licencia | Notas |
|---|---|---|---|---|---|
| **A (recomendado)** | **MediaPipe FaceMesh-V2** (dentro de `face_landmarker.task`) + detector **BlazeFace short-range** | 256×256 (landmarks), 192×192 (detector, según la doc del bundle) | 478 puntos 3D (468 + iris) y 52 blendshapes (modelo aparte, opcional) | **Apache 2.0** (model card de FaceMesh-V2: "Licensed under Apache License, Version 2.0") | Trae evaluación de equidad por tono de piel (Fitzpatrick 1–6) y región geográfica. Incluye iris (informe §5.7). Es float16 |
| B | MediaPipe Face Mesh **V1** (`face_landmark.tflite`) + `face_detection_short_range.tflite` | 192×192 | 468 puntos 3D | Apache 2.0 (repo `google-ai-edge/mediapipe`) | Más liviano que V2 (el informe publica 7,4 / 3,4 / 2,6 ms en un Pixel 3 para full / light / lightest). Sin iris. Es el que asume el prompt P1 (entrada 192×192) |
| C | Variante *attention mesh* (`face_landmark_with_attention`) | 192×192 | 478 puntos con refinamiento de labios, ojos e iris | Apache 2.0 | Mejor contorno de labios (clave para el maquillaje), pero más caro: medir solo si A y B entran con margen |

**Descartados:** PFLD, 3DDFA_V2, los modelos de InsightFace y similares, porque están entrenados con datasets de investigación no comercial (300W-LP, WFLW, etc.; informe §6.1).

**Dependencia necesaria:** el runtime LiteRT (`com.google.ai.edge.litert:litert`, Apache 2.0, la última versión publicada es la 2.1.5 del 7 de julio de 2026) más su GPU delegate. Lo que agrega al APK hay que medirlo al integrarlo.

**Plan del arnés, una vez aprobado:** una pantalla sin UI de render que corre 300 inferencias por backend (GPU delegate, CPU con XNNPACK y 2 hilos, CPU con 4 hilos) sobre una imagen fija, descarta las 20 primeras como warm-up y reporta p50/p95 en esta misma tabla:

| Modelo | Backend | p50 (ms) | p95 (ms) | Notas |
|---|---|---|---|---|
| | GPU delegate | | | |
| | CPU XNNPACK ×2 | | | |
| | CPU XNNPACK ×4 | | | |

---

## 5. Revisiones de cierre (`perf-auditor` y `shader-reviewer`)

Las dos revisiones corrieron sobre el código del spike. Se corrigió todo menos lo marcado como "pendiente".

**Rendimiento y ciclo de vida:**
- Una excepción síncrona en `start()` dejaba la sesión huérfana, y todo `start()` posterior respondía `already_started`. → try/catch con liberación.
- Un `stop` durante la apertura de la cámara dejaba el `CameraDevice` abierto. → el hilo de cámara sigue vivo hasta el `onClosed` del dispositivo y de la sesión, con un respaldo de 2 s.
- Un `stop` durante `start` dejaba el `Future` de Dart colgado. → responde `cancelled`.
- `release()` bloqueaba el hilo de UI hasta 2 s. → ahora solo espera que el hilo de render suelte la ventana (≤ 250 ms; normalmente un frame), y cámara y GL se cierran de forma asíncrona.
  - El estrés encontró un crash nuevo al hacer todo asíncrono: un frame llegaba a Flutter con el engine ya desacoplado. Por eso la `SurfaceProducer` se libera de forma síncrona.
- Se agregó try/catch a `updateTexImage`, y los callbacks acumulados sin buffer nuevo se descartan comparando timestamps.
- Si `eglMakeCurrent` falla, ya no queda `hasWindow = true`.
- Camino caliente:
  - Sin mutex por frame (versión atómica de la matriz de display).
  - El sampler se fija una vez, no por frame.
  - `glInvalidateFramebuffer` antes del draw, para que la Mali no cargue el framebuffer anterior en cada tile.
  - Los percentiles se calculan fuera del lock del hilo de render.
  - El hilo de render tiene prioridad `THREAD_PRIORITY_DISPLAY`.
  - El slider de tinte coalesce las llamadas: gana el último valor.
- Pendiente (menor): cachear el display y la superficie EGL en lugar de `eglGetCurrent*` por frame.

**Shaders:**
- Algunos compiladores GLSL de Mali rechazan bytes no ASCII aunque estén en comentarios. → CMake los quita al embeber; las fuentes conservan los comentarios en español.
- `vTexCoord` en `highp` en los fragment shaders: con `mediump` se perdía la precisión subpíxel del vertex.
- `oklabToLinear` en `highp`: en fp16 daba 1–2 LSB de error en altas luces.
- Sampler con precisión explícita, y uniforms documentados con rango, unidad y layout.
- Estimación del revisor (no medida): el tinte de pantalla completa cuesta ~5–9 ms de GPU por frame en el Mali-G57 MP1, dentro del presupuesto. **Hay que confirmarlo en el E20.**

## 6. Pendiente que no depende del E20

- Tiempo de GPU con `GL_EXT_disjoint_timer_query` (P2). Hoy `cpuP95` no incluye la GPU, porque `eglSwapBuffers` es asíncrono.
