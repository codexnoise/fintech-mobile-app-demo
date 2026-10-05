import '../money.dart';
import '../result.dart';

enum AccountType { checking, savings, unknown }

/// Cuenta propia del usuario. Contrato compartido: accounts la muestra y
/// transfers la usa como origen/destino sin importarse entre sí.
final class Account {
  const Account({
    required this.id,
    required this.type,
    required this.alias,
    required this.maskedNumber,
    required this.balance,
    required this.updatedAt,
  });

  final String id;
  final AccountType type;
  final String alias;

  /// Ya enmascarado por el backend (ej. "•••• 4821").
  final String maskedNumber;
  final Money balance;
  final DateTime? updatedAt;
}

/// Dato con su procedencia: si vino de la caché local (sin conexión o aún
/// sin confirmar con el servidor) la UI lo marca como desactualizado.
final class Live<T> {
  const Live(this.data, {required this.isFromCache});

  final T data;
  final bool isFromCache;
}

/// Lectura en tiempo real de las cuentas del usuario con sesión.
abstract interface class AccountsSource {
  Stream<Result<Live<List<Account>>>> watchAccounts();
}

/// Uid del usuario con sesión, sin acoplar a Firebase Auth.
abstract interface class CurrentUserProvider {
  String? get uid;
}
