/**
 * Casos de uso del BFF. Orquestan dominio puro + puertos; no conocen HTTP
 * ni Firebase. Son lo que se testea con adaptadores en memoria.
 */
import { AppError } from '../errors';
import { hashUid, log } from '../logger';
import type { Deps } from '../ports';
import { assignSegment, reevaluateByBalance } from '../domain/segmentation';
import { generateSeed } from '../domain/seed';
import { summarize } from '../domain/insights';
import { composeExperience, parseExperienceConfig, type SduiDocument } from '../domain/experience';
import { requestFingerprint, type TransferResult } from '../domain/transfer';
import {
  buildAssistantDocument,
  buildUserPrompt,
  GEMINI_RESPONSE_SCHEMA,
  modelOutputSchema,
  SYSTEM_INSTRUCTION,
  verifyModelOutput,
  type AssistantPromptId,
} from '../domain/assistant';
import type { IncomeRange, Occupation, UserProfile } from '../domain/types';
import youngDigitalHome from '../experience/defaults/young_digital__home.json';
import entrepreneurHome from '../experience/defaults/entrepreneur__home.json';
import premiumHome from '../experience/defaults/premium__home.json';

export const DEFAULT_EXPERIENCES: Record<string, unknown> = {
  young_digital__home: youngDigitalHome,
  entrepreneur__home: entrepreneurHome,
  premium__home: premiumHome,
};

async function requireProfile(deps: Deps, uid: string): Promise<UserProfile> {
  const profile = await deps.users.getProfile(uid);
  if (!profile) throw new AppError(409, 'onboarding_required', 'Completa tu registro para continuar.');
  return profile;
}

// ---------------------------------------------------------------- Onboarding

export interface OnboardingInput {
  firstName: string;
  birthYear: number;
  occupation: Occupation;
  incomeRange: IncomeRange;
}

export async function completeOnboarding(deps: Deps, uid: string, input: OnboardingInput): Promise<UserProfile> {
  if (await deps.users.getProfile(uid)) {
    throw new AppError(409, 'already_onboarded', 'Tu registro ya fue completado.');
  }
  const now = deps.clock.now();
  const seed = generateSeed(uid, input.incomeRange, now);
  const totalBalance = seed.accounts.reduce((sum, a) => sum + a.balanceCents, 0);
  const assignment = reevaluateByBalance(assignSegment({ ...input, now }), totalBalance);

  const profile: UserProfile = {
    uid,
    firstName: input.firstName.trim(),
    birthYear: input.birthYear,
    occupation: input.occupation,
    incomeRange: input.incomeRange,
    segment: assignment.segment,
    segmentReason: assignment.reason,
    createdAt: now.toISOString(),
  };
  await deps.users.createWithSeed(profile, seed.accounts, seed.movements);
  log('INFO', 'onboarding_completed', { uid: hashUid(uid), segment: profile.segment, reason: profile.segmentReason });
  return profile;
}

// ---------------------------------------------------------------- Experience (SDUI)

export async function getExperience(deps: Deps, uid: string, screen: string, appVersion: string): Promise<SduiDocument> {
  const profile = await requireProfile(deps, uid);
  const [stored, movements, flags] = await Promise.all([
    deps.experiences.get(profile.segment, screen),
    deps.users.listMovements(uid),
    deps.flags.get(),
  ]);

  // Config publicada por negocio; si es inválida o no existe, default versionado en código.
  let config = stored ? parseExperienceConfig(stored) : null;
  if (stored && !config) log('WARNING', 'experience_config_invalid', { segment: profile.segment, screen });
  config ??= parseExperienceConfig(DEFAULT_EXPERIENCES[`${profile.segment}__${screen}`]);
  if (!config) throw new AppError(404, 'experience_not_found', 'Pantalla no disponible.');

  return composeExperience(config, {
    firstName: profile.firstName,
    segment: profile.segment,
    appVersion,
    summary: summarize(movements, deps.clock.now()),
    flags,
  });
}

// ---------------------------------------------------------------- Transfers

export interface TransferInput {
  fromAccountId: string;
  toAccountId: string;
  amountCents: number;
  note?: string;
  idempotencyKey: string;
}

export async function createTransfer(deps: Deps, uid: string, input: TransferInput): Promise<TransferResult> {
  await requireProfile(deps, uid);
  const cmd = { ...input, uid, transferId: deps.ids.next('trf'), now: deps.clock.now() };
  const result = await deps.ledger.executeTransfer(cmd, requestFingerprint(input));

  if (!result.replayed) {
    log('INFO', 'transfer_completed', { uid: hashUid(uid), transferId: result.transferId });
    // La notificación es best-effort: nunca revierte ni falla la transferencia.
    notifyTransfer(deps, uid, result).catch((error: unknown) =>
      log('WARNING', 'transfer_push_failed', { transferId: result.transferId, error: String(error) }),
    );
  }
  return result;
}

async function notifyTransfer(deps: Deps, uid: string, result: TransferResult): Promise<void> {
  const tokens = await deps.devices.tokens(uid);
  if (!tokens.length) return;
  const amount = `$${(result.amountCents / 100).toFixed(2)}`;
  const { invalidTokens } = await deps.notifier.sendToTokens(tokens, {
    title: 'Transferencia exitosa',
    body: `Moviste ${amount} entre tus cuentas.`,
    data: { type: 'transfer_completed', route: `/accounts/${result.toAccountId}`, transferId: result.transferId },
  });
  if (invalidTokens.length) await deps.devices.removeTokens(uid, invalidTokens);
}

// ---------------------------------------------------------------- Devices / push

export async function registerDevice(
  deps: Deps,
  uid: string,
  device: { deviceId: string; fcmToken: string; platform: 'android' | 'ios'; appVersion: string },
): Promise<{ topics: string[] }> {
  const profile = await requireProfile(deps, uid);
  await deps.devices.upsert(uid, device);
  const topic = `segment_${profile.segment}`;
  await deps.notifier.subscribeToTopic([device.fcmToken], topic);
  return { topics: [topic] };
}

export async function sendSegmentCampaign(
  deps: Deps,
  segment: string,
  message: { title: string; body: string; route?: string },
): Promise<{ messageId: string; topic: string }> {
  const topic = `segment_${segment}`;
  const messageId = await deps.notifier.sendToTopic(topic, {
    title: message.title,
    body: message.body,
    data: { type: 'campaign', route: message.route ?? '/home' },
  });
  return { messageId, topic };
}

// ---------------------------------------------------------------- Micro-apps

export const MICRO_APPS = new Set(['travel_insurance']);

export async function issueMicroAppContext(deps: Deps, uid: string, appId: string) {
  if (!MICRO_APPS.has(appId)) throw new AppError(404, 'micro_app_not_found', 'Servicio no disponible.');
  const flags = await deps.flags.get();
  if (!flags.microAppsEnabled) {
    throw new AppError(503, 'service_unavailable', 'Este servicio está temporalmente deshabilitado.', undefined, 300);
  }
  const profile = await requireProfile(deps, uid);
  // Claims mínimos: la micro-app nunca recibe el token de sesión del banco.
  return deps.contextTokens.issue({ sub: uid, firstName: profile.firstName, segment: profile.segment }, appId);
}

export async function introspectMicroAppContext(deps: Deps, token: string, appId: string) {
  const claims = await deps.contextTokens.verify(token, appId);
  return claims ? { active: true, firstName: claims.firstName, segment: claims.segment } : { active: false };
}

// ---------------------------------------------------------------- Assistant (IA acotada)

export async function askAssistant(deps: Deps, uid: string, promptId: AssistantPromptId) {
  const flags = await deps.flags.get();
  if (!flags.assistantEnabled) {
    throw new AppError(503, 'service_unavailable', 'El asistente no está disponible por ahora.', undefined, 300);
  }
  await requireProfile(deps, uid);
  const summary = summarize(await deps.users.listMovements(uid), deps.clock.now());

  const model = deps.assistantModel;
  if (model) {
    try {
      const raw = await withTimeout(
        model.complete({ system: SYSTEM_INSTRUCTION, user: buildUserPrompt(promptId, summary), responseSchema: GEMINI_RESPONSE_SCHEMA }),
        deps.config.assistantTimeoutMs,
      );
      const parsed = modelOutputSchema.safeParse(JSON.parse(raw));
      if (parsed.success) {
        const { output, report } = verifyModelOutput(parsed.data, summary);
        log('INFO', 'assistant_answer', { promptId, model: model.name, ...report });
        return buildAssistantDocument({ promptId, summary, content: output, source: 'model', modelName: model.name });
      }
      log('WARNING', 'assistant_invalid_output', { promptId, model: model.name });
    } catch (error) {
      log('WARNING', 'assistant_model_failed', { promptId, error: String(error) });
    }
  }
  return buildAssistantDocument({ promptId, summary, content: null, source: 'deterministic_fallback' });
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timeout after ${ms}ms`)), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timer);
        reject(error instanceof Error ? error : new Error(String(error)));
      },
    );
  });
}
