import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/auth/data/firebase_auth_repository.dart';
import 'package:nexo_mobile/features/auth/data/local_biometrics.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/domain/biometrics.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockLocalAuth extends Mock implements LocalAuthentication {}

FirebaseAuthException _fx(String code) => FirebaseAuthException(code: code);

void main() {
  group('mapAuthException', () {
    final table = <String, String>{
      'invalid-credential': AuthErrorCodes.invalidCredentials,
      'wrong-password': AuthErrorCodes.invalidCredentials,
      'user-not-found': AuthErrorCodes.invalidCredentials,
      'email-already-in-use': AuthErrorCodes.emailInUse,
      'invalid-email': AuthErrorCodes.invalidEmail,
      'weak-password': AuthErrorCodes.weakPassword,
      'too-many-requests': AuthErrorCodes.tooManyRequests,
      'user-disabled': AuthErrorCodes.userDisabled,
    };
    table.forEach((firebaseCode, domainCode) {
      test('$firebaseCode -> $domainCode', () {
        final f = mapAuthException(_fx(firebaseCode));
        expect((f as ValidationFailure).code, domainCode);
      });
    });

    test('sin red -> NetworkFailure', () {
      expect(
        mapAuthException(_fx('network-request-failed')),
        isA<NetworkFailure>(),
      );
    });

    test('código desconocido -> UnknownFailure', () {
      expect(mapAuthException(_fx('internal-error')), isA<UnknownFailure>());
    });
  });

  group('FirebaseAuthRepository', () {
    late _MockFirebaseAuth auth;

    setUp(() => auth = _MockFirebaseAuth());

    test('reset de contraseña no revela si la cuenta existe', () async {
      when(() => auth.sendPasswordResetEmail(email: 'x@nexo.ec'))
          .thenThrow(_fx('user-not-found'));

      final res = await FirebaseAuthRepository(auth)
          .sendPasswordReset(' x@nexo.ec ');

      expect(res.isOk, isTrue);
    });

    test('reautenticar sin sesión -> no_session', () async {
      when(() => auth.currentUser).thenReturn(null);

      final res = await FirebaseAuthRepository(auth).reauthenticate('x');

      final f = res.fold(ok: (_) => null, err: (f) => f);
      expect((f! as ValidationFailure).code, AuthErrorCodes.noSession);
    });

    test('login con credenciales inválidas -> Result.err', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: 'ana@nexo.ec',
          password: 'bad',
        ),
      ).thenThrow(_fx('invalid-credential'));

      final res = await FirebaseAuthRepository(auth)
          .signIn(email: 'ana@nexo.ec ', password: 'bad');

      final f = res.fold(ok: (_) => null, err: (f) => f);
      expect((f! as ValidationFailure).code, AuthErrorCodes.invalidCredentials);
    });
  });

  group('LocalAuthBiometricAuthenticator', () {
    late _MockLocalAuth localAuth;

    setUp(() => localAuth = _MockLocalAuth());

    test('pide solo biometría, sin fallback al PIN', () async {
      when(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenAnswer((_) async => true);

      final r = await LocalAuthBiometricAuthenticator(localAuth)
          .authenticate(reason: 'Desbloquea Nexo');

      expect(r, BiometricResult.success);
      verify(
        () => localAuth.authenticate(
          localizedReason: 'Desbloquea Nexo',
          biometricOnly: true,
        ),
      ).called(1);
    });

    test('mapea excepciones de local_auth', () async {
      when(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenThrow(
        const LocalAuthException(code: LocalAuthExceptionCode.biometricLockout),
      );

      final r = await LocalAuthBiometricAuthenticator(localAuth)
          .authenticate(reason: 'x');

      expect(r, BiometricResult.lockedOut);
    });

    test('tabla de códigos', () {
      expect(
        mapLocalAuthCode(LocalAuthExceptionCode.userCanceled),
        BiometricResult.cancelled,
      );
      expect(
        mapLocalAuthCode(LocalAuthExceptionCode.noBiometricsEnrolled),
        BiometricResult.unavailable,
      );
      expect(
        mapLocalAuthCode(LocalAuthExceptionCode.temporaryLockout),
        BiometricResult.lockedOut,
      );
    });

    test('isAvailable exige hardware y huellas registradas', () async {
      when(localAuth.isDeviceSupported).thenAnswer((_) async => true);
      when(() => localAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(localAuth.getAvailableBiometrics).thenAnswer((_) async => []);

      expect(
        await LocalAuthBiometricAuthenticator(localAuth).isAvailable(),
        isFalse,
      );
    });
  });

  group('SecureBiometricPreferences', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('guarda flags por usuario y los borra en clear', () async {
      const prefs = SecureBiometricPreferences(FlutterSecureStorage());

      expect(await prefs.isEnabled('u1'), isFalse);
      await prefs.setEnabled('u1', enabled: true);
      await prefs.markOffered('u1');

      expect(await prefs.isEnabled('u1'), isTrue);
      expect(await prefs.isEnabled('u2'), isFalse);
      expect(await prefs.wasOffered('u1'), isTrue);

      await prefs.clear();
      expect(await prefs.isEnabled('u1'), isFalse);
      expect(await prefs.wasOffered('u1'), isFalse);
    });
  });
}
