# P3: tracker facial en vivo

Diseño del tracker (informe §5.2–5.3) tal como quedó implementado, la desviación respecto de §4 y cómo medirlo en el E20.

## 1. Qué hace

En el Espejo → **Filtro de prueba**:

- **Solo labios** (por defecto): el labial de la receta sobre la malla tracked. Desde P4 es el labial fotorrealista (máscara UV, brillo, acabados): ver `LIPS.md`. La máscara de pantalla provisional de P3 ya no existe.
- **Ver puntos**: dibuja los 478 landmarks (depuración).
- El badge muestra fps del render y el estado del tracker: `cargando modelos…`, `buscando cara…`, `NN Hz · NN ms`.

Los modelos se cargan recién cuando una opción necesita el tracker. La primera vez compila para la GPU (~5 s en el E20 según P1). Después usa la caché de programas en `cacheDir/litert_gpu`: en el emulador, 3657 ms la primera vez y 872 ms la segunda.

## 2. Flujo por frame

Dart no cruza en ningún paso.

```
[makeup-render, ~30 fps]  SurfaceTexture.updateTexImage
  1. CropPass.poll: si el fence del recorte anterior ya se cumplió, map del PBO
     → memcpy a TrackingState::cropPixels → kReady → nativeDrawFrame devuelve
     FRAME_FLAG_CROP_READY → Kotlin postea un Runnable preasignado al tracker.
  2. Si el tracker pidió un recorte (kWaitRender) y el throttle lo permite:
     CropPass.issue → FBO 128² (detector, letterbox, 4×4 taps) o 256² (landmarks,
     ROI rotado, 2×2 taps) → glReadPixels a PBO + fence (no bloquea).
  3. Malla extrapolada al timestamp de este frame (TrackingState::landmarksForRender).
  4. Solo labios: triángulos de labios → máscara R8 a 1/4 de resolución.
  5. Quad de cámara con tinte (completo o con máscara) y, si corresponde, puntos.

[makeup-tracker, ≤ 20 Hz con cara, ≤ 10 Hz buscando]
  nativeTrackerFillInput (RGBA8 → float en C++, sobre un FloatArray reutilizado)
  → writeFloat → run → readFloat (LiteRT, GPU con fallback a CPU)
  → nativeTrackerSubmitDetections / nativeTrackerSubmitLandmarks (C++):
     decodificación, ROI → imagen, One Euro, pose, próximo ROI → kWaitRender
```

**Coordinación:** un único `stage_` atómico (`kIdle → kWaitRender → kGpu → kReady → kWaitRender`) con transiciones por CAS. Hay un solo recorte en vuelo y el último valor gana, así que no hace falta mutex en el camino caliente:

- en `kGpu` el buffer del recorte es del render;
- en `kReady`, del tracker.

Los landmarks filtrados pasan al render por un triple buffer lock-free. El único mutex es el de las stats, que no toma el render.

## 3. Espacios de coordenadas

- **Imagen:** frame derecho y **sin espejar**, en px de la salida (p. ej. 720×1280), con y hacia abajo. El tracker trabaja acá, así izquierda y derecha son anatómicas para P4/P5. El espejo se aplica solo al dibujar (`uImageToClip` en `face_mesh.vert`).
- **Recorte:** [0,1]² del tensor, con u a lo largo de la línea de los ojos (landmarks 33 → 263). Las conversiones están en `tracking/roi.h`; el shader de recorte usa `roiCropMatrix` más la `displayMatrix` sin espejo.
- **Malla canónica** (`cpp/mesh/canonical_mesh.h`, generada desde `third_party/mediapipe_face_geometry`): cm, y hacia arriba, z hacia la cámara. Para la pose, los landmarks se pasan a esa convención invirtiendo y y z.

## 4. Estabilización

| Pieza | Dónde | Parámetros (`engine_config.h`) |
|---|---|---|
| Detector + ROI desde la caja y los ojos | `blazeface_decoder.cpp`, `roi.cpp` | score ≥ 0,5, NMS ponderado IoU 0,3, ROI ×1,5 |
| Landmarks sobre el ROI del resultado anterior | `tracking_state.cpp` | presencia ≥ 0,5; si no, vuelve al detector |
| One Euro por coordenada (port 1:1 del informe) | `one_euro.h` | minCutoff 1,0, β 0,05, dCutoff 1,0; reinicio si pasan > 0,5 s |
| Extrapolación lineal acotada | `extrapolator.h` | ≤ 1,5 intervalos |
| Fundido al aparecer o perder la cara | `landmarksForRender` | 150 ms |
| Pose (Procrustes ponderado: cuaterniones de Horn) | `umeyama.cpp` | base de Procrustes de MediaPipe (33 puntos) |
| Jitter | `submitLandmarks` | desplazamiento medio 2D de los 33 puntos estables entre resultados |

Tests de host (`test_native/run_host_tests.cmd`, 28 tests):

- One Euro reproduce el informe: 0,42 px en reposo con ruido de 1 px y 1,91 px de retraso a 30 px/s.
- Umeyama recupera R, t y s conocidos.
- El decodificador encuentra una cara inyectada.
- Ciclo completo detector → landmarks → pérdida → stop con una cara sintética hecha con la malla canónica. La pose da ~0°.

## 5. Desviación de §4 del informe (aprobada con el plan de P3)

La inferencia corre en **Kotlin** (`CompiledModel` de LiteRT, la API que se midió en P1), no en C++:

- **Por qué:** el AAR de LiteRT trae `libLiteRt.so` pero no los headers de C/C++.
- **Qué quedó en C++, igual que en el informe:** recorte, decodificación, ROI, filtros, pose y render.
- **Cómo se cambia de modelo:** el contrato `IFaceTracker` es la interfaz Kotlin `FaceTracker`. Mientras el modelo nuevo respete la topología de FaceMesh (478 puntos), alcanza con otra implementación de `FaceTracker`.

**Costo aceptado:** `readFloat()` aloca la salida en cada inferencia (~6 KB para landmarks) en el hilo del tracker, no en el de render.

## 6. Cómo medir en el E20 (protocolo §11.5)

```bash
flutter run --profile -t lib/main_tracker.dart -d <id-del-E20>
```

Cada 5 s sale en logcat una línea `TRACK` con fps, CPU p95 del render, estado, Hz, ms de landmarks (p50/p95), ms del detector, readback, jitter, presencia, pose, corridas, pérdidas, init y backend.

```bash
adb logcat -s flutter | grep TRACK
```

| Prueba | Cómo | Objetivo |
|---|---|---|
| Render + tracker, 10 min | "Ver puntos" encendido, cara frente a la cámara | render ≥ 24 fps sostenido, tracker ≥ 15 Hz |
| Solo labios, 10 min | "Solo labios" con un preset | ídem; anotar diferencia de fps |
| Jitter estático | Teléfono apoyado frente a una **foto** de una cara (impresa o en otra pantalla): una persona nunca está quieta | `jitter` < 0,5 px |
| Recuperación | Sacar la cara del cuadro y volver | el estado vuelve a `tracking` en < 1 s; `losses` sube de a uno |
| Memoria y térmica | `dumpsys meminfo` al inicio y a los 10 min; `dumpsys battery` cada 2–3 min | sin crecimiento sostenido |
| Carga de modelos | `init` la primera vez vs. al reabrir | segunda vez mucho menor que 5,4 s |

### Resultados

| Prueba | Fecha | Render fps | Tracker Hz | Landmarks p50/p95 ms | Jitter px | Notas |
|---|---|---|---|---|---|---|
| Primera prueba con cara real (no es el protocolo completo) | 2026-10-12 | 28 | 15 | 22–26 (badge) | sin medir | Los puntos caen sobre la cara y la siguen. "Solo labios" con Rojo clásico pinta solo los labios. Landmarks más lentos que en P1 (16,9 ms con E/S): la GPU se comparte con el render |
| Con el labial de P4 (capturas, no el protocolo completo) | 2026-10-12 | 28–29 | 14 | 20–24 (badge) | sin medir | El labial de P4 no baja el render. Detalle en `LIPS.md` §6 |

**Palancas, en orden, si el render baja de 24 fps:**

1. `kTrackerMaxHz` a 15.
2. Detector en CPU (9 ms en P1).
3. Landmarks en CPU (~80 ms ≈ 12 Hz, con más extrapolación).

## 7. Revisiones de cierre (`perf-auditor` y `shader-reviewer`, 2026-10-12)

Ningún hallazgo crítico. Se corrigió:

- **Tracker trabado para siempre (alto):**
  - Si un recorte listo no se podía convertir en entrada, o las salidas del modelo tenían otro tamaño, el ciclo quedaba en `kReady`. Ahora `abortCrop` lo descarta y vuelve al detector.
  - Si `glFenceSync` devolvía null, el ciclo quedaba en `kGpu`. Ahora se trata como `cropFailed`.
  - Los recortes descartados se cuentan en `cropFailures` (línea `TRACK`): sirve para ver si la GPU compartida con LiteRT llega tarde.
- `request_` se lee recién con el stage tomado. La ventana restante es un `stop()+start()` justo en ese microsegundo y solo podría dar un ROI viejo durante un recorte.
- La máscara de labios no se reintenta en cada frame si su FBO falla.
- `TestFilterView` no crea el timer de stats si se desmontó durante el inicio.
- El tracker limpia el error al recuperarse.
- **Shaders:**
  - `tint_oklab` con máscara sale antes donde la máscara es 0: menos ALU y sin degradar sombras en fp16.
  - Precisión explícita de `uMask` y `vOutputUv`.
  - Los puntos se mezclan sin tocar el alpha del framebuffer (`glBlendFuncSeparate`).

Hecho en P4 (`LIPS.md`):

- Recorte de gamut del tinte: bisección de croma con L y tono fijos, en lugar del clamp por canal.
- Comisuras: máscara UV con borde difuminado sobre contornos suavizados, en lugar de la máscara de pantalla.

Sigue pendiente:

- Watchdog si el delegado GPU se cuelga en `run()`.

No se va a hacer: el protocolo completo de 10 minutos (jitter, memoria, térmica). Lo decidió el responsable del proyecto el 2026-10-12. Las mediciones del E20 quedan como las del badge en las capturas (§6 y `LIPS.md` §6).
