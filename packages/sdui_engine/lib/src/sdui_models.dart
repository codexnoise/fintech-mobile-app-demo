/// Contrato Server-Driven UI de Nexo (schemaVersion 1).
///
/// Principio de seguridad: el servidor describe QUÉ mostrar y en QUÉ orden,
/// nunca CÓMO ejecutar. Las acciones son un conjunto cerrado y tipado; no se
/// aceptan URLs arbitrarias ni código.
library;

/// Documento SDUI para una pantalla.
final class SduiDocument {
  const SduiDocument({
    required this.schemaVersion,
    required this.screen,
    required this.segment,
    required this.ttl,
    required this.components,
    this.version,
  });

  final int schemaVersion;
  final String screen;
  final String segment;
  final Duration ttl;
  final List<SduiComponent> components;

  /// Versión de la configuración publicada (para trazabilidad y rollback).
  final String? version;
}

/// Un bloque de la pantalla. `props` ya fue validado contra el tipo
/// sólo en lo estructural; cada widget del registry valida sus campos.
final class SduiComponent {
  const SduiComponent({
    required this.id,
    required this.type,
    required this.props,
    this.minAppVersion,
  });

  final String id;
  final String type;
  final Map<String, Object?> props;
  final String? minAppVersion;
}

/// Acciones permitidas. Cualquier otra se descarta en el parser.
sealed class SduiAction {
  const SduiAction();
}

/// Navega a una ruta interna registrada en la app.
final class NavigateAction extends SduiAction {
  const NavigateAction(this.route);
  final String route;
}

/// Abre una micro-app registrada (ej. `travel_insurance`).
final class OpenMicroAppAction extends SduiAction {
  const OpenMicroAppAction(this.appId);
  final String appId;
}

/// Abre el asistente con un prompt predefinido opcional.
final class OpenAssistantAction extends SduiAction {
  const OpenAssistantAction({this.promptId});
  final String? promptId;
}

/// Resultado del parseo: el documento útil + advertencias para observabilidad.
final class SduiParseResult {
  const SduiParseResult({required this.document, required this.warnings});

  final SduiDocument document;

  /// Componentes o acciones descartados (tipo desconocido, versión, props
  /// inválidas). Se reportan a analytics/crashlytics como no fatales.
  final List<String> warnings;
}

/// El JSON no cumple el contrato mínimo: se debe usar el fallback.
final class SduiFormatException implements Exception {
  const SduiFormatException(this.message);
  final String message;

  @override
  String toString() => 'SduiFormatException: $message';
}
