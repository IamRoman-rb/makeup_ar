// Cuota con transacciones reales de Firestore: solo con el emulador
// (npm run test:emulator). Sin FIRESTORE_EMULATOR_HOST se saltea.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { FirestoreQuotaStore, dayKey } from '../src/quota';

const emulator = process.env.FIRESTORE_EMULATOR_HOST;

test('dayKey en UTC', () => {
  assert.equal(dayKey(new Date('2026-10-13T23:59:59-03:00')), '20261014');
});

test('cuota en Firestore: transacciones concurrentes no pasan el límite', { skip: !emulator }, async () => {
  const app = initializeApp({ projectId: 'demo-armakeup' }, 'quota-test');
  const db = getFirestore(app);
  const store = new FirestoreQuotaStore(db);
  const uid = `quota-${Date.now()}`;
  const results = await Promise.all(Array.from({ length: 8 }, () => store.consume(uid, '20261013', 5)));
  assert.equal(results.filter(Boolean).length, 5);
  const snapshot = await db.doc(`users/${uid}/usage/20261013`).get();
  assert.equal(snapshot.get('count'), 5);
  assert.equal(await store.consume(uid, '20261014', 5), true);  // otro día, otra cuota
});
