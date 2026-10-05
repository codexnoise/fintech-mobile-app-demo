import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/features/auth/presentation/widgets/auth_widgets.dart';

void main() {
  testWidgets('"siguiente" salta al próximo campo, no al botón del ojo', (
    tester,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PasswordField(
                key: const Key('first'),
                controller: first,
                label: 'Contraseña',
                validator: (_) => null,
                textInputAction: TextInputAction.next,
              ),
              PasswordField(
                key: const Key('second'),
                controller: second,
                label: 'Confirma',
                validator: (_) => null,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('first')));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byKey(const Key('second')),
        matching: find.byWidget(focused.widget),
      ),
      findsOneWidget,
    );
  });
}
