# P4: labios realistas

Diseño del labial (informe §5.4–5.5) tal como quedó implementado, cómo regenerar sus datos y cómo probarlo en el E20.

## 1. Qué hace

En Espejo → **Filtro de prueba**, con **Solo labios**, cada look pinta su labial completo de la receta: color, opacidad, acabado, brillo y `lumaFollow`.

- **Acabado:** Mate / Satinado / Brillo / Shimmer, para comparar el mismo color.
- **Intensidad:** la opacidad del labial.
- **Mantené para comparar:** mientras está apretado, opacidad 0, o sea la cámara sin maquillaje.

Sin "Solo labios", el filtro sigue siendo el tinte de pantalla completa de P2.

## 2. Flujo por frame

1. **Quad de cámara:** paso directo o tinte completo.
2. **Capas de cara y ojos** (P5, `FACE.md`).
3. **Capa de labios:**
   - Se dibujan los 176 triángulos de la malla tracked alrededor de la boca (`kLipsRegionTriangles`) con `lips.vert` / `lips.frag`.
   - Sin máscara de pantalla. Desde P5 la salida va premultiplicada (`layerOver` en `color.glsl`): sobre la cámara sola da el mismo resultado de P4, y sobre la base el labial va encima sin pisarla alrededor de la boca. Donde el mapa vale 0, el píxel no cambia.
4. **Puntos de depuración:** si están encendidos.

El camino provisional de P3 se borró: FBO R8 de máscara a ¼, `drawLipsMask` y la variante `MASKED` del tinte. Con eso se ahorra una pasada de pantalla completa y un cambio de framebuffer.

## 3. Datos

### Mapa de labios

`cpp/mesh/lips_maps.h` es generado: no se edita a mano.

- **Formato:** RG8 de 256×128 sobre el rectángulo UV de los labios (`kLipsMapUvRect`) más un margen.
- **R, máscara:**
  - 1 dentro del labio y 0 en la boca abierta y fuera.
  - El borde se difumina con la distancia a los contornos externo e interno, suavizados con Catmull-Rom. Las comisuras no quedan finas.
- **G, brillo:** tres gaussianas: una ancha en el centro del labio inferior y dos chicas en el superior.
- **Triángulos de zona:** los que tocan el rectángulo, menos los 18 que cruzan la boca. Así nunca se pinta sobre los dientes.
- **Parámetros:** en `tools/uv_masks/lips.json`. Vista previa en `img/lips_maps.png`.

```bash
python tools/uv_masks/gen_lips_maps.py
```
```bash
python tools/uv_masks/gen_lips_maps.py --check
```

`--check` falla si el header versionado no coincide con lo que genera el script.

### Normales

`mesh/mesh_normals.h` calcula las normales por vértice de la malla canónica una vez por contexto GL. Las usa `lips.vert`; ver §4.

### Medición en el tracker

`tracking/appearance.cpp` mide en cada inferencia, sobre el recorte de 256² que ya está en CPU. No tiene costo de GPU.

- **L del labio:** 36 muestras entre los contornos externo e interno, a profundidad 0,35 y 0,65, sin las comisuras.
- **L de la piel:** 10 puntos de las mejillas.
- **Cálculo:** mediana y después EMA (`kAppearanceSmoothing`).

El resultado viaja con los puntos en el triple buffer (`FaceAppearance`). La pose suma la dirección hacia la cámara en coordenadas de la malla: la fila 2 de la rotación de Procrustes.

## 4. Sombreado (`lips.frag`)

La especificación ejecutable es `tools/lips/lip_shading.py`. Si cambia el shader, cambia la referencia y sus tests.

```
w     = máscara · opacidad · orientación
s     = L_píxel / L_labio_medido                 (sombreado del labio real, ≤ 1,6)
L     = mix(L_píxel, L_color · s, w · lumaFollow)
(a,b) = mix((a,b)_píxel, (a,b)_color · s, w)
color = OKLab → lineal bajando solo la croma si sale de gamut (color.glsl)
+ brillo = (mapa(uv − desplazamiento)^nitidez [+ destellos]) · gloss · luz · w · smoothstep(0,75, 1,05, s)
```

- **Por qué `· s`:**
  - OKLab es homogéneo: escalar la luz lineal por k escala (L, a, b) por k^(1/3). El labial bajo la luz de ese píxel es `color · s`: las sombras y los pliegues quedan más oscuros y menos saturados, y las zonas iluminadas más claras.
  - La primera versión (`L + (L_color − L_labio)·w·lumaFollow` con croma constante) se veía como una calcomanía en el E20. Ver §6.
- **`lumaFollow`:** cuánto tapa el labial el tono propio del labio.
  - 1 = cubre (la L media del labio pasa a ser la del color).
  - 0 = solo croma, como un bálsamo con color.
  - La opacidad ya modela lo traslúcido. Por eso los presets usan 0,6–1. Con los valores viejos (0,2–0,5), el rojo salía coral y el gótico malva.
  - Si la receta no lo trae, el motor usa 0,8 (`RecipeParams.kt`).
- **Brillo:**
  - **Desplazamiento:** se corre con la pose (`kLipsGlossShiftPerView`, máximo `kLipsGlossShiftMaxUv`), así el reflejo se mueve al girar.
  - **Luz:** se apaga en escenas muy oscuras según la L de la piel. Nunca más por tener la piel oscura.
  - **Sombras:** no aparece en las sombras del labio (`smoothstep` sobre `s`).
- **Acabados** (`Renderer::setLips`):

| Acabado | gloss | Nitidez | Extra |
|---|---|---|---|
| Mate | 0 | — | — |
| Satinado | gloss · 0,5 | 1,5 | — |
| Brillo | gloss | 4 | — |
| Shimmer | gloss · 0,5 | 1,5 | destellos por hash de celdas del mapa (96×48, 6 %, 6 cambios/s) |

- **Orientación:**
  - `vFacing = smoothstep(0, 0,3, normal_canónica · vista)`.
  - De frente, el labio está entre 0,77 y 0,99. Con la cabeza girada 60°, la comisura lejana queda en ~0 y se desvanece.
  - No hay prueba de profundidad: sin esto, la mitad lejana del labio se pintaba por encima del borde de la cara.
- **Gamut:** `oklabToLinearInGamut` hace una bisección de 6 pasos sobre la croma, solo si el color sale de gamut. Conserva L y tono. El tinte de pantalla completa también la usa.
- **Costo:**
  - 3 lecturas de textura: cámara, máscara y brillo desplazado. Las dos últimas salen del mismo mapa de 64 KB.
  - Fuera del labio, el shader sale temprano.

## 5. Calibración

```bash
python tools/lips/calibration_grid.py
```

- **Qué hace:**
  - Pinta un labio sintético (sombreado, pliegues y un reflejo real) en 5 tonos de piel definidos en OKLab (L 0,86 → 0,40).
  - Le aplica cada preset de `recipe_presets.dart` con la misma matemática y las mismas constantes del motor.
- **Salida:**
  - `img/lips_calibration.png`: la fila 0 son las muestras de color y la columna 0 la piel sin maquillaje.
  - En consola, por celda, la diferencia de L y croma entre el labio pintado y la receta.
- **Resultado con los valores actuales:**
  - |ΔL| ≤ 0,08 salvo en los colores claros (Natural y Rosado) sobre piel profunda, donde el labio queda más oscuro que la muestra (ΔL −0,15 a −0,21). Es lo esperable de un labial semitraslúcido sobre un labio oscuro.
  - Si se quiere más cobertura ahí, se sube la opacidad del preset, no `lumaFollow`.

No reemplaza probar con caras reales: no hay dataset de tonos de piel. Las caras de prueba no salen del teléfono.

## 6. Protocolo en el E20

```bash
flutter run --profile -t lib/main_tracker.dart -d <id-del-E20>
```

| Prueba | Cómo | Objetivo |
|---|---|---|
| Rendimiento | "Solo labios" con cada preset y acabado; leer el badge y la línea `TRACK` | render ≥ 24 fps, tracker ≥ 15 Hz |
| Comisuras | Boca cerrada, abierta, sonriendo | el color llega a las comisuras sin salirse ni pintar dientes |
| Brillo | Rosado fresco con Brillo; girar la cabeza | el reflejo se mueve; desaparece con Mate |
| Perfil | Girar la cabeza ~60° | la mitad lejana no se pinta fuera de la cara |
| Antes/después | Capturas con "Mantené para comparar", luz cálida y fría | el color se parece a la muestra del chip |

### Resultados

| Fecha | Render fps | Tracker Hz | Landmarks ms | Notas |
|---|---|---|---|---|
| 2026-10-12 | 28–29 | 14 | 20–24 (badge) | Primera versión. Shaders sin errores en el Mali-G57. No pinta dientes ni el interior de la boca; los acabados y el comparar andan. **Problemas** (capturas): el rojo salía rojo-naranja y más claro que la muestra; el color plano parecía calcomanía; de perfil (~60°) la mitad lejana del labio se pintaba por fuera de la cara; con la lengua afuera se pinta la lengua donde el tracker cree que está el labio inferior. Corregido con el sombreado relativo, los `lumaFollow` nuevos y el desvanecido por orientación (§4) |
| 2026-10-12 | 28 | 14 | 20–21 (badge) | Versión con sombreado relativo y desvanecido. Rojo clásico satinado a intensidad 1: el labio conserva sus sombras y pliegues (línea de la boca, labio superior más oscuro) y ya no se ve plano. Boca abierta: el interior sigue sin pintar. Perfil (~45°): el labial queda dentro de la cara. El render no bajó. |

El protocolo de 10 minutos (jitter, memoria, térmica) no se va a correr: queda fuera de P4 por decisión del responsable del proyecto (2026-10-12). Las métricas de arriba son del badge durante las capturas.

## 7. Revisiones de cierre (`perf-auditor` y `shader-reviewer`, 2026-10-12)

No hubo hallazgos críticos. El hilo de render no aloca memoria por frame, hay un solo hilo dueño de GL y nada cruza JNI por frame.

**Corregido:**

- **Brillo sin lectura dependiente:** el desplazamiento por pose se resta en `lips.vert` (`vGlossUv`), así Mali puede adelantar las 3 lecturas.
- **División por cero:** el shader se protege solo con `max(uLipLightness, 0,1)`, sin depender de la CPU.
- **Shimmer:**
  - Cada cambio es un patrón nuevo. Antes era el mismo patrón corrido en diagonal.
  - El tick se repite cada 256 cambios, para que el hash no pierda resolución.
- **Gamut:** `inGamut` tolera 1e-5. Así los blancos y negros exactos no disparan la búsqueda completa. No es más tolerante porque, en colores muy oscuros, el clamp por canal ya desvía el tono.
- **Filtro de prueba:** un pedido que el motor rechaza (por ejemplo, el motor detenido con un pedido en vuelo) se descarta sin dejar una excepción suelta. Tiene test.
- **Comentarios y contrato:** `<cmath>` en `tracking_state.h`, y error y costo reales de la bisección documentados en `color.glsl`.

**Queda para medir en el E20 antes de tocar:**

- **Costo de GPU según el color:** con labiales saturados, los reflejos salen de gamut y pagan 7 conversiones más.
  - Comparar el tiempo de GPU con Rojo clásico contra Natural.
  - Si pesa, bajar `GAMUT_STEPS` a 4.
- **Mate:** igual lee el mapa de brillo y calcula el `pow`. Una variante sin brillo ahorraría una lectura.
- **Saltos de la pose:** la vista se actualiza a la tasa del tracker (14 Hz). Si el desvanecido de perfil se ve a saltos al girar rápido, interpolar la vista en `landmarksForRender`.
- **`glBufferSubData` de los puntos:** son 3,8 KB por frame. Rotar VBOs solo si aparecen stalls.

## 8. Delineado de labios (P6b)

El campo `lips.liner` de la receta (color y opacidad) se dibuja en la misma pasada de labios: no suma pasadas ni lecturas.

**Datos:**
- **Mapa:** `kLipsMapRgba` (antes RG8) suma el canal B: la distancia al borde del labial, a ambos lados, normalizada por `kLipLinerMaxDistanceUv` (~1,7 mm).
- **Grosor:** la receta no lo trae; está en `engine_config.h` (`kLipLinerEdge`).

**Shader:**
- `lips.frag` dibuja un anillo con `1 − smoothstep(kLipLinerEdge, +aa, distancia)`, con un `aa` de `fwidth` que tiene piso y techo.
- El anillo va encima del labial, con el sombreado relativo topeado en 1. La mitad exterior del anillo cae sobre piel, más clara que el labio, y sin el tope se aclaraba (revisión de `shader-reviewer`, 2026-10-13).
- Es mate: tapa el brillo del labial que tiene debajo.
- **Cobertura:** `1 − (1 − w)(1 − delineado)`. También pinta apenas por fuera del labial.

**Resto del código:**
- **API:** `nativeSetLipLiner`; `LipParams.liner` en Kotlin.
- **Referencia:** `lip_shading.py`, en `liner_alpha` y en `shade(liner=…)`, con tests.
- **Calibración:** la grilla de cara suma la columna de prueba "Rojo + delineado".
- **Arnés:** ningún preset lo usa. `main_tracker.dart` suma la opción "Rojo + delineado" para probarlo en el E20.

## 9. Limitaciones conocidas

- **Lengua o dedos sobre la boca:** el tracker no sabe que el labio está tapado y se pinta encima. Es la oclusión de §5.6 (fase 2).
- **Bigote sobre el labio superior:** se pinta como labio oscuro (el pelo baja `s`). Es lo que haría un labial real debajo del bigote, pero el contorno lo pone el tracker.
- **Tracker a 14 Hz:** con movimientos rápidos, el labial va detrás de la boca hasta que la extrapolación lo alcanza. Las palancas están en `TRACKER.md` §6.
