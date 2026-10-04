import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';

void main() {
  group('Money', () {
    test('suma y resta en centavos sin errores de punto flotante', () {
      const a = Money(10); // 0,10
      const b = Money(20); // 0,20
      expect((a + b).cents, 30);
      expect((b - a).cents, 10);
    });

    test('fromTypedDigits interpreta entrada estilo cajero', () {
      expect(Money.fromTypedDigits('12345').cents, 12345);
      expect(Money.fromTypedDigits(r'$1,234.5').cents, 12345);
      expect(Money.fromTypedDigits('').isZero, isTrue);
    });

    test('fromTypedDigits limita la longitud para evitar overflow', () {
      final m = Money.fromTypedDigits('9' * 40);
      expect(m.cents.toString().length, 15);
    });

    test('format agrupa miles y respeta signo', () {
      expect(const Money(123456789).format(), r'$1,234,567.89');
      expect(const Money(5).format(), r'$0.05');
      expect(const Money(-100000).format(), r'-$1,000.00');
      expect(
        const Money(123456).format(thousands: '.', decimal: ','),
        r'$1.234,56',
      );
    });

    test('rechaza operar con monedas distintas', () {
      expect(
        () => const Money(1) + const Money(1, currency: 'EUR'),
        throwsArgumentError,
      );
    });

    test('comparaciones', () {
      expect(const Money(5) < const Money(6), isTrue);
      expect(const Money(6) >= const Money(6), isTrue);
      expect(const Money(-5).abs(), const Money(5));
    });
  });
}
