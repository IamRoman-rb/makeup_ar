# Studio (F3): looks generados con IA

Los filtros del catálogo se crean con IA desde la app. Un admin escribe un pedido, la IA propone tres variantes, el admin las prueba en vivo, las ajusta y publica la que quiere. Un filtro es solo una receta `makeup-recipe/2`: la IA elige parámetros, nunca código (`motor_ar_propio.md` §10).

## Flujo

```
Catálogo (admin) -> "Crear con IA (Studio)"
  prompt -> generateRecipe (Cloud Function, Gemini en Vertex AI; F2_PLAN.md)
         -> 3 variantes validadas en el servidor (Ajv) y en la app (RecipeValidator)
  vista previa en vivo con el motor (TestFilterView con las variantes)
  editor: color HEX y cantidad por capa, acabado del labial, quitar capas (RecipeEdits)
  remix: "más natural", "tonos más cálidos"... sobre la variante elegida
  Guardar borrador -> look_drafts/{id}
  Publicar         -> looks/{id} (con recipe, recipeSchema, minEngine y source)
Catálogo y paso a paso -> "Probar en AR" -> espejo con el motor y ese look puesto

F4 (en el teléfono, sin LLM; F4_PLAN.md):
  "Desde foto": aviso de privacidad -> galería -> landmarks + rectificación a UV + muestreo
               -> receta (política de opacidad) -> 3 variantes con la confianza por región
  "Paleta de producto": galería -> K-means en OKLab -> tocar un color -> elegir la capa
```

## Código

| Capa | Archivo | Qué hace |
|---|---|---|
| Dominio | `lib/features/studio/domain/recipe_generator.dart` | Contrato `IRecipeGenerator` y motivos de falla. |
| | `studio_look.dart` | `StudioLook`, categorías, `lookRecipe()` (solo recetas válidas con `minEngine` <= `kMakeupEngineVersion`) e `ILookRepository`. |
| | `recipe_edits.dart` | Ediciones que nunca producen una receta inválida: pasan por el JSON y vuelven por `RecipeValidator(clampOutOfRange: true)`. |
| Datos | `lib/features/studio/data/cloud_recipe_generator.dart` | Callable con revalidación y respaldo al preset más cercano. |
| | `firestore_look_repository.dart` | Borradores y publicación. Publicar escribe el look y borra el borrador en un batch. |
| | `app_check_setup.dart` | Proveedor de App Check. |
| Presentación | `lib/features/studio/presentation/studio_screen.dart` | Pantalla, diálogo de publicación y lista de borradores. |
| | `recipe_editor_panel.dart` | Editor de capas. |
| Vista previa | `TestFilterView(options:, initialOptionId:, onOptionSelected:)` | Si cambian las opciones, conserva la elegida por id y vuelve a mandar su receta. Así cada edición se ve en vivo. |
| Entrada | `catalog_screen.dart`, `step_by_step_screen.dart` y `CameraScreen(initialLook:)` | Menú de admin y botones "Probar en AR". |
| F4: dominio | `image_look.dart`, `image_recipe.dart`, `oklab.dart` | Medidas de la foto, `IImageLookAnalyzer` e `ImageRecipeBuilder`: inversión del sombreado del motor, presencia, confianza, error de ajuste y variantes. |
| F4: datos | `engine_image_analyzer.dart` | El analizador del motor (`MakeupEngine.analyzeFaceImage`/`extractPalette`). |

## Datos y reglas

- **`look_drafts/{id}`:**
  - solo admins leen, escriben y borran;
  - siempre con `recipe` (un map).
  - Va aparte de `looks` porque las reglas no filtran consultas: con borradores dentro de `looks`, el catálogo habría necesitado `where status` y migrar los looks viejos.
- **`looks/{id}`:**
  - lectura pública, como antes;
  - escritura solo para admins;
  - si vienen, se valida el tipo de `recipe` (map), `minEngine` (int) y `recipeSchema`.
  - Los looks viejos, sin receta, siguen iguales y no muestran "Probar en AR".
- **Tests:** `firestore-tests/rules.test.mjs` (19).

## Versionado

`kMakeupEngineVersion` (`makeup_recipe.dart`) vale 1. Cada look publicado guarda `minEngine` con la versión que lo creó. Una app con un motor más viejo no ofrece el look. Hay que subir la versión cuando el motor sume algo que una receta pueda pedir.

## Tests

- `flutter test test/features/studio`: dominio, servicio y pantalla. Cubre generar, elegir, editar en vivo, guardar, publicar, el respaldo y el remix.
- La vista previa con opciones propias está en `test/features/ar/presentation/test_filter_view_test.dart`.

## Para probarlo de punta a punta

Hace falta haber hecho primero el deploy de F2 (`F2_PLAN.md`, "Para desplegar"), que incluye `firestore:rules`. Después:

1. Tu usuario tiene que tener `is_admin: true` en `users/{uid}`. Se pone desde la consola de Firebase.
2. Para usar el motor en vivo, instalá la app completa. En profile, App Check usa el proveedor debug, así que hay que registrar el token que aparece en logcat.
3. Catálogo → botón + → "Crear con IA (Studio)" → escribir un pedido → Generar → elegir y ajustar → Publicar.
4. En el catálogo aparece el look con "Probar en AR".

## QA automático (F5)

Antes de publicar, cada receta pasa los chequeos del §10.10 (`lib/features/studio/domain/recipe_qa.dart`). El panel "Control de calidad" del Studio los muestra en verde, amarillo o rojo y se recalcula en cada edición.

- **Con algo en rojo, Publicar se deshabilita.** Los borradores se guardan igual.
- **Caras de prueba sintéticas, no fotos:** los 5 tonos de piel de `tools/makeup/calibration_grid.py` con luz neutra, y el tono medio con luz cálida y fría. No hay dataset ni consentimiento que gestionar.
- **Qué se calcula:** el color del píxel medio de cada región con la matemática del motor (`lips.frag`, `face.frag`/`eyes.frag` y la adaptación a la luz).
- **Paridad:** `tools/studio/qa_reference.py` hace lo mismo con las funciones de referencia y genera `test/fixtures/qa_render_cases.json`. El test de Dart compara con tolerancia 1e-3.

| Chequeo | Rojo (bloquea) | Amarillo |
|---|---|---|
| Visibilidad | No se nota en ningún tono (ΔE < 0,008) | Apenas se nota en el tono medio (< 0,012) |
| Saturación | — | Color saturado (croma ≥ 0,15) que sale de gamut antes de s = 1,1: se lava con la luz |
| Tonos de piel | Base o iluminador suben L > 0,15 en la piel profunda (tiza) | Otra capa sube L > 0,15 (ceniza), o se pierde en el tono más claro o el más profundo |
| Cobertura | — | Delineado y wing > 0,85, base > 0,8, o rubor con spread 1 y opacidad > 0,7 |
| Rendimiento | — | 3 efectos a la vez (combinación no medida en el E20; el look completo sí: 28 fps) |

Los umbrales son iniciales, calibrados para que pasen todos los presets (`python tools/studio/qa_reference.py --report`). Hoy algunos presets dan avisos amarillos: los colores claros (Rosado fresco, el dorado de Glam) se ven ceniza sobre la piel más profunda.

## Pendiente

- **Calibrar F4** con 20 fotos en el E20 (F4_PLAN.md, "Para probarlo en el E20").
- **Usuarios finales que generan sus propios looks:** hoy solo admins.
- La imagen del catálogo es una URL opcional; todavía no se sube desde el Studio.
