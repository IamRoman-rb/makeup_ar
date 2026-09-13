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

- [ ] Crear cuenta en DeepAR y generar license keys para:
  - Android, `applicationId = com.example.ar_makeup_app`
  - iOS, bundle id del proyecto (`ios/Runner.xcodeproj`)
- [ ] Instalar DeepAR Studio y crear `makeup_base.deepar` con los nodos paramétricos
      descritos arriba (labios, blush, sombra, delineador, pestañas, base/glow).

## Fase 1 — Dependencias

- [ ] Agregar `deepar_flutter` (paquete oficial) a `pubspec.yaml`.
- [ ] Quitar `mediapipe_face_mesh` de `pubspec.yaml` (confirmado sin uso).
- [ ] Registrar `assets/ar_effects/makeup_base.deepar` en la sección `assets:` de
      `pubspec.yaml`.
- [ ] Decidir el destino de `android/app/libs/deepar.aar`: eliminarlo si el plugin
      `deepar_flutter` trae su propia resolución del SDK nativo, o actualizarlo si el
      plugin todavía requiere vendorizarlo a mano (confirmar contra la doc de la versión
      instalada).
- [ ] Limpiar el comentario/workaround "FIX NAMESPACE Y SDK PARA DEEPAR" en
      `android/build.gradle.kts:16` si deja de ser necesario con el plugin oficial.

## Fase 2 — Wiring nativo

- [ ] Android: confirmar que `AndroidManifest.xml` declara el permiso de cámara y que
      `minSdk`/`compileSdk`/NDK en `android/app/build.gradle.kts` cumplen los mínimos de
      DeepAR.
- [ ] Android: agregar la license key de DeepAR según lo pida el plugin (meta-data en
      manifest o init en Dart).
- [ ] iOS: confirmar `NSCameraUsageDescription` en `ios/Runner/Info.plist`.
- [ ] iOS: agregar la license key de DeepAR y el `.xcframework`/pod que instale el plugin
      vía `pod install`.
- [ ] iOS: subir el deployment target si DeepAR lo requiere.

## Fase 3 — Capa Dart nueva (archivos a crear)

- [ ] `lib/ar/ar_makeup_engine.dart` — interfaz común (`initialize`, `startCamera`,
      `applyRecipe(Map recipe)`, `dispose`, widget de preview).
- [ ] `lib/ar/deepar_makeup_engine.dart` — implementación con `DeepArController`, carga
      `makeup_base.deepar` y traduce la receta a llamadas `changeParameter`.
- [ ] `lib/ar/legacy_canvas_makeup_engine.dart` — mueve ahí tal cual el código actual de
      cámara + ML Kit + `RealisticMakeupPainter`, como motor de respaldo.
- [ ] `lib/services/ai_makeup_recipe_service.dart` — extrae de `camera_screen.dart` la
      llamada a Groq y el armado del prompt (lógica de negocio, no de UI).

## Fase 4 — Integración (archivos a modificar)

- [ ] `lib/camera_screen.dart` — se reduce a UI (botones, caja de prompt) y delega
      inicialización/renderizado al `ArMakeupEngine` elegido, en vez de tener la cámara,
      ML Kit y el painter inline.

## Fase 5 — Verificación

- [ ] Probar en dispositivo Android real: prompt → receta → DeepAR aplica el look en vivo,
      sin caídas de FPS ni crashes al rotar/pausar la app.
- [ ] Probar en dispositivo iOS real, mismo checklist.
- [ ] Confirmar que los looks guardados viejos en Firestore (`makeup_params` vía
      `MakeupRecipe.convertLegacy`) se siguen aplicando bien contra el nuevo motor.

## Fase 6 — Limpieza (solo tras validar Fase 5)

- [ ] Eliminar `lib/ar/legacy_canvas_makeup_engine.dart` y `google_mlkit_face_mesh_detection`
      de `pubspec.yaml` si nada más depende de la malla de puntos cruda.
- [ ] Actualizar este checklist marcando lo completado.

## Riesgo/nota abierta

El código actual de Groq (`lib/camera_screen.dart`) manda
`'Authorization': 'Bearer'` sin ninguna clave — esa llamada tal cual está rota. Es un bug
preexistente, no forma parte de esta migración, pero hay que resolverlo (agregar la API key,
lo ideal vía variable de entorno o remote config, nunca hardcodeada en el repo) para que el
flujo de prompt funcione en cualquiera de los dos motores.
