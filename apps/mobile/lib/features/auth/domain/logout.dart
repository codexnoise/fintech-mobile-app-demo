import 'package:nexo_core/nexo_core.dart';

import 'auth_repository.dart';
import 'biometrics.dart';

/// Cierra sesión sin dejar datos del usuario en el dispositivo: limpiezas de
/// cada feature, flags biométricos y por último la sesión de Firebase (que
/// dispara la navegación a login).
class LogoutUseCase {
  LogoutUseCase(
    this._auth,
    this._biometricPrefs,
    this._cleanups, {
    void Function(Object error)? onCleanupError,
  }) : _onCleanupError = onCleanupError ?? _ignore;

  static void _ignore(Object _) {}

  final AuthRepository _auth;
  final BiometricPreferences _biometricPrefs;
  final SessionCleanupRegistry _cleanups;
  final void Function(Object error) _onCleanupError;

  Future<void> call() async {
    final errors = await _cleanups.runAll();
    errors.forEach(_onCleanupError);
    try {
      await _biometricPrefs.clear();
    } on Object catch (e) {
      _onCleanupError(e);
    }
    await _auth.signOut();
  }
}
