import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/biometrics.dart';

final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  const LocalAuthBiometricAuthenticator(this._localAuth);

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics &&
          (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        // Sin fallback a PIN/patrón: la biometría es el segundo factor.
        biometricOnly: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return mapLocalAuthCode(e.code);
    } on PlatformException {
      return BiometricResult.failed;
    }
  }
}

BiometricResult mapLocalAuthCode(LocalAuthExceptionCode code) => switch (code) {
  LocalAuthExceptionCode.userCanceled ||
  LocalAuthExceptionCode.systemCanceled ||
  LocalAuthExceptionCode.timeout ||
  LocalAuthExceptionCode.userRequestedFallback ||
  LocalAuthExceptionCode.authInProgress => BiometricResult.cancelled,
  LocalAuthExceptionCode.noBiometricsEnrolled ||
  LocalAuthExceptionCode.noBiometricHardware ||
  LocalAuthExceptionCode.noCredentialsSet ||
  LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
  LocalAuthExceptionCode.uiUnavailable => BiometricResult.unavailable,
  LocalAuthExceptionCode.temporaryLockout ||
  LocalAuthExceptionCode.biometricLockout => BiometricResult.lockedOut,
  LocalAuthExceptionCode.deviceError ||
  LocalAuthExceptionCode.unknownError => BiometricResult.failed,
};

/// Flags biométricos en Keystore (Android, AES-GCM) / Keychain (iOS, solo
/// este dispositivo, disponible tras el primer desbloqueo).
final class SecureBiometricPreferences implements BiometricPreferences {
  const SecureBiometricPreferences(this._storage);

  /// Almacenamiento con las opciones de seguridad de Nexo.
  static FlutterSecureStorage createStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  static String _enabledKey(String uid) => 'biometric.enabled.$uid';
  static String _offeredKey(String uid) => 'biometric.offered.$uid';

  @override
  Future<bool> isEnabled(String uid) async =>
      await _storage.read(key: _enabledKey(uid)) == 'true';

  @override
  Future<void> setEnabled(String uid, {required bool enabled}) =>
      _storage.write(key: _enabledKey(uid), value: '$enabled');

  @override
  Future<bool> wasOffered(String uid) async =>
      await _storage.read(key: _offeredKey(uid)) == 'true';

  @override
  Future<void> markOffered(String uid) =>
      _storage.write(key: _offeredKey(uid), value: 'true');

  @override
  Future<void> clear() => _storage.deleteAll();
}
