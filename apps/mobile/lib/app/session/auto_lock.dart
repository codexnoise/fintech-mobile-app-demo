import 'package:flutter/widgets.dart';

/// Bloquea la app si estuvo oculta más de [timeout]. Solo cuentan los
/// estados en que la app no se ve (`hidden`/`paused`); `inactive` lo producen
/// el diálogo biométrico o la cortina de notificaciones y no debe bloquear.
class AutoLock {
  AutoLock({
    required this._onLock,
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<void> Function() _onLock;
  final Duration timeout;
  final DateTime Function() _now;

  DateTime? _hiddenSince;
  AppLifecycleListener? _listener;

  void attach() => _listener ??= AppLifecycleListener(onStateChange: handle);

  void dispose() {
    _listener?.dispose();
    _listener = null;
  }

  @visibleForTesting
  void handle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _hiddenSince ??= _now();
      case AppLifecycleState.resumed:
        final since = _hiddenSince;
        _hiddenSince = null;
        if (since != null && _now().difference(since) > timeout) _onLock();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }
}
