import 'package:go_router/go_router.dart';

import 'env.dart';
import 'placeholder_page.dart';

/// Rutas de la app. Las features se comunican navegando a estas rutas, nunca
/// importándose entre sí.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const lock = '/lock';
  static const home = '/home';
  static const accountPattern = '/accounts/:id';
  static const transferNew = '/transfers/new';
  static const microAppPattern = '/micro-apps/:appId';
  static const assistant = '/assistant';
  static const networkLab = '/dev/network-lab';

  static String account(String id) => '/accounts/${Uri.encodeComponent(id)}';
  static String microApp(String appId) =>
      '/micro-apps/${Uri.encodeComponent(appId)}';
}

/// Construye el router. Las pantallas reales reemplazan a los placeholders
/// bloque a bloque (F2–F11); los guards de sesión llegan en F2.
GoRouter buildRouter({
  required AppEnv env,
  String initialLocation = AppRoutes.splash,
}) {
  GoRoute page(String path, String title) => GoRoute(
    path: path,
    builder: (_, state) => PlaceholderPage(title: title, location: state.uri),
  );

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: env.isDev,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => SplashPlaceholder(showRouteIndex: env.isDev),
      ),
      page(AppRoutes.login, 'Iniciar sesión'),
      page(AppRoutes.register, 'Crear cuenta'),
      page(AppRoutes.onboarding, 'Onboarding'),
      page(AppRoutes.lock, 'App bloqueada'),
      page(AppRoutes.home, 'Inicio'),
      page(AppRoutes.accountPattern, 'Detalle de cuenta'),
      page(AppRoutes.transferNew, 'Nueva transferencia'),
      page(AppRoutes.microAppPattern, 'Micro-app'),
      page(AppRoutes.assistant, 'Asistente'),
      // Herramienta de demo: no existe en builds de producción.
      if (env.isDev) page(AppRoutes.networkLab, 'Network Lab'),
    ],
    errorBuilder: (_, state) =>
        PlaceholderPage(title: 'Página no encontrada', location: state.uri),
  );
}

/// Rutas navegables desde el índice de desarrollo del splash.
const devRouteIndex = <(String, String)>[
  ('Iniciar sesión', AppRoutes.login),
  ('Crear cuenta', AppRoutes.register),
  ('Onboarding', AppRoutes.onboarding),
  ('App bloqueada', AppRoutes.lock),
  ('Inicio', AppRoutes.home),
  ('Cuenta corriente', '/accounts/checking'),
  ('Nueva transferencia', AppRoutes.transferNew),
  ('Viaja Seguro', '/micro-apps/travel_insurance'),
  ('Asistente', AppRoutes.assistant),
  ('Network Lab', AppRoutes.networkLab),
];
