# Licencias de terceros

**Fecha:** 2026-11-02. Las licencias de los paquetes de pub las junta Flutter y se ven en la app (Perfil > Privacidad y datos > Licencias de terceros, `showLicensePage`). Lo que no viene de pub se registra a mano en `main.dart` (`LicenseRegistry`).

## Dependencias directas (pub)

Leídas del archivo `LICENSE` de cada paquete en la caché local.

| Paquete | Versión | Licencia |
|---|---|---|
| camera | 0.12.0+2 | BSD-3-Clause |
| crypto | 3.0.8 | BSD-3-Clause |
| cupertino_icons | 1.0.9 | MIT |
| drift / drift_flutter | 2.35.3 / 0.3.1 | MIT |
| google_fonts | 8.2.1 | BSD-3-Clause (las fuentes Playfair Display e Inter: SIL OFL 1.1) |
| image_picker | 1.0.8 | BSD-3-Clause |
| intl | 0.20.3 | BSD-3-Clause |
| path / path_provider | 1.9.1 / 2.1.6 | BSD-3-Clause |
| permission_handler | 11.4.0 | MIT |
| purchases_flutter (RevenueCat) | 10.12.0 | MIT |
| sqlite3 / sqlite3_flutter_libs | 3.5.2 / 0.6.0+eol | MIT (SQLite: dominio público) |
| video_player | 2.14.0 | BSD-3-Clause |
| flutter_launcher_icons (solo desarrollo) | 0.14.4 | MIT |

Quitada en esta rama: `no_screenshot` (sin uso).

## Nativo y datos dentro del motor

| Componente | Licencia | Dónde | Visible en la app |
|---|---|---|---|
| Modelos MediaPipe Face Landmarker (`face_detector.tflite`, `face_landmarks_detector.tflite`) | Apache 2.0 | `packages/makeup_engine/third_party/mediapipe_face_landmarker/` | Sí (`assets/legal/apache-2.0.txt`) |
| Malla canónica MediaPipe face geometry | Apache 2.0 | `packages/makeup_engine/third_party/mediapipe_face_geometry/` | Sí (misma entrada) |
| LiteRT (`com.google.ai.edge.litert`) | Apache 2.0 | Gradle del plugin | No automáticamente: las licencias de dependencias Android no las junta Flutter. Agregar con el plugin de licencias de Google o a mano si el abogado lo pide |
| SDK nativo de RevenueCat (purchases-android / purchases-ios) | MIT | Transitivo de `purchases_flutter` | Ídem |

## A revisar (origen no documentado en el repo)

- `assets/app_icon.jpg`: autoría y derechos del ícono (Ley 11.723). `[COMPLETAR: origen y licencia]`.
- Portadas, imágenes de pasos y videos que cargue el admin en el catálogo: derechos de cada uno.
- Historial público del repo con `deepar.aar` y `makeup_base.deepar` (AUDIT.md §4.3): revisar la licencia de DeepAR.
