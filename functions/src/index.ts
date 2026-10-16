// Cloud Functions de makeup_ar. Deploy (lo corrés vos, con el plan Blaze y la
// Vertex AI API habilitada): firebase deploy --only functions
// Sin deploy: emulador local con LLM falso (docs/ar_engine/F2_PLAN.md).
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret, defineString } from 'firebase-functions/params';
import { onCall, onRequest } from 'firebase-functions/v2/https';

import { AiLookDeps, FirestoreAiLookStore, handleDeleteAiLook, handleSaveAiLook } from './aiLooks';
import { GenerateDeps, handleGenerate } from './generateRecipe';
import { FakeLlmClient } from './llm/fakeLlmClient';
import { GeminiClient } from './llm/geminiClient';
import { LlmClient } from './llm/llmClient';
import { FirestoreQuotaStore } from './quota';
import { FirestorePremiumStore, WebhookDeps, handleRevenueCatWebhook } from './revenueCatWebhook';

initializeApp();

// Modelo y ubicación de Vertex AI, cambiables sin tocar código
// (functions/.env o el prompt del deploy). gemini-3.5-flash: estable, sin
// retiro antes de mayo de 2027 (verificado el 2026-10-13).
const geminiModel = defineString('GEMINI_MODEL', { default: 'gemini-3.5-flash' });
const geminiLocation = defineString('GEMINI_LOCATION', { default: 'global' });

// Solo el emulador de Functions define FUNCTIONS_EMULATOR; en Cloud Run no
// existe, así que en producción nada de esto cambia. En el emulador: LLM falso
// (salvo USE_GEMINI_IN_EMULATOR=1) y App Check no exigido, porque sin el token
// de debug registrado el SDK no manda token y el emulador rechazaría todo.
const inEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
const fakeLlm = inEmulator && process.env.USE_GEMINI_IN_EMULATOR !== '1';
if (inEmulator) {
  logger.warn(`Emulador: App Check no exigido; LLM ${fakeLlm ? 'falso (fake-emulator)' : 'Gemini real'}.`);
}

let deps: GenerateDeps | undefined;
let lookDeps: AiLookDeps | undefined;

function getDeps(): GenerateDeps {
  if (deps) return deps;
  const db = getFirestore();
  const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? '';
  const llm: LlmClient = fakeLlm
    ? new FakeLlmClient()
    : new GeminiClient({ project, location: geminiLocation.value(), model: geminiModel.value() });
  deps = {
    llm,
    quota: new FirestoreQuotaStore(db),
    isAdmin: async (uid) => (await db.collection('users').doc(uid).get()).get('is_admin') === true,
    now: () => new Date(),
    log: (entry) => logger.info('generateRecipe', entry),
  };
  return deps;
}

function getLookDeps(): AiLookDeps {
  if (lookDeps) return lookDeps;
  lookDeps = {
    store: new FirestoreAiLookStore(getFirestore()),
    now: () => new Date(),
    log: (entry) => logger.info('aiLooks', entry),
  };
  return lookDeps;
}

const lookOptions = {
  region: 'us-central1',
  enforceAppCheck: !inEmulator,
  timeoutSeconds: 20,
  memory: '256MiB' as const,
  maxInstances: 3,
};

// "Mis looks" de usuarios finales: el cliente no escribe users/{uid}/ai_looks.
export const saveAiLook = onCall(lookOptions, (request) =>
  handleSaveAiLook(request.auth ? { uid: request.auth.uid } : undefined, request.data, getLookDeps()));

export const deleteAiLook = onCall(lookOptions, (request) =>
  handleDeleteAiLook(request.auth ? { uid: request.auth.uid } : undefined, request.data, getLookDeps()));

export const generateRecipe = onCall(
  {
    region: 'us-central1',
    enforceAppCheck: !inEmulator,
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 3,
  },
  (request) => handleGenerate(request.auth ? { uid: request.auth.uid } : undefined, request.data, getDeps()),
);

// VIP: RevenueCat avisa compras y vencimientos; solo este endpoint escribe el
// estado VIP (AUDIT.md §5.2). El secreto es el valor del header Authorization
// configurado en RevenueCat: firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
const revenueCatAuth = defineSecret('REVENUECAT_WEBHOOK_AUTH');
// Igual que RevenueCatKeys.entitlementId en la app.
const vipEntitlement = defineString('VIP_ENTITLEMENT', { default: 'vip' });
let webhookDeps: WebhookDeps | undefined;

function getWebhookDeps(): WebhookDeps {
  if (webhookDeps) return webhookDeps;
  webhookDeps = {
    secret: () => revenueCatAuth.value(),
    entitlement: vipEntitlement.value(),
    store: new FirestorePremiumStore(getFirestore()),
    log: (entry) => logger.info('revenueCatWebhook', entry),
  };
  return webhookDeps;
}

export const revenueCatWebhook = onRequest(
  { region: 'us-central1', secrets: [revenueCatAuth], timeoutSeconds: 10, memory: '256MiB', maxInstances: 3 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('POST');
      return;
    }
    const result = await handleRevenueCatWebhook(req.header('authorization'), req.body, getWebhookDeps());
    res.status(result.status).json({ outcome: result.outcome });
  },
);
