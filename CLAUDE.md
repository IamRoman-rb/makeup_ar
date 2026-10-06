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
- Contrato: `IMakeupRenderer` con implementaciones `NativeGpuMakeupRenderer` y `CustomPainterMakeupRenderer` (respaldo), elegidas por `--dart-define=AR_RENDERER=native|painter`.
- Tracker detrás de `IFaceTracker`: se puede cambiar el modelo de landmarks sin tocar nada más.

## Comandos

Son los estándar de Flutter; si algo cambia en el repo, corregilo acá.

- `flutter pub get` · `flutter analyze` · `flutter test`
- Medir rendimiento siempre en profile: `flutter run --profile -d <id>`. Nunca en debug.
- Regenerar i18n: `flutter gen-l10n` (usa `l10n.yaml`).
- Paridad del esquema de recetas: `python tools/studio/validate_recipe_cases.py` (requiere `jsonschema`). Si tocás el esquema o `test/fixtures/recipe_v2_cases.json`, corré esto y `flutter test test/features`.

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
