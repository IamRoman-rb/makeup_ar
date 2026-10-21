# P3: tracker facial en vivo

Diseño del tracker (informe §5.2–5.3) tal como quedó implementado, la desviación respecto de §4 y cómo medirlo en el E20.

## 1. Qué hace

En el arnés del tracker (`lib/main_tracker.dart`, con todos los presets; desde 2026-10-16 la app ya no tiene el botón "Filtro de prueba" en el Espejo):

- **Solo labios** (por defecto): el labial de la receta sobre la malla tracked. Desde P4 es el labial fotorrealista (máscara UV, brillo, acabados): ver `LIPS.md`; desde P5, el look completo (cara y ojos): ver `FACE.md`. La máscara de pantalla provisional de P3 ya no existe.
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

## 8. Espejo con el motor, sin tracker (2026-10-16)

La pestaña Espejo es `TestFilterView(mirrorOnly: true)` sobre la misma sesión del motor.
- **Cómo se apaga el tracker:** `IMakeupRenderer.setTrackingEnabled(false)` lo pide antes de `start()`. Queda `TintRegion.full` con el tinte en 0, que es passthrough de la cámara, y `EngineSession` deja el tracker apagado. Los modelos se cargan recién la primera vez que se pide el filtro.
- **Al alternar:** solo se prende o se apaga el tracker y se manda la receta. Antes, el Espejo usaba el plugin `camera` y cada cambio cerraba y reabría la cámara: en el E20, CameraX tardaba 503 ms en abrir, más los 787 ms de carga de modelos.
- **Para verificar en el E20:**
  - al alternar no tienen que aparecer `Opening CameraId` ni `Closing Camera`;
  - en Espejo, el tracker figura apagado en las métricas.

**Cambio del 2026-10-16 (recorrido catálogo → filtro → tutorial):** el Espejo de la barra quedó solo cámara, sin el botón "Filtro de prueba" ni presets. El tracker se prende solo cuando se entra con un look:
- desde el catálogo, el paso a paso o "Mis looks", con `CameraScreen(initialLook:)`;
- se ve únicamente ese look, con intensidad y comparar (`TestFilterControls.intensity`);
- "Ver tutorial" (`onOpenTutorial`):
  - desde el catálogo hace `pushReplacement` al paso a paso, así la cámara se cierra antes de que arranque el video;
  - desde el paso a paso vuelve atrás.

Los presets se prueban en el arnés `main_tracker.dart`.

## 9. Precisión: ajuste del One Euro y malla suave (2026-10-20)

Más puntos detectados no se pueden pedir: FaceMesh-V2 da 478 fijos. Lo que se mejora es el temblor y la forma entre puntos.

### One Euro ajustable en vivo

- `kOneEuroMinCutoff` y `kOneEuroBeta` (`engine_config.h`) eran valores provisorios.
- En el arnés, "Ajuste" abre dos sliders que los cambian en vivo: `MakeupEngine.setTrackerTuning` → `TrackingState::setFilterTuning`, dos atómicos que el tracker copia en el próximo resultado.
- Menos `minCutoff` da menos temblor y más atraso; más `beta` da menos atraso al moverse.
- La línea `TRACK` suma `oneEuro=minCutoff/beta mesh=…`, y cada cambio deja una línea `TUNE`.
- Con las combinaciones medidas en el E20 (jitter quieta y atraso al mover la cabeza) se fijan los valores en `engine_config.h`.

### Malla suave

- **Cómo se arma:** cada triángulo se parte en 4 con un punto por arista (468 + 1365 = 1833 puntos).
  - Stencils fijos de `mesh/subdivided_mesh.h`, generados por `tools/mesh/gen_subdivided_mesh.py` (`--check`).
  - Interior: butterfly; borde de la cara: 4 puntos.
  - Pliegues en el contorno interno de los labios y en el de cada ojo: con la boca cerrada, la malla los cruza con triángulos finitos, y si el stencil los atravesara movería la comisura hacia el otro labio. Las cuerdas de la ranura quedan en el punto medio.
  - El esquema es interpolante: los landmarks no se mueven y el labial sigue llegando a las comisuras.
- **Tope:** el punto suave no se aparta del medio de su arista más que `kSmoothMeshMaxOffset` (15 %) del largo de la arista.
  - Una curva real muestreada cada 60° se corre ~13 %.
  - En la comisura externa (landmark 61, aristas de 0,65 y 0,13 cm) el esquema se pasaba al 64 %.
- **UV:** la de un punto nuevo es el punto medio de la arista. Así los mapas de labios, cara y ojos se curvan con la cara en pantalla en lugar de quebrarse en cada triángulo.
- **Sin cambios** en shaders ni mapas.
- **Costo por frame:** ~10 mil multiplicaciones en `uploadMesh` (arreglos fijos, hilo de render), un VBO de 1843 puntos (incluido el iris, al final, para el overlay) y 4 veces más triángulos en cada zona. Las listas se expanden una vez por contexto GL.
- **Modo apagado:** los puntos nuevos son el punto medio (misma imagen que la malla de 468). Por defecto apagada (`kSmoothMeshDefault`) hasta validarla en el E20 con el chip "Malla suave" del arnés.

### En el E20

- `flutter run --profile -t lib/main_tracker.dart -d <id>` → "Ajuste".
- Probar 2 o 3 combinaciones de sliders; para cada una, la línea `TRACK` quieta (jitter) y la sensación de atraso al girar.
- Prender y apagar "Malla suave" mirando de cerca comisuras, arco de cupido y delineado.
- Si mejora y fps/cpu no cambian, se prende por defecto.

## 10. Precisión: borde real del labial y segunda pasada sobre la boca (2026-10-21)

Son las opciones 3 y 4 de la tabla de precisión. Las dos vienen apagadas y se prenden con chips del arnés ("Ajuste" → "Borde real" y "Contorno fino") para compararlas en el E20.

### Opción 3: borde real del labial (`lips.frag`, `uEdgeRefine`)

- **Qué hace:** en ~0,85 mm alrededor del contorno externo (canal B del mapa < `EDGE_BAND`), la máscara pasa a ser "cuánto se parece este píxel al labio". Usa la misma proyección `p` de la cromaticidad sobre el eje piel → labio que aprendió la oclusión.
  - Donde la malla se pasó sobre la piel, el labial se retira.
  - Donde el labio real asoma afuera de la malla, el labial llega.
- **Dónde no actúa:**
  - en los píxeles oscuros (boca abierta, sombra de la comisura);
  - en los quemados (un reflejo en el borde tiene la croma lavada).
- **Fuerza:** sube con el contraste labio/piel. Entre `kOcclusionMinContrast` y el doble va de 0 a 1, así el borde no salta cuando aparece el eje. Sin eje (labio y piel parecidos) no hace nada.
- **Especificación y tests:** `tools/lips/lip_shading.py` (`refined_mask`, `edge_strength`) y `python -m unittest discover -s tools/lips`.
- **Vista previa:** `python tools/lips/edge_preview.py` → `docs/ar_engine/img/lips_edge_preview.png`. Labio sintético con la malla corrida 4 px, en 3 tonos de piel: cámara | malla (hoy) | borde real.
- **Costo:** ninguna lectura de textura nueva y ~15-20 operaciones en la franja. `p` y el sombreado se calculan una vez para el borde y para la oclusión.
- **Revisión del shader:** aplicados los hallazgos (reflejos, `p` una sola vez, franja apagada con fundido 0 o de espaldas, fuerza gradual).
- **A medir en el E20:** que el borde no parpadee con poca luz. Si parpadea, bajar `kLipEdgeRefineStrength` o subir `EDGE_LOW/HIGH`.

### Opción 4: segunda pasada sobre la boca (`tracking/lip_contour.h`)

- **Qué hace:** después de cada resultado del modelo, los 20 puntos del contorno externo de los labios (salvo las dos comisuras) se ajustan al borde real del color.
  - En el recorte de 256 que ya se leyó, se arma un perfil de `p` cada 0,5 px a lo largo de la normal, ±3 px.
  - Se interpola con precisión subpíxel el cruce de 0,5 (labio → piel) más cercano al punto del modelo.
  - Tope de 2 px y suavizado 1/4-1/2-1/4 entre vecinos.
  - Corre antes del One Euro, que sigue suavizando en el tiempo.
- **Sin modelo nuevo:** visión clásica sobre el mismo recorte, en el hilo del tracker (~15 Hz) y sin allocations.
- **Más resolución, si hace falta:** con la boca a ~75 px del recorte, la precisión subpíxel compensa. Si en el E20 no alcanza, el mismo algoritmo acepta un recorte dedicado de la boca a resolución de cámara (otro `CropPass`), sin cambiar la lógica.
- **Tests:** `test_native/lip_contour_test.cpp` (labio sintético: los puntos corridos 1,5 px vuelven al borde; sin eje o sin luz no hace nada; respeta el tope).
- **Métrica:** la línea `TRACK` muestra `contour=` (ajuste medio en px del recorte).

### Opción 5: modelo propio más denso

Ver `docs/ar_engine/MODEL.md` (fase 3). Hacen falta datos con consentimiento y entrenamiento; eso no se puede hacer sin vos (CLAUDE.md: usar datos o modelos requiere tu aprobación). La infraestructura queda preparada.
