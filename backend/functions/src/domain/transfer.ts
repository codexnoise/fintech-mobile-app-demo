import type { Account, Movement } from './types';

export const TRANSFER_LIMITS = {
  minCents: 1,
  maxPerTransferCents: 500_000, // USD 5.000
  dailyMaxCents: 1_000_000, // USD 10.000
} as const;

export type TransferRejectionCode =
  | 'same_account'
  | 'invalid_amount'
  | 'exceeds_per_transfer_limit'
  | 'exceeds_daily_limit'
  | 'insufficient_funds'
  | 'account_not_found';

export interface TransferCommand {
  uid: string;
  transferId: string;
  fromAccountId: string;
  toAccountId: string;
  amountCents: number;
  note?: string;
  idempotencyKey: string;
  now: Date;
}

export interface TransferState {
  from: Account | null;
  to: Account | null;
  /** Monto ya transferido hoy (UTC) por el usuario. */
  dailyUsedCents: number;
  /** Fecha (YYYY-MM-DD) a la que corresponde dailyUsedCents. */
  dailyDate: string | null;
}

export interface TransferPlan {
  debit: Movement;
  credit: Movement;
  fromBalanceCents: number;
  toBalanceCents: number;
  dailyDate: string;
  dailyUsedCents: number;
}

export type TransferDecision = { ok: true; plan: TransferPlan } | { ok: false; code: TransferRejectionCode };

export interface TransferResult {
  transferId: string;
  status: 'completed';
  fromAccountId: string;
  toAccountId: string;
  amountCents: number;
  debitMovementId: string;
  creditMovementId: string;
  fromBalanceCents: number;
  toBalanceCents: number;
  createdAt: string;
  /** true si la respuesta proviene de un reintento con la misma idempotency key. */
  replayed: boolean;
}

export const utcDay = (d: Date) => d.toISOString().slice(0, 10);

/**
 * Lógica pura de una transferencia entre cuentas propias.
 * Se ejecuta DENTRO de la transacción de base de datos, con el estado leído
 * en esa misma transacción (sin condiciones de carrera).
 */
export function evaluateTransfer(cmd: TransferCommand, state: TransferState): TransferDecision {
  if (!Number.isSafeInteger(cmd.amountCents) || cmd.amountCents < TRANSFER_LIMITS.minCents) {
    return { ok: false, code: 'invalid_amount' };
  }
  if (cmd.fromAccountId === cmd.toAccountId) return { ok: false, code: 'same_account' };
  if (!state.from || !state.to) return { ok: false, code: 'account_not_found' };
  if (cmd.amountCents > TRANSFER_LIMITS.maxPerTransferCents) {
    return { ok: false, code: 'exceeds_per_transfer_limit' };
  }
  const today = utcDay(cmd.now);
  const usedToday = state.dailyDate === today ? state.dailyUsedCents : 0;
  if (usedToday + cmd.amountCents > TRANSFER_LIMITS.dailyMaxCents) {
    return { ok: false, code: 'exceeds_daily_limit' };
  }
  if (state.from.balanceCents < cmd.amountCents) return { ok: false, code: 'insufficient_funds' };

  const createdAt = cmd.now.toISOString();
  const fromBalanceCents = state.from.balanceCents - cmd.amountCents;
  const toBalanceCents = state.to.balanceCents + cmd.amountCents;
  const description = cmd.note?.trim() || 'Transferencia entre cuentas propias';

  return {
    ok: true,
    plan: {
      debit: {
        id: `${cmd.transferId}-debit`,
        accountId: state.from.id,
        amountCents: -cmd.amountCents,
        description,
        category: 'transfer',
        createdAt,
        balanceAfterCents: fromBalanceCents,
        transferId: cmd.transferId,
      },
      credit: {
        id: `${cmd.transferId}-credit`,
        accountId: state.to.id,
        amountCents: cmd.amountCents,
        description,
        category: 'transfer',
        createdAt,
        balanceAfterCents: toBalanceCents,
        transferId: cmd.transferId,
      },
      fromBalanceCents,
      toBalanceCents,
      dailyDate: today,
      dailyUsedCents: usedToday + cmd.amountCents,
    },
  };
}

export function toResult(cmd: TransferCommand, plan: TransferPlan): TransferResult {
  return {
    transferId: cmd.transferId,
    status: 'completed',
    fromAccountId: cmd.fromAccountId,
    toAccountId: cmd.toAccountId,
    amountCents: cmd.amountCents,
    debitMovementId: plan.debit.id,
    creditMovementId: plan.credit.id,
    fromBalanceCents: plan.fromBalanceCents,
    toBalanceCents: plan.toBalanceCents,
    createdAt: plan.debit.createdAt,
    replayed: false,
  };
}

/** Huella del payload: reusar una key con otro payload es un error del cliente. */
export function requestFingerprint(cmd: Pick<TransferCommand, 'fromAccountId' | 'toAccountId' | 'amountCents' | 'note'>): string {
  return [cmd.fromAccountId, cmd.toAccountId, cmd.amountCents, cmd.note ?? ''].join('|');
}
