import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/auth_repository.dart';
import '../domain/biometrics.dart';
import '../domain/logout.dart';
import 'auth_messages.dart';

sealed class LockScreenState {
  const LockScreenState();
}

final class LockIdle extends LockScreenState {
  const LockIdle(this.method, {this.message});

  final UnlockMethod method;
  final String? message;
}

final class LockInProgress extends LockScreenState {
  const LockInProgress(this.method);

  final UnlockMethod method;
}

final class LockUnlocked extends LockScreenState {
  const LockUnlocked();
}

class LockCubit extends Cubit<LockScreenState> {
  LockCubit(
    this._auth,
    this._biometric,
    this._session,
    this._logout, {
    required UnlockMethod method,
  }) : super(LockIdle(method));

  final AuthRepository _auth;
  final BiometricAuthenticator _biometric;
  final SessionSignals _session;
  final LogoutUseCase _logout;

  Future<void> unlockWithBiometric() async {
    final current = state;
    if (current is! LockIdle || current.method != UnlockMethod.biometric) {
      return;
    }
    emit(const LockInProgress(UnlockMethod.biometric));

    final result = await _biometric.authenticate(reason: 'Desbloquea Nexo');
    switch (result) {
      case BiometricResult.success:
        await _unlocked();
      case BiometricResult.cancelled:
        emit(const LockIdle(UnlockMethod.biometric));
      case BiometricResult.failed:
        emit(
          const LockIdle(
            UnlockMethod.biometric,
            message: 'No pudimos verificar tu biometría. Intenta de nuevo.',
          ),
        );
      // Nunca se cae al PIN del dispositivo: se pide la contraseña de Nexo.
      case BiometricResult.lockedOut:
        emit(
          const LockIdle(
            UnlockMethod.password,
            message:
                'Demasiados intentos con biometría. Ingresa tu contraseña.',
          ),
        );
      case BiometricResult.unavailable:
        emit(
          const LockIdle(
            UnlockMethod.password,
            message: 'La biometría no está disponible. Ingresa tu contraseña.',
          ),
        );
    }
  }

  Future<void> unlockWithPassword(String password) async {
    if (state is! LockIdle) return;
    emit(const LockInProgress(UnlockMethod.password));
    final result = await _auth.reauthenticate(password);
    switch (result) {
      case Ok():
        await _unlocked();
      // El correo está fijo en esta pantalla: solo puede fallar la clave.
      case Err(
        failure: ValidationFailure(code: AuthErrorCodes.invalidCredentials),
      ):
        emit(
          const LockIdle(
            UnlockMethod.password,
            message: 'Contraseña incorrecta.',
          ),
        );
      case Err(:final failure):
        emit(
          LockIdle(UnlockMethod.password, message: authErrorMessage(failure)),
        );
    }
  }

  Future<void> useAnotherAccount() async {
    final current = state;
    if (current is LockInProgress || current is LockUnlocked) return;
    emit(LockInProgress((current as LockIdle).method));
    await _logout();
  }

  Future<void> _unlocked() async {
    emit(const LockUnlocked());
    await _session.unlocked();
  }
}
