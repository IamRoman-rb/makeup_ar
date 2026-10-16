# Arranque de la app: medición en el E20

## Por qué

En el log de la prueba del 2026-10-16, en el E20 en profile:
- `App running slow: Executing activity onCreate took 3915ms`;
- `Skipped 349 frames!`, unas 5,8 s con el hilo principal ocupado.

Antes de optimizar hay que saber qué etapa se lleva el tiempo.

## Qué se ejecuta hoy antes de que la app sea usable

1. **Android `onCreate`:** arranca el motor de Flutter y registra los plugins.
2. **`main()`**, todo en serie y antes de `runApp`:
   - `Firebase.initializeApp`;
   - `activateAppCheck`;
   - `VipService.configure` (RevenueCat).

   Los tres corren en el hilo principal de Android.
3. **Primer frame:** el splash.
4. **Splash:** una espera fija de 3 s y después una transición de 0,8 s al catálogo o al login.

## Marcas

`lib/startup_trace.dart` escribe en logcat líneas `STARTUP <etapa> <ms>`, en ms desde el inicio de `main()`:

| Etapa | Momento |
|---|---|
| `main` | Inicio de `main()` (0). |
| `firebase` | `Firebase.initializeApp` terminado. |
| `app_check` | `activateAppCheck` terminado. |
| `revenuecat` | `VipService.configure` terminado. |
| `first_frame` | Primer frame rasterizado: el splash ya se ve. |
| `splash_done_catalog` / `splash_done_login` | El splash termina y navega. |

## Protocolo (lo corrés vos)

Arranque en frío, 5 veces, en profile y con el teléfono desbloqueado. `adb` está en `%LOCALAPPDATA%\Android\Sdk\platform-tools`.

1. Instalar en profile:

   ```
   flutter run --profile -d <id>
   ```

   Después cortá con `q`: la app queda instalada.
2. En otra terminal, dejar el log filtrado:

   ```
   adb logcat -c
   adb logcat -s flutter ActivityTaskManager | findstr "STARTUP Displayed"
   ```

3. En cada repetición:

   ```
   adb shell am force-stop com.example.ar_makeup_app
   adb shell am start -W -n com.example.ar_makeup_app/.MainActivity
   ```

   `am start -W` imprime `TotalTime`, que es el tiempo hasta el primer frame de Android y se mide desde el proceso, no desde `main()`.
4. **Qué pasarme:** las 5 tandas de líneas `STARTUP` y los 5 `TotalTime`, y si había sesión iniciada (catálogo) o no (login).

## Qué se decide con los números

Se decide después de medir, no antes:
- **Si `firebase` → `revenuecat` se lleva segundos:** App Check y RevenueCat pasan a después del primer frame, sin `await` antes de `runApp`. Las llamadas que los necesitan esperan a que estén listos; las callables y las compras ocurren mucho después.
- **Si `TotalTime` es mucho mayor que `first_frame`:** el costo está antes de `main()`, en el motor y el registro de plugins. Ahí se mira qué plugin inicializa en `onAttachedToEngine`.
- **Espera fija del splash (3 s):** es una decisión de producto. Se puede reemplazar por "hasta que esté listo, con un mínimo de X ms".

## Medición 1 (E20, 2026-10-16) y cambio aplicado

Una corrida con `flutter run --profile`, primer arranque después de instalar y con sesión iniciada. No son las 5 en frío del protocolo, pero alcanza para decidir, porque la espera dominante era fija en el código.

| Etapa | ms desde `main()` |
|---|---|
| `onCreate` (antes de `main`) | 844 (logcat `CheckTime`) |
| `firebase` | 666, con 60 frames perdidos antes del primer frame |
| `app_check` | 678 |
| `revenuecat` | 679 (sin key: no se mide el costo real) |
| `first_frame` | 733 |
| `splash_done_catalog` | 3695: 2962 ms de espera fija |

Después venían 800 ms de transición. En total, unos 4,5 s hasta el catálogo, y el 65 % era la espera fija del splash.

**Cambio, decidido con el usuario:**
- Firebase, App Check y RevenueCat arrancan después de `runApp` (`lib/app_services.dart`), en paralelo con el splash.
- El splash espera que terminen, con un mínimo de 800 ms (`kMinSplashDuration`). El fade del logo pasa a 600 ms.
- Si fallan (por ejemplo, sin red), el splash muestra el error y un botón para reintentar. Antes la app se cerraba.

**Esperado:**
- primer frame en menos de 100 ms;
- catálogo alrededor de 1,6 s después de `main()` (800 ms de splash más 800 de transición);
- RevenueCat sigue sin medir: hay que repetir con la key.

**Pendiente:** repetir el protocolo (5 arranques en frío, con la key de RevenueCat) y anotar los números acá.

## Revisión perf-auditor (2026-10-16)

`perf-auditor` revisó lo que cambió desde `6958c02`: arranque, VIP, Mis looks y las pantallas movidas.

**Corregido:**
- **Streams de Firestore creados en `build()`** (tutorial, editor de looks, catálogo y guardados). Cada `setState` se volvía a suscribir y mostraba el spinner:
  - en el tutorial, cada swipe de paso destruía el reproductor de video;
  - en el editor se perdía el foco;
  - en el catálogo parpadeaba la lista con cada tecla.
  
  Ahora cada stream se crea una vez en el `State`.
- **Video del tutorial:**
  - se pausa al ir a segundo plano y al abrir la cámara AR;
  - si falla `initialize()` vuelve a "sin video";
  - `_resolving` ya no queda trabado;
  - el ícono de play vuelve al terminar.
- **Fondo del paywall:** era una imagen de `picsum.photos`, un servicio de terceros que se pedía cada vez; ahora es un degradé local.
- **RevenueCat:** `configure` se marca hecho solo si sale bien, así que el "Reintentar" del splash lo vuelve a intentar.
- **`setState` después de `dispose`:** corregido en el editor de looks y en editar perfil. Si un borrado falla, el editor ya no queda con el spinner.
- **Varios:**
  - `saved_looks_screen` ya no usa `data!` sin chequear;
  - se agregó el `dispose` que faltaba en los controllers de login y registro;
  - en Mis looks, `generate` atrapa excepciones;
  - `AppServices.ready` se dispara después de `runApp`.

**Pendiente, a decidir con mediciones del E20:**
- **Catálogo** (`dumpsys meminfo` con el catálogo abierto):
  - la lista se arma entera, no es perezosa;
  - las imágenes se decodifican sin `cacheWidth`;
  - `lookRecipe` corre en cada rebuild.
- **Guardados:** se escucha toda la colección `looks` y se filtra en el teléfono.
- **Arranque:**
  - RevenueCat en paralelo con Firebase; antes hay que medirlo con la key;
  - fuentes de GoogleFonts empaquetadas, sin bajarlas por red;
  - transición de 800 ms.
- **Menores:** imágenes de pasos y avatar sin `cacheWidth`.
