import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_core/nexo_core.dart';

import '../domain/auth_repository.dart';
import 'auth_messages.dart';

sealed class RegisterState {
  const RegisterState();
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterInProgress extends RegisterState {
  const RegisterInProgress();
}

/// Cuenta creada; el router lleva al onboarding.
final class RegisterSuccess extends RegisterState {
  const RegisterSuccess();
}

final class RegisterError extends RegisterState {
  const RegisterError(this.message);

  final String message;
}

class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._auth) : super(const RegisterInitial());

  final AuthRepository _auth;

  Future<void> submit({required String email, required String password}) async {
    if (state is RegisterInProgress || state is RegisterSuccess) return;
    emit(const RegisterInProgress());
    final result = await _auth.register(email: email, password: password);
    emit(switch (result) {
      Ok() => const RegisterSuccess(),
      Err(:final failure) => RegisterError(authErrorMessage(failure)),
    });
  }
}
