# Matriz legal-técnica y hallazgos

**Fecha:** 2026-11-02 · **Rama:** `feat/privacy-release-prep`

Contrasta el código con normas argentinas y políticas de las tiendas. **No es asesoramiento legal ni una declaración de cumplimiento**: identifica controles técnicos y deja marcado lo que tiene que interpretar un abogado argentino (`[REVISAR]` en los textos de `assets/legal/`).

## 1. Marco

### Obligatorio (según el caso)

| Norma | Qué toca en esta app | Control técnico | Estado |
|---|---|---|---|
| Ley 25.326 y Decreto 1558/2001 (datos personales) | Cuentas locales, perfil, foto; id enviado a RevenueCat | Información al titular (art. 6): política in-app + aceptación en el registro. Minimización (art. 4): sin campo "Edad" duplicado, foto achicada sin EXIF. Acceso (art. 14): "Copiar mis datos". Rectificación (art. 16): Editar perfil, Quitar foto. Supresión (art. 16): borrado completo. Seguridad (art. 9): hash de contraseñas, almacenamiento privado, logs silenciados en release | Implementado en código; textos en **borrador** |
| Ley 25.326 art. 2 (datos sensibles) | Tono de piel (¿origen étnico?) | Campo opcional y editable; se declara en la política con `[REVISAR]` | **Decisión legal** |
| Ley 25.326 art. 12 (transferencia internacional) | RevenueCat, Inc. | Solo se manda un UUID aleatorio, sin email ni nombre | **Pendiente legal/contractual** |
| Ley 25.326 art. 21 / normativa AAIP (registro de bases) | Base de usuarios | Leyenda de la AAIP incluida en la política, marcada `[REVISAR]` | **Pendiente del operador** (¿inscripción? la base está en los teléfonos, no en el operador: lo define el abogado) |
| Código Civil y Comercial arts. 52–53 (imagen) | Cámara, fotos de referencia | Nada se graba ni se comparte; aviso de usar fotos propias o con permiso (Studio, términos) | Implementado |
| CCyC art. 26 y Ley 26.061 (menores) | Registro abierto a cualquier edad | `LEGAL_MINIMUM_AGE` aplicado en el registro; sin valor no bloquea | **Bloqueo**: el operador define la edad con un abogado |
| Ley 24.240 art. 4 (información) y art. 10 | Paywall VIP | Precio con período, prueba gratis / precio de introducción, renovación automática, cómo cancelar, enlaces a términos/privacidad | Implementado |
| Ley 24.240 art. 34; Res. SCI 424/2020 (botón de arrepentimiento); Res. SC 316/2018 (botón de baja) | Suscripción por tienda | "Gestionar o cancelar suscripción" en Perfil > Privacidad y datos y en el paywall | Implementado parcialmente; **aplicabilidad a compras in-app: decisión legal** |
| Ley 24.240 art. 37 (cláusulas abusivas) | Términos | Sin cláusulas de exoneración redactadas; sección marcada `[REVISAR]` | **Pendiente legal** |
| DNU 274/2019 (lealtad comercial, publicidad) | Promesa del VIP | Titular cambiado a "los tutoriales que los incluyen". El catálogo sembrado **no tiene videos**: vender VIP así sería engañoso | **Bloqueo** (H3) |
| Ley 11.723 y licencias | Modelos MediaPipe, fuentes, ícono, contenido | Apache 2.0 de MediaPipe visible en "Licencias de terceros"; inventario en `THIRD_PARTY_LICENSES.md` | Parcial: ícono y contenido sin origen documentado |
| Requisitos tributarios/comerciales | Cobro | Lo cobra la tienda; datos fiscales del operador no están en el repo | **Operador** |

### Políticas de las tiendas (requisitos técnicos)

| Política | Control | Estado |
|---|---|---|
| Google Play: permisos mínimos y en contexto | Sin `RECORD_AUDIO`; cámara pedida al usarla con explicación | Implementado |
| Google Play: borrado de cuenta in-app y por web | In-app sí. **La URL web de solicitud de borrado la exige Play** | In-app implementado; URL **pendiente del operador** |
| Google Play: Data Safety | Borrador en `DATA_INVENTORY.md` §6 | Pendiente de cargar en la consola |
| Google Play: target API, firma, applicationId | Release exige `android/key.properties` y bloquea `com.example.*` | Corte implementado; **ID y keystore del operador** |
| Apple 5.1.1(v): borrado de cuenta in-app | Implementado | — |
| Apple 3.1.2: suscripciones (título, duración, precio, enlaces) | Implementado en el paywall; **falta el enlace a la EULA en App Store Connect** | Parcial |
| Apple 5.1.1 / privacy manifest (`PrivacyInfo.xcprivacy`) | No existe (hace falta Xcode) | **Pendiente** (`IOS.md`) |
| Apple 2.1: completitud | VIP sin contenido | **Bloqueo** (H3) |

### Voluntario (no son requisito de publicación; no se encontró obligación contractual ni normativa)

| Marco | Uso sugerido |
|---|---|
| ISO/IEC 27001 / 27017 / 27018 | Referencia para cuando haya servidor (hoy no hay infraestructura cloud propia) |
| ISO/IEC 27701 / 29100 | Principios de privacidad usados como guía: minimización, limitación de finalidad, transparencia |
| ISO/IEC 25010 | Calidad: los tests (307) y `flutter analyze` sin warnings cubren mantenibilidad/fiabilidad básicas |
| ISO/IEC 40500 (WCAG 2.0) | Referencia de accesibilidad: semántica de botones, contraste, escalado de texto en pantallas nuevas |

## 2. Hallazgos

Severidad: Alta = impide publicar o expone a usuarios; Media = incumplimiento probable de política o norma; Baja = mejora.

| # | Sev. | Hallazgo | Evidencia | Estado | Cambio |
|---|---|---|---|---|---|
| H1 | Alta | La primera cuenta de cada teléfono era admin → Studio, editor y videos VIP gratis para cualquiera | `drift_auth_repository.dart` (`isFirst`), `app_user.dart` (`canSeePremiumAt`) | **Corregido** | `LocalAdminPolicy`: admin local solo en debug/profile o `--dart-define=LOCAL_ADMIN=true`; se aplica al crear y al leer (una base de un build interno no da privilegios en uno de tienda). Tests en `drift_auth_repository_test.dart` |
| H2 | Alta | Paywall sin período, renovación, oferta ni cómo cancelar | `vip_paywall_screen.dart` | **Corregido** | `SubscriptionTerms`, `subscription_texts.dart`, aviso de renovación, enlaces, `ManageSubscriptionScreen`. Tests en `test/features/vip/` |
| H3 | Alta | VIP no desbloquea nada en una instalación nueva | `catalog_seed.dart` sin `video_url` | **Pendiente (operador)** | Titular corregido; queda como bloqueo |
| H4 | Alta | Sin política, términos ni aceptación | — | **Parcial** | Borradores en 4 idiomas (`assets/legal/`), `LegalInfo` por `--dart-define`, casilla obligatoria, banner BORRADOR. Faltan datos del responsable y revisión legal |
| H5 | Media | Borrado incompleto (borradores, `created_by`, fotos viejas, RevenueCat) y errores confusos | `deleteAccount`, `account_settings_screen.dart` | **Corregido en lo alcanzable** | Transacción + `AccountDeletion` (fotos, `logOut`), mensajes por resultado, aviso de que no cancela la suscripción. Borrado en RevenueCat: pendiente de servidor |
| H6 | Media | Foto de perfil con EXIF/GPS y a resolución completa; temporales del selector; sin "Quitar foto" | `profile_photo_store.dart` (copiaba el archivo) | **Corregido** | Re-codificación PNG ≤ 512 px, `discardPickedFile`, "Quitar foto", `ResizeImage` en avatares. Tests en `profile_photo_store_test.dart` |
| H7 | Media | Android: el motor nunca pedía el permiso de cámara (fallaba y caía al respaldo; la Guía quedaba "no disponible") | `EngineSession.kt` (SecurityException) | **Corregido** | `camera_permission_gate.dart` integrado en `TestFilterView`. Tests en `camera_permission_gate_test.dart`. **Probar en el E20** |
| H8 | Media | Permisos de micrófono sin uso; falta descripción de fotos en iOS | `AndroidManifest.xml`, `Info.plist` | **Corregido** | — |
| H9 | Media | Release firmado con la key de debug; `com.example.*` | `build.gradle.kts` | **Parcial** | Firma desde `key.properties` y corte de `bundleRelease`/`assembleRelease` (probado con `--dry-run`). ID definitivo: operador |
| H10 | Media | Interruptores de notificaciones y boletín que no hacían nada | `account_settings_screen.dart` | **Corregido** | Sección quitada y claves borradas de los ARB |
| H11 | Media | `functions/.env.local` sin trackear y sin ignorar (no se leyó su contenido); `android/app/google-services.json` (API key de Firebase, desde `51ccdd7`) versionado aunque Firebase ya no se usa | `git status`, `git log` | **Parcial** | `.gitignore` cubre `functions/.env*`. El resto, en el checklist (no se tocaron archivos protegidos) |
| H12 | Baja | `debugPrint` con detalles de excepciones en release | varios | **Corregido** | Silenciado en release; mensajes con `runtimeType` y sin `$e` en pantalla en los flujos tocados |
| H13 | Baja | "Edad" libre además de la fecha; sin edad mínima | `signup_screen.dart` | **Parcial** | Campo quitado, edad calculada, `AgePolicy`. Valor de la edad: operador |
| H14 | Baja | Google Fonts en runtime | `google_fonts` | **Pendiente (decisión)** | Declarado en la política |
| H15 | Baja | Dependencia sin uso (`no_screenshot`); `flutter_launcher_icons` en dependencias | `pubspec.yaml` | **Corregido** | — |
| H16 | Baja | Accesibilidad: avatar/filas sin semántica, contraste bajo | `profile_screen.dart`, `account_settings_screen.dart` | **Parcial** | Semántica y `InkWell` en filas, contraste del texto de borrado. Revisión completa con TalkBack/VoiceOver: pendiente |
| H17 | Info | `firestore.rules` y functions | AUDIT.md §5 | Sin cambios | No se usan; CLAUDE.md exige confirmación para tocarlas |
| H18 | Info | Copia de seguridad del sistema | `AndroidManifest.xml` | Decisión del operador | Declarado en la política |
| H19 | Info | iOS sin privacy manifest ni Podfile | `ios/` | Pendiente (Mac) | `IOS.md` |
