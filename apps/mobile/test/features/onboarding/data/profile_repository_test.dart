import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/features/onboarding/data/api_profile_repository.dart';
import 'package:nexo_mobile/features/onboarding/domain/user_profile.dart';

void main() {
  test('parsea el UserProfile del BFF', () {
    final p = parseUserProfile({
      'uid': 'u1',
      'firstName': 'Diego',
      'segment': 'premium',
      'segmentReason': 'Ingresos altos',
      'birthYear': 1990,
    });

    expect(p.uid, 'u1');
    expect(p.firstName, 'Diego');
    expect(p.segment, Segment.premium);
    expect(p.segmentReason, 'Ingresos altos');
  });

  test('segmento nuevo desconocido no rompe', () {
    final p = parseUserProfile({
      'uid': 'u1',
      'firstName': 'D',
      'segment': 'platinum',
    });
    expect(p.segment, Segment.unknown);
  });

  test('sin campos obligatorios -> FormatException', () {
    expect(() => parseUserProfile({'uid': 'u1'}), throwsFormatException);
    expect(() => parseUserProfile(['x']), throwsFormatException);
  });

  test('wire values del contrato', () {
    expect(Occupation.businessOwner.wire, 'business_owner');
    expect(Occupation.fromWire('freelancer'), Occupation.freelancer);
    expect(IncomeRange.fromWire('high'), IncomeRange.high);
    expect(IncomeRange.fromWire('x'), isNull);
  });
}
