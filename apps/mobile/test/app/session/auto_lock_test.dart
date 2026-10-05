import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/app/session/auto_lock.dart';

void main() {
  late DateTime now;
  late int locks;
  late AutoLock autoLock;

  setUp(() {
    now = DateTime(2026, 10, 5, 9);
    locks = 0;
    autoLock = AutoLock(onLock: () async => locks++, now: () => now);
  });

  void background() => autoLock.handle(AppLifecycleState.hidden);
  void foreground() => autoLock.handle(AppLifecycleState.resumed);

  test('29 s en background no bloquea', () {
    background();
    now = now.add(const Duration(seconds: 29));
    foreground();

    expect(locks, 0);
  });

  test('31 s en background bloquea al volver', () {
    background();
    now = now.add(const Duration(seconds: 31));
    foreground();

    expect(locks, 1);
  });

  test('cuenta desde que la app se ocultó, no desde la última pausa', () {
    background();
    now = now.add(const Duration(seconds: 20));
    autoLock.handle(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 20));
    foreground();

    expect(locks, 1);
  });

  test('inactive (diálogo biométrico, notificaciones) no cuenta', () {
    autoLock.handle(AppLifecycleState.inactive);
    now = now.add(const Duration(minutes: 5));
    foreground();

    expect(locks, 0);
  });

  test('cada salida a background se mide por separado', () {
    background();
    now = now.add(const Duration(seconds: 31));
    foreground();
    background();
    now = now.add(const Duration(seconds: 5));
    foreground();

    expect(locks, 1);
  });
}
