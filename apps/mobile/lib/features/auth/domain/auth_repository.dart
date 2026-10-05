import 'package:nexo_core/nexo_core.dart';

/// Usuario autenticado (solo lo que la app necesita; sin datos de perfil).
final class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

/// Códigos de [ValidationFailure] que devuelve [AuthRepository]. La capa de
/// presentación los traduce a mensajes; nunca se muestran códigos de Firebase.
abstract final class AuthErrorCodes {
  static const invalidCredentials = 'auth.invalid_credentials';
  static const emailInUse = 'auth.email_in_use';
  static const invalidEmail = 'auth.invalid_email';
  static const weakPassword = 'auth.weak_password';
  static const tooManyRequests = 'auth.too_many_requests';
  static const userDisabled = 'auth.user_disabled';
  static const noSession = 'auth.no_session';
}

abstract interface class AuthRepository {
  /// Emite el usuario actual al suscribirse y luego cada cambio de sesión.
  Stream<AuthUser?> userChanges();

  AuthUser? get currentUser;

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> register({
    required String email,
    required String password,
  });

  Future<Result<void>> sendPasswordReset(String email);

  /// Confirma la identidad del usuario con sesión vigente (pantalla de bloqueo
  /// sin biometría).
  Future<Result<void>> reauthenticate(String password);

  Future<void> signOut();
}
