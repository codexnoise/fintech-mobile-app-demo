import 'package:nexo_core/nexo_core.dart';

import '../domain/auth_repository.dart';

/// Mensaje para el usuario. Nunca muestra códigos de Firebase.
String authErrorMessage(Failure failure) => switch (failure) {
  ValidationFailure(code: AuthErrorCodes.invalidCredentials) =>
    'Correo o contraseña incorrectos.',
  ValidationFailure(code: AuthErrorCodes.emailInUse) =>
    'Ya existe una cuenta con este correo. Inicia sesión.',
  ValidationFailure(code: AuthErrorCodes.invalidEmail) =>
    'Ingresa un correo válido.',
  ValidationFailure(code: AuthErrorCodes.weakPassword) =>
    'La contraseña es muy débil. Usa al menos 8 caracteres con letras '
        'y números.',
  ValidationFailure(code: AuthErrorCodes.tooManyRequests) =>
    'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
  ValidationFailure(code: AuthErrorCodes.userDisabled) =>
    'Esta cuenta está deshabilitada. Contacta a soporte.',
  ValidationFailure(code: AuthErrorCodes.noSession) =>
    'Tu sesión expiró. Ingresa nuevamente.',
  _ => failure.userMessage,
};
