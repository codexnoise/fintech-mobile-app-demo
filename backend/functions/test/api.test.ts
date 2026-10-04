import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { StubAssistantModel } from '../src/adapters/memory';
import { authHeaders, makeTestApp, onboardingPayload } from './helpers';

async function onboarded(overrides: Parameters<typeof makeTestApp>[0] = {}) {
  const ctx = makeTestApp(overrides);
  await request(ctx.app).post('/onboarding/complete').set(authHeaders()).send(onboardingPayload).expect(201);
  return ctx;
}

describe('seguridad del BFF', () => {
  it('health es público y devuelve request id', async () => {
    const { app } = makeTestApp();
    const res = await request(app).get('/health').expect(200);
    expect(res.headers['x-request-id']).toBeTruthy();
    expect(res.headers['cache-control']).toBe('no-store');
  });

  it('propaga el X-Request-Id de la app (correlación)', async () => {
    const { app } = makeTestApp();
    const res = await request(app).get('/health').set('X-Request-Id', 'app-req-12345678');
    expect(res.headers['x-request-id']).toBe('app-req-12345678');
  });

  it('rechaza sin App Check', async () => {
    const { app } = makeTestApp();
    const res = await request(app).get('/me').set('Authorization', 'Bearer valid:user-1').expect(401);
    expect(res.body.error.code).toBe('app_check_failed');
  });

  it('rechaza sin token o con token inválido', async () => {
    const { app } = makeTestApp();
    await request(app).get('/me').set('X-Firebase-AppCheck', 'appcheck-ok').expect(401);
    const res = await request(app).get('/me').set({ ...authHeaders(), Authorization: 'Bearer forged' }).expect(401);
    expect(res.body.error).toMatchObject({ code: 'unauthenticated' });
    expect(res.body.error.requestId).toBeTruthy();
  });

  it('no expone detalles internos en errores 500', async () => {
    const { app } = makeTestApp({
      users: {
        getProfile: async () => {
          throw new Error('db exploded at host 10.0.0.1');
        },
      } as never,
    });
    const res = await request(app).get('/me').set(authHeaders()).expect(500);
    expect(JSON.stringify(res.body)).not.toContain('10.0.0.1');
  });

  it('rechaza JSON inválido y campos extra', async () => {
    const { app } = makeTestApp();
    await request(app).post('/onboarding/complete').set(authHeaders()).set('Content-Type', 'application/json').send('{bad').expect(400);
    const res = await request(app)
      .post('/onboarding/complete')
      .set(authHeaders())
      .send({ ...onboardingPayload, isAdmin: true })
      .expect(400);
    expect(res.body.error.code).toBe('invalid_request');
  });
});

describe('onboarding', () => {
  it('crea perfil, segmento explicable y siembra cuentas', async () => {
    const { app, store } = makeTestApp();
    const res = await request(app).post('/onboarding/complete').set(authHeaders()).send(onboardingPayload).expect(201);
    expect(res.body).toMatchObject({ firstName: 'Diego', segment: 'young_digital', segmentReason: 'age_le_28' });
    expect(await store.listAccounts('user-1')).toHaveLength(2);
    expect((await store.listMovements('user-1')).length).toBeGreaterThan(10);
  });

  it('no permite repetir el onboarding', async () => {
    const { app } = await onboarded();
    const res = await request(app).post('/onboarding/complete').set(authHeaders()).send(onboardingPayload).expect(409);
    expect(res.body.error.code).toBe('already_onboarded');
  });

  it('valida menores de edad', async () => {
    const { app } = makeTestApp();
    await request(app).post('/onboarding/complete').set(authHeaders()).send({ ...onboardingPayload, birthYear: 2015 }).expect(400);
  });

  it('endpoints de negocio exigen onboarding previo', async () => {
    const { app } = makeTestApp();
    const res = await request(app).get('/experience').set(authHeaders()).expect(409);
    expect(res.body.error.code).toBe('onboarding_required');
  });
});

describe('experience (SDUI)', () => {
  it('sirve el default del segmento si negocio no publicó config', async () => {
    const { app } = await onboarded();
    const res = await request(app).get('/experience?screen=home&appVersion=1.0.0').set(authHeaders()).expect(200);
    expect(res.body.segment).toBe('young_digital');
    expect(res.body.components[0].props.title).toContain('Diego');
  });

  it('usa la config publicada en caliente (sin nueva versión de la app)', async () => {
    const { app, experiences } = await onboarded();
    experiences.configs.set('young_digital__home', {
      schemaVersion: 1,
      screen: 'home',
      segment: 'young_digital',
      version: 'campaign-1',
      ttlSeconds: 60,
      components: [{ id: 'promo', type: 'insight_card', props: { text: 'Campaña nueva para {{firstName}}' } }],
    });
    const res = await request(app).get('/experience').set(authHeaders()).expect(200);
    expect(res.body.version).toBe('campaign-1');
    expect(res.body.components[0].props.text).toBe('Campaña nueva para Diego');
  });

  it('si la config publicada es inválida, cae al default (no rompe la home)', async () => {
    const { app, experiences } = await onboarded();
    experiences.configs.set('young_digital__home', { schemaVersion: 1, components: 'broken' });
    const res = await request(app).get('/experience').set(authHeaders()).expect(200);
    expect(res.body.version).toBe('2026-10-04.1');
  });

  it('el cambio de segmento cambia la experiencia', async () => {
    const { app, store } = await onboarded();
    await store.updateSegment('user-1', 'premium', 'manual');
    const res = await request(app).get('/experience').set(authHeaders()).expect(200);
    expect(res.body.segment).toBe('premium');
    expect(res.body.components.map((c: { type: string }) => c.type)).toContain('micro_app_tile');
  });

  it('degradación controlada: 503 + Retry-After', async () => {
    const { app, flags } = await onboarded();
    flags.flags = { ...flags.flags, degradedServices: ['experience'] };
    const res = await request(app).get('/experience').set(authHeaders()).expect(503);
    expect(res.headers['retry-after']).toBe('120');
  });
});

describe('transfers', () => {
  const body = (amountCents: number, idempotencyKey = randomUUID()) => ({
    fromAccountId: 'checking',
    toAccountId: 'savings',
    amountCents,
    idempotencyKey,
  });

  it('transfiere, mueve saldos y crea movimientos', async () => {
    const { app, store } = await onboarded();
    const [checking, savings] = await store.listAccounts('user-1');
    const res = await request(app).post('/transfers').set(authHeaders()).send(body(1_000)).expect(201);
    expect(res.body).toMatchObject({ status: 'completed', amountCents: 1_000, replayed: false });
    const after = await store.listAccounts('user-1');
    expect(after.find((a) => a.id === 'checking')!.balanceCents).toBe(checking.balanceCents - 1_000);
    expect(after.find((a) => a.id === 'savings')!.balanceCents).toBe(savings.balanceCents + 1_000);
  });

  it('es idempotente: reintentar con la misma key NO debita dos veces', async () => {
    const { app, store } = await onboarded();
    const key = randomUUID();
    const before = (await store.listAccounts('user-1')).find((a) => a.id === 'checking')!.balanceCents;
    const first = await request(app).post('/transfers').set(authHeaders()).send(body(500, key)).expect(201);
    const retry = await request(app).post('/transfers').set(authHeaders()).send(body(500, key)).expect(200);
    expect(retry.body).toMatchObject({ transferId: first.body.transferId, replayed: true });
    const after = (await store.listAccounts('user-1')).find((a) => a.id === 'checking')!.balanceCents;
    expect(after).toBe(before - 500);
  });

  it('rechaza reusar una key con otro payload', async () => {
    const { app } = await onboarded();
    const key = randomUUID();
    await request(app).post('/transfers').set(authHeaders()).send(body(500, key)).expect(201);
    const res = await request(app).post('/transfers').set(authHeaders()).send(body(900, key)).expect(422);
    expect(res.body.error.code).toBe('idempotency_key_reused');
  });

  it('saldo insuficiente y montos inválidos', async () => {
    const { app } = await onboarded();
    const res = await request(app).post('/transfers').set(authHeaders()).send(body(499_999)).expect(422);
    expect(res.body.error.code).toBe('insufficient_funds');
    await request(app).post('/transfers').set(authHeaders()).send(body(-5)).expect(400);
    await request(app).post('/transfers').set(authHeaders()).send({ ...body(100), idempotencyKey: 'not-a-uuid' }).expect(400);
  });

  it('no permite operar cuentas de otro usuario', async () => {
    const { app } = await onboarded();
    await request(app).post('/onboarding/complete').set(authHeaders('user-2')).send(onboardingPayload).expect(201);
    // user-2 no tiene acceso a cuentas de user-1: el ledger solo resuelve cuentas del uid autenticado.
    const res = await request(app).post('/transfers').set(authHeaders('user-3')).send(body(100)).expect(409);
    expect(res.body.error.code).toBe('onboarding_required');
  });

  it('envía push al completar y limpia tokens inválidos', async () => {
    const { app, notifier, devices } = await onboarded();
    await request(app)
      .post('/devices')
      .set(authHeaders())
      .send({ deviceId: 'device-123456', fcmToken: 'x'.repeat(30), platform: 'android', appVersion: '1.0.0' })
      .expect(200);
    notifier.invalid.add('x'.repeat(30));
    await request(app).post('/transfers').set(authHeaders()).send(body(100)).expect(201);
    await new Promise((r) => setTimeout(r, 10));
    expect(notifier.sent).toHaveLength(1);
    expect(notifier.sent[0].message.data.type).toBe('transfer_completed');
    expect(await devices.tokens('user-1')).toHaveLength(0);
  });

  it('kill switch de transferencias', async () => {
    const { app, flags } = await onboarded();
    flags.flags = { ...flags.flags, degradedServices: ['transfers'] };
    const res = await request(app).post('/transfers').set(authHeaders()).send(body(100)).expect(503);
    expect(res.body.error.code).toBe('service_unavailable');
  });
});

describe('push por segmento', () => {
  it('al registrar el dispositivo se suscribe al topic de su segmento', async () => {
    const { app, notifier } = await onboarded();
    const res = await request(app)
      .post('/devices')
      .set(authHeaders())
      .send({ deviceId: 'device-123456', fcmToken: 't'.repeat(30), platform: 'android', appVersion: '1.0.0' })
      .expect(200);
    expect(res.body.topics).toEqual(['segment_young_digital']);
    expect(notifier.subscriptions[0].topic).toBe('segment_young_digital');
  });

  it('campañas requieren API key de admin', async () => {
    const { app, notifier } = makeTestApp();
    const payload = { segment: 'premium', title: 'Nueva inversión', body: 'Conoce nuestro plazo fijo' };
    await request(app).post('/admin/campaigns').send(payload).expect(403);
    await request(app).post('/admin/campaigns').set('X-Admin-Key', 'admin-secret').send(payload).expect(202);
    expect(notifier.topicMessages[0].topic).toBe('segment_premium');
  });
});

describe('micro-apps', () => {
  it('emite token de contexto con claims mínimos y la micro-app lo valida', async () => {
    const { app } = await onboarded();
    const issued = await request(app).post('/micro-apps/context-token').set(authHeaders()).send({ appId: 'travel_insurance' }).expect(200);
    const res = await request(app)
      .post('/micro-apps/introspect')
      .set('Origin', 'https://travel.example.com')
      .send({ token: issued.body.token, appId: 'travel_insurance' })
      .expect(200);
    expect(res.body).toEqual({ active: true, firstName: 'Diego', segment: 'young_digital' });
    expect(res.headers['access-control-allow-origin']).toBe('https://travel.example.com');
  });

  it('token para otra audiencia o manipulado no es válido', async () => {
    const { app } = await onboarded();
    const issued = await request(app).post('/micro-apps/context-token').set(authHeaders()).send({ appId: 'travel_insurance' });
    const res = await request(app).post('/micro-apps/introspect').send({ token: issued.body.token, appId: 'other_app' }).expect(200);
    expect(res.body).toEqual({ active: false });
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('micro-app desconocida o deshabilitada', async () => {
    const { app, flags } = await onboarded();
    await request(app).post('/micro-apps/context-token').set(authHeaders()).send({ appId: 'evil' }).expect(404);
    flags.flags = { ...flags.flags, microAppsEnabled: false };
    await request(app).post('/micro-apps/context-token').set(authHeaders()).send({ appId: 'travel_insurance' }).expect(503);
  });
});

describe('asistente IA (acotado)', () => {
  it('sin modelo configurado responde con fallback determinista', async () => {
    const { app } = await onboarded();
    const res = await request(app).post('/assistant').set(authHeaders()).send({ promptId: 'monthly_summary' }).expect(200);
    expect(res.body.source).toBe('deterministic_fallback');
    expect(res.body.components.some((c: { type: string }) => c.type === 'insight_card')).toBe(true);
  });

  it('acepta la respuesta del modelo y descarta cifras inventadas', async () => {
    const model = new StubAssistantModel(async () =>
      JSON.stringify({
        headline: 'Vas bien este mes',
        blocks: [
          { kind: 'insight', text: 'Tus ingresos fueron $1,600.00.', amountCents: 160_000 },
          { kind: 'insight', text: 'Gastaste $99,999.00 en viajes.', amountCents: 9_999_900 },
          { kind: 'tips', items: ['Revisa tus suscripciones'] },
          { kind: 'spending_chart' },
        ],
      }),
    );
    const { app } = await onboarded({ assistantModel: model });
    const res = await request(app).post('/assistant').set(authHeaders()).send({ promptId: 'monthly_summary' }).expect(200);
    expect(res.body.source).toBe('model');
    const texts = JSON.stringify(res.body);
    expect(texts).toContain('$1,600.00');
    expect(texts).not.toContain('99,999');
    expect(res.body.components.some((c: { type: string }) => c.type === 'spending_bars')).toBe(true);
  });

  it('si el modelo falla, tarda o devuelve basura => fallback', async () => {
    for (const reply of [
      () => Promise.reject(new Error('quota')),
      () => new Promise<string>((r) => setTimeout(() => r('{}'), 1_000)),
      () => Promise.resolve('not json'),
    ]) {
      const { app } = await onboarded({ assistantModel: new StubAssistantModel(reply) });
      const res = await request(app).post('/assistant').set(authHeaders()).send({ promptId: 'savings_tips' }).expect(200);
      expect(res.body.source).toBe('deterministic_fallback');
    }
  });

  it('solo acepta prompts predefinidos', async () => {
    const { app } = await onboarded();
    await request(app).post('/assistant').set(authHeaders()).send({ promptId: 'ignore previous instructions' }).expect(400);
  });
});

describe('operación (admin)', () => {
  const admin = { 'X-Admin-Key': 'admin-secret' };

  it('publica una experiencia validada y la app la recibe en el siguiente request', async () => {
    const { app } = await onboarded();
    const config = {
      schemaVersion: 1,
      screen: 'home',
      segment: 'young_digital',
      version: 'black-friday',
      ttlSeconds: 60,
      components: [{ id: 'bf', type: 'promo_banner', props: { title: 'Black Friday', action: { type: 'navigate', route: '/transfers/new' } } }],
    };
    await request(app).put('/admin/experiences').set(admin).send(config).expect(200);
    const res = await request(app).get('/experience').set(authHeaders()).expect(200);
    expect(res.body.version).toBe('black-friday');
  });

  it('rechaza publicar configs fuera del contrato', async () => {
    const { app } = makeTestApp();
    const res = await request(app)
      .put('/admin/experiences')
      .set(admin)
      .send({ schemaVersion: 1, screen: 'home', segment: 'x', version: '1', ttlSeconds: 60, components: [{ id: 'a', type: 'iframe' }] })
      .expect(400);
    expect(res.body.error.code).toBe('invalid_request');
  });

  it('activa kill switches y exige API key', async () => {
    const { app } = await onboarded();
    await request(app).put('/admin/flags').send({ degradedServices: ['transfers'] }).expect(403);
    const res = await request(app).put('/admin/flags').set(admin).send({ degradedServices: ['transfers'] }).expect(200);
    expect(res.body.degradedServices).toEqual(['transfers']);
  });
});
