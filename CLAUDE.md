# CLAUDE.md — makeup_ar

App Flutter de maquillaje en realidad aumentada, en tiempo real, con motor AR propio (sin SDKs AR de terceros). Dispositivo de referencia: **Moto E20** (Unisoc T606, GPU Mali-G57 MP1, 2 GB de RAM, Android 11 Go). Si anda ahí, anda en todos.

## Idioma y estilo

- Respondé en español. Comentarios y mensajes de commit en español; identificadores en inglés.
- Directo y técnico: sin explicaciones básicas de Flutter. Código completo (método o bloque entero), nunca fragmentos con "..." que obliguen a adivinar llaves.

## Diseño del motor (leer solo cuando trabajes en AR o filtros)

El diseño completo está en `docs/ar_engine/motor_ar_propio.md`. No se importa a propósito: leelo con Read cuando haga falta. Resumen:

- Núcleo nativo (C++/OpenGL ES 3.0) en `packages/makeup_engine`: cámara → GPU → tracker → compositor → `Texture` de Flutter.
- Render y ML desacoplados: render a ~30 fps con la última malla + extrapolación; inferencia a 15–20 Hz en otro hilo.
- El maquillaje se pinta en espacio UV sobre la malla tracked (máscaras por región), mezclando en OKLab. No hay curvas Bézier por frame.
- Dart solo manda recetas JSON y lee métricas. Cero cruces por Dart por frame.
- Contrato: `IMakeupRenderer` con implementaciones `NativeGpuMakeupRenderer` y `MirrorFallbackRenderer` (respaldo: espejo sin maquillaje; el motor Dart viejo con ML Kit no volvió), elegidas por `--dart-define=AR_RENDERER=native|painter`.
- Tracker detrás de `IFaceTracker`: se puede cambiar el modelo de landmarks sin tocar nada más.

## Comandos

Son los estándar de Flutter; si algo cambia en el repo, corregilo acá.

- `flutter pub get` · `flutter analyze` · `flutter test`
- Medir rendimiento siempre en profile: `flutter run --profile -d <id>`. Nunca en debug.
- Regenerar i18n: `flutter gen-l10n` (usa `l10n.yaml`).
- Benchmark del tracker (LiteRT, GPU vs CPU; imagen sintética): `flutter run --profile -t lib/main_benchmark.dart -d <id>`. Resultados en pantalla y en logcat (`makeup_bench`).
- Renderer de maquillaje: `--dart-define=AR_RENDERER=native|painter` (por defecto native; `painter` = respaldo sin maquillaje, muestra el espejo con un aviso). Contrato en `lib/features/ar/domain/i_makeup_renderer.dart`.
- Arnés del tracker (P3; filtro de prueba sin Firebase, línea `TRACK` cada 5 s en logcat): `flutter run --profile -t lib/main_tracker.dart -d <id>`. Protocolo en `docs/ar_engine/TRACKER.md`. Botones "Foto" y "Paleta" (F4: foto de referencia → receta, foto de producto → paleta; líneas `PHOTO` y `PALETTE`), ver `docs/ar_engine/F4_PLAN.md`.
- Regenerar el mapa UV de labios (si cambia `tools/uv_masks/lips.json` o la malla): `python tools/uv_masks/gen_lips_maps.py`; `--check` verifica que lo versionado esté al día. Vista previa en `docs/ar_engine/img/lips_maps.png`.
- Regenerar los mapas UV de cara y ojos (base, contorno, iluminador, rubor, sombras, delineado; si cambia `tools/uv_masks/face.json` o la malla): `python tools/uv_masks/gen_face_maps.py`; `--check` igual que el de labios. Vistas previas en `docs/ar_engine/img/{face,eye}_maps.png`.
- Validar shaders (glslc del NDK; sintaxis y tipos, no reemplaza probar en el teléfono): `python tools/shaders/check_shaders.py`.
- Referencia Python del sombreado de labios (misma matemática que `lips.frag`): `python -m unittest discover -s tools/lips`.
- Grilla de calibración del maquillaje completo (cara sintética en UV con los mapas reales, 5 tonos de piel × presets, más piel media con luz cálida y fría): `python tools/makeup/calibration_grid.py` → `docs/ar_engine/img/face_calibration.png`.
- Referencia Python del compositor de capas (cara y ojos; misma matemática que `face.frag`/`eyes.frag` y `layerOver`): `python -m unittest discover -s tools/makeup`.
- Grilla de calibración del labial (5 tonos de piel × presets; ajustar `lumaFollow`/opacidad de los presets): `python tools/lips/calibration_grid.py` → `docs/ar_engine/img/lips_calibration.png`. Diseño en `docs/ar_engine/LIPS.md`.
- Regenerar la malla canónica (si cambia `packages/makeup_engine/third_party/mediapipe_face_geometry`): `python tools/mesh/gen_canonical_mesh.py`.
- Spike del motor nativo: `flutter run --profile -t lib/main_spike.dart -d <id>` (no carga Firebase ni RevenueCat).
- Tests del plugin: `flutter test` dentro de `packages/makeup_engine` (Dart) y `android/gradlew.bat :makeup_engine:testDebugUnitTest` (JVM; necesita `JAVA_HOME` apuntando al JBR de Android Studio).
- Tests de host del C++ del motor (matemática del tracker, sin GL; necesita Visual Studio con C++): `packages\makeup_engine\test_native\run_host_tests.cmd [filtro]`.
- Reglas de Firestore (emulador, sin dependencias npm; necesita `JAVA_HOME` al JBR de Android Studio): `firebase emulators:exec --only firestore --project demo-armakeup "node --test --test-reporter=tap firestore-tests/rules.test.mjs"`.
- Cloud Functions (`functions/`, Node 22 + TypeScript): `npm install` y `npm test` dentro de `functions/` (con la cuota contra el emulador: `npm run test:emulator`, necesita `JAVA_HOME` y java en el PATH). Deploy (lo corre el usuario): `firebase deploy --only functions --project armakeupapp`. Diseño y pasos en `docs/ar_engine/F2_PLAN.md`.
- App Check: `--dart-define=APP_CHECK=debug|playIntegrity` (por defecto debug fuera de release). Callables contra el emulador: `--dart-define=FUNCTIONS_EMULATOR=127.0.0.1:5001` + `adb reverse tcp:5001 tcp:5001`.
- Probar el Studio y "Mis looks" sin deploy (sin Blaze): `firebase emulators:start --only functions --project armakeupapp` (Enter en los dos parámetros). En el emulador el LLM es falso (`fake-emulator`; `#unavailable` en el prompt simula la caída) y App Check no se exige; Firestore y Auth son los reales. Pasos en `docs/ar_engine/F2_PLAN.md`.
- Paridad del esquema de recetas: `python tools/studio/validate_recipe_cases.py` (requiere `jsonschema`). Si tocás el esquema o `test/fixtures/recipe_v2_cases.json`, corré esto y `flutter test test/features`.
- QA automático del Studio (F5): `python tools/studio/qa_reference.py` regenera `test/fixtures/qa_render_cases.json` (`--check` verifica, `--report` muestra los valores de los presets para calibrar umbrales). Si cambia la matemática de los shaders o una constante de `engine_config.h`, regenerá y corré `flutter test test/features/studio`.
- Modelo propio (fase 3, solo infraestructura; sin datos ni entrenamiento): `python -m unittest discover -s tools/model` (necesita `torch`, `numpy` y `opencv-python`; ver `tools/model/requirements.txt`). Protocolo de datos en `tools/model/CONSENT.md` y pasos en `docs/ar_engine/MODEL.md`. Los datos viven fuera del repo.
- iOS (fase 4, OpenGL ES 3 de EAGL; mismo núcleo C++): si cambian las fuentes o los shaders del `CMakeLists.txt`, `python tools/ios/gen_ios_sources.py` (`--check` verifica). La rama iOS del C++ se compila sin Mac con `python tools/ios/check_ios_cpp.py` (NDK + shims; no compila Swift). Pasos en una Mac y checklist de paridad en `docs/ar_engine/IOS.md`.
- Referencia Python de la capa de iris: `python -m unittest discover -s tools/makeup` (incluye `iris_shading.py`).

## Reglas de código (Dart)

- Null-safety estricta. Nada de `!` sin comprobación previa en la misma función.
- Prohibido crear objetos pesados (Paint, Path, Shader, listas) dentro de `paint()` o de loops por frame.
- Cancelá en `dispose()` todo `StreamSubscription`, `Timer`, controller e `Isolate`.
- Los frames se descartan con una bandera tipo `_frameInFlight`; nunca se encolan.
- Arquitectura limpia, feature-first: `lib/features/<feature>/{domain,data,presentation}`. El dominio no depende de Flutter ni de Firebase.
- Código nuevo con tests. `flutter analyze` sin warnings antes de dar algo por terminado.

## Reglas del motor nativo y shaders

Las reglas detalladas se cargan solas desde `.claude/rules/` cuando tocás esos archivos. Lo esencial:

- GLES 3.0, cero allocations por frame en el hilo de render, un hilo dueño del contexto GL.
- GLSL ES 3.00, `mediump` por defecto, conversiones de color en un único include.
- Toda constante de rendimiento va en un único header de configuración.

## Recetas e IA (filtros)

- Un filtro es una receta JSON `makeup-recipe/2` validada contra `docs/ar_engine/recipe_v2.schema.json`. Nunca código ni shaders generados por IA.
- Todo lo que venga de un LLM se valida (esquema + rangos) en el servidor y en la app. Si no valida, se descarta y se usa un preset local.
- Ninguna API key dentro de la app. Los LLM se llaman desde Cloud Functions con Secret Manager, App Check, auth y cuota por usuario.
- Las fotos de referencia no se guardan: solo salen números.

## Seguridad y secretos

- No leas ni copies secretos. Si encontrás una key en el código o en el historial, reportá archivo, commit y tipo, sin pegar el valor, y recordame revocarla.
- No toques `.env`, `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `*.jks` ni `revenue_cat_keys.dart` (un hook lo bloquea). Usá `revenue_cat_keys.example.dart` como referencia.

## Cómo trabajar

- Plan primero (modo plan) en cualquier tarea que toque más de 2–3 archivos o cambie arquitectura.
- Una fase por rama o worktree, commits chicos, sin mezclar refactors con features.
- Medir antes de optimizar. No se acepta una "mejora de rendimiento" sin números del E20. Vos no podés correr nada en el teléfono: dejá el arnés y los comandos listos y pedime los resultados.
- Antes de cerrar una fase, usá los subagentes `perf-auditor` (rendimiento) y `shader-reviewer` (shaders).
- Si algo falla 2–3 veces con el mismo error: parás, resumís qué probaste y qué descartaste, y me lo decís.

## Parar y preguntarme antes de

- Agregar una dependencia (justificá licencia, tamaño y mantenimiento).
- Usar un modelo o dataset (licencia: muchos son solo para investigación, no comerciales).
- Modificar `firestore.rules`, cuotas o costos de servicios.
- Cambiar la arquitectura de §4 del informe o el esquema de recetas.

## No hacer

- No agregar SDKs AR de terceros (Banuba, DeepAR, Perfect Corp, etc.) ni otros motores 3D.
- No usar `startImageStream` del paquete `camera` para el camino AR nuevo: copia YUV a Dart.
- No procesar píxeles de cámara en Dart.
- No subir caras de usuarios a ningún servidor sin consentimiento explícito.

## Definición de terminado

1. `flutter analyze` y `flutter test` en verde (más tests de host C++ si aplica).
2. Sin allocations por frame en el camino caliente (verificado con `perf-auditor`).
3. Medición en el E20 anotada con el protocolo de `docs/ar_engine/motor_ar_propio.md` §11.5.
4. Documentación actualizada en `docs/ar_engine/` si cambió una decisión.
