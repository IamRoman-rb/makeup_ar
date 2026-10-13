# P5–P6: cara, ojos, pestañas, efectos y API final

Este documento describe el resto de las regiones de la receta (informe §5.4–5.8 y §10.8), tal como quedaron implementadas:
- **P5:** rubor, base, contorno, iluminador, sombras y delineado;
- **P6:** pestañas y efectos procedurales (pecas, glitter, sheen).

También cubre la API Dart que queda estable, cómo regenerar los datos y cómo probarlo en el E20. Los labios están en `LIPS.md`. Con P6 el motor dibuja la receta `makeup-recipe/2` completa, salvo el delineado de labios.

## 1. Qué hace

En Espejo → **Filtro de prueba**, cada look se aplica completo.

**Controles:**
- **Zona** (Todo / Labios / Ojos / Mejillas / Piel): muestra una sola región, para comparar o capturar.
- **Intensidad**: multiplica todas las opacidades y el coverage de la base. Va de 0 a 1,5; 1 es la receta tal cual.
- **Acabado del labial**: visible con Todo o con Labios.
- **Mantené para comparar** y **Ver puntos**: igual que en P4.

**Qué no se dibuja todavía:**
- **Delineado de labios** (`lips.liner`).
- **Pestañas en 3D:** las pestañas de P6 se pintan sobre la piel. De perfil no salen del contorno de la cara (§10).

## 2. Flujo por frame

1. **Quad de cámara.**
2. **Cara** (`face.vert` + `face.frag`):
   - 852 triángulos: toda la malla menos los 18 que cruzan la boca y los 14 que cruzan cada ojo.
   - Capas en orden: base, contorno, rubor e iluminador.
3. **Ojos** (`face.vert` + `eyes.frag`): 284 triángulos alrededor de los dos ojos. Dibuja hasta 4 sombras en el orden de la receta y el delineado encima.
4. **Labios** (`lips.vert` + `lips.frag`).
5. **Puntos de depuración.**

**Composición de las pasadas:**
- **Blending premultiplicado** (`layerOver` en `color.glsl`): `rgb = resultado − (1−A)·cámara`, `a = A`, con `glBlendFuncSeparate(ONE, ONE_MINUS_SRC_ALPHA, ZERO, ONE)`.
  - Sobre la cámara sola da exactamente el resultado de la pasada.
  - Sobre una pasada anterior la compone encima: la sombra va sobre la base y el labial sobre la base.
  - Con A = 0 no cambia nada.
- Si la receta no tiene nada en una zona, ese draw no se hace.
- Dentro de una pasada, una región apagada cuesta una multiplicación, no una lectura.

**Receta atómica:**
- Kotlin llama un `nativeSet*` por región (labios, rubor, cada capa de piel, cada sombra, delineado) y después `nativeCommitRecipe`.
- El render copia la receta publicada solo cuando cambia la versión, así que nunca dibuja media receta.

## 3. Datos

### Mapas UV

Los genera `tools/uv_masks/gen_face_maps.py` con los parámetros de `tools/uv_masks/face.json`. Los contornos salen de los de MediaPipe que ya están en el repo (Apache 2.0).

**Media cara con espejo:**
- Las UV de la malla canónica son simétricas (error ≤ 0,001) y ningún triángulo cruza la línea media. Las dos cosas las verifican los tests de host.
- Por eso se guarda solo la mitad derecha de la imagen y `face.vert` espeja por vértice con `u' = min(u, 1 − u)`. Es exacto.

| Mapa | Formato | Canales |
|---|---|---|
| `kFaceMapRgb` | RGB8 128×224, media cara | piel (base; 0 en ojos, cejas y labios, difuminado hacia el borde de la cara), contorno, iluminador (ya × piel) |
| `kEyeMapA` | RGBA8 192×160, ojo derecho | párpado, pliegue, V externa, lagrimal |
| `kEyeMapB` | RGBA8 192×160 | hueso de la ceja, distancia a la línea de pestañas, distancia al wing, avance del wing |

**Coordenadas del ojo:** `s` va de 0 en el ángulo externo a 1 en el lagrimal. `t` va de 0 en la línea de pestañas a 1 en el borde inferior de la ceja, y es negativo debajo del párpado inferior. Párpado, pliegue, V externa y hueso de la ceja son ventanas o gaussianas en (s, t).

**Delineado por distancia:**
- **Grosor:** el canal guarda la distancia a la línea de pestañas, normalizada por `kLinerMaxDistanceUv` (0,012 UV, unos 3 mm) y afinada hacia el lagrimal. El shader corta en `mix(kLinerThicknessMin, kLinerThicknessMax, thickness)` con un borde de `kLinerFeather`. El `thickness` de la receta es continuo sin regenerar nada.
- **Wing:** la línea de pestañas termina en el ángulo externo, sin tapa redonda. El wing sale de ahí en la prolongación del párpado inferior, levantada 10° (`liftDeg`). Nunca pinta debajo de esa prolongación, se afina hacia la punta y se ve hasta `wing × kWingLengthUv`. Así sigue la forma real del ojo, que la malla transfiere, en vez de un ángulo fijo: con el ángulo fijo de 22° y la tapa redonda, en el E20 se veía como un gancho hacia abajo (§7).

**Rubor analítico:**
- No usa textura: es una gaussiana elíptica en la UV espejada, `exp(−½·|M·uv' + o|²)`. `M` y `o` salen de `kCheekPlacements` (apple, high, low).
- `spread` escala los sigmas entre `kCheekSpreadScaleMin` y `kCheekSpreadScaleMax`.
- Se multiplica por el canal de piel.

```bash
python tools/uv_masks/gen_face_maps.py
```
```bash
python tools/uv_masks/gen_face_maps.py --check
```

Las vistas previas están en `img/face_maps.png` (rojo piel, verde contorno, azul iluminador) y en `img/eye_maps.png` (regiones y delineado simulado).

## 4. Sombreado

La especificación ejecutable es `tools/makeup/face_shading.py` (`compose`, `layer_over`, `blend`).

```
s = L_píxel / L_piel_medida                     (FaceAppearance::skinLightness; ≤ 1,6)
por capa i, en orden:
  L      = mix(L, (color_i · s).L, a_i · lumaFollow_i)
  ab     = mix(ab, (color_i · s).ab, a_i)
  brillo = mix(brillo, brillo_i, a_i)            (una capa encima tapa el de abajo)
color = OKLab → lineal bajando croma si sale de gamut, + brillo · smoothstep(0,85, 1,1, s)
salida: layerOver(color, cámara, 1 − Π(1 − a_i))
```

- **Mismo modelo que los labios de P4:** el producto bajo la luz de ese píxel es `color · s`. Conserva el sombreado y la textura de la piel.
- **Base:** `coverage` sobre el canal de piel.
- **Contorno y rubor:** capas normales.
- **Iluminador:**
  - Sigue la L de su color solo en `kHighlightLumaFollow` (0,4) y suma un brillo `kHighlightShine` donde hay luz.
  - Con lumaFollow 1, un crema sobre piel oscura quedaba como una franja de tiza (§5).
- **Sombras:**
  - La región se elige con un selector one-hot sobre el mapa A, o sobre B.r para el hueso de la ceja.
  - Satinado = brillo `kShadowSatinShine`.
  - Shimmer = satinado más destellos (variante `SHIMMER`).
- **Delineado:** última capa de la pasada de ojos, sin brillo; tapa el brillo de las sombras que tiene debajo.
- **Orientación:** el mismo mecanismo que los labios (`vFacing`, normales de la malla), con un rango más permisivo (§8). De perfil, la mitad lejana no se pinta fuera de la cara.

### Lecturas por fragmento

| Pasada | Lecturas | Cubre |
|---|---|---|
| Cara | 2 (mapa de cara y, solo donde hay alguna capa, cámara) | toda la cara, ~25–35 % de la pantalla |
| Ojos | 4 (mapas A, B y C y, solo donde hay alguna capa, cámara) | zona de ojos |
| Labios | 3 (P4) | ~2 % |

## 5. Calibración

```bash
python tools/makeup/calibration_grid.py
```

La grilla se genera así:
- Pinta una cara sintética directamente en el espacio UV, que es casi una proyección frontal.
- Usa los mapas reales del motor y la misma matemática.
- Compone las pasadas en el mismo orden que el render: cara, ojos y labios.

Salida: `img/face_calibration.png`, con 5 tonos de piel (L 0,86 → 0,40) por fila y los 5 presets por columna. Muestra que cada región cae en su lugar.

Con la grilla se ajustó:
- **Contorno e iluminador:** más anchos; antes se veían como rayas.
- **`kHighlightLumaFollow` y `kHighlightShine`.**

No reemplaza una cara real: la cara sintética es plana y no tiene volumen.

## 6. API Dart

**Contrato:** `lib/features/ar/domain/i_makeup_renderer.dart`, sin Flutter. Lo usa la vista:

| Método | Qué hace |
|---|---|
| `start()` | Devuelve `MakeupSurface` (id de textura y tamaño), o null si no puede dibujar maquillaje en este equipo. |
| `applyRecipe(MakeupRecipe?)` | Aplica la receta. |
| `setShowLandmarks(bool)` | Muestra u oculta los puntos de depuración. |
| `stats()` | Métricas del render y del tracker. |
| `stop()` | Libera el renderer. |

**Implementaciones**, elegidas con `--dart-define=AR_RENDERER=native|painter` (por defecto `native`; `makeup_renderer_factory.dart`):
- `NativeGpuMakeupRenderer`: el motor nativo. Si no puede iniciar (sin GLES 3, sin cámara), `start` devuelve null con el motivo.
- `MirrorFallbackRenderer`: el respaldo. No dibuja nada.

Cuando `start` devuelve null, la vista muestra un aviso y llama a `onUnavailable`. El Espejo vuelve entonces a la cámara normal con un SnackBar.

**Ajustes de receta:** `adjustRecipe` (`domain/recipe_adjustments.dart`) aplica la zona, la intensidad y el acabado del labial. Devuelve una receta nueva, que sigue siendo válida para `RecipeValidator` (tiene test).

**Plugin:** `TintRegion.lips` pasó a llamarse `TintRegion.makeup` (`REGION_MAKEUP`, `kMakeup`). `full` queda solo para el tinte de la pantalla del spike.

## 7. Protocolo en el E20

```bash
flutter run --profile -t lib/main_tracker.dart -d <id-del-E20>
```

| Prueba | Cómo | Objetivo |
|---|---|---|
| Rendimiento | Zona "Todo" con cada preset. Leer el badge y la línea `TRACK`. | Render ≥ 24 fps, tracker ≥ 14 Hz. |
| Ojos | Abiertos, cerrados y mirando a un costado, con Gótico y Glam dorado. | La sombra no cae en el ojo y el delineado sigue la línea de pestañas. |
| Mejillas | Natural (apple) y Glam dorado (high). | El rubor queda en el lugar del placement. |
| Piel | Gótico (contorno) y Glam dorado (iluminador). | El contorno queda bajo el pómulo; el iluminador, arriba del pómulo y en el puente de la nariz; no tapan cejas, ojos ni labios. |
| Perfil | Girar la cabeza ~60°. | Nada se pinta fuera de la cara. |
| Pestañas | Ojos abiertos, cerrados y mirando hacia arriba, con cada preset. | Salen de la línea de pestañas sin flotar ni pintar el ojo. |
| Efectos | Glam dorado (glitter en párpados) y Rosado fresco (sheen en mejillas y nariz); zona "Ojos" y "Mejillas". | El glitter titila en el párpado; el sheen aclara apenas pómulos y nariz. |
| Respaldo | `--dart-define=AR_RENDERER=painter` | El Espejo muestra la cámara normal con el aviso. |

### Resultados

| Fecha | Render fps | Tracker Hz | Notas |
|---|---|---|---|
| 2026-10-12 | 29 (emulador, sin cara) | — | Los programas de cara y ojos compilan y enlazan en el driver del emulador, también después de los arreglos de §8. El filtro de prueba nuevo y el respaldo (`AR_RENDERER=painter`) funcionan. **Falta medir en el E20 con cara.** |
| 2026-10-12 | 28 | 14 (19–20 ms) | **E20 con cara**, look completo con cada preset: el render no bajó respecto de solo labios. Sombras, delineado y labios caen en su lugar y no pintan el ojo, tampoco con un ojo cerrado. Base, rubor, contorno e iluminador se ven sutiles con las opacidades de los presets. **Problemas** (capturas ampliadas): el wing salía como un gancho hacia abajo y las sombras tenían el borde superior duro. Corregido: wing sobre la prolongación del párpado inferior, sin tapa en el ángulo (§3); borde del párpado más difuminado (`tFeather` 0,1 → 0,3); rubor "high" más alto, hacia el pómulo. **Falta confirmar en el E20.** |

## 8. Revisiones de cierre (`perf-auditor` y `shader-reviewer`, 2026-10-12)

No hubo hallazgos críticos:
- no hay allocations por frame;
- no hay JNI por frame;
- el mutex solo se toma cuando cambia la receta;
- `releaseGl` libera todo;
- el estado GL queda limpio entre pasadas;
- las varyings y los rangos de los uniforms son correctos;
- la matemática coincide con la referencia Python.

**Corregido:**

- **Desvanecido por orientación propio de cara y ojos** (`kFaceFacingFadeStart/End` = −0,15 / 0,1). Con el rango de los labios pasaba esto:
  - de frente, la mandíbula y las sienes perdían hasta un 30 % del contorno;
  - con la cabeza girada 30°, el pómulo y el rubor del lado lejano desaparecían aunque se ven.

  Lo confirmé con las normales de la malla.
- **La cámara se lee después de la salida temprana** en `face.frag` y `eyes.frag`. La textura externa es la lectura cara y la pasada de cara cubre toda la cara aunque la receta tenga solo rubor.
- **`layerOver` exacto:** si la mezcla en OKLab oscurece más que la cobertura (un delineado negro), la cobertura efectiva sube lo justo. Antes se recortaba y aclaraba el borde. Tiene test en Python.
- **Borde del delineado de al menos ~1,5 px** (`fwidth`): con poco grosor medía menos de un píxel y titilaba.
- **Wing corto:** arranca opaco.
- **Destellos del shimmer:** distintos en cada ojo; antes se espejaban.
- **`keep` en highp:** con fp16 el borde exterior de las máscaras quedaba sin cobertura.
- **`SHADING_MAX` y `SHINE_SHADING_*`:** viven una sola vez, en `color.glsl`.

**Queda para medir en el E20 antes de tocar.** Palancas en orden, si el render baja de 24 fps con "Todo":

1. **Resolución del compositor:** `kMaxPreviewLongSide/ShortSide` de 1280×720 a 960×540. Saca ~44 % de los fragmentos de todas las pasadas.
2. **Gamut:** `GAMUT_STEPS` de 6 a 4, o bajar `SHADING_MAX` en la cara. En los reflejos, la croma escalada sale de gamut y paga la bisección.
3. **Rápida:** bajar `kTrackerMaxHz` a 15 (la GPU es una sola y la comparten render y tracker).
4. **Más trabajo:**
   - IBOs por capa: hoy la pasada de cara rasteriza toda la cara aunque la receta tenga solo rubor.
   - Framebuffer fetch (ARM/EXT) para no releer la cámara en cada pasada.
   - Mapa de cara en RGBA8 en lugar de RGB8.

Estimación sin medir del `perf-auditor`: la pasada de cara cuesta unos 3–6 ms de GPU en el E20, los ojos 0,5–1 ms y los labios 0,2–0,4 ms.

## 9. Pestañas y efectos (P6)

### Pestañas (`eyes.frag`, última capa de los ojos)

**Mapa `kEyeMapC`** (RGBA8 del rectángulo del ojo). Para cada línea de pestañas, superior e inferior, guarda:
- la posición a lo largo de la línea, de 0 en el ángulo externo a 1 en el lagrimal;
- la altura hacia afuera del ojo, normalizada por `kLashMaxLengthUv` (~7 mm) o por `kLowerLashMaxLengthUv`.

Altura 1 significa "sin pestañas": dentro del ojo o lejos de la línea.

**Hebras procedurales:**
- En coordenadas de la línea, `x = (s + curl·h²·(1,2 − 1,6·s)) · N`; cada celda de `x` es una hebra.
- Cada hebra:
  - tiene un largo propio, `length × (0,6 + 0,4 · hash)`, más corto hacia el lagrimal;
  - se afina hacia la punta, con el borde antialiasado con `fwidth`;
  - se inclina hacia afuera en el ángulo externo y un poco hacia adentro en el lagrimal.
- **Raíz:** se oscurece según `volume`.
- **Inferiores:** menos hebras, más finas, menos inclinadas y con `kLowerLashOpacity` de opacidad.
- **Color:** fijo, `kLashColor`, un negro de máscara de pestañas: la receta no trae color.
- **Parámetros:**
  - `volume` → cantidad de hebras (`kLashCount*`), ancho (`kLashWidth*`) y raíz;
  - `length` → `kLashLength*`.
- **Costo:** con `uLashAmount = 0` no se calcula nada (rama uniforme).

### Efectos (lista cerrada, informe §10.8)

| Efecto | `cheeks_nose` / `full_face` | `eyes` | `lips` |
|---|---|---|---|
| Pecas | Pasada de cara, variante `EFFECTS`: un punto por celda (presencia, centro y radio por hash), color = piel del píxel × (0,74, 1,2, 1,35) en OKLab, capa después de la base | — | — |
| Glitter | Destellos por celda que cambian con el tiempo (`kGlitterDensity*`, `kGlitterSparkle`) | Destellos sobre párpado y pliegue (variante `SHIMMER`) | Destellos del labial (variante `SHIMMER`) |
| Sheen | Aclarado relativo de la luz (`× (1 + kSheenGain)`) solo donde la piel ya está más iluminada que la media | Ídem sobre párpado y pliegue | Más brillo del labial (`kLipSheenGloss`) |

- **Máscaras de región:**
  - `cheeks_nose`: canal A del mapa de cara (ahora RGBA8): mejillas altas y puente de la nariz.
  - `full_face`: la piel.
  - `eyes`: párpado y pliegue.
  - `lips`: la máscara del labio.
- **Región por defecto:** sin región, Kotlin (`EffectParams`) y Dart (`effectZone`) usan la misma regla: glitter en los ojos; sheen y pecas en mejillas y nariz.
- **Zonas del filtro de prueba:** cada efecto se muestra con la zona de su región.
- **Calibración:** dos problemas vistos en la grilla.
  - Un sheen aditivo dejaba un velo gris en piel oscura. Por eso es relativo.
  - Las pecas con un corrimiento de croma fijo salían naranjas en piel oscura. Por eso el color es proporcional a la piel.

## 10. Limitaciones conocidas

- **Delineado de labios:** no se dibuja (§1).
- **Pestañas en 2D:** se pintan sobre la piel del párpado. De perfil o mirando muy abajo no se ven como hebras que salen de la cara: eso necesita geometría propia (fase 2).
- **Hebras irregulares:** la posición a lo largo de la línea está cuantizada a 8 bits en el mapa. Con ~30 hebras eso las hace un poco irregulares, y no molesta porque las pestañas reales también lo son.
- **Oclusión:** igual que en los labios, una mano sobre la cara se pinta encima. Es la oclusión de §5.6 (fase 2).
- **Referencia de L:** la L de referencia es la de las mejillas. En los párpados, que suelen estar más oscuros, la sombra queda un poco más oscura que la muestra. Es lo que pasa con una sombra real.
- **Formas fijas:** las regiones son las mismas para todas las caras, salvo lo que deforma la malla. Ajustar formas por persona (párpado encapotado, por ejemplo) queda para la fase de calidad.
