import 'dart:convert';
import 'dart:math';

/// Micro-app de un aliado, abierta en un WebView endurecido.
final class MicroApp {
  const MicroApp({
    required this.id,
    required this.title,
    required this.url,
    required this.allowedHost,
  });

  final String id;
  final String title;
  final Uri url;

  /// Único host al que el WebView puede navegar.
  final String allowedHost;
}

/// Registry cerrado: solo se abren micro-apps declaradas aquí.
final microApps = <String, MicroApp>{
  'travel_insurance': MicroApp(
    id: 'travel_insurance',
    title: 'Viaja Seguro',
    url: Uri.parse('https://nexo-fintech-demo.web.app/'),
    allowedHost: 'nexo-fintech-demo.web.app',
  ),
};

/// Solo https al host del aliado. Bloquea otros hosts y esquemas
/// (`file:`, `intent:`, `javascript:`, `data:`…).
bool isNavigationAllowed(MicroApp app, Uri uri) =>
    uri.scheme == 'https' && uri.host == app.allowedHost;

// --- Bridge v1 (contrato en micro_apps/travel_insurance/README.md) -----------

sealed class BridgeMessage {
  const BridgeMessage();
}

final class BridgeReady extends BridgeMessage {
  const BridgeReady();
}

final class BridgeQuoteAccepted extends BridgeMessage {
  const BridgeQuoteAccepted({
    required this.plan,
    required this.destination,
    required this.priceCents,
  });

  final String plan;
  final String destination;

  /// Calculado por el aliado: solo informativo, Nexo no cobra este monto.
  final int priceCents;
}

final class BridgeClose extends BridgeMessage {
  const BridgeClose();
}

final class BridgeError extends BridgeMessage {
  const BridgeError(this.code);

  final String code;
}

const _maxMessageBytes = 8 * 1024;

/// Parser estricto. Devuelve `null` (se descarta) si el mensaje no cumple el
/// contrato: JSON inválido, `v != 1`, tipo fuera del allowlist o nonce
/// distinto. `ready` es el único sin nonce: la micro-app aún no lo recibió.
BridgeMessage? parseBridgeMessage(String raw, {String? expectedNonce}) {
  if (raw.length > _maxMessageBytes) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['v'] != 1) return null;

  final type = decoded['type'];
  if (type == 'ready') return const BridgeReady();

  final nonce = decoded['nonce'];
  if (expectedNonce == null || nonce is! String || nonce != expectedNonce) {
    return null;
  }
  final payload = decoded['payload'];
  switch (type) {
    case 'quote_accepted':
      if (payload is! Map) return null;
      final price = payload['priceCents'];
      return BridgeQuoteAccepted(
        plan: payload['plan'] is String ? payload['plan'] as String : 'basic',
        destination: payload['destination'] is String
            ? payload['destination'] as String
            : '',
        priceCents: price is int && price >= 0 ? price : 0,
      );
    case 'close':
      return const BridgeClose();
    case 'error':
      final code = payload is Map ? payload['code'] : null;
      return BridgeError(code is String ? code : 'unknown');
    default:
      return null;
  }
}

/// 16 bytes aleatorios criptográficamente seguros, base64url.
String newNonce() {
  final random = Random.secure();
  return base64Url.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
}

/// Script que entrega el contexto. El contenido va siempre por `jsonEncode`.
String contextScript({
  required String nonce,
  required String token,
  required String apiBase,
}) {
  final message = jsonEncode({
    'v': 1,
    'type': 'context',
    'nonce': nonce,
    'token': token,
    'apiBase': apiBase,
  });
  return 'window.nexo.receive($message);';
}
