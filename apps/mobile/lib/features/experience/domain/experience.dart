import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

/// De dónde salió la pantalla. Se muestra con un indicador sutil y se mide.
enum ExperienceSource {
  /// Recién servida por el BFF.
  remote,

  /// Última versión buena guardada en el dispositivo (sin conexión, BFF caído).
  cache,

  /// JSON embebido en la app: siempre hay algo que mostrar.
  bundled,
}

final class Experience {
  const Experience({
    required this.document,
    required this.source,
    required this.loadedAt,
    this.warnings = const [],
    this.remoteFailure,
  });

  final SduiDocument document;
  final ExperienceSource source;
  final DateTime loadedAt;

  /// Componentes descartados por el parser (observabilidad).
  final List<String> warnings;

  /// Por qué no se usó el remoto (si aplica).
  final Failure? remoteFailure;
}

/// Almacén del último documento bueno por pantalla y segmento.
abstract interface class ExperienceCache {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> clear();
}

abstract interface class ExperienceRepository {
  /// Nunca devuelve error mientras exista el JSON embebido.
  Future<Result<Experience>> load({
    required String screen,
    required String segment,
  });
}
