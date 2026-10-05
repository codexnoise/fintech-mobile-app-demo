import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/auth_repository.dart';
import 'auth_messages.dart';
import 'auth_validators.dart';

sealed class LoginState {
  const LoginState();
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginInProgress extends LoginState {
  const LoginInProgress();
}

/// La sesión cambió; el router navega solo (no hay navegación aquí).
final class LoginSuccess extends LoginState {
  const LoginSuccess();
}

final class LoginError extends LoginState {
  const LoginError(this.message);

  final String message;
}

final class LoginPasswordResetSent extends LoginState {
  const LoginPasswordResetSent(this.email);

  final String email;
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._auth) : super(const LoginInitial());

  final AuthRepository _auth;

  Future<void> submit({required String email, required String password}) async {
    if (state is LoginInProgress || state is LoginSuccess) return;
    emit(const LoginInProgress());
    final result = await _auth.signIn(email: email, password: password);
    emit(switch (result) {
      Ok() => const LoginSuccess(),
      Err(:final failure) => LoginError(authErrorMessage(failure)),
    });
  }

  Future<void> requestPasswordReset(String email) async {
    if (state is LoginInProgress) return;
    if (validateEmail(email) != null) {
      return emit(
        const LoginError('Escribe tu correo para enviarte el enlace.'),
      );
    }
    emit(const LoginInProgress());
    final result = await _auth.sendPasswordReset(email);
    emit(switch (result) {
      Ok() => LoginPasswordResetSent(email.trim()),
      Err(:final failure) => LoginError(authErrorMessage(failure)),
    });
  }
}
