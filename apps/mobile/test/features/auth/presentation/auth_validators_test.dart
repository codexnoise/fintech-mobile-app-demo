import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_mobile/features/auth/presentation/auth_validators.dart';

void main() {
  test('email', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('ana'), isNotNull);
    expect(validateEmail('ana@nexo'), isNotNull);
    expect(validateEmail(' ana@nexo.ec '), isNull);
  });

  test('contraseña de login solo exige que exista', () {
    expect(validateLoginPassword(''), isNotNull);
    expect(validateLoginPassword('x'), isNull);
  });

  test('contraseña nueva: 8+ caracteres con letras y números', () {
    expect(validateNewPassword('abc123'), isNotNull);
    expect(validateNewPassword('abcdefgh'), isNotNull);
    expect(validateNewPassword('12345678'), isNotNull);
    expect(validateNewPassword('clave1234'), isNull);
  });

  test('confirmación', () {
    expect(validateConfirmation('clave1234', 'clave1235'), isNotNull);
    expect(validateConfirmation('clave1234', 'clave1234'), isNull);
  });
}
