import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexo_design_system/nexo_design_system.dart';

import 'biometric_setup_cubit.dart';
import 'widgets/auth_widgets.dart';

class BiometricSetupPage extends StatelessWidget {
  const BiometricSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<BiometricSetupCubit, BiometricSetupState>(
          builder: (context, state) {
            final cubit = context.read<BiometricSetupCubit>();
            final busy = state is! BiometricSetupIdle;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NexoSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(
                        title: 'Ingresa más rápido',
                        subtitle:
                            'Usa tu huella o rostro para abrir Nexo. Tus datos '
                            'biométricos nunca salen de tu dispositivo.',
                      ),
                      const SizedBox(height: NexoSpacing.xl),
                      if (state case BiometricSetupIdle(:final message?))
                        FormErrorBanner(message),
                      PrimaryButton(
                        label: 'Activar biometría',
                        loading: state is BiometricSetupInProgress,
                        onPressed: busy ? null : cubit.enable,
                      ),
                      const SizedBox(height: NexoSpacing.sm),
                      TextButton(
                        onPressed: busy ? null : cubit.skip,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(kMinTapTarget),
                        ),
                        child: const Text('Ahora no'),
                      ),
                      const SizedBox(height: NexoSpacing.xs),
                      Text(
                        'Si no la activas, te pediremos tu contraseña cada '
                        'vez que abras la app.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: NexoColors.onSurfaceMuted),
                      ),
                    ],
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
