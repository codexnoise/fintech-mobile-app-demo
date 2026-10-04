import { z } from 'zod';
import { CATEGORY_LABELS, deterministicInsights, formatUsd, type MonthlySummary } from './insights';
import { MOVEMENT_CATEGORIES, type MovementCategory } from './types';
import type { SduiComponent, SduiDocument } from './experience';

/**
 * Asistente financiero con IA generativa, ACOTADO:
 * - Solo prompts predefinidos (sin texto libre => menos prompt injection).
 * - El modelo recibe agregados SIN PII y devuelve CONTENIDO estructurado
 *   (JSON con schema), nunca UI ni acciones.
 * - Cada cifra se verifica contra los agregados reales; lo no verificable se descarta.
 * - El servidor arma el documento SDUI con componentes de SOLO LECTURA.
 * - Si el modelo falla o tarda, se responde con insights deterministas.
 */

export const ASSISTANT_PROMPTS = {
  monthly_summary: '¿Cómo voy este mes con mis finanzas?',
  spending_breakdown: '¿En qué estoy gastando más y cómo lo reduzco?',
  savings_tips: '¿Cuánto podría ahorrar el próximo mes?',
} as const;
export type AssistantPromptId = keyof typeof ASSISTANT_PROMPTS;
export const ASSISTANT_PROMPT_IDS = Object.keys(ASSISTANT_PROMPTS) as AssistantPromptId[];

export const SYSTEM_INSTRUCTION = [
  'Eres el asistente financiero de una app bancaria de Ecuador (moneda USD).',
  'Responde en español neutro, cálido y breve. Máximo 3 bloques "insight" y 1 bloque "tips" con hasta 4 consejos.',
  'Usa EXCLUSIVAMENTE las cifras del JSON de datos. Nunca inventes montos, tasas ni productos.',
  'Si mencionas un monto, ponlo también en amountCents (entero, centavos) y la categoría si aplica.',
  'No des recomendaciones de inversión específicas ni pidas datos personales.',
].join(' ');

/** Schema de salida esperado del modelo (plano, compatible con structured output). */
export const modelOutputSchema = z.object({
  headline: z.string().min(1).max(140),
  blocks: z
    .array(
      z.object({
        kind: z.enum(['insight', 'tips', 'spending_chart']),
        text: z.string().max(280).optional(),
        amountCents: z.number().int().optional(),
        category: z.enum(MOVEMENT_CATEGORIES).optional(),
        items: z.array(z.string().max(180)).max(5).optional(),
      }),
    )
    .max(6),
});
export type ModelOutput = z.infer<typeof modelOutputSchema>;

/** Mismo schema en formato OpenAPI-subset para Gemini (responseSchema). */
export const GEMINI_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    headline: { type: 'STRING' },
    blocks: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          kind: { type: 'STRING', enum: ['insight', 'tips', 'spending_chart'] },
          text: { type: 'STRING' },
          amountCents: { type: 'INTEGER' },
          category: { type: 'STRING', enum: [...MOVEMENT_CATEGORIES] },
          items: { type: 'ARRAY', items: { type: 'STRING' } },
        },
        required: ['kind'],
      },
    },
  },
  required: ['headline', 'blocks'],
} as const;

export function buildUserPrompt(promptId: AssistantPromptId, summary: MonthlySummary): string {
  const data = {
    periodo: 'últimos 30 días',
    ingresosCents: summary.incomeCents,
    gastosCents: summary.spentCents,
    ahorroCents: summary.savedCents,
    gastosPorCategoriaCents: summary.byCategory,
  };
  return `Pregunta del cliente: "${ASSISTANT_PROMPTS[promptId]}"\nDatos (JSON): ${JSON.stringify(data)}`;
}

export interface VerificationReport {
  verifiedClaims: number;
  droppedClaims: number;
}

const TOLERANCE = (cents: number) => Math.max(100, Math.round(Math.abs(cents) * 0.01));
const near = (a: number, b: number) => Math.abs(a - b) <= TOLERANCE(b);

/** Conjunto de cifras reales contra las que se verifica cualquier monto del modelo. */
function verifiedAmounts(summary: MonthlySummary): number[] {
  return [summary.incomeCents, summary.spentCents, summary.savedCents, ...Object.values(summary.byCategory)].filter(
    (v): v is number => typeof v === 'number' && v > 0,
  );
}

/** Extrae montos escritos en texto ("$1,234.56") y los pasa a centavos. */
export function amountsInText(text: string): number[] {
  const matches = text.match(/\$\s?\d[\d,]*(?:\.\d{1,2})?/g) ?? [];
  return matches.map((m) => Math.round(Number.parseFloat(m.replace(/[$,\s]/g, '')) * 100));
}

/**
 * Verifica la salida del modelo. Devuelve el contenido aceptado y un reporte
 * (útil para observabilidad: tasa de alucinación por versión de prompt/modelo).
 */
export function verifyModelOutput(
  output: ModelOutput,
  summary: MonthlySummary,
): { output: ModelOutput; report: VerificationReport } {
  const real = verifiedAmounts(summary);
  let verifiedClaims = 0;
  let droppedClaims = 0;

  const blocks = output.blocks.filter((block) => {
    if (block.kind !== 'insight') return true;
    const claims: number[] = [...amountsInText(block.text ?? '')];
    if (block.amountCents !== undefined) claims.push(Math.abs(block.amountCents));
    if (block.category && block.amountCents !== undefined) {
      const categoryReal = summary.byCategory[block.category];
      if (categoryReal === undefined || !near(Math.abs(block.amountCents), categoryReal)) {
        droppedClaims++;
        return false;
      }
    }
    const ok = claims.every((c) => real.some((r) => near(c, r)));
    if (ok) verifiedClaims += claims.length;
    else droppedClaims++;
    return ok && Boolean(block.text);
  });

  return { output: { ...output, blocks }, report: { verifiedClaims, droppedClaims } };
}

export type AssistantSource = 'model' | 'deterministic_fallback';

/** Convierte contenido (validado o determinista) en un documento SDUI de solo lectura. */
export function buildAssistantDocument(params: {
  promptId: AssistantPromptId;
  summary: MonthlySummary;
  content: ModelOutput | null;
  source: AssistantSource;
  modelName?: string;
}): SduiDocument & { source: AssistantSource; model?: string } {
  const { summary, content } = params;
  const components: SduiComponent[] = [];

  const headline = content?.headline ?? 'Tu resumen de los últimos 30 días';
  components.push({ id: 'headline', type: 'greeting_header', props: { title: ASSISTANT_PROMPTS[params.promptId], subtitle: headline } });

  const insightTexts = content
    ? content.blocks.filter((b) => b.kind === 'insight' && b.text).map((b) => b.text as string)
    : deterministicInsights(summary);
  insightTexts.slice(0, 3).forEach((text, i) =>
    components.push({ id: `insight-${i}`, type: 'insight_card', props: { text, verified: true } }),
  );

  // Las cifras del gráfico SIEMPRE salen de datos reales, nunca del modelo.
  const wantsChart = content ? content.blocks.some((b) => b.kind === 'spending_chart') : true;
  if (wantsChart && summary.spentCents > 0) {
    const bars = (Object.entries(summary.byCategory) as Array<[MovementCategory, number]>)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([category, amountCents]) => ({ label: CATEGORY_LABELS[category], amountCents, formatted: formatUsd(amountCents) }));
    components.push({ id: 'spending', type: 'spending_bars', props: { title: 'Gastos por categoría', bars } });
  }

  const tips = content?.blocks.find((b) => b.kind === 'tips')?.items ?? defaultTips(params.promptId);
  if (tips.length) components.push({ id: 'tips', type: 'tip_list', props: { title: 'Sugerencias', items: tips.slice(0, 4) } });

  return {
    schemaVersion: 1,
    screen: 'assistant',
    segment: 'any',
    version: `assistant-${params.source}`,
    ttlSeconds: 60,
    components,
    source: params.source,
    ...(params.modelName ? { model: params.modelName } : {}),
  };
}

function defaultTips(promptId: AssistantPromptId): string[] {
  switch (promptId) {
    case 'savings_tips':
      return ['Programa un ahorro automático apenas recibas tu ingreso.', 'Define un tope mensual para tu categoría de mayor gasto.'];
    case 'spending_breakdown':
      return ['Revisa suscripciones que ya no usas.', 'Agrupa tus compras del supermercado en una sola salida semanal.'];
    case 'monthly_summary':
      return ['Mantén un fondo de emergencia de 3 meses de gastos.'];
  }
}
