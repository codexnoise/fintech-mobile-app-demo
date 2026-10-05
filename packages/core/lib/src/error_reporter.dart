/// Reporte de errores no fatales (Crashlytics en la app) sin acoplar a Firebase.
abstract interface class ErrorReporter {
  void report(Object error, StackTrace? stack, {String? reason});
}

/// Fallback para tests y entornos sin Crashlytics.
final class PrintErrorReporter implements ErrorReporter {
  const PrintErrorReporter();

  @override
  void report(Object error, StackTrace? stack, {String? reason}) {
    // ignore: avoid_print
    print('[no fatal] ${reason ?? ''} $error');
  }
}
