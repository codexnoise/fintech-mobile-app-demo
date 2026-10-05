import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/domain/biometrics.dart';
import 'package:nexo_mobile/features/auth/domain/logout.dart';
import 'package:nexo_mobile/features/auth/presentation/biometric_setup_cubit.dart';
import 'package:nexo_mobile/features/auth/presentation/lock_cubit.dart';

import '../../../helpers/fakes.dart';

class _MockSignals extends Mock implements SessionSignals {}

class _MockLogout extends Mock implements LogoutUseCase {}

void main() {
  late FakeAuthRepository auth;
  late FakeBiometricAuthenticator biometric;
  late FakeBiometricPreferences prefs;
  late _MockSignals signals;
  late _MockLogout logout;

  setUp(() {
    auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: 'u1', email: 'ana@nexo.ec'),
    );
    biometric = FakeBiometricAuthenticator();
    prefs = FakeBiometricPreferences();
    signals = _MockSignals();
    logout = _MockLogout();
    when(signals.unlocked).thenAnswer((_) async {});
    when(signals.biometricSetupFinished).thenAnswer((_) async {});
    when(logout.call).thenAnswer((_) async {});
  });

  group('BiometricSetupCubit', () {
    BiometricSetupCubit build() =>
        BiometricSetupCubit(auth, biometric, prefs, signals);

    blocTest<BiometricSetupCubit, BiometricSetupState>(
      'activar exige confirmar con biometría y guarda el flag',
      build: build,
      act: (c) => c.enable(),
      expect: () => [
        isA<BiometricSetupInProgress>(),
        isA<BiometricSetupDone>(),
      ],
      verify: (_) {
        expect(prefs.enabled, {'u1'});
        verify(signals.biometricSetupFinished).called(1);
      },
    );

    blocTest<BiometricSetupCubit, BiometricSetupState>(
      'si cancela el prompt no activa y puede reintentar',
      setUp: () => biometric.result = BiometricResult.cancelled,
      build: build,
      act: (c) => c.enable(),
      expect: () => [
        isA<BiometricSetupInProgress>(),
        isA<BiometricSetupIdle>().having((s) => s.message, 'message', isNull),
      ],
      verify: (_) {
        expect(prefs.enabled, isEmpty);
        verifyNever(signals.biometricSetupFinished);
      },
    );

    blocTest<BiometricSetupCubit, BiometricSetupState>(
      'ahora no: termina sin activar',
      build: build,
      act: (c) => c.skip(),
      expect: () => [isA<BiometricSetupDone>()],
      verify: (_) {
        expect(prefs.enabled, isEmpty);
        verify(signals.biometricSetupFinished).called(1);
      },
    );
  });

  group('LockCubit', () {
    LockCubit build(UnlockMethod method) =>
        LockCubit(auth, biometric, signals, logout, method: method);

    blocTest<LockCubit, LockScreenState>(
      'desbloqueo biométrico exitoso',
      build: () => build(UnlockMethod.biometric),
      act: (c) => c.unlockWithBiometric(),
      expect: () => [isA<LockInProgress>(), isA<LockUnlocked>()],
      verify: (_) => verify(signals.unlocked).called(1),
    );

    blocTest<LockCubit, LockScreenState>(
      'cancelar mantiene la app bloqueada',
      setUp: () => biometric.result = BiometricResult.cancelled,
      build: () => build(UnlockMethod.biometric),
      act: (c) => c.unlockWithBiometric(),
      expect: () => [
        isA<LockInProgress>(),
        isA<LockIdle>()
            .having((s) => s.method, 'method', UnlockMethod.biometric)
            .having((s) => s.message, 'message', isNull),
      ],
      verify: (_) => verifyNever(signals.unlocked),
    );

    blocTest<LockCubit, LockScreenState>(
      'biometría bloqueada por intentos -> pide contraseña de Nexo',
      setUp: () => biometric.result = BiometricResult.lockedOut,
      build: () => build(UnlockMethod.biometric),
      act: (c) => c.unlockWithBiometric(),
      expect: () => [
        isA<LockInProgress>(),
        isA<LockIdle>()
            .having((s) => s.method, 'method', UnlockMethod.password)
            .having((s) => s.message, 'message', isNotNull),
      ],
    );

    blocTest<LockCubit, LockScreenState>(
      'desbloqueo con contraseña reautentica',
      build: () => build(UnlockMethod.password),
      act: (c) => c.unlockWithPassword('clave1234'),
      expect: () => [isA<LockInProgress>(), isA<LockUnlocked>()],
      verify: (_) {
        expect(auth.lastPassword, 'clave1234');
        verify(signals.unlocked).called(1);
      },
    );

    blocTest<LockCubit, LockScreenState>(
      'contraseña incorrecta -> mensaje y sigue bloqueada',
      setUp: () => auth.nextFailure = const ValidationFailure(
        AuthErrorCodes.invalidCredentials,
      ),
      build: () => build(UnlockMethod.password),
      act: (c) => c.unlockWithPassword('mala'),
      expect: () => [
        isA<LockInProgress>(),
        isA<LockIdle>().having(
          (s) => s.message,
          'message',
          'Contraseña incorrecta.',
        ),
      ],
      verify: (_) => verifyNever(signals.unlocked),
    );

    blocTest<LockCubit, LockScreenState>(
      'usar otra cuenta cierra sesión',
      build: () => build(UnlockMethod.biometric),
      act: (c) => c.useAnotherAccount(),
      expect: () => [isA<LockInProgress>()],
      verify: (_) => verify(logout.call).called(1),
    );
  });
}
