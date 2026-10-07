# Auditoría del repo (P0)

**Fecha:** 2026-10-06 · **Base:** `origin/main` @ `0735988` · **Alcance:** todas las ramas, historial completo (26 commits), código actual, reglas de Firestore, secretos.
Ningún archivo del proyecto se modificó para esta auditoría; este documento es el único entregable.

---

## 0. Resumen

| # | Hallazgo | Severidad | Acción |
|---|---|---|---|
| 1 | `firestore.rules` deja que cualquier usuario se ponga `is_admin: true` en su propio documento → puede editar/borrar todo el catálogo | **Crítica** | Cambiar reglas (necesita tu OK, ver §5.1) |
| 2 | Mismo agujero con `is_premium` → cualquiera se hace VIP gratis; además `video_url` de los looks es de lectura pública | **Alta** | Reglas + validar VIP en servidor (§5.2) |
| 3 | El repo es **público** y su historial contiene `deepar.aar` (37,6 MB) y `makeup_base.deepar` (5,2 MB) | Media (licencia) | Revisar licencia de DeepAR; opcional purgar historial (§4.3) |
| 4 | Un clon limpio **no compila**: `lib/vip/revenue_cat_keys.dart` está en `.gitignore` y `vip_service.dart` lo importa | Media | Pasar a `--dart-define` (§5.3) |
| 5 | `test/widget_test.dart` está roto (referencia `MyApp`, que no existe) → `flutter test` falla | Baja | Reemplazar el test (§5.3) |
| 6 | Tu checkout local de `main` tiene `lib/ar/deepar_keys.dart` (sin trackear) con license keys de DeepAR que ya no se usan | Baja | Revocar en el panel de DeepAR y borrar el archivo |
| 7 | No hay **ninguna** key de Groq en el historial | — | Nada que revocar en Groq por el repo |
| 8 | El Espejo actual (plugin `camera`, `camera_android_camerax 0.7.4+6`) crashea al salir de la app con *FlutterJNI is not attached to native* (3/3 en el emulador; no ocurre con el motor nativo, 0/3) | Media | Probar `camera_android_camerax 0.7.5+1` (necesita tu OK por ser cambio de dependencia) o reemplazar el Espejo por el motor nativo |

---

## 1. Qué existe hoy (`main`)

- **App "espejo + tutoriales"**: `camera_screen.dart` es un `CameraPreview` espejado sin AR; tutoriales paso a paso por look (`step_by_step_screen.dart`, lee `looks/{id}.steps`); catálogo, looks guardados, perfil, login/signup, i18n es/en/pt/fr.
- **`filter_editor_screen.dart`**: editor admin de *pasos* del tutorial (nombre, imagen, video, categoría, pasos). Ya **no** edita colores/opacidades (eso se quitó en `effe2d6`).
- **VIP**: `lib/vip/` con RevenueCat (`purchases_flutter`); el estado VIP se guarda desde el cliente en `users/{uid}.is_premium`.
- **Dependencias**: `camera ^0.12`, Firebase (core/auth/firestore/storage), `purchases_flutter`, `video_player`, `image_picker 1.0.8` (fijada), `no_screenshot`, `google_fonts`, `intl`, `permission_handler` (con overrides). **No** hay ML Kit, DeepAR, LiteRT ni `http`.
- **Android**: `minSdk 24`, `applicationId com.example.ar_makeup_app`, release firmado con la key de **debug**, bloque en `android/build.gradle.kts` que fuerza `compileSdk 36`/`minSdk 24` en todos los subproyectos (originalmente "FIX NAMESPACE Y SDK PARA DEEPAR E IMAGE PICKER"; hoy lo sigue necesitando `image_picker 1.0.8`).
- **Toolchain local**: Flutter 3.47.0 / Dart 3.13.0.

### Estado de calidad (medido hoy en un clon limpio)

`flutter analyze`: **6 errores, 1 warning, 14 infos**.
- Errores: 5 por `revenue_cat_keys.dart` inexistente (hallazgo 4) y 1 por `MyApp` en `test/widget_test.dart` (hallazgo 5).
- Warning: import sin usar de `login_screen.dart` en `lib/main.dart:6`.
- Infos: `withOpacity` deprecado (8), `activeColor` deprecado (2) y `BuildContext` usado tras `await` (4). Aparte, `flutter` avisa que `synthetic-package` en `l10n.yaml` ya no tiene efecto.

La "Definición de terminado" de `CLAUDE.md` (`flutter analyze` sin warnings) **no se puede cumplir** hasta resolver los hallazgos 4 y 5.

---

## 2. Qué se perdió y dónde

Correcciones a §1 del informe `motor_ar_propio.md`: **no** hay una sola rama (existe `origin/claude/flutter-ar-makeup-migration-plan-c2abb5`, idéntica a lo ya mergeado), y `android/` **sí** está en el repo.

Historia del pipeline AR:

| Commit | Qué pasó |
|---|---|
| `51ccdd7` | Primer commit. Motor 100% Dart: `camera` + `startImageStream` + ML Kit Face Mesh + `CustomPainter`, todo dentro de `camera_screen.dart`. Llamada a Groq desde la app (la línea de la key **ya estaba vacía**). `deepar.aar` presente pero sin conectar |
| `7dbef8d` | `MIGRATION_CHECKLIST.md`: plan para migrar a DeepAR con un efecto base paramétrico |
| `3c13606` | Abstracción `ArMakeupEngine` + `DeepArMakeupEngine` + `LegacyCanvasMakeupEngine` (418 líneas) + `AiMakeupRecipeService` (Groq) |
| `a2f5b1a` | Asset `makeup_base.deepar` (5,2 MB) y mapeo de nodos DeepAR |
| `0f4d97b`, `9ef6fe1`, `1127815` | Fixes de rotación/espejo de la malla, toggle de cejas y crash tras `dispose` en el motor legacy |
| `acd4fb6` | Se quita el input de prompt de IA de la cámara; nace el editor admin |
| **`effe2d6`** | **Se borra todo el AR** por decisión de producto ("el overlay 2D nunca convenció; DeepAR requería setup pago y trabajo en Studio"). Borrados: `lib/ar/*`, `lib/services/ai_makeup_recipe_service.dart`, `assets/ar_effects/*`, `android/app/libs/deepar.aar`, `MIGRATION_CHECKLIST.md`; dependencias `deepar_flutter`, `vector_math`, `google_mlkit_face_mesh_detection` |

Para recuperar cualquier archivo: `git show effe2d6^:<ruta>`.

---

## 3. Qué conviene recuperar

| Pieza (en `effe2d6^`) | ¿Recuperar? | Motivo |
|---|---|---|
| `lib/ar/ar_makeup_engine.dart` (contrato `ArMakeupEngine`) | **Como referencia** | La idea es la misma que `IMakeupRenderer`, pero acopla `Widget buildPreview()` y `Map<String,dynamic>` sin tipar. El contrato nuevo usa `MakeupRecipe` tipada |
| `lib/ar/legacy_canvas_makeup_engine.dart` | **Parcial**, como base de `CustomPainterMakeupRenderer` (fallback/iOS) | Ya resuelve rotación, espejo, `_isProcessing` y `dispose`. Pero viola reglas actuales: `startImageStream` (YUV a Dart), `Paint()`/`Path()` creados dentro de `paint()`, `_scale`/`_offsetX` calibrados a mano. Solo sirve como respaldo, nunca como camino principal |
| `MakeupRecipe.convertLegacy` + formato `makeup_recipe` v1 | **Sí, como migrador v1 → v2** | Algunos documentos de `looks` en Firestore pueden tener `makeup_recipe` (v1) o `makeup_params` (legacy). No pude consultar Firestore para confirmarlo: hay que revisarlo en la consola |
| Prompt de Groq de `AiMakeupRecipeService` | **No** | Lo reemplaza el system prompt de §10.4 en una Cloud Function |
| `DeepArMakeupEngine`, `deepar_node_mapping.dart`, `deepar_keys.example.dart`, assets `.deepar` | **No** | Contradicen el objetivo (sin SDKs AR de terceros) |
| `MIGRATION_CHECKLIST.md` | **No** | Plan obsoleto (DeepAR) |
| Editor de looks, i18n, VIP, tutoriales | **Ya están en `main`** | No se perdieron |

---

## 4. Secretos y licencias

Búsqueda en los 26 commits de todas las ramas con patrones de Groq (`gsk_`), OpenAI (`sk-`), Stripe (`sk_live`/`sk_test`), RevenueCat (`appl_`/`goog_`), Google (`AIza…`), claves privadas PEM y asignaciones genéricas `api_key|license_key|secret|token = "<16+ chars>"`. Los valores **no** se copiaron en ningún lado.

### 4.1 Encontrado

| Archivo | Commits | Tipo | Riesgo |
|---|---|---|---|
| `android/app/google-services.json`, `lib/firebase_options.dart` | Todos, desde `51ccdd7` | API keys de Firebase (`AIza…`) | **No son secretas** (Firebase las publica en el cliente). Pero conviene **restringirlas** en Google Cloud Console (Android: por package + SHA-1; iOS: por bundle ID; web: por dominio) y activar **App Check** |
| `lib/ar/deepar_keys.example.dart` | `3c13606` → `effe2d6^` | Placeholders | Sin riesgo |
| `lib/vip/revenue_cat_keys.example.dart` | Actual | Placeholders | Sin riesgo |

### 4.2 No encontrado

- **Ninguna key de Groq** en ningún commit. En `51ccdd7` la línea de la key ya estaba borrada, y el servicio posterior tenía `'Authorization': 'Bearer'` sin key (un TODO). Si la key existió en tu PC o en un APK que hayas distribuido, **revocala igual** en console.groq.com: no lo puedo verificar desde el repo.
- `lib/vip/revenue_cat_keys.dart` y `lib/ar/deepar_keys.dart` **nunca** se commitearon.

### 4.3 Licencias y tamaño del historial

- El repo es **público** en GitHub. Su historial contiene `android/app/libs/deepar.aar` (SDK binario de DeepAR, 37,6 MB) y `assets/ar_effects/makeup_base.deepar` (5,2 MB). Redistribuir el SDK de un tercero en un repo público puede violar su licencia: **revisá los términos de DeepAR**. Si hay que sacarlo, se necesita reescribir el historial (`git filter-repo` + force-push sobre `main`). Es destructivo y rompe los clones existentes, así que no lo hice: es tu decisión.
- Además, esos 43 MB los descarga cualquiera que clone el repo.

---

## 5. Riesgos y cambios propuestos (no aplicados)

### 5.1 Crítico: escalada a admin

`firestore.rules` actual:

```
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

Cualquier usuario logueado puede hacer `users/{suUid}.set({is_admin: true}, merge)` desde un cliente propio (las keys de Firebase son públicas) y desde ahí escribir en `looks`, porque la regla de `looks` confía en ese campo. **Impacto:** cualquiera puede borrar o reemplazar el catálogo (imágenes, videos, pasos).

Cambio propuesto: prohibir que el cliente toque campos privilegiados. El admin se otorga solo desde la consola de Firebase o con el Admin SDK.

```
match /users/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null && request.auth.uid == userId
    && !request.resource.data.keys().hasAny(['is_admin', 'is_premium']);
  allow update: if request.auth != null && request.auth.uid == userId
    && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['is_admin', 'is_premium']);
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

Hay que probarla con el emulador antes de desplegarla (`.claude/rules/firebase.md`). **Requiere tu confirmación** (`CLAUDE.md`: no se modifica `firestore.rules` sin preguntar).

### 5.2 Alto: VIP gratis y videos expuestos

- `VipService._syncPremiumFlag` escribe `is_premium` desde el cliente. Con la regla actual cualquiera se marca VIP. Con la regla de §5.1 el cliente ya no puede escribirlo, así que la fuente de verdad tiene que pasar al servidor: un **webhook de RevenueCat → Cloud Function** que escriba `is_premium` con el Admin SDK. Alternativa sin backend: no guardar el flag y consultar `Purchases.getCustomerInfo()` en el cliente (más simple, pero manipulable en un dispositivo rooteado).
- `looks.video_url` es de lectura pública: el "paywall" solo oculta el reproductor, pero la URL se puede leer sin pagar. Si el video es contenido pago, debería vivir en una subcolección `looks/{id}/premium/{doc}` con lectura solo para usuarios VIP (`get(users/uid).data.is_premium == true`), o en Storage con reglas equivalentes.

### 5.3 Compilación y tests

- **Hallazgo 4:** que el código compile no debería depender de un archivo ignorado. Propuesta: `RevenueCatKeys` lee `String.fromEnvironment('RC_ANDROID_KEY')` / `'RC_IOS_KEY'` (con `--dart-define` o `--dart-define-from-file=env/revenuecat.json`, archivo ignorado), y `revenue_cat_keys.dart` se versiona sin valores. Las keys públicas de RevenueCat (`appl_`/`goog_`) están pensadas para ir en el cliente, pero se respeta la decisión de no versionarlas.
- **Hallazgo 5:** reemplazar `test/widget_test.dart` (plantilla de `flutter create` que referencia `MyApp`) por tests reales. Los de F1 (recetas) van en `test/features/ar/`.

### 5.4 Otros

- `applicationId com.example.ar_makeup_app`: Google Play rechaza `com.example`. Hay que cambiarlo antes de publicar, y eso implica registrar la app nueva en Firebase y regenerar `google-services.json`.
- El release se firma con la key de debug.
- El bloque `subprojects { afterEvaluate { compileSdkVersion(36) … } }` fuerza versiones en todos los plugins. Hoy hace falta por `image_picker 1.0.8`; puede romper el plugin nativo `makeup_engine` de P1 si este necesita otro `minSdk`. Revisar al crear el plugin.
- Tu checkout principal (`C:/Users/USER/Documents/proyectos/ar_makeup_app`) está **2 commits atrás** de `origin/main`: hacé `git pull` ahí.

---

## 6. Decisiones que necesito de vos

1. **¿Aplico la regla de §5.1?** (Recomendado: sí, ya.)
2. **VIP:** ¿webhook de RevenueCat → Cloud Function (recomendado) o `getCustomerInfo()` en el cliente?
3. **Historial público con `deepar.aar`:** ¿lo purgamos (force-push) o lo dejamos?
4. **Firestore:** ¿algún look tiene `makeup_recipe` o `makeup_params`? Define si F1 necesita el migrador v1 → v2.
5. **RevenueCat keys por `--dart-define`** (§5.3): ¿lo hago?
