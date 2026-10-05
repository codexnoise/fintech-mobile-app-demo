/// Rutas de la app: contrato compartido para que las features naveguen sin
/// importarse entre sí ni depender del router de la app.
abstract final class NexoRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const biometricSetup = '/biometric-setup';
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
