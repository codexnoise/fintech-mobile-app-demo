import type { Account, IncomeRange, Movement, MovementCategory } from './types';

/**
 * Genera el "core bancario simulado" de un cliente nuevo: 2 cuentas y ~30 días
 * de movimientos realistas. Es determinista por uid (mismo uid => mismos datos),
 * lo que hace reproducibles los tests y la demo.
 */

const MONTHLY_INCOME_CENTS: Record<IncomeRange, number> = {
  low: 60_000, // USD 600
  medium: 160_000, // USD 1.600
  high: 650_000, // USD 6.500
};

const SAVINGS_OPENING_CENTS: Record<IncomeRange, number> = {
  low: 25_000,
  medium: 180_000,
  high: 1_450_000,
};

const EXPENSES: ReadonlyArray<{ category: MovementCategory; description: string; minPct: number; maxPct: number }> = [
  { category: 'food', description: 'Supermaxi', minPct: 3, maxPct: 8 },
  { category: 'food', description: 'Restaurante', minPct: 1, maxPct: 4 },
  { category: 'transport', description: 'Gasolinera Primax', minPct: 2, maxPct: 5 },
  { category: 'transport', description: 'Uber', minPct: 0.5, maxPct: 2 },
  { category: 'shopping', description: 'Compra en línea', minPct: 2, maxPct: 7 },
  { category: 'services', description: 'Pago de luz', minPct: 1, maxPct: 3 },
  { category: 'services', description: 'Plan celular', minPct: 1, maxPct: 2 },
  { category: 'entertainment', description: 'Streaming', minPct: 0.5, maxPct: 1.5 },
  { category: 'health', description: 'Farmacia', minPct: 0.5, maxPct: 3 },
];

export interface SeedResult {
  accounts: Account[];
  movements: Movement[];
}

export function generateSeed(uid: string, incomeRange: IncomeRange, now: Date): SeedResult {
  const rand = mulberry32(fnv1a(uid));
  const income = MONTHLY_INCOME_CENTS[incomeRange];
  const nowIso = now.toISOString();

  const checking: Account = {
    id: 'checking',
    type: 'checking',
    alias: 'Cuenta corriente',
    maskedNumber: `•••• ${fourDigits(rand)}`,
    balanceCents: 0,
    currency: 'USD',
    updatedAt: nowIso,
  };
  const savings: Account = {
    id: 'savings',
    type: 'savings',
    alias: 'Cuenta de ahorros',
    maskedNumber: `•••• ${fourDigits(rand)}`,
    balanceCents: 0,
    currency: 'USD',
    updatedAt: nowIso,
  };

  type Draft = Omit<Movement, 'id' | 'balanceAfterCents'>;
  const drafts: Draft[] = [];
  const dayMs = 24 * 60 * 60 * 1000;
  const at = (daysAgo: number, hour: number) =>
    new Date(now.getTime() - daysAgo * dayMs - (24 - hour) * 60 * 60 * 1000).toISOString();

  // Ingresos (dos quincenas) en la cuenta corriente.
  drafts.push({ accountId: 'checking', amountCents: Math.round(income / 2), description: 'Pago de nómina', category: 'salary', createdAt: at(28, 9) });
  drafts.push({ accountId: 'checking', amountCents: Math.round(income / 2), description: 'Pago de nómina', category: 'salary', createdAt: at(13, 9) });

  // Gastos distribuidos en 30 días.
  const expenseCount = 16 + Math.floor(rand() * 6);
  for (let i = 0; i < expenseCount; i++) {
    const e = EXPENSES[Math.floor(rand() * EXPENSES.length)];
    const pct = e.minPct + rand() * (e.maxPct - e.minPct);
    const amount = Math.max(150, Math.round((income * pct) / 100));
    drafts.push({
      accountId: 'checking',
      amountCents: -amount,
      description: e.description,
      category: e.category,
      createdAt: at(Math.floor(rand() * 29) + 1, 8 + Math.floor(rand() * 12)),
    });
  }

  // Ahorro programado: corriente -> ahorros.
  const saving = Math.round(income * 0.1);
  drafts.push({ accountId: 'checking', amountCents: -saving, description: 'Ahorro programado', category: 'transfer', createdAt: at(12, 10) });
  drafts.push({ accountId: 'savings', amountCents: saving, description: 'Ahorro programado', category: 'transfer', createdAt: at(12, 10) });

  drafts.sort((a, b) => a.createdAt.localeCompare(b.createdAt));

  const balances: Record<string, number> = {
    checking: Math.round(income * 0.35),
    savings: SAVINGS_OPENING_CENTS[incomeRange],
  };
  const movements: Movement[] = drafts.map((d, index) => {
    balances[d.accountId] += d.amountCents;
    return { ...d, id: `seed-${String(index).padStart(3, '0')}`, balanceAfterCents: balances[d.accountId] };
  });

  // Ningún saldo negativo: si los gastos aleatorios superan, se ajusta el saldo inicial.
  const minChecking = Math.min(0, ...movements.filter((m) => m.accountId === 'checking').map((m) => m.balanceAfterCents));
  if (minChecking < 0) {
    const topUp = -minChecking + 5_000;
    for (const m of movements) if (m.accountId === 'checking') m.balanceAfterCents += topUp;
    balances.checking += topUp;
  }

  checking.balanceCents = balances.checking;
  savings.balanceCents = balances.savings;
  return { accounts: [checking, savings], movements };
}

function fourDigits(rand: () => number): string {
  return String(Math.floor(rand() * 10_000)).padStart(4, '0');
}

/** Hash FNV-1a de 32 bits (determinista, no criptográfico). */
export function fnv1a(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** PRNG pequeño y determinista. */
export function mulberry32(seed: number): () => number {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
