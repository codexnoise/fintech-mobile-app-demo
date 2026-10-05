import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:nexo_mobile/features/onboarding/domain/user_profile.dart';
import 'package:nexo_mobile/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:nexo_mobile/features/onboarding/presentation/onboarding_page.dart';

import '../../../helpers/fakes.dart';

class _MockSignals extends Mock implements SessionSignals {}

void main() {
  testWidgets('avanza por los 3 pasos y envía', (tester) async {
    final profiles = FakeProfileRepository();
    final signals = _MockSignals();
    when(signals.profileChanged).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: NexoTheme.light(),
        home: BlocProvider(
          create: (_) =>
              OnboardingCubit(profiles, signals, currentYear: () => 2026),
          child: const OnboardingPage(),
        ),
      ),
    );

    expect(find.text('Paso 1 de 3'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Ana');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 2 de 3'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '1994');
    await tester.tap(find.text('Independiente'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 3 de 3'), findsOneWidget);
    await tester.tap(find.text('Más de USD 3.000 al mes'));
    await tester.tap(find.text('Finalizar'));
    // El spinner queda activo hasta que el router navega: no usar settle.
    await tester.pump();

    final sent = profiles.submitted!;
    expect(sent.firstName, 'Ana');
    expect(sent.birthYear, 1994);
    expect(sent.occupation, Occupation.freelancer);
    expect(sent.incomeRange, IncomeRange.high);
  });

  testWidgets('el progreso es accesible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => OnboardingCubit(
            FakeProfileRepository(),
            _MockSignals(),
            currentYear: () => 2026,
          ),
          child: const OnboardingPage(),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Paso 1 de 3'), findsWidgets);
  });
}
