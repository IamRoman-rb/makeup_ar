// Cuota diaria por usuario (UTC) en users/{uid}/usage/{yyyymmdd}. Las reglas
// de Firestore no dan acceso del cliente a esa subcolección: solo la escribe
// esta función con el Admin SDK.
import type { Firestore } from 'firebase-admin/firestore';

export interface QuotaStore {
  // Suma 1 al contador del día si no llegó al límite. false = cuota agotada.
  consume(uid: string, day: string, limit: number): Promise<boolean>;
}

// yyyymmdd en UTC.
export function dayKey(now: Date): string {
  return now.toISOString().slice(0, 10).replaceAll('-', '');
}

export class FirestoreQuotaStore implements QuotaStore {
  constructor(private readonly db: Firestore) {}

  consume(uid: string, day: string, limit: number): Promise<boolean> {
    const ref = this.db.collection('users').doc(uid).collection('usage').doc(day);
    return this.db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const count = snapshot.exists ? Number(snapshot.get('count') ?? 0) : 0;
      if (count >= limit) return false;
      tx.set(ref, { count: count + 1, updatedAt: new Date() }, { merge: true });
      return true;
    });
  }
}
