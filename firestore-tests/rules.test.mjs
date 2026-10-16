// Tests de firestore.rules contra el emulador de Firestore, sin dependencias
// (node:test + fetch a la API REST del emulador). Uso, desde la raíz del repo:
//
//   firebase emulators:exec --only firestore --project demo-armakeup "node --test firestore-tests/rules.test.mjs"
//
// El proyecto "demo-*" es solo local: no toca el proyecto real.
// El emulador acepta tokens sin firmar ("alg": "none") para simular usuarios,
// y "Bearer owner" para sembrar datos saltándose las reglas.
import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

const HOST = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const PROJECT = process.env.GCLOUD_PROJECT ?? 'demo-armakeup';
const BASE = `http://${HOST}/v1/projects/${PROJECT}/databases/(default)/documents`;

function userToken(uid) {
  const encode = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    iat: now,
    exp: now + 3600,
    auth_time: now,
    sub: uid,
    user_id: uid,
    firebase: { sign_in_provider: 'password', identities: {} },
  };
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode(payload)}.`;
}

function toValue(value) {
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toValue) } };
  if (value !== null && typeof value === 'object') return { mapValue: toFields(value) };
  return { stringValue: String(value) };
}

function toFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) fields[key] = toValue(value);
  return { fields };
}

/** auth: uid, 'owner' (salta reglas) o null (sin login). Devuelve el status HTTP. */
async function request(method, path, auth, data, updateMask) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth === 'owner') headers.Authorization = 'Bearer owner';
  else if (auth) headers.Authorization = `Bearer ${userToken(auth)}`;
  let url = `${BASE}/${path}`;
  if (updateMask) url += '?' + updateMask.map((f) => `updateMask.fieldPaths=${f}`).join('&');
  const response = await fetch(url, { method, headers, body: data ? JSON.stringify(toFields(data)) : undefined });
  await response.text();
  return response.status;
}

const read = (path, auth) => request('GET', path, auth);
/** set() completo (crea o reemplaza). */
const set = (path, auth, data) => request('PATCH', path, auth, data);
/** update() parcial: solo los campos dados, como DocumentReference.update en la app. */
const update = (path, auth, data) => request('PATCH', path, auth, data, Object.keys(data));
const remove = (path, auth) => request('DELETE', path, auth);

const OK = 200;
const DENIED = 403;

beforeEach(async () => {
  await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  await set('users/admin', 'owner', { nombre: 'Admin', is_admin: true });
  await set('users/alice', 'owner', { nombre: 'Alice', correo: 'a@a.com' });
  await set('looks/look1', 'owner', { name: 'Rojo', category: 'Lips' });
});

// --- El agujero que se cierra -------------------------------------------------

test('un usuario NO puede ponerse is_admin: true con update', async () => {
  assert.equal(await update('users/alice', 'alice', { is_admin: true }), DENIED);
});

test('un usuario NO puede ponerse is_admin: true reemplazando su documento', async () => {
  assert.equal(await set('users/alice', 'alice', { nombre: 'Alice', is_admin: true }), DENIED);
});

test('un usuario nuevo NO puede crearse ya como admin', async () => {
  assert.equal(await set('users/mallory', 'mallory', { nombre: 'M', is_admin: true }), DENIED);
});

test('tras el intento fallido, no puede escribir en looks', async () => {
  await update('users/alice', 'alice', { is_admin: true });
  assert.equal(await set('looks/look1', 'alice', { name: 'Hackeado' }), DENIED);
  assert.equal(await remove('looks/look1', 'alice'), DENIED);
});

test('un admin tampoco puede cambiar su propio is_admin desde el cliente', async () => {
  assert.equal(await update('users/admin', 'admin', { is_admin: false }), DENIED);
});

// --- Lo que la app hace hoy tiene que seguir funcionando -----------------------

test('registro: signup_screen crea su documento sin is_admin', async () => {
  assert.equal(
    await set('users/bob', 'bob', { nombre: 'Bob', correo: 'b@b.com', edad: 25, tipo_piel: 'Mixta' }),
    OK,
  );
});

test('registro con is_admin: false explícito también se permite', async () => {
  assert.equal(await set('users/bob', 'bob', { nombre: 'Bob', is_admin: false }), OK);
});

test('edit_profile_screen actualiza sus datos', async () => {
  assert.equal(await update('users/alice', 'alice', { nombre: 'Alicia', edad: 30 }), OK);
});

test('catalog/saved_looks actualizan saved_looks', async () => {
  assert.equal(await update('users/alice', 'alice', { saved_looks: ['look1'] }), OK);
});

// --- VIP (AUDIT.md §5.2): el estado lo escribe solo el servidor ---------------

const FUTURE = new Date(Date.now() + 30 * 24 * 3600 * 1000);
const PAST = new Date(Date.now() - 24 * 3600 * 1000);

test('el cliente NO puede marcarse VIP: ni is_premium ni premium_until, ni al crear ni al actualizar', async () => {
  assert.equal(await update('users/alice', 'alice', { is_premium: true }), DENIED);
  assert.equal(await update('users/alice', 'alice', { premium_until: FUTURE }), DENIED);
  assert.equal(await update('users/alice', 'alice', { premium_event_ms: 1 }), DENIED);
  assert.equal(await set('users/alice', 'alice', { nombre: 'Alice', premium_until: FUTURE }), DENIED);
  assert.equal(await set('users/mallory', 'mallory', { nombre: 'M', is_premium: true }), DENIED);
  assert.equal(await set('users/mallory', 'mallory', { nombre: 'M', premium_until: FUTURE }), DENIED);
});

test('un VIP edita su perfil sin tocar el estado VIP', async () => {
  await set('users/vip', 'owner', { nombre: 'Vip', premium_until: FUTURE, premium_event_ms: 5 });
  assert.equal(await update('users/vip', 'vip', { nombre: 'Vip 2' }), OK);
  assert.equal(await update('users/vip', 'vip', { premium_until: PAST }), DENIED);
});

test('contenido premium: lo leen VIP vigentes y admins; no vencidos, comunes ni anónimos', async () => {
  await set('looks/look1/premium/content', 'owner', { video_url: 'https://example.com/v.mp4' });
  await set('users/vip', 'owner', { nombre: 'Vip', premium_until: FUTURE });
  await set('users/expired', 'owner', { nombre: 'Ex', premium_until: PAST });
  await set('users/legacy', 'owner', { nombre: 'Legacy', is_premium: true });
  assert.equal(await read('looks/look1/premium/content', 'vip'), OK);
  assert.equal(await read('looks/look1/premium/content', 'admin'), OK);
  assert.equal(await read('looks/look1/premium/content', 'expired'), DENIED);
  assert.equal(await read('looks/look1/premium/content', 'legacy'), DENIED);
  assert.equal(await read('looks/look1/premium/content', 'alice'), DENIED);
  assert.equal(await read('looks/look1/premium/content', null), DENIED);
});

test('contenido premium: solo un admin lo escribe, y solo con video_url', async () => {
  await set('users/vip', 'owner', { nombre: 'Vip', premium_until: FUTURE });
  assert.equal(await set('looks/look1/premium/content', 'vip', { video_url: 'x' }), DENIED);
  assert.equal(await set('looks/look1/premium/content', 'alice', { video_url: 'x' }), DENIED);
  assert.equal(await set('looks/look1/premium/content', 'admin', { video_url: 'https://example.com/v.mp4' }), OK);
  assert.equal(await set('looks/look1/premium/content', 'admin', { video_url: 'x', otro: 1 }), DENIED);
  assert.equal(await remove('looks/look1/premium/content', 'alice'), DENIED);
  assert.equal(await remove('looks/look1/premium/content', 'admin'), OK);
});

test('un admin edita su perfil sin tocar is_admin', async () => {
  assert.equal(await update('users/admin', 'admin', { nombre: 'Admin 2' }), OK);
});

test('account_settings_screen borra su propia cuenta', async () => {
  assert.equal(await remove('users/alice', 'alice'), OK);
});

test('cada usuario lee solo su documento', async () => {
  assert.equal(await read('users/alice', 'alice'), OK);
  assert.equal(await read('users/admin', 'alice'), DENIED);
  assert.equal(await read('users/alice', null), DENIED);
});

test('nadie escribe el documento de otro', async () => {
  assert.equal(await update('users/admin', 'alice', { nombre: 'x' }), DENIED);
  assert.equal(await remove('users/admin', 'alice'), DENIED);
});

test('looks: lectura pública, escritura solo admin', async () => {
  assert.equal(await read('looks/look1', null), OK);
  assert.equal(await read('looks/look1', 'alice'), OK);
  assert.equal(await set('looks/look2', 'alice', { name: 'x' }), DENIED);
  assert.equal(await set('looks/look2', null, { name: 'x' }), DENIED);
  assert.equal(await set('looks/look2', 'admin', { name: 'Nuevo' }), OK);
  assert.equal(await remove('looks/look1', 'admin'), OK);
});

// --- Cuota de generateRecipe (F2): solo la escribe la función ----------------

test('usage: ni el dueño ni un admin lo leen o escriben desde el cliente', async () => {
  await set('users/alice/usage/20261013', 'owner', { count: 3 });
  assert.equal(await read('users/alice/usage/20261013', 'alice'), DENIED);
  assert.equal(await set('users/alice/usage/20261013', 'alice', { count: 0 }), DENIED);
  assert.equal(await remove('users/alice/usage/20261013', 'alice'), DENIED);
  assert.equal(await set('users/admin/usage/20261013', 'admin', { count: 0 }), DENIED);
});

// --- Studio (F3): borradores y looks con receta -------------------------------

const RECIPE = { schema: 'makeup-recipe/2', name: 'Rojo', lips: { color: '#B3122D', opacity: 0.85 } };
const DRAFT = { name: 'Rojo', category: 'Lips', recipe: RECIPE, recipeSchema: 'makeup-recipe/2', minEngine: 1 };

test('look_drafts: solo admins leen, escriben y borran', async () => {
  assert.equal(await set('look_drafts/d1', 'admin', DRAFT), OK);
  assert.equal(await read('look_drafts/d1', 'admin'), OK);
  assert.equal(await read('look_drafts/d1', 'alice'), DENIED);
  assert.equal(await read('look_drafts/d1', null), DENIED);
  assert.equal(await set('look_drafts/d2', 'alice', DRAFT), DENIED);
  assert.equal(await remove('look_drafts/d1', 'alice'), DENIED);
  assert.equal(await remove('look_drafts/d1', 'admin'), OK);
});

test('look_drafts: sin receta o con tipos incorrectos se rechaza', async () => {
  assert.equal(await set('look_drafts/d1', 'admin', { name: 'Sin receta' }), DENIED);
  assert.equal(await set('look_drafts/d1', 'admin', { ...DRAFT, recipe: 'texto' }), DENIED);
  assert.equal(await set('look_drafts/d1', 'admin', { ...DRAFT, minEngine: 'uno' }), DENIED);
  assert.equal(await set('look_drafts/d1', 'admin', { ...DRAFT, recipeSchema: 'makeup-recipe/1' }), DENIED);
});

test('looks: el admin publica con receta; los viejos sin receta siguen valiendo', async () => {
  assert.equal(await set('looks/nuevo', 'admin', { ...DRAFT, steps: [] }), OK);
  assert.equal(await read('looks/nuevo', null), OK);
  assert.equal(await set('looks/malo', 'admin', { ...DRAFT, recipe: 3 }), DENIED);
  assert.equal(await update('looks/look1', 'admin', { name: 'Rojo 2' }), OK);
  assert.equal(await set('looks/otro', 'alice', { ...DRAFT }), DENIED);
});

// --- Looks de usuarios finales (ai_looks) ---------------------------------------

test('ai_looks: el dueño lee y lista los suyos; otros no', async () => {
  await set('users/alice/ai_looks/l1', 'owner', { name: 'Rojo', recipe: { schema: 'makeup-recipe/2', name: 'Rojo' } });
  assert.equal(await read('users/alice/ai_looks/l1', 'alice'), OK);
  assert.equal(await read('users/alice/ai_looks', 'alice'), OK);
  assert.equal(await read('users/alice/ai_looks/l1', 'admin'), DENIED);
  assert.equal(await read('users/alice/ai_looks', 'admin'), DENIED);
  assert.equal(await read('users/alice/ai_looks/l1', null), DENIED);
});

test('ai_looks: nadie escribe ni borra desde el cliente (solo las callables)', async () => {
  await set('users/alice/ai_looks/l1', 'owner', { name: 'Rojo' });
  assert.equal(await set('users/alice/ai_looks/l2', 'alice', { name: 'Nuevo' }), DENIED);
  assert.equal(await update('users/alice/ai_looks/l1', 'alice', { name: 'Cambiado' }), DENIED);
  assert.equal(await remove('users/alice/ai_looks/l1', 'alice'), DENIED);
  assert.equal(await set('users/alice/ai_looks/l3', 'admin', { name: 'Admin' }), DENIED);
});
