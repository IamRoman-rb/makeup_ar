// handleRevenueCatWebhook con un store en memoria: sin emuladores.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { LIFETIME_UNTIL, PremiumStore, WebhookDeps, handleRevenueCatWebhook } from '../src/revenueCatWebhook';

const SECRET = 'Bearer secreto-de-prueba';
const UID = 'firebaseUid123';
const EXPIRES = Date.parse('2026-11-16T12:00:00Z');

class MemoryStore implements PremiumStore {
  docs = new Map<string, { until: Date; eventMs: number }>();
  async applyIfNewer(uid: string, until: Date, eventMs: number) {
    const last = this.docs.get(uid);
    if (last && last.eventMs >= eventMs) return false;
    this.docs.set(uid, { until, eventMs });
    return true;
  }
}

function setup(secret = SECRET) {
  const store = new MemoryStore();
  const logs: Record<string, unknown>[] = [];
  const deps: WebhookDeps = { secret: () => secret, entitlement: 'vip', store, log: (e) => logs.push(e) };
  return { store, logs, deps };
}

function body(event: Record<string, unknown>) {
  return {
    api_version: '1.0',
    event: {
      type: 'INITIAL_PURCHASE',
      app_user_id: UID,
      entitlement_ids: ['vip'],
      expiration_at_ms: EXPIRES,
      event_timestamp_ms: 1000,
      ...event,
    },
  };
}

test('sin el header correcto: 401 y no escribe', async () => {
  for (const auth of [undefined, '', 'Bearer otro']) {
    const { store, deps } = setup();
    const result = await handleRevenueCatWebhook(auth, body({}), deps);
    assert.equal(result.status, 401);
    assert.equal(store.docs.size, 0);
  }
});

test('sin secreto configurado: rechaza todo', async () => {
  const { deps } = setup('');
  assert.equal((await handleRevenueCatWebhook('', body({}), deps)).status, 401);
});

test('compra: premium_until = vencimiento', async () => {
  const { store, deps } = setup();
  const result = await handleRevenueCatWebhook(SECRET, body({}), deps);
  assert.deepEqual(result, { status: 200, outcome: 'applied' });
  assert.equal(store.docs.get(UID)?.until.getTime(), EXPIRES);
});

test('compra de por vida (sin vencimiento): hasta 2100', async () => {
  const { store, deps } = setup();
  await handleRevenueCatWebhook(SECRET, body({ type: 'NON_RENEWING_PURCHASE', expiration_at_ms: null }), deps);
  assert.equal(store.docs.get(UID)?.until.getTime(), LIFETIME_UNTIL.getTime());
});

test('vencimiento: premium_until en el pasado', async () => {
  const { store, deps } = setup();
  await handleRevenueCatWebhook(SECRET, body({}), deps);
  const expired = Date.parse('2026-10-01T00:00:00Z');
  await handleRevenueCatWebhook(SECRET, body({ type: 'EXPIRATION', expiration_at_ms: expired, event_timestamp_ms: 2000 }), deps);
  assert.equal(store.docs.get(UID)?.until.getTime(), expired);
});

test('cancelación, problemas de cobro y TEST: no cambian nada', async () => {
  const { store, deps } = setup();
  for (const type of ['CANCELLATION', 'BILLING_ISSUE', 'TEST']) {
    const result = await handleRevenueCatWebhook(SECRET, body({ type }), deps);
    assert.deepEqual(result, { status: 200, outcome: 'ignored_type' });
  }
  const transfer = await handleRevenueCatWebhook(SECRET, body({ type: 'TRANSFER' }), deps);
  assert.equal(transfer.outcome, 'ignored_transfer');
  assert.equal(store.docs.size, 0);
});

test('evento más viejo que el último aplicado: se descarta', async () => {
  const { store, deps } = setup();
  await handleRevenueCatWebhook(SECRET, body({ type: 'EXPIRATION', expiration_at_ms: 5, event_timestamp_ms: 3000 }), deps);
  const result = await handleRevenueCatWebhook(SECRET, body({ event_timestamp_ms: 2000 }), deps);
  assert.equal(result.outcome, 'stale');
  assert.equal(store.docs.get(UID)?.until.getTime(), 5);
});

test('usuario anónimo u otro entitlement: 200 sin escribir', async () => {
  const { store, deps } = setup();
  const anonymous = await handleRevenueCatWebhook(SECRET, body({ app_user_id: '$RCAnonymousID:abc' }), deps);
  assert.equal(anonymous.outcome, 'ignored_user');
  const other = await handleRevenueCatWebhook(SECRET, body({ entitlement_ids: ['pro'] }), deps);
  assert.equal(other.outcome, 'ignored_entitlement');
  const legacy = await handleRevenueCatWebhook(SECRET, body({ entitlement_ids: null, entitlement_id: 'vip' }), deps);
  assert.equal(legacy.outcome, 'applied');
  assert.equal(store.docs.size, 1);
});

test('cuerpo malformado: 400', async () => {
  const { deps } = setup();
  for (const bad of [null, {}, { event: 'x' }, { event: { type: 'RENEWAL' } }, body({ event_timestamp_ms: 'ayer' })]) {
    assert.equal((await handleRevenueCatWebhook(SECRET, bad, deps)).status, 400);
  }
});

test('el log no lleva el secreto ni el cuerpo', async () => {
  const { logs, deps } = setup();
  await handleRevenueCatWebhook(SECRET, body({ price: 9.99 }), deps);
  await handleRevenueCatWebhook('Bearer otro', body({}), deps);
  const text = JSON.stringify(logs);
  assert.ok(!text.includes('secreto'));
  assert.ok(!text.includes('9.99'));
});
