import express, { type Request, type Response } from 'express';
import { z } from 'zod';
import type { Deps } from '../ports';
import { AppError } from '../errors';
import { ASSISTANT_PROMPT_IDS } from '../domain/assistant';
import { INCOME_RANGES, OCCUPATIONS, SEGMENTS } from '../domain/types';
import { TRANSFER_LIMITS } from '../domain/transfer';
import { experienceConfigSchema } from '../domain/experience';
import {
  askAssistant,
  completeOnboarding,
  createTransfer,
  getExperience,
  introspectMicroAppContext,
  issueMicroAppContext,
  registerDevice,
  sendSegmentCampaign,
} from '../application/use-cases';
import { appCheck, authenticate, errorHandler, notFound, requestId, requireService, securityHeaders, validate } from './middleware';

const CURRENT_YEAR = new Date().getUTCFullYear();

const onboardingBody = validate(
  z.strictObject({
    firstName: z.string().trim().min(2).max(40).regex(/^[\p{L} '-]+$/u, 'Solo letras'),
    birthYear: z.number().int().min(CURRENT_YEAR - 100).max(CURRENT_YEAR - 18),
    occupation: z.enum(OCCUPATIONS),
    incomeRange: z.enum(INCOME_RANGES),
  }),
);

const experienceQuery = validate(
  z.object({
    screen: z.enum(['home']).default('home'),
    appVersion: z.string().regex(/^\d+\.\d+\.\d+([+-][\w.]+)?$/).default('1.0.0'),
  }),
  'query',
);

const transferBody = validate(
  z.strictObject({
    fromAccountId: z.string().min(1).max(64),
    toAccountId: z.string().min(1).max(64),
    amountCents: z.number().int().positive().max(TRANSFER_LIMITS.maxPerTransferCents * 10),
    note: z.string().trim().max(60).optional(),
    idempotencyKey: z.string().uuid(),
  }),
);

const deviceBody = validate(
  z.strictObject({
    deviceId: z.string().min(8).max(128),
    fcmToken: z.string().min(20).max(4096),
    platform: z.enum(['android', 'ios']),
    appVersion: z.string().max(32),
  }),
);

const contextTokenBody = validate(z.strictObject({ appId: z.string().min(1).max(64) }));
const introspectBody = validate(z.strictObject({ token: z.string().min(10).max(4096), appId: z.string().min(1).max(64) }));
const assistantBody = validate(z.strictObject({ promptId: z.enum(ASSISTANT_PROMPT_IDS as [string, ...string[]]) }));
const experienceBody = validate(experienceConfigSchema);
const flagsBody = validate(
  z.strictObject({
    degradedServices: z.array(z.enum(['onboarding', 'experience', 'transfers', 'micro_apps', 'assistant'])).optional(),
    microAppsEnabled: z.boolean().optional(),
    assistantEnabled: z.boolean().optional(),
  }),
);
const campaignBody = validate(
  z.strictObject({
    segment: z.enum(SEGMENTS),
    title: z.string().min(3).max(60),
    body: z.string().min(3).max(160),
    route: z.string().startsWith('/').optional(),
  }),
);

/**
 * BFF HTTP (Express). Se monta en una sola Cloud Function `api`.
 * Orden: request-id -> headers -> rutas públicas -> App Check -> auth -> rutas.
 */
export function createApp(deps: Deps) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '32kb' }));
  app.use(requestId);
  app.use(securityHeaders);

  // ------------------------------------------------------------- Públicas
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', time: deps.clock.now().toISOString() });
  });

  // La micro-app (otro origen) valida el token de contexto: introspección RFC 7662-like.
  app.options('/micro-apps/introspect', (req, res) => {
    applyCors(req, res, deps.config.microAppOrigins);
    res.status(204).end();
  });
  app.post('/micro-apps/introspect', async (req, res) => {
    applyCors(req, res, deps.config.microAppOrigins);
    const { token, appId } = introspectBody(req);
    res.json(await introspectMicroAppContext(deps, token, appId));
  });

  // ------------------------------------------------------------- Operación interna (API key de admin)
  // En producción esto sería un backoffice con IAM; aquí habilita la demo en vivo.
  const admin = express.Router();
  admin.use((req, _res, next) => {
    if (!deps.config.adminApiKey || req.header('x-admin-key') !== deps.config.adminApiKey) {
      throw new AppError(403, 'forbidden', 'No autorizado.');
    }
    next();
  });
  admin.post('/campaigns', async (req, res) => {
    const { segment, ...message } = campaignBody(req);
    res.status(202).json(await sendSegmentCampaign(deps, segment, message));
  });
  // Publica una experiencia SDUI sin publicar la app. Se valida contra el contrato antes de guardar.
  admin.put('/experiences', async (req, res) => {
    const config = experienceBody(req);
    await deps.experiences.put(config);
    res.json({ published: `${config.segment}__${config.screen}`, version: config.version });
  });
  // Kill switches / degradación controlada.
  admin.put('/flags', async (req, res) => {
    const flags = flagsBody(req);
    await deps.flags.set(flags);
    res.json(await deps.flags.get());
  });
  app.use('/admin', admin);

  // ------------------------------------------------------------- Autenticadas
  const secured = express.Router();
  secured.use(appCheck(deps));
  secured.use(authenticate(deps));

  secured.post('/onboarding/complete', requireService(deps, 'onboarding'), async (req, res) => {
    res.status(201).json(await completeOnboarding(deps, req.uid!, onboardingBody(req)));
  });

  secured.get('/me', async (req, res) => {
    const profile = await deps.users.getProfile(req.uid!);
    if (!profile) throw new AppError(404, 'onboarding_required', 'Completa tu registro para continuar.');
    res.json(profile);
  });

  secured.get('/experience', requireService(deps, 'experience'), async (req, res) => {
    const { screen, appVersion } = experienceQuery(req);
    res.json(await getExperience(deps, req.uid!, screen, appVersion));
  });

  secured.post('/transfers', requireService(deps, 'transfers'), async (req, res) => {
    const result = await createTransfer(deps, req.uid!, transferBody(req));
    res.status(result.replayed ? 200 : 201).json(result);
  });

  secured.post('/devices', async (req, res) => {
    res.json(await registerDevice(deps, req.uid!, deviceBody(req)));
  });

  secured.post('/micro-apps/context-token', requireService(deps, 'micro_apps'), async (req, res) => {
    const { appId } = contextTokenBody(req);
    res.json(await issueMicroAppContext(deps, req.uid!, appId));
  });

  secured.post('/assistant', requireService(deps, 'assistant'), async (req, res) => {
    const { promptId } = assistantBody(req) as { promptId: (typeof ASSISTANT_PROMPT_IDS)[number] };
    res.json(await askAssistant(deps, req.uid!, promptId));
  });

  app.use(secured);
  app.use(() => notFound());
  app.use(errorHandler);
  return app;
}

function applyCors(req: Request, res: Response, allowed: string[]): void {
  const origin = req.header('origin');
  if (origin && allowed.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  }
}
