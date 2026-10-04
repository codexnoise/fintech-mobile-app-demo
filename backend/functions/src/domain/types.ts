/**
 * Modelo de dominio del BFF de Nexo.
 * Dinero SIEMPRE en enteros (centavos). Fechas en ISO-8601 UTC.
 */

export const SEGMENTS = ['young_digital', 'entrepreneur', 'premium'] as const;
export type Segment = (typeof SEGMENTS)[number];

export const OCCUPATIONS = ['student', 'employee', 'business_owner', 'freelancer', 'retired', 'other'] as const;
export type Occupation = (typeof OCCUPATIONS)[number];

export const INCOME_RANGES = ['low', 'medium', 'high'] as const;
export type IncomeRange = (typeof INCOME_RANGES)[number];

export interface UserProfile {
  uid: string;
  firstName: string;
  birthYear: number;
  occupation: Occupation;
  incomeRange: IncomeRange;
  segment: Segment;
  /** Explicabilidad: por qué se asignó el segmento (auditoría y demo). */
  segmentReason: string;
  createdAt: string;
}

export type AccountType = 'savings' | 'checking';

export interface Account {
  id: string;
  type: AccountType;
  alias: string;
  maskedNumber: string;
  balanceCents: number;
  currency: 'USD';
  updatedAt: string;
}

export const MOVEMENT_CATEGORIES = [
  'salary',
  'transfer',
  'food',
  'transport',
  'shopping',
  'services',
  'entertainment',
  'health',
] as const;
export type MovementCategory = (typeof MOVEMENT_CATEGORIES)[number];

export interface Movement {
  id: string;
  accountId: string;
  /** Firmado: negativo = débito, positivo = crédito. */
  amountCents: number;
  description: string;
  category: MovementCategory;
  createdAt: string;
  balanceAfterCents: number;
  transferId?: string;
}

export interface OpsFlags {
  /** Servicios en mantenimiento/degradados: responden 503 (kill switch). */
  degradedServices: string[];
  microAppsEnabled: boolean;
  assistantEnabled: boolean;
}

export const DEFAULT_OPS_FLAGS: OpsFlags = {
  degradedServices: [],
  microAppsEnabled: true,
  assistantEnabled: true,
};
