import type { TransferRejectionCode } from './domain/transfer';

/** Error con semántica HTTP. Los mensajes son seguros para mostrar (sin internals). */
export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: unknown,
    readonly retryAfterSeconds?: number,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class TransferRejectedError extends AppError {
  constructor(readonly reason: TransferRejectionCode) {
    super(reason === 'account_not_found' ? 404 : 422, reason, TRANSFER_MESSAGES[reason]);
  }
}

export class IdempotencyConflictError extends AppError {
  constructor() {
    super(422, 'idempotency_key_reused', 'La clave de idempotencia ya se usó con otros datos.');
  }
}

const TRANSFER_MESSAGES: Record<TransferRejectionCode, string> = {
  same_account: 'La cuenta de origen y destino deben ser distintas.',
  invalid_amount: 'El monto debe ser mayor a cero.',
  exceeds_per_transfer_limit: 'El monto supera el límite por transferencia.',
  exceeds_daily_limit: 'Superaste tu límite diario de transferencias.',
  insufficient_funds: 'Saldo insuficiente en la cuenta de origen.',
  account_not_found: 'No encontramos una de las cuentas.',
};
