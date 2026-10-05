/// Eventos de producto sin PII (Firebase Analytics en la app).
abstract interface class AnalyticsTracker {
  void track(String event, [Map<String, Object> params = const {}]);

  void setUserProperty(String name, String? value);
}

/// Por defecto en tests y en código que no necesita medir.
final class NoopAnalytics implements AnalyticsTracker {
  const NoopAnalytics();

  @override
  void track(String event, [Map<String, Object> params = const {}]) {}

  @override
  void setUserProperty(String name, String? value) {}
}

/// Catálogo de eventos: un nombre por hecho de negocio, nunca montos ni datos
/// personales en los parámetros.
abstract final class AnalyticsEvents {
  static const transferCompleted = 'transfer_completed';
  static const sduiFallbackUsed = 'sdui_fallback_used';
  static const microAppQuoteAccepted = 'micro_app_quote_accepted';
}
