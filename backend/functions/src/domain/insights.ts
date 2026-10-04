import type { Movement, MovementCategory } from './types';

export interface MonthlySummary {
  incomeCents: number;
  spentCents: number;
  savedCents: number;
  byCategory: Partial<Record<MovementCategory, number>>;
  topCategory: MovementCategory | null;
  topCategoryCents: number;
}

export const CATEGORY_LABELS: Record<MovementCategory, string> = {
  salary: 'nómina',
  transfer: 'transferencias',
  food: 'comida',
  transport: 'transporte',
  shopping: 'compras',
  services: 'servicios',
  entertainment: 'entretenimiento',
  health: 'salud',
};

/** Resumen de los últimos 30 días. Fuente de verdad para insights y validación de IA. */
export function summarize(movements: Movement[], now: Date): MonthlySummary {
  const since = now.getTime() - 30 * 24 * 60 * 60 * 1000;
  const recent = movements.filter((m) => new Date(m.createdAt).getTime() >= since);
  const byCategory: Partial<Record<MovementCategory, number>> = {};
  let incomeCents = 0;
  let spentCents = 0;
  let savedCents = 0;

  for (const m of recent) {
    if (m.category === 'salary' && m.amountCents > 0) incomeCents += m.amountCents;
    if (m.category === 'transfer') {
      if (m.accountId === 'savings' && m.amountCents > 0) savedCents += m.amountCents;
      continue; // movimientos internos no son gasto
    }
    if (m.amountCents < 0) {
      const amount = -m.amountCents;
      spentCents += amount;
      byCategory[m.category] = (byCategory[m.category] ?? 0) + amount;
    }
  }

  let topCategory: MovementCategory | null = null;
  let topCategoryCents = 0;
  for (const [category, cents] of Object.entries(byCategory) as Array<[MovementCategory, number]>) {
    if (cents > topCategoryCents) {
      topCategory = category;
      topCategoryCents = cents;
    }
  }
  return { incomeCents, spentCents, savedCents, byCategory, topCategory, topCategoryCents };
}

/** Insights deterministas (también usados como fallback del asistente). */
export function deterministicInsights(s: MonthlySummary): string[] {
  const insights: string[] = [];
  if (s.topCategory) {
    insights.push(`Tu mayor gasto del mes fue en ${CATEGORY_LABELS[s.topCategory]}: ${formatUsd(s.topCategoryCents)}.`);
  }
  if (s.incomeCents > 0) {
    const pct = Math.round((s.spentCents / s.incomeCents) * 100);
    insights.push(`Gastaste el ${pct}% de tus ingresos de los últimos 30 días.`);
  }
  if (s.savedCents > 0) insights.push(`Ahorraste ${formatUsd(s.savedCents)} este mes. ¡Buen ritmo!`);
  return insights;
}

export function formatUsd(cents: number): string {
  const negative = cents < 0;
  const abs = Math.abs(cents);
  const major = Math.floor(abs / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const minor = String(abs % 100).padStart(2, '0');
  return `${negative ? '-' : ''}$${major}.${minor}`;
}
