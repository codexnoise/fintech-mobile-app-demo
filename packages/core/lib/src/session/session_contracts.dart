/// Avisos de las features hacia la sesión de la app (que vive en el shell).
/// Permite, por ejemplo, que onboarding informe que el perfil cambió sin
/// conocer el router ni la máquina de estados de sesión.
abstract interface class SessionSignals {
  /// El perfil del usuario cambió (ej. completó el onboarding).
  Future<void> profileChanged();

  /// El usuario desbloqueó la app (biometría o contraseña).
  Future<void> unlocked();

  /// El usuario aceptó o rechazó activar la biometría.
  Future<void> biometricSetupFinished();
}

/// Limpiezas que se ejecutan al cerrar sesión (cache SDUI, Firestore, etc.).
/// Cada feature registra la suya; el logout no necesita conocerlas.
final class SessionCleanupRegistry {
  final List<Future<void> Function()> _cleanups = [];

  void register(Future<void> Function() cleanup) => _cleanups.add(cleanup);

  /// Ejecuta todas las limpiezas. Un fallo no impide las demás; los errores
  /// se devuelven para que el llamador los reporte.
  Future<List<Object>> runAll() async {
    final errors = <Object>[];
    for (final cleanup in _cleanups) {
      try {
        await cleanup();
      } on Object catch (e) {
        errors.add(e);
      }
    }
    return errors;
  }
}
