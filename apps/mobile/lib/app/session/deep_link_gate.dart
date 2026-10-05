import 'package:flutter/scheduler.dart';

import 'session_status.dart';

/// Retiene un deep link (tap en una push) hasta que se pueda abrir: la app
/// en primer plano y la sesión lista. Si en el camino hay que pasar por
/// `/lock`, la ruta se abre después de desbloquear.
///
/// No se apoya en el `from` del redirect: go_router evalúa el redirect con
/// la URI base de la pila, sin las rutas agregadas con `push`
/// (go_router 18, `RouteMatchList.uri`), así que el destino se perdía.
class DeepLinkGate {
  DeepLinkGate({
    required this._currentStatus,
    required this._isForeground,
    required this._navigate,
    void Function(void Function() flush)? schedule,
  }) : _schedule = schedule ?? _nextFrame;

  final SessionStatus Function() _currentStatus;
  final bool Function() _isForeground;
  final void Function(String route) _navigate;
  final void Function(void Function()) _schedule;

  String? _pending;

  /// Espera al siguiente frame: el auto-lock decide en el mismo resume.
  static void _nextFrame(void Function() flush) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => flush())
      ..scheduleFrame();
  }

  void add(String route) {
    _pending = route;
    _schedule(_flush);
  }

  void onResumed() => _schedule(_flush);

  void onStatus(SessionStatus status) {
    // El deep link era para el usuario que cerró sesión: se descarta.
    if (status is SessionUnauthenticated) _pending = null;
    _schedule(_flush);
  }

  void _flush() {
    final route = _pending;
    if (route == null || !_isForeground()) return;
    if (_currentStatus() is! SessionReady) return;
    _pending = null;
    _navigate(route);
  }
}
