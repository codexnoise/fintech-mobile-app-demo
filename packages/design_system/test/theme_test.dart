import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

void main() {
  test('el tema usa los tokens de marca', () {
    final theme = NexoTheme.light();
    expect(theme.colorScheme.primary, NexoColors.brand);
    expect(theme.scaffoldBackgroundColor, NexoColors.background);
  });

  testWidgets('el texto secundario cumple contraste AA sobre surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NexoTheme.light(),
        home: const Scaffold(
          backgroundColor: NexoColors.surface,
          body: Center(
            child: Text(
              'Actualizado hace 5 min',
              style: TextStyle(color: NexoColors.onSurfaceMuted, fontSize: 14),
            ),
          ),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
