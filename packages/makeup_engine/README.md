# makeup_engine

Plugin propio del motor AR (ver `docs/ar_engine/motor_ar_propio.md` en la raíz del repo).

- `android/src/main/cpp`: núcleo C++ (GLES 3.0): renderer, métricas, shaders embebidos desde `cpp/shaders/`.
- `android/src/main/kotlin`: cámara (Camera2), EGL, hilo de render y `SurfaceProducer` de Flutter.
- `lib/makeup_engine.dart`: API Dart (`start`, `stop`, `setTint`, `getStats`).

Estado: spike P1. Resultados en `docs/ar_engine/SPIKE_RESULTS.md`.
