/// Entorno de ejecución. Se inyecta con
/// `--dart-define-from-file=env/<entorno>.json` (ver `env/*.example.json`).
enum AppFlavor { dev, prod }

final class AppEnv {
  const AppEnv({
    required this.flavor,
    required this.apiBaseUrl,
    required this.useEmulators,
  });

  /// Lee los valores definidos en compilación. [fallback] es el flavor del
  /// entrypoint (`main_dev.dart` / `main_prod.dart`) si `APP_ENV` no viene.
  factory AppEnv.fromEnvironment({required AppFlavor fallback}) {
    const rawEnv = String.fromEnvironment('APP_ENV');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const useEmulators = bool.fromEnvironment('USE_EMULATORS');

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
    );
  }

  final AppFlavor flavor;
  final String apiBaseUrl;
  final bool useEmulators;

  bool get isDev => flavor == AppFlavor.dev;
}
