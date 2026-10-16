// LLM falso del emulador: variantes válidas, deterministas y caída simulada.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import { GenerateDeps, MAX_VARIANTS, handleGenerate } from '../src/generateRecipe';
import { FAKE_MODEL, FAKE_UNAVAILABLE_TAG, FakeLlmClient } from '../src/llm/fakeLlmClient';
import { LlmUnavailableError } from '../src/llm/llmClient';
import { isValidRecipe } from '../src/recipeSchema';

const llm = new FakeLlmClient();

async function variantsFor(user: string): Promise<unknown[]> {
  const response = await llm.generate({ system: 'sistema', user });
  assert.equal(response.model, FAKE_MODEL);
  return (JSON.parse(response.text) as { variants: unknown[] }).variants;
}

test('las variantes del LLM falso cumplen el esquema', async () => {
  for (const user of ['rojo intenso', 'nude natural', 'look de fiesta', '']) {
    const variants = await variantsFor(user);
    assert.equal(variants.length, MAX_VARIANTS);
    for (const variant of variants) assert.ok(isValidRecipe(variant), JSON.stringify(variant));
  }
});

test('el LLM falso es determinista y varía con el pedido', async () => {
  assert.deepEqual(await variantsFor('rojo intenso'), await variantsFor('rojo intenso'));
  const lips = new Set<string>();
  for (const user of ['a', 'b', 'c', 'd', 'e', 'f']) {
    for (const variant of await variantsFor(user)) lips.add((variant as { lips: { color: string } }).lips.color);
  }
  assert.ok(lips.size > 3, `solo ${lips.size} colores distintos`);
});

test('las 3 variantes de un pedido son distintas', async () => {
  const colors = (await variantsFor('rojo intenso')).map((v) => (v as { lips: { color: string } }).lips.color);
  assert.equal(new Set(colors).size, MAX_VARIANTS);
});

test(`${FAKE_UNAVAILABLE_TAG} simula el modelo caído`, async () => {
  await assert.rejects(llm.generate({ system: 's', user: `rojo ${FAKE_UNAVAILABLE_TAG}` }), LlmUnavailableError);
});

test('punta a punta con handleGenerate: 3 variantes válidas y unavailable con la marca', async () => {
  const counts = new Map<string, number>();
  const deps: GenerateDeps = {
    llm,
    quota: {
      async consume(uid, day, limit) {
        const key = `${uid}/${day}`;
        const count = counts.get(key) ?? 0;
        if (count >= limit) return false;
        counts.set(key, count + 1);
        return true;
      },
    },
    isAdmin: async () => false,
    now: () => new Date('2026-10-16T12:00:00Z'),
    log: () => {},
  };
  const user = { uid: 'user-1' };
  const result = await handleGenerate(user, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, deps);
  assert.equal(result.variants.length, MAX_VARIANTS);
  assert.equal(result.model, FAKE_MODEL);
  await assert.rejects(
    handleGenerate(user, { kind: 'prompt', prompt: `rojo ${FAKE_UNAVAILABLE_TAG}`, locale: 'es' }, deps),
    (error: unknown) => error instanceof HttpsError && error.code === 'unavailable',
  );
});
