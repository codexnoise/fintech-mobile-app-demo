/// Reporte de errores no fatales (Crashlytics en la app) sin acoplar a Firebase.
abstract interface class ErrorReporter {
  /// [requestId] es el `X-Request-Id` del BFF: permite cruzar el error de la
  /// app con el log del backend.
  void report(
    Object error,
    StackTrace? stack, {
    String? reason,
    String? requestId,
  });
}

/// Fallback para tests y entornos sin Crashlytics.
final class PrintErrorReporter implements ErrorReporter {
  const PrintErrorReporter();

  @override
  void report(
    Object error,
    StackTrace? stack, {
    String? reason,
    String? requestId,
  }) {
    // ignore: avoid_print
    print('[no fatal] ${reason ?? ''} ${requestId ?? ''} $error');
  }
}
