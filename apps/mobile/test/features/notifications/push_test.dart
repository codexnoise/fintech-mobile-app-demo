import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/notifications/domain/push.dart';
import 'package:nexo_mobile/features/notifications/presentation/push_coordinator.dart';

class _FakeMessaging implements PushMessaging {
  String? currentToken = 'tok-1';
  final refreshes = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<Map<String, Object?>>.broadcast();
  Map<String, Object?>? initial;
  int deletes = 0;

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushMessage> get foregroundMessages => foreground.stream;

  @override
  Stream<Map<String, Object?>> get openedMessages => opened.stream;

  @override
  Future<Map<String, Object?>?> initialMessageData() async => initial;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<PushPermission> permission() async => PushPermission.notDetermined;

  @override
  Future<void> deleteToken() async => deletes++;
}

class _FakeLocal implements LocalNotifier {
  final shown = <(PushMessage, PushChannel, String?)>[];
  final taps = StreamController<String?>.broadcast();
  Map<String, Object?>? launchPayload;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show(
    PushMessage message, {
    required PushChannel channel,
    String? payloadRoute,
  }) async => shown.add((message, channel, payloadRoute));

  @override
  Stream<String?> get taps$ => taps.stream;

  @override
  Future<String?> launchRoute() async => launchPayload?['route'] as String?;
}

class _FakeDevices implements DevicesRepository {
  final registered = <DeviceRegistration>[];

  @override
  Future<Result<List<String>>> register(DeviceRegistration device) async {
    registered.add(device);
    return const Result.ok(['segment_premium']);
  }
}

class _FakeDeviceId implements DeviceIdStore {
  @override
  Future<String> deviceId() async => 'device-abc';
}

void main() {
  group('routeFromPushData (allowlist)', () {
    test('rutas internas permitidas', () {
      expect(routeFromPushData({'route': '/home'}), '/home');
      expect(
        routeFromPushData({'route': '/accounts/savings'}),
        '/accounts/savings',
      );
      expect(routeFromPushData({'route': '/transfers/new'}), '/transfers/new');
    });

    test('rechaza rutas externas, desconocidas o malformadas', () {
      expect(routeFromPushData({'route': 'https://evil.com'}), isNull);
      expect(routeFromPushData({'route': '//evil.com'}), isNull);
      expect(routeFromPushData({'route': '/admin'}), isNull);
      expect(routeFromPushData({'route': '/accounts/../admin'}), isNull);
      expect(routeFromPushData({'route': '/lock'}), isNull);
      expect(routeFromPushData({}), isNull);
      expect(routeFromPushData({'route': 42}), isNull);
    });

    test('canal según el tipo', () {
      expect(
        channelFor({'type': 'transfer_completed'}),
        PushChannel.transactions,
      );
      expect(channelFor({'type': 'campaign'}), PushChannel.campaigns);
      expect(channelFor({}), PushChannel.campaigns);
    });
  });

  group('PushCoordinator', () {
    late _FakeMessaging messaging;
    late _FakeLocal local;
    late _FakeDevices devices;
    late PushCoordinator coordinator;
    late List<String> routes;

    setUp(() async {
      messaging = _FakeMessaging();
      local = _FakeLocal();
      devices = _FakeDevices();
      coordinator = PushCoordinator(
        messaging: messaging,
        local: local,
        devices: devices,
        deviceIds: _FakeDeviceId(),
        platform: 'android',
        appVersion: '1.0.0',
      );
      routes = [];
      coordinator.routes.listen(routes.add);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('en primer plano muestra notificación local con su canal', () async {
      await coordinator.start();
      messaging.foreground.add(
        const PushMessage(
          title: 'Transferencia exitosa',
          body: r'Moviste $25.00',
          data: {'type': 'transfer_completed', 'route': '/accounts/savings'},
        ),
      );
      await settle();

      final (message, channel, route) = local.shown.single;
      expect(message.title, 'Transferencia exitosa');
      expect(channel, PushChannel.transactions);
      expect(route, '/accounts/savings');
    });

    test('tap en notificación (background) navega a la ruta', () async {
      await coordinator.start();
      messaging.opened.add({'route': '/accounts/checking'});
      await settle();

      expect(routes, ['/accounts/checking']);
    });

    test('tap en notificación local (foreground) navega', () async {
      await coordinator.start();
      local.taps.add('/accounts/savings');
      await settle();

      expect(routes, ['/accounts/savings']);
    });

    test(
      'app cerrada: la notificación que la abrió navega al iniciar',
      () async {
        messaging.initial = {'route': '/accounts/savings'};
        await coordinator.start();
        await settle();

        expect(routes, ['/accounts/savings']);
      },
    );

    test('ruta no permitida: abre la app sin navegar', () async {
      await coordinator.start();
      messaging.opened.add({'route': 'https://evil.com'});
      local.taps.add('/admin');
      await settle();

      expect(routes, isEmpty);
    });

    test('con sesión lista registra el dispositivo una vez', () async {
      await coordinator.start();
      await coordinator.onSessionReady();
      await coordinator.onSessionReady();

      final device = devices.registered.single;
      expect(device.deviceId, 'device-abc');
      expect(device.fcmToken, 'tok-1');
      expect(device.platform, 'android');
      expect(device.appVersion, '1.0.0');
    });

    test('si el token rota, lo vuelve a registrar', () async {
      await coordinator.start();
      await coordinator.onSessionReady();
      messaging.refreshes.add('tok-2');
      await settle();

      expect(devices.registered.map((d) => d.fcmToken), ['tok-1', 'tok-2']);
    });

    test(
      'logout borra el token y permite registrar al siguiente usuario',
      () async {
        await coordinator.start();
        await coordinator.onSessionReady();

        await coordinator.onLogout();
        await coordinator.onSessionReady();

        expect(messaging.deletes, 1);
        expect(devices.registered, hasLength(2));
      },
    );
  });
}
