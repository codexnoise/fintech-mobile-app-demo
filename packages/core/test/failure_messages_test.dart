import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';

void main() {
  test('usa el mensaje del BFF cuando existe', () {
    expect(
      const ValidationFailure(
        'insufficient_funds',
        'Saldo insuficiente.',
      ).userMessage,
      'Saldo insuficiente.',
    );
  });

  test('nunca expone detalles técnicos de errores de servidor', () {
    const f = ServerFailure(code: 'internal_error', message: 'TypeError: x');
    expect(f.userMessage, isNot(contains('TypeError')));
  });

  test('sin red tiene un mensaje accionable', () {
    expect(const NetworkFailure().userMessage, contains('conexión'));
  });
}
