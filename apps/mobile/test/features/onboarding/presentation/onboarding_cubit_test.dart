import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/onboarding/domain/user_profile.dart';
import 'package:nexo_mobile/features/onboarding/presentation/onboarding_cubit.dart';

import '../../../helpers/fakes.dart';

class _MockSignals extends Mock implements SessionSignals {}

void main() {
  late FakeProfileRepository profiles;
  late _MockSignals signals;

  setUp(() {
    profiles = FakeProfileRepository();
    signals = _MockSignals();
    when(signals.profileChanged).thenAnswer((_) async {});
  });

  OnboardingCubit build() =>
      OnboardingCubit(profiles, signals, currentYear: () => 2026);

  blocTest<OnboardingCubit, OnboardingState>(
    'avanza paso a paso y envía los datos del contrato',
    build: build,
    act: (c) async {
      c.submitName('  Ana María ');
      c.submitProfile(birthYear: 1995, occupation: Occupation.freelancer);
      await c.submitIncome(IncomeRange.medium);
    },
    expect: () => [
      isA<OnboardingEditing>().having((s) => s.step, 'step', 1),
      isA<OnboardingEditing>().having((s) => s.step, 'step', 2),
      isA<OnboardingSubmitting>(),
      isA<OnboardingDone>(),
    ],
    verify: (_) {
      final sent = profiles.submitted!;
      expect(sent.firstName, 'Ana María');
      expect(sent.birthYear, 1995);
      expect(sent.occupation, Occupation.freelancer);
      expect(sent.incomeRange, IncomeRange.medium);
      verify(signals.profileChanged).called(1);
    },
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'nombre inválido no avanza',
    build: build,
    act: (c) => c.submitName('A'),
    expect: () => [
      isA<OnboardingEditing>()
          .having((s) => s.step, 'step', 0)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'menor de 18 no avanza',
    build: build,
    act: (c) {
      c.submitName('Ana');
      c.submitProfile(birthYear: 2010, occupation: Occupation.student);
    },
    skip: 1,
    expect: () => [
      isA<OnboardingEditing>()
          .having((s) => s.step, 'step', 1)
          .having((s) => s.error, 'error', contains('18')),
    ],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'back vuelve al paso anterior conservando lo ingresado',
    build: build,
    act: (c) {
      c.submitName('Ana');
      c.back();
    },
    expect: () => [
      isA<OnboardingEditing>().having((s) => s.step, 'step', 1),
      isA<OnboardingEditing>()
          .having((s) => s.step, 'step', 0)
          .having((s) => s.draft.firstName, 'firstName', 'Ana'),
    ],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'error del BFF se muestra y permite reintentar en el mismo paso',
    setUp: () => profiles.completeResult = const Result.err(
      ServiceUnavailableFailure(message: 'En mantenimiento.'),
    ),
    build: build,
    act: (c) async {
      c.submitName('Ana');
      c.submitProfile(birthYear: 1990, occupation: Occupation.employee);
      await c.submitIncome(IncomeRange.low);
    },
    skip: 3,
    expect: () => [
      isA<OnboardingEditing>()
          .having((s) => s.step, 'step', 2)
          .having((s) => s.error, 'error', 'En mantenimiento.'),
    ],
    verify: (_) => verifyNever(signals.profileChanged),
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'already_onboarded (reintento tras timeout) se trata como éxito',
    setUp: () => profiles.completeResult = const Result.err(
      ValidationFailure('already_onboarded'),
    ),
    build: build,
    act: (c) async {
      c.submitName('Ana');
      c.submitProfile(birthYear: 1990, occupation: Occupation.employee);
      await c.submitIncome(IncomeRange.low);
    },
    skip: 3,
    expect: () => [isA<OnboardingDone>()],
    verify: (_) => verify(signals.profileChanged).called(1),
  );
}
