# Guía de maquillaje en vivo (2026-10-20)

Pedido de la clienta: mientras la usuaria se maquilla de verdad, la app compara su cara con el look elegido y le dice qué hacer. Por ejemplo: "falta color en los labios", "el delineado quedó corto", "bajá el rubor".

## Qué hace (v1)

- **Entrada:** catálogo → look → espejo con el look → **"Guíame"**. También desde el ícono de cámara del paso a paso.
  - La guía reemplaza a la cámara: una sola sesión.
- **Inicio:** tarjeta "Antes de empezar".
  - **Tomar referencia** (cara lavada, 2 muestras) o **Saltear**.
  - Con referencia, el color natural de labios, rubor y párpados es el de la usuaria. Sin ella se estima desde la piel con la misma luz; los labios quedan aproximados.
- **En marcha:**
  - La cámara muestra la cara real, sin maquillaje virtual.
  - Cada ~1,5 s se toma una muestra.
  - Arriba, una ficha por zona: ✓ bien, ↑ falta, ↓ sobra, paleta = tono, ? no se ve.
  - Abajo, la indicación de la zona en foco, que también se dice en voz alta.
  - "Mantené para ver el look" pone el look virtual encima mientras se aprieta.
- **Zonas, en orden de aplicación:**
  1. sombras (párpado, pliegue, V externa, lagrimal, bajo la ceja);
  2. delineado (grosor y cola);
  3. rubor;
  4. delineado de labios;
  5. labios.
- **Fuera de v1:**
  - **Cejas:** no están en el esquema de recetas. La etapa 2 cambia el esquema (hay que aprobarlo), agrega mapas UV y la ceja virtual.
  - **Base, contorno, iluminador y pestañas:** no se miden con confianza.
- **Voz:** TextToSpeech de Android dentro del plugin (`CoachVoice.kt`), sin dependencias nuevas.
  - Cada indicación corta la anterior.
  - Botón para silenciar.
  - Si el teléfono no tiene voz para el idioma, se avisa una vez y queda solo el texto.
  - El manifest del plugin declara la consulta del servicio de voz (`<queries>`), obligatoria desde Android 11.
- **Privacidad:** el recorte de la cara vive en memoria nativa, se mide y se descarta. No se guarda ni se sube ninguna imagen; solo salen números.

## Cómo mide

### Muestra en vivo (motor)

1. **Pedido:** Dart `MakeupEngine.sampleLiveLook()` → Kotlin `EngineSession.sampleLiveLook()` (hilo de fondo) → `nativeLookSampleRequest`.
2. **Recorte (hilo de render, `Renderer::runLookSample`):**
   - en el próximo frame con la cara entera (fundido en 1), recorta el ROI de los landmarks (×`kLookSampleRoiScale`) a `kLookSampleSize`² RGBA;
   - usa el mismo shader de recorte y la lectura asíncrona con PBO y fence (`LookSamplePass`);
   - pasa los landmarks a px del recorte.
   - Sin allocations: los buffers se crean con el Renderer y el estado es atómico (idle → requested → inFlight → ready → idle).
3. **Medición (hilo del analizador):** `nativeLookSampleTake` mide con `analyzeLiveSample`, que es el `analyzeLook` de "Desde foto", con los landmarks del tracker en lugar de correr los modelos otra vez.
   - La distancia entre ojos vuelve en **px de cámara**: el recorte normaliza el tamaño de la cara, y es la de cámara la que dice si está lejos.
   - Si en 1,5 s no hubo cara, vuelve null ("Mirá de frente").
4. **Concurrencia:** `nativeDestroy` y cada medición van bajo el mismo lock en `EngineSession`.

### Comparación (`lib/features/coach/domain/coach.dart`, Dart puro)

**Modelo del motor para pintar una capa:** `base + t · (color − base)`, con la L escalada por `lumaFollow`.
- Se despeja la `t` que mejor explica lo observado (proyección, recortada a [0; 1,5]).
- Si ni la mejor `t` se parece (ΔE > `toneTolerance`), el tono no es el del look:
  - más oscuro o más claro si domina la L;
  - otro tono si domina la croma.
- Si no, compara `t` con la opacidad de la receta: por debajo de 1 − `amountLow` **falta**; por encima de 1 + `amountHigh` **sobra**.

**Delineado:** el grosor y la cola medidos se pasan a unidades de la receta con el mismo mapeo inverso de "Desde foto". Se compara ± `linerThicknessTolerance` y ± `wingTolerance`.

**Estabilidad (`CoachSession`):**
- la primera lectura de una zona vale; para cambiar hacen falta 2 iguales seguidas;
- en foco queda la primera zona que no está bien;
- la misma indicación no se repite antes de 6 s;
- "Listo" se dice una sola vez.
- Sin cara, cara lejos o sin piel de referencia (luz), se avisa y los veredictos no se tocan.

Todos los umbrales están en `CoachPolicy` (`coach_policy.dart`): son **valores iniciales a calibrar en el E20**.

## Límite conocido: resolución del delineado

- En la cámara frontal a 720p, con la cara a ~30 cm, un delineado fino mide 1–2 px.
- Con los ojos a menos de `minEyeDistanceForLinerPx` (170 px de cámara), la guía dice "Acercate para revisar el delineado" en lugar de opinar.
- En el test de host (`live_look_sample_test.cpp`), un delineado de 0,3 en una cara de ~360 px no se distingue; uno de 0,7 sí.

## Costo

| Qué | Dónde | Costo |
|---|---|---|
| Recorte de la cara | GPU | 512² × 4 lecturas, una vez por muestra |
| Lectura del recorte | GPU → CPU | 1 MB, una vez por muestra |
| Medición | CPU, hilo de fondo | `analyzeLook` + un `StillImage` de 1 MB, una vez por muestra |
| Comparación | Dart | despreciable |

- Mientras la guía corre no se dibuja maquillaje virtual, salvo al apretar "ver el look". El render queda más liviano que el filtro.
- La línea `COACH` en logcat lleva los ms por muestra, la tasa del tracker, los fps, el foco y los veredictos.

## Para probar en el E20

`flutter run --profile -d <id>` → catálogo → un look con labios, rubor y delineado → **Guíame**.

1. **Referencia:** con la cara lavada, "Tomar referencia".
2. **Labial:**
   - sin labial: tiene que decir que falta;
   - con poco: falta;
   - con la cantidad del look: bien;
   - con un labial de otro color: el tono no es el del look.
3. **Delineado:** acercate a la cámara; probar uno corto y uno largo con cola.
4. **Rubor:** primero apenas, después de más.
5. **Toma:** girar la cara y alejarse; tiene que pedir que mires de frente o te acerques.
6. **Logcat:** pasame las líneas `COACH`, en particular `ms=` (cuánto tarda cada medición) y `hz=` (que el tracker no baje de su tasa). Si alguna indicación no coincide con lo que ves, anotá cuál era y qué tenías puesto: con eso calibro `CoachPolicy`.

## Revisión `perf-auditor` (2026-10-20)

No encontró allocations por frame, ni JNI por frame, ni carreras de memoria.

**Aplicado:**
- Sin capas que dibujar (la guía tiene tracker pero no receta), la malla no se sube al VBO.
- La malla suave compara cuadrados en lugar de `hypot` por arista.
- La guía tiene su propio hilo de fondo: esperar la cara no frena los análisis del Studio.
- `setLanguage` del TextToSpeech se llama solo si cambia el idioma.
- La referencia no espera muestras en segundo plano.
- La línea `COACH` no se calcula en release.

**A medir en el E20:**
- costo de `uploadMesh` con la malla suave encendida y apagada;
- fps y temperatura con 4× triángulos y todas las capas;
- p95/p99 del frame durante la guía, sobre todo cuando coinciden el recorte del tracker y la muestra;
- memoria durante la guía (~3 MB entre buffer, PBO e imagen por muestra).
