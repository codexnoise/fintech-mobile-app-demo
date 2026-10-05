import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/app/session/session_redirect.dart';
import 'package:nexo_mobile/app/session/session_status.dart';
import 'package:nexo_mobile/features/onboarding/domain/user_profile.dart';

const _profile = UserProfile(
  uid: 'u1',
  firstName: 'Ana',
  segment: Segment.youngDigital,
);

String? go(SessionStatus status, String location) =>
    sessionRedirect(status, Uri.parse(location));

void main() {
  test('cargando o perfil no disponible -> splash', () {
    expect(go(const SessionLoading(), NexoRoutes.home), NexoRoutes.splash);
    expect(go(const SessionLoading(), NexoRoutes.splash), isNull);
    expect(
      go(
        const SessionProfileUnavailable(NetworkFailure()),
        NexoRoutes.accountPattern,
      ),
      NexoRoutes.splash,
    );
  });

  test('sin sesión solo permite login y registro', () {
    const s = SessionUnauthenticated();
    expect(go(s, NexoRoutes.home), NexoRoutes.login);
    expect(go(s, NexoRoutes.splash), NexoRoutes.login);
    expect(go(s, NexoRoutes.login), isNull);
    expect(go(s, NexoRoutes.register), isNull);
  });

  test('onboarding pendiente fuerza /onboarding', () {
    const s = SessionNeedsOnboarding();
    expect(go(s, NexoRoutes.home), NexoRoutes.onboarding);
    expect(go(s, NexoRoutes.onboarding), isNull);
  });

  test('oferta de biometría fuerza /biometric-setup', () {
    const s = SessionNeedsBiometricSetup();
    expect(go(s, NexoRoutes.home), NexoRoutes.biometricSetup);
    expect(go(s, NexoRoutes.biometricSetup), isNull);
  });

  test('bloqueada -> /lock recordando el destino', () {
    const s = SessionLocked(UnlockMethod.biometric);
    expect(go(s, '/accounts/checking'), '/lock?from=%2Faccounts%2Fchecking');
    expect(go(s, NexoRoutes.home), '/lock?from=%2Fhome');
    expect(go(s, NexoRoutes.splash), NexoRoutes.lock);
    expect(go(s, '/lock?from=%2Fhome'), isNull);
  });

  test('lista: sale de las pantallas de entrada', () {
    const s = SessionReady(_profile);
    for (final gate in [
      NexoRoutes.splash,
      NexoRoutes.login,
      NexoRoutes.register,
      NexoRoutes.onboarding,
      NexoRoutes.biometricSetup,
      NexoRoutes.lock,
    ]) {
      expect(go(s, gate), NexoRoutes.home, reason: gate);
    }
    expect(go(s, '/accounts/savings'), isNull);
  });

  test('lista: vuelve al destino guardado al desbloquear', () {
    const s = SessionReady(_profile);
    expect(go(s, '/lock?from=%2Faccounts%2Fchecking'), '/accounts/checking');
  });

  test('ignora destinos externos o inválidos en from', () {
    const s = SessionReady(_profile);
    expect(go(s, '/lock?from=https%3A%2F%2Fevil.com'), NexoRoutes.home);
    expect(go(s, '/lock?from=%2F%2Fevil.com'), NexoRoutes.home);
    expect(go(s, '/lock?from=%2Flogin'), NexoRoutes.home);
  });

  test('Network Lab no tiene guard de sesión', () {
    expect(go(const SessionUnauthenticated(), NexoRoutes.networkLab), isNull);
  });
}
