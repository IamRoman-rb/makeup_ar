# Migración del motor AR a DeepAR

## Contexto (estado actual verificado en el código)

- El "motor AR" hoy es 100% Dart: `camera` (feed de video) + `google_mlkit_face_mesh_detection`
  (malla oficial de 468 puntos) + un `CustomPainter` propio (`RealisticMakeupPainter` en
  `lib/camera_screen.dart`) que dibuja blush, sombra, delineador, labios y pestañas como
  paths/gradientes 2D sobre los puntos de la malla.
- La receta de maquillaje se genera en vivo con un prompt de texto vía la API de Groq
  (Llama 3) y también se puede cargar desde Firestore (`looks/{id}.makeup_recipe`, con
  conversión de un formato legacy `makeup_params`).
- `android/app/libs/deepar.aar` está en el repo pero **no está conectado a nada**: no hay
  dependencia en `build.gradle.kts`, ni `MethodChannel`, ni código Kotlin/Swift que lo use.
  Solo queda un comentario suelto en `android/build.gradle.kts:16`.
- `mediapipe_face_mesh` está en `pubspec.yaml` pero no se usa en ningún archivo de `lib/`.
- No existe `.xcframework` de DeepAR para iOS.

## Decisión de arquitectura (resuelve la tensión IA-prompt vs. efectos pre-armados)

DeepAR normalmente trabaja con efectos `.deepar` armados a mano en DeepAR Studio (editor
visual). Como el requisito es seguir generando el look **por prompt, sin usar un editor**,
la solución es un híbrido:

1. Se crea **una sola vez** (tarea de configuración, no repetida por el usuario final) un
   efecto base paramétrico `assets/ar_effects/makeup_base.deepar` con nodos/parámetros
   nombrados para cada feature: labios, blush, sombra de ojos, delineador, pestañas,
   base/glow.
2. El flujo de prompt → Groq/Llama3 → JSON de receta **se mantiene igual que hoy**.
3. En vez de pintar la receta con `CustomPainter`, se aplica sobre el efecto ya cargado
   llamando a `DeepArController.changeParameter(gameObject, component, parameter, valor)`
   por cada color/opacidad de la receta.

Esto preserva la experiencia actual del usuario (nada de editar efectos a mano) y suma el
motor de tracking/renderizado nativo de DeepAR.

## Fase 0 — Prerrequisitos (fuera del alcance de este agente, acción manual)

- [x] License keys de DeepAR generadas (Android e iOS) — cargadas en
      `lib/ar/ar_engine_config.dart`.
- [ ] Instalar DeepAR Studio y crear `makeup_base.deepar` con los nodos paramétricos
      descritos arriba (labios, blush, sombra, delineador, pestañas). **Sigue pendiente:
      es lo único que falta para poder activar `ArEngineConfig.useDeepAr = true`.**

## Fase 1 — Dependencias

- [x] Agregado `deepar_flutter: ^0.0.5` y `vector_math` a `pubspec.yaml`.
- [x] Sacado `mediapipe_face_mesh` de `pubspec.yaml` (confirmado sin uso).
- [x] Registrada la carpeta `assets/ar_effects/` en `pubspec.yaml` (con un README
      explicando qué va ahí).
- [x] `android/app/libs/deepar.aar` **se mantiene** — corrección a la suposición original:
      el propio módulo Gradle del plugin `deepar_flutter` (`:deepar:`) apunta a ese mismo
      archivo y falla si no está. Lo que sí había que evitar era declarar una dependencia
      Gradle manual duplicada sobre el mismo `.aar` (rompía con "Namespace 'ai.deepar.ar'
      is used in multiple modules") — no se agregó ninguna.
- [ ] El comentario "FIX NAMESPACE Y SDK PARA DEEPAR" en `android/build.gradle.kts:16` se
      dejó como está a propósito: fuerza `compileSdk`/`minSdk`/`targetSdk` en todos los
      subproyectos y lo siguen necesitando otros plugins viejos sin namespace propio (ej.
      `image_picker` 1.0.8), no es exclusivo de DeepAR.

## Fase 2 — Wiring nativo

- [x] Android: permiso de cámara ya estaba declarado. Se agregó
      `READ_EXTERNAL_STORAGE` (maxSdk 32) — `WRITE_EXTERNAL_STORAGE` no hizo falta
      agregarlo porque `camera_android_camerax` ya lo declara.
- [x] Android: license key cargada vía `DeepArController.initialize()` en
      `lib/ar/deepar_makeup_engine.dart` (no como meta-data de manifest).
- [x] iOS: `NSCameraUsageDescription`/`NSMicrophoneUsageDescription` ya estaban en
      `Info.plist`.
- [ ] iOS: **pendiente, requiere Mac.** Este repo nunca tuvo un `ios/Podfile` generado
      (no hay evidencia de que se haya corrido `pod install` nunca), y no se puede generar
      ni validar desde Windows. Cuando alguien abra el proyecto en Xcode/macOS por primera
      vez va a necesitar: `pod install`, agregar `GCC_PREPROCESSOR_DEFINITIONS` para
      `PERMISSION_CAMERA`/`PERMISSION_MICROPHONE` si el plugin lo pide, y confirmar el
      deployment target (DeepAR pide iOS 13+).

## Fase 3 — Capa Dart nueva (archivos creados)

- [x] `lib/ar/ar_makeup_engine.dart` — interfaz común (`initialize`, `buildPreview`,
      `applyRecipe`, `setEffectEnabled`, `dispose` vía `ChangeNotifier`).
- [x] `lib/ar/ar_engine_config.dart` — flag `useDeepAr` (en `false` hasta que exista el
      `.deepar`) + license keys + path del asset base.
- [x] `lib/ar/deepar_node_mapping.dart` — nombres de game objects/parámetros que el motor
      DeepAR espera encontrar en el efecto (placeholders a ajustar cuando exista el
      `.deepar` real).
- [x] `lib/ar/deepar_makeup_engine.dart` — implementación con `DeepArController`, carga
      `makeup_base.deepar` y traduce la receta a llamadas `changeParameter`.
- [x] `lib/ar/legacy_canvas_makeup_engine.dart` — cámara + ML Kit + `RealisticMakeupPainter`
      movidos tal cual acá, como motor de respaldo (es el que usa la app hoy, porque
      `useDeepAr = false`).
- [x] `lib/services/ai_makeup_recipe_service.dart` — extraída de `camera_screen.dart` la
      llamada a Groq, el armado del prompt y `MakeupRecipe` (default/legacy conversion).

## Fase 4 — Integración

- [x] `lib/camera_screen.dart` reescrito: ahora solo tiene UI (botones, caja de prompt) y
      delega al `ArMakeupEngine` elegido (`DeepArMakeupEngine` o `LegacyCanvasMakeupEngine`
      según `ArEngineConfig.useDeepAr`).

## Fase 5 — Verificación

- [x] `flutter analyze`: sin errores ni warnings nuevos (solo lints preexistentes de
      `withOpacity` deprecado, ya presentes antes de esta migración).
- [x] `flutter build apk --debug`: compila y linkea correctamente contra el `.aar` de
      DeepAR.
- [ ] **No probado en un dispositivo/emulador real** (no había ninguno conectado en esta
      sesión). Con `useDeepAr = false` el comportamiento visible debería ser idéntico al de
      antes de esta migración — igual conviene confirmarlo en un dispositivo.
- [ ] Probar en dispositivo iOS real (bloqueado por Fase 2 iOS).
- [ ] Una vez que exista `makeup_base.deepar` y se active `useDeepAr = true`: probar
      prompt → receta → DeepAR aplica el look en vivo, sin caídas de FPS ni crashes al
      rotar/pausar. Ajustar `deepar_node_mapping.dart` contra los nombres reales de los
      game objects.
- [ ] Confirmar que los looks guardados viejos en Firestore (`makeup_params` vía
      `MakeupRecipe.convertLegacy`) se siguen aplicando bien contra el motor DeepAR.

## Fase 6 — Limpieza (solo tras validar Fase 5 con `useDeepAr = true` en producción)

- [ ] Eliminar `lib/ar/legacy_canvas_makeup_engine.dart` y `google_mlkit_face_mesh_detection`
      de `pubspec.yaml` si nada más depende de la malla de puntos cruda.

## Riesgo/nota abierta

El código actual de Groq (`lib/camera_screen.dart`) manda
`'Authorization': 'Bearer'` sin ninguna clave — esa llamada tal cual está rota. Es un bug
preexistente, no forma parte de esta migración, pero hay que resolverlo (agregar la API key,
lo ideal vía variable de entorno o remote config, nunca hardcodeada en el repo) para que el
flujo de prompt funcione en cualquiera de los dos motores.
