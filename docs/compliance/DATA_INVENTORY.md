# Inventario de datos y proveedores

**Fecha:** 2026-11-02 · **Rama:** `feat/privacy-release-prep` · **Alcance:** código de este repo (app Flutter, plugin `packages/makeup_engine`, configuración Android/iOS). No incluye la consola de RevenueCat, las tiendas ni servidores (no hay).

Documento técnico, no asesoramiento legal. Describe lo que hace el código hoy; si cambia el código, hay que actualizarlo (y la política en `assets/legal/`).

## 1. Arquitectura real

- La app **no tiene servidor propio ni Firebase en uso** (desde `24a3ac2`). Todo vive en una base SQLite local (`lib/shared/data/local_db/`, drift) dentro del almacenamiento privado de la app. `functions/`, `firestore.rules` y `firestore-tests/` son referencia para un servidor futuro: no se despliegan ni se llaman.
- Motor AR nativo propio (`packages/makeup_engine`, C++/OpenGL ES + LiteRT). Los modelos (`face_detector.tflite`, `face_landmarks_detector.tflite`) van dentro del APK; **el plugin no tiene código de red** (verificado: sin `INTERNET` propio, sin sockets/HTTP en `android/src` ni `ios/Classes`). LiteRT no descarga modelos: se quitaron los permisos de servicios en primer plano que declara para AI Packs (`packages/makeup_engine/android/src/main/AndroidManifest.xml`).
- No hay SDKs de analítica, publicidad, crash reporting ni atribución.

## 2. Flujo de cada dato

| Dato | Origen | Dónde se procesa / guarda | Sale del teléfono | Retención | Borrado | Código |
|---|---|---|---|---|---|---|
| Imagen de cámara en vivo | Cámara frontal (Camera2 / AVCapture) | GPU → tracker (landmarks) → compositor → textura. Nada se escribe a disco | No | Solo el frame en curso (memoria) | Automático | `EngineSession.kt`, `EngineSession.swift`, `test_filter_view.dart` |
| Landmarks / medidas de la Guía | Tracker | Memoria, durante la sesión de la Guía | No | Sesión | Automático | `lib/features/coach/` |
| Foto de referencia / de producto (Studio, solo admin interno) | Galería (`image_picker`) | Bytes en memoria → motor → números (colores Oklab, coberturas). La copia temporal del selector se borra al leerla | No | Ninguna (solo la receta resultante) | `discardPickedFile` | `studio_screen.dart`, `engine_image_analyzer.dart`, `lib/shared/data/picked_files.dart` |
| Foto de perfil | Galería (`image_picker`, máx. 1024 px) | Se re-codifica a PNG de máx. 512 px **sin metadatos** (EXIF/GPS) en `documents/profile_photos/<uid>-<ms>.png`. El temporal del selector se borra | No (salvo copia de seguridad del sistema, §4) | Mientras exista la cuenta | "Quitar foto", cambio de foto o borrado de cuenta (`deleteAllFor`) | `profile_photo_store.dart` |
| Email, nombre, fecha de nacimiento | Registro / Editar perfil | Tabla `users` | No | Mientras exista la cuenta | Borrado de cuenta (fila borrada de verdad) | `drift_auth_repository.dart` |
| Edad | Calculada de la fecha de nacimiento | Columna `users.age` (ya no se pide aparte) | No | Ídem | Ídem | `AgePolicy` |
| Contraseña | Registro / cambio | Hash PBKDF2-HMAC-SHA256 + sal + iteraciones; nunca en claro | No | Ídem | Ídem | `password_hasher.dart` |
| Tipo/tono de piel, gustos | Registro / Editar perfil | `users` | No | Ídem | Ídem | — |
| Looks guardados, Mis looks | Uso | `saved_looks`, `ai_looks` | No | Ídem | Cascada al borrar la cuenta | `tables.dart` |
| Borradores y looks publicados del Studio | Admin interno | `look_drafts`, `looks.created_by` | No | Ídem | Borradores: borrados; looks publicados: quedan sin autor | `deleteAccount` |
| Id de cuenta (UUID v4) | Generado | `users.id`; se manda a **RevenueCat** como `appUserID` | **Sí** (RevenueCat) | Según RevenueCat | `Purchases.logOut()` al borrar; borrado en RevenueCat: **pendiente** (§5) | `vip_service.dart` |
| Compras / estado VIP | Tienda → RevenueCat SDK | `users.premium_until` (caché local) | Sí (tienda, RevenueCat) | Según tienda y RevenueCat | Fila local al borrar la cuenta | `vip_service.dart`, `app_services.dart` |
| IP y datos técnicos | — | — | Sí: Google Fonts (descarga de fuentes en runtime), hosts de portadas/videos del catálogo, RevenueCat, tiendas | Según cada tercero | — | `google_fonts`, `look_cover.dart`, `step_by_step_screen.dart` |
| Logs | `debugPrint` | Logcat/consola **solo en debug y profile** (en release se silencian, `main.dart`); los mensajes de error ya no incluyen el detalle de la excepción | No | — | — | `main.dart` |

**Identificación de personas:** el análisis facial ubica 478 puntos y mide colores para dibujar maquillaje. No genera plantillas biométricas, no compara caras entre sí ni contra una base, y no guarda nada. No se trata, en términos técnicos, de identificación biométrica. Si el tratamiento debe calificarse jurídicamente como "dato biométrico" o "sensible" (Ley 25.326 art. 2) lo decide un abogado; el inventario da la evidencia técnica.

## 3. Permisos

| Plataforma | Permiso | Uso | Cuándo se pide |
|---|---|---|---|
| Android | `CAMERA` | Maquillaje en vivo, Guía, vista previa del Studio | Al abrir la cámara, con explicación previa (`camera_permission_gate.dart`); si se niega no se insiste en la sesión y se ofrece "Permitir cámara"/"Abrir ajustes" |
| Android | `INTERNET`, `BILLING` y los que agreguen los plugins | RevenueCat/Billing, fuentes, imágenes del catálogo | Instalación (no son runtime) |
| Android | ~~`RECORD_AUDIO`~~ | Quitado: nadie graba audio | — |
| Android | Fotos | `image_picker_android 0.8.13+19` abre el selector de documentos del sistema (`useAndroidPhotoPicker` en false): no declara ni pide permiso de almacenamiento (verificado en su manifest) | — |
| iOS | `NSCameraUsageDescription` | Ídem cámara | El motor (`EngineSession.swift`) con el diálogo del sistema |
| iOS | `NSPhotoLibraryUsageDescription` | Foto de perfil y fotos del Studio | Selector del sistema |
| iOS | ~~`NSMicrophoneUsageDescription`~~ | Quitado | — |

## 4. Copias de seguridad del sistema

Android (Auto Backup, `allowBackup` por defecto) e iCloud pueden incluir la base y la foto de perfil en la copia del usuario, bajo su cuenta de Google o Apple. Se dejó activo porque sin servidor es la única forma de no perder la cuenta al cambiar de teléfono, y se declara en la política. **Decisión del operador** (checklist): mantenerlo, excluir la base (`dataExtractionRules`) o desactivarlo.

## 5. Proveedores

| Proveedor | Para qué | Datos | Configuración | Pendiente |
|---|---|---|---|---|
| RevenueCat, Inc. | Estado de la suscripción VIP | `appUserID` (UUID aleatorio, sin email ni nombre), recibos, datos técnicos del dispositivo | Key pública por `--dart-define-from-file=env/revenuecat.json` | Contrato/DPA y transferencia internacional (art. 12 Ley 25.326); procedimiento para borrar el `appUserID` (API REST `DELETE /v1/subscribers/{id}` con la secret key, **solo desde un servidor**) |
| Google Play Billing / App Store | Cobro | Los que trate cada tienda | Consola de cada tienda | Formularios de Data Safety / App Privacy (§6) |
| Google Fonts | Tipografías Playfair Display e Inter (OFL) | IP, user agent | `google_fonts` con descarga en runtime | Empaquetar las fuentes y `GoogleFonts.config.allowRuntimeFetching = false` para que no haya llamada a Google (suma ~1 MB al APK: decidir) |
| Hosts de imágenes/videos del catálogo | Contenido de looks cargado por el admin | IP | URLs en la tabla `looks` | Hoy el catálogo sembrado no tiene URLs; si se agregan, alojar en infraestructura propia o declarada |

## 6. Para los formularios de las tiendas (borrador, a validar)

- **Google Play – Data Safety:** datos "recopilados" (enviados fuera del teléfono): identificadores de la app/compras (RevenueCat), historial de compras. Datos de la cuenta, fotos y cara: procesados solo en el teléfono (Google no los considera "recopilados" si no salen del dispositivo). Cifrado en tránsito: sí (HTTPS de RevenueCat/tiendas). Borrado: in-app; para datos en RevenueCat, por email al responsable (pendiente de URL pública de solicitud de borrado, que Play exige).
- **Apple – App Privacy:** "Purchases" e "Identifiers (User ID)" vinculados al usuario, para funcionalidad de la app; sin tracking.
- La URL pública de la política de privacidad la tiene que publicar el operador (las tiendas no aceptan un texto solo dentro de la app).
