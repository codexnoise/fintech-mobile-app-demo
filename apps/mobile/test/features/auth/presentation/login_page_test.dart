import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/presentation/login_cubit.dart';
import 'package:nexo_mobile/features/auth/presentation/login_page.dart';

import '../../../helpers/fakes.dart';

Future<FakeAuthRepository> pumpLogin(WidgetTester tester) async {
  final auth = FakeAuthRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: NexoTheme.light(),
      home: BlocProvider(
        create: (_) => LoginCubit(auth),
        child: const LoginPage(),
      ),
    ),
  );
  return auth;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('valida campos vacíos sin llamar al backend', (tester) async {
    final auth = await pumpLogin(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa tu correo.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(auth.lastPassword, isNull);
  });

  testWidgets('valida formato de correo', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(field('Correo electrónico'), 'ana');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
  });

  testWidgets('envía credenciales válidas', (tester) async {
    final auth = await pumpLogin(tester);

    await tester.enterText(field('Correo electrónico'), 'ana@nexo.ec');
    await tester.enterText(field('Contraseña'), 'clave1234');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(auth.lastPassword, 'clave1234');
  });

  testWidgets('muestra el error del backend', (tester) async {
    final auth = await pumpLogin(tester);
    auth.nextFailure = const ValidationFailure(
      AuthErrorCodes.invalidCredentials,
    );

    await tester.enterText(field('Correo electrónico'), 'ana@nexo.ec');
    await tester.enterText(field('Contraseña'), 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('la contraseña se puede mostrar y ocultar', (tester) async {
    await pumpLogin(tester);

    EditableText password() => tester.widget<EditableText>(
      find.descendant(
        of: field('Contraseña'),
        matching: find.byType(EditableText),
      ),
    );
    expect(password().obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    expect(password().obscureText, isFalse);
  });
}
