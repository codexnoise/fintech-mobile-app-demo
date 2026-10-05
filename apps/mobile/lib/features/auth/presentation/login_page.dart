import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'auth_validators.dart';
import 'login_cubit.dart';
import 'widgets/auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            if (state is LoginPasswordResetSent) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Si existe una cuenta con ${state.email}, te enviamos '
                    'un enlace para restablecer tu contraseña.',
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            final busy = state is LoginInProgress || state is LoginSuccess;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NexoSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthHeader(
                            title: 'Bienvenido a Nexo',
                            subtitle:
                                'Tu banca digital transparente y sin '
                                'fricción',
                          ),
                          const SizedBox(height: NexoSpacing.xl),
                          if (state case LoginError(:final message))
                            FormErrorBanner(message),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            validator: validateEmail,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: NexoSpacing.md),
                          PasswordField(
                            controller: _password,
                            label: 'Contraseña',
                            validator: validateLoginPassword,
                            onSubmitted: _submit,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => context
                                        .read<LoginCubit>()
                                        .requestPasswordReset(_email.text),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          const SizedBox(height: NexoSpacing.xs),
                          PrimaryButton(
                            label: 'Iniciar sesión',
                            loading: busy,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: NexoSpacing.lg),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('¿No tienes cuenta?'),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => context.go(NexoRoutes.register),
                                child: const Text('Abre tu cuenta'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
