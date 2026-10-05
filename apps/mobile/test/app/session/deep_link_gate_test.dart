import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/app/session/deep_link_gate.dart';
import 'package:nexo_mobile/app/session/session_status.dart';

import '../../helpers/fakes.dart';

void main() {
  late SessionStatus status;
  late bool foreground;
  late List<String> navigated;
  late DeepLinkGate gate;

  setUp(() {
    status = const SessionReady(testProfile);
    foreground = true;
    navigated = [];
    gate = DeepLinkGate(
      currentStatus: () => status,
      isForeground: () => foreground,
      navigate: navigated.add,
      // Síncrono en tests; en la app espera al siguiente frame.
      schedule: (flush) => flush(),
    );
  });

  test('sesión lista y app visible: navega de inmediato', () {
    gate.add('/accounts');

    expect(navigated, ['/accounts']);
  });

  test('tap con la app aún en background: espera al resume', () {
    foreground = false;
    gate.add('/accounts');
    expect(navigated, isEmpty);

    foreground = true;
    gate.onResumed();

    expect(navigated, ['/accounts']);
  });

  test('si al volver la app se bloquea, abre la ruta tras desbloquear', () {
    foreground = false;
    gate.add('/accounts/savings');

    // Resume: el auto-lock ya bloqueó la sesión en el mismo frame.
    foreground = true;
    status = const SessionLocked(UnlockMethod.biometric);
    gate.onResumed();
    expect(navigated, isEmpty);

    status = const SessionReady(testProfile);
    gate.onStatus(status);

    expect(navigated, ['/accounts/savings']);
  });

  test('app abierta desde cerrada: espera a que la sesión se resuelva', () {
    status = const SessionLoading();
    gate.add('/accounts');
    gate.onStatus(const SessionLocked(UnlockMethod.password));
    expect(navigated, isEmpty);

    status = const SessionReady(testProfile);
    gate.onStatus(status);

    expect(navigated, ['/accounts']);
  });

  test('sin sesión descarta el deep link al cerrar sesión', () {
    status = const SessionLocked(UnlockMethod.password);
    gate.add('/accounts');

    status = const SessionUnauthenticated();
    gate.onStatus(status);
    status = const SessionReady(testProfile);
    gate.onStatus(status);

    expect(navigated, isEmpty, reason: 'no abrir datos del usuario anterior');
  });

  test('navega una sola vez y el último tap gana', () {
    status = const SessionLocked(UnlockMethod.password);
    gate
      ..add('/home')
      ..add('/accounts');

    status = const SessionReady(testProfile);
    gate
      ..onStatus(status)
      ..onStatus(status);

    expect(navigated, ['/accounts']);
  });
}
