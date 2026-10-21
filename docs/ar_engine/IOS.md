# Fase 4: iOS con OpenGL ES (port del motor)

Estado: **código escrito, sin compilar en Xcode ni probar en un iPhone** (se desarrolló desde Windows). El C++ de la rama iOS sí se verifica: compila con el NDK y shims de los headers de Apple. Falta que alguien con una Mac siga los pasos de abajo.

Decisión (2026-10-15): OpenGL ES 3 de EAGL en lugar de Metal. Apple lo marca deprecado desde iOS 12, pero sigue funcionando. Así el núcleo C++, los shaders, el tracker y el compositor son **los mismos** que en Android; con Metal había que reescribir el compositor y los shaders en MSL. Si Apple lo retira, el plan B es ANGLE (GLES sobre Metal), que es una dependencia y hay que consultarla antes.

## Arquitectura

| Android | iOS |
|---|---|
| Camera2 → `SurfaceTexture` (textura OES) | AVFoundation (BGRA, vertical, sin espejo) → `CVOpenGLESTextureCache` (textura 2D) |
| EGL + `SurfaceProducer` | `EAGLContext` ES3 → FBO propio → `glBlitFramebuffer` invertido a uno de 4 `CVPixelBuffer` (publicado cuando su fence está señalada) → `FlutterTexture.copyPixelBuffer` |
| LiteRT (GPU con caché, fallback CPU) | TensorFlowLiteSwift 2.17 (Metal, fallback CPU) |
| JNI (`jni_bridge.cpp`) | API C (`ios/Classes/engine_c_api.{h,cpp}`), misma superficie |
| Kotlin: `EngineSession`, `LiteRtFaceTracker`, `RecipeParams`, `StillImageAnalyzer`, `MakeupEnginePlugin` | Swift: mismos nombres en `ios/Classes/` |

**Núcleo C++:** no se movió. `tools/ios/gen_ios_sources.py` genera dos cosas:
- `ios/Classes/core/*.cpp`, un archivo por fuente de `android/src/main/cpp` que solo la incluye. CocoaPods no compila archivos fuera de la carpeta del pod, y no se usa un *unity build* porque los namespaces anónimos chocarían.
- `ios/Classes/generated/shader_sources.h`, igual que el paso de CMake.

La lista sale de `CMakeLists.txt`: si se agrega una fuente o un shader, hay que regenerar (`--check` avisa).

**Diferencias de plataforma dentro del núcleo** (todas en `gl_utils.h`, `gl_program.cpp` y `renderer.cpp`, detrás de `MAKEUP_PLATFORM_IOS`):
- **Headers y logging:** `OpenGLES/ES3` y `os_log`.
- **Textura de cámara:** `MAKEUP_CAMERA_TEXTURE` vale `GL_TEXTURE_2D` en iOS y `GL_TEXTURE_EXTERNAL_OES` en Android.
- **Shaders:** se quita `#extension GL_OES_EGL_image_external_essl3` y `samplerExternalOES` pasa a `sampler2D` al compilar. El GLSL sigue siendo uno solo.
- **Framebuffer de salida:** `Renderer::setOutputFramebuffer`, porque las pasadas de recorte y de escena dejan el 0. Al invalidar un FBO se usa `GL_COLOR_ATTACHMENT0`.
- **Cierre del frame:** en iOS el núcleo no presenta; lo hace la plataforma después del blit (fence + un solo `glFlush`).
- **Textura de cámara por frame:** `Renderer::setCameraTexture`, porque la caché crea una por frame.

Android no cambia de comportamiento: compila igual y pasan los tests de host, Kotlin y Flutter.

**Orientación:** la cámara entrega el buffer vertical y sin espejo. La matriz de textura invierte v, como la de `SurfaceTexture`, así el recorte del tracker y la malla quedan iguales que en Android. El espejo lo hace `displayMatrix` (rotación 0). El núcleo dibuja con la fila 0 abajo, como GL, y el blit invertido la deja arriba para Flutter: Dart no cambia.

**Modelos:** los mismos `.tflite` de Android. Una *script phase* del podspec los copia al bundle del pod al compilar, sin duplicarlos en el repo.

**Lo que no está en iOS:** `runBenchmark` (el benchmark de modelos es del E20) responde `unsupported`.

## Dependencia nueva

- `TensorFlowLiteSwift` y `TensorFlowLiteSwift/Metal` 2.17 (Apache 2.0, Google). Es el mismo runtime que LiteRT en Android, publicado como CocoaPod. Solo entra en el build de iOS.

## Verificación sin Mac (la corre Claude o cualquiera en Windows)

```
python tools/ios/gen_ios_sources.py --check
python tools/ios/check_ios_cpp.py
```

`check_ios_cpp.py` compila (solo sintaxis, con los mismos `-Werror` que Android) cada fuente del núcleo y la API C con `MAKEUP_PLATFORM_IOS` y shims (`tools/ios/shims`). Detecta errores de la rama iOS del C++. **No** compila Swift ni prueba nada en un iPhone.

## Pasos en una Mac (los corrés vos)

1. Xcode 15 o posterior y CocoaPods (`sudo gem install cocoapods`).
2. En la raíz del repo: `flutter pub get`, después `cd ios && pod install`. Si el `Podfile` no existe, lo crea `flutter build ios`. Hace falta `platform :ios, '13.0'` o más (Firebase ya lo pide).
3. Abrí `ios/Runner.xcworkspace`, elegí tu equipo de firma y conectá un iPhone (el simulador no tiene cámara frontal).
4. `flutter run --profile -t lib/main_tracker.dart -d <iphone>`: el arnés del tracker, con las líneas `TRACK` en la consola de Xcode.
5. Si algo no compila, mandame el error de Xcode tal cual: el Swift se escribió sin compilador.

## Checklist de paridad visual con Android (criterio de salida de la fase 4)

Con el arnés, en el iPhone y en el E20, con la misma luz:
- [ ] La imagen se ve derecha y espejada como en Android (levantar la mano derecha mueve la de la derecha de la pantalla).
- [ ] Los puntos ("Ver puntos") caen sobre la cara, también al girar la cabeza. Si salen invertidos verticalmente, la matriz de textura (`EngineSession.texMatrix`) está al revés.
- [ ] Cada preset (labial, rubor, sombras, delineado, pestañas, efectos, iris) se ve igual que en Android en la misma escena.
- [ ] La oclusión de labios con la mano funciona (`TRACK ... occl=`).
- [ ] "Desde foto" y "Paleta" del Studio devuelven valores parecidos a los de Android para la misma foto.
- [ ] 30 fps estables durante 10 minutos (líneas `TRACK`), sin crecimiento de memoria (Instruments → Allocations).
- [ ] Al salir y volver a entrar a la pantalla no queda la cámara tomada ni hay crash.
- [ ] Ajuste del arnés (2026-10-21, **Swift escrito sin compilador**): `setTrackerTuning` (One Euro, malla suave, borde real, contorno fino) en `engine_c_api` y Swift; la línea `TRACK` muestra `oneEuro=`, `contour=`. Verificar que compile y que los chips del arnés cambien la imagen como en Android.
- [ ] Guía de maquillaje (2026-10-21, **Swift escrito sin compilador**): `sampleLiveLook` (`makeup_look_sample_request`/`take`, cola `makeup-coach`, mismo lock que `makeup_destroy`) y voz con `AVSpeechSynthesizer` (`CoachVoice.swift`). Verificar: catálogo → look → "Guíame" mide y habla en español; sin voz instalada para el idioma, avisa y queda el texto.

## Revisión de cierre (`perf-auditor`, 2026-10-15)

Aplicado:
- **`stop()` durante el permiso de cámara:** antes, el inicio seguía y usaba el núcleo ya destruido. Ahora se cancela, y toda la limpieza de GL (`teardownGl`) se encola detrás de un `initGl` en curso, así libera lo que se haya llegado a crear.
- **Segundo plano:** al pasar a inactiva no se envía nada a la GPU (iOS mata la app si se hace). Se marca la pausa, el tracker se apaga, se espera el frame en curso con `glFinish` y la cámara se detiene. Al volver se reanuda. Las interrupciones y los errores de la sesión de cámara aparecen en `stats()["error"]`.
- **Textura de cámara:** `withExtendedLifetime` la mantiene viva hasta que se envían los comandos que la leen.
- **Buffers de salida:**
  - un solo `glFlush` por frame;
  - fence por buffer, y el buffer se publica al frame siguiente si ya está señalada, sin esperas;
  - 4 buffers, sin reusar el publicado, el pendiente ni uno tomado por otro proceso (`IOSurfaceIsInUse`).
- **Datos compartidos:** `textureId` bajo el mismo lock que `released`, una toma por frame. `textureFrameAvailable` se llama desde la cola de render, sin closure ni salto a main.
- **Parámetros de textura:** se fijan una vez por nombre de textura de la caché.
- **Fotos del Studio:** se decodifican con ImageIO ya reducidas, sin la foto entera en memoria.

Pendiente de medir (las reglas piden números antes de optimizar): dibujar directo en el `CVPixelBuffer` con el giro vertical en las matrices, sin el blit. Si la GPU del iPhone sobra, no hace falta.

## Riesgos conocidos

- **Pausa en segundo plano:** si hay una inferencia del tracker en curso en Metal al pasar a inactiva, termina igual; el tracker se apaga después.

- **OpenGL ES deprecado:** cada versión de iOS lo mantiene, pero sin mejoras. Vigilar avisos en las notas de Xcode.
- **TensorFlowLiteSwift 2.17:** Google está migrando a "LiteRT" también en iOS. Si el pod se retira, hay que cambiar el nombre del pod; la API Swift es la misma.
- **Swift sin compilar:** pueden aparecer errores de tipos menores (por ejemplo, cómo importa Swift los `enum` anónimos de C). Son de corrección directa.
