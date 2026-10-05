import 'package:nexo_core/nexo_core.dart';

import '../../features/auth/domain/biometrics.dart';
import '../../features/onboarding/domain/user_profile.dart';

export '../../features/auth/domain/biometrics.dart' show UnlockMethod;

/// Estado de la sesión de la app. El router decide la pantalla a partir de él.
sealed class SessionStatus {
  const SessionStatus();
}

/// Resolviendo la sesión o cargando el perfil.
final class SessionLoading extends SessionStatus {
  const SessionLoading();
}

final class SessionUnauthenticated extends SessionStatus {
  const SessionUnauthenticated();
}

final class SessionNeedsOnboarding extends SessionStatus {
  const SessionNeedsOnboarding();
}

/// Se ofrece activar la biometría (una sola vez por usuario).
final class SessionNeedsBiometricSetup extends SessionStatus {
  const SessionNeedsBiometricSetup();
}

/// Hay sesión de Firebase pero el usuario debe confirmar su identidad.
final class SessionLocked extends SessionStatus {
  const SessionLocked(this.method);

  final UnlockMethod method;
}

final class SessionReady extends SessionStatus {
  const SessionReady(this.profile);

  final UserProfile profile;
}

/// No se pudo cargar el perfil (sin red, BFF caído, etc.).
final class SessionProfileUnavailable extends SessionStatus {
  const SessionProfileUnavailable(this.failure);

  final Failure failure;
}
