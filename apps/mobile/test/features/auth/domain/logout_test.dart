import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/domain/logout.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('limpia todo y cierra la sesión al final', () async {
    final auth = FakeAuthRepository(initialUser: const AuthUser(uid: 'u1'));
    final prefs = FakeBiometricPreferences()
      ..enabled.add('u1')
      ..offered.add('u1');
    final registry = SessionCleanupRegistry();
    final order = <String>[];
    registry.register(() async => order.add('cache:${auth.signOutCalls}'));

    await LogoutUseCase(auth, prefs, registry)();

    expect(order, ['cache:0'], reason: 'limpia antes de cerrar sesión');
    expect(prefs.enabled, isEmpty);
    expect(prefs.offered, isEmpty);
    expect(auth.signOutCalls, 1);
  });

  test('cierra sesión aunque una limpieza falle', () async {
    final auth = FakeAuthRepository(initialUser: const AuthUser(uid: 'u1'));
    final registry = SessionCleanupRegistry()
      ..register(() async => throw StateError('firestore'));
    final reported = <Object>[];

    await LogoutUseCase(
      auth,
      FakeBiometricPreferences(),
      registry,
      onCleanupError: reported.add,
    )();

    expect(auth.signOutCalls, 1);
    expect(reported.single, isA<StateError>());
  });
}
