import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/auth_repository.dart';
import '../domain/biometrics.dart';

sealed class BiometricSetupState {
  const BiometricSetupState();
}

final class BiometricSetupIdle extends BiometricSetupState {
  const BiometricSetupIdle({this.message});

  final String? message;
}

final class BiometricSetupInProgress extends BiometricSetupState {
  const BiometricSetupInProgress();
}

final class BiometricSetupDone extends BiometricSetupState {
  const BiometricSetupDone();
}

class BiometricSetupCubit extends Cubit<BiometricSetupState> {
  BiometricSetupCubit(this._auth, this._biometric, this._prefs, this._session)
    : super(const BiometricSetupIdle());

  final AuthRepository _auth;
  final BiometricAuthenticator _biometric;
  final BiometricPreferences _prefs;
  final SessionSignals _session;

  /// Activa solo después de que el usuario confirma con su biometría.
  Future<void> enable() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || state is! BiometricSetupIdle) return;
    emit(const BiometricSetupInProgress());

    final result = await _biometric.authenticate(
      reason: 'Confirma tu identidad para activar el ingreso con biometría',
    );
    switch (result) {
      case BiometricResult.success:
        await _prefs.setEnabled(uid, enabled: true);
        await _finish();
      case BiometricResult.cancelled:
        emit(const BiometricSetupIdle());
      case BiometricResult.unavailable:
        emit(
          const BiometricSetupIdle(
            message: 'Tu dispositivo no tiene biometría configurada.',
          ),
        );
      case BiometricResult.lockedOut || BiometricResult.failed:
        emit(
          const BiometricSetupIdle(
            message: 'No pudimos verificar tu biometría. Intenta de nuevo.',
          ),
        );
    }
  }

  Future<void> skip() async {
    if (state is! BiometricSetupIdle) return;
    await _finish();
  }

  Future<void> _finish() async {
    emit(const BiometricSetupDone());
    await _session.biometricSetupFinished();
  }
}
