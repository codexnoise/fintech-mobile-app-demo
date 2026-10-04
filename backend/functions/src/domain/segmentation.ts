import type { IncomeRange, Occupation, Segment } from './types';

export interface SegmentationInput {
  birthYear: number;
  occupation: Occupation;
  incomeRange: IncomeRange;
  now: Date;
}

export interface SegmentAssignment {
  segment: Segment;
  reason: string;
}

/** Umbral de saldo total (centavos) que promueve a Premium por comportamiento. */
export const PREMIUM_BALANCE_THRESHOLD_CENTS = 1_000_000; // USD 10.000

/**
 * Reglas deterministas y explicables (orden = prioridad).
 * Se mantienen en backend para poder cambiarlas sin publicar la app.
 */
export function assignSegment(input: SegmentationInput): SegmentAssignment {
  const age = input.now.getUTCFullYear() - input.birthYear;
  if (input.incomeRange === 'high') {
    return { segment: 'premium', reason: 'income_high' };
  }
  if (input.occupation === 'business_owner' || input.occupation === 'freelancer') {
    return { segment: 'entrepreneur', reason: `occupation_${input.occupation}` };
  }
  if (age <= 28) {
    return { segment: 'young_digital', reason: 'age_le_28' };
  }
  return { segment: 'young_digital', reason: 'default_digital' };
}

/**
 * Re-evaluación por comportamiento: un saldo alto promueve a Premium.
 * Nunca degrada automáticamente (evita cambios bruscos de experiencia).
 */
export function reevaluateByBalance(current: SegmentAssignment, totalBalanceCents: number): SegmentAssignment {
  if (current.segment !== 'premium' && totalBalanceCents >= PREMIUM_BALANCE_THRESHOLD_CENTS) {
    return { segment: 'premium', reason: 'balance_ge_threshold' };
  }
  return current;
}
