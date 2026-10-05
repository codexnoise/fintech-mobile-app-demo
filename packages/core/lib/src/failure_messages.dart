import 'result.dart';

/// Mensaje genérico y seguro para mostrar al usuario. Las features pueden
/// especializarlo por código; este es el fallback común.
extension FailureMessage on Failure {
  String get userMessage => switch (this) {
    NetworkFailure() => 'Sin conexión. Revisa tu internet e intenta de nuevo.',
    TimeoutFailure() =>
      'El servicio está tardando más de lo normal. '
          'Intenta de nuevo.',
    UnauthorizedFailure() => 'Tu sesión expiró. Ingresa nuevamente.',
    // El BFF garantiza que `message` es apto para el usuario (docs/api.md).
    ValidationFailure(:final message?) => message,
    ValidationFailure() => 'Revisa los datos ingresados.',
    ServiceUnavailableFailure(:final message?) => message,
    ServiceUnavailableFailure() =>
      'Este servicio está en mantenimiento. Intenta en unos minutos.',
    ServerFailure() ||
    UnknownFailure() => 'Algo salió mal. Intenta de nuevo en unos minutos.',
  };
}
