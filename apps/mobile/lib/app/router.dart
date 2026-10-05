import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';

import '../features/auth/presentation/login_cubit.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_cubit.dart';
import '../features/auth/presentation/register_page.dart';
import 'env.dart';
import 'placeholder_page.dart';
import 'session/session_cubit.dart';
import 'session/session_redirect.dart';
import 'splash_page.dart';

/// Construye el router. Los guards dependen de [session]; [di] resuelve las
/// dependencias de cada pantalla. Los placeholders se reemplazan bloque a
/// bloque (F2–F11).
GoRouter buildRouter({
  required AppEnv env,
  required SessionCubit session,
  required GetIt di,
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
      GoRoute(
        path: NexoRoutes.login,
        builder: (_, _) => BlocProvider(
          create: (_) => LoginCubit(di()),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: NexoRoutes.register,
        builder: (_, _) => BlocProvider(
          create: (_) => RegisterCubit(di()),
          child: const RegisterPage(),
        ),
      ),
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
