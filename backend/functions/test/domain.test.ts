import { describe, expect, it } from 'vitest';
import { assignSegment, reevaluateByBalance } from '../src/domain/segmentation';
import { generateSeed } from '../src/domain/seed';
import { evaluateTransfer, TRANSFER_LIMITS, type TransferCommand } from '../src/domain/transfer';
import { deterministicInsights, formatUsd, summarize } from '../src/domain/insights';
import { composeExperience, compareSemver, parseExperienceConfig } from '../src/domain/experience';
import { DEFAULT_OPS_FLAGS, type Account } from '../src/domain/types';
import youngHome from '../src/experience/defaults/young_digital__home.json';
import premiumHome from '../src/experience/defaults/premium__home.json';
import { NOW } from './fixtures';

describe('segmentation', () => {
  it('asigna premium por ingreso alto aunque sea joven', () => {
    expect(assignSegment({ birthYear: 2003, occupation: 'student', incomeRange: 'high', now: NOW })).toEqual({
      segment: 'premium',
      reason: 'income_high',
    });
  });
  it('asigna emprendedor por ocupación', () => {
    expect(assignSegment({ birthYear: 1990, occupation: 'business_owner', incomeRange: 'medium', now: NOW }).segment).toBe('entrepreneur');
    expect(assignSegment({ birthYear: 1990, occupation: 'freelancer', incomeRange: 'low', now: NOW }).segment).toBe('entrepreneur');
  });
  it('asigna joven digital por edad y por defecto', () => {
    expect(assignSegment({ birthYear: 2000, occupation: 'employee', incomeRange: 'low', now: NOW }).reason).toBe('age_le_28');
    expect(assignSegment({ birthYear: 1980, occupation: 'employee', incomeRange: 'low', now: NOW }).reason).toBe('default_digital');
  });
  it('promueve a premium por saldo pero nunca degrada', () => {
    expect(reevaluateByBalance({ segment: 'young_digital', reason: 'x' }, 1_000_000).segment).toBe('premium');
    expect(reevaluateByBalance({ segment: 'premium', reason: 'income_high' }, 0).segment).toBe('premium');
  });
});

describe('seed', () => {
  it('es determinista por uid', () => {
    expect(generateSeed('abc', 'medium', NOW)).toEqual(generateSeed('abc', 'medium', NOW));
    expect(generateSeed('abc', 'medium', NOW)).not.toEqual(generateSeed('xyz', 'medium', NOW));
  });
  it('mantiene la cadena de saldos consistente y nunca negativa', () => {
    for (const uid of ['u1', 'u2', 'u3', 'u4', 'u5']) {
      for (const income of ['low', 'medium', 'high'] as const) {
        const { accounts, movements } = generateSeed(uid, income, NOW);
        for (const account of accounts) {
          const own = movements.filter((m) => m.accountId === account.id);
          expect(own.at(-1)!.balanceAfterCents).toBe(account.balanceCents);
          expect(own.every((m) => m.balanceAfterCents >= 0)).toBe(true);
          expect(own.every((m) => Number.isInteger(m.amountCents))).toBe(true);
        }
      }
    }
  });
});

describe('evaluateTransfer', () => {
  const account = (id: string, balanceCents: number): Account => ({
    id,
    type: 'checking',
    alias: id,
    maskedNumber: '•••• 0000',
    balanceCents,
    currency: 'USD',
    updatedAt: NOW.toISOString(),
  });
  const cmd = (amountCents: number, overrides: Partial<TransferCommand> = {}): TransferCommand => ({
    uid: 'u',
    transferId: 'trf_1',
    fromAccountId: 'checking',
    toAccountId: 'savings',
    amountCents,
    idempotencyKey: 'k',
    now: NOW,
    ...overrides,
  });
  const state = { from: account('checking', 10_000), to: account('savings', 500), dailyDate: null, dailyUsedCents: 0 };

  it('mueve el dinero y genera débito/crédito con saldos resultantes', () => {
    const d = evaluateTransfer(cmd(2_500), state);
    expect(d.ok).toBe(true);
    if (!d.ok) return;
    expect(d.plan.fromBalanceCents).toBe(7_500);
    expect(d.plan.toBalanceCents).toBe(3_000);
    expect(d.plan.debit.amountCents).toBe(-2_500);
    expect(d.plan.credit.amountCents).toBe(2_500);
  });

  it.each([
    [cmd(0), 'invalid_amount'],
    [cmd(1.5), 'invalid_amount'],
    [cmd(100, { toAccountId: 'checking' }), 'same_account'],
    [cmd(10_001), 'insufficient_funds'],
    [cmd(TRANSFER_LIMITS.maxPerTransferCents + 1), 'exceeds_per_transfer_limit'],
  ])('rechaza %#', (command, code) => {
    const d = evaluateTransfer(command, { ...state, from: account('checking', 10_000_000) });
    if (code === 'insufficient_funds') {
      expect(evaluateTransfer(command, state)).toEqual({ ok: false, code });
    } else {
      expect(d).toEqual({ ok: false, code });
    }
  });

  it('respeta el límite diario y lo reinicia al cambiar de día', () => {
    const rich = { ...state, from: account('checking', 10_000_000) };
    expect(evaluateTransfer(cmd(100), { ...rich, dailyDate: '2026-10-04', dailyUsedCents: TRANSFER_LIMITS.dailyMaxCents })).toEqual({
      ok: false,
      code: 'exceeds_daily_limit',
    });
    expect(evaluateTransfer(cmd(100), { ...rich, dailyDate: '2026-10-03', dailyUsedCents: TRANSFER_LIMITS.dailyMaxCents }).ok).toBe(true);
  });

  it('rechaza cuentas inexistentes', () => {
    expect(evaluateTransfer(cmd(100), { ...state, to: null })).toEqual({ ok: false, code: 'account_not_found' });
  });
});

describe('insights', () => {
  it('resume ingresos, gastos y ahorro sin contar transferencias internas como gasto', () => {
    const { movements } = generateSeed('u1', 'medium', NOW);
    const s = summarize(movements, NOW);
    expect(s.incomeCents).toBe(160_000);
    expect(s.spentCents).toBeGreaterThan(0);
    expect(s.savedCents).toBe(16_000);
    expect(s.topCategory).not.toBeNull();
    expect(deterministicInsights(s).length).toBeGreaterThanOrEqual(2);
  });
  it('formatea USD', () => {
    expect(formatUsd(123456789)).toBe('$1,234,567.89');
    expect(formatUsd(-5)).toBe('-$0.05');
  });
});

describe('experience', () => {
  const summary = summarize(generateSeed('u1', 'medium', NOW).movements, NOW);
  const ctx = { firstName: 'Ana', segment: 'young_digital' as const, appVersion: '1.0.0', summary, flags: DEFAULT_OPS_FLAGS };

  it('los defaults versionados cumplen el contrato', () => {
    expect(parseExperienceConfig(youngHome)).not.toBeNull();
    expect(parseExperienceConfig(premiumHome)).not.toBeNull();
  });

  it('interpola variables de personalización', () => {
    const doc = composeExperience(parseExperienceConfig(youngHome)!, ctx);
    expect(doc.components[0].props.title).toBe('Hola, Ana 👋');
    expect(JSON.stringify(doc)).not.toContain('{{');
  });

  it('aplica el kill switch de micro-apps y asistente', () => {
    const doc = composeExperience(parseExperienceConfig(premiumHome)!, {
      ...ctx,
      flags: { ...DEFAULT_OPS_FLAGS, microAppsEnabled: false, assistantEnabled: false },
    });
    const json = JSON.stringify(doc);
    expect(json).not.toContain('open_micro_app');
    expect(json).not.toContain('open_assistant');
    expect(doc.components.some((c) => c.type === 'micro_app_tile')).toBe(false);
    expect(doc.components.some((c) => c.type === 'promo_banner')).toBe(false);
  });

  it('filtra por versión mínima de la app', () => {
    const config = parseExperienceConfig({
      ...youngHome,
      components: [...youngHome.components, { id: 'new', type: 'insight_card', minAppVersion: '2.0.0', props: {} }],
    })!;
    expect(composeExperience(config, ctx).components.some((c) => c.id === 'new')).toBe(false);
    expect(composeExperience(config, { ...ctx, appVersion: '2.1.0' }).components.some((c) => c.id === 'new')).toBe(true);
  });

  it('rechaza configs con tipos fuera del catálogo', () => {
    expect(parseExperienceConfig({ ...youngHome, components: [{ id: 'x', type: 'webview_anything', props: {} }] })).toBeNull();
  });

  it('compareSemver', () => {
    expect(compareSemver('1.10.0', '1.9.0')).toBeGreaterThan(0);
    expect(compareSemver('1.0.0+3', '1.0.0')).toBe(0);
  });
});
