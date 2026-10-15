// handleGenerate con dependencias falsas: sin emuladores ni red.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import { ADMIN_DAILY_QUOTA, GenerateDeps, USER_DAILY_QUOTA, handleGenerate, validVariants } from '../src/generateRecipe';
import { LlmClient, LlmRequest, LlmUnavailableError } from '../src/llm/llmClient';
import { QuotaStore } from '../src/quota';

const red = {
  schema: 'makeup-recipe/2',
  name: 'Rojo',
  lips: { color: '#B3122D', opacity: 0.85, finish: 'satin' },
};
const nude = { schema: 'makeup-recipe/2', name: 'Nude', lips: { color: '#B07A6A', opacity: 0.6 } };
const withShader = { ...red, name: 'Malo', shader: 'void main(){}' };

class FakeLlm implements LlmClient {
  requests: LlmRequest[] = [];
  constructor(private readonly reply: string | Error) {}
  async generate(request: LlmRequest) {
    this.requests.push(request);
    if (this.reply instanceof Error) throw this.reply;
    return { text: this.reply, model: 'fake-model' };
  }
}

class MemoryQuota implements QuotaStore {
  counts = new Map<string, number>();
  async consume(uid: string, day: string, limit: number) {
    const key = `${uid}/${day}`;
    const count = this.counts.get(key) ?? 0;
    if (count >= limit) return false;
    this.counts.set(key, count + 1);
    return true;
  }
}

function deps(reply: string | Error, admin = true) {
  const logs: Record<string, unknown>[] = [];
  const llm = new FakeLlm(reply);
  const quota = new MemoryQuota();
  const d: GenerateDeps = {
    llm,
    quota,
    isAdmin: async () => admin,
    now: () => new Date('2026-10-13T12:00:00Z'),
    log: (entry) => logs.push(entry),
  };
  return { d, llm, quota, logs };
}

const admin = { uid: 'admin-1' };
const okReply = JSON.stringify({ variants: [red, nude, withShader] });

async function expectCode(promise: Promise<unknown>, code: string) {
  await assert.rejects(promise, (error: unknown) => error instanceof HttpsError && error.code === code);
}

test('sin sesión: unauthenticated', async () => {
  await expectCode(handleGenerate(undefined, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, deps(okReply).d),
    'unauthenticated');
});

test(`usuario final: genera con cuota de ${USER_DAILY_QUOTA} por día`, async () => {
  const { d, llm } = deps(okReply, false);
  const user = { uid: 'user-1' };
  for (let i = 0; i < USER_DAILY_QUOTA; i++) {
    const result = await handleGenerate(user, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, d);
    assert.equal(result.variants.length, 2);
  }
  await expectCode(handleGenerate(user, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, d), 'resource-exhausted');
  assert.equal(llm.requests.length, USER_DAILY_QUOTA);
});

test('entrada inválida de un usuario final: no gasta cuota', async () => {
  const { d, quota } = deps(okReply, false);
  await expectCode(handleGenerate({ uid: 'user-1' }, { kind: 'prompt', prompt: '', locale: 'es' }, d),
    'invalid-argument');
  assert.equal(quota.counts.size, 0);
});

test('entrada inválida: invalid-argument', async () => {
  const { d, llm } = deps(okReply);
  const bad = [
    null,
    'texto',
    { kind: 'prompt', prompt: '', locale: 'es' },
    { kind: 'prompt', prompt: '   ', locale: 'es' },
    { kind: 'prompt', prompt: 'x'.repeat(301), locale: 'es' },
    { kind: 'prompt', prompt: 'rojo', locale: 'de' },
    { kind: 'otra', prompt: 'rojo', locale: 'es' },
    { kind: 'image', prompt: 'rojo', locale: 'es' },
    { kind: 'remix', prompt: 'más natural', locale: 'es' },
    { kind: 'remix', prompt: 'más natural', locale: 'es', baseRecipe: withShader },
  ];
  for (const data of bad) await expectCode(handleGenerate(admin, data, d), 'invalid-argument');
  assert.equal(llm.requests.length, 0);
});

test('prompt: devuelve solo las variantes válidas y loguea sin el texto', async () => {
  const { d, llm, logs } = deps(okReply);
  const result = await handleGenerate(admin, { kind: 'prompt', prompt: 'labios rojos', locale: 'es' }, d);
  assert.deepEqual(result.variants, [red, nude]);
  assert.equal(result.model, 'fake-model');
  assert.match(result.requestId, /^[0-9a-f-]{36}$/);
  assert.match(llm.requests[0].user, /labios rojos/);
  assert.match(llm.requests[0].system, /makeup-recipe\/2/);
  assert.equal(logs.length, 1);
  assert.equal(logs[0].valid, 2);
  assert.equal(logs[0].invalid, 1);
  assert.ok(!JSON.stringify(logs).includes('labios rojos'));
});

test('remix: manda la receta base y la instrucción', async () => {
  const { d, llm } = deps(JSON.stringify({ variants: [nude] }));
  const result = await handleGenerate(admin, { kind: 'remix', prompt: 'más natural', locale: 'es', baseRecipe: red }, d);
  assert.deepEqual(result.variants, [nude]);
  assert.match(llm.requests[0].user, /#B3122D/);
  assert.match(llm.requests[0].user, /más natural/);
  assert.match(llm.requests[0].system, /COMPLETE recipe/);
});

test('modelo con basura: cero variantes, sin error', async () => {
  for (const reply of ['no es json', '{"otra":1}', '{"variants":"x"}', '[]']) {
    const result = await handleGenerate(admin, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, deps(reply).d);
    assert.deepEqual(result.variants, []);
  }
});

test('modelo caído: unavailable, y la cuota igual se descuenta', async () => {
  const { d, quota } = deps(new LlmUnavailableError('timeout'));
  await expectCode(handleGenerate(admin, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, d), 'unavailable');
  assert.equal(quota.counts.get('admin-1/20261013'), 1);
});

test(`cuota: la llamada ${ADMIN_DAILY_QUOTA + 1} del día falla`, async () => {
  const { d, llm } = deps(okReply);
  for (let i = 0; i < ADMIN_DAILY_QUOTA; i++) {
    await handleGenerate(admin, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, d);
  }
  await expectCode(handleGenerate(admin, { kind: 'prompt', prompt: 'rojo', locale: 'es' }, d), 'resource-exhausted');
  assert.equal(llm.requests.length, ADMIN_DAILY_QUOTA);
});

test('validVariants: como mucho 3 y las de más cuentan como inválidas', () => {
  const { valid, invalid } = validVariants(JSON.stringify({ variants: [red, red, red, red] }));
  assert.equal(valid.length, 3);
  assert.equal(invalid, 1);
});
