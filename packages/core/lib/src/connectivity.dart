import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de red del dispositivo. "Online" significa que hay una interfaz
/// conectada, no que el backend responda (eso lo manejan timeouts y errores).
abstract interface class ConnectivityMonitor {
  Future<bool> isOnline();

  Stream<bool> get onlineChanges;
}

final class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async =>
      _online(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_online).distinct();
}
