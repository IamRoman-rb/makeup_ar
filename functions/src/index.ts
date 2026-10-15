// Cloud Functions de makeup_ar. Deploy (lo corrés vos, con el plan Blaze y la
// Vertex AI API habilitada): firebase deploy --only functions
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineString } from 'firebase-functions/params';
import { onCall } from 'firebase-functions/v2/https';

import { AiLookDeps, FirestoreAiLookStore, handleDeleteAiLook, handleSaveAiLook } from './aiLooks';
import { GenerateDeps, handleGenerate } from './generateRecipe';
import { GeminiClient } from './llm/geminiClient';
import { FirestoreQuotaStore } from './quota';

initializeApp();

// Modelo y ubicación de Vertex AI, cambiables sin tocar código
// (functions/.env o el prompt del deploy). gemini-3.5-flash: estable, sin
// retiro antes de mayo de 2027 (verificado el 2026-10-13).
const geminiModel = defineString('GEMINI_MODEL', { default: 'gemini-3.5-flash' });
const geminiLocation = defineString('GEMINI_LOCATION', { default: 'global' });

let deps: GenerateDeps | undefined;
let lookDeps: AiLookDeps | undefined;

function getDeps(): GenerateDeps {
  if (deps) return deps;
  const db = getFirestore();
  const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? '';
  deps = {
    llm: new GeminiClient({ project, location: geminiLocation.value(), model: geminiModel.value() }),
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
  enforceAppCheck: true,
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
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 3,
  },
  (request) => handleGenerate(request.auth ? { uid: request.auth.uid } : undefined, request.data, getDeps()),
);
