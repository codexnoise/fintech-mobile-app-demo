/**
 * Entry point de Cloud Functions (2nd gen).
 * Una sola función HTTP `api` (BFF) para minimizar cold starts y centralizar
 * middleware de seguridad, correlación y degradación.
 */
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { getFirestore } from 'firebase-admin/firestore';
import { createApp } from './http/app';
import type { Deps } from './ports';
import {
  FcmNotifier,
  firebaseApp,
  FirebaseIdentity,
  FirestoreDevices,
  FirestoreExperiences,
  FirestoreFlags,
  FirestoreUsers,
  GeminiAssistantModel,
  JwtContextTokens,
  UuidIds,
} from './adapters/firebase';

const MICROAPP_SIGNING_KEY = defineSecret('MICROAPP_SIGNING_KEY');
const ADMIN_API_KEY = defineSecret('ADMIN_API_KEY');
/** Si el valor es "disabled", el asistente usa solo el fallback determinista. */
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const MICROAPP_ORIGINS = defineString('MICROAPP_ORIGINS', { default: '' });
const APP_CHECK_ENFORCED = defineString('APP_CHECK_ENFORCED', { default: 'true' });

let app: ReturnType<typeof createApp> | null = null;

function buildApp() {
  const db = getFirestore(firebaseApp());
  const users = new FirestoreUsers(db);
  const geminiKey = GEMINI_API_KEY.value();
  const deps: Deps = {
    users,
    ledger: users,
    experiences: new FirestoreExperiences(db),
    flags: new FirestoreFlags(db),
    devices: new FirestoreDevices(db),
    notifier: new FcmNotifier(),
    identity: new FirebaseIdentity(),
    contextTokens: new JwtContextTokens(MICROAPP_SIGNING_KEY.value()),
    assistantModel: geminiKey && geminiKey !== 'disabled' ? new GeminiAssistantModel(geminiKey) : null,
    clock: { now: () => new Date() },
    ids: new UuidIds(),
    config: {
      appCheckEnforced: process.env.FUNCTIONS_EMULATOR !== 'true' && APP_CHECK_ENFORCED.value() !== 'false',
      adminApiKey: ADMIN_API_KEY.value(),
      microAppOrigins: MICROAPP_ORIGINS.value()
        .split(',')
        .map((o) => o.trim())
        .filter(Boolean),
      assistantTimeoutMs: 8_000,
    },
  };
  return createApp(deps);
}

export const api = onRequest(
  {
    region: 'us-east1',
    secrets: [MICROAPP_SIGNING_KEY, ADMIN_API_KEY, GEMINI_API_KEY],
    memory: '512MiB',
    timeoutSeconds: 30,
    concurrency: 40,
    maxInstances: 10,
    invoker: 'public', // la autorización la hace el middleware (ID token + App Check)
  },
  (req, res) => {
    app ??= buildApp();
    return app(req, res);
  },
);
