// Looks generados por usuarios finales (motor_ar_propio.md §10.12-§10.13):
// users/{uid}/ai_looks/{id}. El cliente solo los lee (firestore.rules); las
// escrituras pasan por estas callables, que validan la receta con el mismo
// esquema que la app y ponen un tope por usuario. Sin dependencias de Firebase
// salvo HttpsError y el tipo Firestore: se testea con un store en memoria.
//
// Minimización: se guarda la receta, no el texto del pedido.
import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { MAX_RECIPE_JSON } from './generateRecipe';
import { isValidRecipe } from './recipeSchema';

// Looks guardados por usuario: a partir de acá hay que borrar uno para guardar otro.
export const MAX_AI_LOOKS = 30;
export const AI_LOOK_SOURCES: readonly string[] = ['prompt', 'remix'];
const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

export interface AiLookDoc {
  recipe: Record<string, unknown>;
  recipeSchema: 'makeup-recipe/2';
  name: string;
  source: { type: string };
  createdAt: Date;
}

export interface AiLookStore {
  // Agrega el look si el usuario tiene menos de [max]. null = tope alcanzado.
  addIfBelow(uid: string, look: AiLookDoc, max: number): Promise<string | null>;
  // false si no existía.
  remove(uid: string, id: string): Promise<boolean>;
}

export interface AiLookDeps {
  store: AiLookStore;
  now(): Date;
  log(entry: Record<string, unknown>): void;
}

function requireAuth(auth: { uid: string } | undefined): { uid: string } {
  if (!auth) throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  return auth;
}

export async function handleSaveAiLook(
  auth: { uid: string } | undefined,
  data: unknown,
  deps: AiLookDeps,
): Promise<{ id: string }> {
  const { uid } = requireAuth(auth);
  if (typeof data !== 'object' || data === null) throw new HttpsError('invalid-argument', 'Entrada inválida.');
  const input = data as Record<string, unknown>;
  const recipe = input.recipe;
  if (JSON.stringify(recipe ?? null).length > MAX_RECIPE_JSON || !isValidRecipe(recipe)) {
    throw new HttpsError('invalid-argument', 'La receta no es válida.');
  }
  const source = input.source ?? 'prompt';
  if (typeof source !== 'string' || !AI_LOOK_SOURCES.includes(source)) {
    throw new HttpsError('invalid-argument', 'source inválido.');
  }
  const valid = recipe as Record<string, unknown>;
  const id = await deps.store.addIfBelow(uid, {
    recipe: valid,
    recipeSchema: 'makeup-recipe/2',
    name: String(valid.name),
    source: { type: source },
    createdAt: deps.now(),
  }, MAX_AI_LOOKS);
  if (id === null) {
    deps.log({ uid, outcome: 'ai_looks_full' });
    throw new HttpsError('resource-exhausted', `Ya tenés ${MAX_AI_LOOKS} looks guardados.`);
  }
  deps.log({ uid, outcome: 'ai_look_saved', id });
  return { id };
}

export async function handleDeleteAiLook(
  auth: { uid: string } | undefined,
  data: unknown,
  deps: AiLookDeps,
): Promise<{ deleted: true }> {
  const { uid } = requireAuth(auth);
  const id = (data as { id?: unknown } | null)?.id;
  if (typeof id !== 'string' || !ID_PATTERN.test(id)) throw new HttpsError('invalid-argument', 'id inválido.');
  if (!(await deps.store.remove(uid, id))) throw new HttpsError('not-found', 'El look no existe.');
  deps.log({ uid, outcome: 'ai_look_deleted', id });
  return { deleted: true };
}

// Store real: transacción que cuenta (hasta [max]) y crea, así dos guardados
// simultáneos no pasan el tope.
export class FirestoreAiLookStore implements AiLookStore {
  constructor(private readonly db: Firestore) {}

  addIfBelow(uid: string, look: AiLookDoc, max: number): Promise<string | null> {
    const collection = this.db.collection('users').doc(uid).collection('ai_looks');
    return this.db.runTransaction(async (tx) => {
      const existing = await tx.get(collection.select().limit(max));
      if (existing.size >= max) return null;
      const ref = collection.doc();
      tx.create(ref, look);
      return ref.id;
    });
  }

  async remove(uid: string, id: string): Promise<boolean> {
    const ref = this.db.collection('users').doc(uid).collection('ai_looks').doc(id);
    return this.db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot.exists) return false;
      tx.delete(ref);
      return true;
    });
  }
}
