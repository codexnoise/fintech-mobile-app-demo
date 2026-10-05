import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:uuid/uuid.dart';

import '../domain/push.dart';

final class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._fcm);

  final FirebaseMessaging _fcm;

  static PushMessage _toMessage(RemoteMessage m) => PushMessage(
    title: m.notification?.title,
    body: m.notification?.body,
    data: m.data,
  );

  @override
  Future<String?> token() => _fcm.getToken();

  @override
  Stream<String> get tokenRefreshes => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<Map<String, Object?>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, Object?>?> initialMessageData() async =>
      (await _fcm.getInitialMessage())?.data;

  @override
  Future<PushPermission> permission() async =>
      _map((await _fcm.getNotificationSettings()).authorizationStatus);

  @override
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return _map(settings.authorizationStatus) == PushPermission.granted;
  }

  @override
  Future<void> deleteToken() => _fcm.deleteToken();

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };
}

final class LocalNotificationsNotifier implements LocalNotifier {
  LocalNotificationsNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String?>.broadcast();
  var _nextId = 0;

  @override
  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => _taps.add(r.payload),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in PushChannel.values) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: channel == PushChannel.transactions
              ? Importance.high
              : Importance.defaultImportance,
        ),
      );
    }
  }

  @override
  Future<void> show(
    PushMessage message, {
    required PushChannel channel,
    String? payloadRoute,
  }) => _plugin.show(
    id: _nextId++,
    title: message.title,
    body: message.body,
    payload: payloadRoute,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel == PushChannel.transactions
            ? Importance.high
            : Importance.defaultImportance,
        priority: channel == PushChannel.transactions
            ? Priority.high
            : Priority.defaultPriority,
      ),
    ),
  );

  @override
  Stream<String?> get taps$ => _taps.stream;

  @override
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }
}

final class ApiDevicesRepository implements DevicesRepository {
  const ApiDevicesRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<String>>> register(DeviceRegistration device) => _api.post(
    '/devices',
    // Upsert por deviceId en el BFF: seguro de reintentar.
    idempotent: true,
    body: {
      'deviceId': device.deviceId,
      'fcmToken': device.fcmToken,
      'platform': device.platform,
      'appVersion': device.appVersion,
    },
    decode: (json) => [
      for (final t in (json! as Map)['topics'] as List) t as String,
    ],
  );
}

final class SecureDeviceIdStore implements DeviceIdStore {
  SecureDeviceIdStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'device.id';

  @override
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _key);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _key, value: id);
    return id;
  }
}
