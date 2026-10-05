import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/app/session/session_cubit.dart';
import 'package:nexo_mobile/app/session/session_status.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/domain/biometrics.dart';
import 'package:nexo_mobile/features/onboarding/domain/profile_repository.dart';
import 'package:nexo_mobile/features/onboarding/domain/user_profile.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockProfiles extends Mock implements ProfileRepository {}

class _MockBiometric extends Mock implements BiometricAuthenticator {}

class _MockPrefs extends Mock implements BiometricPreferences {}

const _user = AuthUser(uid: 'u1', email: 'ana@nexo.ec');
const _profile = UserProfile(
  uid: 'u1',
  firstName: 'Ana',
  segment: Segment.premium,
);

void main() {
  late _MockAuth auth;
  late _MockProfiles profiles;
  late _MockBiometric biometric;
  late _MockPrefs prefs;
  late StreamController<AuthUser?> users;

  setUp(() {
    auth = _MockAuth();
    profiles = _MockProfiles();
    biometric = _MockBiometric();
    prefs = _MockPrefs();
    users = StreamController<AuthUser?>();
    when(auth.userChanges).thenAnswer((_) => users.stream);
    when(profiles.fetchProfile)
        .thenAnswer((_) async => const Result.ok(_profile));
    when(biometric.isAvailable).thenAnswer((_) async => true);
    when(() => prefs.isEnabled(any())).thenAnswer((_) async => false);
    when(() => prefs.wasOffered(any())).thenAnswer((_) async => true);
    when(() => prefs.markOffered(any())).thenAnswer((_) async {});
  });

  tearDown(() => users.close());

  SessionCubit build() => SessionCubit(
    auth: auth,
    profiles: profiles,
    biometric: biometric,
    biometricPrefs: prefs,
  )..start();

  blocTest<SessionCubit, SessionStatus>(
    'sin sesión al arrancar -> unauthenticated',
    build: build,
    act: (_) => users.add(null),
    expect: () => [isA<SessionUnauthenticated>()],
  );

  group('sesión restaurada al arrancar', () {
    blocTest<SessionCubit, SessionStatus>(
      'con biometría activa -> lock biométrico',
      setUp: () =>
          when(() => prefs.isEnabled('u1')).thenAnswer((_) async => true),
      build: build,
      act: (_) => users.add(_user),
      expect: () => [
        isA<SessionLocked>().having(
          (s) => s.method,
          'method',
          UnlockMethod.biometric,
        ),
      ],
      verify: (_) => verifyNever(profiles.fetchProfile),
    );

    blocTest<SessionCubit, SessionStatus>(
      'sin biometría -> lock con contraseña',
      build: build,
      act: (_) => users.add(_user),
      expect: () => [
        isA<SessionLocked>().having(
          (s) => s.method,
          'method',
          UnlockMethod.password,
        ),
      ],
    );

    blocTest<SessionCubit, SessionStatus>(
      'biometría activa pero el sensor ya no está disponible -> contraseña',
      setUp: () {
        when(() => prefs.isEnabled('u1')).thenAnswer((_) async => true);
        when(biometric.isAvailable).thenAnswer((_) async => false);
      },
      build: build,
      act: (_) => users.add(_user),
      expect: () => [
        isA<SessionLocked>().having(
          (s) => s.method,
          'method',
          UnlockMethod.password,
        ),
      ],
    );

    blocTest<SessionCubit, SessionStatus>(
      'al desbloquear carga el perfil -> ready',
      build: build,
      act: (cubit) async {
        users.add(_user);
        await Future<void>.delayed(Duration.zero);
        await cubit.unlocked();
      },
      skip: 1,
      expect: () => [isA<SessionLoading>(), isA<SessionReady>()],
    );
  });

  group('login nuevo (no restaurado)', () {
    blocTest<SessionCubit, SessionStatus>(
      'perfil completo -> ready sin pedir desbloqueo',
      build: build,
      act: (_) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        users.add(_user);
      },
      expect: () => [
        isA<SessionUnauthenticated>(),
        isA<SessionLoading>(),
        isA<SessionReady>(),
      ],
    );

    blocTest<SessionCubit, SessionStatus>(
      'onboarding_required -> needsOnboarding',
      setUp: () => when(profiles.fetchProfile).thenAnswer(
        (_) async => const Result.err(ValidationFailure('onboarding_required')),
      ),
      build: build,
      act: (_) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        users.add(_user);
      },
      skip: 2,
      expect: () => [isA<SessionNeedsOnboarding>()],
    );

    blocTest<SessionCubit, SessionStatus>(
      'biometría no ofrecida y disponible -> needsBiometricSetup',
      setUp: () =>
          when(() => prefs.wasOffered('u1')).thenAnswer((_) async => false),
      build: build,
      act: (_) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        users.add(_user);
      },
      skip: 2,
      expect: () => [isA<SessionNeedsBiometricSetup>()],
    );

    blocTest<SessionCubit, SessionStatus>(
      'biometría no disponible -> ready sin ofrecerla',
      setUp: () {
        when(() => prefs.wasOffered('u1')).thenAnswer((_) async => false);
        when(biometric.isAvailable).thenAnswer((_) async => false);
      },
      build: build,
      act: (_) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        users.add(_user);
      },
      skip: 2,
      expect: () => [isA<SessionReady>()],
    );

    blocTest<SessionCubit, SessionStatus>(
      'error de red al cargar perfil -> profileUnavailable',
      setUp: () =>
          when(profiles.fetchProfile)
              .thenAnswer((_) async => const Result.err(NetworkFailure())),
      build: build,
      act: (_) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        users.add(_user);
      },
      skip: 2,
      expect: () => [isA<SessionProfileUnavailable>()],
    );
  });

  blocTest<SessionCubit, SessionStatus>(
    'biometricSetupFinished marca la oferta y pasa a ready',
    setUp: () =>
        when(() => prefs.wasOffered('u1')).thenAnswer((_) async => false),
    build: build,
    act: (cubit) async {
      users.add(null);
      await Future<void>.delayed(Duration.zero);
      users.add(_user);
      await Future<void>.delayed(Duration.zero);
      when(() => prefs.wasOffered('u1')).thenAnswer((_) async => true);
      await cubit.biometricSetupFinished();
    },
    skip: 3,
    expect: () => [isA<SessionReady>()],
    verify: (_) => verify(() => prefs.markOffered('u1')).called(1),
  );

  group('lock()', () {
    blocTest<SessionCubit, SessionStatus>(
      'bloquea una sesión lista',
      build: build,
      act: (cubit) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        users.add(_user);
        await Future<void>.delayed(Duration.zero);
        await cubit.lock();
      },
      skip: 3,
      expect: () => [isA<SessionLocked>()],
    );

    blocTest<SessionCubit, SessionStatus>(
      'no hace nada sin sesión',
      build: build,
      act: (cubit) async {
        users.add(null);
        await Future<void>.delayed(Duration.zero);
        await cubit.lock();
      },
      expect: () => [isA<SessionUnauthenticated>()],
    );
  });

  blocTest<SessionCubit, SessionStatus>(
    'logout desde cualquier estado -> unauthenticated',
    setUp: () =>
        when(() => prefs.isEnabled('u1')).thenAnswer((_) async => true),
    build: build,
    act: (_) async {
      users.add(_user);
      await Future<void>.delayed(Duration.zero);
      users.add(null);
    },
    expect: () => [isA<SessionLocked>(), isA<SessionUnauthenticated>()],
  );

  blocTest<SessionCubit, SessionStatus>(
    'un perfil que llega tarde no pisa un logout posterior',
    setUp: () {
      final pending = Completer<Result<UserProfile>>();
      when(profiles.fetchProfile).thenAnswer((_) => pending.future);
      addTearDown(() => pending.complete(const Result.ok(_profile)));
    },
    build: build,
    act: (_) async {
      users.add(null);
      await Future<void>.delayed(Duration.zero);
      users.add(_user);
      await Future<void>.delayed(Duration.zero);
      users.add(null);
    },
    expect: () => [
      isA<SessionUnauthenticated>(),
      isA<SessionLoading>(),
      isA<SessionUnauthenticated>(),
    ],
  );
}
