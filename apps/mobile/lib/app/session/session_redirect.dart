import 'package:nexo_core/nexo_core.dart';

import 'session_status.dart';

/// Pantallas de entrada: nunca son destino válido para una sesión lista.
const _gateRoutes = {
  NexoRoutes.splash,
  NexoRoutes.login,
  NexoRoutes.register,
  NexoRoutes.onboarding,
  NexoRoutes.biometricSetup,
  NexoRoutes.lock,
};

const _fromParam = 'from';

/// Guard de navegación: devuelve a dónde redirigir, o `null` para permitir
/// [location]. Función pura para testearla con tablas.
String? sessionRedirect(SessionStatus status, Uri location) {
  final path = location.path;
  // Herramientas de desarrollo: la ruta solo existe en dev.
  if (path.startsWith('/dev/')) return null;

  String? only(String route) => path == route ? null : route;

  return switch (status) {
    SessionLoading() || SessionProfileUnavailable() => only(NexoRoutes.splash),
    SessionUnauthenticated() =>
      path == NexoRoutes.login || path == NexoRoutes.register
          ? null
          : NexoRoutes.login,
    SessionNeedsOnboarding() => only(NexoRoutes.onboarding),
    SessionNeedsBiometricSetup() => only(NexoRoutes.biometricSetup),
    SessionLocked() => _toLock(location),
    SessionReady() =>
      _gateRoutes.contains(path)
          ? _safeFrom(location) ?? NexoRoutes.home
          : null,
  };
}

/// Recuerda el destino (ej. deep link de una push) para volver tras
/// desbloquear.
String? _toLock(Uri location) {
  if (location.path == NexoRoutes.lock) return null;
  if (_gateRoutes.contains(location.path)) return NexoRoutes.lock;
  return Uri(
    path: NexoRoutes.lock,
    queryParameters: {_fromParam: location.toString()},
  ).toString();
}

/// Solo rutas internas: evita redirecciones abiertas vía `from`.
String? _safeFrom(Uri location) {
  if (location.path != NexoRoutes.lock) return null;
  final from = location.queryParameters[_fromParam];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final target = Uri.tryParse(from);
  if (target == null || target.hasScheme || _gateRoutes.contains(target.path)) {
    return null;
  }
  return from;
}
