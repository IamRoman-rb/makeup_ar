# Base local SQLite (sin Firebase)

Desde noviembre de 2026 la app no usa Firebase: cuentas, catálogo, guardados, borradores del Studio y "Mis looks" viven en una base SQLite en el teléfono (drift). Más adelante se sincroniza con un servidor propio; este documento deja el diseño listo para eso.

## Qué cambió

| Antes (Firebase) | Ahora (local) |
|---|---|
| Firebase Auth (email y contraseña) | `users` + `sessions`, contraseña con PBKDF2-HMAC-SHA256 (`PasswordHasher`) |
| Firestore `users/{uid}` | fila de `users` |
| `users/{uid}.saved_looks[]` | tabla `saved_looks` (`user_id`, `look_id`) |
| Firestore `looks` + `looks/{id}/premium/content` | tabla `looks` (el video VIP en `video_url`) |
| Firestore `look_drafts` | tabla `look_drafts` |
| `users/{uid}/ai_looks` + callables `saveAiLook`/`deleteAiLook` | tabla `ai_looks` (`DriftAiLookRepository` valida y pone el tope) |
| Storage `profile_pictures/` | archivo en la carpeta de documentos de la app (`ProfilePhotoStore`) |
| Callable `generateRecipe` (LLM) | `LocalRecipeGenerator`: sin IA, el preset más parecido (`PromptFallback`) |
| `is_admin` puesto desde la consola | la primera cuenta creada en el dispositivo es admin, **solo en debug/profile o con `--dart-define=LOCAL_ADMIN=true`** (`LocalAdminPolicy`); en un build de tienda nadie es admin |
| Webhook de RevenueCat → `premium_until` | el SDK informa el vencimiento (`VipService.purchase/restore/activeUntil`) y se guarda en `users.premium_until` |
| App Check | no aplica (no hay backend) |

`functions/`, `firestore.rules`, `firestore-tests/` y `firebase.json` siguen en el repo como referencia para el servidor: la validación del esquema, la cuota, los prompts del LLM y el webhook de RevenueCat se portan de ahí.

## Código

- Base: `lib/shared/data/local_db/` (`tables.dart`, `app_database.dart` y el generado `app_database.g.dart`).
- Repositorios: `lib/features/<feature>/data/drift_*_repository.dart`, detrás de las interfaces del dominio (`IAuthRepository`, `ICatalogRepository`, `ISavedLooksRepository`, `ILookRepository`, `IAiLookRepository`). Las pantallas no tocan la base.
- Composición: `lib/app_services.dart` abre la base en el splash (`AppDatabase.open`, isolate de fondo con `drift_flutter`) y entrega los repositorios.
- Siembra: una base nueva se llena con un look por preset (`CatalogSeed`, ids `preset-<id>`).
- Regenerar después de tocar las tablas: `dart run build_runner build`.

## Esquema

Fechas en ms desde epoch. JSON guardado como texto y validado al leer (recetas con `RecipeValidator` y `minEngine`).

- `users`: email único en minúsculas, `password_hash`/`password_salt`/`password_iterations`, perfil (nombre, fecha de nacimiento `yyyy-MM-dd`, edad, tipo y tono de piel, gustos en JSON, `photo_path`), `is_admin`, `premium_until`.
- `sessions`: una sola fila (`slot = 'current'`) con `user_id`. La clave es texto a propósito: una `INTEGER PRIMARY KEY` sin valor toma un rowid nuevo y habría varias sesiones.
- `looks`: nombre, categoría (`Lips`/`Eyes`/`Complexion`), portada, `steps` (JSON), `sort_order`, `recipe`/`recipe_schema`/`min_engine`/`source`, `video_url`, `created_by`.
- `look_drafts`: los campos de `StudioLook.toMap()`.
- `saved_looks`: clave (`user_id`, `look_id`).
- `ai_looks`: `user_id`, `recipe`, `source` (`prompt`/`remix`).

`PRAGMA foreign_keys = ON` en cada apertura: borrar un usuario borra en cascada su sesión, sus guardados y sus looks.

## Preparado para sincronizar

Todas las tablas menos `sessions` tienen:

- `updated_at`: para last-write-wins por fila.
- `deleted_at`: lápida. Borrar un look, un borrador, un guardado o un look de IA no borra la fila: la marca, para poder subir el borrado. La UI filtra `deleted_at IS NULL`.
- `dirty`: cambiado localmente y sin subir (outbox). Lo sembrado arranca en `false`.

Los ids son UUID v4 (`newId()`), así no chocan con los de otros dispositivos. La excepción es `users`: borrar la cuenta borra la fila de verdad (datos personales); cuando haya servidor, borrar la cuenta también será una llamada a la API.

Borrar la cuenta (`AccountDeletion`, `docs/compliance/DATA_INVENTORY.md`): en una transacción se borran la fila de `users` (en cascada sesión, `saved_looks` y `ai_looks`) y los `look_drafts` del usuario (de verdad, sin lápida), y los `looks` que publicó quedan con `created_by = NULL` (`dirty`). Después se borran todas sus fotos (`ProfilePhotoStore.deleteAllFor`) y se hace `Purchases.logOut()`.

Plan para el servidor (no implementado):

1. Auth en el servidor (tokens). Las cuentas locales se migran al registrarse en el servidor, o se descartan.
2. Subida: filas con `dirty = true`, en orden de `updated_at`; al confirmar, `dirty = false`.
3. Bajada: cambios con `updated_at` mayor al último sincronizado; gana el `updated_at` más nuevo.
4. `is_admin` y `premium_until` vuelven a ser del servidor (el webhook de RevenueCat).
5. La IA del Studio llama al servidor. **La key del LLM vive en el servidor, nunca en la app** (CLAUDE.md). La nueva implementación de `IRecipeGenerator` reemplaza a `LocalRecipeGenerator` en `AppServices` y vuelve a validar cada variante.

## Decisiones y límites

- **Seguridad de las cuentas locales:** no es seguridad real (la base está en el teléfono). El hash evita la contraseña en claro en la base o en un backup. `PasswordHasher.defaultIterations = 20000`: medir el login en el E20 y bajar si pasa de ~300 ms; las iteraciones se guardan por usuario y un login con iteraciones viejas rehace el hash.
- **Sin "olvidé mi contraseña":** sin servidor no hay mail. Hay "Cambiar contraseña" (pide la actual).
- **VIP:** sin webhook, el vencimiento lo informa el SDK de RevenueCat en el teléfono. Se refresca al arrancar y después del login (`AppServices.refreshVip`), sin bloquear.
- **Admin:** la primera cuenta del dispositivo, solo en builds internos (`LocalAdminPolicy`: debug, profile o `LOCAL_ADMIN=true`). Ve el Studio, el editor del catálogo y los videos. En release la columna `is_admin` se ignora al leer: una base creada con un build interno no da privilegios en uno de tienda (antes, cualquier usuario de la tienda veía los videos VIP gratis).
- **Foto de perfil:** se re-codifica a PNG de 512 px como máximo, sin metadatos (`ProfilePhotoStore.sanitize`); el avatar se decodifica con `ResizeImage` (resuelve el pendiente de memoria de la revisión perf-auditor para el avatar).
- **Catálogo:** los looks y tutoriales que estaban en Firestore no se migraron; la base nueva arranca con los presets.

## Tests

- `test/shared/data/local_db/`: siembra, unicidad, cascada, sesión única.
- `test/features/*/data/drift_*_test.dart`: cada repositorio con `NativeDatabase.memory()`.
- Widget tests con la base: usar `test/helpers/memory_database.dart` (`closeStreamsSynchronously`; sin eso drift deja un Timer pendiente y `testWidgets` falla o se cuelga), y `tester.runAsync` para lo que corre en otro isolate (el hash).

## Revisión perf-auditor (2026-11-02)

**Corregido:**
- `setPremiumUntil` no escribe si el vencimiento no cambió (`refreshVip` corre en cada arranque: marcaba la fila `dirty` y redibujaba el catálogo).
- `AppServices.retry()` reabre la base de cero si la primera apertura falló.
- El tope de Mis looks cuenta con `COUNT` en lugar de traer las filas.

**Pendiente, a decidir con mediciones del E20** (con 5 presets son baratos; crecen con el catálogo):
- `watchLooks` decodifica JSON y valida la receta de todas las filas en el hilo de UI en cada cambio de cualquier look, y una vez por pantalla que escucha (catálogo y guardados). Posible arreglo: memoizar por `id` + `updated_at` y compartir un solo stream.
- Avatar: `FileImage` sin `ResizeImage`/`cacheWidth` y `pickImage` sin `maxWidth`. Una foto de 12 MP se decodifica a ~48 MB para un círculo de 100 px (riesgo de memoria con 2 GB).
- Catálogo: la lista no es perezosa (`shrinkWrap`) y los `StreamBuilder` de usuario y guardados envuelven toda la pantalla; cada corazón reconstruye todos los items. Portadas de red sin `cacheWidth`.
- Arranque: `VipService.configure` espera a la base; son independientes y podrían ir en paralelo. Medir `db` y `revenuecat`.
- PBKDF2: medir el login (20000 iteraciones).
- SQLite sin WAL: solo si las escrituras se notan.

## En el E20 (pendiente)

Anotar con el protocolo de `STARTUP.md`:

- `STARTUP db <ms>`: abrir la base y leer la sesión (en la primera apertura incluye crear el esquema y sembrar).
- Tiempo de login (PBKDF2): del toque en "Iniciar sesión" al catálogo.
- Recorrido: registro → cerrar sesión → login → catálogo → guardar → Studio → publicar → aparece en el catálogo → Mis looks → borrar cuenta.
