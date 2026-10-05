import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/biometrics.dart';
import '../../features/onboarding/domain/profile_repository.dart';
import '../../features/onboarding/domain/user_profile.dart';
import 'session_status.dart';

/// Máquina de estados de la sesión. Combina la sesión de Firebase, el perfil
/// del BFF y el bloqueo; las features la notifican vía [SessionSignals].
class SessionCubit extends Cubit<SessionStatus> implements SessionSignals {
  SessionCubit({
    required this._auth,
    required this._profiles,
    required this._biometric,
    required BiometricPreferences biometricPrefs,
  }) : _prefs = biometricPrefs,
       super(const SessionLoading());

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final BiometricAuthenticator _biometric;
  final BiometricPreferences _prefs;

  StreamSubscription<AuthUser?>? _subscription;
  String? _uid;
  UserProfile? _profile;

  /// Cómo se desbloquea al auto-bloquear; se calcula al quedar lista.
  UnlockMethod? _lockMethod;
  bool _firstEvent = true;

  /// Invalida resoluciones en curso cuando cambia la sesión.
  int _generation = 0;

  void start() {
    _subscription ??= _auth.userChanges().listen(_onUser);
  }

  Future<void> _onUser(AuthUser? user) async {
    final restored = _firstEvent;
    _firstEvent = false;
    final generation = ++_generation;
    _uid = user?.uid;
    _profile = null;

    if (user == null) return emit(const SessionUnauthenticated());
    if (restored) {
      // Sesión persistida de una apertura anterior: confirmar identidad.
      final method = await _unlockMethod(user.uid);
      if (generation == _generation) emit(SessionLocked(method));
      return;
    }
    await _resolve(generation);
  }

  /// Auto-lock: solo bloquea una sesión ya lista.
  ///
  /// Emite en el mismo frame del resume (sin esperar al secure storage) para
  /// que nada alcance a mostrarse ni a navegar con la sesión desbloqueada.
  Future<void> lock() async {
    if (_uid == null || state is! SessionReady) return;
    emit(SessionLocked(_lockMethod ?? UnlockMethod.password));
  }

  /// Reintento manual desde la pantalla de error del splash.
  Future<void> retry() => _resolve(++_generation);

  @override
  Future<void> unlocked() async {
    if (state is! SessionLocked) return;
    await _resolve(++_generation);
  }

  @override
  Future<void> profileChanged() => _resolve(++_generation);

  @override
  Future<void> biometricSetupFinished() async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs.markOffered(uid);
    final profile = _profile;
    if (profile == null) return _resolve(++_generation);
    // La biometría pudo activarse recién: recalcular el método de bloqueo.
    _lockMethod = await _unlockMethod(uid);
    emit(SessionReady(profile));
  }

  Future<UnlockMethod> _unlockMethod(String uid) async =>
      await _prefs.isEnabled(uid) && await _biometric.isAvailable()
      ? UnlockMethod.biometric
      : UnlockMethod.password;

  Future<void> _resolve(int generation) async {
    final uid = _uid;
    if (uid == null) return;
    emit(const SessionLoading());

    final result = await _profiles.fetchProfile();
    if (generation != _generation) return;

    switch (result) {
      case Err(failure: ValidationFailure(code: onboardingRequiredCode)):
        emit(const SessionNeedsOnboarding());
      case Err(:final failure):
        emit(SessionProfileUnavailable(failure));
      case Ok(value: final profile):
        _profile = profile;
        final offer =
            !await _prefs.wasOffered(uid) && await _biometric.isAvailable();
        _lockMethod = await _unlockMethod(uid);
        if (generation != _generation) return;
        emit(
          offer ? const SessionNeedsBiometricSetup() : SessionReady(profile),
        );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
