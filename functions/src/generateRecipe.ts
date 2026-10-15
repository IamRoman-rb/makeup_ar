// Lógica de la callable generateRecipe (contrato: motor_ar_propio.md §10.4 y
// docs/ar_engine/F2_PLAN.md). Sin dependencias de Firebase salvo HttpsError:
// todo lo externo entra por GenerateDeps, así se testea sin emuladores.
//
// Flujo: auth -> entrada -> cuota según el rol (se descuenta ANTES del LLM, así
// los errores no sirven para esquivarla) -> LLM -> cada variante validada con
// el esquema (las inválidas se descartan, nunca se reparan) -> log sin texto.
// App Check lo exige onCall({enforceAppCheck: true}) en index.ts.
import { randomUUID } from 'node:crypto';

import { HttpsError } from 'firebase-functions/v2/https';

import { LlmClient, LlmUnavailableError } from './llm/llmClient';
import { promptSystem, promptUser, remixSystem, remixUser } from './prompt';
import { QuotaStore, dayKey } from './quota';
import { isValidRecipe } from './recipeSchema';

export const MAX_PROMPT_LENGTH = 300;
export const MAX_VARIANTS = 3;
// Generaciones por día (UTC): admins (Studio) y usuarios finales ("Mis looks").
export const ADMIN_DAILY_QUOTA = 20;
export const USER_DAILY_QUOTA = 5;
// Tope del JSON de la receta base de un remix (= RecipeValidator.maxJsonLength).
export const MAX_RECIPE_JSON = 16 * 1024;
export const LOCALES: readonly string[] = ['es', 'en', 'pt', 'fr'];

export interface GenerateDeps {
  llm: LlmClient;
  quota: QuotaStore;
  isAdmin(uid: string): Promise<boolean>;
  now(): Date;
  log(entry: Record<string, unknown>): void;
}

export interface GenerateResult {
  variants: unknown[];
  model: string;
  requestId: string;
}

interface ParsedInput {
  kind: 'prompt' | 'remix';
  text: string;
  locale: string;
  baseRecipe?: unknown;
}

function parseInput(data: unknown): ParsedInput {
  if (typeof data !== 'object' || data === null) throw new HttpsError('invalid-argument', 'Entrada inválida.');
  const input = data as Record<string, unknown>;
  const kind = input.kind;
  if (kind === 'image') throw new HttpsError('invalid-argument', 'Imagen -> receta todavía no está disponible.');
  if (kind !== 'prompt' && kind !== 'remix') throw new HttpsError('invalid-argument', 'kind inválido.');
  const text = typeof input.prompt === 'string' ? input.prompt.trim() : '';
  if (text.length === 0 || text.length > MAX_PROMPT_LENGTH) {
    throw new HttpsError('invalid-argument', `El texto tiene que tener entre 1 y ${MAX_PROMPT_LENGTH} caracteres.`);
  }
  const locale = input.locale;
  if (typeof locale !== 'string' || !LOCALES.includes(locale)) {
    throw new HttpsError('invalid-argument', 'locale inválido.');
  }
  if (kind === 'prompt') return { kind, text, locale };
  const baseRecipe = input.baseRecipe;
  if (JSON.stringify(baseRecipe ?? null).length > MAX_RECIPE_JSON || !isValidRecipe(baseRecipe)) {
    throw new HttpsError('invalid-argument', 'La receta base no es válida.');
  }
  return { kind, text, locale, baseRecipe };
}

// Variantes válidas de la respuesta del modelo (0 a MAX_VARIANTS).
export function validVariants(text: string): { valid: unknown[]; invalid: number } {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { valid: [], invalid: 1 };
  }
  const variants = (parsed as { variants?: unknown })?.variants;
  if (!Array.isArray(variants)) return { valid: [], invalid: 1 };
  const valid: unknown[] = [];
  let invalid = 0;
  for (const variant of variants.slice(0, MAX_VARIANTS)) {
    if (isValidRecipe(variant)) valid.push(variant);
    else invalid++;
  }
  return { valid, invalid: invalid + Math.max(0, variants.length - MAX_VARIANTS) };
}

export async function handleGenerate(
  auth: { uid: string } | undefined,
  data: unknown,
  deps: GenerateDeps,
): Promise<GenerateResult> {
  if (!auth) throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  const input = parseInput(data);
  const limit = (await deps.isAdmin(auth.uid)) ? ADMIN_DAILY_QUOTA : USER_DAILY_QUOTA;
  if (!(await deps.quota.consume(auth.uid, dayKey(deps.now()), limit))) {
    throw new HttpsError('resource-exhausted', 'Se agotó la cuota diaria de generaciones.');
  }

  const requestId = randomUUID();
  const started = deps.now().getTime();
  const request =
    input.kind === 'prompt'
      ? { system: promptSystem(), user: promptUser(input.locale, input.text) }
      : { system: remixSystem(), user: remixUser(input.locale, input.text, input.baseRecipe) };
  let response;
  try {
    response = await deps.llm.generate(request);
  } catch (error) {
    deps.log({ requestId, uid: auth.uid, kind: input.kind, outcome: 'llm_unavailable',
      latencyMs: deps.now().getTime() - started, error: error instanceof Error ? error.message : 'desconocido' });
    if (error instanceof LlmUnavailableError) throw new HttpsError('unavailable', 'El generador no está disponible.');
    throw new HttpsError('internal', 'Error del generador.');
  }
  const { valid, invalid } = validVariants(response.text);
  // Nunca el texto del pedido ni la respuesta: solo números.
  deps.log({ requestId, uid: auth.uid, kind: input.kind, model: response.model, promptLength: input.text.length,
    valid: valid.length, invalid, latencyMs: deps.now().getTime() - started });
  return { variants: valid, model: response.model, requestId };
}
