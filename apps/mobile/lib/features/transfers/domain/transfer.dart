import 'package:nexo_core/nexo_core.dart';

/// Límites del backend (docs/api.md); el cliente los valida para dar
/// feedback inmediato, el servidor es la fuente de verdad.
const maxPerTransfer = Money(500000);
const maxNoteLength = 60;

final class TransferRequest {
  const TransferRequest({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.idempotencyKey,
    this.note,
  });

  final String fromAccountId;
  final String toAccountId;
  final Money amount;
  final String? note;

  /// Uno por intento de transferencia; se reutiliza en los reintentos para
  /// que el backend no debite dos veces.
  final String idempotencyKey;
}

final class TransferReceipt {
  const TransferReceipt({
    required this.transferId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.fromBalance,
    required this.toBalance,
    required this.createdAt,
    required this.replayed,
  });

  final String transferId;
  final String fromAccountId;
  final String toAccountId;
  final Money amount;
  final Money fromBalance;
  final Money toBalance;
  final DateTime createdAt;

  /// La respuesta corresponde a un reintento ya procesado.
  final bool replayed;
}

abstract interface class TransfersRepository {
  Future<Result<TransferReceipt>> submit(TransferRequest request);
}
