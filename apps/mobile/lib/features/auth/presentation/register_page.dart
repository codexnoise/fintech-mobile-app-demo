import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'auth_validators.dart';
import 'register_cubit.dart';
import 'widgets/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    context.read<RegisterCubit>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(NexoRoutes.login)),
      ),
      body: SafeArea(
        child: BlocBuilder<RegisterCubit, RegisterState>(
          builder: (context, state) {
            final busy =
                state is RegisterInProgress || state is RegisterSuccess;
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
                            title: 'Abre tu cuenta',
                            subtitle: 'En 3 minutos y sin papeleo.',
                          ),
                          const SizedBox(height: NexoSpacing.xl),
                          if (state case RegisterError(:final message))
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
                            validator: validateNewPassword,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: NexoSpacing.xxs),
                          Text(
                            'Mínimo $minPasswordLength caracteres, con letras '
                            'y números.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: NexoColors.onSurfaceMuted),
                          ),
                          const SizedBox(height: NexoSpacing.md),
                          PasswordField(
                            controller: _confirmation,
                            label: 'Confirma tu contraseña',
                            validator: (v) =>
                                validateConfirmation(_password.text, v),
                            autofillHints: const [AutofillHints.newPassword],
                            onSubmitted: _submit,
                          ),
                          const SizedBox(height: NexoSpacing.lg),
                          PrimaryButton(
                            label: 'Crear cuenta',
                            loading: busy,
                            onPressed: _submit,
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
