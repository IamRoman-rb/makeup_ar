// Webhook de RevenueCat -> estado VIP en users/{uid} (AUDIT.md §5.2). El
// cliente ya no puede escribir el estado VIP (firestore.rules): la única fuente
// es este endpoint, autenticado con el header Authorization que se configura
// en RevenueCat (Integrations -> Webhooks) y se guarda en Secret Manager.
//
// Se guarda premium_until (vencimiento) y no un booleano: las reglas comparan
// con request.time, así el VIP vence solo aunque se pierda el evento EXPIRATION.
// premium_event_ms descarta eventos viejos (RevenueCat reintenta y no garantiza
// orden). Sin dependencias de Firebase salvo el tipo Firestore: se testea con
// un store en memoria.
import { createHash, timingSafeEqual } from 'node:crypto';

import type { Firestore } from 'firebase-admin/firestore';
import { Timestamp } from 'firebase-admin/firestore';

// Eventos que otorgan o extienden el VIP hasta expiration_at_ms.
export const GRANT_EVENTS: readonly string[] = [
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
  'SUBSCRIPTION_EXTENDED',
  'NON_RENEWING_PURCHASE',
  'TEMPORARY_ENTITLEMENT_GRANT',
];
// Compra sin vencimiento (de por vida).
export const LIFETIME_UNTIL = new Date('2100-01-01T00:00:00Z');
const ANONYMOUS_PREFIX = '$RCAnonymousID:';
const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export interface PremiumStore {
  // Aplica el vencimiento si [eventMs] es más nuevo que el último aplicado.
  // false si el evento era viejo.
  applyIfNewer(uid: string, until: Date, eventMs: number): Promise<boolean>;
}

export interface WebhookDeps {
  // Valor esperado del header Authorization (Secret Manager).
  secret(): string;
  entitlement: string;
  store: PremiumStore;
  log(entry: Record<string, unknown>): void;
}

export interface WebhookResult {
  status: number;
  outcome: string;
}

function sameSecret(given: string, expected: string): boolean {
  // Hash previo: timingSafeEqual exige el mismo largo.
  const a = createHash('sha256').update(given).digest();
  const b = createHash('sha256').update(expected).digest();
  return timingSafeEqual(a, b);
}

function entitlementsOf(event: Record<string, unknown>): string[] {
  const ids = event.entitlement_ids;
  if (Array.isArray(ids)) return ids.filter((id): id is string => typeof id === 'string');
  return typeof event.entitlement_id === 'string' ? [event.entitlement_id] : [];
}

export async function handleRevenueCatWebhook(
  authorization: string | undefined,
  body: unknown,
  deps: WebhookDeps,
): Promise<WebhookResult> {
  const secret = deps.secret();
  if (secret.length === 0 || authorization === undefined || !sameSecret(authorization, secret)) {
    deps.log({ outcome: 'unauthorized' });
    return { status: 401, outcome: 'unauthorized' };
  }
  const event = (body as { event?: unknown } | null)?.event;
  if (typeof event !== 'object' || event === null) return { status: 400, outcome: 'malformed' };
  const e = event as Record<string, unknown>;
  const type = e.type;
  const uid = e.app_user_id;
  const eventMs = e.event_timestamp_ms;
  if (typeof type !== 'string' || typeof uid !== 'string' || typeof eventMs !== 'number') {
    return { status: 400, outcome: 'malformed' };
  }
  const result = (outcome: string): WebhookResult => {
    // Solo metadatos: nada de recibos ni precios.
    deps.log({ outcome, type, uid, eventMs });
    return { status: 200, outcome };
  };

  if (uid.startsWith(ANONYMOUS_PREFIX) || !UID_PATTERN.test(uid)) return result('ignored_user');
  if (type === 'TRANSFER') return result('ignored_transfer');
  if (type !== 'EXPIRATION' && !GRANT_EVENTS.includes(type)) return result('ignored_type');
  if (!entitlementsOf(e).includes(deps.entitlement)) return result('ignored_entitlement');

  const expiration = e.expiration_at_ms;
  let until: Date;
  if (typeof expiration === 'number') {
    until = new Date(expiration);
  } else if (type === 'EXPIRATION') {
    until = new Date(eventMs);
  } else {
    until = LIFETIME_UNTIL;
  }
  const applied = await deps.store.applyIfNewer(uid, until, eventMs);
  return result(applied ? 'applied' : 'stale');
}

export class FirestorePremiumStore implements PremiumStore {
  constructor(private readonly db: Firestore) {}

  applyIfNewer(uid: string, until: Date, eventMs: number): Promise<boolean> {
    const ref = this.db.collection('users').doc(uid);
    return this.db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const last = snapshot.get('premium_event_ms');
      if (typeof last === 'number' && last >= eventMs) return false;
      tx.set(ref, { premium_until: Timestamp.fromDate(until), premium_event_ms: eventMs }, { merge: true });
      return true;
    });
  }
}
