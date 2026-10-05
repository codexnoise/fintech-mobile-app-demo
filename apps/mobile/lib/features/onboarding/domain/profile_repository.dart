import 'package:nexo_core/nexo_core.dart';

import 'user_profile.dart';

/// Código con el que el BFF indica que falta completar el onboarding.
const onboardingRequiredCode = 'onboarding_required';

abstract interface class ProfileRepository {
  /// `GET /me`. Devuelve `ValidationFailure(onboardingRequiredCode)` si el
  /// usuario aún no completó el registro.
  Future<Result<UserProfile>> fetchProfile();

  /// `POST /onboarding/complete`.
  Future<Result<UserProfile>> completeOnboarding(OnboardingData data);
}
