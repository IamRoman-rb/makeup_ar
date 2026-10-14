# F4: imagen → receta y foto de producto → paleta

Sigue a F3 (`STUDIO.md`). Diseño de origen: `motor_ar_propio.md` §10.5 y §10.6, y el prompt de F4 en §11.6. Referencia ejecutable: `tools/studio/sample_region_reference.py`.

## Decisiones

1. **Todo en el teléfono.** La foto se decodifica, se analiza y se descarta en el dispositivo. Al Studio solo llegan números (colores OKLab, puntajes y cantidades de muestras).
   - **Por qué:** no se sube ninguna cara a un servidor (`CLAUDE.md`, "No hacer"), no hay costo nuevo y anda sin conexión.
   - **Qué se pierde:** el LLM de visión (§10.5, paso 7) aportaba el estilo de delineado, el shimmer y la presencia de regiones. Acá eso sale de medidas deterministas sobre los mapas UV del motor (ver más abajo).
   - **Si más adelante se quiere visión:** es un paso opcional con consentimiento explícito por foto. Se agrega a `generateRecipe` como `kind: image` con `imageStats`, sin la foto.
2. **Mismo tracker, mismos mapas.**
   - **Landmarks:** BlazeFace y FaceMesh-V2 en CPU, con un intérprete propio que se carga y se libera en cada análisis, para no competir con la sesión de cámara.
   - **Rectificación:** se rasterizan los triángulos de la malla en el espacio de cada mapa (labios, cara y ojos). Por cada texel se toma el punto de la foto por baricéntricas. Así las máscaras de los shaders caen sobre la foto sin lógica nueva por región.
   - **Mapas espejados:** los de cara y ojos guardan media cara y se rasterizan los dos lados (u' = min(u, 1 − u)), lo que duplica las muestras.
3. **Píxeles en C++, receta en Dart.**
   - **C++** (`cpp/studio/`, sin GL, con tests de host) mide: piel base, color robusto y `gloss_score` por región, perfil del delineado y del wing, y paleta K-means.
   - **Dart** (`lib/features/studio/domain/image_recipe.dart`, dominio puro) arma la receta:
     - política de opacidad e inversión del modelo de sombreado del motor;
     - gamut y presencia de regiones;
     - confianza y error de ajuste por región;
     - tres variantes (fiel, intensa, sutil).
4. **Sin dependencias nuevas.** `image_picker` ya está en la app. La decodificación y la orientación EXIF se hacen con el framework de Android (`BitmapFactory` y `android.media.ExifInterface`, minSdk 24).

## Medidas (C++)

| Región | Máscara | Qué se mide |
|---|---|---|
| Piel base | Parches en frente, puente de la nariz y mentón (UV de landmarks 151, 9, 6, 168, 175 y 199) | Mediana robusta OKLab. Es la referencia sin maquillaje. |
| Labios | Mapa de labios R >= 0,5 | Color robusto y `gloss_score`. |
| Delineado de labios | Mitad interna del anillo (R >= 0,5 y B < `kLipLinerEdge`) | Color robusto. Hay delineado si difiere del interior del labio. |
| Rubor | Gaussiana de cada placement (spread 0,5) en el mapa de cara, peso >= 0,5 | Color robusto de cada placement. Gana el que más se aparta de la piel. |
| Sombras | Mapa de ojos A (párpado, pliegue, V externa, lagrimal) y B.r (hueso de la ceja), canal >= 0,5 y lejos de la línea de pestañas | Color robusto y `gloss_score`, que da el acabado. |
| Delineado de ojos | B.g: distancia a la línea de pestañas en 12 franjas | Fracción de texels oscuros por franja. El grosor es la última franja contigua mayoritariamente oscura. El color es el de esos texels. |
| Wing | B.b < borde del delineado, avance B.a en 10 franjas | Ídem a lo largo del avance. Da el largo del wing. |

- **Muestreo robusto:** el mismo que el script de referencia: se descarta el 5 % más oscuro y el 8 % más claro en L y se toma la mediana por canal.
- **`gloss_score`:** la fracción de muestras con L > mediana + 0,12, dividida por 0,06 y recortada a [0, 1].
- **Rechazos, con su motivo:**
  - sin cara;
  - cara chica (distancia entre ojos < 60 px);
  - presencia baja;
  - perfil marcado (|yaw| alto, medido con la nariz respecto de los ojos).

## Receta (Dart)

El motor pinta `obs = piel + w · (color · s − piel)`. Sobre la piel media, s ≈ 1. La L se mezcla con `lumaFollow`: en los labios 0,8 por defecto y en el resto 1.

1. **Política de opacidad**, igual que §10.5:
   - labios 0,85, delineado de labios 0,9 y rubor 0,35;
   - sombras 0,5 y delineado de ojos 0,9.
2. **Color objetivo:**
   - ab_t = ab_piel + (ab_obs − ab_piel) / w;
   - L_t = L_piel + (L_obs − L_piel) / (w · lumaFollow).
   - Si sale de gamut sRGB, se sube w hasta que entre, como en la referencia.
3. **Presencia** (umbrales iniciales; se calibran con fotos reales):
   - **sombras:** ΔE OKLab contra la piel > 0,045;
   - **rubor:** Δab > 0,02 y más rojo que la piel;
   - **delineado:** grosor medido > grosor mínimo del motor + 0,05;
   - **wing:** avance > 0,15;
   - **delineado de labios:** ΔE contra el interior del labio > 0,05 y más oscuro.
   - **Labios:** siempre se incluyen, porque el color del labio de la foto es parte del look.
4. **Acabado:**
   - **labios:** mate si el puntaje es < 0,15, satinado si es < 0,5 y brillo (gloss = puntaje) si es mayor;
   - **sombras:** mate, satinado o shimmer con los mismos cortes.
5. **Confianza por región:** se combinan la fracción de texels válidos y el pose. Con confianza < 0,4 la región se descarta.
6. **Error de ajuste:** el ΔE entre lo que el motor pintaría con la receta sobre la piel de la foto y el color observado.
   - Es el criterio de salida de F4 del §7: debe quedar por debajo de 0,02 (unas 2 diferencias apenas visibles).
   - Por construcción solo lo rompen el gamut y los recortes, así que también mide si la política de opacidad alcanza.
7. **Variantes:** fiel, intensa (opacidades × 1,25) y sutil (× 0,65), validadas por `RecipeValidator`.

## Paleta (C++)

- **Preparación:** la foto se reduce a un máximo de 96 px por lado y se descartan:
  - el fondo: los píxeles a ΔE < 0,05 de la mediana del borde;
  - los blancos casi puros.
- **Agrupamiento:** K-means en OKLab con k = 5, semillas por el punto más lejano (determinista) y 12 iteraciones.
- **Salida:** se unen los clusters a ΔE < 0,03 y quedan los swatches ordenados por área.
- **En el Studio:** tocar un swatch y elegir la capa (labios, rubor, sombra o delineado) aplica el color con `RecipeEdits`. Si la capa no existe, se agrega con una opacidad por defecto.

## Archivos

- **C++:** `cpp/studio/{still_image,still_face_locator,uv_rectify,region_sampling,look_analysis,palette}.{h,cpp}`. Tests de host en `test_native/studio_*_test.cpp`.
- **JNI y Kotlin:** `nativeStill*` en `jni_bridge.cpp` y `NativeBridge.kt`, más `StillImageAnalyzer.kt`, que hace la decodificación, el EXIF, el CPU de LiteRT y su propio hilo.
- **Canal:** `analyzeFaceImage({bytes})` → `{status, values: List<double>}` y `extractPalette({bytes})` → `List<double>`.
- **Plugin Dart:**
  - `FaceImageAnalysis` y `PaletteSwatch` en `makeup_engine.dart`;
  - los índices se comparten con C++ (`look_analysis.h`) por constantes, como las stats.
- **App:**
  - **dominio:** `studio/domain/image_recipe.dart` (`ImageRecipeBuilder`) e `image_look.dart` (`IImageLookAnalyzer` y las medidas en Dart);
  - **datos:** `studio/data/engine_image_analyzer.dart`;
  - **Studio:** botones "Desde foto" y "Paleta de producto", un aviso de privacidad y la confianza por región.
  - `LookSourceType.image`.
- **Docs:** este archivo, `STUDIO.md` y `CLAUDE.md` si cambia algún comando.

## Verificación

- **Tests de host:**
  - muestreo robusto: mate da ~0, brillante ~1 y el color robusto queda a ±0,005 por canal sRGB, como en el script;
  - rectificación sobre una "foto" sintética pintada desde la malla canónica: se recupera el color de cada región;
  - delineado y wing sintéticos;
  - paleta con 3 colores sobre un fondo blanco.
- **Dart:**
  - el constructor de recetas: identificabilidad (el error de render queda en 0 con las políticas 0,35, 0,6 y 0,85), gamut, ausencias y variantes válidas;
  - el widget del Studio con un analizador falso.
- **En el E20, lo corrés vos:** Studio → "Desde foto", con fotos propias o autorizadas. Anotar el error de ajuste y la confianza por región y comparar el preview con la foto.
  - Criterio de §7: 20 fotos con error de ajuste < 0,02 y un look reconocible.
  - Los umbrales de presencia se recalibran con esos resultados.

## Fuera de alcance

- El LLM de visión (opcional, con consentimiento).
- Base, contorno e iluminador desde la foto: la base copiaría el tono de piel de otra persona.
- Pestañas desde la foto: no se miden. Si hay ojos maquillados, la receta lleva pestañas por defecto (opacidad 0,8).
- QA automático (F5).

## Estado (implementado)

- **C++** (`cpp/studio/`, 17 tests de host en `test_native/studio_*_test.cpp`):
  - el muestreo reproduce el script: mate da ≤ 0,05, brillante ≥ 0,95 y el color robusto queda a ±0,005 sRGB;
  - la cara sintética pintada desde los mapas recupera piel, labios, rubor (con su placement), sombra, grosor del delineado (±0,05) y wing (±0,1);
  - una foto espejada da lo mismo y los triángulos de costado no se muestrean;
  - la paleta separa 3 colores del fondo y del borde mezclado.
  - **Paleta:** los píxeles de borde (un salto de color con un vecino ≥ 0,06) se descartan. Sin eso, el antialias entre el producto y el fondo armaba swatches falsos.
- **Kotlin:** `StillImageAnalyzer` (EXIF, reducción a 1280 px y LiteRT en CPU) y `analyzeFaceImage`/`extractPalette` en un executor propio. `StillImageMathTest` en la JVM.
- **Dart:** `ImageRecipeBuilder` (10 tests), `RecipeEdits.withColorOrAdd` y el Studio ("Desde foto", con un aviso que aparece una vez por pantalla, más la confianza por región y "Paleta de producto"; 3 tests de widget).
  - **Arnés del tracker:** botones "Foto" y "Paleta" que dejan líneas `PHOTO` y `PALETTE` en logcat.

## Para probarlo en el E20

Sin Firebase ni deploy: con el arnés.

1. `flutter run --profile -t lib/main_tracker.dart -d <id>`.
2. Tocar "Foto" y elegir una foto de frente con maquillaje, propia o autorizada. Aparecen 3 chips nuevos (Foto · fiel, intensa y sutil); al tocarlos se ve el look en vivo.
3. En logcat (`adb logcat -s flutter`) se lee una línea así:
   ```
   PHOTO ms=… status=ok yaw=… liner=… wing=… worstFit=… regions=[lips:conf/ΔE …]
   ```
4. Tocar "Paleta" con una foto de producto. Da la línea `PALETTE ms=… #RRGGBB nn% …`.

Anotar por foto:
- `ms` (tiempo total, con la cámara corriendo);
- `worstFit`, que tiene que ser < 0,02;
- las regiones detectadas;
- si el look se reconoce en la vista previa.

Con 20 fotos se cierra el criterio del §7 y se recalibran los umbrales de presencia (`ImageRecipePolicy`, `kLinerDarkDelta`).

## Verificación y revisión de cierre

- **Emulador** (x86_64, cámara virtual; no reemplaza al E20):
  - **Arranque:** el APK del arnés carga el motor con las funciones JNI nuevas y el render sigue a 29 fps.
  - **"Paleta"** con una imagen sintética (rojo `#B41432`, marrón `#784632` y rosa `#C88CA0` sobre blanco) da `PALETTE ms=110 #B41332 51% #794633 34% #C78CA0 15%`.
  - **"Foto"** con esa misma imagen, que no tiene cara, da `PHOTO ms=83 status=noFace`, sin errores. Sí corrió la carga de los modelos en CPU y el detector.
  - **Pendiente:** el camino con cara solo está probado en tests de host. En el E20 hay que probarlo con fotos reales.
- **perf-auditor:** no encontró nada en los hilos de render ni de UI. Se aplicó:
  - **Liberación ante fallas:** el handle nativo, el `Environment`, los modelos y los bitmaps se liberan también ante un `Error`.
  - **Prioridad:** el hilo `makeup-still` va en prioridad de fondo y usa 1 hilo de LiteRT con la cámara activa.
  - **Paleta:** decodifica a 384 px y usa la tabla de sRGB a lineal.
  - **Copia ARGB:** se hace por bloques de 64 filas.
  - **Landmarks:** los que no son finitos dan `badImage`.
  - **UI:** los botones se deshabilitan mientras el aviso o la galería están abiertos.
  - **Excepciones C++ en JNI:** no aplica, el motor compila con `-fno-exceptions`. Una falla de memoria aborta igual; la mitigación es achicar los picos, como se hizo arriba.
- **shader-reviewer:** F4 no toca shaders.

## P8: más fiel a la foto (primeras pruebas en el E20)

Con dos fotos de referencia salía un look muy distinto: labios bordó, delineado negro y casi sin sombra. La referencia tenía párpado violeta con brillo, párpado inferior verde agua y boca en degradé violeta a verde agua. Cambios:

- **Por lado:** en los mapas espejados (rubor, cada sombra, delineado y wing), cada región sale del lado con más maquillaje entre los que se ven al menos `kSideMinCoverage` (0,5) de su máscara.
  - Antes se juntaban los dos lados. Con la cara de 3/4 la cobertura quedaba en ~0,5 y la región se descartaba por baja confianza. Con un look de un solo lado, el color se mezclaba con el lado natural.
- **Labio bicolor:** un 2-means en croma (a, b). Si los grupos están a ≥ 0,06 y el chico tiene ≥ 25 %, se queda el que más se aparta de la piel (si tiene ≥ 35 %); si no, el más grande. Antes la mediana daba un color intermedio.
- **Diagnóstico:** la línea `PHOTO` del arnés muestra los colores observados (`seen=[skin:… lips:… cheeks:… eyes:… liner:…]`), si el labio era bicolor y los lados usados (`sides`: bit 0 rubor, bit 1 párpado, bit 2 delineado).
- **Tests de host:** look de un solo lado, foto de 3/4 y labio bicolor.

Lo que la receta todavía no puede representar:
- **Párpado inferior** (el verde agua debajo del ojo): el esquema no tiene esa región.
- **Degradés y labios de dos colores:** un solo color por región.
- **Brillos de color** (duocromos): el shimmer del motor es blanco.

Fotos de internet: sirven para probar en el teléfono, pero para el catálogo hacen falta fotos propias o con permiso (§10.5).
