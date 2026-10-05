/// Valores del contrato `POST /onboarding/complete` (docs/api.md).
enum Occupation {
  student('student'),
  employee('employee'),
  businessOwner('business_owner'),
  freelancer('freelancer'),
  retired('retired'),
  other('other');

  const Occupation(this.wire);

  final String wire;

  static Occupation? fromWire(String? value) =>
      values.where((o) => o.wire == value).firstOrNull;
}

enum IncomeRange {
  low('low'),
  medium('medium'),
  high('high');

  const IncomeRange(this.wire);

  final String wire;

  static IncomeRange? fromWire(String? value) =>
      values.where((r) => r.wire == value).firstOrNull;
}

/// Segmento asignado por el backend. [unknown] protege ante valores nuevos.
enum Segment {
  youngDigital('young_digital'),
  entrepreneur('entrepreneur'),
  premium('premium'),
  unknown('unknown');

  const Segment(this.wire);

  final String wire;

  static Segment fromWire(String? value) =>
      values.where((s) => s.wire == value).firstOrNull ?? unknown;
}

final class UserProfile {
  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.segment,
    this.segmentReason,
  });

  final String uid;
  final String firstName;
  final Segment segment;
  final String? segmentReason;
}

/// Datos que el usuario ingresa en el onboarding.
final class OnboardingData {
  const OnboardingData({
    required this.firstName,
    required this.birthYear,
    required this.occupation,
    required this.incomeRange,
  });

  final String firstName;
  final int birthYear;
  final Occupation occupation;
  final IncomeRange incomeRange;
}
