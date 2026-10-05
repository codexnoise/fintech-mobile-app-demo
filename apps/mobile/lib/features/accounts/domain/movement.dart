import 'package:nexo_core/nexo_core.dart';

enum MovementCategory {
  salary('salary'),
  transfer('transfer'),
  food('food'),
  transport('transport'),
  shopping('shopping'),
  services('services'),
  entertainment('entertainment'),
  health('health'),

  /// Categorías nuevas del backend que esta versión no conoce.
  other('other');

  const MovementCategory(this.wire);

  final String wire;

  static MovementCategory fromWire(String? value) =>
      values.where((c) => c.wire == value).firstOrNull ?? other;
}

final class Movement {
  const Movement({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.description,
    required this.category,
    required this.createdAt,
    required this.balanceAfter,
  });

  final String id;
  final String accountId;

  /// Firmado: negativo = débito, positivo = crédito.
  final Money amount;
  final String description;
  final MovementCategory category;
  final DateTime createdAt;
  final Money balanceAfter;
}
