import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_mobile/features/auth/domain/auth_repository.dart';
import 'package:nexo_mobile/features/auth/presentation/login_cubit.dart';
import 'package:nexo_mobile/features/auth/presentation/register_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  group('LoginCubit', () {
    blocTest<LoginCubit, LoginState>(
      'login exitoso',
      build: () => LoginCubit(auth),
      act: (c) => c.submit(email: 'ana@nexo.ec', password: 'clave123'),
      expect: () => [isA<LoginInProgress>(), isA<LoginSuccess>()],
    );

    blocTest<LoginCubit, LoginState>(
      'credenciales inválidas -> mensaje humano sin códigos de Firebase',
      setUp: () => auth.nextFailure = const ValidationFailure(
        AuthErrorCodes.invalidCredentials,
      ),
      build: () => LoginCubit(auth),
      act: (c) => c.submit(email: 'ana@nexo.ec', password: 'x'),
      expect: () => [
        isA<LoginInProgress>(),
        isA<LoginError>().having(
          (s) => s.message,
          'message',
          'Correo o contraseña incorrectos.',
        ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'sin red -> mensaje de conexión',
      setUp: () => auth.nextFailure = const NetworkFailure(),
      build: () => LoginCubit(auth),
      act: (c) => c.submit(email: 'ana@nexo.ec', password: 'x'),
      expect: () => [
        isA<LoginInProgress>(),
        isA<LoginError>().having(
          (s) => s.message,
          'message',
          contains('conexión'),
        ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'ignora envíos repetidos mientras está en curso',
      build: () => LoginCubit(auth),
      act: (c) {
        c.submit(email: 'a@nexo.ec', password: 'x');
        c.submit(email: 'a@nexo.ec', password: 'x');
      },
      expect: () => [isA<LoginInProgress>(), isA<LoginSuccess>()],
    );

    blocTest<LoginCubit, LoginState>(
      'reset de contraseña confirma sin revelar si la cuenta existe',
      build: () => LoginCubit(auth),
      act: (c) => c.requestPasswordReset('ana@nexo.ec'),
      expect: () => [
        isA<LoginInProgress>(),
        isA<LoginPasswordResetSent>().having(
          (s) => s.email,
          'email',
          'ana@nexo.ec',
        ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'reset sin correo válido pide el correo',
      build: () => LoginCubit(auth),
      act: (c) => c.requestPasswordReset('no-es-correo'),
      expect: () => [
        isA<LoginError>().having(
          (s) => s.message,
          'message',
          contains('correo'),
        ),
      ],
    );
  });

  group('RegisterCubit', () {
    blocTest<RegisterCubit, RegisterState>(
      'registro exitoso',
      build: () => RegisterCubit(auth),
      act: (c) => c.submit(email: 'ana@nexo.ec', password: 'clave123'),
      expect: () => [isA<RegisterInProgress>(), isA<RegisterSuccess>()],
    );

    blocTest<RegisterCubit, RegisterState>(
      'correo ya registrado',
      setUp: () =>
          auth.nextFailure = const ValidationFailure(AuthErrorCodes.emailInUse),
      build: () => RegisterCubit(auth),
      act: (c) => c.submit(email: 'ana@nexo.ec', password: 'clave123'),
      expect: () => [
        isA<RegisterInProgress>(),
        isA<RegisterError>().having(
          (s) => s.message,
          'message',
          contains('Ya existe una cuenta'),
        ),
      ],
    );
  });
}
