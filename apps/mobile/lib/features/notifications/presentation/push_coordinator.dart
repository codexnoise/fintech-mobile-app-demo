import 'dart:async';

import 'package:nexo_core/nexo_core.dart';

import '../domain/push.dart';

/// Orquesta las push: muestra las de primer plano, traduce taps en rutas
/// (validadas) y mantiene el token registrado en el BFF.
class PushCoordinator {
  PushCoordinator({
    required this._messaging,
    required this._local,
    required this._devices,
    required this._deviceIds,
    required this._platform,
    required this._appVersion,
    ErrorReporter? errorReporter,
  }) : _errors = errorReporter;

  final PushMessaging _messaging;
  final LocalNotifier _local;
  final DevicesRepository _devices;
  final DeviceIdStore _deviceIds;
  final String _platform;
  final String _appVersion;
  final ErrorReporter? _errors;

  final _routes = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<String>? _refreshSub;
  bool _started = false;
  bool _registered = false;

  /// Rutas a abrir por un tap en una notificación.
  Stream<String> get routes => _routes.stream;

  PushPermission? _permissionCache;

  Future<PushPermission> permission() async =>
      _permissionCache ??= await _messaging.permission();

  /// Pide el permiso de notificaciones (Android 13+ / iOS). Llamar en
  /// contexto, nunca al abrir la app.
  Future<bool> requestPermission() async {
    final granted = await _messaging.requestPermission();
    _permissionCache = granted ? PushPermission.granted : PushPermission.denied;
    return granted;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _local.initialize();
    _subscriptions
      ..add(_messaging.foregroundMessages.listen(_showForeground))
      ..add(_messaging.openedMessages.listen(_open))
      ..add(_local.taps$.listen((route) => _open({'route': route})));

    final initial = await _messaging.initialMessageData();
    final localLaunch = await _local.launchRoute();
    if (initial != null) {
      _open(initial);
    } else if (localLaunch != null) {
      _open({'route': localLaunch});
    }
  }

  /// Registra el token cuando hay sesión con perfil (el BFF lo exige).
  Future<void> onSessionReady() async {
    if (_registered) return;
    _registered = true;
    final token = await _messaging.token();
    if (token != null) await _register(token);
    _refreshSub ??= _messaging.tokenRefreshes.listen(_register);
  }

  /// Logout: el dispositivo deja de recibir push del usuario anterior.
  Future<void> onLogout() async {
    _registered = false;
    await _refreshSub?.cancel();
    _refreshSub = null;
    await _messaging.deleteToken();
  }

  Future<void> _register(String token) async {
    final result = await _devices.register(
      DeviceRegistration(
        deviceId: await _deviceIds.deviceId(),
        fcmToken: token,
        platform: _platform,
        appVersion: _appVersion,
      ),
    );
    if (result case Err(:final failure)) {
      // No bloquea la app: se reintenta en el próximo refresh/arranque.
      _registered = false;
      _errors?.report(failure, null, reason: 'push register');
    }
  }

  Future<void> _showForeground(PushMessage message) => _local.show(
    message,
    channel: channelFor(message.data),
    payloadRoute: routeFromPushData(message.data),
  );

  void _open(Map<String, Object?> data) {
    final route = routeFromPushData(data);
    if (route != null) _routes.add(route);
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _refreshSub?.cancel();
    await _routes.close();
  }
}
