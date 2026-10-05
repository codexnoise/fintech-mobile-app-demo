import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import '../domain/biometrics.dart';
import 'auth_validators.dart';
import 'lock_cubit.dart';
import 'widgets/auth_widgets.dart';

/// Pantalla de bloqueo con sesión vigente (Stitch: login con biometría).
class LockPage extends StatefulWidget {
  const LockPage({this.email, super.key});

  final String? email;

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Lanza el prompt al abrir para que desbloquear sea un solo gesto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LockCubit>().unlockWithBiometric();
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submitPassword() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LockCubit>().unlockWithPassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No se puede "volver" a una pantalla protegida sin desbloquear.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<LockCubit, LockScreenState>(
            builder: (context, state) {
              final cubit = context.read<LockCubit>();
              final method = switch (state) {
                LockIdle(:final method) ||
                LockInProgress(:final method) => method,
                LockUnlocked() => UnlockMethod.biometric,
              };
              final busy = state is! LockIdle;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(NexoSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthHeader(
                            title: 'Hola de nuevo',
                            subtitle: widget.email == null
                                ? 'Confirma tu identidad para continuar.'
                                : 'Confirma tu identidad para continuar como '
                                      '${widget.email}.',
                          ),
                          const SizedBox(height: NexoSpacing.xl),
                          if (state case LockIdle(:final message?))
                            FormErrorBanner(message),
                          if (method == UnlockMethod.biometric)
                            FilledButton.tonalIcon(
                              onPressed: busy
                                  ? null
                                  : cubit.unlockWithBiometric,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(
                                  kMinTapTarget + 8,
                                ),
                              ),
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Ingresar con biometría'),
                            )
                          else ...[
                            PasswordField(
                              controller: _password,
                              label: 'Contraseña',
                              validator: validateLoginPassword,
                              onSubmitted: _submitPassword,
                            ),
                            const SizedBox(height: NexoSpacing.md),
                            PrimaryButton(
                              label: 'Desbloquear',
                              loading: busy,
                              onPressed: _submitPassword,
                            ),
                          ],
                          const SizedBox(height: NexoSpacing.lg),
                          TextButton(
                            onPressed: busy ? null : cubit.useAnotherAccount,
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(kMinTapTarget),
                            ),
                            child: const Text('Usar otra cuenta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
