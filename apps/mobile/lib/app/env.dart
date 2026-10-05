/// Entorno de ejecución. Se inyecta con
/// `--dart-define-from-file=env/<entorno>.json` (ver `env/*.example.json`).
enum AppFlavor { dev, prod }

final class AppEnv {
  const AppEnv({
    required this.flavor,
    required this.apiBaseUrl,
    required this.useEmulators,
    this.appCheckDebugToken,
    this.appVersion = defaultAppVersion,
  });

  /// Debe coincidir con `version` de pubspec.yaml (se puede sobrescribir con
  /// `--dart-define=APP_VERSION=…`).
  static const defaultAppVersion = '1.0.0';

  /// Lee los valores definidos en compilación. [fallback] es el flavor del
  /// entrypoint (`main_dev.dart` / `main_prod.dart`) si `APP_ENV` no viene.
  factory AppEnv.fromEnvironment({required AppFlavor fallback}) {
    const rawEnv = String.fromEnvironment('APP_ENV');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const useEmulators = bool.fromEnvironment('USE_EMULATORS');
    const appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
    const appVersion = String.fromEnvironment(
      'APP_VERSION',
      defaultValue: defaultAppVersion,
    );

    final flavor = switch (rawEnv) {
      'dev' => AppFlavor.dev,
      'prod' => AppFlavor.prod,
      _ => fallback,
    };
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL no definido. Ejecuta con '
        '--dart-define-from-file=env/${flavor.name}.json',
      );
    }
    return AppEnv(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      // Nunca emuladores en prod, aunque el archivo lo pida.
      useEmulators: flavor == AppFlavor.dev && useEmulators,
      appCheckDebugToken:
          flavor == AppFlavor.dev && appCheckDebugToken.isNotEmpty
          ? appCheckDebugToken
          : null,
      appVersion: appVersion,
    );
  }

  final AppFlavor flavor;
  final String apiBaseUrl;
  final bool useEmulators;

  /// Debug token de App Check registrado en la consola (solo dev). Si es
  /// `null`, el SDK genera uno y lo imprime en el log al arrancar.
  final String? appCheckDebugToken;
  final String appVersion;

  bool get isDev => flavor == AppFlavor.dev;
}
