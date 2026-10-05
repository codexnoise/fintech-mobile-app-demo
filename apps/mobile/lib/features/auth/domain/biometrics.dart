enum BiometricResult {
  success,

  /// El usuario cerró el diálogo.
  cancelled,

  /// No hay hardware o no hay huellas/rostro registrados.
  unavailable,

  /// Demasiados intentos fallidos; el sistema bloqueó la biometría.
  lockedOut,

  failed,
}

/// Prompt biométrico del sistema. Detrás de una interfaz para usar un fake en
/// tests y en el E2E.
abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();

  /// Solo biometría: sin fallback al PIN del dispositivo.
  Future<BiometricResult> authenticate({required String reason});
}

/// Preferencias biométricas por usuario, en almacenamiento seguro.
abstract interface class BiometricPreferences {
  Future<bool> isEnabled(String uid);

  Future<void> setEnabled(String uid, {required bool enabled});

  /// Si ya se le ofreció activar la biometría (se ofrece una sola vez).
  Future<bool> wasOffered(String uid);

  Future<void> markOffered(String uid);

  Future<void> clear();
}
