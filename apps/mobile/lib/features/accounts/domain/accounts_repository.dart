import 'package:nexo_core/nexo_core.dart';

import 'movement.dart';

/// Primera página de movimientos.
const movementsPageSize = 50;

/// Las reglas de Firestore rechazan consultas con `limit > 100`.
const maxMovementsPerQuery = 100;

const accountNotFoundCode = 'account_not_found';

/// Lectura en tiempo real (solo lectura: las escrituras pasan por el BFF).
abstract interface class AccountsRepository implements AccountsSource {
  /// `ValidationFailure(accountNotFoundCode)` si la cuenta no existe.
  Stream<Result<Live<Account>>> watchAccount(String id);

  /// Movimientos más recientes primero.
  Stream<Result<Live<List<Movement>>>> watchMovements(
    String accountId, {
    required int limit,
  });
}
