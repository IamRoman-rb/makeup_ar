# Checklist de publicación (Argentina, Android e iOS)

**Fecha:** 2026-11-02 · Ver también `DATA_INVENTORY.md` y `LEGAL_MATRIX.md`.

Nada de esto se hizo de forma remota: no se desplegó nada, no se publicó la app ni se tocaron consolas.

## 1. Bloqueos (no publicar hasta resolverlos)

| # | Bloqueo | Qué hacer | Dónde |
|---|---|---|---|
| B1 | Datos del responsable vacíos: los textos legales muestran `[COMPLETAR: …]` y el banner BORRADOR | Completar `env/legal.json` (copiar de `env/legal.example.json`) y compilar con `--dart-define-from-file=env/legal.json` además del de RevenueCat | §2 |
| B2 | Textos legales sin revisión de un abogado argentino (todos los `[REVISAR: …]` de `assets/legal/*.md`) | Revisión legal; reemplazar los `[REVISAR]` por el texto final en los 4 idiomas; recién ahí `LEGAL_REVIEWED=true` | `assets/legal/` |
| B3 | Edad mínima sin definir: el registro no bloquea a nadie | Definirla con un abogado → `LEGAL_MINIMUM_AGE` | `env/legal.json` |
| B4 | El VIP no desbloquea nada en una instalación nueva (los looks sembrados no tienen video) | Cargar contenido VIP real, o no ofrecer el VIP en el lanzamiento (no configurar la offering en RevenueCat). Completar el `[COMPLETAR: contenido incluido en el VIP]` de los términos | `catalog_seed.dart`, RevenueCat |
| B5 | `applicationId` / bundle id `com.example.*` | Elegir el definitivo y cambiarlo en `android/app/build.gradle.kts` (`namespace` y `applicationId`) e `ios/Runner.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`) | — |
| B6 | Sin keystore de release | Crear la keystore (fuera del repo) y `android/key.properties` con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Activar Play App Signing | `android/` |
| B7 | Sin URL pública de política de privacidad ni de solicitud de borrado de cuenta (las exigen Play y App Store) | Publicar el texto final en una web del operador y cargar las URLs en las consolas | Consolas |
| B8 | Formularios Data Safety (Play) y App Privacy (Apple) | Cargar con el borrador de `DATA_INVENTORY.md` §6, revisado | Consolas |
| B9 | iOS sin `PrivacyInfo.xcprivacy`, sin `PERMISSION_CAMERA=1` en el Podfile y textos de permisos solo en español | Pasos en `docs/ar_engine/IOS.md` (necesita una Mac) | `ios/` |
| B10 | Probar en el E20 el permiso de cámara nuevo, la foto de perfil re-codificada (orientación EXIF) y el borrado de cuenta | Recorrido del §5 | Teléfono |

## 2. Datos que tiene que completar el operador

Todo va en `env/legal.json` (no es secreto; se puede versionar si se quiere). Cada campo vacío aparece como `[COMPLETAR: …]` en la app.

| Campo (`--dart-define`) | Qué es | Dónde aparece |
|---|---|---|
| `LEGAL_CONTROLLER_NAME` | Razón social o nombre del responsable | Política, términos |
| `LEGAL_CONTROLLER_TAX_ID` | CUIT | Política, términos |
| `LEGAL_CONTROLLER_ADDRESS` | Domicilio legal | Política, términos |
| `LEGAL_PRIVACY_EMAIL` | Email para derechos de datos personales | Política, Privacidad y datos |
| `LEGAL_SUPPORT_CONTACT` | Soporte y reclamos de consumo | Política, términos |
| `LEGAL_JURISDICTION` | Ley aplicable y jurisdicción (abogado) | Términos |
| `LEGAL_EFFECTIVE_DATE` | Fecha de vigencia | Política, términos |
| `LEGAL_MINIMUM_AGE` | Edad mínima (entero; 0 = sin definir) | Registro, política, términos |
| `LEGAL_REVIEWED` | `true` solo después de la revisión legal | Quita el banner BORRADOR |

Además, en los textos (no son campos): plazo y procedimiento de borrado en RevenueCat (`privacy_*.md`), contenido del VIP (`terms_*.md`).

## 3. Decisiones pendientes del operador

- **Copia de seguridad de Android/iCloud** (`DATA_INVENTORY.md` §4): mantener (hoy), excluir la base o desactivar.
- **Google Fonts**: empaquetar Playfair Display e Inter (SIL OFL 1.1) en `assets/google_fonts/` y poner `GoogleFonts.config.allowRuntimeFetching = false` en `main.dart` para no llamar a Google; suma tamaño al APK (medir en el E20).
- **`url_launcher`** (BSD-3, del equipo de Flutter): permitiría abrir la gestión de la suscripción y la política web desde la app. Hoy se muestran los pasos y el enlace para copiar, para no agregar dependencias sin aprobación (CLAUDE.md).
- **Tono de piel**: si el abogado lo considera dato sensible, pasar a opcional explícito (sin valor por defecto) y consentimiento específico.
- **Registro de la base ante la AAIP**: lo define el abogado.

## 4. Pasos remotos (no ejecutados)

- RevenueCat: offering con productos reales; DPA; procedimiento de borrado por API desde un servidor.
- Play Console: ficha, Data Safety, URL de política y de borrado, clasificación de contenido, público objetivo y edad.
- App Store Connect: App Privacy, EULA o términos propios en la descripción, URL de política, clasificación por edad.
- Google Cloud: el proyecto de Firebase de `android/app/google-services.json` ya no se usa. Sacar el archivo del repo (`git rm --cached android/app/google-services.json` y agregarlo a `.gitignore`) y **restringir o rotar la API key** en Google Cloud Console. El archivo está protegido por el hook del repo y no se modificó.
- `functions/.env.local`: quedó ignorado por `.gitignore`. Si contiene una key real, **revocarla** (no se leyó su contenido).
- Historial del repo público con `deepar.aar` (AUDIT.md §4.3): revisar la licencia de DeepAR.

## 5. Recorrido manual en el E20 (profile)

`flutter run --profile -d <id> --dart-define-from-file=env/revenuecat.json --dart-define-from-file=env/legal.json`

1. Instalación limpia → Registro: la casilla de aceptación es obligatoria; los enlaces abren los borradores; con `LEGAL_MINIMUM_AGE` definida, una fecha menor bloquea.
2. Foto de perfil: elegir una foto vertical de la cámara (con ubicación) → se ve derecha; Perfil > Privacidad y datos > "Copiar mis datos" no muestra la ruta. Comprobar con `adb shell run-as <paquete> ls files/profile_photos` que el archivo es `.png`.
3. Catálogo → Probar en AR: aparece "Acceso a la cámara" antes del diálogo del sistema. Probar "Ahora no" → vista con "Permitir cámara"; negar dos veces → "Abrir ajustes". Repetir en la Guía.
4. Paywall: cada plan muestra precio con período y, si hay, la prueba gratis; abajo el aviso de renovación y los enlaces.
5. Borrar cuenta: el diálogo avisa que no cancela la suscripción; vuelve al login; `profile_photos` queda vacío para ese usuario.
6. Medir `STARTUP` como siempre: el cambio de `main.dart` (licencias, `debugPrint`) no debería mover el arranque.
7. Después de guardar la foto de perfil y de usar "Desde foto" en el Studio: `adb shell run-as <paquete> ls cache` no debería mostrar copias de image_picker (`discardPickedFile`).

## 7. Revisión perf-auditor (2026-11-02)

Sin trabajo por frame en lo agregado. Corregido: el reintento de "Editar perfil" leía un temporal ya borrado (ahora se borra al cerrar la pantalla); `TestFilterView` ya no crea el renderer nativo solo para detenerlo si se negó la cámara; el pedido de permiso no abre el diálogo del sistema si la vista se cerró y no deja un spinner eterno si el canal falla; avatar del registro con `ResizeImage`; `discardPickedFile` compara rutas reales (enlaces `/data/user/0` ↔ `/data/data`). A verificar en el E20: el punto 7.

## 6. Build de release

- `flutter build appbundle --dart-define-from-file=env/revenuecat.json --dart-define-from-file=env/legal.json` falla a propósito sin `android/key.properties` o con `com.example.*`.
- `flutter run --release` también usa `assembleRelease`: para probar en el teléfono, usar `--profile`.
- En release no hay admin local (Studio y editor ocultos). Para un build interno con admin: `--dart-define=LOCAL_ADMIN=true` (nunca en el que se sube a la tienda).
