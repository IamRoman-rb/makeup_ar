# Pruebas pendientes en el E20 (2026-10-21)

Todo esto está implementado y probado en la PC (tests, compilación). Falta verlo y medirlo en el teléfono. Primero `git pull`.

## 1. Arnés del tracker: precisión (`TRACKER.md` §9–§10)

`flutter run --profile -t lib/main_tracker.dart -d <id>` → botón **Ajuste**.

- **One Euro:** probar 2 o 3 combinaciones de `minCutoff`/`beta`. Por cada una, pasar la línea `TRACK` quieta (`jitter=`) y contar si se siente atraso al girar la cabeza.
- **Chips, de a uno, mirando de cerca labios y delineado:**
  - **Malla suave:** contornos más curvos.
  - **Borde real:** el labial sigue al borde real del labio. Vista previa en `docs/ar_engine/img/lips_edge_preview.png`.
  - **Contorno fino:** el contorno se ajusta al borde; `contour=` en `TRACK`.
- Con cada chip prendido, mirar que `fps=` y `cpuP95=` no cambien.
- Lo que mejore se prende por defecto: `kSmoothMeshDefault`, `kLipEdgeRefineDefault` y `kLipContourDefault` en `engine_config.h`.

## 2. Guía de maquillaje (`COACH.md`)

- **App:** catálogo → look → **Guíame** (también desde el tutorial y "Mis looks").
- **Arnés, sin Firebase:** botón **Guía** con el look elegido.

Qué probar:
1. **Referencia** con la cara lavada.
2. **Labial:** sin, poco, bien, de más y de otro color.
3. **Delineado:** cerca de la cámara, corto y largo.
4. **Rubor:** apenas y de más.
5. **Toma:** girar la cara y alejarse.
6. **Medir:** líneas `COACH` (`ms=`, `hz=`). Con la cara quieta, la variación entre muestras da el ruido real (`CoachPolicy.measurementNoise`).

## 3. Lo de días anteriores

- **Recorrido:** catálogo → filtro → "Ver tutorial"; Espejo de la barra solo cámara; Studio con el panel deslizable.
- **Arranque:** líneas `STARTUP` de 5 arranques en frío.
- **Memoria con el catálogo abierto:** `adb shell dumpsys meminfo com.example.ar_makeup_app`.

## 4. iPhone (cuando haya una Mac)

El Swift del ajuste y de la guía se escribió sin compilador: ver el checklist de `IOS.md`.
