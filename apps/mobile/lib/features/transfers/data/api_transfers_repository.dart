import 'package:nexo_core/nexo_core.dart';

import '../domain/transfer.dart';

final class ApiTransfersRepository implements TransfersRepository {
  const ApiTransfersRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<TransferReceipt>> submit(TransferRequest request) => _api.post(
    '/transfers',
    body: {
      'fromAccountId': request.fromAccountId,
      'toAccountId': request.toAccountId,
      'amountCents': request.amount.cents,
      'note': ?request.note,
      'idempotencyKey': request.idempotencyKey,
    },
    // Seguro de reintentar: el backend deduplica por idempotencyKey.
    idempotent: true,
    decode: parseTransferReceipt,
  );
}

TransferReceipt parseTransferReceipt(Object? json) {
  if (json is! Map) throw const FormatException('Transfer: no es objeto');
  int cents(String field) => switch (json[field]) {
    final int v => v,
    _ => throw FormatException('$field debe ser entero'),
  };
  return TransferReceipt(
    transferId: json['transferId'] as String,
    fromAccountId: json['fromAccountId'] as String,
    toAccountId: json['toAccountId'] as String,
    amount: Money(cents('amountCents')),
    fromBalance: Money(cents('fromBalanceCents')),
    toBalance: Money(cents('toBalanceCents')),
    createdAt: DateTime.parse(json['createdAt'] as String),
    replayed: json['replayed'] == true,
  );
}
