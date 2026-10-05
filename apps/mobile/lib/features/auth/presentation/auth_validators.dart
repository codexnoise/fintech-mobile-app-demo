final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
final _hasLetter = RegExp('[A-Za-zÁÉÍÓÚáéíóúÑñ]');
final _hasDigit = RegExp(r'\d');

const minPasswordLength = 8;

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Ingresa tu correo.';
  if (!_emailPattern.hasMatch(email)) return 'Ingresa un correo válido.';
  return null;
}

/// En login no se revela la política: solo se exige que no esté vacía.
String? validateLoginPassword(String? value) =>
    (value ?? '').isEmpty ? 'Ingresa tu contraseña.' : null;

String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.length < minPasswordLength ||
      !_hasLetter.hasMatch(password) ||
      !_hasDigit.hasMatch(password)) {
    return 'Usa al menos $minPasswordLength caracteres con letras y números.';
  }
  return null;
}

String? validateConfirmation(String? password, String? confirmation) =>
    password == confirmation ? null : 'Las contraseñas no coinciden.';
