import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

Widget _app(Widget child) => MaterialApp(
  theme: NexoTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('moneySemanticsLabel', () {
    test('lee dólares y centavos', () {
      expect(
        moneySemanticsLabel(const Money(874025)),
        '8740 dólares con 25 centavos',
      );
    });

    test('singular y sin centavos', () {
      expect(moneySemanticsLabel(const Money(100)), '1 dólar');
      expect(moneySemanticsLabel(const Money(1)), '0 dólares con 1 centavo');
    });

    test('signo', () {
      expect(
        moneySemanticsLabel(const Money(-8420)),
        'menos 84 dólares con 20 centavos',
      );
      expect(
        moneySemanticsLabel(const Money(35000), signed: true),
        'más 350 dólares',
      );
    });
  });

  testWidgets('MoneyText muestra el monto y lo anuncia legible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const MoneyText(Money(874025), semanticsPrefix: 'Saldo')),
    );

    expect(find.text(r'$8,740.25'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Saldo, 8740 dólares con 25 centavos'),
      findsOneWidget,
    );
  });

  group('AmountField', () {
    testWidgets('escribe estilo cajero y entrega Money en centavos', (
      tester,
    ) async {
      Money? last;
      await tester.pumpWidget(
        _app(
          AmountField(value: const Money.zero(), onChanged: (m) => last = m),
        ),
      );

      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();

      expect(last, const Money(12345));
      expect(find.text('123.45'), findsOneWidget);
    });

    testWidgets('ignora caracteres no numéricos', (tester) async {
      Money? last;
      await tester.pumpWidget(
        _app(
          AmountField(value: const Money.zero(), onChanged: (m) => last = m),
        ),
      );

      await tester.enterText(find.byType(TextField), '1a2,3.4');
      await tester.pump();

      expect(last, const Money(1234));
      expect(find.text('12.34'), findsOneWidget);
    });

    testWidgets('refleja cambios externos (atajos +\$50, Todo)', (
      tester,
    ) async {
      var value = const Money(500);
      late StateSetter setState;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return AmountField(value: value, onChanged: (m) => value = m);
            },
          ),
        ),
      );
      expect(find.text('5.00'), findsOneWidget);

      setState(() => value = const Money(1050000));
      await tester.pump();

      expect(find.text('10,500.00'), findsOneWidget);
    });
  });

  test('relativeUpdatedLabel', () {
    final now = DateTime(2026, 10, 5, 12);
    expect(relativeUpdatedLabel(now, now), 'Actualizado hace un momento');
    expect(
      relativeUpdatedLabel(now.subtract(const Duration(minutes: 5)), now),
      'Actualizado hace 5 min',
    );
    expect(
      relativeUpdatedLabel(now.subtract(const Duration(hours: 3)), now),
      'Actualizado hace 3 h',
    );
    expect(
      relativeUpdatedLabel(now.subtract(const Duration(days: 2)), now),
      'Actualizado hace 2 días',
    );
  });

  testWidgets('StatusBanner cumple contraste AA y anuncia el mensaje', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            StatusBanner.offline('Sin conexión. Mostrando datos guardados.'),
            StatusBanner.error('No pudimos cargar tus movimientos.'),
            StatusBanner.maintenance('Transferencias en mantenimiento.'),
          ],
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    expect(find.bySemanticsLabel(RegExp('Sin conexión')), findsOneWidget);
  });

  testWidgets('Skeleton se anuncia como cargando', (tester) async {
    await tester.pumpWidget(_app(const Skeleton(height: 20)));

    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
  });
}
