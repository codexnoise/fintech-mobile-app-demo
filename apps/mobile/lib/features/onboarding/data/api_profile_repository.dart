import 'package:nexo_core/nexo_core.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

final class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<UserProfile>> fetchProfile() =>
      _api.get('/me', decode: parseUserProfile);

  @override
  Future<Result<UserProfile>> completeOnboarding(OnboardingData data) =>
      _api.post(
        '/onboarding/complete',
        body: {
          'firstName': data.firstName.trim(),
          'birthYear': data.birthYear,
          'occupation': data.occupation.wire,
          'incomeRange': data.incomeRange.wire,
        },
        decode: parseUserProfile,
      );
}

/// `UserProfile` del BFF. Lanza [FormatException] si falta un campo
/// obligatorio (el ApiClient lo convierte en `invalid_response`).
UserProfile parseUserProfile(Object? json) {
  if (json is! Map) throw const FormatException('UserProfile: no es objeto');
  final uid = json['uid'];
  final firstName = json['firstName'];
  if (uid is! String || firstName is! String) {
    throw const FormatException('UserProfile: uid/firstName requeridos');
  }
  final reason = json['segmentReason'];
  return UserProfile(
    uid: uid,
    firstName: firstName,
    segment: Segment.fromWire(json['segment'] as String?),
    segmentReason: reason is String ? reason : null,
  );
}
