# F2: plan de la Cloud Function `generateRecipe` (para aprobar)

El prompt F2 del informe pide **"plan primero y mostrame el plan antes de editar"**. Esto es el plan; no se escribió código. Contrato: `motor_ar_propio.md` §10.4 y §10.9.

## Situación de partida (de `AUDIT.md`)

- **Hoy la app no llama a ningún LLM:** el servicio de Groq se borró en `effe2d6` y en ningún commit hubo una key de Groq. F2 no "saca una key de la app": construye el camino seguro **antes** de que vuelva la generación por IA.
- No existe `functions/` y `firebase.json` no tiene sección `functions`.
- La receta, el validador y los presets ya existen en Dart (F1), y los casos de prueba compartidos están en `test/fixtures/recipe_v2_cases.json`.

## Decisiones que necesito antes de escribir código

| # | Decisión | Opciones | Recomendación |
|---|---|---|---|
| 1 | **Plan Blaze de Firebase** | Cloud Functions y Secret Manager exigen el plan pago (con cuota gratuita) | Necesario; definir un presupuesto con alerta de facturación (p. ej. USD 5/mes) |
| 2 | **Proveedor de LLM** | Groq (como el informe) / Gemini vía Vertex AI / otro | Groq por costo y latencia. El código queda detrás de una interfaz `LlmClient` para cambiarlo sin tocar la validación |
| 3 | **Dependencias del servidor** (Node 22, TypeScript) | `firebase-functions`, `firebase-admin`, `ajv` (validador JSON Schema 2020-12 con regex ECMA, ver divergencia en `motor_ar_propio.md` §10.11). El cliente HTTP es el `fetch` nativo de Node, sin SDK de Groq | Las tres, todas MIT o Apache 2.0 |
| 4 | **Dependencias de la app** | `cloud_functions` y `firebase_app_check` (FlutterFire, BSD-3) | Las dos. App Check en Android usa Play Integrity, y en debug un *debug provider* |
| 5 | **Cuota por usuario** | N generaciones por día | Arrancar con 20/día para admins y 5/día para el resto; queda en una constante |
| 6 | **¿Quién puede generar?** | Solo admins (Studio, F3) / todos | Solo admins hasta F3. Requiere arreglar antes la escalada a admin (`AUDIT.md` §5.1): si no, cualquiera se hace admin y consume la cuota |

## Diseño

```
functions/
  package.json            # node 22, deps de la decisión 3; scripts build/test/lint
  tsconfig.json
  src/index.ts            # export generateRecipe
  src/generateRecipe.ts   # onCall({enforceAppCheck: true, secrets: [GROQ_API_KEY]})
  src/recipeSchema.ts     # carga docs/ar_engine/recipe_v2.schema.json (copiado al build) + Ajv
  src/quota.ts            # transacción users/{uid}/usage/{yyyymmdd} (UTC)
  src/llm/groqClient.ts   # fetch a la API compatible con OpenAI, JSON mode, timeout 15 s, 1 reintento
  src/prompt.ts           # system prompt del §10.4, sin cambios
  test/schemaParity.test.ts  # usa test/fixtures/recipe_v2_cases.json: misma paridad que Dart y Python
  test/generateRecipe.test.ts # emulador de Functions + Firestore, LLM simulado
```

Flujo de `generateRecipe({kind:"prompt", prompt, locale})`:

1. `request.auth` obligatorio → si falta, `unauthenticated`. App Check obligatorio por `enforceAppCheck` → si falla, `failed-precondition`.
2. Validación de entrada: `prompt` es texto de 1 a 300 caracteres, `locale` está en `es|en|pt|fr` y `kind == "prompt"`. Si no cumple, `invalid-argument`. `image` y `remix` quedan para F4/F3 y por ahora devuelven `invalid-argument`.
3. Cuota: transacción que lee y suma en `users/{uid}/usage/{yyyymmdd}`. Si se pasa del límite, `resource-exhausted`. La cuota se descuenta **antes** de llamar al LLM, para que los errores no sirvan para esquivarla.
4. LLM con `response_format: json_object` y temperatura 0.3. Si hay timeout o error 5xx, `unavailable`, y la app usa un preset local (`RecipePresets.closestTo`).
5. Parseo y validación de cada variante con Ajv. Las inválidas se descartan sin reparar. Se devuelven de 0 a 3 variantes, más `model` y `requestId`.
6. Log estructurado con `requestId`, uid, cantidad de variantes válidas e inválidas y latencia. **Nunca** se loguea el texto del prompt completo ni la key.

App (`lib/features/ar/data/recipe_generation_service.dart`): llama a la callable, **vuelve a validar** cada variante con `RecipeValidator` (defensa en profundidad), mapea los errores a mensajes para el usuario y, si no queda ninguna variante válida, usa el preset local.

Reglas de Firestore: `users/{uid}/usage/**` no necesita regla nueva, porque las reglas no se heredan a subcolecciones y sin regla el cliente no tiene acceso. **No hay que tocar `firestore.rules` para F2.** Igual se agrega un test con el emulador que confirma que el cliente no puede leer ni escribir `usage`.

## Tests (criterio de aceptación)

- `npm test` en `functions/`: paridad de esquema (los mismos 44 casos), entrada inválida, sin auth, cuota agotada (la llamada 6 de 5), LLM caído, LLM que devuelve basura (cero variantes) y LLM que devuelve 2 variantes válidas y 1 con `shader`.
- `flutter test`: el servicio de la app con la callable simulada (variantes válidas, inválidas y el fallback a preset).
- Ninguna key en el repo. Se agrega un chequeo `git grep -nE "gsk_[A-Za-z0-9]{10,}"` vacío en el script de test.

## Lo que no hace F2

- No despliega: `firebase deploy --only functions` lo corrés vos, después de `firebase functions:secrets:set GROQ_API_KEY`.
- No configura cuotas reales ni presupuestos en Google Cloud. Esos los definís vos (decisiones 1 y 5).
