import { z } from 'zod';
import type { OpsFlags, Segment } from './types';
import { deterministicInsights, formatUsd, type MonthlySummary } from './insights';

/**
 * Contrato SDUI (schemaVersion 1) — espejo de packages/sdui_engine en la app.
 * El servidor compone QUÉ se muestra; la app decide CÓMO dibujarlo con su
 * registry cerrado. Los datos de dinero (saldos) NO viajan en este documento.
 */

export const ALLOWED_COMPONENT_TYPES = [
  'greeting_header',
  'balance_summary',
  'quick_actions',
  'promo_banner',
  'insight_card',
  'micro_app_tile',
  'tip_list',
  'spending_bars',
] as const;

const actionSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('navigate'), route: z.string().startsWith('/') }),
  z.object({ type: z.literal('open_micro_app'), appId: z.string().min(1) }),
  z.object({ type: z.literal('open_assistant'), promptId: z.string().optional() }),
]);
export type SduiAction = z.infer<typeof actionSchema>;

export const componentSchema = z.object({
  id: z.string().min(1),
  type: z.enum(ALLOWED_COMPONENT_TYPES),
  minAppVersion: z.string().optional(),
  props: z.record(z.string(), z.unknown()).default({}),
});
export type SduiComponent = z.infer<typeof componentSchema>;

export const experienceConfigSchema = z.object({
  schemaVersion: z.literal(1),
  screen: z.string().min(1),
  segment: z.string().min(1),
  version: z.string().min(1),
  ttlSeconds: z.number().int().positive().max(86_400),
  components: z.array(componentSchema).max(30),
});
export type ExperienceConfig = z.infer<typeof experienceConfigSchema>;

export interface ExperienceContext {
  firstName: string;
  segment: Segment;
  appVersion: string;
  summary: MonthlySummary;
  flags: OpsFlags;
}

export type SduiDocument = ExperienceConfig;

/** Valida una config editada por negocio antes de servirla (evita publicar basura). */
export function parseExperienceConfig(raw: unknown): ExperienceConfig | null {
  const result = experienceConfigSchema.safeParse(raw);
  return result.success ? result.data : null;
}

/**
 * Compone el documento final para un usuario:
 * 1. Filtra por versión mínima de la app.
 * 2. Aplica kill switches (micro-apps, asistente).
 * 3. Interpola variables de personalización ({{firstName}}, {{insight}}, ...).
 */
export function composeExperience(config: ExperienceConfig, ctx: ExperienceContext): SduiDocument {
  const insights = deterministicInsights(ctx.summary);
  const vars: Record<string, string> = {
    firstName: ctx.firstName,
    insight: insights[0] ?? 'Revisa tus movimientos para conocer tus hábitos.',
    spent: formatUsd(ctx.summary.spentCents),
    saved: formatUsd(ctx.summary.savedCents),
  };

  const isActionAllowed = (action: unknown): boolean => {
    const parsed = actionSchema.safeParse(action);
    if (!parsed.success) return false;
    if (parsed.data.type === 'open_micro_app') return ctx.flags.microAppsEnabled;
    if (parsed.data.type === 'open_assistant') return ctx.flags.assistantEnabled;
    return true;
  };

  const components: SduiComponent[] = [];
  for (const component of config.components) {
    if (component.minAppVersion && compareSemver(ctx.appVersion, component.minAppVersion) < 0) continue;
    if (component.type === 'micro_app_tile' && !ctx.flags.microAppsEnabled) continue;

    const props = { ...component.props };
    if ('action' in props && !isActionAllowed(props.action)) {
      // Un banner sin acción válida pierde sentido: se omite completo.
      if (component.type === 'promo_banner' || component.type === 'micro_app_tile') continue;
      delete props.action;
    }
    if (Array.isArray(props.actions)) {
      props.actions = (props.actions as Array<Record<string, unknown>>).filter((a) => isActionAllowed(a?.action));
    }
    components.push({ ...component, props: interpolate(props, vars) as Record<string, unknown> });
  }

  return { ...config, segment: ctx.segment, components };
}

function interpolate(value: unknown, vars: Record<string, string>): unknown {
  if (typeof value === 'string') return value.replace(/\{\{(\w+)\}\}/g, (_, key: string) => vars[key] ?? '');
  if (Array.isArray(value)) return value.map((v) => interpolate(v, vars));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, interpolate(v, vars)]));
  }
  return value;
}

export function compareSemver(a: string, b: string): number {
  const parts = (v: string) => v.split(/[+-]/)[0].split('.').map((s) => Number.parseInt(s, 10) || 0);
  const pa = parts(a);
  const pb = parts(b);
  for (let i = 0; i < 3; i++) {
    const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (diff !== 0) return diff;
  }
  return 0;
}
