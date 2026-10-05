import 'package:nexo_core/nexo_core.dart';

/// Canales Android (deben coincidir con `channelId` del backend).
enum PushChannel {
  transactions('transactions', 'Movimientos', 'Transferencias y movimientos'),
  campaigns('campaigns', 'Novedades', 'Ofertas y novedades para ti');

  const PushChannel(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;
}

enum PushPermission { granted, denied, notDetermined }

final class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, Object?> data;
}

/// FCM detrás de una interfaz (fakes en tests).
abstract interface class PushMessaging {
  Future<String?> token();

  Stream<String> get tokenRefreshes;

  /// Mensajes recibidos con la app en primer plano (el sistema no los muestra).
  Stream<PushMessage> get foregroundMessages;

  /// `data` de la notificación que el usuario tocó con la app en background.
  Stream<Map<String, Object?>> get openedMessages;

  /// `data` de la notificación que abrió la app desde cerrada.
  Future<Map<String, Object?>?> initialMessageData();

  Future<PushPermission> permission();

  Future<bool> requestPermission();

  Future<void> deleteToken();
}

/// Notificaciones locales (para mostrar las push en primer plano).
abstract interface class LocalNotifier {
  Future<void> initialize();

  Future<void> show(
    PushMessage message, {
    required PushChannel channel,
    String? payloadRoute,
  });

  /// Ruta guardada en la notificación local que el usuario tocó.
  Stream<String?> get taps$;

  /// Ruta de la notificación local que abrió la app desde cerrada.
  Future<String?> launchRoute();
}

final class DeviceRegistration {
  const DeviceRegistration({
    required this.deviceId,
    required this.fcmToken,
    required this.platform,
    required this.appVersion,
  });

  final String deviceId;
  final String fcmToken;
  final String platform;
  final String appVersion;
}

abstract interface class DevicesRepository {
  /// `POST /devices`; devuelve los topics a los que quedó suscrito.
  Future<Result<List<String>>> register(DeviceRegistration device);
}

/// Identificador estable del dispositivo (secure storage).
abstract interface class DeviceIdStore {
  Future<String> deviceId();
}

final _accountRoute = RegExp(r'^/accounts/[A-Za-z0-9_-]{1,64}$');

const _allowedRoutes = {
  NexoRoutes.home,
  NexoRoutes.accounts,
  NexoRoutes.transferNew,
  NexoRoutes.assistant,
};

/// Ruta interna a abrir al tocar una push, o `null` si no está permitida.
/// La push viene de afuera de la app: nunca se navega a rutas arbitrarias.
String? routeFromPushData(Map<String, Object?> data) {
  final route = data['route'];
  if (route is! String) return null;
  if (_allowedRoutes.contains(route) || _accountRoute.hasMatch(route)) {
    return route;
  }
  return null;
}

PushChannel channelFor(Map<String, Object?> data) =>
    data['type'] == 'transfer_completed'
    ? PushChannel.transactions
    : PushChannel.campaigns;
