import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';

import 'env.dart';
import 'placeholder_page.dart';
import 'session/session_cubit.dart';
import 'session/session_redirect.dart';
import 'splash_page.dart';

/// Construye el router. Los guards dependen de [session]; las pantallas
/// reales reemplazan a los placeholders bloque a bloque (F2–F11).
GoRouter buildRouter({
  required AppEnv env,
  required SessionCubit session,
  String initialLocation = NexoRoutes.splash,
}) {
  GoRoute page(String path, String title) => GoRoute(
    path: path,
    builder: (_, state) => PlaceholderPage(title: title, location: state.uri),
  );

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: env.isDev,
    refreshListenable: _StreamListenable(session.stream),
    redirect: (_, state) => sessionRedirect(session.state, state.uri),
    routes: [
      GoRoute(path: NexoRoutes.splash, builder: (_, _) => const SplashPage()),
      page(NexoRoutes.login, 'Iniciar sesión'),
      page(NexoRoutes.register, 'Crear cuenta'),
      page(NexoRoutes.onboarding, 'Onboarding'),
      page(NexoRoutes.biometricSetup, 'Biometría'),
      page(NexoRoutes.lock, 'App bloqueada'),
      page(NexoRoutes.home, 'Inicio'),
      page(NexoRoutes.accountPattern, 'Detalle de cuenta'),
      page(NexoRoutes.transferNew, 'Nueva transferencia'),
      page(NexoRoutes.microAppPattern, 'Micro-app'),
      page(NexoRoutes.assistant, 'Asistente'),
      // Herramienta de demo: no existe en builds de producción.
      if (env.isDev) page(NexoRoutes.networkLab, 'Network Lab'),
    ],
    errorBuilder: (_, state) =>
        PlaceholderPage(title: 'Página no encontrada', location: state.uri),
  );
}

/// Re-evalúa los redirects cada vez que cambia la sesión.
final class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
