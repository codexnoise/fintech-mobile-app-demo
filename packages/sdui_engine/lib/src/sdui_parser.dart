import 'sdui_models.dart';

/// Parser defensivo del contrato SDUI.
///
/// Reglas:
/// - Si el documento no cumple el contrato mínimo -> [SduiFormatException]
///   (la capa superior cae a last-known-good / default embebido).
/// - Si UN componente es inválido -> se omite ese componente, no la pantalla.
/// - Tipos desconocidos se ignoran (forward compatibility).
/// - Componentes con `minAppVersion` mayor a la versión instalada se omiten.
/// - Acciones fuera del allowlist se descartan.
class SduiParser {
  const SduiParser({
    required this.supportedTypes,
    required this.allowedRoutes,
    required this.allowedMicroApps,
    this.supportedSchemaVersion = 1,
  });

  final Set<String> supportedTypes;
  final Set<String> allowedRoutes;
  final Set<String> allowedMicroApps;
  final int supportedSchemaVersion;

  SduiParseResult parse(Object? json, {required String appVersion}) {
    if (json is! Map<String, Object?>) {
      throw const SduiFormatException('root must be an object');
    }
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > supportedSchemaVersion) {
      throw SduiFormatException('unsupported schemaVersion: $schemaVersion');
    }
    final screen = json['screen'];
    final rawComponents = json['components'];
    if (screen is! String || rawComponents is! List<Object?>) {
      throw const SduiFormatException('screen and components are required');
    }
    final ttlSeconds = json['ttlSeconds'];
    final warnings = <String>[];
    final components = <SduiComponent>[];
    final seenIds = <String>{};

    for (final raw in rawComponents) {
      final component = _parseComponent(raw, appVersion, warnings);
      if (component == null) continue;
      if (!seenIds.add(component.id)) {
        warnings.add('duplicated id "${component.id}" skipped');
        continue;
      }
      components.add(component);
    }

    return SduiParseResult(
      document: SduiDocument(
        schemaVersion: schemaVersion,
        screen: screen,
        segment: json['segment'] is String ? json['segment']! as String : 'default',
        ttl: Duration(seconds: ttlSeconds is int && ttlSeconds > 0 ? ttlSeconds : 300),
        components: List.unmodifiable(components),
        version: json['version'] is String ? json['version']! as String : null,
      ),
      warnings: List.unmodifiable(warnings),
    );
  }

  SduiComponent? _parseComponent(
    Object? raw,
    String appVersion,
    List<String> warnings,
  ) {
    if (raw is! Map<String, Object?>) {
      warnings.add('component is not an object');
      return null;
    }
    final id = raw['id'];
    final type = raw['type'];
    if (id is! String || id.isEmpty || type is! String) {
      warnings.add('component without id/type');
      return null;
    }
    if (!supportedTypes.contains(type)) {
      warnings.add('unknown type "$type" ($id) skipped');
      return null;
    }
    final minVersion = raw['minAppVersion'];
    if (minVersion is String && compareSemver(appVersion, minVersion) < 0) {
      warnings.add('"$id" requires app $minVersion (installed $appVersion)');
      return null;
    }
    final props = raw['props'];
    if (props != null && props is! Map<String, Object?>) {
      warnings.add('"$id" props must be an object');
      return null;
    }
    return SduiComponent(
      id: id,
      type: type,
      props: props == null ? const {} : Map.unmodifiable(props as Map<String, Object?>),
      minAppVersion: minVersion is String ? minVersion : null,
    );
  }

  /// Convierte el objeto `action` de un componente en una acción permitida.
  /// Devuelve `null` si la acción no está en el allowlist.
  SduiAction? parseAction(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    switch (raw['type']) {
      case 'navigate':
        final route = raw['route'];
        return route is String && allowedRoutes.contains(route)
            ? NavigateAction(route)
            : null;
      case 'open_micro_app':
        final appId = raw['appId'];
        return appId is String && allowedMicroApps.contains(appId)
            ? OpenMicroAppAction(appId)
            : null;
      case 'open_assistant':
        final promptId = raw['promptId'];
        return OpenAssistantAction(promptId: promptId is String ? promptId : null);
      default:
        return null;
    }
  }
}

/// Compara versiones `major.minor.patch`. Segmentos faltantes = 0.
/// Sufijos no numéricos (ej. `1.0.0+3`, `1.0.0-beta`) se ignoran.
int compareSemver(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp(r'[+-]'))
      .first
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
