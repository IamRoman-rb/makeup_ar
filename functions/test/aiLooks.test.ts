// handleSaveAiLook / handleDeleteAiLook con un store en memoria: sin emuladores.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import { AiLookDeps, AiLookDoc, AiLookStore, MAX_AI_LOOKS, handleDeleteAiLook, handleSaveAiLook } from '../src/aiLooks';

const red = {
  schema: 'makeup-recipe/2',
  name: 'Rojo',
  lips: { color: '#B3122D', opacity: 0.85, finish: 'satin' },
};

class MemoryStore implements AiLookStore {
  looks = new Map<string, Map<string, AiLookDoc>>();
  next = 0;
  async addIfBelow(uid: string, look: AiLookDoc, max: number) {
    const mine = this.looks.get(uid) ?? new Map<string, AiLookDoc>();
    if (mine.size >= max) return null;
    const id = `look${this.next++}`;
    mine.set(id, look);
    this.looks.set(uid, mine);
    return id;
  }
  async remove(uid: string, id: string) {
    return this.looks.get(uid)?.delete(id) ?? false;
  }
}

function deps() {
  const store = new MemoryStore();
  const logs: Record<string, unknown>[] = [];
  const d: AiLookDeps = { store, now: () => new Date('2026-10-15T12:00:00Z'), log: (e) => logs.push(e) };
  return { d, store, logs };
}

async function expectCode(promise: Promise<unknown>, code: string) {
  await assert.rejects(promise, (error: unknown) => error instanceof HttpsError && error.code === code);
}

const alice = { uid: 'alice' };

test('guardar: sin sesión, unauthenticated', async () => {
  await expectCode(handleSaveAiLook(undefined, { recipe: red }, deps().d), 'unauthenticated');
});

test('guardar: receta válida queda en el usuario, sin el texto del pedido', async () => {
  const { d, store, logs } = deps();
  const { id } = await handleSaveAiLook(alice, { recipe: red, prompt: 'labios rojos', source: 'prompt' }, d);
  const saved = store.looks.get('alice')?.get(id);
  assert.ok(saved);
  assert.deepEqual(saved.recipe, red);
  assert.equal(saved.name, 'Rojo');
  assert.equal(saved.recipeSchema, 'makeup-recipe/2');
  assert.deepEqual(saved.source, { type: 'prompt' });
  assert.ok(!JSON.stringify(saved).includes('labios rojos'));
  assert.ok(!JSON.stringify(logs).includes('labios rojos'));
});

test('guardar: receta inválida o source desconocido, invalid-argument', async () => {
  const { d, store } = deps();
  const bad = [
    null,
    {},
    { recipe: { ...red, shader: 'void main(){}' } },
    { recipe: { ...red, lips: { color: '#ZZZZZZ', opacity: 0.5 } } },
    { recipe: { ...red, name: 'x'.repeat(20000) } },
    { recipe: red, source: 'image' },
  ];
  for (const input of bad) await expectCode(handleSaveAiLook(alice, input, d), 'invalid-argument');
  assert.equal(store.looks.size, 0);
});

test(`guardar: tope de ${MAX_AI_LOOKS} looks por usuario`, async () => {
  const { d } = deps();
  for (let i = 0; i < MAX_AI_LOOKS; i++) await handleSaveAiLook(alice, { recipe: red }, d);
  await expectCode(handleSaveAiLook(alice, { recipe: red }, d), 'resource-exhausted');
  // Otro usuario no se ve afectado.
  assert.ok((await handleSaveAiLook({ uid: 'bob' }, { recipe: red }, d)).id);
});

test('borrar: solo los propios; id inválido o inexistente falla', async () => {
  const { d, store } = deps();
  const { id } = await handleSaveAiLook(alice, { recipe: red }, d);
  await expectCode(handleDeleteAiLook(undefined, { id }, d), 'unauthenticated');
  await expectCode(handleDeleteAiLook({ uid: 'bob' }, { id }, d), 'not-found');
  await expectCode(handleDeleteAiLook(alice, { id: '../usage/20261015' }, d), 'invalid-argument');
  await expectCode(handleDeleteAiLook(alice, {}, d), 'invalid-argument');
  assert.deepEqual(await handleDeleteAiLook(alice, { id }, d), { deleted: true });
  assert.equal(store.looks.get('alice')?.size, 0);
  await expectCode(handleDeleteAiLook(alice, { id }, d), 'not-found');
});
